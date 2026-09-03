# Tarefas Agendadas — Lógica e Especificação

Documentação da tela **`/tarefas-agendadas`** e de toda a lógica que a sustenta:
agendamento, execução autônoma do agente de I.A., lock contra duplicidade,
aprovação de rotinas propostas pela IA e geração de relatórios.

> **Implementação**: Flutter (`lib/features/tarefas_agendadas/`) + Cloud Function
> agendada (`functions/scheduledTasksCron.js`)
> **Fuso de referência**: `America/Sao_Paulo` (BRT, UTC-3 fixo)
> **Coleções**: `tb_scheduled_tasks` (tarefas) · `tb_relatorio_ia` +
> `tb_scheduled_reports` (saída de relatório) · `email_queue` (notificação)

---

## 0. Aviso de portabilidade

Até 2026-09-01 esta spec descrevia a implementação em **Next.js** do projeto
irmão `app_company`: rotas `/api/scheduled-tasks/**`, `vercel.json`, Vercel Cron
a cada 5 min, `access-control.js`, `agent-runner.js`. **Nada disso existe
aqui.**

| A spec antiga dizia | O que existe neste repositório |
|---|---|
| `/dashboard/tarefas-agendadas` (page.jsx) | rota `/tarefas-agendadas` → `tarefas_agendadas_screen.dart` |
| `src/app/api/scheduled-tasks/**` (REST) | **não existe** — o app fala direto com o Firestore |
| `scheduled_tasks.schema.js` | `scheduled_tasks_service.dart` |
| `schedule.util.js` | `schedule_util.dart` |
| `agent-runner.js` | `scheduled_tasks_runner.dart` |
| Vercel Cron `*/5 * * * *` | Firebase `onSchedule("*/15 * * * *")` |
| `CRON_SECRET` fail-closed | **não se aplica** — cron do Firebase não é HTTP |
| `DEFAULT_CLINICA = JuhdNt7NG3GYOFKOKOXP` | **removido em 2026-08-20 por ser furo de isolamento** (ver §3) |
| Matriz RBAC `admin`/`rsa`/`med` | **não implementada** (ver §10) |

---

## 1. Visão geral

A tela permite **programar o agente de I.A.** para executar instruções em
linguagem natural automaticamente — uma vez, em intervalo, ou de forma
recorrente (diária, semanal, mensal). Cada tarefa é de um de dois tipos:

| `kind` | Descrição |
|---|---|
| `action` | Executa uma **ação** (enviar e-mails/WhatsApp, atualizar status, etc.) e produz um resumo. |
| `report` | Gera um **relatório com gráficos**, salvo em `tb_relatorio_ia` (+ trilha em `tb_scheduled_reports`). |

Na hora marcada, o agente recebe o `prompt`, chama as ferramentas MCP
necessárias e devolve o resultado, que é registrado no histórico da tarefa.

### Fluxo de ponta a ponta

```
┌───────────────────────────┐   ┌──────────────────────┐   ┌─────────────────┐
│ Tela /tarefas-agendadas   │   │ Chat /ia             │   │ Vigia           │
│ (criar/editar/run/pausar) │   │ (tool agendar_tarefa)│   │ (propõe rotina) │
└─────────────┬─────────────┘   └──────────┬───────────┘   └────────┬────────┘
              │                            │                        │
              └────────────────┬───────────┘                        │
                               ▼                          criarSugestao()
                   ScheduledTasksService                   status: suggested
                   (CRUD + lock + nextRunAt)  ◄────────────────────┘
                               ▲
              ┌────────────────┴────────────────┐
              │ Disparadores                    │
              │ • scheduledTasksCron (*/15 min) │
              │ • Catch-up ao abrir a tela      │
              │ • "Executar agora"              │
              └────────────────┬────────────────┘
                               ▼
                   ScheduledTasksRunner  → MCP (75 tools) → DeepSeek
                               │
              ├── kind=action  → resumo + e-mail opcional (email_queue)
              └── kind=report  → tb_relatorio_ia + tb_scheduled_reports
```

---

## 2. Estrutura de arquivos

```
lib/features/tarefas_agendadas/
├── tarefas_agendadas_screen.dart   ← UI (lista, filtros, histórico)   457 linhas
├── scheduled_tasks_service.dart    ← dados + lock + nextRunAt          394
├── schedule_util.dart              ← cálculo de horários (BRT)         238
├── scheduled_task.dart             ← modelo ScheduledTask / RunRecord  202
├── scheduled_tasks_runner.dart     ← executor (agente + MCP)           164
└── widgets/
    ├── card_sugestao_ia.dart       ← UI de aprovação da proposta       434
    └── task_modal.dart             ← criar/editar                      320

functions/
├── scheduledTasksCron.js           ← executor no servidor (*/15 min)
└── lib/
    ├── costGuards.js               ← makeReadMeter (circuit breaker)
    └── dataAccess.js               ← acesso escopado por tenant
```

---

## 3. Modelo de dados — `tb_scheduled_tasks`

```dart
{
  titulo: String,
  descricao: String,
  prompt: String,                  // instrução em linguagem natural
  kind: 'action' | 'report',
  schedule: {
    type: 'once' | 'interval' | 'daily' | 'weekly' | 'monthly',
    time?: 'HH:MM',                // daily/weekly/monthly (BRT)
    weekdays?: List<int>,          // weekly: 0=Dom .. 6=Sáb
    dayOfMonth?: int,              // monthly: 1-31 (ajustado p/ meses curtos)
    intervalMinutes?: int,         // interval: >= 1
    runAt?: Timestamp              // once (UTC)
  },
  status: 'suggested' | 'rejected' // proposta da IA (ver §3.1)
        | 'active' | 'paused' | 'running' | 'completed' | 'error',
  nextRunAt: Timestamp?,           // null = encerrada ou proposta
  lastRunAt: Timestamp?,
  lockedAt:  Timestamp?,           // lock de execução (claim / manual)
  runCount: int,
  errorCount: int,
  maxRuns: int?,                   // encerra após N execuções
  endAt:   Timestamp?,             // encerra após esta data
  notifyEmail: String?,
  history: [                       // últimas 20 execuções (mais recente primeiro)
    { runAt, ok, summary, toolsUsed, durationMs, reportId }
  ],
  clinicaId: String,               // multi-tenant

  // ── Proposta da IA (só quando status == 'suggested' | 'rejected') ──
  origem: 'humano' | 'ia',
  problemaDetectado: String,       // o que a IA observou, com número
  impactoEstimado: String,         // ganho esperado, em linguagem de gestor
  evidencias: List<String>,        // fatos que sustentam, com fonte
  confianca: double,               // 0..1, declarada pela IA
  sugeridaEm: Timestamp?,
  decididaEm: Timestamp?,
  decididaPor: String?,            // quem aprovou/recusou
  motivoRecusa: String?,           // alimenta o ciclo seguinte do Vigia
  notaCerebroId: String?,          // nota do Cérebro que originou/registrou
  relatorioId: String?             // relatório que acompanhou a proposta
}
```

Constantes (`scheduled_tasks_service.dart`):

| Símbolo | Valor | Função |
|---|---|---|
| `_collection` | `tb_scheduled_tasks` | Coleção Firestore |
| `_historyLimit` | `20` | Máx. de execuções no histórico |
| `_lockTtl` | `10 min` | Tempo após o qual um lock é considerado órfão |

> **Não existe `DEFAULT_CLINICA`.** A versão anterior desta spec documentava
> `DEFAULT_CLINICA = JuhdNt7NG3GYOFKOKOXP` como constante viva — exatamente o
> fallback de clínica que `MCP.md` §3 registra como **removido em 2026-08-20
> por ser furo de isolamento multi-tenant**. Duas specs da mesma pasta se
> contradiziam, e a errada nomeava o valor a reintroduzir. A clínica vem
> sempre de `tarefasClinicaIdProvider` (que resolve por
> `clinicaResolvidaProvider`); sem clínica, nada é lido nem gravado.

---

### 3.1 Rotinas propostas pela IA — `suggested` / `rejected`

O **Vigia** ([`VIGIA.md`](VIGIA.md)) propõe rotinas de prevenção uma vez por
dia. Uma proposta é gravada nesta mesma coleção, como uma tarefa que **existe
mas não roda**.

```
  IA propõe            humano decide              consequência
  ─────────            ─────────────              ────────────
  status: suggested ──▶ Aprovar  ──▶ status: active  + nextRunAt calculado agora
                    └─▶ Recusar  ──▶ status: rejected + motivoRecusa gravado
```

**A garantia: uma rotina proposta pela IA nunca executa sozinha.** São três
travas independentes, e nenhuma depende da UI se comportar:

| # | Trava | Onde |
|---|---|---|
| 1 | A sugestão nasce **sem `nextRunAt`** — não há horário para vencer | `criarSugestao` · `vigiaCron.js › gravarSugestoes` |
| 2 | `getDue` e `claimDue` só aceitam `status == 'active'` | `scheduled_tasks_service.dart` |
| 3 | O cron do servidor filtra o mesmo status | `functions/scheduledTasksCron.js:118,132` |

`setStatus` foi **blindado** para recusar promover uma sugestão: ativar só por
`aprovar()`, que é transacional, calcula o primeiro `nextRunAt` no momento da
decisão e registra `decididaPor`/`decididaEm`. Sem isso haveria um caminho
lateral para ligar uma automação sem decisão humana rastreada.

**Por que `rejected` não é `delete`.** Guardar a recusa com o motivo é o que
impede o Vigia de repropor amanhã o que o gestor já explicou por que não
serve — o ciclo seguinte lê essa lista. Uma recusa apagada viraria uma
proposta repetida.

**Deduplicação.** `chaveDedupe` = `kind` + título normalizado (sem prefixo de
origem entre colchetes, sem pontuação, minúsculo). Cliente Dart e cron Node
precisam gerar a **mesma** chave; `functions/test/vigiaCron.test.js` fixa um
valor literal para a divergência quebrar o build antes de virar sugestão
duplicada em produção.

Coberto por `test/features/vigia_sugestoes_test.dart` (13 testes).

---

## 4. Cálculo de agendamento — `schedule_util.dart`

Funções puras, sem dependências externas. Fuso fixo **BRT (UTC-3)** — seguro
pois o Brasil não tem horário de verão desde 2019. Todo `DateTime` persistido é
UTC; a conversão de/para "hora de parede" BRT acontece só aqui.

| Função | Descrição |
|---|---|
| `computeNextRun(schedule, from)` | Próxima execução (UTC) após `from`; `null` se não houver. Itera dia-a-dia no calendário BRT até achar o 1º candidato válido. |
| `describeSchedule(schedule)` | Descrição legível em pt-BR (ex.: "Todos os dias às 08:00", "A cada 2h"). |
| `parseFlexibleDate(input)` | Converte data flexível → UTC. Aceita ISO (com/sem TZ) e `DD/MM/AAAA HH:MM`. Sem TZ ⇒ interpretado como BRT. |
| `validateSchedule(schedule)` | Devolve `String?` com a mensagem de erro (`null` = válido). **Não lança** — a UI usa o retorno direto. |

**Regras de recorrência:**
- `once` — roda uma vez em `runAt`; depois `nextRunAt = null`.
- `interval` — a cada `intervalMinutes` (mín. 1) a partir de agora.
- `daily` — todo dia às `time`.
- `weekly` — nos `weekdays` (0=Dom..6=Sáb) às `time`.
- `monthly` — no `dayOfMonth` (1-31, ajustado a meses curtos) às `time`.

**Término automático** (`_advance`, `scheduled_tasks_service.dart:354`): a
próxima execução vira `null` quando o tipo é `once`, quando
`runCount + 1 >= maxRuns`, ou quando a próxima data ultrapassa `endAt`. Nesse
caso o status final vira `completed`.

---

## 5. Camada de dados — `ScheduledTasksService`

| Método | Descrição |
|---|---|
| `watch(clinicaId)` | Stream das tarefas da clínica (igualdade simples + ordenação em memória → **sem índice composto**). |
| `create({...})` | Valida, calcula o 1º `nextRunAt` e grava (status `active`). |
| `update(id, patch)` | Edita campos; se `schedule` mudar, recalcula `nextRunAt`. |
| `setStatus(id, status)` | Pausa/retoma. **Recusa promover `suggested` → `active`** (§3.1). |
| `delete(id)` | Exclui. |
| `getDue(clinicaId, {limit})` | Vencidas (`nextRunAt <= now`) e `active` (filtro de status em memória). |
| `criarSugestao({...})` | Proposta da IA: status `suggested`, **sem** `nextRunAt`, com evidências e confiança. |
| `aprovar(id, {por})` | **Transação**: valida que está `suggested`, calcula o 1º `nextRunAt` e ativa. Único caminho que liga a execução. |
| `recusar(id, {motivo, por})` | Marca `rejected` e guarda o motivo para o Vigia não repropor. |
| `paraDeduplicar(clinicaId)` | Todas as tarefas da clínica (inclusive recusadas) — alimenta a dedupe do ciclo. |

### 5.1 Execução exatamente-uma-vez (lock atômico)

O cron e o catch-up do app podem rodar simultaneamente — o lock garante que a
**mesma ocorrência nunca dispare duas vezes** (evita e-mail/WhatsApp duplicado
ao paciente).

| Método | Descrição |
|---|---|
| `claimDue(id)` | **Transação Firestore**: se `active`, sem lock vivo e vencida → marca `status: running`, grava `lockedAt` e **já avança** `nextRunAt`. Retorna a tarefa ou `null` se não ganhou o lock. |
| `finishRun(id, record)` | Grava histórico/contadores, define status final (`active` se há próxima, senão `completed`) e libera o lock. |
| `lockForManualRun(id)` | Lock para "executar agora" (não roda se já houver execução em andamento). |
| `recordManualRun(id, record)` | Registra execução manual **sem** mexer em `nextRunAt`/`status`. |
| `recoverStale(clinicaId)` | Recupera órfãs presas em `running` com lock > 10 min (volta a `active`/`completed`, incrementa `errorCount`). |

> O lock é o que torna seguro ter **dois disparadores** (app e cron). Sem ele,
> abrir a tela às 08:00 enquanto o cron roda dispararia o mesmo lembrete duas
> vezes para o mesmo paciente.

---

## 6. Executor — `ScheduledTasksRunner`

`lib/features/tarefas_agendadas/scheduled_tasks_runner.dart`

| Método | Descrição |
|---|---|
| `runDue({force})` | Catch-up: recupera órfãs → busca vencidas (máx 10) → `claimDue` por candidato → executa quem ganhou o lock. Roda **uma vez por sessão de tela** (guard `_catchUpRan`). |
| `runNow(task)` | "Executar agora": lock manual → executa → `recordManualRun` (sem alterar o agendamento). |
| `_execute(task, clinicaId)` *(interno)* | Roda o agente com timeout de **4 min**; monta o `RunRecord`. |

**System prompts** (constantes no runner):
- `_actionSystem` — `kind=action`: executa de ponta a ponta, **nunca pede
  confirmação**, resume os números obtidos, usa nomes legíveis (nunca IDs).
- `_reportSystem` — `kind=report`: Markdown (Resumo Executivo, tabelas,
  Recomendações) com **1–4 gráficos** em blocos `json-chart` (bar/line/pie).

**Saída de `kind=report`** — grava nos dois lugares, de propósito:
1. `tb_relatorio_ia` — a coleção que a tela `/relatorios` lê. Antes o resultado
   ia só para `tb_scheduled_reports`, então um relatório produzido por uma
   rotina aprovada **não aparecia para quem aprovou a rotina**. O ciclo não
   fechava.
2. `tb_scheduled_reports` (mesmo id) — trilha por tarefa, alimenta o histórico
   de execuções e o link "Ver relatório gerado".

**Saída de `kind=action`** com `notifyEmail` preenchido: enfileira em
`email_queue` (`tipo: 'tarefa'`, `status: 'queued'`).

**Falha nunca propaga para a UI**: `runDue` engole exceções; `_execute` devolve
um `RunRecord` com `ok: false` e o erro no `summary`.

---

## 7. O cron no servidor — `functions/scheduledTasksCron.js`

```js
exports.scheduledTasksCron = onSchedule({
  schedule: "*/15 * * * *",          // §11 hotfix: era */5
  timeZone: "America/Sao_Paulo",
  region: "us-central1",
  secrets: [AZURE_AI_KEY, SENDGRID_API_KEY],
  timeoutSeconds: 540,
  memory: "512MiB",
}, async () => { /* recoverStale → getDue → claimDue → executeTask */ });
```

**Por que dois lados.** O app cobre o uso normal (alguém abre a tela); o cron
garante que uma tarefa vença mesmo com o app fechado. O lock (§5.1) impede
execução dupla.

**A cadência é decisão de custo.** `*/5` → `*/15` corta o multiplicador do cron
de 288 para 96 execuções/dia sem mudar a lógica das tarefas
(`CUSTO.md` §2.1 e §11). O preço é latência: uma tarefa marcada para 08:00 pode
rodar até 08:14.

### 7.1 Guardas de custo (só no lado servidor)

| Constante | Valor | Papel |
|---|---|---|
| `MAX_TASKS_PER_RUN` | `10` | Teto de tarefas por execução do cron |
| `READ_BUDGET` | `1500` | Circuit breaker de leituras (`makeReadMeter`) — estoura com `READ_BUDGET_EXCEEDED` e aborta |
| `AGENDAMENTOS_QUERY_LIMIT` | `500` | Paginação das queries de agendamento |
| `HISTORY_WINDOW_DAYS` | `180` | Janela do histórico usada no cálculo de risco |
| `TENANT_FIELDS` | `["idclinica", "idClinica"]` | Dupla query de tenant (`CUSTO.md` §6.6, ainda não unificada) |

> ⚠️ **O lado Dart não tem nenhuma dessas guardas.** `ScheduledTasksRunner`
> chama `server.callTool` sem medidor de leituras e sem circuit breaker — o
> único limite é o timeout de 4 min e as 6 rodadas do loop do agente. Uma
> tarefa mal escrita (`consultar_colecao` sem filtro, por exemplo) roda no
> cliente sem teto. Registrado em `ATENCAO.md`.

Testes: `functions/test/costGuards.test.js`, `functions/test/dataAccess.test.js`.

---

## 8. UI — `tarefas_agendadas_screen.dart`

### 8.1 Lista de tarefas
- **Header**: título + contador de ativas + botão **Nova tarefa**.
- **Card por tarefa**: ícone/cor por status, badge de status, badge
  **Relatório** (se `kind == 'report'`), rótulo do agendamento
  (`describeSchedule`), próxima/última execução, `runCount` e nº de erros.
- **Ações por card**: Executar agora · Pausar/Retomar (oculto se `completed`) ·
  Editar · Excluir · Detalhes.
- **Detalhes (expandir)**: instrução (`prompt`) + **histórico** das execuções
  (✓/✗, data, duração, nº de ferramentas, resumo). Tarefas `report` exibem link
  para o relatório gerado.

### 8.2 Cards de sugestão da IA — `card_sugestao_ia.dart`
Propostas (`status: 'suggested'`) aparecem numa seção própria, com o
`problemaDetectado`, `impactoEstimado`, as `evidencias` e a `confianca`.

- **Aprovar** → `aprovar()` (transacional, calcula `nextRunAt`).
- **Recusar** → **exige o motivo**. Não é burocracia: a lista de recusadas com
  motivos entra no prompt do ciclo seguinte do Vigia. É o que transforma uma
  recusa em aprendizado em vez de atrito repetido.

### 8.3 Catch-up automático
Ao montar, a tela chama `runDue()` **uma vez** (guard `_catchUpRan`),
disparando as tarefas vencidas da clínica. O lock evita duplicar com o cron.

### 8.4 Modal criar/editar — `task_modal.dart`
- **Tipo**: Ação | Relatório.
- **Título** e **instrução** (`prompt`) — placeholders mudam conforme o tipo.
- **Quando executar**: Uma vez | Intervalo | Diariamente | Semanalmente |
  Mensalmente, com campos condicionais (data/hora, minutos, horário, seletor de
  dias da semana, dia do mês).
- **E-mail de notificação** (opcional).
- Validação por `validateSchedule` antes de salvar.

---

## 9. Ferramentas MCP (atalho pelo chat)

Registradas em `dados_tools.dart`; permitem criar/gerir tarefas em linguagem
natural pelo chat `/ia`. Ver [`MCP.md`](MCP.md) §6.18.

| Tool | Descrição |
|---|---|
| `agendar_tarefa` | Cria a tarefa. Params: `titulo`, `prompt`, `tipo` (once/interval/daily/weekly/monthly), `tipoTarefa` (acao/relatorio), `horario`, `diasSemana`, `diaDoMes`, `intervaloMinutos`, `executarEm` (ISO ou `DD/MM/AAAA HH:MM`), `notificarEmail`. |
| `listar_tarefas_agendadas` | Lista status + próxima execução (filtro por `status`). |
| `pausar_retomar_tarefa` | `pausar` → `paused`; `retomar` → `active`. |
| `cancelar_tarefa_agendada` | Exclui permanentemente pelo `id`. |

> `agendar_tarefa` cria com `status: 'active'` — é ação **humana** (o gestor
> pediu no chat), não proposta da IA. O caminho `suggested` é exclusivo do
> Vigia. A distinção importa: confundir os dois transformaria "pedi ao agente
> que agendasse" em "o agente decidiu agendar".

---

## 10. Controle de acesso — o que existe e o que não existe

| Camada | Situação |
|---|---|
| **Multi-tenant** | ✅ Toda query escopada por `clinicaId` (`tarefasClinicaIdProvider`); o cron usa `TENANT_FIELDS` |
| **Aprovação humana** | ✅ Três travas + `setStatus` blindado (§3.1) |
| **Lock de execução** | ✅ Transacional (§5.1) |
| **RBAC por papel** | ❌ **não implementado** |

> **RBAC — divergência corrigida em 2026-09-01.** A versão anterior desta spec
> documentava `requireScheduleAccess`, `canAccessClinica`,
> `resolveCreateClinica` e uma matriz `admin`/`rsa`/`med` — tudo do projeto
> Next.js. No app Flutter **não há gate de papel**: `AppUser.roles` só alimenta
> `roleLabel` (rótulo de exibição). Qualquer usuário logado pode abrir
> `/tarefas-agendadas`, criar tarefas, aprovar sugestões da IA e usar
> `agendar_tarefa` no chat.
>
> Isso é risco aberto em [`ATENCAO.md`](ATENCAO.md) — a aprovação humana
> impede a IA de agir sozinha, mas não distingue *qual* humano aprova.

---

## 11. Robustez (resumo)

| Camada | Medida |
|---|---|
| **Duplicidade** | Lock atômico (`claimDue`/`lockForManualRun`) em transação Firestore |
| **Travamento** | `recoverStale` recupera órfãs (lock > 10 min); timeout de 4 min por execução |
| **Automação sem aprovação** | 3 travas + `setStatus` blindado; 13 testes |
| **Multi-tenant** | Queries e criação escopadas por `clinicaId` |
| **Índices** | Igualdade simples + ordenação em memória → sem índice composto |
| **Custo (servidor)** | `READ_BUDGET` 1500 + `MAX_TASKS_PER_RUN` 10 + cadência `*/15` |
| **Custo (cliente)** | ❌ sem medidor — ver §7.1 |

---

## 12. Referências internas

| Assunto | Arquivo |
|---|---|
| UI | `lib/features/tarefas_agendadas/tarefas_agendadas_screen.dart` |
| Dados e lock | `lib/features/tarefas_agendadas/scheduled_tasks_service.dart` |
| Horários | `lib/features/tarefas_agendadas/schedule_util.dart` |
| Executor | `lib/features/tarefas_agendadas/scheduled_tasks_runner.dart` |
| Cron | `functions/scheduledTasksCron.js` |
| Ferramentas do agente | [`MCP.md`](MCP.md) |
| Ciclo que propõe rotinas | [`VIGIA.md`](VIGIA.md) |
| Deploy do cron | [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) |
| Orçamento de leituras | [`CUSTO.md`](CUSTO.md) §2.1, §6.8, §11 |
| Riscos abertos | [`ATENCAO.md`](ATENCAO.md) |
