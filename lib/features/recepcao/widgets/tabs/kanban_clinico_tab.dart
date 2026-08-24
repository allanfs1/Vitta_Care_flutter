import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../models/queue_entry.dart';
import '../../recepcao_provider.dart';

class KanbanClinicoTab extends StatelessWidget {
  const KanbanClinicoTab({super.key});

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Kanban Clínico'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: const KanbanBoard(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openFullscreen(context),
                icon: const Icon(Icons.open_in_full, size: 16),
                label: const Text('Expandir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: KanbanBoard()),
      ],
    );
  }
}

/// Quadro Kanban (3 colunas) reutilizado inline e em tela cheia.
class KanbanBoard extends ConsumerWidget {
  const KanbanBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recepcaoProvider);
    final now = DateTime.now();

    final waiting = state.triagedQueue;
    final inService = state.inService;
    final done = state.done;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildColumn(context, ref, 'TRIAGEM / ESPERA', waiting, now, const Color(0xFFFFF9C4), QueueStatus.waiting),
            const SizedBox(width: AppSpacing.lg),
            _buildColumn(context, ref, 'EM ATENDIMENTO', inService, now, const Color(0xFFE3F2FD), QueueStatus.inService),
            const SizedBox(width: AppSpacing.lg),
            _buildColumn(context, ref, 'ALTAS / FINALIZADOS', done, now, const Color(0xFFE8F5E9), QueueStatus.done),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, WidgetRef ref, String title, List<QueueEntry> entries, DateTime now, Color headerColor, QueueStatus target) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Text('${entries.length}', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) =>
                  ref.read(recepcaoProvider.notifier).moveTo(details.data, target),
              builder: (context, candidate, rejected) {
                final hovering = candidate.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: hovering
                        ? theme.colorScheme.primary.withValues(alpha: 0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                      color: hovering
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: entries.isEmpty
                      ? Center(
                          child: Text(hovering ? 'Soltar aqui' : '—',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.outline)),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(2),
                          children: entries
                              .map((e) => _buildCard(context, ref, theme, e, now))
                              .toList(),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, ThemeData theme, QueueEntry entry, DateTime now) {
    final isDone = entry.status == QueueStatus.done;
    final card = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: entry.manchester.color, width: 6)),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: entry.manchester.color,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(entry.manchester.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: entry.manchester.onColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 8)),
                  ),
                  const SizedBox(width: 6),
                  Text('#${entry.protocol}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(entry.patientName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(entry.waitLabel(now), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(entry.origin, style: theme.textTheme.labelSmall?.copyWith(fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showEntryDetails(context, theme, entry),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Text('VISUALIZAR', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!isDone) {
                          ref.read(recepcaoProvider.notifier).complete(entry.id);
                        } else {
                          ref.read(recepcaoProvider.notifier).moveTo(entry.id, QueueStatus.inService);
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isDone ? 'REABRIR' : 'CONCLUIR', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<String>(
      data: entry.id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(width: 296, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  void _showEntryDetails(BuildContext context, ThemeData theme, QueueEntry entry) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Detalhes do Atendimento', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Paciente: ${entry.patientName}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Protocolo: #${entry.protocol}'),
                Text('Senha: ${entry.senha}'),
                Text('Risco: ${entry.manchester.label.toUpperCase()}'),
                Text('Origem: ${entry.origin}'),
                Text('Tipo: ${entry.attendanceType.label}'),
                const SizedBox(height: 16),
                if (!entry.vitals.isEmpty) ...[
                  Text('Sinais Vitais:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  if (entry.vitals.paLabel != null) Text('PA: ${entry.vitals.paLabel}'),
                  if (entry.vitals.fc != null) Text('FC: ${entry.vitals.fc} bpm'),
                  if (entry.vitals.temperatura != null) Text('Temp: ${entry.vitals.temperatura}°C'),
                  if (entry.vitals.satO2 != null) Text('SatO2: ${entry.vitals.satO2}%'),
                  if (entry.vitals.glicemia != null) Text('HGT: ${entry.vitals.glicemia} mg/dL'),
                  if (entry.vitals.dor != null && entry.vitals.dor! > 0) Text('Dor: ${entry.vitals.dor}/10'),
                  const SizedBox(height: 16),
                ],
                Text('Timeline:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                for (final t in entry.timeline)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('• ${t.action} - ${t.timestamp.hour.toString().padLeft(2, '0')}:${t.timestamp.minute.toString().padLeft(2, '0')}', style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('FECHAR'),
            ),
          ],
        );
      },
    );
  }
}
