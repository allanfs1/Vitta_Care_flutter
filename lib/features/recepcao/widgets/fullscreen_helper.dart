import 'package:flutter/material.dart';

/// Abre [child] em um diálogo de tela cheia com AppBar e botão de fechar.
void showRecepcaoFullscreen(BuildContext context, String title, Widget child) {
  showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (ctx) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        body: child,
      ),
    ),
  );
}

/// Botão "Expandir" padronizado para as abas da recepção.
class ExpandTabBar extends StatelessWidget {
  const ExpandTabBar({super.key, required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: onExpand,
          icon: const Icon(Icons.open_in_full, size: 16),
          label: const Text('Expandir'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF3B30),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}
