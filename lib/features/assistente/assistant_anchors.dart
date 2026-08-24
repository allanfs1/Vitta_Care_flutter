import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registro de âncoras de spotlight: `anchorId` -> `GlobalKey` do widget alvo.
/// Permite ao overlay do assistente localizar o retângulo de um elemento real
/// na tela para destacá-lo.
class AssistantAnchors {
  final Map<String, GlobalKey> _keys = {};

  void register(String id, GlobalKey key) => _keys[id] = key;

  void unregister(String id, GlobalKey key) {
    if (_keys[id] == key) _keys.remove(id);
  }

  /// Contexto do alvo (para `Scrollable.ensureVisible`), ou `null`.
  BuildContext? contextOf(String id) => _keys[id]?.currentContext;

  /// Retângulo global do alvo, ou `null` se ainda não está montado/visível.
  Rect? rectOf(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

final assistantAnchorsProvider =
    Provider<AssistantAnchors>((ref) => AssistantAnchors());

/// Envolve um widget para que o assistente possa destacá-lo (spotlight).
class AssistantTarget extends ConsumerStatefulWidget {
  const AssistantTarget({
    super.key,
    required this.anchorId,
    required this.child,
  });

  final String anchorId;
  final Widget child;

  @override
  ConsumerState<AssistantTarget> createState() => _AssistantTargetState();
}

class _AssistantTargetState extends ConsumerState<AssistantTarget> {
  final GlobalKey _key = GlobalKey();
  AssistantAnchors? _anchors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cacheia a instância aqui: usar `ref` no `dispose` lança
    // "Cannot use ref after the widget was disposed" no Riverpod atual.
    final anchors = ref.read(assistantAnchorsProvider);
    _anchors = anchors;
    anchors.register(widget.anchorId, _key);
  }

  @override
  void dispose() {
    _anchors?.unregister(widget.anchorId, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
