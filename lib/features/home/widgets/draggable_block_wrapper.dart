import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Envolve um bloco da Home com um drag handle visual e feedback de arraste.
///
/// O handle aparece ao fazer hover (desktop/web) ou permanece sempre visível
/// no topo-direito do bloco.
class DraggableBlockWrapper extends StatefulWidget {
  const DraggableBlockWrapper({
    super.key,
    required this.label,
    required this.child,
    required this.isEditing,
  });

  /// Rótulo exibido junto ao handle (ex: "Indicadores").
  final String label;

  /// O widget real do bloco.
  final Widget child;

  /// Se está no modo de edição (drag habilitado).
  final bool isEditing;

  @override
  State<DraggableBlockWrapper> createState() => _DraggableBlockWrapperState();
}

class _DraggableBlockWrapperState extends State<DraggableBlockWrapper> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) return widget.child;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final handleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final borderColor = isDark
        ? AppColors.primary.withValues(alpha: 0.4)
        : AppColors.primary.withValues(alpha: 0.25);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 4),
          border: Border.all(
            color: _hovering ? AppColors.primary.withValues(alpha: 0.5) : borderColor,
            width: _hovering ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle bar ───────────────────────────────────
            ReorderableDragStartListener(
              index: 0, // será substituído pelo index real do builder
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.surfaceDark : AppColors.surfaceAlt)
                      .withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg + 2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator, size: 20, color: handleColor),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: handleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.open_with, size: 16, color: handleColor.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),

            // ── Conteúdo real ────────────────────────────────
            widget.child,
          ],
        ),
      ),
    );
  }
}
