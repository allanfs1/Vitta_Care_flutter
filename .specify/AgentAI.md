# 🧠 Plataforma de I.A. Médica — Especificação

Especificação da plataforma de I.A. do Vitta: o que o agente faz, o que ele
**não pode** fazer sozinho, e onde cada peça vive.

> **Telas**: `/ia` (hub) · `/cerebro` · `/evidencias` · `/tarefas-agendadas` · `/relatorios`
> **Código**: `lib/features/ia/` · `lib/core/modules/mcp/` · `functions/`
> **Modelo**: DeepSeek V4 (Azure AI Foundry), OpenAI-compatível
> **Ferramentas**: 79 (MCP) — ver [`MCP.md`](MCP.md)

---

## 0. Como ler este documento

Esta spec nasceu como **proposta** de um agente autônomo de absenteísmo, com
requisitos numerados (RF-01…RF-21). Boa parte virou código; outra parte não, e
uma terceira virou coisa diferente do que estava escrito.

Para não repetir o erro que já custou caro nesta pasta — uma spec descrevendo o
sistema errado, e alguém "consertando" o código para bater com ela — cada
requisito abaixo carrega um **estado verificado contra o código em
2026-09-01**:

| Marca | Significado |
|---|---|
| ✅ | Implementado e verificável no código |
| 🟡 | Implementado de forma diferente da proposta original |
| ⬜ | Não implementado — continua sendo proposta |
| ❌ | Descartado ou substituído |

As seções §1–§2 são a **proposta original com estado verificado**. As §3–§6
descrevem o que **existe hoje**. Se as duas divergirem, §3+ é a verdade.

> **Portabilidade.** A versão anterior desta spec descrevia rotas Next.js
> (`/api/chat/stream-chat`, `src/lib/ai-client.js`, `/dashboard/chat`) do
> projeto irmão `app_company`. **Nada disso existe aqui** — o Vitta é Flutter.
> Ver §3.

---

## 1. Visão geral da feature

O chat começou **reativo**: o gestor pergunta, o sistema busca via MCP e
responde. A plataforma atual mantém esse modo e acrescenta dois proativos —
o **Vigia** (ciclo diário que analisa e propõe) e as **tarefas agendadas**
(rotinas que executam sozinhas depois de aprovadas).

| Aspecto | Chat (passivo) | Agente (autônomo) |
|---|---|---|
| **Ativação** | O humano inicia | Cronograma / boot do app |
| **Análise** | Responde ao perguntado | Analisa sem ser solicitado |
| **Ação** | Exibe informação | Envia e-mail/WhatsApp, agenda, escreve no Cérebro |
| **Aprendizado** | Nenhum | Recusas com motivo voltam ao contexto do ciclo seguinte |
| **Notificação** | Não notifica | Feed de notificações + alertas na `/ia` |

> ⚠️ **"Autônomo" tem limite explícito.** O agente decide *o que sugerir*;
> ele nunca decide *ligar uma automação*. Ver §2.2 e [`VIGIA.md`](VIGIA.md) §2.

---

## 2. Requisitos — proposta e estado

### 2.1 🔮 Motor de predição de absenteísmo

- **RF-01** ✅ Calcular `riskScore` (0–100) por agendamento, a partir de
  histórico de faltas, dia da semana, horário, antecedência e modalidade.
  *Onde:* `pacientes_risco_tools.dart` (`calcular_risco_paciente`),
  `functions/lib/costGuards.js › quickScore/faltaRatios`.
  *Divergência:* clima (previsto como opcional V2) ⬜ não foi integrado.
- **RF-02** 🟡 Persistir o score. **A coleção não é `tb_absenteismo_scores`** —
  a base de produção usa `dashboard_risco` e `tb_faltas_data`, que já existiam.
  O schema proposto (`factors[]`, `predictedAt`, `outcome`) não foi adotado.
- **RF-03** ⬜ Atualizar `outcome` após a consulta para retroalimentar o
  modelo. **Não existe** — sem isso não há laço de aprendizado supervisionado,
  e o score permanece heurístico (pesos fixos), não treinado.
- **RNF-01** 🟡 Rodar em cron de madrugada. Roda no `scheduledTasksCron`
  (`*/15 * * * *`), sob demanda de tarefa agendada — não há job dedicado às
  02:00.
- **RNF-02** ✅ Não bloqueia o app: cálculo em Cloud Function ou em tool MCP
  assíncrona.

### 2.2 📡 Ações automáticas (agent loop)

Cadeia proposta por nível de risco:

| Nível | Ações propostas | Estado |
|---|---|---|
| BAIXO (0–25) | Lembrete padrão 24 h antes | ✅ via tarefa agendada |
| MÉDIO (26–50) | Lembrete reforçado 48 h + 24 h, texto persuasivo | ✅ via tarefa agendada |
| ALTO (51–75) | + flag de ligação para a recepção | 🟡 o flag existe no dado; a fila da recepção não persiste (`ATENCAO.md`) |
| CRÍTICO (76+) | + lista de espera / overbooking + alerta no painel | ✅ `lista_espera_*`, `overbooking_*`, alertas na `/ia` |

- **RF-04** 🟡 Execução por job agendado. **Não são 06:00 e 14:00 fixos** — o
  gestor define o horário ao criar a rotina; o cron varre a cada 15 min.
- **RF-05** 🟡 Registrar cada ação. **A coleção não é `tb_agent_actions`** — o
  registro vive no `history[]` da própria tarefa (`RunRecord`: `runAt`, `ok`,
  `summary`, `toolsUsed`, `durationMs`, `reportId`), limitado a 20 execuções.
  *Consequência real:* não há trilha consultável de "todas as ações do agente
  no mês" — só as últimas 20 por tarefa.
- **RF-06** 🟡 Ver e reverter/pausar. Pausar ✅ (`pausar_retomar_tarefa`,
  `pausar_agente` por paciente). **Reverter** ⬜ não existe: um e-mail enviado
  não é desfeito.
- **RF-07** ✅ Usar as ferramentas MCP existentes, sem lógica duplicada.
  Cumprido: o runner só chama `McpServer.callTool`.

> **A garantia que substituiu a autonomia total.** A proposta original previa o
> agente agindo sozinho. O que foi implementado é mais estrito: rotinas
> propostas pela IA nascem `suggested` e **três travas independentes** impedem
> que executem sem aprovação humana. Ver [`VIGIA.md`](VIGIA.md) §2 e
> [`TAREFAS_AGENDADAS.md`](TAREFAS_AGENDADAS.md) §3.1. Isso não é uma
> limitação pendente de remoção — é a decisão de produto.

### 2.3 📊 Dashboard de absenteísmo

- **RF-08…RF-13** 🟡 Existem como módulo próprio (`/absenteismo`,
  `features/absenteismo/`), não como `/dashboard/absenteismo`. KPIs, série
  temporal e tabela de risco ✅. **Heatmap hora × dia (RF-13)** ⬜ e
  **"faltas evitadas pelo agente" / economia estimada (RF-08)** ⬜ dependem de
  RF-03 (medir o desfecho), que não existe — sem ele o número seria inventado.
- **RF-12** 🟡 A tabela de maior risco existe; o botão "Intervir manualmente"
  que abre o chat com contexto pré-carregado ⬜ não foi feito.

### 2.4 🔔 Alertas em tempo real

- **RF-14** 🟡 `iaAlertsProvider` varre a cada 60 s e emite alertas
  `warning`/`critical`. **Cobre** e-mails com falha em `email_queue` e
  overbookings nas últimas 24 h. **Não cobre** os dois outros gatilhos
  propostos: paciente crítico sem confirmação a 12 h ⬜, e taxa semanal 20 %
  acima da média histórica ⬜.
- **RF-15** 🟡 Aparecem como chips na barra do topo da `/ia` — não como badge
  no sino do header global.
- **RF-16** ✅ Cada alerta é clicável e abre o tema no chat (campo `prompt`).

### 2.5 🤖 Agent mode no chat

- **RF-17** ✅ Todas as sete ferramentas propostas existem, e o catálogo cresceu
  para 75. Ver [`MCP.md`](MCP.md) §6.
- **RF-18** ✅ As interações de exemplo funcionam — o loop de ferramentas
  (até 6 rodadas) encadeia consulta → simulação → ação.

### 2.6 📋 Relatório semanal automatizado

- **RF-19** 🟡 Existe como **capacidade**, não como rotina fixa de domingo
  22:00: qualquer tarefa `kind: report` com `schedule` semanal produz isso. O
  Vigia gera um relatório **diário** em `tb_relatorio_ia`.
- **RF-20** 🟡 Salvo em `tb_relatorio_ia` ✅, mas o `tipoRelatorio` gravado é
  `ia`/`agendado`, não `semanal_absenteismo`.
- **RF-21** 🟡 Envio por e-mail: enfileirado em `email_queue` quando
  `notifyEmail` está preenchido — via `emailProxy`/SendGrid, não
  `google_enviar_email`.

---

## 3. Arquitetura real

```
lib/
├── core/modules/mcp/              ← 79 ferramentas (MCP.md)
│   ├── mcp_server.dart
│   ├── mcp_tool.dart              ← McpContext: isolamento multi-tenant
│   └── tools/*.dart
└── features/ia/
    ├── ia_screen.dart             ← hub /ia (3 colunas responsivas)
    ├── agent/
    │   ├── ai_agent_service.dart  ← loop de ferramentas + planner
    │   ├── agent_controller.dart  ← estado do chat
    │   ├── agent_orchestrator.dart← modo Agentes (multi-agente)
    │   ├── agent_plans_service.dart
    │   ├── ia_chats_service.dart  ← histórico (tb_ia_chats)
    │   ├── ia_alerts_provider.dart← alertas proativos (60 s)
    │   ├── document_service.dart  ← anexos → analyzeDocument
    │   ├── voice_input_service.dart ← STT pt_BR
    │   └── ai_export_service.dart ← exportar conversa/plano
    ├── vigia/                     ← ciclo diário (VIGIA.md)
    └── widgets/                   ← 14 widgets da /ia

functions/
├── chatProxy.js          ← proxy do modelo (guarda a AZURE_AI_KEY)
├── analyzeDocument.js    ← Azure Document Intelligence
├── anthropicProxy.js     ← ⚠️ publicado, mas nenhum código Dart o chama
├── emailProxy.js         ← SendGrid
├── whatsappProxy.js      ← Z-API
├── scheduledTasksCron.js ← executor das rotinas (*/15 min)
└── vigiaCron.js          ← ciclo diário no servidor (06:00 BRT)
```

### Coleções Firestore

| Coleção | Papel |
|---|---|
| `tb_ia_chats` | Histórico de conversas do chat |
| `tb_agent_plans` | Planos do modo Agentes (tarefas, resultados, síntese) |
| `tb_scheduled_tasks` | Rotinas — incluindo as propostas pela IA |
| `tb_relatorio_ia` | Relatórios (lidos por `/relatorios`) |
| `tb_scheduled_reports` | Trilha por tarefa do relatório gerado |
| `tb_vigia_ciclos` | Auditoria do ciclo diário + trava contra ciclo duplo |
| `tb_cerebro_notas` / `tb_cerebro_eventos` | Memória do agente + auditoria de escrita |
| `dashboard_risco` / `tb_faltas_data` | Scores de risco e faltas |
| `email_queue` / `email_logs` | Fila e log de e-mails |

> **Coleções propostas que nunca existiram:** `tb_absenteismo_scores`,
> `tb_agent_actions`, `tb_agent_config`. Não as crie sem decidir antes o que
> fazer com `dashboard_risco` e `history[]`, que já ocupam esse espaço.

---

## 4. Superfícies da plataforma

### 4.1 Hub `/ia` — `ia_screen.dart`

Layout de três colunas, responsivo (desktop ≥ 1024 px; tablet ≥ 768 px; abaixo
disso as laterais viram `Drawer`):

| Coluna | Conteúdo |
|---|---|
| Esquerda (`ai_dashboard_left_sidebar`) | Busca, nova conversa, histórico (`tb_ia_chats`), planos salvos (`tb_agent_plans`) |
| Centro (`ai_dashboard_main_area`) | Chat **ou** modo Agentes, conforme o toggle |
| Direita (`ai_dashboard_right_sidebar`) | Status do sistema, config dos agentes (timeout, lote, retries), anexos pendentes, histórico de planos/relatórios |

### 4.2 Modo Chat

- **Loop de ferramentas** (`ai_agent_service.dart`): até **6 rodadas**
  alternando geração ↔ execução de tools MCP até `finish_reason: stop`.
  Eventos: `AgentThinking` → `AgentToolDone` → `AgentToken` → `AgentDone` /
  `AgentError`.
- **Chips de ferramenta**: cada tool aparece como chip que pisca enquanto
  executa e vira ✓/✗ — o usuário vê o agente trabalhando. O ✗ vem do contrato
  de erro do MCP (texto começando com `Erro:`).
- **Markdown + gráficos**: blocos `json-chart` viram gráficos reais
  (`ai_chart_view.dart`); JSON incompleto durante o streaming mostra
  "gerando gráfico" em vez de erro.
- **Autocomplete** (`ia_suggestions_panel.dart`): sugestões agrupadas por
  categoria, filtradas pelo texto digitado.
- **Voz (STT)**: `voice_input_service.dart`, `speech_to_text` em `pt_BR`.
- **Anexos + OCR**: PDF/DOCX/XLSX/imagem → `document_service.dart` →
  Cloud Function `analyzeDocument` (Azure Document Intelligence) → texto
  injetado como contexto na mensagem.
- **Exportação**: `ai_export_service.dart` (copiar, arquivo, e-mail).

### 4.3 Modo Agentes (orquestrador multi-agente)

`agent_orchestrator.dart`

1. **Plano** — `AiAgentService.plan()` decompõe o objetivo em **2–6 tarefas
   paralelas e independentes**, cada uma com `prompt` autossuficiente. O parser
   é defensivo: remove cercas de código, isola o primeiro array JSON, descarta
   entradas sem `prompt`.
2. **Execução paralela** — em lotes de `agentBatchSizeProvider`
   (clampado a 1–8; padrão baixo de propósito, para não virar rajada e tomar
   429 do modelo), com `agentTimeoutProvider` por tarefa e retries
   configuráveis. Timeout vira resultado marcado, não exceção.
3. **Síntese** — consolida os resultados num relatório executivo.
4. **Persistência** — plano e relatório em `tb_agent_plans`, carimbados com
   `idclinica`.

### 4.4 Alertas proativos

`ia_alerts_provider.dart` — `StreamProvider` que recalcula a cada 60 s e devolve
`IaAlert { label, icon, severity, prompt }`. Clicar envia `prompt` ao chat.

### 4.5 Agendamento inteligente (B2B)

`smart_scheduling_card.dart` — recurso **restrito a clínicas privadas**; os
demais tipos veem o recurso bloqueado em vez de escondido.

### 4.7 Evidências científicas (PubMed) — `/evidencias`

Módulo novo (2026-09-01). Transforma pergunta clínica em busca no PubMed e
devolve resposta **rastreável até a fonte**. Duas superfícies:

- **Tela `/evidencias`** — busca, triagem por desenho de estudo e ano, resumo
  sob demanda, "Como pesquisamos" (a consulta que o PubMed realmente executou).
- **Ferramentas `pubmed_*`** — o agente do `/ia` passa a citar literatura real
  em vez de responder de memória.
- **Modo agente da própria tela** — pergunta em português vira PICO, estratégia
  Entrez, busca calibrada, leitura de resumos e síntese citada, com cada passo
  visível. É o único agente do projeto que **mostra e deixa corrigir** a própria
  interpretação antes de agir (EVIDENCIAS.md §7.1).
- **Chat de pesquisa** — conversa com seguimento, ferramentas de literatura e
  acervo que acumula pela sessão. Cada resposta é conferida contra o acervo, e
  responder **sem buscar** é sinalizado na tela (EVIDENCIAS.md §7.2).

Somando: o módulo tem três superfícies de IA, e as três passam pela mesma trava
determinística de citação.

### 4.8 Planejador do Simulador — `/monte-carlo`

Automatiza a montagem do plano de encaixes da semana: varre N dias, simula cada
um e entrega onde olhar primeiro. Acrescentado em 2026-09-02.

Repete a disciplina do módulo de Evidências com outra âncora:

| | Evidências | Simulador |
|---|---|---|
| O código produz | artigos recuperados | números da simulação |
| A I.A. faz | sintetiza | prioriza e explica |
| A trava confere | cada PMID citado | cada cifra citada |

E acrescenta a regra do Vigia: **sugere, não aplica**. Nenhum encaixe é criado
pela I.A. — ver [`SIMULADOR.md`](SIMULADOR.md) §3.

Duas garantias que são **código, não prompt**:

| Garantia | Onde |
|---|---|
| PMID citado tem que existir no pacote recuperado | `citacao_validator.dart` |
| Dado pessoal nunca sai para o NCBI | `functions/lib/pubmed.js › detectarPhi` |

Isto endereça diretamente a lacuna registrada em §6 ("Sem dado pessoal no
Cérebro: regra no prompt, **sem validação em código**") — no caminho do PubMed,
onde o dado sairia para fora do país, a validação existe.

Spec completa: [`EVIDENCIAS.md`](EVIDENCIAS.md).

### 4.6 Assistente de ajuda — **não documentado até agora**

`lib/features/assistente/` (1.747 linhas) é uma **segunda superfície de I.A.**,
distinta do hub `/ia`: um assistente de ajuda embutido, com tours guiados
(`assistant_tours.dart`), base de conhecimento local
(`assistant_knowledge.dart`), âncoras de UI (`assistant_anchors.dart`) e
fallback para o modelo real via `chatProxy` para perguntas abertas
(`assistant_controller.dart:98`).

Ele responde primeiro pela base local e só chama a IA quando não sabe — é o que
mantém o custo baixo. **Nenhuma spec o cobria**; esta menção existe para que
não seja tratado como código órfão.

---

## 5. Conectividade e modelo

`lib/core/services/ai_config.dart` centraliza endpoint e credencial.

| Modo | Quando | Credencial |
|---|---|---|
| **Proxy** (produção) | `--dart-define=AI_PROXY_URL=<url>` definido | Fica **só no servidor** (`chatProxy` injeta `AZURE_AI_KEY`) |
| **Direto** (desenvolvimento) | Sem `AI_PROXY_URL` | `--dart-define=AZURE_AI_KEY=...` embarcada no build |
| **Fallback local** | Sem nenhuma das duas | Sem IA real |

> ⚠️ **No modo direto a chave vai no bundle** — na build web ela é legível por
> qualquer visitante. Produção **precisa** do proxy. Ver [`AI_chaves.md`](AI_chaves.md).

**Modelo**: `DeepSeek-V4-Flash` (padrão), `temperature 0.4`. Retry com backoff
exponencial respeitando `Retry-After` em 429/503; erro HTTP definitivo não
dispara fallback de endpoint (o servidor respondeu — insistir só multiplica o
custo).

---

## 6. Segurança e limites — estado real

| Invariante | Estado |
|---|---|
| Isolamento multi-tenant no MCP | ✅ fail-closed em 4 pontos; 10 testes |
| LOCK do `clinicaId` contra prompt injection | ✅ argumento do modelo ignorado |
| IA nunca executa automação sozinha | ✅ 3 travas + `setStatus` blindado; 13 testes |
| Escrita no Cérebro auditada (motivo + confiança) | ✅ `tb_cerebro_eventos` |
| Sem dado pessoal em nota do Cérebro | 🟡 regra no prompt, **sem validação em código** |
| Sem dado pessoal na busca PubMed | ✅ bloqueio em código, antes da rede (`EVIDENCIAS.md` §11) |
| Citação verificável (PMID existe) | ✅ validação determinística (`citacao_validator.dart`) |
| Autenticação no `pubmedProxy` | ✅ `verifyIdToken` — única function do projeto que exige login |
| RBAC por papel | ❌ **não implementado** (ver `MCP.md` §9) |
| Autenticação nos proxies de IA | ❌ **ausente** (ver `ATENCAO.md`) |
| Orçamento de leituras no cliente | ❌ só no cron (`TAREFAS_AGENDADAS.md` §7.1) |

---

## 7. Métricas de sucesso — e por que não são medidas hoje

| Métrica | Meta | Como está |
|---|---|---|
| Redução na taxa de absenteísmo | −30 % em 90 dias | ⬜ sem linha de base registrada |
| Taxa de confirmação após lembrete | > 75 % | ⬜ depende de RF-03 (desfecho) |
| Faltas evitadas pelo agente / mês | > 50 | ⬜ idem |
| Economia estimada mensal | > R$ 5.000 | ⬜ idem |
| Tempo médio de resposta do agente | < 2 s | 🟡 irreal com loop de ferramentas: cada rodada é uma chamada ao modelo + N queries |

> **Estas metas não são acionáveis hoje.** Quatro das cinco dependem de medir o
> desfecho de cada intervenção (RF-03), que não existe; a quinta contradiz a
> arquitetura de tool-calling. Tratá-las como compromisso de produto sem antes
> implementar a medição produz relatório inventado — exatamente o que a regra
> de confiança do Cérebro existe para evitar.
>
> **Próximo passo mínimo:** gravar o `outcome` do agendamento após a data
> (RF-03). Sem ele, nenhuma métrica de eficácia da IA é verificável.

---

## 8. Backlog priorizado da plataforma de I.A.

Ordenado por (valor ÷ esforço). Nenhum é bug; são o que leva a plataforma
adiante. Ver também o backlog geral em [`ATENCAO.md`](ATENCAO.md).

| # | Item | Esforço | Por quê |
|---|---|---|---|
| 1 | Autenticar `chatProxy`/`emailProxy`/`whatsappProxy` | P | Hoje qualquer um envia e-mail/WhatsApp pela conta da clínica |
| 2 | Gravar `outcome` do agendamento (RF-03) | P–M | Destrava **todas** as métricas de eficácia |
| 3 | Decidir sobre `McpCache` (ligar ou remover) | P | 68 linhas mortas documentadas como camada ativa |
| 4 | Remover ou usar `anthropicProxy` | P | Function publicada com secret e sem chamador |
| 5 | Orçamento de leituras no runner Dart | P–M | Paridade com o cron; teto de custo no cliente |
| 6 | Trilha consultável de ações do agente | M | `history[]` guarda só 20 por tarefa |
| 7 | Painel de métricas do Vigia (aprovado × recusado) | M | Fecha o ciclo de confiança na IA |
| 8 | RBAC por papel | M | Distinguir *qual* humano aprova uma rotina |
| 9 | Validar em código a ausência de dado pessoal no Cérebro | M | Hoje é só instrução de prompt |
| 10 | Heatmap hora × dia (RF-13) | M | Único gráfico proposto que falta |
| 11 | As 9 tools restantes do Cérebro | M–G | Ver `obsidian.md` §9.1 |
| 12 | Busca semântica no Cérebro (embeddings) | G | Maior salto de qualidade de recuperação — também destravaria o reranking do módulo de Evidências |
| 13 | Busca salva + alerta de nova literatura | M | `tb_scheduled_tasks` já suporta; fecha o caso "acompanhar tema" |

**P** = horas · **M** = 1–3 dias · **G** = mais de uma semana.

---

## 9. Referências

| Assunto | Documento |
|---|---|
| Ferramentas do agente | [`MCP.md`](MCP.md) |
| Ciclo diário e aprovação | [`VIGIA.md`](VIGIA.md) |
| Rotinas e execução | [`TAREFAS_AGENDADAS.md`](TAREFAS_AGENDADAS.md) |
| Memória do agente | [`obsidian/obsidian.md`](obsidian/obsidian.md) |
| Evidências científicas | [`EVIDENCIAS.md`](EVIDENCIAS.md) |
| Chaves e endpoints | [`AI_chaves.md`](AI_chaves.md) |
| Deploy das functions | [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) |
| Custo por ferramenta | [`CUSTO.md`](CUSTO.md) |
| Riscos abertos | [`ATENCAO.md`](ATENCAO.md) |
