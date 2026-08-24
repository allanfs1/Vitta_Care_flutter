import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

class SatisfacaoKpiCards extends StatelessWidget {
  const SatisfacaoKpiCards({
    super.key,
    required this.mediaGeral,
    required this.nps,
    required this.totalFeedbacks,
    required this.criticos,
  });

  final double mediaGeral;
  final int nps;
  final int totalFeedbacks;
  final int criticos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final children = [
          _buildCard(
            context,
            title: 'MÉDIA GERAL',
            value: mediaGeral.toStringAsFixed(1),
            suffix: '/5.0',
            icon: Icons.trending_up,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary.withValues(alpha: 0.1),
          ),
          _buildCard(
            context,
            title: 'ÍNDICE NPS',
            value: nps.toString(),
            icon: Icons.sentiment_satisfied_alt,
            iconColor: Colors.orange,
            iconBgColor: Colors.orange.withValues(alpha: 0.1),
          ),
          _buildCard(
            context,
            title: 'TOTAL FEEDBACKS',
            value: totalFeedbacks.toString(),
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.withValues(alpha: 0.1),
          ),
          _buildCard(
            context,
            title: 'CRÍTICOS',
            value: criticos.toString(),
            valueColor: AppColors.danger,
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.danger,
            iconBgColor: AppColors.danger.withValues(alpha: 0.1),
          ),
        ];

        if (isMobile) {
          return Column(
            children: children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: c,
            )).toList(),
          );
        }

        return Row(
          children: children.map((c) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: c != children.last ? AppSpacing.md : 0,
              ),
              child: c,
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String value,
    String? suffix,
    Color? valueColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: valueColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                      ),
                    ),
                    if (suffix != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        suffix,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
