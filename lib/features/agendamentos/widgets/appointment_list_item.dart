import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/appointment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../navigation/app_router.dart';

/// Item da lista de agendamentos (A-01).
class AppointmentListItem extends StatelessWidget {
  const AppointmentListItem({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = appointment;
    return AppCard(
      onTap: () => context.go(AppRoutes.appointmentDetail(a.id)),
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
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.medical_services_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${a.doctorName} • ${a.specialty}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    '${Fmt.time(a.start)} – ${Fmt.time(a.end)} • ${a.tipoConsulta}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (a.lateMinutes != null) ...[
                const SizedBox(width: 8),
                StatusBadge(
                  label: 'Atraso ${a.lateMinutes}m',
                  color: AppColors.danger,
                  background: AppColors.dangerLight,
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
