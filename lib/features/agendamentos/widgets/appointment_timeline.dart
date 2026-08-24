import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../navigation/app_router.dart';

/// A-04 — Timeline diária do médico em formato vertical.
class AppointmentTimeline extends StatelessWidget {
  const AppointmentTimeline({super.key, required this.appointments});

  final List<Appointment> appointments;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const Center(child: Text('Sem consultas hoje.'));
    }
    final sorted = [...appointments]..sort((a, b) => a.start.compareTo(b.start));

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final a = sorted[i];
        final isLast = i == sorted.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Text(Fmt.time(a.start),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: a.status == AppointmentStatus.noShow
                              ? AppColors.danger
                              : null,
                        )),
              ),
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.status.color,
                      border: Border.all(color: a.status.background, width: 3),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: AppColors.border),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _TimelineCard(appointment: a)),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = appointment;
    final tinted = a.status == AppointmentStatus.noShow ||
        a.status == AppointmentStatus.cancelled;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => context.go(AppRoutes.appointmentDetail(a.id)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tinted ? a.status.background : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(a.patientName, style: theme.textTheme.titleMedium),
                  ),
                  StatusBadge.appointment(a.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('${a.doctorName} • ${a.specialty}',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${Fmt.time(a.start)} - ${Fmt.time(a.end)}',
                      style: theme.textTheme.bodySmall),
                  if (a.firstVisit) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.person_add_alt, size: 13),
                    const SizedBox(width: 2),
                    Text('Primeira visita', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
