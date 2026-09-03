# MCP — Ferramentas do Agente de I.A.

Especificação do registro de ferramentas **Model Context Protocol** deste
repositório: como o agente de I.A. lê e escreve dados da clínica, e o que
impede que ele toque nos dados de outra.

> **Projeto Firebase**: `agendaclinica-457713`
> **Implementação**: Dart puro, em `lib/core/modules/mcp/`
> **Consumidores**: agente do chat (`/ia`), Vigia (`features/ia/vigia/`),
> executor de tarefas agendadas (`scheduled_tasks_runner.dart`)
> **Nome/versão do servidor**: `Agenda Clinica MCP` v2.0.0

---

## 0. Aviso de portabilidade — leia antes de procurar arquivo

Este documento descreveu, até 2026-09-01, o servidor MCP em **Next.js** do
projeto irmão `app_company` (`src/core/modules/mcp/mcp.server.js`, transports
HTTP/Stdio, `@modelcontextprotocol/sdk`, `zod`). **Nada disso existe neste
repositório.**

O Vitta é um app **Flutter**. O MCP foi portado para Dart e roda **dentro do
processo do app**: não há servidor HTTP, não há transport, não há SDK do MCP
nem `zod`. O agente chama `McpServer.callTool` como uma função local.

| O que a spec antiga dizia | O que existe aqui |
|---|---|
| `src/core/modules/mcp/mcp.server.js` | `lib/core/modules/mcp/mcp_server.dart` |
| `createMcpServer(opts)` (JS) | `createMcpServer({db, defaultClinicaId})` (Dart) |
| Transport HTTP `WebStandardStreamableHTTPServerTransport` | **não existe** — chamada em processo |
| Transport Stdio `scripts/mcp-server.mjs` | **não existe** |
| Validação por `zod` | mapa `inputSchema` (JSON Schema literal) + coerção em `McpArgs` |
| `src/lib/mcp-cache.js` (cache ativo) | `mcp_cache.dart` existe mas **não é usado** (§5) |
| Sessão `__session` do Next.js | `clinicaResolvidaProvider` (Riverpod) |

Se você chegou aqui procurando um endpoint `/api/mcp`, ele é de outro
repositório. Ver `cloud_functions.md` para o que este projeto publica.

---

## 1. Visão geral

O MCP expõe os módulos de negócio (agendamentos, médicos, pacientes,
absenteísmo, overbooking, lista de espera, SUS/APS, WhatsApp, e-mail, tarefas
agendadas, Cérebro) como **ferramentas** que o LLM pode invocar.

Toda a lógica vive numa **factory única** (`createMcpServer`) consumida por
três chamadores no mesmo processo:

```
  ┌──────────────┐   ┌──────────────┐   ┌────────────────────────┐
  │ Chat  /ia    │   │ Vigia        │   │ Runner de tarefas      │
  │ agent_       │   │ vigia_       │   │ scheduled_tasks_       │
  │ controller   │   │ service      │   │ runner                 │
  └──────┬───────┘   └──────┬───────┘   └───────────┬────────────┘
         │                  │                       │
         └──────────────────┼───────────────────────┘
                            ▼
              mcpServerProvider (Riverpod)
              createMcpServer(defaultClinicaId: clinicaResolvida)
                            │
                            ▼
              lib/core/modules/mcp/mcp_server.dart
                            │
        ┌───────────────────┼────────────────────┐
        ▼                   ▼                    ▼
   Cloud Firestore    Cloud Functions      APIs externas
   (SDK do cliente)   (emailProxy,         (Google Workspace,
                       whatsappProxy)       Z-API via proxy)
```

O **loop de ferramentas** (modelo → tool → modelo) roda no cliente, em
`ai_agent_service.dart`. O MCP não fala com o modelo; ele só executa o que for
pedido e devolve texto.

---

## 2. Estrutura de arquivos

```
lib/core/modules/mcp/
├── mcp_server.dart        ← factory createMcpServer() + despacho de tools
├── mcp_tool.dart          ← McpTool, McpContext, McpArgs, McpResult, ok()/err()
├── mcp_providers.dart     ← mcpServerProvider, mcpToolSpecsProvider
├── mcp_cache.dart         ← cache TTL (NÃO usado hoje — ver §5)
└── tools/
    ├── agendamentos_tools.dart       (551 linhas)
    ├── cerebro_tools.dart            (526)
    ├── clinicas_medicos_tools.dart   (233)
    ├── comunicacao_tools.dart      (1.511)
    ├── dados_tools.dart              (833)
    ├── overbooking_sus_tools.dart  (1.140)
    └── pacientes_risco_tools.dart  (1.119)
```

---

## 3. A factory — `createMcpServer(...)`

`lib/core/modules/mcp/mcp_server.dart`

```dart
McpServer createMcpServer({
  FirebaseFirestore? db,
  String? defaultClinicaId,
}) {
  final ctx = McpContext(db: db, defaultClinicaId: defaultClinicaId);
  final groups = <McpTool>[
    ...buildClinicasMedicosTools(ctx),
    ...buildAgendamentosTools(ctx),
    ...buildPacientesRiscoTools(ctx),
    ...buildOverbookingSusTools(ctx),
    ...buildDadosTools(ctx),
    ...buildComunicacaoTools(ctx),
    ...buildCerebroTools(ctx),
  ];
  // assert(!map.containsKey(tool.name)) — nome duplicado quebra em debug
  return McpServer._(ctx, map);
}
```

### Constantes e helpers (`mcp_tool.dart`)

| Símbolo | Valor / função |
|---|---|
| `McpContext.defaultLimit` | `50` — limite padrão das listagens |
| `ok(text)` | `McpResult(text)` |
| `err(msg)` | `McpResult('Erro: ...', isError: true)` |
| `ctx.toJson(docs)` | Mapeia docs do Firestore para `{ id, ...data }` **filtrando os de outra clínica** |
| `McpArgs` | Coerção defensiva dos argumentos do LLM (`str`, `intArg`, `numArg`, `boolArg`, `strList`) |

> **Removido — `GLOBAL_DEFAULT_CLINICA`.** Existia uma constante
> `"JuhdNt7NG3GYOFKOKOXP"` usada como clínica padrão quando `defaultClinicaId`
> chegava vazio. Como **todo** o isolamento multi-tenant se ancora nesse campo,
> o fallback fazia a IA ler e gravar sobre os dados de uma clínica de produção
> alheia sempre que o contexto subisse sem clínica — o que acontece nos
> primeiros frames de cada boot do app. Foi removida em 2026-08-20; **não
> reintroduza**. Ver `test/security/mcp_isolamento_clinica_test.dart`.
>
> Se você encontrar esse valor em outra spec desta pasta, a outra spec está
> errada — ele foi retirado de `TAREFAS_AGENDADAS.md` em 2026-09-01.

### 3.1 Multi-tenant — a regra central

`defaultClinicaId` é a clínica do usuário logado, injetada pelo provider.

> **Sem clínica resolvida, nada acontece.** Um contexto com `defaultClinicaId`
> vazio é *fail-closed* em quatro pontos independentes:

| Ponto | Comportamento sem clínica |
|---|---|
| `McpServer.callTool` | Recusa **antes** de despachar — nenhuma tool chega a abrir conexão |
| `ctx.clinicaId()` | Lança `McpSemClinica` em vez de devolver algo arbitrário |
| `ctx.belongsToClinic(doc)` | `false` para qualquer documento |
| `ctx.isForeignClinic(doc)` | `true` para qualquer documento com campo de clínica |

A guarda em `callTool` é o que torna a recusa **determinística**: deixar cada
handler tropeçar sozinho fazia a mensagem de erro depender de qual operação
tocasse o Firestore primeiro.

**LOCK do LLM.** `ctx.clinicaId(argDoLlm)` **ignora** o argumento e sempre
devolve a clínica do contexto. Uma tool pode declarar `clinicaId` no schema
para o modelo, mas o valor que o modelo passar nunca é usado — é assim que um
prompt malicioso não consegue pedir dados de outra clínica.

**Campos de clínica reconhecidos** (`McpContext._clinicFields`), porque o
schema histórico não é uniforme: `idClinica`, `idclinica`, `clinicaId`,
`idClinic`, `clinica`, `id_clinica`. Aceita `String`, caminho
(`tb_clinica/abc` → `abc`) e `DocumentReference`.

**No cliente Flutter, a clínica vem de `clinicaResolvidaProvider`** — nunca de
`selectedClinicIdProvider`, que vale o placeholder de `MockData` (`'c1'`)
durante o boot. Ver `mcp_providers.dart` e §6.6 de `CUSTO.md`.

---

## 4. Providers (Riverpod)

```dart
final mcpServerProvider = Provider<McpServer>((ref) {
  final clinicaId = ref.watch(clinicaResolvidaProvider);
  return createMcpServer(defaultClinicaId: clinicaId);
});

final mcpToolSpecsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(mcpServerProvider).listToolSpecs();
});
```

O servidor é **reconstruído quando a clínica muda** — não há estado a
invalidar. Em modo demonstração (sem Firebase) o servidor ainda é criado; as
tools devolvem `McpResult` de erro em vez de derrubar a UI.

---

## 5. Cache — existe, mas está desligado

`mcp_cache.dart` define um `McpCache` singleton com TTL
(`getCache`/`setCache`/`invalidate`/`withCache`).

> ⚠️ **Nenhum arquivo do projeto o referencia.** São 68 linhas de código morto.
> A spec anterior o descrevia como camada ativa com TTL de 2 min — não é.
> Toda chamada de tool vai direto ao Firestore.

Isso importa para custo: os SOPs de `CUSTO.md` §6.2 (context cache por
execução) **não estão implementados no lado Dart**. Decidir entre ligar o cache
ou remover o arquivo é item aberto em `ATENCAO.md`.

---

## 6. Catálogo de ferramentas — 79 registradas

Todas devolvem texto via `ok()` ou `err()`. `clinicaId` é quase sempre opcional
no schema — mas o valor é **sempre** o da clínica do contexto (LOCK, §3.1).

> A contagem é verificável:
> `grep -ohE "name: .[a-z0-9_]+." lib/core/modules/mcp/tools/*.dart | sort -u | wc -l`

### 6.1 Clínicas
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_clinicas` | Lista clínicas cadastradas (`limite`) | `tb_clinica` |
| `buscar_clinica` | Busca clínica por ID | `tb_clinica` |

### 6.2 Médicos
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_medicos` | Filtra por clínica, especialidade e `apenasAtivos` | `tb_medicos` |
| `buscar_medico` | Busca médico por ID | `tb_medicos` |

### 6.3 Agendamentos
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_agendamentos` | Filtros: clínica, médico, status, intervalo de datas | `tb_agendamentos` |
| `buscar_agendamento` | Busca por ID | `tb_agendamentos` |
| `criar_agendamento` | Cria consulta (status inicial `confirmado`) | `tb_agendamentos` |
| `atualizar_status_agendamento` | `confirmado/cancelado/faltou/realizado/reagendado` | `tb_agendamentos` |
| `listar_agendamentos_hoje` | Agendamentos do dia | `tb_agendamentos` |

`criar_agendamento` grava referências (`idMedico`, `idClinica`/`idclinica`,
`idPaciente`), dados desnormalizados do paciente, `modalidade`
(`Presencial`/`Telemedicina`) e timestamps.

### 6.4 Pacientes / Usuários
| Tool | Descrição | Coleção |
|---|---|---|
| `buscar_paciente` | Busca por `cpf`, `uid` ou `nome` (prefixo em `display_name`) | `users` |
| `listar_usuarios` | Lista usuários (`apenasAtivos`, clínica) | `users` |

### 6.5 Risco de falta / Predição
| Tool | Descrição | Coleção / serviço |
|---|---|---|
| `listar_agendamentos_alto_risco` | Risco previsto (`prioridade`, `foiIgnorado`) | `dashboard_risco` |
| `listar_faltas_ia` | Faltas registradas pelo algoritmo | `tb_faltas_data` |
| `analisar_reputacao_paciente` | Score de reputação por CPF | `patient_reputation` |
| `calcular_risco_paciente` | Score de risco + fatores | cálculo local |
| `listar_agendamentos_risco_alto` | Score ≥ 50 nos próximos X dias | scores |
| `historico_absenteismo_paciente` | Estatísticas de faltas do paciente | cálculo local |
| `taxa_absenteismo` | KPIs da clínica (taxa, variação, economia) | cálculo local |
| `simular_overbooking` | Simula impacto de overbooking num slot | `tb_agendamentos` + scores |

`simular_overbooking` calcula risco médio e nº de agendamentos críticos
(score ≥ 76), retornando uma **recomendação** textual.

### 6.6 Overbooking — leitura
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_eventos_overbooking` | Eventos detectados (`decisao`) | `tb_overbooking_events` |
| `listar_realocacoes` | Realocações (`status`, `processado`) | `queue_realoc` |
| `listar_relatorios_overbooking` | Relatórios e métricas | `tb_overbooking_reports` |

### 6.7 Overbooking — painel, automação e lista de espera
| Tool | Descrição |
|---|---|
| `overbooking_painel` | Resumo dia/semana: previsão, risco, slots, automação |
| `overbooking_horarios_livres` | Ocupação × limite por horário do médico |
| `overbooking_confirmacoes_automaticas` | Dispara confirmações de alto risco (idempotente) |
| `lista_espera_adicionar` | Adiciona à fila com prioridade 0–100 |
| `lista_espera_listar` | Lista a fila (filtro por `status`) |
| `lista_espera_aceitar` | Aceita convocação → **cria** o agendamento |
| `lista_espera_recusar` | Recusa/expira e convoca o próximo |
| `lista_espera_remover` | Remove paciente da fila |

### 6.8 Tickets de suporte
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_tickets` | Filtros: status, prioridade, fila, responsável | `tickets` |
| `buscar_ticket` | Busca por ID | `tickets` |

### 6.9 E-mails / Notificações (logs e filas)
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_email_logs` | Log de e-mails enviados (`tipo`) | `email_logs` |
| `listar_email_queue` | Fila de e-mails (`status`) | `email_queue` |
| `listar_lembretes` | Controle de lembretes (`ultimoStatus`) | `tb_lembrete_controle` |

### 6.10 Relatórios e histórico
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_relatorios_ia` | Relatórios gerados pela IA (`tipoRelatorio`) | `tb_relatorio_ia` |
| `listar_historico_confirmacoes` | Histórico de confirmações (`action`) | `tb_confirmationHistory` |
| `listar_historico_clinica` | Histórico geral da agenda | `historico_agenda_clinica` |
| `listar_filas` | Filas de atendimento | `queues` |
| `listar_avisos` | Avisos do sistema (`ativo`) | `notices` |

### 6.11 Consulta genérica
| Tool | Descrição |
|---|---|
| `consultar_colecao` | Fallback para **qualquer** coleção (`colecao`, `campo`, `valor`, `limite`) |

> ⚠️ `consultar_colecao` é a tool mais cara do catálogo: sem `campo`/`valor` ela
> faz varredura. `CUSTO.md` §3.1 a lista como Falha A, **ainda aberta**.

### 6.12 Agente de absenteísmo (pausa)
| Tool | Descrição |
|---|---|
| `pausar_agente` | Suspende ações automáticas para um paciente |
| `retomar_agente` | Retoma ações automáticas |

### 6.13 SUS / APS — Previne Brasil & Busca Ativa
| Tool | Descrição |
|---|---|
| `previne_brasil_indicadores` | Indicadores por linha de cuidado: numerador/denominador, cobertura %, meta, projeção de repasse |
| `busca_ativa_linha_cuidado` | Pacientes em atraso por linha de cuidado, prontos para convocação |

### 6.14 Cloud Functions (e-mails transacionais)
| Tool | Uso |
|---|---|
| `enviar_email_confirmacao` | Confirmação de consulta |
| `enviar_email_overbooking` | Aviso informativo (sem ação) |
| `enviar_email_realocacao` | Reagendamento com link seguro (token + HMAC) |

### 6.15 Google Workspace
| Tool | Descrição |
|---|---|
| `google_agendar_evento` | Cria evento no Google Calendar da clínica |
| `google_listar_eventos` | Lista próximos eventos (`timeMin`/`timeMax`) |
| `google_enviar_email` | Envia e-mail via Gmail da clínica |
| `google_buscar_drive` | Busca arquivos no Google Drive |

### 6.16 E-mail (SendGrid via `emailProxy`)
| Tool | Uso |
|---|---|
| `email_enviar_livre` | Texto livre / Markdown → HTML |
| `email_confirmar_consulta` | Confirmação de consulta |
| `email_lembrete_consulta` | Lembrete (24 h / 2 h antes) |
| `email_aviso_overbooking` | Realocação com link de reagendamento |
| `email_relatorio` | Relatório executivo |
| `email_enviar_em_lote` | Lote (máx 15; `{{nome}}` personaliza) |

Endpoint: `https://us-central1-agendaclinica-457713.cloudfunctions.net/emailProxy`
([comunicacao_tools.dart:11](../lib/core/modules/mcp/tools/comunicacao_tools.dart:11)).
O corpo aceita **Markdown**, renderizado em template de marca. Envios
registram em `email_logs`.

### 6.17 WhatsApp (Z-API via `whatsappProxy`)
| Tool | Uso |
|---|---|
| `whatsapp_status` | Verifica conexão da instância |
| `whatsapp_validar_numero` | Número tem WhatsApp ativo? |
| `whatsapp_enviar_texto` | Texto livre (`delay` configurável) |
| `whatsapp_confirmar_consulta` | Confirmação |
| `whatsapp_lembrete_consulta` | Lembrete |
| `whatsapp_aviso_overbooking` | Realocação com link |
| `whatsapp_enviar_lista_confirmacao` | Botões Sim/Reagendar/Cancelar |
| `whatsapp_enviar_em_lote` | Lote (máx 20; `{{nome}}` personaliza) |

Endpoint: `.../whatsappProxy`
([comunicacao_tools.dart:16](../lib/core/modules/mcp/tools/comunicacao_tools.dart:16)).
Números passam por normalização; config por clínica lida do Firestore pela
própria function.

### 6.18 Tarefas agendadas
| Tool | Descrição |
|---|---|
| `agendar_tarefa` | Cria tarefa futura/recorrente (`tipoTarefa`: `acao`/`relatorio`) |
| `listar_tarefas_agendadas` | Lista tarefas, status e próxima execução |
| `pausar_retomar_tarefa` | Pausa (`paused`) / retoma (`active`) |
| `cancelar_tarefa_agendada` | Exclui permanentemente |

Recorrência `once/interval/daily/weekly/monthly`, `horario` HH:MM (BRT),
`diasSemana`, `diaDoMes`, `intervaloMinutos`, data `once` flexível
(`DD/MM/AAAA HH:MM`). Ver `TAREFAS_AGENDADAS.md`.

### 6.19 Cérebro (segundo cérebro da clínica)
| Tool | Tipo | Descrição |
|---|---|---|
| `cerebro_buscar` | leitura | Busca no vault (texto + grafo) |
| `cerebro_ler` | leitura | Lê nota, opcionalmente com backlinks |
| `cerebro_listar` | leitura | Lista com filtros (tag/tipo/estado/período) |
| `cerebro_escrever` | **escrita** | Cria/atualiza nota (`criar`/`substituir`/`append`/`patch`) |
| `cerebro_linkar` | **escrita** | Cria link explícito entre duas notas |

`cerebro_escrever` exige `confianca` (0–1) e `motivo` — os dois vão para
auditoria em `tb_cerebro_eventos`, e confiança < 0,7 grava como rascunho para
revisão humana. **Nunca escrever nome, CPF ou telefone de paciente numa nota.**

> `obsidian.md` §9.1 lista 14 tools do Cérebro. **Só estas 5 existem**; as
> outras 9 (`cerebro_grafo`, `cerebro_vizinhos`, `cerebro_caminho`,
> `cerebro_taguear`, `cerebro_mover`, `cerebro_arquivar`, `cerebro_diario`,
> `cerebro_canvas`, `cerebro_reverter`) são projeto, não código.

### 6.20 Evidência científica (PubMed/NCBI)
| Tool | Tipo | Descrição |
|---|---|---|
| `pubmed_buscar` | leitura | Pesquisa literatura; devolve PMID, título, autores, ano, desenho do estudo |
| `pubmed_artigo` | leitura | Resumo (abstract) completo de até 10 PMIDs |
| `pubmed_relacionados` | leitura | PMIDs relacionados (ELink) |
| `pubmed_corrigir_termo` | leitura | Correção ortográfica do termo (ESpell) |

Vão pela Cloud Function `pubmedProxy` — **a única do projeto que exige login**
(`verifyIdToken`) — e caem para o NCBI direto quando ela não está publicada,
com a guarda de dado pessoal rodando nos dois caminhos.
Ver [`EVIDENCIAS.md`](EVIDENCIAS.md) §3.0 e §3.2.

**Duas diferenças em relação ao resto do catálogo:**

1. **O resultado não é dado de tenant.** Literatura é pública: o PMID 31452104
   é o mesmo artigo para toda clínica. A guarda de `callTool` continua valendo
   (sem clínica resolvida nada é despachado), mas o cache é compartilhado de
   propósito — ver EVIDENCIAS.md §4.
2. **São registradas mesmo sem serviço.** Em modo demonstração devolvem erro
   explicativo em vez de sumirem do catálogo. Tool ausente faz o modelo
   responder **de memória**, que é exatamente o que o módulo existe para evitar.

Dado pessoal de paciente é bloqueado **no servidor**, antes de qualquer rede
(CPF, CNS, CNPJ, e-mail, telefone, 11+ dígitos). Ver EVIDENCIAS.md §11.

---

## 7. Padrões de implementação

- **Schema de entrada**: cada tool declara `inputSchema` como JSON Schema
  literal (mapa Dart). Não há `zod`; a coerção é feita por `McpArgs`, que
  tolera o modelo mandar `"5"` onde o schema pede número.
- **Saída uniforme**: sempre `McpResult`. Sucesso via `ok(json)`, falha via
  `err(msg)` — cujo texto começa com `Erro:`, o que o loop do agente usa para
  marcar o chip como ✗.
- **Nenhuma tool lança**: `callTool` embrulha o handler em `try/catch` e
  converte exceção em `McpResult` de erro. O agente nunca quebra por uma tool.
- **Filtro de tenant na saída**: `ctx.toJson(docs)` descarta documentos de
  outra clínica mesmo que a query os traga — defesa em profundidade contra
  query mal escopada.
- **Idempotência**: ações sensíveis (confirmações automáticas, lista de espera,
  tarefas agendadas) são idempotentes/transacionais nos respectivos serviços.

---

## 8. Integração com o agente

- **Loop de ferramentas**: `lib/features/ia/agent/ai_agent_service.dart` —
  até **6 rodadas** alternando geração ↔ execução de tools, até
  `finish_reason: stop`. Eventos emitidos: `AgentThinking`, `AgentToolDone`,
  `AgentToken`, `AgentDone`, `AgentError`.
- **Modelo**: `DeepSeek-V4-Flash` no Azure AI Foundry, via `chatProxy`
  (Cloud Function) quando `AI_PROXY_URL` está definido; acesso direto no
  desenvolvimento. Ver `AI_chaves.md`.
- **Multi-tenant**: o `clinicaId` entra tanto no `McpContext` quanto no system
  prompt do modelo.
- **Gráficos**: o agente pode responder com blocos de código `json-chart`,
  renderizados por `ai_chart_view.dart`.

---

## 9. Segurança — estado real

| Camada | Situação |
|---|---|
| **Multi-tenant** | ✅ Fail-closed em 4 pontos (§3.1), 10 testes em `test/security/mcp_isolamento_clinica_test.dart` |
| **LOCK do LLM** | ✅ Argumento `clinicaId` do modelo é ignorado |
| **Filtro de saída** | ✅ `toJson` descarta documento de clínica alheia |
| **RBAC** | ❌ **Não implementado neste app** — ver abaixo |
| **Autenticação dos proxies** | ❌ `emailProxy` / `whatsappProxy` / `chatProxy` aceitam qualquer chamador — ver `ATENCAO.md` |
| **Regras do Firestore** | ⚠️ `firestore.rules` versionado, deploy pendente (`ATENCAO.md`) |

> **RBAC — divergência conhecida.** As versões anteriores desta spec e de
> `TAREFAS_AGENDADAS.md` descreviam uma matriz `admin`/`rsa`/`med` com
> `canUseSchedules`, herdada do projeto Next.js. **Ela não existe no app
> Flutter.** `AppUser.roles` é lido apenas para montar `roleLabel` (rótulo de
> exibição); nenhuma tool é escondida por papel. Na prática, **todo usuário
> logado tem acesso às 79 ferramentas**, inclusive `agendar_tarefa`,
> `email_enviar_em_lote` e `whatsapp_enviar_em_lote`.
>
> Isso está registrado como risco aberto em `ATENCAO.md`. Não documente a
> matriz como se valesse — foi essa exata confusão que fez `MCP.md` descrever
> o fallback de clínica como correto depois de ele ter sido removido.

---

## 10. Referências internas

| Assunto | Arquivo |
|---|---|
| Factory e despacho | `lib/core/modules/mcp/mcp_server.dart` |
| Contexto, tipos, helpers | `lib/core/modules/mcp/mcp_tool.dart` |
| Providers | `lib/core/modules/mcp/mcp_providers.dart` |
| Ferramentas | `lib/core/modules/mcp/tools/*.dart` |
| Loop do agente | `lib/features/ia/agent/ai_agent_service.dart` |
| Ciclo diário | [`VIGIA.md`](VIGIA.md) |
| Tarefas agendadas | [`TAREFAS_AGENDADAS.md`](TAREFAS_AGENDADAS.md) |
| Cérebro | [`obsidian/obsidian.md`](obsidian/obsidian.md) |
| Evidências (PubMed) | [`EVIDENCIAS.md`](EVIDENCIAS.md) |
| Custo por ferramenta | [`CUSTO.md`](CUSTO.md) §4 |
| Chaves e endpoints | [`AI_chaves.md`](AI_chaves.md) |
| Riscos abertos | [`ATENCAO.md`](ATENCAO.md) |
