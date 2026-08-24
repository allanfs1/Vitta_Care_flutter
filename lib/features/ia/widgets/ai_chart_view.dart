import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Especificação de um gráfico vindo de um bloco ```json-chart``` na resposta da IA.
class ChartSpec {
  ChartSpec({required this.type, required this.title, required this.points});

  final String type; // bar | line | pie
  final String title;
  final List<ChartPoint> points;

  static ChartSpec? tryParse(String jsonStr) {
    try {
      final m = jsonDecode(jsonStr);
      if (m is! Map) return null;
      final data = (m['data'] as List?) ?? const [];
      final points = <ChartPoint>[];
      for (final e in data) {
        if (e is Map) {
          final label = (e['label'] ?? e['name'] ?? '').toString();
          final value = e['value'] ?? e['y'] ?? e['count'];
          final v = value is num
              ? value.toDouble()
              : double.tryParse(value?.toString() ?? '');
          if (v != null) points.add(ChartPoint(label, v));
        }
      }
      if (points.isEmpty) return null;
      return ChartSpec(
        type: (m['type'] ?? 'bar').toString(),
        title: (m['title'] ?? '').toString(),
        points: points,
      );
    } catch (_) {
      return null;
    }
  }
}

class ChartPoint {
  ChartPoint(this.label, this.value);
  final String label;
  final double value;
}

/// Renderiza um [ChartSpec] usando fl_chart (bar/line/pie) no tema escuro da IA.
class AiChartView extends StatelessWidget {
  const AiChartView({super.key, required this.spec});

  final ChartSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spec.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                spec.title,
                style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          SizedBox(height: 200, child: _chart(context)),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context) {
    switch (spec.type) {
      case 'pie':
        return _pie(context);
      case 'line':
        return _line(context);
      default:
        return _bar(context);
    }
  }

  Color _color(int i) =>
      AppColors.chartPalette[i % AppColors.chartPalette.length];

  Widget _bar(BuildContext context) {
    final maxY = spec.points.map((p) => p.value).fold<double>(0, (a, b) => b > a ? b : a);
    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= spec.points.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    spec.points[i].label,
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context), fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < spec.points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: spec.points[i].value,
                color: _color(i),
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _line(BuildContext context) {
    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= spec.points.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    spec.points[i].label,
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context), fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < spec.points.length; i++)
                FlSpot(i.toDouble(), spec.points[i].value),
            ],
            isCurved: true,
            color: AppColors.pinkAccent,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.pinkAccent.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pie(BuildContext context) {
    final total = spec.points.fold<double>(0, (a, b) => a + b.value);
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < spec.points.length; i++)
                  PieChartSectionData(
                    value: spec.points[i].value,
                    color: _color(i),
                    title: total == 0
                        ? ''
                        : '${(spec.points[i].value / total * 100).round()}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < spec.points.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, color: _color(i)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          spec.points[i].label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context), fontSize: 11),
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
