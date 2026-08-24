import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// IA-02/IA-04 — assistente de chat com IA (streaming de resposta).
void showAiChatSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _AiChatView(),
    ),
  );
}

class _ChatMessage {
  _ChatMessage(this.text, {required this.fromUser});
  String text;
  final bool fromUser;
}

class _AiChatView extends ConsumerStatefulWidget {
  const _AiChatView();

  @override
  ConsumerState<_AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends ConsumerState<_AiChatView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage('Olá! Sou o assistente Vitta. Pergunte sobre seus dados.',
        fromUser: false),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(text, fromUser: true));
      _messages.add(_ChatMessage('', fromUser: false));
      _sending = true;
      _controller.clear();
    });
    final reply = _messages.last;
    await for (final chunk in ref.read(aiServiceProvider).chat(text)) {
      if (!mounted) return;
      setState(() => reply.text += chunk);
      _scrollToEnd();
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Assistente Vitta', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(message: _messages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Pergunte algo…'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromUser = message.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: message.text.isEmpty
            ? Text('…', style: theme.textTheme.bodyMedium?.copyWith(color: fromUser ? Colors.white : AppColors.textPrimary))
            : MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    color: fromUser ? Colors.white : AppColors.textPrimary,
                  ),
                  h1: theme.textTheme.titleLarge?.copyWith(
                    color: fromUser ? Colors.white : AppColors.textPrimary,
                  ),
                  h2: theme.textTheme.titleMedium?.copyWith(
                    color: fromUser ? Colors.white : AppColors.textPrimary,
                  ),
                  h3: theme.textTheme.titleSmall?.copyWith(
                    color: fromUser ? Colors.white : AppColors.textPrimary,
                  ),
                  listBullet: theme.textTheme.bodyMedium?.copyWith(
                    color: fromUser ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}
