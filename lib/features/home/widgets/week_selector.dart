import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/enums.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../navigation/app_router.dart';
import '../../agendamentos/widgets/new_appointment_dialog.dart';

/// H-03 — "Esta semana": seletor dinâmico de 7 dias com navegação entre semanas,
/// filtros rápidos por status, cartões detalhados e estado vazio com CTA de agendamento.
class WeekSelector extends ConsumerStatefulWidget {
  const WeekSelector({super.key});

  @override
  ConsumerState<WeekSelector> createState() => _WeekSelectorState();
}

class _WeekSelectorState extends ConsumerState<WeekSelector> {
  late DateTime _selected;
  late DateTime _referenceMonday;
  AppointmentStatus? _statusFilter;
  bool _expanded = false;

  static const _previewCount = 4;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _referenceMonday = _selected.subtract(Duration(days: _selected.weekday - 1));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _goToPreviousWeek() {
    setState(() {
      _referenceMonday = _referenceMonday.subtract(const Duration(days: 7));
      _selected = _referenceMonday;
      _statusFilter = null;
      _expanded = false;
    });
  }

  void _goToNextWeek() {
    setState(() {
      _referenceMonday = _referenceMonday.add(const Duration(days: 7));
      _selected = _referenceMonday;
      _statusFilter = null;
      _expanded = false;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selected = today;
      _referenceMonday = today.subtract(Duration(days: today.weekday - 1));
      _statusFilter = null;
      _expanded = false;
    });
  }

  void _openNewAppointment(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => NewAppointmentDialog(initialDate: _selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentWeek = _sameDay(_referenceMonday, today.subtract(Duration(days: today.weekday - 1)));

    // 7 dias da semana (Segunda a Domingo)
    final days = List.generate(7, (i) => _referenceMonday.add(Duration(days: i)));
    final appointments = ref.watch(appointmentsProvider);

    List<Appointment> apptsOf(DateTime day) => appointments
        .where((a) => _sameDay(a.start, day))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // Consultas da semana inteira para estatísticas
    final weekAppts = appointments.where((a) {
      final d = DateTime(a.start.year, a.start.month, a.start.day);
      return !d.isBefore(days.first) && !d.isAfter(days.last);
    }).toList();

    // Consultas do dia selecionado
    final dayAppts = apptsOf(_selected);

    // Contagens por status para os filtros rápidos do dia
    final confirmedCount = dayAppts.where((a) => a.status == AppointmentStatus.confirmed).length;
    final pendingCount = dayAppts.where((a) => a.status == AppointmentStatus.pending).length;
    final cancelledCount = dayAppts.where((a) => a.status == AppointmentStatus.cancelled).length;

    // Aplicação do filtro de status no dia
    final filteredAppts = _statusFilter == null
        ? dayAppts
        : dayAppts.where((a) => a.status == _statusFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Barra de Navegação de Semanas & Controles ────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              // Mês e Intervalo de Datas
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          Fmt.monthYear(_referenceMonday),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isCurrentWeek)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Semana Atual',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.dayMonth(days.first)} até ${Fmt.dayMonth(days.last)} • ${weekAppts.length} consultas na semana',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Botão "Hoje"
              if (!isCurrentWeek || !_sameDay(_selected, today)) ...[
                OutlinedButton.icon(
                  onPressed: _goToToday,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.today_rounded, size: 14, color: AppColors.primary),
                  label: const Text('Hoje', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(width: 6),
              ],

              // Setas Anterior / Próxima
              Material(
                color: Colors.transparent,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Semana anterior',
                      onPressed: _goToPreviousWeek,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Próxima semana',
                      onPressed: _goToNextWeek,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // Atalho + Novo Agendamento
              FilledButton.icon(
                onPressed: () => _openNewAppointment(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Agendar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── 2. Faixa dos 7 Dias da Semana ──────────────────────────────────
        SizedBox(
          height: 102,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = days[i];
              final selected = _sameDay(day, _selected);
              final isToday = _sameDay(day, today);
              final list = apptsOf(day);
              final count = list.length;
              final hasConfirmed = list.any((a) => a.status == AppointmentStatus.confirmed);
              final hasPending = list.any((a) => a.status == AppointmentStatus.pending);
              final hasCancel = list.any((a) => a.status == AppointmentStatus.cancelled);

              return GestureDetector(
                onTap: () => setState(() {
                  _selected = day;
                  _statusFilter = null;
                  _expanded = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: selected ? null : AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : (isToday ? AppColors.primary : AppColors.borderOf(context)),
                      width: isToday && !selected ? 1.8 : 1.0,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dia da semana com badge 'HOJE'
                      Column(
                        children: [
                          if (isToday && !selected)
                            Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'HOJE',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 2),
                          Text(
                            Fmt.weekdayShort(day).toUpperCase(),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : (isToday ? AppColors.primary : AppColors.textSecondaryOf(context)),
                              fontWeight: isToday || selected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),

                      // Número do dia
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isToday ? AppColors.primary : AppColors.textPrimaryOf(context)),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.1,
                        ),
                      ),

                      // Indicador de Consultas
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.25)
                                : AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  color: selected ? Colors.white : AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white
                                      : (hasConfirmed
                                          ? AppColors.success
                                          : (hasPending
                                              ? AppColors.warning
                                              : (hasCancel ? AppColors.danger : AppColors.primary))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '—',
                            style: TextStyle(
                              color: selected ? Colors.white54 : AppColors.textTertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── 3. Cabeçalho do Dia & Chips de Filtro Rápido ───────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_note_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _sameDay(_selected, today)
                            ? 'Hoje, ${Fmt.dayMonth(_selected)}'
                            : '${Fmt.weekdayFull(_selected)}, ${Fmt.dayMonth(_selected)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (_sameDay(_selected, today)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Hoje',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    dayAppts.isEmpty
                        ? 'Nenhuma consulta programada'
                        : '${dayAppts.length} consulta${dayAppts.length > 1 ? 's' : ''} no total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Chips de Filtro por Status (visíveis quando há agendamentos)
            if (dayAppts.isNotEmpty) ...[
              _FilterPill(
                label: 'Todos',
                count: dayAppts.length,
                isSelected: _statusFilter == null,
                onTap: () => setState(() => _statusFilter = null),
              ),
              if (confirmedCount > 0) ...[
                const SizedBox(width: 4),
                _FilterPill(
                  label: 'Confirmados',
                  count: confirmedCount,
                  color: AppColors.success,
                  isSelected: _statusFilter == AppointmentStatus.confirmed,
                  onTap: () => setState(() => _statusFilter = _statusFilter == AppointmentStatus.confirmed ? null : AppointmentStatus.confirmed),
                ),
              ],
              if (pendingCount > 0) ...[
                const SizedBox(width: 4),
                _FilterPill(
                  label: 'Pendentes',
                  count: pendingCount,
                  color: AppColors.warning,
                  isSelected: _statusFilter == AppointmentStatus.pending,
                  onTap: () => setState(() => _statusFilter = _statusFilter == AppointmentStatus.pending ? null : AppointmentStatus.pending),
                ),
              ],
              if (cancelledCount > 0) ...[
                const SizedBox(width: 4),
                _FilterPill(
                  label: 'Cancelados',
                  count: cancelledCount,
                  color: AppColors.danger,
                  isSelected: _statusFilter == AppointmentStatus.cancelled,
                  onTap: () => setState(() => _statusFilter = _statusFilter == AppointmentStatus.cancelled ? null : AppointmentStatus.cancelled),
                ),
              ],
            ],
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── 4. Lista de Consultas ou Empty State Aprimorado ────────────────
        if (dayAppts.isEmpty)
          _EmptyDay(
            selectedDate: _selected,
            onNewAppointment: () => _openNewAppointment(context),
            onOpenFullAgenda: () => context.go(AppRoutes.agendamentos),
          )
        else if (filteredAppts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              children: [
                Icon(Icons.filter_list_off_rounded, size: 28, color: AppColors.textTertiary),
                const SizedBox(height: 6),
                Text(
                  'Nenhuma consulta com o status selecionado',
                  style: TextStyle(color: AppColors.textSecondaryOf(context), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _statusFilter = null),
                  child: const Text('Limpar filtros'),
                ),
              ],
            ),
          )
        else ...[
          for (final a in (_expanded ? filteredAppts : filteredAppts.take(_previewCount)))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AppointmentRow(
                appointment: a,
                onTap: () => context.go(AppRoutes.appointmentDetail(a.id)),
              ),
            ),

          if (filteredAppts.length > _previewCount)
            _SeeAllButton(
              expanded: _expanded,
              total: filteredAppts.length,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
        ],
      ],
    );
  }
}

/// Chip de filtro rápido por status.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderOf(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '$label ($count)',
              style: TextStyle(
                color: isSelected ? activeColor : AppColors.textSecondaryOf(context),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha/cartão de consulta aprimorado com avatar, horário detalhado e chips.
class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = appointment;
    final status = a.status;
    final end = a.start.add(Duration(minutes: a.durationMinutes));

    // Iniciais do paciente
    final patientParts = a.patientName.trim().split(' ');
    final initials = patientParts.length > 1
        ? '${patientParts.first[0]}${patientParts.last[0]}'.toUpperCase()
        : (patientParts.isNotEmpty && patientParts.first.isNotEmpty ? patientParts.first[0].toUpperCase() : 'P');

    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      elevation: 0.5,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderOf(context)),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de cor do status à esquerda
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSpacing.radiusMd),
                      bottomLeft: Radius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                ),

                // Bloco de horário com fundo sutil
                Container(
                  width: 76,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAltOf(context).withValues(alpha: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Fmt.time(a.start),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'até ${Fmt.time(end)}',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Avatar com iniciais
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // Conteúdo principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          a.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.medical_services_outlined, size: 12, color: AppColors.textSecondaryOf(context)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${a.specialty} • ${a.doctorName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusChip(status: status),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAltOf(context),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    a.modalidade.toLowerCase().contains('online')
                                        ? Icons.videocam_rounded
                                        : Icons.apartment_rounded,
                                    size: 11,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    a.modalidade,
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Botão Chevron de Ação
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAltOf(context).withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão moderno para expandir/recolher a lista completa.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({
    required this.expanded,
    required this.total,
    required this.onTap,
  });

  final bool expanded;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
        label: Text(
          expanded ? 'Ver menos' : 'Ver todos os $total agendamentos do dia',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      ),
    );
  }
}

/// Estado vazio premium com ilustração, informações claras e botões de ação (CTA).
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({
    required this.selectedDate,
    required this.onNewAppointment,
    required this.onOpenFullAgenda,
  });

  final DateTime selectedDate;
  final VoidCallback onNewAppointment;
  final VoidCallback onOpenFullAgenda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderOf(context)),
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceOf(context),
            AppColors.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícone estilizado com badge circular
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),

          // Título amigável
          Text(
            'Nenhuma consulta neste dia',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),

          // Descrição contextual
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              'Não há pacientes agendados para ${Fmt.weekdayFull(selectedDate)}, ${Fmt.dayMonth(selectedDate)}. Aproveite para abrir novos horários ou agendar uma consulta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Botões de Ação
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onNewAppointment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Novo Agendamento', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: onOpenFullAgenda,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: BorderSide(color: AppColors.borderOf(context)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: const Text('Ver Agenda Completa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
