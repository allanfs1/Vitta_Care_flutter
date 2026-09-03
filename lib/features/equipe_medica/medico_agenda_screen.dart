import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/appointment.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../overbooking/occupancy.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/status_badge.dart';
import '../agenda_publica/widgets/compartilhar_agenda_dialog.dart';
import '../totem/models/totem_config.dart';
import '../totem/providers/totem_config_provider.dart';

/// Agenda do médico em **tempo real** (PM-09), pública (acessível sem login via
/// QR Code). Reproduz a lógica de slots do Totem: para cada horário do dia conta
/// os agendamentos ativos e calcula a capacidade do médico (`capacityAt`,
/// overbooking §1). Atualiza sozinha via `doctorAgendaProvider`
/// (`tb_agendamentos` por `idMedico`, snapshots do Firestore).
class MedicoAgendaScreen extends ConsumerStatefulWidget {
  const MedicoAgendaScreen({
    super.key,
    required this.doctorId,
    this.doctorName,
  });

  final String doctorId;
  final String? doctorName;

  @override
  ConsumerState<MedicoAgendaScreen> createState() => _MedicoAgendaScreenState();
}

class _MedicoAgendaScreenState extends ConsumerState<MedicoAgendaScreen> {
  // Janela de atendimento exibida (mesma faixa comercial do totem).
  static const _startHour = 7;
  static const _endHour = 18;

  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _shiftDay(int days) =>
      setState(() => _date = _date.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doctorAsync = ref.watch(doctorByIdProvider(widget.doctorId));
    final apptsAsync = ref.watch(doctorAgendaProvider(widget.doctorId));

    final doctor = doctorAsync.valueOrNull;
    final title = doctor?.name ?? widget.doctorName ?? 'Agenda do médico';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Agenda em tempo real',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        actions: [
          if (doctor != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartilhar página da agenda',
              onPressed: () {
                final tc = ref
                        .read(publicTotemConfigProvider(doctor.clinicId))
                        .valueOrNull ??
                    const TotemConfig();
                CompartilharAgendaDialog.show(
                  context,
                  doctor: doctor,
                  config: tc,
                );
              },
            ),
        ],
      ),
      body: apptsAsync.when(
        loading: () => const LoadingView(message: 'Carregando agenda…'),
        error: (err, stack) =>
            const ErrorView(message: 'Não foi possível carregar a agenda.'),
        data: (appointments) => _buildBody(context, doctor, appointments),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, Doctor? doctor, List<Appointment> appointments) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = _sameDay(_date, now);
    final wd = _date.weekday;

    // Consultas do médico no dia selecionado, agrupadas por hora.
    final dayAppts = appointments.where((a) => _sameDay(a.start, _date)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final byHour = <int, List<Appointment>>{};
    for (final a in dayAppts) {
      byHour.putIfAbsent(a.start.hour, () => []).add(a);
    }

    final confirmadas =
        dayAppts.where((a) => a.status == AppointmentStatus.confirmed).length;

    // Janela de horas exibida: faixa comercial (7–18h) expandida para cobrir
    // consultas fora dela (madrugada/plantão) — ver OVERBOOKING.md §B4.
    var startHour = _startHour;
    var endHour = _endHour;
    for (final a in dayAppts) {
      if (a.start.hour < startHour) startHour = a.start.hour;
      if (a.start.hour > endHour) endHour = a.start.hour;
    }
    // Enquanto o médico (e sua config de capacidade) não carrega, a capacidade
    // é "desconhecida" e não deve ser exibida como lotada (ver §B5).
    final capacityKnown = doctor != null;

    return Column(
      children: [
        // Cabeçalho: avatar + navegação de dia + resumo.
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  AppAvatar(
                    initials: doctor?.initials ?? '?',
                    imageUrl: doctor?.photoUrl,
                    imageBytes: doctor?.photoBytes,
                    radius: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      doctor == null
                          ? ''
                          : 'CRM ${doctor.crm} • ${doctor.primarySpecialty}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  _Pill(
                    label: '${dayAppts.length} consultas',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Pill(
                    label: '$confirmadas confirm.',
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => _shiftDay(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            isToday ? 'Hoje' : Fmt.weekdayShort(_date),
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          Text(Fmt.fullDate(_date),
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _shiftDay(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: endHour - startHour + 1,
            itemBuilder: (context, i) {
              final hour = startHour + i;
              final slotAppts = [...?byHour[hour]]
                ..sort((a, b) => a.start.compareTo(b.start));
              final booked = slotAppts
                  .where((a) => a.status != AppointmentStatus.cancelled)
                  .length;
              final hhmm = '${hour.toString().padLeft(2, '0')}:00';
              final capacity =
                  doctor?.capacityAt(wd, hhmm) ?? (booked < 1 ? 1 : booked);
              final isNow = isToday && now.hour == hour;
              return _HourSlot(
                hour: hour,
                appointments: slotAppts,
                booked: booked,
                capacity: capacity,
                capacityKnown: capacityKnown,
                isNow: isNow,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Um horário (hora cheia) da timeline com ocupação/capacidade e as consultas.
class _HourSlot extends StatelessWidget {
  const _HourSlot({
    required this.hour,
    required this.appointments,
    required this.booked,
    required this.capacity,
    required this.capacityKnown,
    required this.isNow,
  });

  final int hour;
  final List<Appointment> appointments;
  final int booked;
  final int capacity;
  final bool capacityKnown;
  final bool isNow;

  // Nível/cor unificados em [OccupancyLevel] (ver OVERBOOKING.md §M2/§B6).
  Color get _capColor => capacityKnown
      ? OccupancyLevel.from(booked: booked, capacity: capacity).color
      : AppColors.textTertiary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hhmm = '${hour.toString().padLeft(2, '0')}:00';
    final free = booked < capacity;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna de horário + linha vertical (marcador "agora").
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(hhmm,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isNow ? AppColors.primary : null,
                    )),
                if (isNow)
                  Text('agora',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.primary)),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: isNow ? AppColors.primary : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                color: isNow ? AppColors.primaryLight : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_seat_outlined,
                            size: 16, color: _capColor),
                        const SizedBox(width: 6),
                        Text(capacityKnown ? '$booked/$capacity' : '$booked/—',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: _capColor)),
                        const SizedBox(width: 6),
                        Text(
                          !capacityKnown
                              ? 'Capacidade…'
                              : (free
                                  ? '${capacity - booked} vaga(s)'
                                  : 'Lotado'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (appointments.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Livre',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textTertiary)),
                    ] else
                      for (final a in appointments) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Text(Fmt.time(a.start),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.patientName,
                                      style: theme.textTheme.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                    '${a.specialty} • ${a.tipoConsulta}',
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            StatusBadge.appointment(a.status),
                          ],
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
