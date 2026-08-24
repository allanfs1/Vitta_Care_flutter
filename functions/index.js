/**
 * Codebase "ia" — funções de suporte ao chat/IA do app Vitta.
 *
 * Isolado das funções do backend principal por um `codebase` próprio em
 * firebase.json, para que o deploy daqui NÃO remova as outras Cloud Functions
 * do projeto. Faça sempre deploy direcionado:
 *
 *   firebase deploy --only functions:chatProxy,functions:emailProxy,\
 *     functions:whatsappProxy,functions:analyzeDocument,functions:anthropicProxy
 */
Object.assign(
  exports,
  require("./chatProxy"),
  require("./analyzeDocument"),
  require("./emailProxy"),
  require("./sendConfirmationEmail"),
  require("./whatsappProxy"),
  require("./anthropicProxy"),
  require("./scheduledTasksCron"),
  require("./vigiaCron")
);
