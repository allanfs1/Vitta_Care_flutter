import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../models/queue_entry.dart';
import '../../recepcao_provider.dart';
import '../fullscreen_helper.dart';

class FilaGeralTab extends StatelessWidget {
  const FilaGeralTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpandTabBar(
          onExpand: () => showRecepcaoFullscreen(
              context, 'Fila Geral', const FilaGeralTable()),
        ),
        const Expanded(child: FilaGeralTable()),
      ],
    );
  }
}

class FilaGeralTable extends ConsumerWidget {
  const FilaGeralTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recepcaoProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Espera ordenada por risco; depois os que já estão em atendimento.
    final active = filterBySearch([
      ...state.triagedQueue,
      ...state.inService,
    ], ref.watch(recepcaoSearchProvider));

    if (active.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: Text('Nenhum paciente na fila geral.')),
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
              dataRowMaxHeight: 88,
              dataRowMinHeight: 88,
              columnSpacing: AppSpacing.md,
              columns: const [
                DataColumn(label: Text('RISCO / PROTOCOLO')),
                DataColumn(label: Text('PACIENTE')),
                DataColumn(label: Text('ESPERA / SLA')),
                DataColumn(label: Text('RESPONSÁVEL / eSF')),
                DataColumn(label: Text('AÇÕES')),
              ],
              rows: active
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
    final breached = entry.slaBreached(now);
    return DataRow(
      cells: [
        // RISCO / PROTOCOLO
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: entry.manchester.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.manchester.color,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      entry.manchester.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: entry.manchester.onColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('#${entry.protocol}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        // PACIENTE
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.patientName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
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
                  const SizedBox(width: 6),
                  Text('• ${entry.attendanceType.label}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              if (!entry.vitals.isEmpty)
                Text(_vitalsSummary(entry),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),

        // ESPERA / SLA
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.waitLabel(now),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: breached
                      ? const Color(0xFFFFEBEB)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      breached ? Icons.timer_outlined : Icons.schedule,
                      size: 11,
                      color: breached
                          ? const Color(0xFFFF3B30)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      breached ? 'SLA ESTOURADO' : 'NO PRAZO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: breached
                            ? const Color(0xFFFF3B30)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // RESPONSÁVEL / eSF
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.assignedTo ?? 'Não atribuído',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (entry.microarea.isNotEmpty || entry.acs.isNotEmpty)
                Text(
                  [
                    if (entry.microarea.isNotEmpty) 'Microárea ${entry.microarea}',
                    if (entry.acs.isNotEmpty) entry.acs,
                  ].join(' • '),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),

        // AÇÕES
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Chamar',
                icon: const Icon(Icons.campaign_outlined,
                    color: Colors.grey, size: 20),
                onPressed: () =>
                    ref.read(recepcaoProvider.notifier).callNext(),
              ),
              IconButton(
                tooltip: 'Encaminhar (Referência)',
                icon: const Icon(Icons.north_east, color: Colors.grey, size: 20),
                onPressed: () => _referDialog(context, ref, entry),
              ),
              IconButton(
                tooltip: 'Concluir',
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.grey, size: 20),
                onPressed: () =>
                    ref.read(recepcaoProvider.notifier).complete(entry.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _vitalsSummary(QueueEntry e) {
    final v = e.vitals;
    final parts = <String>[
      if (v.paLabel != null) 'PA ${v.paLabel}',
      if (v.fc != null) 'FC ${v.fc}',
      if (v.temperatura != null) '${v.temperatura}°',
      if (v.satO2 != null) 'SatO₂ ${v.satO2}%',
      if (v.glicemia != null) 'HGT ${v.glicemia}',
      if (v.dor != null && v.dor! > 0) 'Dor ${v.dor}/10',
    ];
    return parts.join('  ·  ');
  }

  Future<void> _referDialog(
      BuildContext context, WidgetRef ref, QueueEntry entry) async {
    const destinos = [
      'UPA Central',
      'Hospital Regional',
      'CAPS',
      'Ambulatório de Especialidades',
    ];
    final destino = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Encaminhar ${entry.patientName}'),
        children: [
          for (final d in destinos)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 18),
                    const SizedBox(width: 12),
                    Text(d),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (destino != null) {
      ref.read(recepcaoProvider.notifier).refer(entry.id, destino);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.patientName} encaminhado para $destino.')),
        );
      }
    }
  }
}
