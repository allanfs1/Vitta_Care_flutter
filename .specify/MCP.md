# MCP — Agenda Clínica

Documentação completa da lógica, implementação e especificação do servidor **Model Context Protocol (MCP)** deste projeto.

> **Projeto Firebase**: `agendaclinica-457713`
> **Stack**: Next.js 16 (App Router) + Firebase Admin / Firestore
> **SDK**: `@modelcontextprotocol/sdk` + `zod`
> **Nome do servidor MCP**: `Agenda Clinica MCP` — versão `2.0.0`

---

## 1. Visão Geral

O MCP expõe os módulos de negócio da plataforma (agendamentos, médicos, pacientes,
absenteísmo, overbooking, lista de espera, SUS/APS, WhatsApp, e-mail, tarefas agendadas)
como **Tools** que um LLM (o agente do chat, Claude Desktop, Cursor, etc.) pode invocar.

Toda a lógica das ferramentas vive numa **factory única e reutilizável**
(`createMcpServer`) consumida por dois *transports* distintos:

| Modo | Arquivo | Transport | Consumidores |
|---|---|---|---|
| **HTTP (web/prod)** | `src/app/api/mcp/route.js` | `WebStandardStreamableHTTPServerTransport` (stateless) | Agente do chat, agentes autônomos, clientes web |
| **Local (dev)** | `scripts/mcp-server.mjs` | `StdioServerTransport` | Claude Desktop, Cursor, VS Code, Antigravity IDE |

> ⚠️ **Nota de implementação**: a especificação original (`especificacao/especificacao_mcp.md`)
> descrevia o transport HTTP como `SSEServerTransport` com mapa de sessões. A implementação
> **atual** usa `WebStandardStreamableHTTPServerTransport` em **modo stateless**
> (`sessionIdGenerator: undefined`), que é compatível com o ambiente serverless do Next.js.

### Arquitetura

```
┌──────────────────────┐        ┌──────────────────────┐
│  Claude Desktop /     │        │  Agente de Chat /     │
│  Cursor / VS Code     │        │  Clientes Web         │
└──────────┬───────────┘        └──────────┬───────────┘
           │ Stdio                          │ HTTP (streamable)
           ▼                                ▼
 scripts/mcp-server.mjs          src/app/api/mcp/route.js
           │                                │
           └──────────────┬─────────────────┘
                          ▼
        src/core/modules/mcp/mcp.server.js
                createMcpServer(opts)
                          │
          ┌───────────────┼───────────────────────────┐
          ▼               ▼                           ▼
   Firebase Admin   Core Modules                External APIs
   (Firestore)      (absenteísmo, overbooking,  (Z-API WhatsApp,
                     SUS, scheduled_tasks,        SendGrid, Google
                     google)                      Workspace, Cloud Fns)
```

---

## 2. Estrutura de Arquivos

```
app_company/
├── scripts/
│   └── mcp-server.mjs                 ← Servidor MCP local (Stdio)
├── claude_desktop_config.json         ← Config do cliente Claude Desktop
├── src/
│   ├── app/api/mcp/route.js           ← Servidor MCP HTTP (stateless streamable)
│   ├── lib/mcp-cache.js               ← Cache em memória (TTL) para respostas MCP
│   └── core/modules/mcp/
│       └── mcp.server.js              ← Factory createMcpServer() com TODAS as tools
└── especificacao/especificacao_mcp.md ← Spec histórica (v2.0)
```

---

## 3. Factory do Servidor — `createMcpServer(opts)`

`src/core/modules/mcp/mcp.server.js`

```js
export function createMcpServer(opts = {}) {
  // Clínica padrão por requisição (escopo multi-tenant).
  // Sombreia a constante global para que TODAS as tools usem a clínica do usuário logado.
  const DEFAULT_CLINICA = opts.defaultClinicaId || GLOBAL_DEFAULT_CLINICA;
  const server = new McpServer({ name: "Agenda Clinica MCP", version: "2.0.0" });
  // ... registro de ~50 tools ...
  return server;
}
```

### Constantes e helpers

| Símbolo | Valor / Função |
|---|---|
| `GLOBAL_DEFAULT_CLINICA` | `"JuhdNt7NG3GYOFKOKOXP"` — clínica padrão de fallback |
| `DEFAULT_LIMIT` | `50` — limite padrão das listagens |
| `toJSON(docs)` | Mapeia `docs` do Firestore para `{ id, ...data() }` |
| `ok(data)` | `{ content: [{ type: "text", text: JSON.stringify(data, null, 2) }] }` |
| `err(msg)` | `{ content: [{ type: "text", text: "Erro: " + msg }] }` |

### Multi-tenant (escopo de clínica)

`opts.defaultClinicaId` permite que o transport injete a clínica do usuário logado.
Com isso, `DEFAULT_CLINICA` **sombreia** a constante global e **todas** as tools que
aceitam `clinicaId` opcional passam a operar na clínica correta por padrão.
Filtros de clínica usam referências de documento: `adminDb.doc(\`tb_clinica/${clinicaId}\`)`.

---

## 4. Transports

### 4.1 HTTP (produção) — `src/app/api/mcp/route.js`

```js
import { WebStandardStreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js";
import { createMcpServer } from "@/core/modules/mcp/mcp.server";

export const dynamic = "force-dynamic";

async function handleRequest(request) {
  const server = createMcpServer();
  const transport = new WebStandardStreamableHTTPServerTransport({
    sessionIdGenerator: undefined, // stateless — compatível com Next.js serverless
  });
  await server.connect(transport);
  return transport.handleRequest(request);
}

export { handleRequest as GET, handleRequest as POST, handleRequest as DELETE };
```

- **Modo stateless**: cada requisição cria um servidor/transport efêmeros (sem mapa de sessões).
- Exporta os métodos `GET`, `POST`, `DELETE` apontando para o mesmo handler.
- `dynamic = "force-dynamic"` para impedir cache de rota do Next.js.

> O agente do chat injeta `defaultClinicaId` via `createMcpServer({ defaultClinicaId })`
> a partir da sessão `__session` do usuário (ver `src/lib/ai-client.js`).

### 4.2 Local (dev) — `scripts/mcp-server.mjs`

```js
#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { initializeApp, cert } from "firebase-admin/app";
import { readFileSync } from "fs";
import { resolve } from "path";

const keyPath = resolve(process.cwd(), "especificacao/firebase-admin.json");
const serviceAccount = JSON.parse(readFileSync(keyPath, "utf-8"));
initializeApp({ credential: cert(serviceAccount) });

import { createMcpServer } from "../src/core/modules/mcp/mcp.server.js";
const server = createMcpServer();
const transport = new StdioServerTransport();
await server.connect(transport);
```

- Inicializa o Firebase Admin com `especificacao/firebase-admin.json` (credencial local).
- Reutiliza a **mesma** factory `createMcpServer` do transport HTTP.
- Execução: `node scripts/mcp-server.mjs`.

---

## 5. Cache em memória — `src/lib/mcp-cache.js`

Cache de processo (vive no servidor Node.js, limpo a cada deploy) para respostas repetidas.

| Função | Descrição |
|---|---|
| `getCache(key)` | Retorna o valor ou `null` se expirado/ausente (limpa entradas expiradas) |
| `setCache(key, data, ttlMs = 120_000)` | Grava com expiração (TTL padrão 2 min) |
| `invalidateCache(prefix)` | Remove todas as chaves que começam com `prefix` |
| `withCache(key, fn, ttlMs)` | Executa `fn()` só se não houver cache válido |
| `cacheStats()` | `{ active, expired, total }` |

> TTL sugerido: **2 min** para listas; **30 s** para dados em tempo real.

---

## 6. Catálogo de Tools

A factory registra ~50 ferramentas. Todas retornam JSON via `ok()` ou mensagem via `err()`.
`clinicaId` é quase sempre opcional e usa `DEFAULT_CLINICA` (multi-tenant) quando omitido.

### 6.1 Clínicas
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_clinicas` | Lista clínicas cadastradas (`limite`) | `tb_clinica` |
| `buscar_clinica` | Busca clínica por ID | `tb_clinica` |

### 6.2 Médicos
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_medicos` | Filtra por clínica, especialidade e `apenasAtivos` (status=true) | `tb_medicos` |
| `buscar_medico` | Busca médico por ID | `tb_medicos` |

### 6.3 Agendamentos
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_agendamentos` | Filtros: clínica, médico, status, intervalo de datas | `tb_agendamentos` |
| `buscar_agendamento` | Busca por ID | `tb_agendamentos` |
| `criar_agendamento` | Cria consulta (status inicial `confirmado`) | `tb_agendamentos` |
| `atualizar_status_agendamento` | Status: `confirmado/cancelado/faltou/realizado/reagendado` | `tb_agendamentos` |
| `listar_agendamentos_hoje` | Agendamentos do dia (filtra por clínica/médico) | `tb_agendamentos` |

`criar_agendamento` grava referências (`idMedico`, `idClinica`/`idclinica`, `idPaciente`),
dados desnormalizados do paciente, `modalidade` (`Presencial`/`Telemedicina`), timestamps.

### 6.4 Pacientes / Usuários
| Tool | Descrição | Coleção |
|---|---|---|
| `buscar_paciente` | Busca por `cpf`, `uid` ou `nome` (prefixo em `display_name`) | `users` |
| `listar_usuarios` | Lista usuários (`apenasAtivos`, clínica) | `users` |

### 6.5 Risco de falta / Predição (IA)
| Tool | Descrição | Coleção / Serviço |
|---|---|---|
| `listar_agendamentos_alto_risco` | Risco previsto pela IA (`prioridade`, `foiIgnorado`) | `dashboard_risco` |
| `listar_faltas_ia` | Faltas registradas pelo algoritmo (`processado`, `risco_falta`) | `tb_faltas_data` |
| `analisar_reputacao_paciente` | Score de reputação por CPF | `patient_reputation` |
| `calcular_risco_paciente` | Score de risco + fatores | `absenteismo.service` |
| `listar_agendamentos_risco_alto` | Score ≥ 50 nos próximos X dias | `COLLECTIONS.SCORES` |
| `historico_absenteismo_paciente` | Estatísticas de faltas do paciente | `absenteismo.service` |
| `taxa_absenteismo` | KPIs da clínica (taxa, variação, economia) | `absenteismo.service` |
| `simular_overbooking` | Simula impacto de overbooking num slot | `tb_agendamentos` + SCORES |

`simular_overbooking` calcula risco médio e nº de agendamentos críticos (score ≥ 76),
retornando uma **recomendação** textual.

### 6.6 Overbooking — leitura
| Tool | Descrição | Coleção |
|---|---|---|
| `listar_eventos_overbooking` | Eventos detectados (`decisao`) | `tb_overbooking_events` |
| `listar_realocacoes` | Realocações (`status`, `processado`) | `queue_realoc` |
| `listar_relatorios_overbooking` | Relatórios e métricas | `tb_overbooking_reports` |

### 6.7 Overbooking — painel, automação e lista de espera (FEATURE-008)
| Tool | Descrição | Serviço |
|---|---|---|
| `overbooking_painel` | Resumo dia/semana: previsão, risco, slots, automação | `getOverbookingDashboard` |
| `overbooking_horarios_livres` | Ocupação × limite por horário do médico (RF-09) | `getFreeSlots` |
| `overbooking_confirmacoes_automaticas` | Dispara confirmações de alto risco (RF-11, idempotente) | `runConfirmacoesAutomaticas` |
| `lista_espera_adicionar` | Adiciona à fila com prioridade 0–100 (RF-12) | `addToWaitlist` |
| `lista_espera_listar` | Lista a fila (filtro por `status`) | `listWaitlist` |
| `lista_espera_aceitar` | Aceita convocação → **cria** o agendamento | `aceitarConvocacao` |
| `lista_espera_recusar` | Recusa/expira e convoca o próximo | `recusarConvocacao` |
| `lista_espera_remover` | Remove paciente da fila | `removerDaFila` |

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
| `consultar_colecao` | Fallback para **qualquer** coleção Firestore (`colecao`, `campo`, `valor`, `limite`) |

### 6.12 Agente de absenteísmo (pausa)
| Tool | Descrição | Coleção |
|---|---|---|
| `pausar_agente` | Suspende ações automáticas para um paciente | `COLLECTIONS.CONFIG` (`pause_<id>`) |
| `retomar_agente` | Retoma ações automáticas | `COLLECTIONS.CONFIG` |

### 6.13 SUS / APS — Previne Brasil & Busca Ativa
| Tool | Descrição | Serviço |
|---|---|---|
| `previne_brasil_indicadores` | Indicadores por linha de cuidado: numerador/denominador, cobertura %, meta, projeção de repasse | `getPrevineBrasil` |
| `busca_ativa_linha_cuidado` | Pacientes em atraso por linha de cuidado, prontos para convocação | `getBuscaAtiva` |

Sem `clinicaId` → consolidado de todas as clínicas (escopo RSA).
Linhas válidas vêm de `LINHA_IDS` (`sus_linhas`).

### 6.14 Cloud Functions (e-mails transacionais)
| Tool | Endpoint | Uso |
|---|---|---|
| `enviar_email_confirmacao` | `api-wriqcan55q-uc.a.run.app/sendConfirmationEmail` | Confirmação de consulta |
| `enviar_email_overbooking` | `.../sendOverbookingEmail` | Aviso informativo (sem ação) |
| `enviar_email_realocacao` | `.../cancelAndReschedulePage` | Reagendamento com link seguro (token + HMAC) |

### 6.15 Google Workspace (`google.service`)
| Tool | Descrição |
|---|---|
| `google_agendar_evento` | Cria evento no Google Calendar da clínica |
| `google_listar_eventos` | Lista próximos eventos (`timeMin`/`timeMax`) |
| `google_enviar_email` | Envia e-mail via Gmail da clínica |
| `google_buscar_drive` | Busca arquivos no Google Drive |

### 6.16 E-mail (SendGrid HTTP API — `email-sender`)
| Tool | Template | Uso |
|---|---|---|
| `email_enviar_livre` | `htmlMensagemLivre` | Texto livre / Markdown → HTML |
| `email_confirmar_consulta` | `htmlConfirmacao` | Confirmação de consulta |
| `email_lembrete_consulta` | `htmlLembrete` | Lembrete (24h/2h antes) |
| `email_aviso_overbooking` | `htmlOverbooking` | Realocação com link de reagendamento |
| `email_relatorio` | `htmlRelatorio` | Relatório executivo |
| `email_enviar_em_lote` | `htmlMensagemLivre` | Lote (máx 15; `{{nome}}` personaliza) |

> Todos os envios SendGrid registram em `email_logs` via `logEmail` (status `sent`/`failed`).
> O corpo aceita **Markdown** (não HTML) — é renderizado em template de marca automaticamente.

### 6.17 WhatsApp (Z-API — `lib/whatsapp`)
| Tool | Endpoint Z-API | Uso |
|---|---|---|
| `whatsapp_status` | `status` (GET) | Verifica conexão da instância |
| `whatsapp_validar_numero` | `contacts-exists/{phone}` | Número tem WhatsApp ativo? |
| `whatsapp_enviar_texto` | `send-text` | Texto livre (`delay` configurável) |
| `whatsapp_confirmar_consulta` | `send-text` + `templateConfirmacao` | Confirmação |
| `whatsapp_lembrete_consulta` | `send-text` + `templateLembrete` | Lembrete |
| `whatsapp_aviso_overbooking` | `send-text` + `templateOverbooking` | Realocação com link |
| `whatsapp_enviar_lista_confirmacao` | `send-button-list` | Botões Sim/Reagendar/Cancelar |
| `whatsapp_enviar_em_lote` | `send-text` | Lote (máx 20; `{{nome}}` personaliza) |

Números passam por `normalizePhone`; config por clínica via `getWhatsappConfig`.

### 6.18 Tarefas agendadas (Scheduled Tasks)
| Tool | Descrição |
|---|---|
| `agendar_tarefa` | Cria tarefa futura/recorrente (`tipoTarefa`: `acao`/`relatorio`) |
| `listar_tarefas_agendadas` | Lista tarefas, status e próxima execução |
| `pausar_retomar_tarefa` | Pausa (`paused`) / retoma (`active`) |
| `cancelar_tarefa_agendada` | Exclui permanentemente |

`agendar_tarefa` aceita recorrência `once/interval/daily/weekly/monthly`, `horario` HH:MM (BRT),
`diasSemana`, `diaDoMes`, `intervaloMinutos`, e data `once` flexível (`parseFlexibleDate`,
aceita `DD/MM/AAAA HH:MM`). O `prompt` é a instrução em linguagem natural executada na hora marcada.
`tipoTarefa: "relatorio"` → `kind: "report"` (salvo na página de Relatórios e enviado por e-mail).

---

## 7. Padrões de implementação

- **Validação de entrada**: cada tool define seu schema com **Zod** (`z.string()`, `z.enum()`,
  `z.number().int()`, `z.array(...)`, `.optional()`, `.describe()`). As descrições alimentam o LLM.
- **Saída uniforme**: sempre `content: [{ type: "text", text }]` via `ok()`/`err()`.
- **Tratamento de erro**: tools que chamam serviços externos envolvem a lógica em `try/catch`
  e retornam `err(e.message)` — nunca lançam exceção para fora do handler.
- **Referências Firestore**: filtros por entidade usam `adminDb.doc(\`colecao/id\`)`, não strings.
- **Idempotência**: ações sensíveis (confirmações automáticas, lista de espera, scheduled tasks)
  são idempotentes/transacionais nos respectivos serviços.

---

## 8. Configuração de clientes MCP

### Claude Desktop / Antigravity IDE — `claude_desktop_config.json`
```json
{
  "mcpServers": {
    "agenda-clinica-local": {
      "command": "node",
      "args": ["c:/Users/micro/OneDrive/Documentos/AntiyGravity/my-project/app_company/scripts/mcp-server.mjs"],
      "env": { "FIREBASE_PROJECT_ID": "agendaclinica-457713" }
    }
  }
}
```

### HTTP (produção)
```
Base URL: https://<seu-dominio>/api/mcp
GET / POST / DELETE  → mesmo handler (transport streamable, stateless)
```

### Teste local (MCP Inspector)
```bash
npx @modelcontextprotocol/inspector node scripts/mcp-server.mjs
```

---

## 9. Integração com o Chat / Agente de I.A

- **Rota de streaming**: `POST /api/chat/stream-chat` (SSE — eventos `token`, `thinking`,
  `tool_done`, `done`, `error`).
- **Cliente IA**: `src/lib/ai-client.js`;
  executor não-streaming (tarefas agendadas): `src/lib/agent-runner.js`.
- **Loop de ferramentas**: o agente chama tools MCP em rodadas até a resposta final.
- **Multi-tenant**: a clínica de TODAS as tools vem do `idclinica` do usuário logado
  (sessão `__session`), via `createMcpServer({ defaultClinicaId })`; o ID também entra no system prompt.
- **Gráficos**: o agente pode responder com blocos ` ```json-chart ` renderizados com recharts.
- **RBAC**: as tools de tarefa agendada só são expostas para papéis `admin`/`rsa` (não para `med`).

---

## 10. Segurança

| Camada | Medida |
|---|---|
| **HTTP** | Sessão `__session` (Firebase Admin) resolvida antes de instanciar o servidor; clínica do usuário injetada como escopo |
| **Stdio (local)** | Acesso restrito às credenciais locais de `especificacao/firebase-admin.json` |
| **Multi-tenant** | Queries escopadas por `clinicaId`; criação travada na clínica do usuário |
| **RBAC** | `admin`/`rsa`/`med` acessam o sistema; tarefas/relatórios só `admin`/`rsa` |
| **Tools destrutivas** | `criar_agendamento`, `atualizar_status_agendamento`, envios e tarefas exigem autenticação |
| **Cron** | `CRON_SECRET` obrigatório (fail-closed) para o executor de tarefas agendadas |

---

## 11. Dependências

```bash
npm install @modelcontextprotocol/sdk zod
```
> `zod` e `firebase-admin` já constam no `package.json`.

---

## 12. Referências internas

- Factory e tools: `src/core/modules/mcp/mcp.server.js`
- Transport HTTP: `src/app/api/mcp/route.js`
- Transport Stdio: `scripts/mcp-server.mjs`
- Cache: `src/lib/mcp-cache.js`
- Spec histórica (v2.0): `especificacao/especificacao_mcp.md`
- Tarefas agendadas: `especificacao/docs/tarefas_agendadas_scheduled.md`
- Chat / Agente de I.A: `especificacao/docs/AgentAI.md`
