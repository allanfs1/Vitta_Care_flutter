import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// Card de KPI (H-05 / AB-05): rótulo, valor grande e variação opcional.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.kpi, this.icon});

  final Kpi kpi;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDelta = kpi.delta != null;
    final deltaColor = kpi.deltaPositive ? AppColors.success : AppColors.danger;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  kpi.label,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              text: kpi.value,
              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 26),
              children: [
                TextSpan(
                  text: kpi.suffix,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          if (hasDelta) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  kpi.deltaPositive ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: deltaColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${kpi.delta! >= 0 ? '+' : ''}${kpi.delta!.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
