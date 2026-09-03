/// Configuração central de conectividade da IA (chat-completions).
///
/// **Segurança.** Em produção, defina
/// `--dart-define=AI_PROXY_URL=<url-da-Cloud-Function>` apontando para um proxy
/// OpenAI-compatível (ex.: `chatProxy`/`assistenteHelp`). Quando o proxy está
/// configurado, o cliente **não** envia a credencial `AZURE_AI_KEY` — a Cloud
/// Function injeta a chave no servidor, então ela nunca vai para o bundle
/// entregue ao navegador (essencial no Flutter Web).
///
/// Sem o proxy (fluxo de desenvolvimento), cai no acesso **direto** ao Azure AI
/// Foundry usando `AZURE_AI_KEY` fornecida em tempo de build. Sem nenhuma das
/// duas, as chamadas de IA caem no fallback local.
///
/// Centraliza o endpoint/chave que antes estavam duplicados em
/// `ai_service.dart` e `ai_agent_service.dart`.
class AiConfig {
  const AiConfig._();

  /// URL da Cloud Function proxy (OpenAI-compatível). Vazia = sem proxy.
  static const String proxyUrl = String.fromEnvironment('AI_PROXY_URL');

  /// Endpoint OpenAI-compatível do Azure AI Foundry (acesso direto).
  static const String azureEndpoint =
      'https://micro-mrfgtgfz-eastus2.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview';

  /// Chave do Azure AI Foundry fornecida em tempo de build
  /// (`--dart-define=AZURE_AI_KEY=...`).
  static const String azureApiKey = String.fromEnvironment('AZURE_AI_KEY');

  /// `true` quando as chamadas passam por uma Cloud Function — a credencial
  /// fica no servidor e nunca é embarcada no cliente.
  static bool get usesProxy => proxyUrl.isNotEmpty;

  /// Endpoint efetivo das chamadas de chat-completions.
  static String get endpoint => usesProxy ? proxyUrl : azureEndpoint;

  /// Chave enviada **pelo cliente**. Vazia quando há proxy (a credencial nunca
  /// sai do servidor, evitando vazamento no bundle web). Header `api-key` só
  /// deve ser incluído quando esta string não for vazia.
  static String get clientKey => usesProxy ? '' : azureApiKey;

  /// `true` quando as chamadas de IA têm como funcionar: via proxy, ou via
  /// acesso direto com `AZURE_AI_KEY` embarcada. `false` = só fallback local,
  /// e qualquer envio ao modelo devolve HTTP 401.
  static bool get isConfigured => usesProxy || azureApiKey.isNotEmpty;

  /// Rótulo curto do modo de conectividade — para o painel de status da /ia.
  static AiConnectivity get connectivity => usesProxy
      ? AiConnectivity.proxy
      : (azureApiKey.isNotEmpty
          ? AiConnectivity.direct
          : AiConnectivity.unconfigured);
}

/// Como o app fala com o modelo. Ver [AiConfig.connectivity].
enum AiConnectivity {
  /// Via Cloud Function `chatProxy` — credencial fica no servidor (produção).
  proxy,

  /// Acesso direto ao Azure AI Foundry com `AZURE_AI_KEY` de build (dev).
  direct,

  /// Sem `AI_PROXY_URL` nem `AZURE_AI_KEY` — o modelo recusa (401).
  unconfigured;

  String get label => switch (this) {
        AiConnectivity.proxy => 'Chat + agentes (via proxy seguro)',
        AiConnectivity.direct => 'Chat + agentes (Azure direto)',
        AiConnectivity.unconfigured => 'Sem credencial — configure AI_PROXY_URL',
      };
}
