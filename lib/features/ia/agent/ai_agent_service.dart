import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/ai_config.dart';
import 'agent_models.dart';

/// Evento emitido pelo loop do agente (espelha os eventos SSE do AgentAI.md:
/// `thinking`, `tool_done`, `token`, `done`, `error`).
sealed class AgentEvent {
  const AgentEvent();
}

/// Uma ferramenta MCP está prestes a ser executada.
class AgentThinking extends AgentEvent {
  const AgentThinking(this.toolName, this.callId);
  final String toolName;
  final String callId;
}

/// Resultado da execução de uma ferramenta.
class AgentToolDone extends AgentEvent {
  const AgentToolDone(this.toolName, this.callId, this.ok);
  final String toolName;
  final String callId;
  final bool ok;
}

/// Fragmento incremental do texto final (streaming).
class AgentToken extends AgentEvent {
  const AgentToken(this.text);
  final String text;
}

/// Conclusão: resposta final completa.
class AgentDone extends AgentEvent {
  const AgentDone(this.text);
  final String text;
}

/// Erro irrecuperável da rodada.
class AgentError extends AgentEvent {
  const AgentError(this.message);
  final String message;
}

/// Saída de uma ferramenta: o texto e **se falhou**.
///
/// O `isError` vem de `McpResult.isError`, que a tool já produz. Antes o loop
/// deduzia falha por `result.startsWith('Erro:')` — sniffing de string que erra
/// nos dois sentidos: uma tool que devolve um log contendo "Erro:" era marcada
/// como falha, e uma que falha com outra redação passava por sucesso.
typedef ToolOutcome = ({String text, bool isError});

/// Executor de uma ferramenta MCP.
typedef ToolExecutor = Future<ToolOutcome> Function(
    String name, Map<String, dynamic> args);

/// Cliente do agente de IA — endpoint OpenAI-compatível resolvido por
/// [AiConfig]. Sem `AI_PROXY_URL`, fala **direto** com o Azure AI Foundry
/// (DeepSeek V4); o endpoint devolve headers CORS, então funciona no Flutter
/// Web. Com `--dart-define=AI_PROXY_URL=<url>`, roteia pela Cloud Function e o
/// cliente não envia a credencial (a chave fica no servidor).
///
/// ⚠️ Segurança: no acesso direto, a chave vai embarcada no cliente e fica
/// exposta (sobretudo na build web). Em produção, configure o proxy via
/// [AiConfig] — ou instancie com `AiAgentService(endpoint: '<url>', apiKey: '')`.
///
/// Implementa o **loop de ferramentas** descrito em `.specify/AgentAI.md`: até
/// [maxRounds] rodadas alternando geração ↔ execução de tools MCP até a
/// resposta final.
class AiAgentService {
  AiAgentService({
    String? endpoint,
    String? apiKey,
    this.model = 'DeepSeek-V4-Flash',
    this.maxRounds = 6,
    this.maxRetries = 3,
    this.prazoTotal = const Duration(minutes: 3),
    this.maxCharsPorResultado = 8000,
    http.Client? client,
  })  : _urls = [endpoint ?? AiConfig.endpoint],
        _apiKey = apiKey ?? AiConfig.clientKey,
        _client = client ?? http.Client();

  final List<String> _urls;
  final String _apiKey;
  final String model;
  final int maxRounds;

  /// Tentativas extras em respostas 429/503 antes de desistir.
  final int maxRetries;

  /// Teto de tempo da rodada inteira.
  ///
  /// Cada requisição tem 90 s de timeout e pode ser retentada; sem um teto
  /// global, `maxRounds` × `maxRetries` × 90 s chega a quase meia hora de
  /// espera com a interface travada em "pensando". O prazo é verificado entre
  /// rodadas: a rodada em curso termina, e a próxima não começa.
  final Duration prazoTotal;

  /// Teto de caracteres do resultado de **cada** ferramenta.
  ///
  /// O resultado entra no histórico e é reenviado em toda rodada seguinte, então
  /// um retorno grande custa uma vez por rodada restante. Trunca com marca
  /// explícita para o modelo saber que há mais dado — e poder pedir com filtro.
  final int maxCharsPorResultado;

  final http.Client _client;

  /// Executa uma rodada completa do agente para a [history] (que já inclui a
  /// nova mensagem do usuário). Emite eventos até [AgentDone] ou [AgentError].
  Stream<AgentEvent> run({
    required List<ChatMessage> history,
    required List<Map<String, dynamic>> toolSpecs,
    required ToolExecutor callTool,
    required String clinicaId,
  }) async* {
    final tools = _toOpenAiTools(toolSpecs);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(clinicaId)},
      ...history
          .where((m) => m.role != ChatRole.system)
          .map((m) => m.toApi()),
    ];

    final relogio = Stopwatch()..start();

    try {
      for (var round = 0; round < maxRounds; round++) {
        if (relogio.elapsed > prazoTotal) {
          yield AgentError(
              'Tempo esgotado após ${relogio.elapsed.inSeconds}s e $round '
              'rodada(s) de ferramentas. Tente uma pergunta mais específica.');
          return;
        }
        final resp = await _complete(messages, tools);
        final choice = (resp['choices'] as List?)?.firstOrNull;
        final msg = (choice as Map?)?['message'] as Map<String, dynamic>?;
        if (msg == null) {
          yield const AgentError('Resposta vazia do modelo.');
          return;
        }

        final rawToolCalls = (msg['tool_calls'] as List?) ?? const [];
        final content = (msg['content'] as String?) ?? '';

        if (rawToolCalls.isEmpty) {
          // Resposta final — streama em pedaços para dar sensação de digitação.
          yield* _stream(content.isEmpty
              ? 'Não consegui gerar uma resposta. Tente reformular.'
              : content);
          yield AgentDone(content);
          return;
        }

        // Há tool calls: registra a mensagem do assistant e executa as tools.
        messages.add({
          'role': 'assistant',
          'content': content.isEmpty ? null : content,
          'tool_calls': rawToolCalls,
        });

        for (final raw in rawToolCalls) {
          final tc = raw as Map<String, dynamic>;
          final id = (tc['id'] ?? '').toString();
          final fn = (tc['function'] as Map?) ?? const {};
          final name = (fn['name'] ?? '').toString();
          final argsStr = (fn['arguments'] ?? '{}').toString();

          yield AgentThinking(name, id);

          Map<String, dynamic> args;
          try {
            final decoded = jsonDecode(argsStr.isEmpty ? '{}' : argsStr);
            args = decoded is Map<String, dynamic>
                ? decoded
                : <String, dynamic>{};
          } catch (_) {
            args = <String, dynamic>{};
          }

          String result;
          var okFlag = true;
          try {
            final saida = await callTool(name, args);
            result = saida.text;
            okFlag = !saida.isError;
          } catch (e) {
            result = 'Erro: $e';
            okFlag = false;
          }

          yield AgentToolDone(name, id, okFlag);

          messages.add({
            'role': 'tool',
            'tool_call_id': id,
            'content': _truncar(result),
          });
        }
      }

      // Esgotou as rodadas sem resposta final.
      yield const AgentError(
          'Limite de rodadas de ferramentas atingido sem resposta final.');
    } catch (e) {
      yield AgentError(_friendlyError(e));
    }
  }

  /// **Planner** (modo Agentes): decompõe um objetivo em 2–6 tarefas paralelas
  /// e independentes, cada uma com `prompt` autossuficiente.
  Future<List<PlanTask>> plan(String objective) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _plannerPrompt()},
      {'role': 'user', 'content': objective},
    ];
    final resp = await _complete(messages, const []);
    final choice = (resp['choices'] as List?)?.firstOrNull;
    final content =
        ((choice as Map?)?['message'] as Map?)?['content']?.toString() ?? '';
    return _parsePlan(content);
  }

  /// Executa uma tarefa (com ferramentas MCP) e retorna o texto final.
  /// Versão não-streaming usada pela execução paralela do orquestrador.
  Future<String> runToString({
    required String prompt,
    required List<Map<String, dynamic>> toolSpecs,
    required ToolExecutor callTool,
    required String clinicaId,
  }) async {
    final buffer = StringBuffer();
    String? finalText;
    await for (final ev in run(
      history: [ChatMessage(role: ChatRole.user, content: prompt)],
      toolSpecs: toolSpecs,
      callTool: callTool,
      clinicaId: clinicaId,
    )) {
      if (ev is AgentToken) {
        buffer.write(ev.text);
      } else if (ev is AgentDone) {
        finalText = ev.text;
      } else if (ev is AgentError) {
        throw StateError(ev.message);
      }
    }
    final result = (finalText != null && finalText.isNotEmpty)
        ? finalText
        : buffer.toString();
    return result.isEmpty ? 'Sem resultado.' : result;
  }

  String _plannerPrompt() {
    return '''
Você é um PLANEJADOR de agentes para uma plataforma de gestão clínica.
Decomponha o objetivo do usuário em 2 a 6 tarefas PARALELAS e INDEPENDENTES,
cada uma executável sozinha por um agente com acesso às ferramentas MCP
(agendamentos, médicos, pacientes, risco, overbooking, e-mail, etc.).

Responda APENAS com um array JSON válido, sem texto extra, no formato:
[
  {"titulo": "Título curto", "prompt": "Instrução autossuficiente para o agente", "complex": false}
]
Regras: cada "prompt" deve ser claro e independente das outras tarefas; use
"complex": true só para tarefas que exigem análise mais profunda.
''';
  }

  List<PlanTask> _parsePlan(String content) {
    var s = content.trim();
    // Remove cercas de código ```json ... ```
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final fm = fence.firstMatch(s);
    if (fm != null) s = fm.group(1)!.trim();
    // Isola o primeiro array JSON.
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start >= 0 && end > start) s = s.substring(start, end + 1);

    try {
      final decoded = jsonDecode(s);
      if (decoded is! List) return const [];
      final tasks = <PlanTask>[];
      for (final e in decoded) {
        if (e is Map) {
          final titulo = (e['titulo'] ?? e['title'] ?? 'Tarefa').toString();
          final prompt = (e['prompt'] ?? e['instrucao'] ?? '').toString();
          if (prompt.trim().isEmpty) continue;
          tasks.add(PlanTask(
            titulo: titulo,
            prompt: prompt,
            complex: e['complex'] == true,
          ));
        }
      }
      return tasks.take(6).toList();
    } catch (_) {
      return const [];
    }
  }

  /// POST direto ao Azure AI Foundry (chat-completions OpenAI-compatível).
  ///
  /// Tenta os endpoints de [_urls] em ordem: falhas de rede/CORS ("Failed to
  /// fetch") só são propagadas quando **todos** falham. Um status HTTP de erro
  /// (não-200) é definitivo e não dispara fallback — o servidor respondeu.
  /// Corta o resultado de uma ferramenta, avisando o modelo do corte.
  ///
  /// A marca importa: sem ela o modelo conclui sobre uma lista que acha
  /// completa. Com ela, sabe que precisa filtrar.
  String _truncar(String texto) {
    if (texto.length <= maxCharsPorResultado) return texto;
    final corte = texto.substring(0, maxCharsPorResultado);
    final sobra = texto.length - maxCharsPorResultado;
    return '$corte\n\n[resultado truncado: $sobra caracteres a mais. '
        'Refaça a chamada com filtro mais estreito ou "limite" menor.]';
  }

  Future<Map<String, dynamic>> _complete(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      if (tools.isNotEmpty) 'tools': tools,
      if (tools.isNotEmpty) 'tool_choice': 'auto',
      'temperature': 0.4,
    });
    final headers = {
      'Content-Type': 'application/json',
      if (_apiKey.isNotEmpty) 'api-key': _apiKey,
    };

    Object? lastError;
    for (final url in _urls) {
      // Retenta no mesmo host em caso de throttling (429) ou indisponibilidade
      // temporária (503), com backoff que respeita o header `Retry-After`.
      for (var attempt = 0;; attempt++) {
        final http.Response res;
        try {
          res = await _client
              .post(
                Uri.parse(url),
                headers: headers,
                body: body,
              )
              .timeout(const Duration(seconds: 90));
        } catch (e) {
          // Host inacessível (Failed to fetch/timeout): tenta o próximo.
          lastError = e;
          break;
        }

        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Formato de resposta inesperado.');
          }
          return decoded;
        }

        if ((res.statusCode == 429 || res.statusCode == 503) &&
            attempt < maxRetries) {
          await Future<void>.delayed(_retryDelay(res, attempt));
          continue;
        }

        // Erro definitivo (inclui 429 após esgotar as tentativas).
        throw HttpException(res.statusCode, res.body);
      }
    }

    // Todos os hosts falharam ao conectar.
    throw lastError ?? const FormatException('Nenhum host de IA disponível.');
  }

  /// Espera antes de retentar: usa o header `Retry-After` (segundos) quando
  /// presente; senão, backoff exponencial 1s → 2s → 4s com um leve jitter.
  Duration _retryDelay(http.Response res, int attempt) {
    final retryAfter = res.headers['retry-after'];
    if (retryAfter != null) {
      final secs = int.tryParse(retryAfter.trim());
      if (secs != null) {
        return Duration(seconds: secs.clamp(1, 30));
      }
    }
    final base = 1 << attempt; // 1, 2, 4
    return Duration(milliseconds: base * 1000 + attempt * 150);
  }

  /// Converte os specs MCP (`{name, description, inputSchema}`) para o formato
  /// de function-calling da OpenAI/Azure.
  List<Map<String, dynamic>> _toOpenAiTools(
      List<Map<String, dynamic>> specs) {
    return [
      for (final s in specs)
        {
          'type': 'function',
          'function': {
            'name': s['name'],
            'description': s['description'],
            'parameters': s['inputSchema'] ??
                {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
    ];
  }

  /// Streama um texto em pequenos blocos (efeito de digitação).
  Stream<AgentEvent> _stream(String text) async* {
    final words = text.split(RegExp(r'(?<= )'));
    final buffer = StringBuffer();
    var i = 0;
    for (final w in words) {
      buffer.write(w);
      i++;
      // Emite a cada ~3 palavras para reduzir rebuilds.
      if (i % 3 == 0) {
        yield AgentToken(buffer.toString());
        buffer.clear();
        await Future<void>.delayed(const Duration(milliseconds: 18));
      }
    }
    if (buffer.isNotEmpty) yield AgentToken(buffer.toString());
  }

  String _systemPrompt(String clinicaId) {
    return '''
Você é o **Assistente Vitta**, um agente de gestão clínica que opera SOMENTE
com os dados da clínica do usuário logado (clinicaId: $clinicaId). Isolamento
multi-tenant é obrigatório: nunca peça nem aceite outro clinicaId — as
ferramentas já estão travadas nessa clínica.

Diretrizes:
- Responda em português do Brasil, de forma objetiva e profissional.
- Use as ferramentas MCP disponíveis para consultar/agir sobre dados reais
  (agendamentos, médicos, pacientes, risco de absenteísmo, overbooking, e-mail,
  WhatsApp, tarefas agendadas). Não invente dados — se não houver, diga.
- Antes de ações sensíveis (criar agendamento, enviar e-mail/WhatsApp, agendar
  tarefa), confirme os parâmetros essenciais com o usuário se estiverem ambíguos.
- Para visualizações, você pode incluir UM bloco de gráfico no formato:
  ```json-chart
  {"type":"bar|line|pie","title":"...","data":[{"label":"Seg","value":12}]}
  ```
  Use apenas quando ajudar a entender números.
- Seja conciso. Use markdown (listas, negrito, tabelas) quando útil.
''';
  }

  /// Traduz a falha em algo que aponte a causa certa.
  ///
  /// A versão anterior dizia "credencial recusada — verifique a chave do Azure"
  /// em todo 401. Isso mandava para o lugar errado no caso mais comum: build
  /// **sem** `AI_PROXY_URL` nem `AZURE_AI_KEY`. Aí não há chave nenhuma para
  /// verificar — a requisição sai sem header e o Azure recusa, corretamente.
  /// Quem lia a mensagem ia auditar uma chave que não existe.
  String _friendlyError(Object e) {
    if (e is HttpException) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        if (!AiConfig.isConfigured) {
          return 'A IA não está configurada nesta build. Rode com '
              '--dart-define=AI_PROXY_URL=<url do chatProxy> (recomendado, a '
              'credencial fica no servidor) ou --dart-define=AZURE_AI_KEY=<chave> '
              'para acesso direto em desenvolvimento.';
        }
        return 'Credencial da IA recusada (HTTP ${e.statusCode}). '
            '${AiConfig.usesProxy ? "O proxy respondeu, mas a credencial dele foi rejeitada pelo provedor." : "Verifique a chave do Azure AI Foundry."}';
      }
      if (e.statusCode == 429) {
        return 'Limite de requisições da IA atingido (HTTP 429). A cota do '
            'Azure DeepSeek está saturada — aguarde alguns segundos e tente '
            'novamente, ou reduza o número de tarefas em paralelo.';
      }
      // 5xx vindo do proxy quase nunca é a IA: é a própria Cloud Function
      // caindo. Já aconteceu com o faturamento do projeto desligado, que
      // impede a function de ler o segredo com a chave.
      if (e.statusCode >= 500 && AiConfig.usesProxy) {
        return 'O serviço de IA (chatProxy) respondeu ${e.statusCode}. A falha é '
            'da Cloud Function, não da sua pergunta — verifique os logs dela '
            '(`firebase functions:log --only chatProxy`) e se o faturamento do '
            'projeto está habilitado.';
      }
      return 'Erro ${e.statusCode} ao falar com a IA: ${e.body}';
    }
    if (e is TimeoutException) {
      return 'Tempo esgotado ao aguardar a IA. Tente novamente.';
    }
    return 'Falha ao conectar ao endpoint de IA: $e.';
  }

  void dispose() => _client.close();
}

class HttpException implements Exception {
  const HttpException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'HttpException($statusCode)';
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
