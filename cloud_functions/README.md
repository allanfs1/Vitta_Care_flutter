# Cloud Functions — Chat de IA (proxy seguro)

Estas funções dão suporte ao **chat de IA** do app (`/ia`), descrito em
`.specify/AgentAI.md`. A chave do Azure DeepSeek fica **somente no servidor**.

> **Valores das chaves** (em `.specify/AI_chaves.md`):
> - `AZURE_AI_KEY` (chat) = `AZURE_DEEPSEEK_KEY` (§1.4)
> - `AZURE_DOCINTEL_KEY` (OCR) = `AZURE_COGNITIVE_KEY` (§1.5)
>
> Neste projeto as duas chaves têm o **mesmo valor**, mas endpoints diferentes
> (`services.ai.azure.com/openai/v1/` p/ DeepSeek; `cognitiveservices.azure.com`
> p/ Document Intelligence). Configure cada uma como secret (não comite a chave).

## `chatProxy.js`

Proxy HTTPS que repassa o chat para o Azure AI Foundry (DeepSeek V4) e devolve
a resposta (incluindo `tool_calls`). O **loop de ferramentas MCP roda no app**
(`lib/features/ia/agent/ai_agent_service.dart`), que chama esta função a cada
rodada.

### Deploy

1. No projeto Firebase `agendaclinica-457713`, copie `chatProxy.js` para a pasta
   `functions/` (ou cole a função no seu `index.js`).
2. Garanta as dependências em `functions/package.json`:
   - `firebase-functions` (v2) e Node 20+/22 (tem `fetch` global).
3. Configure a chave como **secret** (valor em `.specify/AI_chaves.md`):
   ```bash
   firebase functions:secrets:set AZURE_AI_KEY
   ```
4. (Opcional) variáveis de ambiente:
   - `AZURE_AI_ENDPOINT` — endpoint chat/completions (padrão já aponta para o do projeto)
   - `AZURE_AI_MODEL` — `DeepSeek-V4-Flash` (padrão) ou `DeepSeek-V4-Pro`
5. Publique:
   ```bash
   firebase deploy --only functions:chatProxy
   ```

A URL final deve ser:
```
https://us-central1-agendaclinica-457713.cloudfunctions.net/chatProxy
```
que é o `AiAgentService.defaultProxyUrl` usado pelo Flutter. Se a sua URL/região
for diferente, ajuste `proxyUrl` ao instanciar `AiAgentService`
(em `agent_controller.dart`, no `aiAgentServiceProvider`).

## `analyzeDocument.js`

Proxy HTTPS para **OCR/extração** de anexos (Azure Document Intelligence,
modelo `prebuilt-read`). Usado pelo botão de anexo do chat
(`lib/features/ia/widgets/attachment_button.dart` → `document_service.dart`).
Arquivos de texto (`.txt/.md/.csv/.json`) são lidos no cliente e **não** passam
por aqui; PDFs/imagens/Office vão para esta função.

### Deploy
1. Copie `analyzeDocument.js` para `functions/`.
2. Configure a chave e o endpoint do recurso de Document Intelligence:
   ```bash
   firebase functions:secrets:set AZURE_DOCINTEL_KEY
   # defina também a env AZURE_DOCINTEL_ENDPOINT, ex.:
   #   https://<seu-recurso>.cognitiveservices.azure.com
   ```
3. `firebase deploy --only functions:analyzeDocument`

URL esperada (default em `DocumentService.defaultProxyUrl`):
```
https://us-central1-agendaclinica-457713.cloudfunctions.net/analyzeDocument
```

## `emailProxy.js`

Envio **direto** de e-mail via SendGrid (síncrono), usado pela camada MCP
(`comunicacao_tools.dart` → helper `_enqueueEmail`): cada tool de e-mail tenta
enviar pelo proxy e grava log em `email_queue` (`status: 'sent'` ou, em falha,
`'queued'` para o `ffProcessEmailQueue` entregar depois).

### Deploy
```bash
firebase functions:secrets:set SENDGRID_API_KEY   # AI_chaves.md §1.6
# (opcional) env EMAIL_FROM / EMAIL_FROM_NAME
firebase deploy --only functions:emailProxy
```
URL: `https://us-central1-agendaclinica-457713.cloudfunctions.net/emailProxy`
(igual ao `_emailProxyUrl` em `comunicacao_tools.dart`).

## `anthropicProxy.js`

Alternativa ao DeepSeek: aceita o **mesmo contrato OpenAI** do `chatProxy`
(messages/tools/tool_calls) e traduz para a API Messages da Anthropic (Claude),
devolvendo no formato OpenAI. Para usar no app, instancie
`AiAgentService(proxyUrl: AiAgentService.anthropicProxyUrl)` no
`aiAgentServiceProvider`.

### Deploy
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY  # AI_chaves.md §1.3
# (opcional) env ANTHROPIC_MODEL (padrão claude-sonnet-4-6), ANTHROPIC_MAX_TOKENS
firebase deploy --only functions:anthropicProxy
```
> Nota: em `AI_chaves.md` a `ANTHROPIC_API_KEY` ainda é placeholder
> (`your_anthropic_api_key_here`) — defina a chave real antes de usar.

## `whatsappProxy.js`

Envio **direto** de WhatsApp via Z-API (ver `.specify/ZAPI.md`), usado pela
camada MCP (`comunicacao_tools.dart` → helper `_writeWhatsapp`): cada tool de
WhatsApp tenta enviar pelo proxy e grava log em `tb_conversas` (`status:
'enviado'` ou, em falha, `'enfileirado'`).

As credenciais Z-API são **por clínica** e vêm do Firestore
(`tb_config_whatsapp`: `intanceId`, `token`, `tokenCliente`, `idclinica`) —
nada de credencial no cliente. Suporta `send-text` e `send-button-list`.

### Deploy
```bash
firebase deploy --only functions:whatsappProxy
```
(Sem secrets — usa `firebase-admin` para ler `tb_config_whatsapp`.)
URL: `https://us-central1-agendaclinica-457713.cloudfunctions.net/whatsappProxy`
(igual ao `_whatsappProxyUrl` em `comunicacao_tools.dart`).

## `scheduledTasksCron.js`

Cron **real no servidor** (Gen 2, `onSchedule` a cada 5 min, TZ America/Sao_Paulo)
que executa as **Tarefas Agendadas** (`tb_scheduled_tasks`) mesmo com o app
fechado. Usa o MESMO lock/schema do cliente (claim em transação + avanço de
`nextRunAt`), então cron e catch-up do app nunca duplicam a execução.

Agente Node chama o Azure DeepSeek (secret `AZURE_AI_KEY`) com **17 ferramentas**
Firestore/comunicação: `consultar_colecao`, `listar_agendamentos`,
`listar_agendamentos_hoje`, `listar_medicos`, `buscar_paciente`, `listar_usuarios`,
`taxa_absenteismo`, `listar_agendamentos_risco_alto`, `historico_absenteismo_paciente`,
`listar_eventos_overbooking`, `listar_realocacoes`, `listar_tickets`,
`listar_relatorios_ia`, `listar_email_logs`, `listar_email_queue`,
`enviar_email` (SendGrid), `enviar_whatsapp` (Z-API). Todas escopadas por clínica.
`kind=report` → `tb_scheduled_reports`; `kind=action` + `notifyEmail` → e-mail do resumo.

### Deploy
```bash
firebase deploy --only functions:ia:scheduledTasksCron
```
(secrets `AZURE_AI_KEY` e `SENDGRID_API_KEY`; habilita Cloud Scheduler/Pub-Sub.)

> Observação: o agente do cron usa um **subconjunto** de ferramentas (Node),
> enquanto o app (Dart) expõe o catálogo MCP completo. Para paridade total,
> portar mais tools para Node ou apontar o cron ao MCP do backend existente.

## Segurança / próximos passos
- Restrinja `Access-Control-Allow-Origin` ao domínio do app em produção.
- Opcional: exigir **App Check** ou validar o `__session`/ID token do Firebase
  Auth dentro da função antes de repassar à Azure (recomendado para evitar abuso).
- O isolamento por clínica é garantido no cliente (MCP), mas para defesa em
  profundidade você pode validar o `clinicaId` do usuário no proxy também.
