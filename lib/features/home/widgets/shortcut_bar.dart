import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../navigation/app_router.dart';

/// H-06 — barra de atalhos superiores para ações rápidas.
class ShortcutBar extends StatelessWidget {
  const ShortcutBar({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_Shortcut>[
      _Shortcut('Chat IA', Icons.auto_awesome, AppColors.pinkAccent.withValues(alpha: 0.15),
          AppColors.pinkAccent, () => context.go(AppRoutes.ia)),
      _Shortcut('Nova\nConsulta', Icons.add_circle_outline, AppColors.primaryLight,
          AppColors.primary, () => context.go(AppRoutes.agendamentos)),
      _Shortcut('Confirmar\nTodos', Icons.fact_check_outlined,
          AppColors.secondaryLight, AppColors.secondary,
          () => context.go(AppRoutes.agendamentos)),
      _Shortcut('Lista de\nEspera', Icons.groups_outlined, AppColors.warningLight,
          AppColors.warning, () => context.go(AppRoutes.agendamentos)),
      _Shortcut('Relatórios', Icons.bar_chart, AppColors.surfaceAlt,
          AppColors.textSecondary, () => context.go(AppRoutes.absenteismo)),
      _Shortcut('Equipe\nMédica', Icons.badge_outlined, AppColors.secondaryLight,
          AppColors.secondary, () => context.go(AppRoutes.equipeMedica)),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: _ShortcutTile(item: items[i])),
        ],
      ],
    );
  }
}

class _Shortcut {
  _Shortcut(this.label, this.icon, this.bg, this.fg, this.onTap);
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item});
  final _Shortcut item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      onTap: item.onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: item.bg, shape: BoxShape.circle),
            child: Icon(item.icon, color: item.fg),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
