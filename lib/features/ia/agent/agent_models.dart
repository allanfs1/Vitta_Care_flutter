import 'dart:convert';

/// Modelos do chat/agente de IA (`.specify/AgentAI.md`).

/// Papel de uma mensagem na conversa (formato OpenAI/Azure).
enum ChatRole { system, user, assistant, tool }

extension ChatRoleApi on ChatRole {
  String get api => switch (this) {
        ChatRole.system => 'system',
        ChatRole.user => 'user',
        ChatRole.assistant => 'assistant',
        ChatRole.tool => 'tool',
      };
}

/// Uma chamada de ferramenta solicitada pelo modelo.
class ToolCall {
  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.ok,
    this.done = false,
  });

  final String id;
  final String name;

  /// Argumentos como JSON string (formato OpenAI) — pode vir parcial.
  final String arguments;

  /// Resultado da execução: `null` enquanto roda, `true`/`false` ao concluir.
  bool? ok;
  bool done;

  Map<String, dynamic> parseArgs() {
    try {
      final v = jsonDecode(arguments.isEmpty ? '{}' : arguments);
      return v is Map<String, dynamic> ? v : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

/// Uma tarefa do plano multi-agente (modo Agentes, AgentAI.md §7.1.4).
class PlanTask {
  PlanTask({required this.titulo, required this.prompt, this.complex = false});

  final String titulo;
  final String prompt;
  final bool complex;
}

/// Status de execução de uma tarefa do orquestrador.
enum TaskStatus { idle, running, done, error }

/// Mensagem exibida no chat e/ou enviada ao modelo.
class ChatMessage {
  ChatMessage({
    required this.role,
    this.content = '',
    this.toolCalls = const [],
    this.toolCallId,
    this.streaming = false,
  });

  final ChatRole role;
  String content;

  /// Tool calls emitidas por uma mensagem de assistant.
  List<ToolCall> toolCalls;

  /// Para mensagens role=tool: a qual tool_call respondem.
  final String? toolCallId;

  /// `true` enquanto o texto ainda está sendo gerado (mostra cursor/animação).
  bool streaming;

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;

  /// Serialização para persistência (Firestore `tb_ia_chats`).
  Map<String, dynamic> toStore() => {
        'role': role.api,
        'content': content,
        if (toolCalls.isNotEmpty)
          'tools': [
            for (final t in toolCalls)
              {'name': t.name, 'ok': t.ok, 'done': t.done},
          ],
      };

  /// Reconstrói uma mensagem a partir do mapa persistido.
  static ChatMessage fromStore(Map<String, dynamic> m) {
    final roleStr = (m['role'] ?? 'assistant').toString();
    final role = ChatRole.values.firstWhere(
      (r) => r.api == roleStr,
      orElse: () => ChatRole.assistant,
    );
    final tools = <ToolCall>[];
    final rawTools = m['tools'];
    if (rawTools is List) {
      for (final t in rawTools) {
        if (t is Map) {
          tools.add(ToolCall(
            id: '',
            name: (t['name'] ?? '').toString(),
            arguments: '',
            ok: t['ok'] is bool ? t['ok'] as bool : null,
            done: t['done'] == true,
          ));
        }
      }
    }
    return ChatMessage(
      role: role,
      content: (m['content'] ?? '').toString(),
      toolCalls: tools,
    );
  }

  /// Serialização para a API de chat (Cloud Function → Azure DeepSeek).
  Map<String, dynamic> toApi() {
    final m = <String, dynamic>{'role': role.api};
    if (role == ChatRole.tool) {
      m['content'] = content;
      m['tool_call_id'] = toolCallId;
      return m;
    }
    if (toolCalls.isNotEmpty) {
      m['content'] = content.isEmpty ? null : content;
      m['tool_calls'] = [
        for (final t in toolCalls)
          {
            'id': t.id,
            'type': 'function',
            'function': {'name': t.name, 'arguments': t.arguments},
          },
      ];
    } else {
      m['content'] = content;
    }
    return m;
  }
}
