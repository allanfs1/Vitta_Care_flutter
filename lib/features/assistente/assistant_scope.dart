import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_router.dart';
import 'assistant_anchors.dart';
import 'assistant_controller.dart';
import 'assistant_models.dart';
import 'assistant_tours.dart';

/// Rotas onde o botão "Ajuda" e o chat ficam ocultos (quiosque / autenticação).
/// O tour com spotlight continua funcionando (ex.: tour do totem).
const Set<String> _hiddenAssistantRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.choosePlan,
  AppRoutes.totem,
  AppRoutes.recepcaoMonitor,
};

/// Envolve o app inteiro, adicionando o assistente de ajuda global:
/// botão flutuante (sempre acessível), painel de chat e o tour com spotlight.
///
/// A camada do assistente vive dentro de um [Overlay] próprio, pois fica fora
/// do Navigator do app — widgets como [TextField]/[Tooltip] exigem um Overlay
/// ancestral (senão dá "No Overlay widget found").
class AssistantScope extends StatelessWidget {
  const AssistantScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Positioned.fill(
          child: Overlay(
            initialEntries: [
              OverlayEntry(builder: (_) => const _AssistantLayer()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Camada do assistente (dentro do Overlay): FAB, chat e spotlight.
class _AssistantLayer extends ConsumerStatefulWidget {
  const _AssistantLayer();

  @override
  ConsumerState<_AssistantLayer> createState() => _AssistantLayerState();
}

class _AssistantLayerState extends ConsumerState<_AssistantLayer>
    with SingleTickerProviderStateMixin {
  String? _lastStepKey;
  Timer? _scrollTimer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Executado uma vez por passo: navega para a tela e rola o alvo para a visão.
  void _onStep(AssistantState s) {
    final step = s.currentStep;
    if (step == null) return;
    final key = '${s.activeTour!.id}#${s.stepIndex}';
    if (key == _lastStepKey) return;
    _lastStepKey = key;

    // IMPORTANTE: navegar pela instância do router (o context deste overlay
    // está acima do InheritedGoRouter, então GoRouter.of(context) falharia).
    final router = ref.read(routerProvider);
    if (step.route != null) {
      final current = router.routerDelegate.currentConfiguration.uri.path;
      if (step.route != current) router.go(step.route!);
    }

    _scrollTimer?.cancel();
    if (step.anchorId != null) {
      _ensureVisible(step.anchorId!, attempt: 0);
    }
  }

  /// Rola o elemento-alvo para a área visível, tentando repetidamente até a
  /// tela montar; reaplica algumas vezes para estabilizar após rebuilds.
  void _ensureVisible(String anchorId, {required int attempt}) {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(
      Duration(milliseconds: attempt == 0 ? 240 : 150),
      () {
        if (!mounted) return;
        final ctx = ref.read(assistantAnchorsProvider).contextOf(anchorId);
        if (ctx != null && ctx.mounted) {
          try {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
              alignment: 0.28,
              curve: Curves.easeOutCubic,
            );
          } catch (_) {}
          // achou: reaplica 1-2x para garantir após a navegação assentar
          if (attempt < 3) _ensureVisible(anchorId, attempt: attempt + 1);
        } else if (attempt < 14) {
          // ainda montando a nova tela → continua tentando
          _ensureVisible(anchorId, attempt: attempt + 1);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(assistantProvider);
    final router = ref.watch(routerProvider);
    if (s.inTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onStep(s));
    } else {
      _lastStepKey = null;
    }

    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        final hideUi = _hiddenAssistantRoutes.contains(path);
        return Stack(
          textDirection: TextDirection.ltr,
          children: [
            if (!s.inTour && !hideUi) _Fab(open: s.isOpen),
            if (s.isOpen && !s.inTour && !hideUi) _ChatPanel(),
            if (s.inTour)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) {
                  // Rect calculado AO VIVO a cada frame → o lightbox acompanha
                  // a rolagem/relayout e aparece assim que o alvo monta.
                  final step = s.currentStep;
                  final anchorId = step?.anchorId;
                  final rect = anchorId == null
                      ? null
                      : ref.read(assistantAnchorsProvider).rectOf(anchorId);
                  return _Spotlight(rect: rect, pulse: _pulse.value);
                },
              ),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------- FAB
class _Fab extends ConsumerWidget {
  const _Fab({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    // Botão Material puro (sem Hero/Scaffold) — vive fora do Navigator.
    return Positioned(
      left: 20,
      bottom: 20,
      child: Material(
        color: accent,
        elevation: 6,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(assistantProvider.notifier).toggle(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(open ? Icons.close : Icons.support_agent,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(open ? 'Fechar' : 'Ajuda',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Chat
class _ChatPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text;
    _ctrl.clear();
    ref.read(assistantProvider.notifier).send(t);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(assistantProvider);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 700;
    final panelWidth = wide ? 380.0 : size.width;
    final panelHeight = wide ? size.height : size.height * 0.72;

    final panel = Material(
      elevation: 16,
      color: theme.colorScheme.surface,
      borderRadius: wide
          ? const BorderRadius.only(
              topLeft: Radius.circular(20), bottomLeft: Radius.circular(20))
          : const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: Column(
          children: [
            // header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(color: accent),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.support_agent, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Assistente Vitta',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Limpar conversa',
                    onPressed: () =>
                        ref.read(assistantProvider.notifier).clearChat(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () =>
                        ref.read(assistantProvider.notifier).close(),
                  ),
                ],
              ),
            ),
            // messages
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(14),
                children: [
                  for (final m in s.messages) _bubble(m, accent, theme),
                  if (s.messages.length <= 1) ...[
                    _starters(accent),
                    _tourSuggestions(accent),
                  ],
                ],
              ),
            ),
            // input
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Pergunte ou descreva o que precisa…',
                          isDense: true,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: accent),
                      onPressed: s.thinking ? null : _send,
                      icon: const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned(
      left: 0,
      bottom: 0,
      top: wide ? 0 : null,
      child: panel,
    );
  }

  Widget _bubble(AssistantMessage m, Color accent, ThemeData theme) {
    final isUser = m.role == AssistantRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? accent : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(m.text, style: const TextStyle(color: Colors.white, height: 1.35))
            else if (m.text.isEmpty && m.streaming)
              Text('…',
                  style: TextStyle(color: theme.colorScheme.onSurface, height: 1.35))
            else
              MarkdownBody(
                data: m.text,
                shrinkWrap: true,
                styleSheet: _mdStyle(theme),
              ),
            if (m.tourSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in m.tourSuggestions) _tourChip(id, accent),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _mdStyle(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    final accent = theme.colorScheme.primary;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(color: onSurface, height: 1.4, fontSize: 14),
      pPadding: EdgeInsets.zero,
      strong: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
      em: TextStyle(color: onSurface, fontStyle: FontStyle.italic),
      listBullet: TextStyle(color: onSurface, fontSize: 14, height: 1.4),
      h1: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w800),
      h2: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w800),
      h3: TextStyle(color: onSurface, fontSize: 15, fontWeight: FontWeight.w800),
      a: TextStyle(color: accent, decoration: TextDecoration.underline),
      code: TextStyle(
        color: onSurface,
        backgroundColor: theme.colorScheme.surface,
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      blockSpacing: 8,
      listIndent: 18,
    );
  }

  Widget _tourChip(String id, Color accent) {
    final tour = ref.read(assistantProvider.notifier).tourById(id);
    if (tour == null) return const SizedBox.shrink();
    return ActionChip(
      avatar: Icon(Icons.play_circle_fill, size: 18, color: accent),
      label: Text(tour.title),
      visualDensity: VisualDensity.compact,
      onPressed: () => ref.read(assistantProvider.notifier).startTour(id),
    );
  }

  Widget _starters(Color accent) {
    final qs = ref.read(assistantProvider.notifier).starterQuestions;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final q in qs)
            ActionChip(
              label: Text(q, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(assistantProvider.notifier).ask(q),
            ),
        ],
      ),
    );
  }

  Widget _tourSuggestions(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOURS GUIADOS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.grey[500])),
          const SizedBox(height: 8),
          for (final t in kHelpTours)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(t.icon, color: accent),
                title: Text(t.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    ref.read(assistantProvider.notifier).startTour(t.id),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Spotlight
class _Spotlight extends ConsumerWidget {
  const _Spotlight({required this.rect, this.pulse = 0});
  final Rect? rect;
  final double pulse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assistantProvider);
    final step = s.currentStep;
    if (step == null) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.sizeOf(context);
    final total = s.activeTour!.steps.length;
    final notifier = ref.read(assistantProvider.notifier);

    // Posição do balão.
    const bubbleW = 320.0;
    const bubbleH = 210.0;
    double top, left;
    if (rect != null) {
      final below = rect!.bottom + 14;
      final fitsBelow = below + bubbleH < size.height;
      top = fitsBelow
          ? below
          : (rect!.top - bubbleH - 14).clamp(16.0, size.height - bubbleH - 16);
      left = (rect!.center.dx - bubbleW / 2)
          .clamp(12.0, size.width - bubbleW - 12);
    } else {
      top = (size.height - bubbleH) / 2;
      left = (size.width - bubbleW) / 2;
    }

    return Stack(
      children: [
        // Camada escura com recorte (absorve toques no fundo).
        Positioned.fill(
          child: GestureDetector(
            onTap: () {},
            child: CustomPaint(
              painter: _SpotlightPainter(hole: rect, accent: accent, pulse: pulse),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Balão de instrução.
        Positioned(
          top: top,
          left: left,
          width: bubbleW,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Passo ${s.stepIndex + 1} de $total',
                            style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: notifier.endTour,
                        child: Icon(Icons.close,
                            size: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(step.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(step.body,
                      style: TextStyle(color: Colors.grey[700], height: 1.35)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: notifier.endTour,
                        child: const Text('Sair'),
                      ),
                      const Spacer(),
                      if (s.stepIndex > 0)
                        TextButton(
                          onPressed: notifier.prevStep,
                          child: const Text('Voltar'),
                        ),
                      const SizedBox(width: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white),
                        onPressed: notifier.nextStep,
                        child: Text(s.stepIndex == total - 1
                            ? 'Concluir'
                            : 'Avançar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.accent, this.pulse = 0});
  final Rect? hole;
  final Color accent;
  final double pulse; // 0..1 (animação de respiração)

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.62);
    if (hole == null) {
      canvas.drawRect(full, dim);
      return;
    }
    // Recorte com leve "respiração" para chamar atenção.
    final inflate = 8.0 + pulse * 4.0;
    final rr =
        RRect.fromRectAndRadius(hole!.inflate(inflate), const Radius.circular(16));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(rr),
    );
    canvas.drawPath(path, dim);

    // Brilho externo pulsante.
    canvas.drawRRect(
      rr.inflate(4 + pulse * 6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.18 + 0.22 * (1 - pulse)),
    );
    // Borda principal.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.accent != accent || old.pulse != pulse;
}
