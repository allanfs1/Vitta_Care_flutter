import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class DoctorPerformanceRadarChart extends StatelessWidget {
  const DoctorPerformanceRadarChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Dark
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1D29),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.pinkAccent,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AUDITORIA DE DESEMPENHO MÉDICO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'COMPARATIVO ESTRATÉGICO ENTRE OS PROFISSIONAIS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.pinkAccent,
                  ),
                ),
              ],
            ),
          ),
          
          // Radar Chart
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: SizedBox(
              height: 350,
              child: RadarChart(
                RadarChartData(
                  radarTouchData: RadarTouchData(enabled: false),
                  dataSets: [
                    // Dr. FFbc (Rosa)
                    RadarDataSet(
                      fillColor: AppColors.pinkAccent.withValues(alpha: 0.4),
                      borderColor: AppColors.pinkAccent,
                      entryRadius: 0,
                      dataEntries: const [
                        RadarEntry(value: 90), // Consultas
                        RadarEntry(value: 20), // Avaliação
                        RadarEntry(value: 10), // Retorno
                        RadarEntry(value: 10), // Pontualidade
                        RadarEntry(value: 15), // Novos Pacientes
                      ],
                      borderWidth: 1.5,
                    ),
                    // Dr. perX (Azul claro)
                    RadarDataSet(
                      fillColor: Colors.lightBlue.withValues(alpha: 0.4),
                      borderColor: Colors.lightBlue,
                      entryRadius: 0,
                      dataEntries: const [
                        RadarEntry(value: 88), // Consultas
                        RadarEntry(value: 25), // Avaliação
                        RadarEntry(value: 20), // Retorno
                        RadarEntry(value: 18), // Pontualidade
                        RadarEntry(value: 25), // Novos Pacientes
                      ],
                      borderWidth: 1.5,
                    ),
                  ],
                  radarBackgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  radarBorderData: const BorderSide(color: Colors.transparent),
                  titlePositionPercentageOffset: 0.2,
                  titleTextStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  getTitle: (index, angle) {
                    switch (index) {
                      case 0:
                        return const RadarChartTitle(text: 'Consultas');
                      case 1:
                        return const RadarChartTitle(text: 'Avaliação');
                      case 2:
                        return const RadarChartTitle(text: 'Retorno (%)');
                      case 3:
                        return const RadarChartTitle(text: 'Pontualidade (%)');
                      case 4:
                        return const RadarChartTitle(text: 'Novos Pacientes');
                      default:
                        return const RadarChartTitle(text: '');
                    }
                  },
                  tickCount: 4,
                  ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
                  tickBorderData: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  gridBorderData: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          
          // Legenda
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: AppColors.pinkAccent, label: 'Dr. FFbc'),
                const SizedBox(width: AppSpacing.xxl),
                const _LegendItem(color: Colors.lightBlue, label: 'Dr. perX'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
