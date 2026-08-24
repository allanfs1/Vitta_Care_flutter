# 🧠 Agente IA Autônomo — Módulo de Absenteísmo & Gestão Preditiva

> **Objetivo**: Transformar o chat atual (assistente passivo que responde perguntas) em um **Agente de IA autônomo** que monitora, prevê, age e notifica — tudo sem intervenção humana — focado inicialmente no combate ao absenteísmo clínico (faltas).

---

## 1. Visão Geral da Feature

Hoje, o chat funciona em modo **reativo**: o administrador faz uma pergunta, o sistema busca dados via MCP, e retorna uma resposta. O agente proposto inverte esse paradigma para **proativo e autônomo**.

### De Chat para Agente: O Salto

| Aspecto             | Chat Atual (Passivo)                     | Agente IA (Autônomo)                              |
|---------------------|------------------------------------------|----------------------------------------------------|
| **Ativação**        | O humano inicia a conversa               | O agente age sozinho por cronograma/evento          |
| **Análise**         | Responde ao que é perguntado             | Analisa padrões sem ser solicitado                  |
| **Ação**            | Apenas exibe informação                  | Envia emails, WhatsApp, reagenda automaticamente    |
| **Aprendizado**     | Nenhum                                   | Ajusta modelos preditivos com base em histórico     |
| **Notificação**     | Não notifica                             | Push, email e painel de alertas em tempo real       |

---

## 2. Funcionalidades Detalhadas

### 2.1 🔮 Motor de Predição de Absenteísmo

O agente deve analisar o histórico de agendamentos (`tb_agendamentos`) e identificar padrões de falta usando um **score de risco por paciente**.

#### Requisitos Funcionais
- **RF-01**: Calcular um `riskScore` (0–100) para cada agendamento futuro baseado em:
  - Histórico de faltas do paciente (`status === "faltou"` em `tb_agendamentos`)
  - Dia da semana (ex.: segundas têm mais faltas)
  - Horário (ex.: consultas 7h–8h e 17h–18h têm maior taxa de falta)
  - Tempo entre agendamento e data da consulta (quanto maior, maior risco)
  - Clima previsto no dia (integração com API de clima — opcional V2)
  - Modalidade (Telemedicina vs Presencial)
- **RF-02**: Persistir o score no Firestore em `tb_absenteismo_scores` com os campos:
  ```
  {
    agendamentoId: string,
    pacienteId: string,
    medicoId: string,
    clinicaId: string,
    riskScore: number (0-100),
    riskLevel: "baixo" | "medio" | "alto" | "critico",
    factors: [ { name: string, weight: number, value: any } ],
    predictedAt: timestamp,
    outcome: "pendente" | "compareceu" | "faltou"
  }
  ```
- **RF-03**: Atualizar o `outcome` automaticamente após a data da consulta para retroalimentar o modelo.

#### Requisitos Não-Funcionais
- **RNF-01**: O cálculo deve rodar via **cron job** (Cloud Function ou scheduled task) toda madrugada (02:00) para os agendamentos dos próximos 7 dias.
- **RNF-02**: O cálculo não deve bloquear o sistema principal — deve rodar em background.

---

### 2.2 📡 Sistema de Ações Automáticas (Agent Loop)

O agente deve ter um **loop de decisão autônomo** que executa ações baseadas nos scores de risco.

#### Cadeia de Ações por Nível de Risco

```
┌──────────────┬─────────────────────────────────────────────────────────────────────┐
│ Nível        │ Ações Automáticas                                                   │
├──────────────┼─────────────────────────────────────────────────────────────────────┤
│ BAIXO (0-25) │ Nenhuma ação adicional. Lembrete padrão 24h antes.                  │
│ MEDIO (26-50)│ Lembrete reforçado 48h + 24h antes (Email + WhatsApp).              │
│              │ Incluir texto persuasivo personalizado no lembrete.                  │
│ ALTO (51-75) │ Tudo do MEDIO + Ligar para confirmar (flag para recepção).          │
│              │ Sugerir troca de horário via WhatsApp se paciente não confirmar.     │
│ CRÍTICO(76+) │ Tudo do ALTO + Ativar fila de espera (overbooking controlado).      │
│              │ Pré-agendar paciente da lista de espera no mesmo slot.              │
│              │ Notificar administrador no painel com alerta vermelho.               │
└──────────────┴─────────────────────────────────────────────────────────────────────┘
```

#### Requisitos Funcionais
- **RF-04**: Executar a cadeia de ações automaticamente via scheduled job (06:00 e 14:00 diariamente).
- **RF-05**: Cada ação executada deve ser registrada em `tb_agent_actions`:
  ```
  {
    id: auto,
    agendamentoId: string,
    actionType: "lembrete_email" | "lembrete_whatsapp" | "flag_ligacao" | "overbooking" | "notificacao_admin",
    riskLevel: string,
    riskScore: number,
    status: "executado" | "falhou" | "pendente",
    details: string,
    executedAt: timestamp
  }
  ```
- **RF-06**: O administrador pode ver todas as ações do agente no painel e pode **reverter** ou **pausar** o agente para um paciente específico.
- **RF-07**: O agente deve usar as ferramentas MCP existentes (`google_enviar_email`, `atualizar_status_agendamento`, `criar_agendamento`) para executar suas ações — não deve criar lógica duplicada.

---

### 2.3 📊 Dashboard de Absenteísmo (Painel Visual)

Uma nova página no dashboard (`/dashboard/absenteismo`) dedicada à visualização do absenteísmo.

#### Requisitos Funcionais
- **RF-08**: Exibir KPIs no topo:
  - Taxa de absenteísmo do mês atual (%)
  - Comparação com mês anterior (↑↓)
  - Total de faltas evitadas pelo agente (consultas que foram confirmadas após intervenção do agente)
  - Economia estimada (R$) baseada no valor médio das consultas perdidas
- **RF-09**: Gráfico de linha: evolução do absenteísmo nos últimos 12 meses.
- **RF-10**: Gráfico de barras: absenteísmo por dia da semana.
- **RF-11**: Gráfico de pizza: distribuição por nível de risco dos próximos 7 dias.
- **RF-12**: Tabela com os **Top 20 agendamentos de maior risco** dos próximos 7 dias, com:
  - Nome do paciente
  - Médico
  - Data/hora
  - Risk Score (barra visual de progresso colorida)
  - Ações já tomadas pelo agente (ícones)
  - Botão "Intervir Manualmente" (abre o chat com contexto pré-carregado)
- **RF-13**: Heatmap de faltas: mapa de calor por hora × dia da semana mostrando os horários mais problemáticos.

---

### 2.4 🔔 Sistema de Alertas em Tempo Real

#### Requisitos Funcionais
- **RF-14**: O agente deve emitir alertas push no dashboard quando:
  - Um paciente de risco CRÍTICO não confirmou a 12h da consulta
  - O agente falhou ao executar uma ação (ex.: email não enviado)
  - A taxa de absenteísmo da semana atual ultrapassou a média histórica em 20%+
- **RF-15**: Os alertas aparecem como badge no ícone do sino do header do dashboard e numa aba lateral.
- **RF-16**: Cada alerta é clicável e leva diretamente ao contexto (agendamento, paciente ou ação do agente).

---

### 2.5 🤖 Integração com o Chat Existente (Agent Mode)

O chat atual deve ganhar um **modo agente** que permite ao administrador conversar com o agente de absenteísmo em linguagem natural.

#### Requisitos Funcionais
- **RF-17**: Novas ferramentas MCP a serem criadas em `mcp.server.js`:
  - `calcular_risco_paciente(pacienteId)` — retorna o score e fatores de risco
  - `listar_agendamentos_risco_alto(dias)` — lista agendamentos com risco > 50 nos próximos X dias
  - `historico_absenteismo_paciente(pacienteId)` — retorna estatísticas de faltas
  - `simular_overbooking(medicoId, data)` — simula o impacto de overbooking em um slot
  - `taxa_absenteismo(periodo)` — retorna taxa global por período (semanal, mensal, trimestral)
  - `pausar_agente(pacienteId)` — suspende ações automáticas para um paciente
  - `retomar_agente(pacienteId)` — retoma as ações automáticas

- **RF-18**: Exemplos de interações esperadas no chat:
  ```
  Admin: "Quais pacientes têm maior risco de faltar amanhã?"
  Agente: [Usa listar_agendamentos_risco_alto(1)] → Responde com lista + gráfico

  Admin: "Ative overbooking para o Dr. Silva amanhã às 14h"
  Agente: [Usa simular_overbooking] → Mostra impacto → [Usa criar_agendamento] → Confirma

  Admin: "Por que a Maria falta tanto?"
  Agente: [Usa historico_absenteismo_paciente] → Responde com análise dos fatores
  ```

---

### 2.6 📋 Relatório Semanal Automatizado

#### Requisitos Funcionais
- **RF-19**: Todo domingo à noite (22:00), o agente gera automaticamente um relatório semanal contendo:
  - Resumo da semana: total de consultas, faltas, taxa de absenteísmo
  - Ações do agente: quantas intervenções realizou, quantas faltas evitou
  - Pacientes problemáticos: top 5 pacientes com maior taxa de falta acumulada
  - Recomendações: sugestões geradas pela IA (ex.: "considere alterar o horário das consultas de segunda 8h, a taxa de falta é 40%")
- **RF-20**: O relatório é salvo em `tb_relatorio_ia` com `tipoRelatorio: "semanal_absenteismo"`.
- **RF-21**: O relatório é enviado por email para o administrador usando `google_enviar_email`.

---

## 3. Arquitetura Técnica Proposta

```
src/
├── core/
│   └── modules/
│       └── absenteismo/
│           ├── absenteismo.schema.js        # Modelos Firestore (scores, actions)
│           ├── absenteismo.service.js        # Lógica de cálculo de risco
│           ├── absenteismo.agent.js          # Agent Loop (decisão + execução de ações)
│           ├── absenteismo.report.js         # Geração de relatórios automáticos
│           └── absenteismo.constants.js      # Pesos, thresholds, configurações
├── app/
│   ├── api/
│   │   └── absenteismo/
│   │       └── route.js                      # API endpoints (scores, dashboard data)
│   └── dashboard/
│       └── absenteismo/
│           └── page.jsx                      # Página do Dashboard de Absenteísmo
```

### Novas Coleções Firestore
| Coleção                    | Descrição                                    |
|----------------------------|----------------------------------------------|
| `tb_absenteismo_scores`    | Scores de risco por agendamento              |
| `tb_agent_actions`         | Log de todas as ações automáticas do agente  |
| `tb_agent_config`          | Configurações do agente (thresholds, ativo)  |

---

## 4. Priorização (Fases)

### Fase 1 — MVP (Sprint 1–2)
- [x] Motor de cálculo de risco (`absenteismo.service.js`)
- [x] Novas tools MCP para o chat
- [x] Dashboard básico com KPIs e tabela de risco

### Fase 2 — Automação (Sprint 3–4)
- [ ] Agent Loop com execução de ações automáticas
- [ ] Sistema de alertas push no dashboard
- [ ] Relatório semanal automatizado

### Fase 3 — Inteligência (Sprint 5+)
- [ ] Machine Learning: treinar modelo com dados históricos reais
- [ ] Integração com API de clima
- [ ] Overbooking inteligente com simulação de impacto financeiro
- [ ] A/B testing de mensagens de lembrete (qual texto reduz mais faltas?)

---

## 5. Métricas de Sucesso

| Métrica                           | Meta         |
|-----------------------------------|--------------|
| Redução na taxa de absenteísmo    | -30% em 90 dias |
| Taxa de confirmação após lembrete | > 75%        |
| Faltas evitadas pelo agente/mês   | > 50         |
| Economia estimada mensal (R$)     | > R$ 5.000   |
| Tempo médio de resposta do agente | < 2 segundos |

---

## 6. Dependências Existentes Aproveitadas

O agente reutiliza toda a infraestrutura já construída:
- **MCP Server** (`mcp.server.js`): 32 ferramentas já disponíveis para consulta e manipulação de dados
- **Azure DeepSeek V4**: modelo de linguagem para geração de relatórios e análise
- **Azure Cognitive Services**: para análise de documentos médicos anexados
- **Firebase Firestore**: banco de dados principal
- **Google Workspace**: Calendar, Gmail e Drive integrados
- **Recharts**: renderização de gráficos no chat e dashboard
- **Twilio/WhatsApp**: canal de comunicação com pacientes (credenciais já configuradas)
- **SendGrid SMTP**: envio de emails em larga escala (credenciais já configuradas)

---

## 7. Implementação Realizada — Chat, Agente, Tarefas Agendadas e Relatórios

> Esta seção documenta o que foi **efetivamente implementado** a partir desta especificação,
> incluindo a camada que torna o agente autônomo (Tarefas Agendadas) e os relatórios para decisão.
> Referência detalhada: [`docs/tarefas_agendadas.md`](tarefas_agendadas.md) e
> [`especificacao.md`](../especificacao.md) (seções 10–13).

### 7.1 Chat com IA (Agente em Streaming + MCP)

Página única `src/app/dashboard/chat/page.jsx` com dois modos (toggle no header): **Chat**
(conversa em streaming) e **Agentes** (orquestrador multi-agente). A coluna direita mostra o
status do sistema (modelos, MCP, SSE, Firebase) e, conforme o modo, anexos ou config dos agentes.

#### 7.1.1 Backend de streaming — `POST /api/chat/stream-chat`

- **Transporte:** SSE com eventos `token` (texto incremental), `thinking` (tool prestes a ser
  chamada, com `label`+`icon` amigáveis via `TOOL_META`), `tool_done` (resultado da tool, `ok`),
  `done` (resposta final + `chatId`) e `error`.
- **Cliente IA:** `src/lib/ai-client.js` — Azure DeepSeek **V4 Flash** (padrão) com **fallback
  automático para V4 Pro** em 429/5xx; retry com backoff exponencial respeitando `retry-after`.
  `complex: true` vai direto ao Pro. Quatro entradas: `createCompletion`, `createStreamingCompletion`,
  `createStreamingChat` (tool calls) e `getModelInfo`.
- **Loop de ferramentas:** até **6 rodadas** alternando geração ↔ execução de tools MCP, até a
  resposta final (`finish_reason: stop`). As tools rodam por um **MCP in-memory** (`InMemoryTransport`)
  contra `createMcpServer`.
- **Multi-tenant + RBAC:** `getUserAccess(request)` resolve a clínica do usuário logado
  (`createMcpServer({ defaultClinicaId })`, ID também injetado no system prompt) e o flag
  `canUseSchedules`; as tools de tarefa agendada (`agendar_tarefa`, `listar_tarefas_agendadas`,
  `pausar_retomar_tarefa`, `cancelar_tarefa_agendada`) só são expostas a `admin`/`rsa`.
- **Memória de contexto:** últimos **6 turnos** (máx. ~8 000 chars) carregados de `getChatHistory`.
- **System prompt** com regras obrigatórias por canal: e-mail (confirmação/lembrete/overbooking/
  relatório/livre/lote), WhatsApp (Z-API), tarefas agendadas e o contrato do bloco ` ```json-chart `.
- **Persistência:** a pergunta e a resposta final são gravadas via `sendMessage` (não bloqueia o stream).

#### 7.1.2 UI do Chat (modo conversa)

- **Visualização de tool calls:** cada ferramenta aparece como *chip* (ícone + label) que pisca
  enquanto executa e vira ✓/✗ ao concluir — o usuário vê o agente "pensando".
- **Markdown + gráficos:** respostas renderizadas com `react-markdown` + `remark-gfm`. Blocos
  ` ```json-chart ` viram gráficos **recharts** (bar/line/pie). Durante o streaming, JSON incompleto
  mostra "Gerando gráfico…" em vez de erro; `series` é derivada das chaves numéricas quando ausente.
- **Autocomplete inteligente:** ~10 categorias de sugestões (Agendamentos, Médicos, Pacientes,
  Riscos & IA, Overbooking, E-mails, Relatórios, WhatsApp, Tickets, Tarefas) com navegação por teclado.
- **Slash commands:** `/schedule` (aliases `/shendule`, `/agendar`, `/agenda`) e `/tarefas` —
  `/schedule …` reescreve o pedido para acionar `agendar_tarefa`. Reconhecidos no chat e no modo agentes.
- **Entrada por voz (STT):** microfone via Web Speech API (`SpeechRecognition`, pt-BR).
- **Anexos + OCR/extração:** upload de PDF/DOCX/XLSX/imagem → `POST /api/analyze` (Azure Document
  Intelligence, `prebuilt-read`) extrai o texto e o injeta como `[Contexto Azure]` na mensagem.
- **Controle de geração:** botão **parar** (AbortController), timeout de 90 s, mantém o texto parcial;
  auto-scroll inteligente (só acompanha o fim se o usuário já estava lá) + botão "ir ao fim"; copiar resposta.
- **Conversas:** histórico na sidebar (`/api/chat`), busca, "nova conversa".

#### 7.1.3 Alertas proativos

`GET /api/alerts` (poll a cada 60 s) varre o dia e devolve alertas `warning`/`critical` para a barra
do topo: consultas de alto risco hoje (`riskScore ≥ 0.7`), e-mails `failed` em `email_queue` e
overbookings nas últimas 24 h. Cada alerta é clicável e abre o tema no chat.

#### 7.1.4 Modo Agentes (orquestrador multi-agente)

- **Plano:** `POST /api/chat/plan` — o planner (DeepSeek **Pro**, `temperature 0.3`) decompõe o
  objetivo em **2–6 tarefas paralelas e independentes**, cada uma com `prompt` autossuficiente,
  ícone, cor e flag `complex`.
- **Execução paralela:** rodam em lotes de **4** simultâneos via `POST /api/chat` (não-streaming),
  com **timeout configurável (30–180 s)** e **auto-retry** (1×, opcional). Cada agente é um *card*
  com status `idle/running/done/error` e badge **Pro**.
- **Síntese final:** `POST /api/chat/stream` consolida os resultados em um relatório executivo
  (descobertas, pontos críticos, recomendações, gráfico opcional) **em streaming SSE**.
- **Persistência e export:** planos salvos em `tb_agent_plans` (`GET/POST/DELETE /api/agent-plans`),
  listados na sidebar; exportação por copiar, `.txt`, **PDF** (print do browser) e **e-mail**.

### 7.2 Tarefas Agendadas — o "Agent Loop" autônomo (realiza RF-04, RF-19..RF-21)

Concretiza o loop autônomo proposto: o administrador programa o agente em linguagem natural e ele
executa sozinho no horário marcado.

- **Coleção:** `tb_scheduled_tasks` — `{ titulo, prompt, schedule, kind, status, nextRunAt, lastRunAt, runCount, errorCount, notifyEmail, history[], clinicaId }`.
- **`kind`:** `action` (executa ação) | `report` (gera relatório com gráficos).
- **Recorrência:** `once`, `interval`, `daily`, `weekly`, `monthly` (fuso America/Sao_Paulo) — `src/core/modules/scheduled_tasks/schedule.util.js`.
- **Execução:** Vercel Cron `GET /api/cron/scheduler` (a cada 5 min) + catch-up no front-end
  `POST /api/scheduled-tasks/run-due`. Executor: `src/lib/agent-runner.js` (agente MCP não-streaming).
- **Página:** `/dashboard/tarefas-agendadas` (criar/editar/pausar/executar/excluir + histórico).

#### Novas ferramentas MCP (estende RF-17)
| Tool | Descrição |
|---|---|
| `agendar_tarefa` | Cria tarefa (`tipoTarefa`: `acao`/`relatorio`; aceita data BR `DD/MM/AAAA HH:MM`) |
| `listar_tarefas_agendadas` | Lista tarefas + próxima execução |
| `pausar_retomar_tarefa` | Pausa/retoma |
| `cancelar_tarefa_agendada` | Exclui |

#### Robustez (execução exatamente-uma-vez)
- `claimDueTask` — lock atômico em transação Firestore (`status: running`, `lockedAt`, avança `nextRunAt`);
  cron e catch-up nunca duplicam a mesma execução (evita e-mail/WhatsApp duplicado ao paciente).
- `finishRun` finaliza/libera o lock; `recordManualRun` registra "executar agora" sem mexer no agendamento.
- `recoverStaleTasks` recupera órfãs (lock > 10 min); timeout de 4 min por execução.

### 7.3 Relatórios para Decisão (realiza e generaliza RF-08..RF-13, RF-19..RF-21)

Tarefas do tipo `report` geram relatório com gráficos, salvam e enviam por e-mail.

- **Coleção:** `tb_scheduled_reports` — markdown completo + gráficos extraídos.
- **Pipeline:** agente produz markdown com `json-chart` → `extractCharts` (`src/lib/report-format.js`)
  → persistência → e-mail HTML (narrativa + tabelas dos gráficos + link para o painel).
- **Página:** `/dashboard/relatorios-agendados` renderiza markdown + gráficos reais
  (`src/components/ReportRenderer.jsx`). **API:** `GET /api/scheduled-reports`, `GET/DELETE /api/scheduled-reports/[id]`.

### 7.4 Controle de Acesso (RBAC) + Multi-tenant + Ambiente por Papel

Helper servidor `src/lib/access-control.js`; helper cliente `src/lib/roles.js`.

| Papel | Acesso ao sistema | Tarefas/Relatórios | Escopo de clínica |
|---|---|---|---|
| `admin` | sim | sim | apenas a própria `idclinica` |
| `rsa` | sim | sim | todas as clínicas (ou `clinicaIds`) |
| `med` | sim (**só Chat**) | **não** (e sem cron) | — |
| demais | **não** | não | — |

- `idclinica` (coleção `users`) normalizado (string ou referência de documento).
- **Gate app-wide** (`dashboard/layout.jsx`): papéis sem acesso são bloqueados; o `med` é
  redirecionado para `/dashboard/chat` e a Sidebar esconde itens de gestão (ambiente do médico).
- As tools de agendamento só são expostas no chat para `admin`/`rsa`.
- **Cron fail-closed:** `/api/cron/scheduler` bloqueia (503) sem `CRON_SECRET`.

### 7.5 Novas coleções (complementam a seção 3)
| Coleção | Descrição |
|---|---|
| `tb_scheduled_tasks` | Tarefas agendadas (ações e relatórios) |
| `tb_scheduled_reports` | Relatórios gerados (markdown + gráficos) |
| `tb_agent_plans` | Planos multi-agente salvos (tarefas, resultados, síntese) |

### 7.6 Índices Firestore
As consultas foram escritas para **não exigir índices compostos** (campos únicos + ordenação em
memória). Índices recomendados para escala estão em [`erro_indece.md`](../../erro_indece.md).
