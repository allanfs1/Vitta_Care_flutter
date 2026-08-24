import 'package:flutter/material.dart';

import '../../../core/models/clinic.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

/// H-02 — Perfil da unidade, com visual adaptado ao tipo (UBS/UPA/APS/Privada).
class UnitProfileBanner extends StatelessWidget {
  const UnitProfileBanner({super.key, required this.clinic});

  final Clinic clinic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = clinic.type;
    return AppCard(
      color: type.color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: type.color,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.local_hospital, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: type.color,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text(
                        type.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (type.isB2B) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.workspace_premium, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(type.description, style: theme.textTheme.titleMedium),
                Text(
                  clinic.specialties.take(3).join(' • '),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
