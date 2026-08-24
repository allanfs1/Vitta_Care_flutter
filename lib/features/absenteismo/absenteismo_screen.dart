import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_router.dart';
import '../../core/models/appointment.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import '../../core/models/patient.dart';
import '../../core/services/app_providers.dart';
import '../../core/services/mock_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/ai_insight_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_badge.dart';
import '../ia/widgets/ai_report_card.dart';
import 'widgets/heatmap_grid.dart';

/// Agente 3 — Absenteísmo e Cancelamentos (`features/absenteismo`).
/// Cobre AB-01..AB-09.
class AbsenteismoScreen extends ConsumerWidget {
  const AbsenteismoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Cópia antes de ordenar: `patientsProvider` devolve a lista compartilhada
    // (`MockData.patients`); ordenar in-place mutaria a fonte global e a ordem
    // vista por outras telas. `[...]` isola a ordenação a esta build.
    final patients = [...ref.watch(patientsProvider)]
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
    final wide = !Responsive.isMobile(context);

    // AB-09 — índice de absenteísmo por médico (dados reais da clínica ativa:
    // faltas ÷ total de agendamentos do médico; cai para a média histórica
    // quando o médico ainda não tem agendamentos no período).
    final byDoctor = _absenteeismByDoctor(
        ref.watch(clinicDoctorsProvider), ref.watch(appointmentsProvider));
    final teamAvg = byDoctor.isEmpty
        ? 0.0
        : byDoctor.map((e) => e.index).reduce((a, b) => a + b) / byDoctor.length;
    final totalFaltas = ref
        .watch(appointmentsProvider)
        .where((a) => a.status == AppointmentStatus.noShow)
        .length;

    return Column(
      children: [
        const AppHeader(title: 'Visão Gerencial'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
            children: [
              Text('Monitore eficiência operacional e adesão dos pacientes.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),

              // Ações
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.relatorios),
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Ver relatórios'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarEmMassa(context, ref),
                      icon: const Icon(Icons.send),
                      label: const Text('Confirmar em massa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // AB-01 / AB-05 — KPIs
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: Responsive.gridColumns(context, max: 4),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.4,
                children: const [
                  KpiCard(
                    kpi: Kpi(label: 'Absenteísmo geral', value: '18', suffix: '%',
                        delta: 2.4, deltaPositive: false),
                    icon: Icons.person_off_outlined,
                  ),
                  KpiCard(
                    kpi: Kpi(label: 'Cancelamentos', value: '12', suffix: '%',
                        delta: -0.8),
                    icon: Icons.event_busy,
                  ),
                  KpiCard(
                    kpi: Kpi(label: 'Maior risco (médico)', value: '22', suffix: '%'),
                    icon: Icons.medical_information_outlined,
                  ),
                  KpiCard(
                    kpi: Kpi(label: 'Realocação', value: '72', suffix: '%', delta: 5.0),
                    icon: Icons.autorenew,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // AB-01 donut + AB-01 por unidade (barras)
              _responsiveRow(
                wide,
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Absenteísmo global',
                        subtitle: 'Últimos 30 dias',
                        trailing: AiInsightButton(
                          chartTitle: 'Absenteísmo global',
                          summary:
                              'A taxa global de absenteísmo está em 18% nos últimos 30 dias, 2,4 p.p. acima da meta de 15%.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Center(
                        child: DonutChart(percent: 18, color: AppColors.danger),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: Text('Meta < 15%  •  +2,4% vs meta',
                            style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Absenteísmo por unidade',
                        trailing: AiInsightButton(
                          chartTitle: 'Absenteísmo por unidade',
                          summary:
                              'UBS lidera com 21%, seguida de APS (15%) e UPA (12%).',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SimpleBarChart(
                        data: MockData.absenteeismByUnit(),
                        colorFor: (i) => [
                          AppColors.danger,
                          AppColors.primary,
                          AppColors.secondary
                        ][i % 3],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // AB-01 linha (tendência) + AB-02 pizza (cancelamentos)
              _responsiveRow(
                wide,
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Tendência de absenteísmo',
                        trailing: AiInsightButton(
                          chartTitle: 'Tendência de absenteísmo',
                          summary:
                              'A série de 6 meses recuou de 22% para 16%, tendência de queda consistente.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SimpleLineChart(
                          data: MockData.absenteeismTrend(), color: AppColors.danger),
                    ],
                  ),
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Motivos de cancelamento',
                        trailing: AiInsightButton(
                          chartTitle: 'Motivos de cancelamento',
                          summary:
                              'Paciente responde por 48% dos cancelamentos, seguido de Clínica (22%), Médico (18%) e Sistema (12%).',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LegendPieChart(data: MockData.cancellationBreakdown()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // AB-08/AB-09 — por especialidade/médico (barras)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Absenteísmo por especialidade',
                      subtitle: 'Segmentado por área médica',
                      trailing: AiInsightButton(
                        chartTitle: 'Absenteísmo por especialidade',
                        summary:
                            'Clínica Geral tem o maior índice (22%); Dermatologia o menor (11%).',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SimpleBarChart(data: MockData.absenteeismBySpecialty()),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // AB-09 — índice de absenteísmo por médico (KPIs + barras)
              if (byDoctor.isNotEmpty) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Absenteísmo por médico',
                        subtitle: 'Índice individual (faltas ÷ agendamentos)',
                        trailing: AiInsightButton(
                          chartTitle: 'Absenteísmo por médico',
                          summary:
                              '${byDoctor.first.label} tem o maior índice '
                              '(${byDoctor.first.index.toStringAsFixed(0)}%); '
                              '${byDoctor.last.label} o menor '
                              '(${byDoctor.last.index.toStringAsFixed(0)}%).',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // KPIs (AB-05) do índice por médico.
                      Row(
                        children: [
                          Expanded(
                            child: KpiCard(
                              icon: Icons.percent,
                              kpi: Kpi(
                                label: 'Índice médio da equipe',
                                value: teamAvg.toStringAsFixed(1),
                                suffix: '%',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: KpiCard(
                              icon: Icons.trending_up,
                              kpi: Kpi(
                                label: 'Maior — ${byDoctor.first.label}',
                                value: byDoctor.first.index.toStringAsFixed(0),
                                suffix: '%',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: KpiCard(
                              icon: Icons.trending_down,
                              kpi: Kpi(
                                label: 'Menor — ${byDoctor.last.label}',
                                value: byDoctor.last.index.toStringAsFixed(0),
                                suffix: '%',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: KpiCard(
                              icon: Icons.person_off_outlined,
                              kpi: Kpi(
                                label: 'Total de faltas (período)',
                                value: '$totalFaltas',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SimpleBarChart(
                        data: [
                          for (final e in byDoctor)
                            TimeSeriesPoint(e.label, e.index),
                        ],
                        colorFor: (i) => _sevColor(byDoctor[i].index),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // AB-04 — heatmap
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Densidade de faltas',
                      subtitle: 'Concentração por dia e horário',
                      trailing: AiInsightButton(
                        chartTitle: 'Densidade de faltas (heatmap)',
                        summary:
                            'A maior concentração de faltas ocorre às quartas e quintas no fim da tarde (índice ~0,9).',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    HeatmapGrid(data: MockData.heatmap()),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // AB-06 — risco de faltas (IA)
              const SectionHeader(
                  title: 'Faltas críticas',
                  subtitle: 'Pacientes com maior risco — requer contato'),
              const SizedBox(height: AppSpacing.md),
              for (final p in patients.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RiskPatientTile(patient: p),
                ),
              const SizedBox(height: AppSpacing.lg),

              // AB-07 — relatórios inteligentes (IA)
              const SectionHeader(
                  title: 'Relatório inteligente',
                  subtitle: 'Insights e recomendações por IA'),
              const SizedBox(height: AppSpacing.md),
              const AiReportCard(),
            ],
          ),
        ),
      ],
    );
  }

  /// AB-09 — calcula o índice de absenteísmo (%) por médico a partir dos
  /// agendamentos da clínica, ordenado do maior para o menor.
  List<_DoctorAbsence> _absenteeismByDoctor(
      List<Doctor> doctors, List<Appointment> appointments) {
    final list = <_DoctorAbsence>[];
    for (final d in doctors) {
      final mine = appointments.where((a) => a.doctorId == d.id).toList();
      final total = mine.length;
      final faltas =
          mine.where((a) => a.status == AppointmentStatus.noShow).length;
      final index = total > 0 ? faltas / total * 100 : d.absenceRate * 100;
      list.add(_DoctorAbsence(_shortDoctorLabel(d.name), index));
    }
    list.sort((a, b) => b.index.compareTo(a.index));
    return list;
  }

  /// Rótulo curto para o eixo do gráfico (sobrenome do profissional).
  String _shortDoctorLabel(String name) {
    final parts = name
        .replaceAll('Dr. ', '')
        .replaceAll('Dra. ', '')
        .trim()
        .split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.last;
  }

  /// Cor por severidade do índice: verde (ok), âmbar (atenção), vermelho (alto).
  Color _sevColor(double index) {
    if (index >= 20) return AppColors.danger;
    if (index >= 15) return AppColors.warning;
    return AppColors.success;
  }

  /// AB-03 — Confirmação em massa: confirma, de uma só vez, todos os
  /// agendamentos pré-agendados de hoje em diante. Cada confirmação persiste em
  /// `tb_agendamentos` via [AppointmentsNotifier.setStatus]. Pede confirmação
  /// antes, pois é uma ação em lote sobre a agenda real.
  Future<void> _confirmarEmMassa(BuildContext context, WidgetRef ref) async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final pendentes = ref
        .read(appointmentsProvider)
        .where((a) =>
            a.status == AppointmentStatus.pending && !a.start.isBefore(hoje))
        .toList();

    final messenger = ScaffoldMessenger.of(context);

    if (pendentes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nenhum agendamento pré-agendado para confirmar.'),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar em massa'),
        content: Text(
          'Confirmar ${pendentes.length} '
          'agendamento${pendentes.length == 1 ? '' : 's'} pré-agendado'
          '${pendentes.length == 1 ? '' : 's'} de hoje em diante?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final notifier = ref.read(appointmentsProvider.notifier);
    for (final a in pendentes) {
      notifier.setStatus(a.id, AppointmentStatus.confirmed);
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${pendentes.length} '
          'agendamento${pendentes.length == 1 ? '' : 's'} confirmado'
          '${pendentes.length == 1 ? '' : 's'}.',
        ),
      ),
    );
  }

  Widget _responsiveRow(bool wide, Widget a, Widget b) {
    if (!wide) {
      return Column(children: [a, const SizedBox(height: AppSpacing.lg), b]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: b),
        ],
      ),
    );
  }
}

/// Índice de absenteísmo (%) de um médico, para o gráfico/KPIs do AB-09.
class _DoctorAbsence {
  const _DoctorAbsence(this.label, this.index);
  final String label;
  final double index;
}

class _RiskPatientTile extends StatelessWidget {
  const _RiskPatientTile({required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(
              initials: patient.initials,
              radius: 20,
              color: patient.riskLevel.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name, style: theme.textTheme.titleMedium),
                Text(patient.phone ?? '', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge.risk(patient.riskLevel),
              const SizedBox(height: 4),
              Text('${patient.absencesYtd} faltas/ano',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          TextButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Contatando ${patient.name}…')),
            ),
            icon: const Icon(Icons.call, size: 16),
            label: const Text('Contato'),
          ),
        ],
      ),
    );
  }
}
