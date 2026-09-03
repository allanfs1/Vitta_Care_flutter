# Firebase Cloud Functions

Esta é a lista de todas as Cloud Functions configuradas no projeto.

> **Para publicar**, veja [`CLOUD_FUNCTION.md`](CLOUD_FUNCTION.md) — procedimento,
> secrets, verificação e rollback. Atenção especial à regra de deploy
> **direcionado**: `firebase deploy --only functions` (sem nome) apaga as
> funções que não estiverem no codebase publicado, e a maior parte desta
> lista vem de outros repositórios.

| Function Name | Version | Trigger | Location | Memory | Runtime |
|---|---|---|---|---|---|
| checkFaltasPacientes | v2 | https | southamerica-east1 | --- | nodejs22 |
| listarAgendamentos | v2 | https | southamerica-east1 | --- | nodejs22 |
| api | v2 | https | us-central1 | 256 | nodejs22 |
| checkFaltasPacientes | v2 | https | us-central1 | 953.67 | nodejs22 |
| checkOverbookingConfigConsistency | v2 | scheduled | us-central1 | 256 | nodejs22 |
| configurarMedicoAoCriar | v2 | google.cloud.firestore.document.v1.created | us-central1 | 256 | nodejs22 |
| ffRemindersCronPush | v2 | scheduled | us-central1 | 256 | nodejs22 |
| gcalOAuthCallback | v2 | https | us-central1 | 953.67 | nodejs22 |
| gcalOAuthStart | v2 | https | us-central1 | 256 | nodejs22 |
| getEnvioStats | v2 | https | us-central1 | 256 | nodejs22 |
| getToken | v2 | https | us-central1 | 256 | nodejs22 |
| listarAgendamentos | v2 | https | us-central1 | 256 | nodejs22 |
| migrarCampoTicket | v2 | https | us-central1 | 256 | nodejs22 |
| onAgendamentoCreate | v2 | google.cloud.firestore.document.v1.created | us-central1 | 256 | nodejs22 |
| onAgendamentoDelete | v2 | google.cloud.firestore.document.v1.deleted | us-central1 | 256 | nodejs22 |
| onAgendamentoUpdate | v2 | google.cloud.firestore.document.v1.updated | us-central1 | 256 | nodejs22 |
| registrarAgendamentoOficial | v2 | https | us-central1 | 256 | nodejs22 |
| resetEnvioCounter | v2 | https | us-central1 | 256 | nodejs22 |
| resetMedicosOverbooking | v2 | callable | us-central1 | 256 | nodejs22 |
| scheduledPredictionJob | v2 | scheduled | us-central1 | 256 | nodejs22 |
| sendDailyReminders | v2 | scheduled | us-central1 | 256 | nodejs22 |
| setupMedicosOverbooking | v2 | https | us-central1 | 256 | nodejs22 |
| setupMedicosOverbookingAdvanced | v2 | https | us-central1 | 256 | nodejs22 |
| setupSingleMedicoOverbooking | v2 | https | us-central1 | 256 | nodejs22 |
| testPredictionSave | v2 | https | us-central1 | 256 | nodejs22 |
| testWhatsApp | v2 | https | us-central1 | 256 | nodejs22 |
| testWhatsAppBatch | v2 | https | us-central1 | 256 | nodejs22 |
| addFcmToken | v1 | callable | us-central1 | 256 | nodejs20 |
| assistenteHelp | v1 | callable | us-central1 | 256 | nodejs20 |
| attachPrebookingToke | v1 | callable | us-central1 | 1024 | nodejs20 |
| cancelAndReschedulePage | v1 | https | us-central1 | 256 | nodejs20 |
| confirmarPacientesIA | v1 | callable | us-central1 | 256 | nodejs20 |
| createdPaciente | v1 | callable | us-central1 | 256 | nodejs20 |
| createdUser | v1 | callable | us-central1 | 256 | nodejs20 |
| createdUserPassword | v1 | callable | us-central1 | 512 | nodejs20 |
| dailyOverbookingManager | v1 | scheduled | us-central1 | 512 | nodejs20 |
| enqueueEmails | v1 | callable | us-central1 | 2048 | nodejs20 |
| expireOverbookingTokens | v1 | scheduled | us-central1 | 256 | nodejs20 |
| expirePrebookings | v1 | scheduled | us-central1 | 256 | nodejs20 |
| ffEnqueueHighRiskPatients | v1 | scheduled | us-central1 | 1024 | nodejs20 |
| ffProcessEmailQueue | v1 | scheduled | us-central1 | 2048 | nodejs20 |
| ffSaveFcmToken | v1 | callable | us-central1 | 512 | nodejs20 |
| getZapiQRCode | v1 | callable | us-central1 | 256 | nodejs20 |
| notifyOverbookingBatch | v1 | callable | us-central1 | 512 | nodejs20 |
| processarFilaEmailParaPush | v1 | scheduled | us-central1 | 2048 | nodejs20 |
| processarFilaRealocacao | v1 | scheduled | us-central1 | 2048 | nodejs20 |
| rescheduleConfirm | v1 | https | us-central1 | 256 | nodejs20 |
| resumePrebookingToken | v1 | https | us-central1 | 256 | nodejs20 |
| scheduledOverbookingNotifications | v1 | scheduled | us-central1 | 256 | nodejs20 |
| sendConfirmAppointmentEmail | v1 | callable | us-central1 | 256 | nodejs20 |
| sendEmailUserCancel | v1 | callable | us-central1 | 256 | nodejs20 |
| sendGenericEmail | v1 | callable | us-central1 | 256 | nodejs20 |
| sendGenericEmailADM | v1 | callable | us-central1 | 256 | nodejs20 |
| sendOverbookingEmail | v1 | https | us-central1 | 256 | nodejs20 |
| sendPrebookingEmail | v1 | callable | us-central1 | 256 | nodejs20 |
| sendPushNotificationsTrigger | v1 | providers/cloud.firestore/eventTypes/document.create | us-central1 | 2048 | nodejs20 |
| sendRescheduleLinkWithButton | v1 | https | us-central1 | 256 | nodejs20 |
| sendScheduledPushNotifications | v1 | scheduled | us-central1 | 256 | nodejs20 |
| sendUserPushNotificationsTrigger | v1 | providers/cloud.firestore/eventTypes/document.create | us-central1 | 2048 | nodejs20 |
| thanksPage | v1 | https | us-central1 | 256 | nodejs20 |
| updatePaciente | v1 | callable | us-central1 | 256 | nodejs20 |
| updateUserPass | v1 | https | us-central1 | 512 | nodejs20 |
