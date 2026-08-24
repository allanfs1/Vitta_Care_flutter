import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modules/mcp/mcp_providers.dart';
import 'agent_models.dart';
import 'ai_agent_service.dart';
import 'ia_chats_service.dart';
import 'ia_session.dart';

/// Estado do chat do agente de IA.
class AgentChatState {
  const AgentChatState({this.messages = const [], this.running = false});

  final List<ChatMessage> messages;
  final bool running;

  bool get isEmpty => messages.where((m) => m.role != ChatRole.system).isEmpty;

  AgentChatState copyWith({List<ChatMessage>? messages, bool? running}) =>
      AgentChatState(
        messages: messages ?? this.messages,
        running: running ?? this.running,
      );
}

final aiAgentServiceProvider = Provider<AiAgentService>((ref) {
  final service = AiAgentService(maxRetries: ref.watch(agentMaxRetriesProvider));
  ref.onDispose(service.dispose);
  return service;
});

final agentChatProvider =
    StateNotifierProvider<AgentChatController, AgentChatState>((ref) {
  return AgentChatController(ref);
});

/// Orquestra a conversa: envia ao [AiAgentService] (Cloud Function → DeepSeek)
/// e executa as ferramentas MCP via [mcpServerProvider]. Respeita o isolamento
/// multi-tenant — todas as tools operam só na clínica do usuário logado.
class AgentChatController extends StateNotifier<AgentChatState> {
  AgentChatController(this._ref) : super(const AgentChatState());

  final Ref _ref;
  StreamSubscription<AgentEvent>? _sub;

  /// Id da conversa persistida (null = ainda não salva).
  String? _chatId;
  String? get chatId => _chatId;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.running) return;

    final server = _ref.read(mcpServerProvider);
    final specs = _ref.read(mcpToolSpecsProvider);
    final clinicaId = server.ctx.defaultClinicaId;

    final userMsg = ChatMessage(role: ChatRole.user, content: trimmed);
    final assistant =
        ChatMessage(role: ChatRole.assistant, content: '', streaming: true);

    // Histórico enviado ao modelo: tudo que já existe + a nova pergunta
    // (sem o placeholder do assistant).
    final history = [...state.messages, userMsg];

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistant],
      running: true,
    );

    final stream = _ref.read(aiAgentServiceProvider).run(
          history: history,
          toolSpecs: specs,
          clinicaId: clinicaId,
          callTool: (name, args) async {
            final r = await server.callTool(name, args);
            return r.text;
          },
        );

    final completer = Completer<void>();
    _sub = stream.listen(
      (event) {
        switch (event) {
          case AgentThinking(:final toolName, :final callId):
            assistant.toolCalls = [
              ...assistant.toolCalls,
              ToolCall(id: callId, name: toolName, arguments: ''),
            ];
          case AgentToolDone(:final callId, :final ok):
            for (final tc in assistant.toolCalls) {
              if (tc.id == callId) {
                tc.done = true;
                tc.ok = ok;
              }
            }
          case AgentToken(:final text):
            assistant.content += text;
          case AgentDone(:final text):
            if (text.isNotEmpty) assistant.content = text;
            assistant.streaming = false;
          case AgentError(:final message):
            assistant.content = assistant.content.isEmpty
                ? '⚠️ $message'
                : '${assistant.content}\n\n⚠️ $message';
            assistant.streaming = false;
        }
        _bump();
      },
      onError: (Object e) {
        assistant.content = '⚠️ Erro inesperado: $e';
        assistant.streaming = false;
        _bump();
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        assistant.streaming = false;
        _bump();
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
    state = state.copyWith(running: false);

    // Persiste a conversa (multi-tenant). Falhas não quebram a UX.
    try {
      final titulo = _titleFrom(state.messages);
      _chatId = await _ref.read(iaChatsServiceProvider).saveChat(
            chatId: _chatId,
            titulo: titulo,
            messages: state.messages
                .where((m) =>
                    m.role == ChatRole.user || m.role == ChatRole.assistant)
                .toList(),
            clinicaId: server.ctx.defaultClinicaId,
          );
    } catch (_) {/* ignora falha de persistência */}
  }

  String _titleFrom(List<ChatMessage> messages) {
    final firstUser = messages.firstWhere(
      (m) => m.role == ChatRole.user,
      orElse: () => ChatMessage(role: ChatRole.user, content: 'Conversa'),
    );
    final t = firstUser.content.trim().replaceAll('\n', ' ');
    return t.length <= 48 ? t : '${t.substring(0, 48)}…';
  }

  /// Inicia uma nova conversa (limpa o estado e o id persistido).
  void newConversation() {
    _sub?.cancel();
    _chatId = null;
    state = const AgentChatState();
  }

  /// Carrega uma conversa salva pelo id.
  Future<void> loadConversation(String id) async {
    _sub?.cancel();
    try {
      final messages = await _ref.read(iaChatsServiceProvider).loadMessages(id);
      _chatId = id;
      state = AgentChatState(messages: messages);
    } catch (_) {/* mantém estado atual */}
  }

  /// Emite uma nova referência de lista para acionar o rebuild.
  void _bump() {
    state = state.copyWith(messages: [...state.messages]);
  }

  void reset() {
    _sub?.cancel();
    state = const AgentChatState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
