import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../agent/agent_controller.dart';
import '../agent/agent_models.dart';
import '../agent/chat_interface.dart';
import '../agent/ia_session.dart';
import 'ai_chart_view.dart';
import 'attachment_button.dart';
import 'ia_suggestions_panel.dart';
import 'voice_mic_button.dart';

/// Painel de chat funcional do agente de IA (`.specify/AgentAI.md`).
///
/// Loop de ferramentas MCP + streaming + markdown + gráficos `json-chart`.
class AiChatPanel extends ConsumerStatefulWidget {
  const AiChatPanel({super.key});

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  /// Prompt aplicado a partir de uma sugestão. Enquanto o campo contiver
  /// exatamente esse texto, o painel de sugestões fica oculto (evita reabrir
  /// mostrando a própria sugestão recém-escolhida).
  String? _appliedSuggestion;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
  }

  void _onChanged() {
    // O usuário editou o texto → volta a permitir sugestões.
    if (_appliedSuggestion != null && _controller.text != _appliedSuggestion) {
      _appliedSuggestion = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _focus.removeListener(_onChanged);
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSuggestion(String prompt) {
    _appliedSuggestion = prompt;
    _controller
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    _focus.requestFocus();
  }

  void _send([String? preset]) {
    final typed = (preset ?? _controller.text).trim();
    final attachments = ref.read(pendingAttachmentsProvider);
    if (typed.isEmpty && attachments.isEmpty) return;

    // Injeta o conteúdo dos anexos como contexto (AgentAI.md §7.1.2).
    final buffer = StringBuffer();
    for (final entry in attachments.entries) {
      buffer
        ..writeln('[Contexto do documento "${entry.key}"]')
        ..writeln(entry.value)
        ..writeln();
    }
    if (typed.isNotEmpty) buffer.write(typed);

    _controller.clear();
    ref.read(pendingAttachmentsProvider.notifier).clear();
    ref.read(agentChatProvider.notifier).send(buffer.toString());
    _scrollToEndSoon();
  }

  void _onVoice(String text) {
    _controller
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  void _onAttachment(String name, String text) {
    ref.read(pendingAttachmentsProvider.notifier).add(name, text);
  }

  void _scrollToEndSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentChatProvider);
    final style = chatStyleOf(ref.watch(effectiveChatInterfaceProvider));
    // Mantém o scroll perto do fim enquanto o agente responde.
    ref.listen(agentChatProvider, (_, _) => _scrollToEndSoon());

    return Column(
      children: [
        Expanded(
          child: state.isEmpty
              ? _Welcome(onPick: _send, style: style)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: state.messages.length,
                  itemBuilder: (_, i) {
                    final m = state.messages[i];
                    if (m.role == ChatRole.system || m.role == ChatRole.tool) {
                      return const SizedBox.shrink();
                    }
                    return _MessageBubble(message: m, style: style);
                  },
                ),
        ),
        if (_focus.hasFocus && _appliedSuggestion == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: IaSuggestionsPanel(
                query: _controller.text, onSelect: _onSuggestion),
          ),
        _InputBar(
          controller: _controller,
          focusNode: _focus,
          running: state.running,
          onSend: _send,
          attachments: ref.watch(pendingAttachmentsProvider).keys.toList(),
          onRemoveAttachment: (name) =>
              ref.read(pendingAttachmentsProvider.notifier).remove(name),
          onVoice: _onVoice,
          onAttachment: _onAttachment,
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick, required this.style});
  final void Function(String) onPick;
  final ChatInterfaceStyle style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(style.icon, color: style.accent, size: 40),
            const SizedBox(height: AppSpacing.lg),
            Text(style.welcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 30 * style.fontScale,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              style.welcomeSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 15 * style.fontScale,
                  height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: [
                for (final s in style.suggestions)
                  _SuggestCard(
                    icon: s.icon,
                    color: s.color,
                    title: s.title,
                    prompt: s.prompt,
                    onTap: () => onPick(s.prompt),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestCard extends StatelessWidget {
  const _SuggestCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.prompt,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.style});
  final ChatMessage message;
  final ChatInterfaceStyle style;

  @override
  Widget build(BuildContext context) =>
      style.bubbles ? _bubbleLayout(context) : _documentLayout(context);

  /// Layout em balões (usuário à direita, assistente à esquerda).
  Widget _bubbleLayout(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: EdgeInsets.all(AppSpacing.lg * style.density),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
        decoration: BoxDecoration(
          color: isUser ? style.accent : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border:
              isUser ? null : Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.toolCalls.isNotEmpty) ...[
              _ToolChips(calls: message.toolCalls),
              const SizedBox(height: AppSpacing.sm),
            ],
            ..._renderContent(context, message, isUser),
          ],
        ),
      ),
    );
  }

  /// Layout "documento" full-width: cada mensagem ocupa a largura, rotulada
  /// (Assistente / Você). Leitura corrida, ideal p/ perfis executivo e clínico.
  Widget _documentLayout(BuildContext context) {
    final isUser = message.isUser;
    final bg = isUser
        ? style.accent.withValues(alpha: 0.12)
        : AppColors.surfaceOf(context).withValues(alpha: 0.4);
    final border = isUser
        ? style.accent.withValues(alpha: 0.35)
        : AppColors.borderOf(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: EdgeInsets.all(AppSpacing.lg * style.density),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isUser ? Icons.person_outline : style.icon,
                  size: 14 * style.fontScale, color: style.accent),
              const SizedBox(width: 6),
              Text(isUser ? 'Você' : 'Assistente',
                  style: TextStyle(
                      color: style.accent,
                      fontSize: 11 * style.fontScale,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (message.toolCalls.isNotEmpty) ...[
            _ToolChips(calls: message.toolCalls),
            const SizedBox(height: AppSpacing.sm),
          ],
          // Full-width: texto sempre na cor primária (fundo claro/translúcido).
          ..._renderContent(context, message, false),
        ],
      ),
    );
  }

  /// Cor de texto legível sobre o acento (preto/branco por luminância).
  static Color _onAccent(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  List<Widget> _renderContent(
      BuildContext context, ChatMessage m, bool isUser) {
    if (m.content.isEmpty) {
      if (m.streaming) {
        return [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.textSecondaryOf(context)),
          ),
        ];
      }
      return const [SizedBox.shrink()];
    }

    final scale = style.fontScale;
    final textColor =
        isUser ? _onAccent(style.accent) : AppColors.textPrimaryOf(context);
    final segments = _splitCharts(m.content);
    return [
      for (final seg in segments)
        seg.chart != null
            ? AiChartView(spec: seg.chart!)
            : MarkdownBody(
                data: seg.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: textColor, height: 1.4, fontSize: 14 * scale),
                  listBullet:
                      TextStyle(color: textColor, fontSize: 14 * scale),
                  strong: TextStyle(
                      color: textColor, fontWeight: FontWeight.bold),
                  h1: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20 * scale),
                  h2: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17 * scale),
                  h3: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15 * scale),
                  code: TextStyle(
                      color: textColor, backgroundColor: AppColors.surfaceAltOf(context)),
                  tableBorder: TableBorder.all(color: AppColors.borderOf(context)),
                  tableHead: TextStyle(
                      color: textColor, fontWeight: FontWeight.bold),
                  tableBody:
                      TextStyle(color: textColor, fontSize: 14 * scale),
                ),
              ),
      if (m.streaming)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('▍',
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context), fontSize: 12)),
        ),
    ];
  }
}

/// Segmento de conteúdo: texto markdown OU um gráfico.
class _Segment {
  _Segment.text(this.text) : chart = null;
  _Segment.chart(this.chart) : text = '';
  final String text;
  final ChartSpec? chart;
}

/// Separa blocos ```json-chart``` do restante do markdown.
List<_Segment> _splitCharts(String content) {
  final regex = RegExp(r'```json-chart\s*([\s\S]*?)```', multiLine: true);
  final segments = <_Segment>[];
  var last = 0;
  for (final match in regex.allMatches(content)) {
    if (match.start > last) {
      final t = content.substring(last, match.start).trim();
      if (t.isNotEmpty) segments.add(_Segment.text(t));
    }
    final spec = ChartSpec.tryParse(match.group(1)?.trim() ?? '');
    if (spec != null) {
      segments.add(_Segment.chart(spec));
    } else {
      // JSON ainda incompleto (streaming) → placeholder.
      segments.add(_Segment.text('_Gerando gráfico…_'));
    }
    last = match.end;
  }
  if (last < content.length) {
    final t = content.substring(last).trim();
    if (t.isNotEmpty) segments.add(_Segment.text(t));
  }
  if (segments.isEmpty) segments.add(_Segment.text(content));
  return segments;
}

class _ToolChips extends StatelessWidget {
  const _ToolChips({required this.calls});
  final List<ToolCall> calls;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in calls)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(
                color: c.done
                    ? (c.ok == true ? Colors.tealAccent : AppColors.danger)
                        .withValues(alpha: 0.4)
                    : AppColors.borderOf(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!c.done)
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.6, color: AppColors.pinkAccent),
                  )
                else
                  Icon(
                    c.ok == true ? Icons.check_circle : Icons.error,
                    size: 12,
                    color: c.ok == true ? Colors.tealAccent : AppColors.danger,
                  ),
                const SizedBox(width: 5),
                Text(
                  c.name,
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.running,
    required this.onSend,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onVoice,
    required this.onAttachment,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool running;
  final void Function([String?]) onSend;
  final List<String> attachments;
  final void Function(String name) onRemoveAttachment;
  final void Function(String text) onVoice;
  final void Function(String name, String text) onAttachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in attachments)
                    Chip(
                      backgroundColor: AppColors.surfaceAltOf(context),
                      side: BorderSide(color: AppColors.borderOf(context)),
                      avatar: const Icon(Icons.description,
                          size: 14, color: AppColors.pinkAccent),
                      label: Text(name,
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      deleteIconColor: AppColors.textSecondaryOf(context),
                      onDeleted: () => onRemoveAttachment(name),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              children: [
                AttachmentButton(onExtracted: onAttachment, enabled: !running),
                VoiceMicButton(onText: onVoice, enabled: !running),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !running,
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: (_) => onSend(),
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: InputDecoration(
                      hintText: 'Pergunte algo ao DeepSeek…',
                      hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                running
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.pinkAccent),
                        ),
                      )
                    : IconButton(
                        onPressed: () => onSend(),
                        icon: const Icon(Icons.send,
                            color: AppColors.pinkAccent),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
