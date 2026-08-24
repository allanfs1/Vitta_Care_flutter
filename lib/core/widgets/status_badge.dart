import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_spacing.dart';

/// Badge de status com cor e fundo. Usado para status de consulta e risco.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  StatusBadge.appointment(AppointmentStatus status, {super.key})
      : label = status.label,
        color = status.color,
        background = status.background,
        icon = status.icon;

  StatusBadge.risk(RiskLevel level, {super.key, String prefix = 'Risco '})
      : label = '$prefix${level.label}',
        color = level.color,
        background = level.background,
        icon = null;

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
