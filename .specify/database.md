# Estrutura do Banco de Dados Firestore

Este documento contém a estrutura atualizada das coleções do Firestore para o projeto **agendaclinica-457713**, analisada automaticamente a partir de dados reais.

## Resumo das Coleções

Total de coleções: 55

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

