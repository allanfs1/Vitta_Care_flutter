import 'package:flutter/material.dart';

import '../../../core/i18n/textos.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

/// 4 cards coloridos: Elite (Diamante), Assíduos (Ouro), Atenção (Prata), Risco (Bronze).
class HealthScoreKpiCards extends StatelessWidget {
  const HealthScoreKpiCards({
    super.key,
    required this.elite,
    required this.assiduos,
    required this.atencao,
    required this.risco,
  });

  final int elite;
  final int assiduos;
  final int atencao;
  final int risco;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            title: context.txt.t('health.eliteDiamante'),
            value: elite,
            icon: Icons.auto_awesome,
            iconColor: const Color(0xFF4F46E5),
            iconBg: const Color(0xFFEEF2FF),
            watermarkColor: const Color(0xFFEEF2FF).withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _KpiTile(
            title: context.txt.t('health.assiduosOuro'),
            value: assiduos,
            icon: Icons.emoji_events,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFEF3C7),
            watermarkColor: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _KpiTile(
            title: context.txt.t('health.atencaoPrata'),
            value: atencao,
            icon: Icons.verified_user_outlined,
            iconColor: const Color(0xFF6B7280),
            iconBg: const Color(0xFFF3F4F6),
            watermarkColor: const Color(0xFFF3F4F6).withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _KpiTile(
            title: context.txt.t('health.riscoBronze'),
            value: risco,
            icon: Icons.error_outline,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEE2E2),
            watermarkColor: const Color(0xFFFEE2E2).withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.watermarkColor,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color watermarkColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Stack(
        children: [
          // Watermark icon no canto direito
          Positioned(
            right: -8,
            bottom: -12,
            child: Icon(
              icon,
              size: 80,
              color: isDark
                  ? iconColor.withValues(alpha: 0.08)
                  : watermarkColor,
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: AppSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
