import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../models/queue_entry.dart';
import '../../recepcao_provider.dart';

class FinalizadosTab extends ConsumerWidget {
  const FinalizadosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recepcaoProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final doneEntries =
        filterBySearch(state.done, ref.watch(recepcaoSearchProvider));

    if (doneEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: Text('Nenhum paciente finalizado.')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingTextStyle: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
              dataRowMaxHeight: 84,
              dataRowMinHeight: 84,
              columnSpacing: AppSpacing.md,
              columns: const [
                DataColumn(label: Text('RISCO / PROTOCOLO')),
                DataColumn(label: Text('PACIENTE')),
                DataColumn(label: Text('DESFECHO')),
                DataColumn(label: Text('RESPONSÁVEL')),
                DataColumn(label: Text('AÇÕES')),
              ],
              rows: doneEntries.map((e) => _buildRow(theme, e, now)).toList(),
            ),
          ),
        ),
        );
      },
    );
  }

  DataRow _buildRow(ThemeData theme, QueueEntry entry, DateTime now) {
    final referred = entry.referral != null && entry.referral!.isNotEmpty;
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 44,
                decoration: BoxDecoration(
                  color: entry.manchester.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('#${entry.protocol}',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.patientName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(entry.careLine.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (referred ? AppColors.warning : AppColors.success)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(referred ? Icons.north_east : Icons.check_circle,
                    size: 13,
                    color: referred ? AppColors.warning : AppColors.success),
                const SizedBox(width: 4),
                Text(
                  referred ? 'ENCAMINHADO • ${entry.referral}' : 'ATENDIDO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: referred ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  entry.assignedTo?.isNotEmpty == true
                      ? entry.assignedTo![0]
                      : '?',
                  style: TextStyle(
                      fontSize: 10, color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(entry.assignedTo ?? 'Sistema',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Imprimir comprovante',
            icon: const Icon(Icons.print_outlined, color: Colors.grey, size: 20),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}
