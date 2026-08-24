import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// AB-04 — Mapa de calor (heatmap) de faltas por dia/horário.
class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({super.key, required this.data});

  /// Linhas = dias úteis (Seg..Sex), colunas = horas (8h..17h). Valores 0..1.
  final List<List<double>> data;

  static const _days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final cols = data.isEmpty ? 0 : data.first.length;
      const labelWidth = 36.0;
      final cell = ((constraints.maxWidth - labelWidth) / cols).clamp(14.0, 40.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = 0; r < data.length; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(_days[r % _days.length],
                        style: theme.textTheme.bodySmall),
                  ),
                  for (var c = 0; c < data[r].length; c++)
                    Container(
                      width: cell - 3,
                      height: cell - 3,
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                            AppColors.surfaceAlt, AppColors.danger, data[r][c]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const SizedBox(width: 36),
              Text('8h', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text('17h', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('Menor', style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              Container(
                width: 80,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [AppColors.surfaceAlt, AppColors.danger],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('Maior', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      );
    });
  }
}
