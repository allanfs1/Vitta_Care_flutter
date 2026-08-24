import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class DensityHeatmap extends StatelessWidget {
  const DensityHeatmap({
    super.key,
    required this.data,
    this.baseColor = AppColors.primary,
    this.onCellTapped,
  });

  /// Lista de listas representando a densidade. 
  /// Ex: [Seg, Ter, Qua, Qui, Sex] onde cada dia tem valores para cada hora.
  final List<List<double>> data;
  final Color baseColor;
  final void Function(int dayIndex, int hourIndex)? onCellTapped;

  static const List<String> _days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = List.generate(data.first.length, (i) => '${8 + i}h');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho das horas
        Row(
          children: [
            const SizedBox(width: 36), // Espaço para os labels dos dias
            ...hours.map((hour) => Expanded(
              child: Text(
                hour,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            )),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // Grid do heatmap
        ...List.generate(data.length, (rowIndex) {
          final row = data[rowIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                // Label do dia
                SizedBox(
                  width: 36,
                  child: Text(
                    _days[rowIndex % _days.length],
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                // Blocos de intensidade
                ...List.generate(row.length, (colIndex) {
                  final value = row[colIndex];
                  return Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => onCellTapped?.call(rowIndex, colIndex),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              theme.brightness == Brightness.dark 
                                  ? AppColors.surfaceAltDark 
                                  : AppColors.surfaceAlt,
                              baseColor,
                              value,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Tooltip(
                            message: 'Densidade: ${(value * 100).toStringAsFixed(0)}%',
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
