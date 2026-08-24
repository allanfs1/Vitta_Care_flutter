# Tarefas Agendadas — Lógica e Especificação

Documentação completa da página **`/dashboard/tarefas-agendadas`** e de toda a lógica
de back-end que a sustenta: agendamento, execução autônoma do agente de IA, locking
contra duplicidade, RBAC/multi-tenant e geração de relatórios.

> **Stack**: Next.js 16 (App Router) + Firebase Admin/Firestore + MCP (agente de I.A)
> **Fuso de referência**: `America/Sao_Paulo` (BRT, UTC-3 fixo)
> **Coleção principal**: `tb_scheduled_tasks`

---

## 1. Visão Geral

A página permite **programar o agente de IA** para executar instruções em linguagem
natural automaticamente — uma vez, em intervalo, ou de forma recorrente (diária, semanal,
mensal). Cada tarefa pode ser de dois tipos:

| `kind`     | Descrição |
|------------|-----------|
| `action`   | Executa uma **ação** (enviar e-mails/WhatsApp, atualizar status, etc.) e produz um resumo. |
| `report`   | Gera um **relatório com gráficos** para decisão, salvo em `tb_scheduled_reports` e (opcionalmente) enviado por e-mail. |

Na hora marcada, um **agente MCP não-streaming** (`agent-runner`) recebe o `prompt`,
chama as ferramentas necessárias e devolve o resultado, que é registrado no histórico da tarefa.

### Fluxo de ponta a ponta

```
┌───────────────────────────┐         ┌───────────────────────────┐
│ Página Tarefas Agendadas  │         │   Chat / Agente de I.A    │
│ (criar/editar/run/pausar) │         │   (tool: agendar_tarefa)  │
└─────────────┬─────────────┘         └─────────────┬─────────────┘
              │  REST /api/scheduled-tasks          │ MCP tool
              ▼                                      ▼
        scheduled_tasks.schema.js  ◄────────────────┘
        (CRUD + lock + nextRunAt)
              ▲                         ┌──────────────────────────┐
   claim/finish (lock atômico)         │  Disparadores            │
              │                         │  • Vercel Cron (5 min)   │
        scheduled_tasks.service.js ◄────┤  • Catch-up (front-end)  │
        (executa + persiste relatório) │  • Executar agora        │
              │                         └──────────────────────────┘
              ▼
        agent-runner.js  → MCP (createMcpServer) → DeepSeek (ai-client)
              │
              ├── kind=action  → resumo + e-mail opcional
              └── kind=report  → extractCharts → tb_scheduled_reports + e-mail HTML
```

---

## 2. Estrutura de Arquivos

```
app_company/
├── src/app/dashboard/tarefas-agendadas/
│   └── page.jsx                                   ← UI (lista, modal criar/editar, histórico)
├── src/app/api/
│   ├── scheduled-tasks/
│   │   ├── route.js                               ← GET (listar) · POST (criar)
│   │   ├── [id]/route.js                          ← GET · PATCH (editar/pausar/retomar) · DELETE
│   │   ├── [id]/run/route.js                      ← POST (executar agora)
│   │   └── run-due/route.js                       ← POST (catch-up das vencidas da clínica)
│   └── cron/
│       └── scheduler/route.js                     ← GET (Vercel Cron, a cada 5 min)
├── src/core/modules/scheduled_tasks/
│   ├── scheduled_tasks.schema.js                  ← Camada de dados + lock + nextRunAt
│   ├── scheduled_tasks.service.js                 ← Orquestração da execução
│   └── schedule.util.js                           ← Cálculo de horários (TZ BRT), validação, parse
├── src/lib/
│   ├── agent-runner.js                            ← Loop de tool-calling não-streaming (MCP)
│   ├── access-control.js                          ← RBAC + multi-tenant
│   └── report-format.js                           ← extractCharts / reportEmailHtml
└── vercel.json                                    ← Configuração do Cron
```

---

## 3. Modelo de Dados — `tb_scheduled_tasks`

```js
{
  titulo: string,
  descricao: string,
  prompt: string,                  // instrução em linguagem natural executada pelo agente
  kind: "action" | "report",
  schedule: {
    type: "once" | "interval" | "daily" | "weekly" | "monthly",
    time?: "HH:MM",                // daily/weekly/monthly (BRT)
    weekdays?: number[],          // weekly: 0=Dom .. 6=Sáb
    dayOfMonth?: number,          // monthly: 1-31 (ajustado p/ meses curtos)
    intervalMinutes?: number,     // interval: >= 1
    runAt?: ISOString             // once
  },
  status: "active" | "paused" | "completed" | "error",
  nextRunAt: Timestamp | null,     // próxima execução (null = encerrada)
  lastRunAt: Timestamp | null,
  lockedAt:  Timestamp | null,     // lock de execução (claim / manual)
  runCount: number,
  errorCount: number,
  maxRuns: number | null,          // encerra após N execuções (opcional)
  endAt:   Timestamp | null,       // encerra após esta data (opcional)
  notifyEmail: string | null,
  history: [                       // últimas 20 execuções (mais recente primeiro)
    { runAt, ok, summary, toolsUsed, durationMs, reportId }
  ],
  clinicaId: string,               // multi-tenant
  createdBy: string | null,        // uid ou "agente-chat"
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

Constantes relevantes (`scheduled_tasks.schema.js`):

| Símbolo | Valor | Função |
|---|---|---|
| `COLLECTION` | `tb_scheduled_tasks` | Coleção Firestore |
| `DEFAULT_CLINICA` | `JuhdNt7NG3GYOFKOKOXP` | Clínica padrão |
| `HISTORY_LIMIT` | `20` | Máx. de execuções no histórico |
| `LOCK_TTL_MS` | `10 min` | Tempo após o qual um lock é considerado órfão |

---

## 4. Cálculo de Agendamento — `schedule.util.js`

Funções puras, sem dependências externas. Fuso fixo **BRT (UTC-3)** — seguro pois o Brasil
não tem horário de verão desde 2019.

| Função | Descrição |
|---|---|
| `computeNextRun(schedule, from)` | Próximo horário de execução (Date UTC) após `from`; `null` se não houver. Itera dia-a-dia no calendário BRT até achar o primeiro candidato válido. |
| `describeSchedule(schedule)` | Descrição legível em pt-BR (ex.: "Todos os dias às 08:00", "A cada 2h"). |
| `parseFlexibleDate(input)` | Converte data flexível → ISO. Aceita `Date`, ISO (com/sem TZ) e `DD/MM/AAAA HH:MM`. Sem TZ ⇒ interpretado como BRT. |
| `validateSchedule(schedule)` | Valida a estrutura; lança `Error` com mensagem amigável. |

**Regras de recorrência:**
- `once` — roda uma vez em `runAt`; depois `nextRunAt = null`.
- `interval` — a cada `intervalMinutes` (mín. 1) a partir de agora.
- `daily` — todo dia às `time`.
- `weekly` — nos `weekdays` (0=Dom..6=Sáb) às `time`.
- `monthly` — no `dayOfMonth` (1-31, ajustado a meses curtos) às `time`.

**Término automático** (`computeNextWithTermination`): a próxima execução vira `null`
quando o tipo é `once`, quando `runCount+1 >= maxRuns`, ou quando a próxima data ultrapassa `endAt`.

---

## 5. Camada de Dados — `scheduled_tasks.schema.js`

| Função | Descrição |
|---|---|
| `createScheduledTask(input)` | Valida, calcula o 1º `nextRunAt` e grava (status `active`). Rejeita se não houver execução futura. |
| `listScheduledTasks(clinicaId, {status, clinicaIds, limite})` | Lista por clínica (igualdade simples + ordenação/filtro em memória → **sem índice composto**). `clinicaId=null` ⇒ todas (rsa). |
| `getScheduledTask(id)` | Busca por ID (serializa timestamps em ISO). |
| `updateScheduledTask(id, patch)` | Edita campos; se `schedule` mudar, recalcula `nextRunAt`; reativar sem futuro recalcula a partir de agora. |
| `deleteScheduledTask(id)` | Exclui. |
| `getDueTasks(now, limit)` | Tarefas vencidas (`nextRunAt <= now`) e `active` (filtro de status em memória). |

### 5.1 Execução exatamente-uma-vez (locking atômico)

O cron e o catch-up do front-end podem rodar simultaneamente — o lock garante que a
**mesma ocorrência nunca dispare duas vezes** (evita e-mail/WhatsApp duplicado ao paciente).

| Função | Descrição |
|---|---|
| `claimDueTask(id, now)` | **Transação Firestore**: se `active`, sem lock vivo e vencida → marca `status: running`, grava `lockedAt` e **já avança** `nextRunAt`. Retorna a tarefa ou `null` se não ganhou o lock. |
| `finishRun(id, runResult)` | Após o claim: grava histórico/contadores, define status final (`active` se há próxima, senão `completed`) e libera o lock. |
| `lockForManualRun(id)` | Lock para "executar agora" (não roda se já houver execução em andamento). |
| `recordManualRun(id, runResult)` | Registra execução manual **sem** mexer em `nextRunAt`/`status`. |
| `unlockManualRun(id)` | Libera o lock manual. |
| `recoverStaleTasks(now)` | Recupera órfãs presas em `running` com lock > `LOCK_TTL_MS` (volta a `active`/`completed`, incrementa `errorCount`). |

---

## 6. Orquestração da Execução — `scheduled_tasks.service.js`

| Função | Descrição |
|---|---|
| `runDueTasks(limit, {clinicaIds})` | Recupera órfãs → busca vencidas → `claimDueTask` por candidato → executa quem ganhou o lock. `clinicaIds=null` ⇒ todas (cron). |
| `runTaskById(id)` | "Executar agora": lock manual → executa → `recordManualRun` → libera lock (sem alterar agendamento). |
| `executeTask(task)` *(interno)* | Roda o agente com `RUN_TIMEOUT_MS = 4 min`; se `report`, extrai gráficos e persiste/envia; senão, notifica resultado por e-mail (se houver). |

**System prompts** (injetam o `clinicaId` real da tarefa):
- `SCHEDULER_SYSTEM` — para `kind=action`: executa de ponta a ponta, nunca pede confirmação, resume números obtidos. `maxRounds = 6`.
- `REPORT_SYSTEM` — para `kind=report`: relatório em Markdown (Resumo Executivo, tabelas, Recomendações) com **1–4 gráficos** ` ```json-chart `. `maxRounds = 8`.

**Pipeline de relatório**: `runAgentTask` → `extractCharts(content)` →
`createReport({...})` em `tb_scheduled_reports` → e-mail HTML (`reportEmailHtml`,
com link para `/dashboard/relatorios-agendados?r=<id>`).

---

## 7. Agente Executor — `agent-runner.js`

`runAgentTask(prompt, { systemPrompt, complex=true, maxRounds=6, defaultClinicaId })`

- Cria um **MCP in-memory** (`InMemoryTransport` + `createMcpServer({ defaultClinicaId })`),
  expondo **todas** as ferramentas ao modelo.
- Loop de tool-calling com `createCompletion` (`ai-client`, DeepSeek Pro por padrão) até a
  resposta final ou `maxRounds`.
- Retorna `{ content, toolsUsed: [{name, ok}], rounds }`.
- Diretriz de prompt: usar sempre **nomes legíveis** (nunca IDs internos) em textos/resumos.

---

## 8. API REST

Todas as rotas exigem **admin/rsa** via `requireScheduleAccess` (ver §10). `force-dynamic`.

| Método & rota | Ação | Observações |
|---|---|---|
| `GET /api/scheduled-tasks` | Lista as tarefas do escopo | admin → sua clínica; rsa → todas/permitidas. Anexa `scheduleLabel`. |
| `POST /api/scheduled-tasks` | Cria tarefa | Clínica resolvida por `resolveCreateClinica`; `auditLog("create")`. 201. |
| `GET /api/scheduled-tasks/[id]` | Detalhe | Valida escopo da clínica (404/403). |
| `PATCH /api/scheduled-tasks/[id]` | Editar / pausar / retomar | Remove `clinicaId` do body (não permite mover de clínica). |
| `DELETE /api/scheduled-tasks/[id]` | Excluir | — |
| `POST /api/scheduled-tasks/[id]/run` | Executar agora | `maxDuration = 300`; `auditLog("run")`. |
| `POST /api/scheduled-tasks/run-due` | Catch-up das vencidas da clínica | Disparado pelo front-end ao abrir a página; lock evita duplicar com o cron. |
| `GET /api/cron/scheduler` | Executor agendado (Vercel Cron) | Protegido por `CRON_SECRET` (fail-closed); processa até 10 vencidas. |

### 8.1 Cron — `vercel.json`

```json
{ "crons": [
  { "path": "/api/cron/monitor",   "schedule": "0 10 * * *" },
  { "path": "/api/cron/scheduler", "schedule": "*/5 * * * *" }
] }
```

- **`/api/cron/scheduler`** roda a cada **5 minutos**. Autenticação por `CRON_SECRET`:
  aceita `x-cron-secret`, `?secret=` ou `Authorization: Bearer <CRON_SECRET>` (enviado
  automaticamente pelo Vercel Cron). **Sem `CRON_SECRET` configurado → 503 (fail-closed).**

---

## 9. UI — `page.jsx`

### 9.1 Lista de tarefas
- **Header**: título + contador de ativas + botão **Nova tarefa**.
- **Card por tarefa**: ícone/cor por status, badge de status, badge **Relatório** (se `kind=report`),
  `scheduleLabel`, próxima/última execução, `runCount` (e nº de erros).
- **Ações por card**: Executar agora · Pausar/Retomar (oculto se `completed`) · Editar · Excluir · Detalhes.
- **Detalhes (expandir)**: instrução (`prompt`) + **histórico** das execuções (✓/✗, data, duração,
  nº de ferramentas, resumo). Tarefas `report` exibem link **"Ver relatório gerado"**
  (`/dashboard/relatorios-agendados?r=<reportId>`).
- **Estados**: carregando, vazio (com dica do `/schedule` no chat) e **acesso restrito** (403/401).

### 9.2 Catch-up automático
Ao montar, a página chama `POST /api/scheduled-tasks/run-due` **uma vez** (guard `ranDue`),
disparando as tarefas vencidas da clínica e recarregando a lista se algo foi processado.

### 9.3 Modal Criar/Editar (`TaskModal`, via `createPortal`)
- **Tipo de tarefa**: Ação | Relatório.
- **Título** e **instrução** (`prompt`) — placeholders mudam conforme o tipo.
- **Quando executar**: Uma vez | Intervalo | Diariamente | Semanalmente | Mensalmente.
  Campos condicionais: `datetime-local` (once) · minutos (interval) · horário (daily/weekly/monthly)
  · seletor de dias da semana (weekly) · dia do mês (monthly).
- **E-mail de notificação** (opcional).
- `buildSchedule()` monta o objeto `schedule`; validação mínima de título/instrução antes de salvar.
- Salvar → `POST` (novo) ou `PATCH` (edição).

---

## 10. Controle de Acesso (RBAC) + Multi-tenant — `access-control.js`

| Papel | Tarefas Agendadas | Escopo de clínica |
|---|---|---|
| `admin` | sim | apenas a própria `idclinica` |
| `rsa` | sim | todas as clínicas (ou `clinicaIds`) |
| `med` | **não** | — (apenas o chat) |
| demais | **não** | — |

- `requireScheduleAccess(request)` — resolve o usuário pela sessão `__session` e exige
  `canUseSchedules` (admin/rsa); lança `AccessError(401/403)`.
- `canAccessClinica(access, clinicaId)` — valida o escopo de cada recurso.
- `resolveCreateClinica(access, requested)` — trava a criação na clínica do usuário (admin)
  ou valida a solicitada (rsa).
- `normalizeClinicaId` — aceita `idclinica` como string **ou** referência de documento.
- As ferramentas MCP de agendamento só são expostas no chat para admin/rsa.

---

## 11. Ferramentas MCP (atalho pelo chat)

Registradas em `mcp.server.js`; permitem criar/gerir tarefas em linguagem natural
(ex.: `/schedule …` no chat). Ver também `MCP.md` §6.18.

| Tool | Descrição |
|---|---|
| `agendar_tarefa` | Cria a tarefa. Params: `titulo`, `prompt`, `tipo` (once/interval/daily/weekly/monthly), `tipoTarefa` (acao/relatorio), `horario`, `diasSemana`, `diaDoMes`, `intervaloMinutos`, `executarEm` (ISO ou `DD/MM/AAAA HH:MM`), `notificarEmail`. |
| `listar_tarefas_agendadas` | Lista status + próxima execução (filtro por `status`). |
| `pausar_retomar_tarefa` | `acao`: `pausar` → `paused`; `retomar` → `active`. |
| `cancelar_tarefa_agendada` | Exclui permanentemente pelo `id`. |

---

## 12. Robustez & Segurança (resumo)

| Camada | Medida |
|---|---|
| **Duplicidade** | Lock atômico (`claimDueTask`/`lockForManualRun`) em transação Firestore. |
| **Travamento** | `recoverStaleTasks` recupera órfãs (lock > 10 min); timeout de 4 min por execução. |
| **Cron** | `CRON_SECRET` obrigatório (fail-closed → 503); aceita Bearer do Vercel Cron. |
| **RBAC** | Toda rota passa por `requireScheduleAccess` (admin/rsa); `med` e demais bloqueados. |
| **Multi-tenant** | Queries e criação escopadas por `clinicaId`; PATCH não move de clínica. |
| **Índices** | Consultas usam igualdade/desigualdade simples + ordenação em memória → sem índice composto. |
| **Auditoria** | `auditLog` em create/run. |

---

## 13. Referências internas

- UI: `src/app/dashboard/tarefas-agendadas/page.jsx`
- API: `src/app/api/scheduled-tasks/**`, `src/app/api/cron/scheduler/route.js`
- Dados/lock: `src/core/modules/scheduled_tasks/scheduled_tasks.schema.js`
- Orquestração: `src/core/modules/scheduled_tasks/scheduled_tasks.service.js`
- Horários: `src/core/modules/scheduled_tasks/schedule.util.js`
- Agente: `src/lib/agent-runner.js` · MCP: `src/core/modules/mcp/mcp.server.js`
- Acesso: `src/lib/access-control.js`
- Relatórios: `src/lib/report-format.js`, `/dashboard/relatorios-agendados`
- Visão do agente/chat: `especificacao/docs/AgentAI.md`
