import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../theme/app_colors.dart';

/// Gráfico de rosca (donut) com percentual central. Usado em taxas (H-04, AB-01).
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.percent,
    this.color = AppColors.primary,
    this.size = 160,
    this.centerLabel,
  });

  final double percent; // 0..100
  final Color color;
  final double size;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Normaliza para [0..100] no desenho: valores fora da faixa (ex.: ocupação
    // acima de 100% no overbooking) não podem virar seção negativa/inválida.
    final filled = percent.clamp(0, 100).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: size * 0.34,
              sections: [
                PieChartSectionData(
                  value: filled,
                  color: color,
                  radius: size * 0.13,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: 100 - filled,
                  color: AppColors.surfaceAlt,
                  radius: size * 0.13,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: theme.textTheme.headlineMedium?.copyWith(color: color),
              ),
              if (centerLabel != null)
                Text(centerLabel!, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gráfico de barras verticais. Usado em "por unidade", "por especialidade".
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.data,
    this.height = 200,
    this.colorFor,
    this.suffix = '%',
  });

  final List<TimeSeriesPoint> data;
  final double height;
  final Color Function(int index)? colorFor;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = data.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    // Evita `maxY == 0` (dados vazios/zerados), que quebra a escala do gráfico.
    final topY = maxY <= 0 ? 1.0 : (maxY * 1.25).ceilToDouble();
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topY,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(0)}$suffix',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(data[i].label, style: theme.textTheme.bodySmall),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].value,
                    width: 26,
                    color: colorFor?.call(i) ??
                        AppColors.chartPalette[i % AppColors.chartPalette.length],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de linha para tendências (H-04, AB-01 linha).
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.data,
    this.color = AppColors.primary,
    this.height = 200,
  });

  final List<TimeSeriesPoint> data;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.dividerColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(data[i].label, style: theme.textTheme.bodySmall),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].value),
              ],
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de pizza com legenda. Usado em distribuição de cancelamentos (AB-02).
class LegendPieChart extends StatelessWidget {
  const LegendPieChart({super.key, required this.data, this.size = 170});

  final List<TimeSeriesPoint> data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.fold<double>(0, (s, p) => s + p.value);
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size * 0.28,
              sections: [
                for (var i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].value,
                    color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                    radius: size * 0.2,
                    // Guarda contra divisão por zero (total vazio/zerado → NaN%).
                    title: total > 0
                        ? '${(data[i].value / total * 100).toStringAsFixed(0)}%'
                        : '0%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < data.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors
                              .chartPalette[i % AppColors.chartPalette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(data[i].label, style: theme.textTheme.bodyMedium),
                      ),
                      Text(
                        '${data[i].value.toStringAsFixed(0)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
