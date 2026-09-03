# Estrutura do Banco de Dados Firestore

Este documento contém a estrutura atualizada das coleções do Firestore para o projeto **agendaclinica-457713**, analisada automaticamente a partir de dados reais.

> **Três origens neste documento.**
>
> 1. **Amostragem automática** — de "Detalhes das Coleções" até "Coleções do app
>    Flutter", geradas a partir de documentos reais em produção. O tipo de cada
>    campo vem de **um** documento de exemplo, então campo opcional ou com tipo
>    variável entre documentos pode não aparecer.
> 2. **Schema do código** — a seção "Coleções do app Flutter" descreve coleções
>    criadas por este repositório; extraída do código-fonte, porque algumas ainda
>    podem não ter documento nenhum em produção.
> 3. **Análise** — a seção "Problemas estruturais" logo abaixo é conclusão sobre
>    o schema, verificada contra o código e contra `firestore.indexes.json`.
>
> Ao regerar a parte automática, **preserve as seções 2 e 3**.

## Resumo das Coleções

Total de coleções: 62

| Coleção | Status | Documento de Exemplo |
| --- | --- | --- |
| [`agents`](#agents) | ✅ Ativa | `66EMAJ0h7q0TJAfvWaGQ` |
| [`anexos`](#anexos) | ✅ Ativa | `03JsmnYII6WtMuPJ7tfF` |
| [`chat_history`](#chat_history) | ✅ Ativa | `0FAvEvPtCmEqrRHDy1fJ` |
| [`chats`](#chats) | ✅ Ativa | `0SECkmpPO0jRmHabcnD4` |
| [`dashboard_risco`](#dashboard_risco) | ✅ Ativa | `0LrT10GNQEjPmTSNZPoq` |
| [`email_logs`](#email_logs) | ✅ Ativa | `02rGiQ2hYI2rRLGm49i2` |
| [`email_queue`](#email_queue) | ✅ Ativa | `00Ejq79Hn4lPxWNjDg5S` |
| [`ff_push_notifications`](#ff_push_notifications) | ✅ Ativa | `02N5DxvbR3CqsOQ9GWhm` |
| [`ff_user_push_notifications`](#ff_user_push_notifications) | ✅ Ativa | `5UmwDal0e1LdmXR95oY8` |
| [`historico_agenda_clinica`](#historico_agenda_clinica) | ✅ Ativa | `66CkdQBLg3nesptEtLHG` |
| [`log_acesso`](#log_acesso) | ✅ Ativa | `0KEToieq0u6ttl1VENU4` |
| [`notices`](#notices) | ✅ Ativa | `tCRazPzfxK97arun9gxL` |
| [`patient_reputation`](#patient_reputation) | ✅ Ativa | `00357184256` |
| [`push_metrics`](#push_metrics) | ✅ Ativa | `7sfrnUAwKZzDkZm9rYF3` |
| [`queue_realoc`](#queue_realoc) | ✅ Ativa | `01v6KCdVk6jPgdFTU9Dv` |
| [`queues`](#queues) | ✅ Ativa | `queue_financeiro` |
| [`register_voice`](#register_voice) | ✅ Ativa | `7E1trXSrlKXw97FMhI73` |
| [`session_chat`](#session_chat) | ✅ Ativa | `0x4MnvQ5fIMTrnofCuKf` |
| [`tb_agendamentos`](#tb_agendamentos) | ✅ Ativa | `001yhba1I7XDCgxWu6JS` |
| [`tb_avaliacoes`](#tb_avaliacoes) | ✅ Ativa | `6MZDY0MPyQxEMh1da4QN` |
| [`tb_clinica`](#tb_clinica) | ✅ Ativa | `2os7CEQ7BEgqXrFPsjis` |
| [`tb_comment_clinicas`](#tb_comment_clinicas) | ✅ Ativa | `Wv626QC9jtCWHzuvA77H` |
| [`tb_comment_user`](#tb_comment_user) | ✅ Ativa | `022V3q3wybZ300B6J2H9` |
| [`tb_config`](#tb_config) | ✅ Ativa | `overbooking` |
| [`tb_config_consistency_logs`](#tb_config_consistency_logs) | ✅ Ativa | `12Gji5nxTDQZG9lKaHG5` |
| [`tb_config_logs`](#tb_config_logs) | ✅ Ativa | `W2bPyW8pselaxZWcp5lA` |
| [`tb_config_whatsapp`](#tb_config_whatsapp) | ✅ Ativa | `ACQl1dZYw92J5awZqm5B` |
| [`tb_configuracao_chat`](#tb_configuracao_chat) | ✅ Ativa | `7cjhvAEvrvGOwuh8zrCA` |
| [`tb_confirmationHistory`](#tb_confirmationHistory) | ✅ Ativa | `04mwp0gIjKsEYS6w1Qld` |
| [`tb_conversas`](#tb_conversas) | ✅ Ativa | `8AShrfF2fm1czzj0mPl8` |
| [`tb_faltas_data`](#tb_faltas_data) | ✅ Ativa | `004wFAmOYnyswVuJk9jH` |
| [`tb_favoritos`](#tb_favoritos) | ✅ Ativa | `5yCU23yMaeRqzbP1TWL9` |
| [`tb_historico`](#tb_historico) | ✅ Ativa | `vdyJw4JNcQPPe7EjPEcj` |
| [`tb_horaios_atendimento`](#tb_horaios_atendimento) | ✅ Ativa | `AntVLT9EwCIxvk0kKUuj` |
| [`tb_hour_agenda`](#tb_hour_agenda) | ✅ Ativa | `0hC8uwyFw890dGh5bscV` |
| [`tb_hour_atendimento_medico`](#tb_hour_atendimento_medico) | ✅ Ativa | `1LEmigX6mxgZlReJJWcp` |
| [`tb_lembrete`](#tb_lembrete) | ✅ Ativa | `XBudovtLJb2HVOaR38vJ` |
| [`tb_lembrete_controle`](#tb_lembrete_controle) | ✅ Ativa | `001yhba1I7XDCgxWu6JS` |
| [`tb_limit_app`](#tb_limit_app) | ✅ Ativa | `37vKcUh3dVuz0P6maryu` |
| [`tb_medicos`](#tb_medicos) | ✅ Ativa | `1U7uzL26dYhROXraqyql` |
| [`tb_medicos_config_history`](#tb_medicos_config_history) | ✅ Ativa | `6uRLpMIHcGIqy2OGnYKJ` |
| [`tb_overbooking_events`](#tb_overbooking_events) | ✅ Ativa | `00wP2dgepKho50sAKiNk` |
| [`tb_overbooking_reports`](#tb_overbooking_reports) | ✅ Ativa | `4hZ6HpLSQGE9MN9JicM5` |
| [`tb_plan_user`](#tb_plan_user) | ✅ Ativa | `3gGNlFKziIKfjGG8I3uI` |
| [`tb_plans`](#tb_plans) | ✅ Ativa | `Ej0hEdh04luMb0uSns1T` |
| [`tb_pre_agendamentos`](#tb_pre_agendamentos) | ✅ Ativa | `1ON3sFQdPxc3MSUghEof` |
| [`tb_relatorio_ia`](#tb_relatorio_ia) | ✅ Ativa | `04hXYI5eWTfrKeF7OL8V` |
| [`tb_service`](#tb_service) | ✅ Ativa | `9KuB1cx29VZ4STMdxyjr` |
| [`tb_tarefas`](#tb_tarefas) | ✅ Ativa | `CWVv0tXyRaKiWv7ZMgco` |
| [`tb_term`](#tb_term) | ✅ Ativa | `N5pDFty6rrpLiyEptnYC` |
| [`tb_users_term`](#tb_users_term) | ✅ Ativa | `N9TxKff7AriOVLOsHssW` |
| [`tb_views_medicos`](#tb_views_medicos) | ✅ Ativa | `B6KzYzieV5sUoxbF5LKc` |
| [`test_permissions`](#test_permissions) | ✅ Ativa | `test` |
| [`tickets`](#tickets) | ✅ Ativa | `HVfKqPrzrTO4wSg09RAh` |
| [`users`](#users) | ✅ Ativa | `05HvHSm4poo4IOEbkrkD` |

---

---

## Problemas estruturais

Conclusões da análise de 2026-09-02, verificadas contra o código do app, contra
as Cloud Functions e contra `firestore.indexes.json`. Não vêm de amostragem.

> **Limitação:** não houve acesso à base viva nesta análise (o servidor MCP do
> Firebase não conectou). Contagens de documentos e presença real de campos
> continuam por confirmar; tudo abaixo se apoia em schema, índices e código.

### 🔴 P1 — A chave de tenant tem cinco grafias

| Grafia | Ocorrências no schema | Onde aparece |
| --- | --- | --- |
| `idclinica` | 22 | maioria da base legada |
| `clinicaId` | 14 | coleções criadas por este app |
| `clinica` | 3 | `dashboard_risco` (como `string`, não `reference`) |
| `idClinica` | 2 | `tb_agendamentos`, `queue_realoc` |
| `clinicId` | 1 | `notices` |

O caso grave é **`tb_agendamentos`, que tem `idClinica` e `idclinica` no mesmo
documento** — dois campos, mesma semântica. Pior: `firestore.indexes.json` tem
índices publicados para **três** grafias nessa coleção:

    idclinica    18 índices
    idClinica     2 índices
    id_clinica    1 índice     ← nem sequer aparece no schema amostrado

O app compensa com **fan-out de assinaturas** em
`appointment_service.dart:208-209`: abre uma query por grafia e mescla os
resultados deduplicando por id. Funciona, e custa o dobro de leituras e de
listeners por clínica. `watchForDoctor` faz o mesmo com **três** formatos de
`idMedico` (referência, id cru, caminho `tb_medicos/<id>`) — 3× as leituras.

Nada cobre `id_clinica`. Se existir documento com essa grafia, ele é invisível
para o app.

**Correção sugerida (ordem importa):**

1. Escolher `idclinica` como canônica — é a grafia com 22 ocorrências, 18
   índices e todas as Cloud Functions. Trocar para `clinicaId` obrigaria a
   migrar a base inteira e republicar índices.
2. Backfill: para todo documento com `idClinica` ou `id_clinica` e sem
   `idclinica`, gravar `idclinica`. Feito por Cloud Function em lote.
3. Só depois: remover o fan-out do app e apagar os índices órfãos.
4. Congelar a regra num teste que falhe se alguma escrita nova usar outra
   grafia.

**Não faça o passo 3 antes do 2.** Remover o fan-out com a base ainda mista
esconde agendamentos sem erro nenhum — some da tela e ninguém percebe.

### 🔴 P2 — `tb_absenteismo_scores` existe nos índices e ninguém lê

Quatro índices publicados:

    clinicaId, outcome, dataConsulta
    clinicaId, outcome, riskScore
    outcome, dataConsulta
    outcome, riskScore

`outcome` + `riskScore` + `dataConsulta` por clínica é **exatamente** o
histórico que a calibração do módulo Monte Carlo precisa e não encontra hoje —
ela cai no `appointmentsProvider`, que só carrega a janela operacional da
agenda. Nenhum arquivo em `lib/` ou `functions/` menciona a coleção.

Ou ela está populada e o app ignora a melhor fonte que tem, ou está vazia e há
quatro índices sendo mantidos à toa. **Verificar antes de qualquer outra coisa
na fase F2** — muda o desenho da calibração.

### 🟡 P3 — Três coleções indexadas e não documentadas

| Coleção | Índices | Código que usa |
| --- | --- | --- |
| `chat_response` | `tel+created_at`, `tel+date` | nenhum |
| `tb_agent_actions` | `status+executedAt` | nenhum |
| `tb_agent_plans` | `clinicaId+createdAt` | `agent_plans_service.dart` ✅ |

`tb_agent_plans` é do app e faltava neste documento — corrigido abaixo. As duas
primeiras não têm consumidor: ou são de um pipeline externo (n8n?), ou são
resíduo de código removido. Índice sem consumidor custa escrita em toda
gravação da coleção.

### 🟡 P4 — Mesma informação com tipos diferentes

| Campo | Coleção | Tipo | Deveria |
| --- | --- | --- | --- |
| `tipo_consulta` | `tb_historico` | `timestamp` | `string` — o nome diz o que é |
| `telefone` | `tb_conversas` | `number` | `string` |
| `tel` | `chat_history`, `session_chat` | `number` | `string` |
| `idclinica` | `tb_avaliacoes`, `tb_historico`, `tb_relatorio_ia` | `string` | `reference`, como nas demais |
| `clinica` | `dashboard_risco` | `string` | idem |

**Telefone como número é defeito, não estilo.** Perde zero à esquerda, estoura
precisão em número internacional longo e impede prefixo com `+`. As coleções
que acertam (`tb_agendamentos.telefonePaciente`, `queue_realoc`) usam `string`.

`tb_historico.tipo_consulta` como `timestamp` provavelmente é campo trocado na
escrita — vale conferir o produtor antes de migrar.

### 🟡 P5 — Denormalização que vai estourar o limite de documento

`tb_configuracao_chat.medicos` é um `array<map>` com o **cadastro inteiro** de
cada médico: dados pessoais, especialidades, foto, ticket e a agenda completa
dos sete dias da semana. É uma cópia de `tb_medicos` dentro de um documento de
configuração.

Dois problemas: o documento cresce com o número de médicos e **o teto do
Firestore é 1 MB**; e a cópia envelhece — alterar o horário em `tb_medicos` não
atualiza aqui.

O mesmo vale para `tb_configuracao_chat.clinica`, que duplica campos de
`tb_clinica` e ainda acrescenta `cidade`, `estado`, `endereco`, `site`,
`modalidade` e `especialidades` — que **não existem** em `tb_clinica`. Ou seja:
a fonte de verdade do endereço da clínica hoje é um documento de configuração
de chat.

### 🟡 P6 — CPF como id de documento

`patient_reputation` usa o CPF como id (`00357184256`) e ainda guarda `cpf`
dentro. Id de documento aparece em log de acesso, em chave de índice, em URL de
console e em mensagem de erro — lugares onde dado pessoal não deveria estar, e
que não se apagam com um `delete` do documento.

`tb_avaliacoes.pacienteCpf` e `tb_agendamentos.cpf` guardam CPF em campo, o que
é tratável; o id não é.

**Correção:** id sintético (o próprio `patientId`) e CPF só em campo, para poder
ser apagado a pedido do titular sem recriar o documento.

### 🟢 P7 — Campos de depuração em produção

`tb_faltas_data._debug_agendamentoId` e `._debug_clinicId` duplicam
`idConsulta` e `idclinica`, que já existem como `reference` no mesmo documento.
Custam escrita e espaço em toda predição gravada.

### 🟢 P8 — Data representada três vezes

`dashboard_risco` guarda `timestampConsulta` (`timestamp`), `dataConsulta`
(`string`) **e** `ano`/`mes`/`dia`/`hora` como números separados. Três
representações que podem divergir; a decomposição em números só se justifica se
houver agregação que dependa dela — e aí o custo é manter as três em sincronia.

### 🟢 P9 — Erros de digitação congelados no schema

| Onde | Está | Deveria |
| --- | --- | --- |
| coleção | `tb_horaios_atendimento` | `tb_horarios_atendimento` |
| `tb_medicos` | `horaiosAtendimento` | `horariosAtendimento` |
| `tb_medicos` | `tiket` | `ticket` (grafia usada em `tb_agendamentos`) |
| `tb_config_whatsapp` | `intanceId` | `instanceId` |

O app já convive com eles (`doctor_service.dart:189,244` lê e escreve `tiket`),
com comentário explicando. **Renomear exige migração** — enquanto não houver,
o valor deste registro é evitar que alguém "conserte" um lado só e quebre o
outro.

### Resumo de prioridade

| # | Problema | Impacto | Bloqueia |
| --- | --- | --- | --- |
| P1 | Cinco grafias de tenant | Dobra leituras; risco de sumiço silencioso | Redução de custo |
| P2 | `tb_absenteismo_scores` órfã | Pode ser a fonte de histórico que falta | Fase F2 da calibração |
| P3 | Índices sem consumidor | Custo de escrita | — |
| P4 | Tipos divergentes | Telefone perde dígito | Integração WhatsApp |
| P5 | Denormalização de médicos | Teto de 1 MB, dado velho | Clínica com muitos médicos |
| P6 | CPF como id | LGPD | Auditoria |
| P7–P9 | Debug, data triplicada, typos | Custo e confusão | — |

---

## Detalhes das Coleções

### <a name="agents"></a>`agents`

- **ID de Exemplo**: `66EMAJ0h7q0TJAfvWaGQ`

| Campo | Tipo |
| --- | --- |
| `name` | `string` |
| `email` | `string` |
| `status` | `string` |
| `skills` | `array<string>` |
| `assignedQueues` | `array<string>` |
| `accessPin` | `string` |
| `joinedAt` | `timestamp` |
| `metrics` | `map` |
| `metrics.maxConcurrentChats` | `number` |
| `metrics.totalChatsToday` | `number` |
| `metrics.averageResponseTime` | `number` |
| `metrics.satisfactionScore` | `number` |
| `metrics.activeChats` | `number` |

---

### <a name="anexos"></a>`anexos`

- **ID de Exemplo**: `03JsmnYII6WtMuPJ7tfF`

| Campo | Tipo |
| --- | --- |
| `id_ref_re` | `string` |
| `id_re` | `string` |
| `pdf_url` | `string` |
| `pdf_view` | `string` |
| `date` | `string` |
| `xlsx` | `string` |

---

### <a name="chat_history"></a>`chat_history`

- **ID de Exemplo**: `0FAvEvPtCmEqrRHDy1fJ`

| Campo | Tipo |
| --- | --- |
| `content` | `string` |
| `updatedAt` | `timestamp` |
| `tel` | `number` |
| `send` | `string` |
| `idmsg` | `string` |

---

### <a name="chats"></a>`chats`

- **ID de Exemplo**: `0SECkmpPO0jRmHabcnD4`

| Campo | Tipo |
| --- | --- |
| `userId` | `string` |
| `title` | `string` |
| `messages` | `array<map>` |
| `messages[].id` | `string` |
| `messages[].role` | `string` |
| `messages[].content` | `string` |
| `messages[].files` | `array<map>` |
| `messages[].files[].name` | `string` |
| `messages[].files[].mimeType` | `string` |
| `createdAt` | `timestamp` |
| `updatedAt` | `timestamp` |

---

### <a name="dashboard_risco"></a>`dashboard_risco`

- **ID de Exemplo**: `0LrT10GNQEjPmTSNZPoq`

| Campo | Tipo |
| --- | --- |
| `riscoPercent` | `number` |
| `risco` | `number` |
| `foiIgnorado` | `boolean` |
| `riscoLabel` | `string` |
| `statusConsulta` | `string` |
| `foiEnviado` | `boolean` |
| `duplicado` | `boolean` |
| `mes` | `number` |
| `hora` | `number` |
| `ano` | `number` |
| `dia` | `number` |
| `prioridade` | `string` |
| `clinica` | `string` |
| `paciente` | `string` |
| `medico` | `string` |
| `timestampConsulta` | `timestamp` |
| `appointmentId` | `string` |
| `dataConsulta` | `string` |
| `origem` | `string` |
| `createdAt` | `timestamp` |

---

### <a name="email_logs"></a>`email_logs`

- **ID de Exemplo**: `02rGiQ2hYI2rRLGm49i2`

| Campo | Tipo |
| --- | --- |
| `appointmentId` | `string` |
| `email` | `string` |
| `type` | `string` |
| `sentAt` | `timestamp` |

---

### <a name="email_queue"></a>`email_queue`

- **ID de Exemplo**: `00Ejq79Hn4lPxWNjDg5S`

| Campo | Tipo |
| --- | --- |
| `appointmentId` | `string` |
| `createdAt` | `timestamp` |
| `isFake` | `boolean` |
| `fakeBatchId` | `string` |
| `erro` | `string` |
| `tentativas` | `number` |
| `processingAt` | `timestamp` |
| `skipped` | `boolean` |
| `status` | `string` |

---

### <a name="ff_push_notifications"></a>`ff_push_notifications`

- **ID de Exemplo**: `02N5DxvbR3CqsOQ9GWhm`

| Campo | Tipo |
| --- | --- |
| `notification_title` | `string` |
| `notification_text` | `string` |
| `target_audience` | `string` |
| `user_refs` | `string` |
| `initial_page_name` | `string` |
| `parameter_data` | `map` |
| `parameter_data.id` | `string` |
| `parameter_data.nome` | `string` |
| `parameter_data.medico` | `string` |
| `parameter_data.data` | `string` |
| `parameter_data.status` | `string` |
| `parameter_data.risco` | `number` |
| `parameter_data.prioridade` | `number` |
| `created_at` | `timestamp` |
| `num_sent` | `number` |
| `status` | `string` |

---

### <a name="ff_user_push_notifications"></a>`ff_user_push_notifications`

- **ID de Exemplo**: `5UmwDal0e1LdmXR95oY8`

| Campo | Tipo |
| --- | --- |
| `notification_title` | `string` |
| `notification_text` | `string` |
| `notification_image_url` | `string` |
| `user_refs` | `string` |
| `initial_page_name` | `string` |
| `parameter_data` | `string` |
| `sender` | `reference` |
| `timestamp` | `timestamp` |
| `num_sent` | `number` |
| `status` | `string` |

---

### <a name="historico_agenda_clinica"></a>`historico_agenda_clinica`

- **ID de Exemplo**: `66CkdQBLg3nesptEtLHG`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `reference` |
| `nome` | `string` |
| `iduser` | `reference` |
| `foto` | `string` |
| `date` | `timestamp` |

---

### <a name="log_acesso"></a>`log_acesso`

- **ID de Exemplo**: `0KEToieq0u6ttl1VENU4`

| Campo | Tipo |
| --- | --- |
| `userRef` | `reference` |
| `userEmail` | `string` |
| `userName` | `string` |
| `sessionId` | `string` |
| `pageName` | `string` |
| `pageRoute` | `string` |
| `deviceOS` | `string` |
| `locale` | `string` |
| `screenWidth` | `string` |
| `screenHeight` | `string` |
| `timestamp` | `timestamp` |

---

### <a name="notices"></a>`notices`

- **ID de Exemplo**: `tCRazPzfxK97arun9gxL`

| Campo | Tipo |
| --- | --- |
| `author` | `string` |
| `content` | `string` |
| `clinicId` | `string` |
| `type` | `string` |
| `createdAt` | `timestamp` |

---

### <a name="patient_reputation"></a>`patient_reputation`

- **ID de Exemplo**: `00357184256`

| Campo | Tipo |
| --- | --- |
| `patientName` | `string` |
| `score` | `number` |
| `lastImpact` | `null` |
| `level` | `string` |
| `patientId` | `string` |
| `trend` | `string` |
| `cpf` | `string` |
| `history` | `array<any>` |
| `totalAppointments` | `number` |
| `totalNoShows` | `number` |
| `updatedAt` | `timestamp` |

---

### <a name="push_metrics"></a>`push_metrics`

- **ID de Exemplo**: `7sfrnUAwKZzDkZm9rYF3`

| Campo | Tipo |
| --- | --- |
| `prioridade` | `string` |
| `risco` | `number` |
| `appointmentId` | `string` |
| `createdAt` | `timestamp` |

---

### <a name="queue_realoc"></a>`queue_realoc`

- **ID de Exemplo**: `01v6KCdVk6jPgdFTU9Dv`

| Campo | Tipo |
| --- | --- |
| `cpfPaciente` | `string` |
| `dataOriginal` | `timestamp` |
| `horarioOriginal` | `string` |
| `emailPaciente` | `string` |
| `especialidade` | `string` |
| `idClinica` | `reference` |
| `idConsultaOriginal` | `reference` |
| `idMedico` | `reference` |
| `idPaciente` | `reference` |
| `nomeMedico` | `string` |
| `nomePaciente` | `string` |
| `novaData` | `timestamp` |
| `novoHorario` | `string` |
| `telefonePaciente` | `string` |
| `executionId` | `string` |
| `createdAt` | `timestamp` |
| `processado` | `boolean` |
| `status` | `string` |
| `updatedAt` | `timestamp` |

---

### <a name="queues"></a>`queues`

- **ID de Exemplo**: `queue_financeiro`

| Campo | Tipo |
| --- | --- |
| `id` | `string` |
| `name` | `string` |
| `distributionStrategy` | `string` |
| `tags` | `array<string>` |
| `status` | `string` |
| `type` | `string` |
| `priority` | `number` |
| `sla` | `map` |
| `sla.firstResponse` | `number` |
| `sla.resolution` | `number` |
| `capacity` | `map` |
| `capacity.maxQueueSize` | `number` |
| `capacity.maxConcurrentChats` | `number` |
| `createdAt` | `timestamp` |

---

### <a name="register_voice"></a>`register_voice`

- **ID de Exemplo**: `7E1trXSrlKXw97FMhI73`

| Campo | Tipo |
| --- | --- |
| `url_audio` | `string` |
| `id` | `string` |

---

### <a name="session_chat"></a>`session_chat`

- **ID de Exemplo**: `0x4MnvQ5fIMTrnofCuKf`

| Campo | Tipo |
| --- | --- |
| `status` | `string` |
| `etapa` | `string` |
| `confirmado` | `boolean` |
| `updatedAt` | `timestamp` |
| `tel` | `number` |

---

### <a name="tb_agendamentos"></a>`tb_agendamentos`

- **ID de Exemplo**: `001yhba1I7XDCgxWu6JS`

| Campo | Tipo |
| --- | --- |
| `confirmationToken` | `string` |
| `confirmationTokenValidUntil` | `timestamp` |
| `cpf` | `string` |
| `createdAt` | `timestamp` |
| `dataConsulta` | `timestamp` |
| `emailPaciente` | `string` |
| `especialidade` | `string` |
| `formaPagamento` | `string` |
| `idClinica` | `reference` |
| `idMedico` | `reference` |
| `idPaciente` | `reference` |
| `idclinica` | `reference` |
| `localConsulta` | `string` |
| `modalidade` | `string` |
| `motivoConsulta` | `string` |
| `nomeMedico` | `string` |
| `nomePaciente` | `string` |
| `status` | `string` |
| `telefonePaciente` | `string` |
| `ticket` | `number` |
| `tipoConsulta` | `string` |
| `updatedAt` | `timestamp` |
| `isFake` | `boolean` |
| `fakeBatchId` | `string` |
| `calendarSyncStatus` | `string` |
| `calendarSyncError` | `string` |

---

### <a name="tb_avaliacoes"></a>`tb_avaliacoes`

- **ID de Exemplo**: `6MZDY0MPyQxEMh1da4QN`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `string` |
| `pacienteNome` | `string` |
| `pacienteTelefone` | `string` |
| `pacienteEmail` | `string` |
| `pacienteCpf` | `string` |
| `notaSistema` | `number` |
| `notaUnidade` | `number` |
| `notaProfissionais` | `number` |
| `notaAtendimento` | `number` |
| `comentario` | `string` |
| `protocolo` | `string` |
| `idagendamento` | `string` |
| `createdAt` | `timestamp` |

---

### <a name="tb_clinica"></a>`tb_clinica`

- **ID de Exemplo**: `2os7CEQ7BEgqXrFPsjis`

| Campo | Tipo |
| --- | --- |
| `nome` | `string` |
| `email` | `string` |
| `status` | `string` |
| `dataCadastro` | `timestamp` |
| `telefone` | `string` |
| `photoClinica` | `string` |

---

### <a name="tb_comment_clinicas"></a>`tb_comment_clinicas`

- **ID de Exemplo**: `Wv626QC9jtCWHzuvA77H`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `reference` |
| `iduser` | `reference` |
| `avaliacao` | `number` |
| `date` | `timestamp` |
| `dateUpdate` | `timestamp` |
| `content` | `string` |

---

### <a name="tb_comment_user"></a>`tb_comment_user`

- **ID de Exemplo**: `022V3q3wybZ300B6J2H9`

| Campo | Tipo |
| --- | --- |
| `iduser` | `reference` |
| `idclinica` | `reference` |
| `rate` | `number` |
| `content` | `string` |
| `name` | `string` |
| `photo` | `string` |
| `dateCt` | `timestamp` |
| `updateCt` | `timestamp` |
| `state` | `string` |

---

### <a name="tb_config"></a>`tb_config`

- **ID de Exemplo**: `overbooking`

| Campo | Tipo |
| --- | --- |
| `diasAnalise` | `number` |
| `maxConcorrencia` | `number` |
| `maxEmailsPorBatch` | `number` |
| `retryAttempts` | `number` |
| `retryBaseDelay` | `number` |
| `rateLimitDelayMs` | `number` |
| `enableRealocacao` | `boolean` |
| `enableNotificacao` | `boolean` |
| `alertEmail` | `string` |

---

### <a name="tb_config_consistency_logs"></a>`tb_config_consistency_logs`

- **ID de Exemplo**: `12Gji5nxTDQZG9lKaHG5`

| Campo | Tipo |
| --- | --- |
| `totalMedicos` | `number` |
| `inconsistentes` | `number` |
| `corrigidos` | `number` |
| `detalhes` | `array<map>` |
| `detalhes[].medicoId` | `string` |
| `detalhes[].nome` | `string` |
| `detalhes[].camposCorrigidos` | `array<string>` |
| `dataVerificacao` | `timestamp` |

---

### <a name="tb_config_logs"></a>`tb_config_logs`

- **ID de Exemplo**: `W2bPyW8pselaxZWcp5lA`

| Campo | Tipo |
| --- | --- |
| `tipo` | `string` |
| `medicoId` | `string` |
| `medicoNome` | `string` |
| `camposConfigurados` | `array<string>` |
| `triggerData` | `timestamp` |

---

### <a name="tb_config_whatsapp"></a>`tb_config_whatsapp`

- **ID de Exemplo**: `ACQl1dZYw92J5awZqm5B`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `reference` |
| `idUser` | `reference` |
| `tokenCliente` | `string` |
| `intanceId` | `string` |
| `token` | `string` |
| `date` | `timestamp` |
| `active` | `number` |

---

### <a name="tb_configuracao_chat"></a>`tb_configuracao_chat`

- **ID de Exemplo**: `7cjhvAEvrvGOwuh8zrCA`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `reference` |
| `ativo` | `boolean` |
| `clinica` | `map` |
| `clinica.nome` | `string` |
| `clinica.cidade` | `string` |
| `clinica.estado` | `string` |
| `clinica.endereco` | `string` |
| `clinica.telefone` | `string` |
| `clinica.site` | `string` |
| `clinica.modalidade` | `array<string>` |
| `clinica.especialidades` | `array<string>` |
| `clinica.photoClinica` | `string` |
| `medicos` | `array<map>` |
| `medicos[].id` | `reference` |
| `medicos[].nome` | `string` |
| `medicos[].crm` | `string` |
| `medicos[].email` | `string` |
| `medicos[].telefone` | `string` |
| `medicos[].especialidades` | `array<string>` |
| `medicos[].biografia` | `string` |
| `medicos[].foto` | `string` |
| `medicos[].ticket` | `number` |
| `medicos[].modalidade` | `array<string>` |
| `medicos[].status` | `boolean` |
| `medicos[].agenda` | `map` |
| `medicos[].agenda.semana` | `map` |
| `medicos[].agenda.semana.domingo` | `map` |
| `medicos[].agenda.semana.domingo.ativo` | `boolean` |
| `medicos[].agenda.semana.domingo.inicio` | `string` |
| `medicos[].agenda.semana.domingo.fim` | `string` |
| `medicos[].agenda.semana.segunda` | `map` |
| `medicos[].agenda.semana.segunda.ativo` | `boolean` |
| `medicos[].agenda.semana.segunda.inicio` | `string` |
| `medicos[].agenda.semana.segunda.fim` | `string` |
| `medicos[].agenda.semana.terca` | `map` |
| `medicos[].agenda.semana.terca.ativo` | `boolean` |
| `medicos[].agenda.semana.terca.inicio` | `string` |
| `medicos[].agenda.semana.terca.fim` | `string` |
| `medicos[].agenda.semana.quarta` | `map` |
| `medicos[].agenda.semana.quarta.ativo` | `boolean` |
| `medicos[].agenda.semana.quarta.inicio` | `string` |
| `medicos[].agenda.semana.quarta.fim` | `string` |
| `medicos[].agenda.semana.quinta` | `map` |
| `medicos[].agenda.semana.quinta.ativo` | `boolean` |
| `medicos[].agenda.semana.quinta.inicio` | `string` |
| `medicos[].agenda.semana.quinta.fim` | `string` |
| `medicos[].agenda.semana.sexta` | `map` |
| `medicos[].agenda.semana.sexta.ativo` | `boolean` |
| `medicos[].agenda.semana.sexta.inicio` | `string` |
| `medicos[].agenda.semana.sexta.fim` | `string` |
| `medicos[].agenda.semana.sabado` | `map` |
| `medicos[].agenda.semana.sabado.ativo` | `boolean` |
| `medicos[].agenda.semana.sabado.inicio` | `string` |
| `medicos[].agenda.semana.sabado.fim` | `string` |
| `medicos[].agenda.slotsDisponiveis` | `array<any>` |
| `dtregistro` | `timestamp` |

---

### <a name="tb_confirmationHistory"></a>`tb_confirmationHistory`

- **ID de Exemplo**: `04mwp0gIjKsEYS6w1Qld`

| Campo | Tipo |
| --- | --- |
| `action` | `string` |
| `appointmentId` | `string` |
| `patientName` | `string` |
| `appointmentDate` | `timestamp` |

---

### <a name="tb_conversas"></a>`tb_conversas`

- **ID de Exemplo**: `8AShrfF2fm1czzj0mPl8`

| Campo | Tipo |
| --- | --- |
| `idref` | `string` |
| `error` | `null` |
| `status` | `string` |
| `idclinica` | `string` |
| `telefone` | `number` |
| `name` | `string` |
| `messageType` | `string` |
| `direction` | `string` |
| `text_bot` | `string` |
| `text` | `string` |
| `dt_register` | `timestamp` |
| `ip` | `string` |
| `messageId` | `string` |
| `photo` | `string` |

---

### <a name="tb_faltas_data"></a>`tb_faltas_data`

- **ID de Exemplo**: `004wFAmOYnyswVuJk9jH`

| Campo | Tipo |
| --- | --- |
| `idpaciente` | `reference` |
| `idConsulta` | `reference` |
| `idclinica` | `reference` |
| `idMedico` | `reference` |
| `idMedicoId` | `string` |
| `data_consulta` | `timestamp` |
| `valor_predicao` | `number` |
| `probabilidade_falta` | `number` |
| `risco_falta` | `string` |
| `processado` | `boolean` |
| `_debug_agendamentoId` | `string` |
| `_debug_clinicId` | `string` |
| `createdAt` | `timestamp` |
| `data_falta_consulta` | `timestamp` |

---

### <a name="tb_favoritos"></a>`tb_favoritos`

- **ID de Exemplo**: `5yCU23yMaeRqzbP1TWL9`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `reference` |
| `iduser` | `reference` |
| `nome` | `string` |
| `foto` | `string` |
| `local` | `string` |
| `km` | `number` |
| `dtCreated` | `timestamp` |
| `dtUpdate` | `timestamp` |

---

### <a name="tb_historico"></a>`tb_historico`

- **ID de Exemplo**: `vdyJw4JNcQPPe7EjPEcj`

| Campo | Tipo |
| --- | --- |
| `presenca_ultimas_consultas` | `array<number>` |
| `idclinica` | `string` |
| `id_paciente` | `string` |
| `distancia_clinica_km` | `number` |
| `tipo_remarcacao` | `string` |
| `meio_lembrete` | `string` |
| `recebeu_lembrete` | `string` |
| `tempo_ultimo_contato` | `number` |
| `sexo` | `string` |
| `plano_saude` | `string` |
| `confirmado` | `string` |
| `historico_faltas` | `string` |
| `tempo_espera` | `number` |
| `primeira_consulta` | `string` |
| `faixa_etaria` | `string` |
| `dia_semana` | `string` |
| `preferencia_contato` | `string` |
| `estado` | `string` |
| `cidade` | `string` |
| `bairro` | `string` |
| `anal_agendamento` | `string` |
| `dias_antecedencia` | `number` |
| `tipo_consulta` | `timestamp` |
| `canal_agendamento` | `string` |

---

### <a name="tb_horaios_atendimento"></a>`tb_horaios_atendimento`

- **ID de Exemplo**: `AntVLT9EwCIxvk0kKUuj`

| Campo | Tipo |
| --- | --- |
| `statusSM` | `array<boolean>` |
| `hourStart` | `array<string>` |
| `idclinica` | `reference` |
| `hourFinal` | `array<string>` |

---

### <a name="tb_hour_agenda"></a>`tb_hour_agenda`

- **ID de Exemplo**: `0hC8uwyFw890dGh5bscV`

| Campo | Tipo |
| --- | --- |
| `startTime` | `timestamp` |
| `endTime` | `timestamp` |
| `vaga` | `number` |
| `status` | `string` |
| `idmedico` | `reference` |
| `idclinica` | `reference` |

---

### <a name="tb_hour_atendimento_medico"></a>`tb_hour_atendimento_medico`

- **ID de Exemplo**: `1LEmigX6mxgZlReJJWcp`

| Campo | Tipo |
| --- | --- |
| `hourFinal` | `array<string>` |
| `hourStart` | `array<string>` |
| `statusSM` | `array<boolean>` |
| `idmedico` | `reference` |
| `idclinica` | `reference` |

---

### <a name="tb_lembrete"></a>`tb_lembrete`

- **ID de Exemplo**: `XBudovtLJb2HVOaR38vJ`

| Campo | Tipo |
| --- | --- |
| `idPaciente` | `reference` |
| `idAgendamento` | `reference` |
| `date` | `timestamp` |

---

### <a name="tb_lembrete_controle"></a>`tb_lembrete_controle`

- **ID de Exemplo**: `001yhba1I7XDCgxWu6JS`

| Campo | Tipo |
| --- | --- |
| `appointmentId` | `string` |
| `pacienteNome` | `string` |
| `emailPaciente` | `string` |
| `telefonePaciente` | `string` |
| `dataConsulta` | `timestamp` |
| `envios` | `array<any>` |
| `totalEnviado` | `number` |
| `ultimoEnvio` | `null` |
| `historicoConfiabilidade` | `array<any>` |
| `versao` | `number` |
| `createdAt` | `timestamp` |
| `ultimoErro` | `string` |
| `ultimoStatus` | `string` |
| `tentativas` | `number` |
| `updatedAt` | `timestamp` |

---

### <a name="tb_limit_app"></a>`tb_limit_app`

- **ID de Exemplo**: `37vKcUh3dVuz0P6maryu`

| Campo | Tipo |
| --- | --- |
| `lt_users` | `number` |
| `tl_consultas` | `number` |
| `idplan` | `reference` |
| `idclinica` | `reference` |

---

### <a name="tb_medicos"></a>`tb_medicos`

- **ID de Exemplo**: `1U7uzL26dYhROXraqyql`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `reference` |
| `nomeCompleto` | `string` |
| `email` | `string` |
| `telefone` | `string` |
| `crm` | `string` |
| `endereco` | `string` |
| `fotoPerfil` | `string` |
| `biografia` | `string` |
| `status` | `boolean` |
| `experiencia` | `string` |
| `tiket` | `number` |
| `especialidades` | `array<string>` |
| `dataAtualizacao` | `timestamp` |
| `dataCriacao` | `timestamp` |
| `horaiosAtendimento` | `reference` |
| `scalaMedico` | `number` |
| `estatisticas` | `map` |
| `estatisticas.realizacoesRealocadas` | `number` |
| `estatisticas.totalConsultasMes` | `number` |
| `estatisticas.mediaFaltas` | `number` |
| `estatisticas.overbookingUtilizado` | `number` |
| `estatisticas.taxaOcupacaoMedia` | `number` |
| `maxOverbook` | `number` |
| `realocacao` | `map` |
| `realocacao.limiteRealocacoesPorDia` | `number` |
| `realocacao.automatica` | `boolean` |
| `realocacao.notificarPaciente` | `boolean` |
| `realocacao.priorizarHorarios` | `array<string>` |
| `realocacao.diasBusca` | `number` |
| `configuracao` | `map` |
| `configuracao.ultimaRevisao` | `null` |
| `configuracao.versao` | `string` |
| `configuracao.dataPadrao` | `null` |
| `notificacao` | `map` |
| `notificacao.templateEmail` | `string` |
| `notificacao.enviarEmail` | `boolean` |
| `notificacao.horarioLimiteNotificacao` | `number` |
| `notificacao.enviarSMS` | `boolean` |
| `notificacao.diasAntecedencia` | `number` |
| `horarioFuncionamento` | `map` |
| `horarioFuncionamento.pausaAlmocoFim` | `string` |
| `horarioFuncionamento.pausaAlmocoInicio` | `string` |
| `horarioFuncionamento.inicio` | `string` |
| `horarioFuncionamento.fim` | `string` |
| `horarioFuncionamento.intervaloConsulta` | `number` |
| `horarioFuncionamento.diasAtendimento` | `array<number>` |
| `limitesSeguranca` | `map` |
| `limitesSeguranca.bloquearAposLimite` | `boolean` |
| `limitesSeguranca.maxPacientesPorDia` | `number` |
| `limitesSeguranca.tempoMinimoEntreConsultas` | `number` |
| `limitesSeguranca.alertaCritico` | `number` |
| `limitesSeguranca.maxPacientesPorHorario` | `number` |
| `overbookingConfig` | `map` |
| `overbookingConfig.saturday` | `map` |
| `overbookingConfig.saturday.descricao` | `string` |
| `overbookingConfig.saturday.maxOverbook` | `number` |
| `overbookingConfig.wednesday` | `map` |
| `overbookingConfig.wednesday.descricao` | `string` |
| `overbookingConfig.wednesday.maxOverbook` | `number` |
| `overbookingConfig.sunday` | `map` |
| `overbookingConfig.sunday.descricao` | `string` |
| `overbookingConfig.sunday.maxOverbook` | `number` |
| `overbookingConfig.monday` | `map` |
| `overbookingConfig.monday.descricao` | `string` |
| `overbookingConfig.monday.maxOverbook` | `number` |
| `overbookingConfig.friday` | `map` |
| `overbookingConfig.friday.descricao` | `string` |
| `overbookingConfig.friday.maxOverbook` | `number` |
| `overbookingConfig.thursday` | `map` |
| `overbookingConfig.thursday.descricao` | `string` |
| `overbookingConfig.thursday.maxOverbook` | `number` |
| `overbookingConfig.tuesday` | `map` |
| `overbookingConfig.tuesday.descricao` | `string` |
| `overbookingConfig.tuesday.maxOverbook` | `number` |
| `limiteSlot` | `number` |
| `overbookingPeriodo` | `map` |
| `overbookingPeriodo.afternoon` | `map` |
| `overbookingPeriodo.afternoon.maxOverbook` | `number` |
| `overbookingPeriodo.afternoon.horarioFim` | `string` |
| `overbookingPeriodo.afternoon.horarioInicio` | `string` |
| `overbookingPeriodo.evening` | `map` |
| `overbookingPeriodo.evening.horarioFim` | `string` |
| `overbookingPeriodo.evening.horarioInicio` | `string` |
| `overbookingPeriodo.evening.maxOverbook` | `number` |
| `overbookingPeriodo.morning` | `map` |
| `overbookingPeriodo.morning.horarioFim` | `string` |
| `overbookingPeriodo.morning.horarioInicio` | `string` |
| `overbookingPeriodo.morning.maxOverbook` | `number` |
| `prioridades` | `map` |
| `prioridades.tipos` | `array<map>` |
| `prioridades.tipos[].peso` | `number` |
| `prioridades.tipos[].descricao` | `string` |
| `prioridades.tipos[].nome` | `string` |
| `prioridades.ativa` | `boolean` |
| `updatedAt` | `timestamp` |

---

### <a name="tb_medicos_config_history"></a>`tb_medicos_config_history`

- **ID de Exemplo**: `6uRLpMIHcGIqy2OGnYKJ`

| Campo | Tipo |
| --- | --- |
| `medicoId` | `string` |
| `medicoNome` | `string` |
| `alteracoes` | `map` |
| `alteracoes.camposAtualizados` | `array<any>` |
| `alteracoes.camposAdicionados` | `array<string>` |
| `alteracoes.updates` | `map` |
| `alteracoes.updates.overbookingPeriodo` | `map` |
| `alteracoes.updates.overbookingPeriodo.evening` | `map` |
| `alteracoes.updates.overbookingPeriodo.evening.maxOverbook` | `number` |
| `alteracoes.updates.overbookingPeriodo.evening.horarioFim` | `string` |
| `alteracoes.updates.overbookingPeriodo.evening.horarioInicio` | `string` |
| `alteracoes.updates.overbookingPeriodo.morning` | `map` |
| `alteracoes.updates.overbookingPeriodo.morning.horarioInicio` | `string` |
| `alteracoes.updates.overbookingPeriodo.morning.maxOverbook` | `number` |
| `alteracoes.updates.overbookingPeriodo.morning.horarioFim` | `string` |
| `alteracoes.updates.overbookingPeriodo.afternoon` | `map` |
| `alteracoes.updates.overbookingPeriodo.afternoon.horarioInicio` | `string` |
| `alteracoes.updates.overbookingPeriodo.afternoon.horarioFim` | `string` |
| `alteracoes.updates.overbookingPeriodo.afternoon.maxOverbook` | `number` |
| `alteracoes.updates.limitesSeguranca` | `map` |
| `alteracoes.updates.limitesSeguranca.alertaCritico` | `number` |
| `alteracoes.updates.limitesSeguranca.maxPacientesPorDia` | `number` |
| `alteracoes.updates.limitesSeguranca.maxPacientesPorHorario` | `number` |
| `alteracoes.updates.limitesSeguranca.tempoMinimoEntreConsultas` | `number` |
| `alteracoes.updates.limitesSeguranca.bloquearAposLimite` | `boolean` |
| `alteracoes.updates.configuracao` | `map` |
| `alteracoes.updates.configuracao.ultimaRevisao` | `null` |
| `alteracoes.updates.configuracao.dataPadrao` | `null` |
| `alteracoes.updates.configuracao.versao` | `string` |
| `alteracoes.updates.notificacao` | `map` |
| `alteracoes.updates.notificacao.enviarEmail` | `boolean` |
| `alteracoes.updates.notificacao.diasAntecedencia` | `number` |
| `alteracoes.updates.notificacao.templateEmail` | `string` |
| `alteracoes.updates.notificacao.horarioLimiteNotificacao` | `number` |
| `alteracoes.updates.notificacao.enviarSMS` | `boolean` |
| `alteracoes.updates.realocacao` | `map` |
| `alteracoes.updates.realocacao.limiteRealocacoesPorDia` | `number` |
| `alteracoes.updates.realocacao.diasBusca` | `number` |
| `alteracoes.updates.realocacao.automatica` | `boolean` |
| `alteracoes.updates.realocacao.priorizarHorarios` | `array<string>` |
| `alteracoes.updates.realocacao.notificarPaciente` | `boolean` |
| `alteracoes.updates.prioridades` | `map` |
| `alteracoes.updates.prioridades.tipos` | `array<map>` |
| `alteracoes.updates.prioridades.tipos[].nome` | `string` |
| `alteracoes.updates.prioridades.tipos[].descricao` | `string` |
| `alteracoes.updates.prioridades.tipos[].peso` | `number` |
| `alteracoes.updates.prioridades.ativa` | `boolean` |
| `alteracoes.updates.maxOverbook` | `number` |
| `alteracoes.updates.limiteSlot` | `number` |
| `alteracoes.updates.overbookingConfig` | `map` |
| `alteracoes.updates.overbookingConfig.wednesday` | `map` |
| `alteracoes.updates.overbookingConfig.wednesday.descricao` | `string` |
| `alteracoes.updates.overbookingConfig.wednesday.maxOverbook` | `number` |
| `alteracoes.updates.overbookingConfig.tuesday` | `map` |
| `alteracoes.updates.overbookingConfig.tuesday.descricao` | `string` |
| `alteracoes.updates.overbookingConfig.tuesday.maxOverbook` | `number` |
| `alteracoes.updates.overbookingConfig.sunday` | `map` |
| `alteracoes.updates.overbookingConfig.sunday.descricao` | `string` |
| `alteracoes.updates.overbookingConfig.sunday.maxOverbook` | `number` |
| `alteracoes.updates.overbookingConfig.friday` | `map` |
| `alteracoes.updates.overbookingConfig.friday.descricao` | `string` |
| `alteracoes.updates.overbookingConfig.friday.maxOverbook` | `number` |
| `alteracoes.updates.overbookingConfig.saturday` | `map` |
| `alteracoes.updates.overbookingConfig.saturday.descricao` | `string` |
| `alteracoes.updates.overbookingConfig.saturday.maxOverbook` | `number` |
| `alteracoes.updates.overbookingConfig.thursday` | `map` |
| `alteracoes.updates.overbookingConfig.thursday.descricao` | `string` |
| `alteracoes.updates.overbookingConfig.thursday.maxOverbook` | `number` |
| `alteracoes.updates.overbookingConfig.monday` | `map` |
| `alteracoes.updates.overbookingConfig.monday.descricao` | `string` |
| `alteracoes.updates.overbookingConfig.monday.maxOverbook` | `number` |
| `alteracoes.updates.estatisticas` | `map` |
| `alteracoes.updates.estatisticas.mediaFaltas` | `number` |
| `alteracoes.updates.estatisticas.totalConsultasMes` | `number` |
| `alteracoes.updates.estatisticas.realizacoesRealocadas` | `number` |
| `alteracoes.updates.estatisticas.taxaOcupacaoMedia` | `number` |
| `alteracoes.updates.estatisticas.overbookingUtilizado` | `number` |
| `alteracoes.updates.horarioFuncionamento` | `map` |
| `alteracoes.updates.horarioFuncionamento.pausaAlmocoInicio` | `string` |
| `alteracoes.updates.horarioFuncionamento.diasAtendimento` | `array<number>` |
| `alteracoes.updates.horarioFuncionamento.fim` | `string` |
| `alteracoes.updates.horarioFuncionamento.pausaAlmocoFim` | `string` |
| `alteracoes.updates.horarioFuncionamento.intervaloConsulta` | `number` |
| `alteracoes.updates.horarioFuncionamento.inicio` | `string` |
| `alteracoes.updates.updatedAt` | `timestamp` |
| `dataHora` | `timestamp` |

---

### <a name="tb_overbooking_events"></a>`tb_overbooking_events`

- **ID de Exemplo**: `00wP2dgepKho50sAKiNk`

| Campo | Tipo |
| --- | --- |
| `executionId` | `string` |
| `medicoId` | `string` |
| `dataSlot` | `string` |
| `ocupacao` | `number` |
| `limiteSlot` | `number` |
| `excesso` | `number` |
| `decisao` | `string` |
| `motivo` | `string` |
| `totalPacientes` | `number` |
| `totalConfirmados` | `number` |
| `pacientes` | `array<map>` |
| `pacientes[].id` | `string` |
| `pacientes[].status` | `string` |
| `pacientes[].prioridade` | `number` |
| `createdAt` | `timestamp` |

---

### <a name="tb_overbooking_reports"></a>`tb_overbooking_reports`

- **ID de Exemplo**: `4hZ6HpLSQGE9MN9JicM5`

| Campo | Tipo |
| --- | --- |
| `executionId` | `string` |
| `dataExecucao` | `string` |
| `duracaoMs` | `number` |
| `medicosProcessados` | `number` |
| `overbookingIdentificados` | `number` |
| `pacientesNotificados` | `number` |
| `pacientesRealocados` | `number` |
| `totalErros` | `number` |
| `erros` | `array<any>` |
| `dataReferencia` | `string` |
| `chaveExecucao` | `string` |
| `emailsEnviados` | `number` |
| `smtpDisponivel` | `boolean` |
| `status` | `string` |
| `createdAt` | `timestamp` |

---

### <a name="tb_plan_user"></a>`tb_plan_user`

- **ID de Exemplo**: `3gGNlFKziIKfjGG8I3uI`

| Campo | Tipo |
| --- | --- |
| `id_plan` | `reference` |
| `id_user` | `reference` |
| `active` | `number` |
| `active_ano` | `number` |

---

### <a name="tb_plans"></a>`tb_plans`

- **ID de Exemplo**: `Ej0hEdh04luMb0uSns1T`

| Campo | Tipo |
| --- | --- |
| `tipoFaturamento` | `string` |
| `inter_preco_ano` | `number` |
| `isPopular` | `boolean` |
| `dataAtualizacao` | `timestamp` |
| `status` | `string` |
| `inter_preco_mes` | `number` |
| `recursosInclusos` | `string` |
| `beneficiosAdicionais` | `array<string>` |
| `descricao` | `string` |
| `intergracao` | `boolean` |
| `dataCriacao` | `timestamp` |
| `limite_consulta` | `number` |
| `nivelSuporte` | `string` |
| `limiteArmazenamento` | `number` |
| `limiteUsuarios` | `number` |
| `precoMensal` | `number` |
| `precoAnual` | `number` |
| `nome` | `string` |

---

### <a name="tb_pre_agendamentos"></a>`tb_pre_agendamentos`

- **ID de Exemplo**: `1ON3sFQdPxc3MSUghEof`

| Campo | Tipo |
| --- | --- |
| `cpf` | `string` |
| `clinicRef` | `reference` |
| `email` | `string` |
| `idMedico` | `reference` |
| `phone` | `string` |
| `channel` | `string` |
| `tempCode` | `string` |
| `consentAccepted` | `boolean` |
| `name` | `string` |
| `createdAt` | `timestamp` |
| `resumeUrl` | `string` |
| `status` | `string` |
| `updatedAt` | `timestamp` |

---

### <a name="tb_relatorio_ia"></a>`tb_relatorio_ia`

- **ID de Exemplo**: `04hXYI5eWTfrKeF7OL8V`

| Campo | Tipo |
| --- | --- |
| `idclinica` | `string` |
| `nomeClinica` | `string` |
| `periodoInicio` | `timestamp` |
| `periodoFim` | `timestamp` |
| `geradoPor` | `string` |
| `tipoRelatorio` | `string` |
| `resumoExecutivo` | `string` |
| `totalAgendamentos` | `number` |
| `totalAtendidos` | `null` |
| `totalFaltas` | `null` |
| `taxaFaltas` | `null` |
| `tempoMedioAtendimentoMin` | `null` |
| `ocupacao_pct` | `null` |
| `tempo_medio_ate_atendimento_dias` | `null` |
| `pontualidade_inicio_min` | `null` |
| `duracao_real_media_min` | `null` |
| `confirmacaoPct` | `null` |
| `remarcacao_pct` | `null` |
| `overbooking_efetivo_pct` | `null` |
| `whatsapp` | `null` |
| `web` | `null` |
| `recepcao` | `null` |
| `cortes` | `string` |
| `resumoPredicoes` | `null` |
| `pacientesRiscoAlto` | `number` |
| `fatoresRisco` | `array<string>` |
| `sugestoes` | `array<string>` |

---

### <a name="tb_service"></a>`tb_service`

- **ID de Exemplo**: `9KuB1cx29VZ4STMdxyjr`

| Campo | Tipo |
| --- | --- |
| `titulo` | `string` |
| `recorrente` | `boolean` |
| `dateCreat` | `timestamp` |
| `dateUpdate` | `timestamp` |
| `desc` | `string` |
| `idclinica` | `reference` |
| `preco` | `number` |

---

### <a name="tb_tarefas"></a>`tb_tarefas`

- **ID de Exemplo**: `CWVv0tXyRaKiWv7ZMgco`

| Campo | Tipo |
| --- | --- |
| `visual` | `boolean` |
| `desc` | `string` |
| `idclinica` | `reference` |
| `dtregistro` | `timestamp` |
| `type` | `string` |
| `titulo` | `string` |

---

### <a name="tb_term"></a>`tb_term`

- **ID de Exemplo**: `N5pDFty6rrpLiyEptnYC`

| Campo | Tipo |
| --- | --- |
| `version` | `string` |
| `status` | `boolean` |
| `created` | `timestamp` |
| `updateAt` | `timestamp` |
| `effectiveDate` | `timestamp` |
| `term` | `string` |
| `type` | `string` |

---

### <a name="tb_users_term"></a>`tb_users_term`

- **ID de Exemplo**: `N9TxKff7AriOVLOsHssW`

| Campo | Tipo |
| --- | --- |
| `idUser` | `reference` |
| `createdAt` | `timestamp` |
| `termId` | `reference` |
| `name` | `string` |
| `acceptedTermsVersion` | `string` |
| `version` | `string` |
| `content` | `string` |
| `effectiveDate` | `timestamp` |
| `email` | `string` |
| `updatedAt` | `timestamp` |
| `acceptedTermsAt` | `timestamp` |

---

### <a name="tb_views_medicos"></a>`tb_views_medicos`

- **ID de Exemplo**: `B6KzYzieV5sUoxbF5LKc`

| Campo | Tipo |
| --- | --- |
| `idmedico` | `reference` |
| `content` | `string` |
| `iduser` | `reference` |
| `device` | `string` |
| `rate` | `number` |
| `date` | `timestamp` |

---

### <a name="test_permissions"></a>`test_permissions`

- **ID de Exemplo**: `test`

| Campo | Tipo |
| --- | --- |
| `timestamp` | `timestamp` |

---

### <a name="tickets"></a>`tickets`

- **ID de Exemplo**: `HVfKqPrzrTO4wSg09RAh`

| Campo | Tipo |
| --- | --- |
| `protocol` | `string` |
| `queueId` | `string` |
| `userId` | `string` |
| `userInfo` | `map` |
| `userInfo.name` | `string` |
| `userInfo.email` | `string` |
| `userInfo.phone` | `string` |
| `origin` | `string` |
| `subject` | `string` |
| `status` | `string` |
| `priority` | `string` |
| `position` | `number` |
| `timeline` | `array<map>` |
| `timeline[].action` | `string` |
| `timeline[].timestamp` | `timestamp` |
| `timeline[].details` | `string` |
| `tags` | `array<string>` |
| `assignedTo` | `string` |
| `timestamps` | `map` |
| `timestamps.created` | `timestamp` |
| `assignedAt` | `timestamp` |

---

### <a name="users"></a>`users`

- **ID de Exemplo**: `05HvHSm4poo4IOEbkrkD`

| Campo | Tipo |
| --- | --- |
| `cpf` | `string` |
| `created_time` | `timestamp` |
| `dataNascimento` | `timestamp` |
| `display_name` | `string` |
| `distancia_km` | `number` |
| `email` | `string` |
| `endereco` | `string` |
| `idclinica` | `reference` |
| `phone_number` | `string` |
| `photo_url` | `string` |
| `preferencias` | `string` |
| `ps_renda` | `number` |
| `roles` | `array<string>` |
| `sexo` | `string` |
| `status` | `boolean` |
| `uid` | `string` |
| `updatedAt` | `timestamp` |
| `fcmToken` | `string` |
| `hasNotifications` | `boolean` |
| `isFake` | `boolean` |
| `fakeBatchId` | `string` |

---

---

## Coleções do app Flutter

Criadas e mantidas por **este repositório** (`vitta_app`). Schema extraído do
código-fonte — a fonte de verdade de cada uma está indicada. Diferente das
seções acima, não vêm de amostragem de documentos reais.

Todas são escopadas por clínica. Atenção ao **nome do campo de tenant**: as
coleções novas usam `clinicaId` (camelCase); boa parte da base legada usa
`idclinica` (ver `CUSTO.md` §6.6). `tb_relatorio_ia` usa `idclinica` por já
existir antes.

| Coleção | Campo de tenant | Fonte de verdade |
| --- | --- | --- |
| [`tb_cerebro_notas`](#tb_cerebro_notas) | `clinicaId` | `nota.dart › Nota.toMap()` |
| [`tb_cerebro_eventos`](#tb_cerebro_eventos) | `clinicaId` | `cerebro_tools.dart › _auditar()` |
| [`tb_vigia_ciclos`](#tb_vigia_ciclos) | id do doc | `vigia_models.dart › ResultadoCiclo` |
| [`tb_notas_clinicas`](#tb_notas_clinicas) | `clinicaId` | `notas_clinicas_repository.dart` |
| [`tb_agentes`](#tb_agentes) | `clinicaId` | `agent_model.dart › toFirestore()` |
| [`tb_filas`](#tb_filas) | `clinicaId` | `queue_model.dart › toFirestore()` |
| [`tb_notificacoes`](#tb_notificacoes) | `clinicaId` | `notificacoes_repository.dart` |
| [`tb_agent_plans`](#tb_agent_plans) | `clinicaId` | `agent_plans_service.dart` |

---

### <a name="tb_cerebro_notas"></a>`tb_cerebro_notas`

Notas do **Cérebro** — o segundo cérebro da clínica (`obsidian/obsidian.md`).
Exclusão é *soft* (`deletedAt`); a purga física é da Cloud Function.

| Campo | Tipo | Nota |
| --- | --- | --- |
| `clinicaId` | `string` | Isolamento multi-tenant, reforçado no cliente |
| `path` | `string` | Caminho tipo arquivo (`protocolos/confirmacao.md`) — chave de resolução de links |
| `titulo` | `string` | |
| `aliases` | `array<string>` | Nomes alternativos que resolvem para esta nota |
| `tipo` | `string` | `nota` \| `analise` \| `diario` \| `protocolo` \| … |
| `tags` | `array<string>` | Hierárquicas (`clinica/risco` indexa também `clinica`) |
| `cor` | `string?` | |
| `conteudo` | `string` | Markdown (VFM). Acima de 900 KB a gravação é recusada |
| `frontmatter` | `map` | |
| `outLinks` | `array<string>` | Chaves de nó de destino |
| `entityRefs` | `array<map>` | `[[@tipo:id]]` — vínculos com entidades do sistema |
| `headings`, `blocos` | `array` | Estrutura do documento |
| `wordCount`, `charCount`, `tempoLeituraSeg` | `number` | |
| `metrics` | `map` | `inDegree`, `outDegree`, `pagerank`, `cluster`, `centralidadeIntermediacao` |
| `origem` | `string` | `humano` \| `agente` |
| `agenteId`, `confianca`, `revisadoPor` | opcionais | Preenchidos quando `origem = agente` |
| `estado` | `string` | `publicada` \| `rascunho` \| `arquivada` |
| `sensivel`, `fixada`, `favorita` | `boolean` | |
| `versao` | `number` | Controle de conflito (transação no `salvar`) |
| `embeddingVersao` | `number` | Reservado para busca semântica |
| `createdAt/By`, `updatedAt/By`, `deletedAt` | | |

> **Ids `nt_demo_*`** identificam a carga de demonstração sintética. Só são
> criados por ação explícita do usuário e podem ser removidos em massa por
> "Limpar dados de demonstração". Nota escrita por gente nunca tem esse prefixo.

**Índice necessário:** `clinicaId ASC, updatedAt DESC` (já publicado). A leitura
tem fallback: se o índice faltar (`failed-precondition`), carrega sem `orderBy`
e ordena no cliente.

---

### <a name="tb_cerebro_eventos"></a>`tb_cerebro_eventos`

Auditoria das escritas do **agente de IA** no Cérebro. Toda gravação via
`cerebro_escrever` / `cerebro_linkar` registra um evento aqui.

| Campo | Tipo |
| --- | --- |
| `clinicaId` | `string` |
| `notaId` | `string` |
| `acao` | `string` (`criar` \| `append` \| `substituir` \| `linkar`) |
| `ator`, `atorTipo` | `string` (`agente`) |
| `motivo` | `string` — obrigatório na tool; é a justificativa auditável |
| `versaoDepois` | `number` |
| `confianca` | `number` (0..1) |
| `criadoEm` | `timestamp` |

> Falha ao auditar **não** bloqueia o agente — a nota é gravada de qualquer
> forma. Auditoria indisponível não deve travar o fluxo clínico.

---

### <a name="tb_vigia_ciclos"></a>`tb_vigia_ciclos`

Auditoria dos ciclos do **Vigia** e, ao mesmo tempo, a **trava diária** que
impede ciclo duplo (`VIGIA.md` §7).

**Id do documento:** `{clinicaId}_{YYYY-MM-DD}` — a chave é o próprio id.

| Campo | Tipo | Nota |
| --- | --- | --- |
| `executou` | `boolean` | `true` só quando o ciclo concluiu. Falha **não** marca `true`, para o próximo boot tentar de novo |
| `motivo` | `string` | Resumo legível do resultado ou da recusa |
| `relatorioId` | `string?` | |
| `sugestoesCriadas` | `number` | |
| `sugestoesDescartadas` | `number` | Dedupe/confiança/malformadas — sinal de calibração |
| `notaCerebroId` | `string?` | |
| `duracaoMs` | `number` | |
| `origem` | `string` | `cron` quando veio da Cloud Function |
| `iniciadoEm`, `em` | `timestamp` | |

---

### <a name="tb_notas_clinicas"></a>`tb_notas_clinicas`

Notas clínicas por paciente (PAC-05). Não confundir com `tb_cerebro_notas` —
estas são observações sobre **um paciente específico**, escritas na tela de
detalhe do paciente.

| Campo | Tipo |
| --- | --- |
| `clinicaId` | `string` |
| `pacienteId` | `string` |
| `autor` | `string` (nome de exibição de quem escreveu) |
| `texto` | `string` |
| `createdAt` | `timestamp` |

**Índice:** nenhum composto necessário — a query usa duas igualdades
(`clinicaId` + `pacienteId`) e ordena no cliente.

---

### <a name="tb_agentes"></a>`tb_agentes`

Atendentes do módulo de filas. Nomes de campo espelham o contrato de
`AGENTS.md` §1.1.

| Campo | Tipo | Nota |
| --- | --- | --- |
| `clinicaId` | `string` | |
| `nomeOperacional` | `string` | |
| `email` | `string` | Normalizado para minúsculo; é o login |
| `accessPin` | `string` | 6 dígitos — **também a senha inicial do Firebase Auth** |
| `disponibilidade` | `string` | `online` \| `busy` \| `away` \| `offline` |
| `assignedQueues` | `array<string>` | Nomes das filas |
| `activeChats` | `number` | Carga atual — **não é atualizada em tempo real** (ver nota) |
| `maxConcurrentChats` | `number` | Teto de atendimentos simultâneos |

> **`activeChats` é estado de sessão, por decisão explícita.** Muda a cada
> mensagem; persistir cada passo custaria uma escrita por evento de chat. O que
> sobrevive ao restart é o cadastro e a `disponibilidade`.

O cadastro é um **double write**: `users/{uid}` (perfil + `roles: ['agente']`)
criado junto, com o login no Firebase Auth feito numa instância secundária para
não derrubar a sessão do admin.

---

### <a name="tb_filas"></a>`tb_filas`

Filas/departamentos de atendimento.

| Campo | Tipo | Nota |
| --- | --- | --- |
| `clinicaId` | `string` | |
| `name` | `string` | |
| `distributionStrategy` | `string` | `least_occupied` \| `round_robin` |
| `sla` | `map` | `{ firstResponseSeconds, resolutionSeconds }` |
| `agentIds` | `array<string>` | |

---

### <a name="tb_notificacoes"></a>`tb_notificacoes`

Feed de notificações do centro de avisos.

| Campo | Tipo | Nota |
| --- | --- | --- |
| `clinicaId` | `string` | |
| `tipo` | `string` | `agendamento` \| `cancelamento` \| `risco` \| `relatorio` \| `ticket` \| `overbooking` |
| `titulo`, `mensagem` | `string` | |
| `time` | `timestamp` | |
| `lida` | `boolean` | |

Teto de 200 no carregamento — notificação é fluxo, não arquivo. "Marcar todas
como lidas" usa batch (limite de 500 operações do Firestore respeitado).

---

### <a name="tb_agent_plans"></a>`tb_agent_plans`

Planos salvos do agente de IA (painel de IA → planos). Estava **fora deste
documento** apesar de ter índice publicado — corrigido em 2026-09-02.

| Campo | Tipo | Nota |
| --- | --- | --- |
| `clinicaId` | `string` | |
| `createdAt` | `timestamp` | |

**Índice publicado:** `clinicaId ASC, createdAt DESC`.

> O schema acima vem do índice e de `agent_plans_service.dart`; os demais campos
> não foram conferidos contra documento real. Regerar a amostragem completa a
> próxima vez que houver acesso à base.

---

## Coleções indexadas sem consumidor conhecido

Têm índice publicado em `firestore.indexes.json`, mas **nenhuma referência** em
`lib/` ou `functions/`. Ficam registradas aqui para não sumirem numa próxima
regeração — e porque índice sem consumidor custa escrita em toda gravação.

### <a name="tb_absenteismo_scores"></a>`tb_absenteismo_scores`

Campos inferidos dos índices: `clinicaId`, `outcome`, `riskScore`,
`dataConsulta`.

**Provavelmente a fonte de histórico que a calibração do Monte Carlo procura.**
Desfecho + escore de risco + data, por clínica, é exatamente a tabela de treino
que o módulo `monte_carlo` monta hoje a partir da agenda operacional — que só
carrega a janela próxima. Ver "Problemas estruturais → P2".

Índices publicados:

    clinicaId, outcome, dataConsulta
    clinicaId, outcome, riskScore
    outcome, dataConsulta
    outcome, riskScore

Os dois últimos, **sem `clinicaId`**, permitem consulta cruzando clínicas. Se a
coleção for usada, revisar `firestore.rules` antes: índice não é permissão, mas
sinaliza que alguém pretendeu consultar assim.

### <a name="tb_agent_actions"></a>`tb_agent_actions`

Campos inferidos: `status`, `executedAt`. Índice `status ASC, executedAt DESC`.

Sem `clinicaId` no índice — se guardar ação de agente por clínica, a consulta
por tenant não tem índice composto.

### <a name="chat_response"></a>`chat_response`

Campos inferidos: `tel`, `created_at`, `date`. Dois índices: `tel+created_at` e
`tel+date` — duas datas diferentes para a mesma coleção, sinal de schema que
mudou sem limpar o anterior.

`tel` como chave sugere o mesmo padrão de `chat_history` e `session_chat`, onde
o telefone é `number` (ver P4).
