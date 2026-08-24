import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/services/ai_config.dart';

/// Trava as invariantes de segurança de [AiConfig]. Os valores concretos vêm de
/// `--dart-define` em tempo de build; aqui garantimos que a *derivação* nunca
/// vaza a credencial quando há proxy — independente do ambiente do teste.
void main() {
  group('AiConfig', () {
    test('endpoint segue o proxy quando configurado, senão o Azure direto', () {
      expect(
        AiConfig.endpoint,
        AiConfig.usesProxy ? AiConfig.proxyUrl : AiConfig.azureEndpoint,
      );
    });

    test('usesProxy reflete a presença de AI_PROXY_URL', () {
      expect(AiConfig.usesProxy, AiConfig.proxyUrl.isNotEmpty);
    });

    test('com proxy, a chave NUNCA é enviada pelo cliente', () {
      // Garantia central: se o proxy está ativo, clientKey é vazia — a
      // credencial fica no servidor e não vaza no bundle web.
      if (AiConfig.usesProxy) {
        expect(AiConfig.clientKey, isEmpty);
      } else {
        // Sem proxy, o cliente envia exatamente a chave do Azure (que pode ser
        // vazia em dev → cai no fallback local).
        expect(AiConfig.clientKey, AiConfig.azureApiKey);
      }
    });
  });
}
