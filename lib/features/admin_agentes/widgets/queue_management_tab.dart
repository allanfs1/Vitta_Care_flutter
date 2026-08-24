import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../models/queue_model.dart';
import '../providers/agent_provider.dart';
import '../providers/queue_provider.dart';
import 'feedback_gravacao.dart';
import 'queue_form_modal.dart';

const _kBrandRed = Color(0xFFFF3B30);
const _kBrandRedBg = Color(0xFFFFF0F0);
const _kDarkPill = Color(0xFF1C1C1E);

/// Aba "SETORES / FILAS" (§1.2): gerência de filas com estratégia e SLA.
class QueueManagementTab extends ConsumerWidget {
  const QueueManagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queues = ref.watch(queuesProvider);

    return AppCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setores e Filas',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'DEFINA A ESTRATÉGIA DE DISTRIBUIÇÃO E O SLA DE CADA FILA.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const QueueFormModal(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('NOVA FILA'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrandRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: queues.isEmpty
                ? _EmptyState(theme: theme)
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: queues.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        _QueueCard(queue: queues[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: theme.dividerColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            'NENHUMA FILA CADASTRADA',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.queue});

  final QueueModel queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agentIds = ref.watch(agentsProvider).map((a) => a.id).toSet();
    final agentCount = queue.agentIds.where(agentIds.contains).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kBrandRed,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.alt_route, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(queue.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Pill(
                      icon: Icons.alt_route,
                      text: queue.distributionStrategy.label,
                      background: _kBrandRedBg,
                      foreground: _kBrandRed,
                    ),
                    _Pill(
                      icon: Icons.bolt_outlined,
                      text:
                          'SLA ${queue.sla.firstResponse.inMinutes}min / ${queue.sla.resolution.inMinutes}min',
                      background: theme.colorScheme.surfaceContainerHighest,
                      foreground: theme.colorScheme.onSurfaceVariant,
                    ),
                    _Pill(
                      icon: Icons.people_outline,
                      text: '$agentCount agente(s)',
                      background: _kDarkPill,
                      foreground: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.grey),
            tooltip: 'Editar',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => QueueFormModal(queue: queue),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _kBrandRed),
            tooltip: 'Remover',
            onPressed: () => _confirmRemove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover fila'),
        content: Text(
            'Deseja remover a fila ${queue.name}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: _kBrandRed),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await comFeedback(
        context,
        () => ref.read(queuesProvider.notifier).removeQueue(queue.id),
      );
    }
  }
}

/// Pílula de informação no padrão dos badges da aplicação.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
