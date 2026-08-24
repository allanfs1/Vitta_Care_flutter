import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_config.dart';

/// Tentativas extras em respostas 429/503 antes de cair no fallback.
const int _helpMaxRetries = 3;

/// Serviço compartilhado de IA (módulo `features/ia`).
///
/// Em produção, conecta ao **Azure AI Foundry** (DeepSeek V4 Flash/Pro) descrito
/// em `.specify/AI_chaves.md`, via endpoint compatível com a API OpenAI:
///
/// ```
/// POST {endpoint}/chat/completions
/// Authorization: Bearer {AZURE_AI_KEY}
/// { "model": "DeepSeek-V4-Pro", "messages": [...] }
/// ```
///
/// A chave **não** deve ser embarcada no app cliente — as requisições devem
/// passar por uma Cloud Function (ver `.specify/cloud_functions.md`). Esta
/// implementação simula respostas para desenvolvimento offline.
class AiService {
  const AiService();

  /// IA-03 — relatório textual com insights em linguagem natural.
  Future<String> generateReport({required String clinicName}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return '''
## Relatório de Desempenho — $clinicName

**Resumo executivo**
No último período, a unidade manteve uma taxa de ocupação de 78%, acima da média
da rede (71%). O absenteísmo recuou de 18% para 16%, refletindo a efetividade dos
lembretes automatizados via WhatsApp.

**Principais insights**
- Quartas-feiras às 15h concentram o maior índice de faltas (índice 0,9).
- A especialidade de Clínica Geral lidera o absenteísmo (22%); recomenda-se
  reforço de confirmação 48h antes.
- A eficiência de realocação de horários cancelados subiu para 72%.

**Recomendações**
1. Ativar overbooking inteligente para os horários críticos identificados.
2. Priorizar contato ativo com os 3 pacientes de risco alto desta semana.
3. Expandir a confirmação automática para retornos de cardiologia.
''';
  }

  /// Insight de leitura de um gráfico específico (feedbacks por IA).
  /// [chartTitle] identifica o gráfico e [summary] traz um resumo dos dados.
  Future<String> chartInsight({
    required String chartTitle,
    required String summary,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return '''
**$chartTitle — leitura por IA**

$summary

**O que isso indica**
- A tendência geral está dentro do esperado para o período, com pontos de
  atenção concentrados nos horários de pico.
- O indicador sugere oportunidade de otimização (realocação/confirmação ativa).

**Recomendações**
1. Agir sobre os horários/segmentos de maior risco destacados no gráfico.
2. Acompanhar a evolução na próxima semana para confirmar a tendência.
3. Acionar lembretes automáticos para reduzir faltas onde o índice está alto.
''';
  }

  /// IA-01 — sugestão de horários otimizados (B2B / clínicas privadas).
  Future<List<String>> suggestSlots({required String specialty}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return [
      'Ter 24/06 • 08:30 — menor risco de falta (94% de comparecimento histórico)',
      'Qua 25/06 • 11:00 — janela ociosa do $specialty',
      'Qui 26/06 • 16:30 — alta aderência para retornos',
    ];
  }

  /// Resposta do **assistente de ajuda** chamando o Azure AI Foundry direto
  /// (DeepSeek). [messages] é a conversa no formato OpenAI (`{role, content}`),
  /// já incluindo o prompt de sistema. Nunca lança: devolve uma mensagem de
  /// fallback se a IA não responder. Em 429/503, retenta com backoff (respeita
  /// `Retry-After`) antes de desistir.
  Future<String> helpReply(List<Map<String, String>> messages) async {
    const fallback =
        'Não consegui falar com a IA agora — o limite de requisições pode ter '
        'sido atingido. Tente de novo em instantes; enquanto isso, use os tours '
        'guiados e as sugestões abaixo. 🙂';
    final body = jsonEncode({
      'model': 'DeepSeek-V4-Flash',
      'messages': messages,
      'temperature': 0.3,
    });
    final headers = {
      'Content-Type': 'application/json',
      // Com proxy (AI_PROXY_URL), a chave fica no servidor e não é enviada
      // pelo cliente — evita vazar a credencial no bundle web.
      if (AiConfig.clientKey.isNotEmpty) 'api-key': AiConfig.clientKey,
    };

    for (var attempt = 0; attempt <= _helpMaxRetries; attempt++) {
      try {
        final res = await http
            .post(Uri.parse(AiConfig.endpoint), headers: headers, body: body)
            .timeout(const Duration(seconds: 30));

        if ((res.statusCode == 429 || res.statusCode == 503) &&
            attempt < _helpMaxRetries) {
          await Future<void>.delayed(_retryDelay(res, attempt));
          continue;
        }
        if (res.statusCode != 200) {
          debugPrint('helpReply HTTP ${res.statusCode}: ${res.body}');
          return fallback;
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final choices = data['choices'];
        String? content;
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map) {
            final message = first['message'];
            if (message is Map) content = message['content']?.toString();
          }
        }
        if (content != null && content.trim().isNotEmpty) return content.trim();
        return fallback;
      } catch (e) {
        debugPrint('helpReply erro: $e');
        return fallback;
      }
    }
    return fallback;
  }

  /// Espera antes de retentar: usa `Retry-After` (segundos) quando presente;
  /// senão, backoff exponencial 1s → 2s → 4s.
  Duration _retryDelay(http.Response res, int attempt) {
    final retryAfter = res.headers['retry-after'];
    if (retryAfter != null) {
      final secs = int.tryParse(retryAfter.trim());
      if (secs != null) return Duration(seconds: secs.clamp(1, 30));
    }
    return Duration(seconds: 1 << attempt);
  }

  /// IA-02 / IA-04 — resposta de chat assistente para análise de dados.
  Stream<String> chat(String prompt) async* {
    const response =
        'Com base nos dados da clínica, a tendência de agendamentos está '
        'positiva (+8% no mês). O principal ponto de atenção é o absenteísmo '
        'às quartas-feiras. Posso gerar um relatório detalhado ou montar um '
        'dashboard de ocupação por especialidade — é só pedir.';
    for (final word in response.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 35));
      yield '$word ';
    }
  }
}
