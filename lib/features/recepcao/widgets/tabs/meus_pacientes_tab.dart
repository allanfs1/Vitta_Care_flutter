import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../models/queue_entry.dart';
import '../../recepcao_provider.dart';

class MeusPacientesTab extends ConsumerWidget {
  const MeusPacientesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recepcaoProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final activeEntries = filterBySearch(
      state.myPatients.where((e) => e.status != QueueStatus.done).toList(),
      ref.watch(recepcaoSearchProvider),
    );

    if (activeEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: Text('Nenhum paciente atribuído a você.')),
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
                DataColumn(label: Text('ESPERA')),
                DataColumn(label: Text('AÇÕES')),
              ],
              rows: activeEntries
                  .map((e) => _buildRow(context, ref, theme, e, now))
                  .toList(),
            ),
          ),
        ),
        );
      },
    );
  }

  DataRow _buildRow(BuildContext context, WidgetRef ref, ThemeData theme,
      QueueEntry entry, DateTime now) {
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entry.careLine.icon,
                      size: 12, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(entry.careLine.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        DataCell(Text(entry.waitLabel(now),
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
        DataCell(
          FilledButton.icon(
            onPressed: () =>
                ref.read(recepcaoProvider.notifier).complete(entry.id),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Atender'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
