import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/models/appointment.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import 'occupancy.dart';
import 'overbooking_engine.dart';
import 'overbooking_models.dart';
import 'overbooking_providers.dart';

/// Card de KPI compacto (OVB-02). Tappable quando `onTap` é informado.
class OvbKpiTile extends StatelessWidget {
  const OvbKpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: color)),
                Text(hint ?? label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge do estado operacional do paciente (OVB-04).
class EstadoBadge extends StatelessWidget {
  const EstadoBadge(this.estado, {super.key});
  final PacienteEstado estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(estado.label.toUpperCase(),
          style: TextStyle(
              color: estado.color, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }
}

/// Chip do nível de ocupação (LIVRE/MÉDIA/ÚLTIMAS/LOTADO).
class OccupancyLevelChip extends StatelessWidget {
  const OccupancyLevelChip(this.level, {super.key});
  final OccupancyLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(level.label,
          style: TextStyle(
              color: level.color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}

/// Gráfico de linha: Agendados × Capacidade por hora, com a hora atual marcada
/// e área de estouro destacada (OVB-03a).
class OccupancyLineChart extends StatelessWidget {
  const OccupancyLineChart({
    super.key,
    required this.hours,
    required this.booked,
    required this.capacity,
  });

  final List<int> hours;
  final Map<int, int> booked;
  final Map<int, int> capacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (hours.isEmpty) return const SizedBox.shrink();

    var maxY = 4.0;
    for (final h in hours) {
      final b = (booked[h] ?? 0).toDouble();
      final c = (capacity[h] ?? 0).toDouble();
      if (b > maxY) maxY = b;
      if (c > maxY) maxY = c;
    }
    maxY = (maxY + 1).ceilToDouble();

    List<FlSpot> spots(Map<int, int> m) =>
        [for (var i = 0; i < hours.length; i++) FlSpot(i.toDouble(), (m[hours[i]] ?? 0).toDouble())];

    final nowHour = DateTime.now().hour;
    final nowIndex = hours.indexOf(nowHour);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('OCUPAÇÃO × HORA',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const Spacer(),
              _legendDot(AppColors.primary, 'Agendados'),
              const SizedBox(width: AppSpacing.sm),
              _legendDot(AppColors.textTertiary, 'Capacidade'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (hours.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                      strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true, interval: 1, reservedSize: 26),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= hours.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${hours[i]}h',
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: nowIndex >= 0
                    ? ExtraLinesData(verticalLines: [
                        VerticalLine(
                          x: nowIndex.toDouble(),
                          color: AppColors.danger.withValues(alpha: 0.6),
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                        ),
                      ])
                    : const ExtraLinesData(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots(capacity),
                    isCurved: false,
                    color: AppColors.textTertiary,
                    barWidth: 2,
                    dashArray: [5, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: spots(booked),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}

/// Gráfico de pizza da distribuição de estados dos pacientes do dia (OVB-03e).
class EstadosPieChart extends StatelessWidget {
  const EstadosPieChart({super.key, required this.counts});
  final Map<PacienteEstado, int> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList();
    final total = entries.fold(0, (s, e) => s + e.value);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DISTRIBUIÇÃO DE ESTADOS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: AppSpacing.lg),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('Sem pacientes no dia.')),
            )
          else
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: e.key.color,
                        title: '${e.value}',
                        radius: 46,
                        titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 6,
            children: [
              for (final e in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: e.key.color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${e.key.label} (${e.value})',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de um médico: cabeçalho + grade de horas com ocupação/overbooking.
class DoctorOverbookCard extends ConsumerWidget {
  const DoctorOverbookCard({
    super.key,
    required this.doctor,
    required this.hours,
    required this.bookedByHour,
    required this.weekday,
    required this.onEdit,
  });

  final Doctor doctor;
  final List<int> hours;
  final Map<int, int> bookedByHour;
  final int weekday;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    var booked = 0;
    var capacity = 0;
    for (final h in hours) {
      booked += bookedByHour[h] ?? 0;
      capacity +=
          doctor.capacityAt(weekday, '${h.toString().padLeft(2, '0')}:00');
    }
    final level = OccupancyLevel.from(booked: booked, capacity: capacity);

    // Agendamentos do dia filtrados para este médico.
    final date = ref.watch(overbookingDateProvider);
    final allAppts = ref.watch(appointmentsProvider);
    final doctorDayAppts = allAppts
        .where((a) =>
            a.doctorId == doctor.id &&
            a.status != AppointmentStatus.cancelled &&
            a.start.year == date.year &&
            a.start.month == date.month &&
            a.start.day == date.day)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  initials: doctor.initials,
                  imageUrl: doctor.photoUrl,
                  imageBytes: doctor.photoBytes,
                  radius: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${doctor.primarySpecialty} • $booked/$capacity no dia',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                OccupancyLevelChip(level),
                IconButton(
                  tooltip: 'Configurar overbooking',
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in hours)
                  _HourCell(
                    hour: h,
                    booked: bookedByHour[h] ?? 0,
                    capacity: doctor.capacityAt(
                        weekday, '${h.toString().padLeft(2, '0')}:00'),
                    onTap: () => _showSlotDetail(
                      context,
                      doctor: doctor,
                      hour: h,
                      appointments: doctorDayAppts
                          .where((a) => a.start.hour == h)
                          .toList(),
                      capacity: doctor.capacityAt(
                          weekday, '${h.toString().padLeft(2, '0')}:00'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSlotDetail(
    BuildContext context, {
    required Doctor doctor,
    required int hour,
    required List<Appointment> appointments,
    required int capacity,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SlotDetailBottomSheet(
        doctor: doctor,
        hour: hour,
        appointments: appointments,
        capacity: capacity,
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell(
      {required this.hour,
      required this.booked,
      required this.capacity,
      this.onTap});

  final int hour;
  final int booked;
  final int capacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final level = OccupancyLevel.from(booked: booked, capacity: capacity);
    final color = level.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${hour.toString().padLeft(2, '0')}h',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('$booked/$capacity',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet que exibe todos os pacientes de um slot (médico × hora) com
/// informações detalhadas do agendamento e link para ver o agendamento completo.
class SlotDetailBottomSheet extends StatelessWidget {
  const SlotDetailBottomSheet({
    super.key,
    required this.doctor,
    required this.hour,
    required this.appointments,
    required this.capacity,
  });

  final Doctor doctor;
  final int hour;
  final List<Appointment> appointments;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final level =
        OccupancyLevel.from(booked: appointments.length, capacity: capacity);
    final hourStr = '${hour.toString().padLeft(2, '0')}:00';

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Handle ──
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: level.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.access_time_filled,
                          color: level.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$hourStr — ${doctor.name}',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${appointments.length}/$capacity pacientes • ${level.label}',
                            style: TextStyle(
                              fontSize: 12,
                              color: level.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OccupancyLevelChip(level),
                  ],
                ),
              ),

              Divider(
                color: isDark ? AppColors.borderDark : AppColors.border,
                height: 1,
              ),

              // ── Lista de pacientes ──
              Expanded(
                child: appointments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available,
                                size: 48,
                                color: AppColors.textTertiary
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum paciente neste horário',
                              style: TextStyle(
                                color: AppColors.textTertiary
                                    .withValues(alpha: 0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: appointments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final appt = appointments[index];
                          return _SlotPatientTile(
                            appointment: appt,
                            onViewDetail: () {
                              Navigator.of(context).pop();
                              context.push('/agendamentos/${appt.id}');
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tile de paciente dentro do bottom sheet de slot.
class _SlotPatientTile extends StatelessWidget {
  const _SlotPatientTile({
    required this.appointment,
    required this.onViewDetail,
  });

  final Appointment appointment;
  final VoidCallback onViewDetail;

  String _timeRange(Appointment a) {
    final sh = a.start.hour.toString().padLeft(2, '0');
    final sm = a.start.minute.toString().padLeft(2, '0');
    final e = a.end;
    final eh = e.hour.toString().padLeft(2, '0');
    final em = e.minute.toString().padLeft(2, '0');
    return '$sh:$sm – $eh:$em';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a = appointment;
    final statusColor = a.status.color;

    return Material(
      color: isDark ? const Color(0xFF232740) : const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onViewDetail,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome + status
              Row(
                children: [
                  // Barra lateral de risco
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: a.patientRisk.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.patientName,
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.tipoConsulta,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a.status.icon,
                            size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          a.status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Info row: horário, modalidade, risco
              Row(
                children: [
                  _infoTag(Icons.schedule, _timeRange(a)),
                  const SizedBox(width: 8),
                  _infoTag(
                    a.modalidade == 'Presencial'
                        ? Icons.location_on_outlined
                        : Icons.videocam_outlined,
                    a.modalidade,
                  ),
                  const SizedBox(width: 8),
                  _riskTag(a.patientRisk),
                  if (a.firstVisit) ...[
                    const SizedBox(width: 8),
                    _infoTag(Icons.fiber_new, 'Primeira vez'),
                  ],
                ],
              ),

              if (a.motivo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notes,
                        size: 14,
                        color: AppColors.textTertiary
                            .withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.motivo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Link to detail
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onViewDetail,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Ver agendamento'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13,
            color: AppColors.textTertiary.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                fontSize: 11,
                color:
                    AppColors.textTertiary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _riskTag(RiskLevel risk) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: risk.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined,
              size: 12, color: risk.color),
          const SizedBox(width: 3),
          Text('Risco ${risk.label}',
              style: TextStyle(
                  fontSize: 10,
                  color: risk.color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Diálogo de edição da configuração de overbooking do médico (OVB / EM-07).
Future<void> showOverbookingConfigDialog(
    BuildContext context, WidgetRef ref, Doctor doctor) async {
  final slotCtrl = TextEditingController(text: '${doctor.slotLimit}');
  final overCtrl = TextEditingController(text: '${doctor.maxOverbook}');
  final capCtrl =
      TextEditingController(text: doctor.maxPerSlot?.toString() ?? '');

  Widget numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Overbooking — ${doctor.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          numField(slotCtrl, 'Limite base por horário (slotLimit)'),
          const SizedBox(height: AppSpacing.md),
          numField(overCtrl, 'Overbook máximo (maxOverbook)'),
          const SizedBox(height: AppSpacing.md),
          numField(capCtrl, 'Teto por horário (vazio = sem teto)'),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'A capacidade de cada horário é o limite base + overbook, limitada '
            'pelo teto quando definido.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar')),
      ],
    ),
  );

  if (saved == true) {
    final slot = int.tryParse(slotCtrl.text.trim());
    final over = int.tryParse(overCtrl.text.trim());
    final capText = capCtrl.text.trim();
    final cap = capText.isEmpty ? null : int.tryParse(capText);
    ref.read(clinicDoctorsProvider.notifier).update(
          doctor.copyWith(
            slotLimit: slot != null && slot >= 1 ? slot : doctor.slotLimit,
            maxOverbook: over != null && over >= 0 ? over : doctor.maxOverbook,
            maxPerSlot: capText.isEmpty ? null : cap,
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Overbooking de ${doctor.name} atualizado.'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }
  slotCtrl.dispose();
  overCtrl.dispose();
  capCtrl.dispose();
}

/// Conta os pacientes do dia por estado (para a pizza OVB-03e).
Map<PacienteEstado, int> contarEstados(
    OverbookingSnapshot snap, RealocacaoState realoc) {
  final realocavel = snap.realocavelIds;
  final counts = <PacienteEstado, int>{};
  for (final a in snap.dayAppointments) {
    final estado = OverbookingEngine.estadoDe(
      a,
      realocavel: realocavel.contains(a.id),
      proposta: realoc.propostas[a.id]?.status,
    );
    counts[estado] = (counts[estado] ?? 0) + 1;
  }
  return counts;
}
