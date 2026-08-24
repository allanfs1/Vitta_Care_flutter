import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/module.dart';
import '../../core/modules/module_graph.dart';
import '../../core/modules/module_registry.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';


/// Tela do **Mapa de Dependências entre Módulos** (AGENTS.md).
/// Renderiza o sistema de módulos: prioridades, grafo, isolamento e status.
class ArquiteturaScreen extends ConsumerWidget {
  const ArquiteturaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final graph = ModuleGraph();
    final validation = graph.validate();
    final order = graph.topologicalOrder();
    final byPriority = ModuleRegistry.byPriority;
    final columns = Responsive.gridColumns(context, max: 3);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de Módulos')),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Sistema de módulos do Vitta: ${ModuleRegistry.modules.length} '
              'módulos, organizados por prioridade e dependências. Use o '
              'interruptor de cada card para habilitar ou desabilitar um módulo '
              '(os módulos base não podem ser desligados).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Validação do grafo
            _ValidationBanner(validation: validation),
            const SizedBox(height: AppSpacing.lg),


            // Ordem de implementação (topológica)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Ordem de implementação',
                    subtitle: 'Sequência válida que respeita as dependências',
                    icon: Icons.format_list_numbered,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (var i = 0; i < order.length; i++)
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ),
                          label: Text(order[i].title),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Módulos por prioridade
            for (final p in ModulePriority.values)
              if (byPriority[p]!.isNotEmpty) ...[
                _PriorityHeader(priority: p),
                const SizedBox(height: AppSpacing.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: byPriority[p]!.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisExtent: 232,
                  ),
                  itemBuilder: (context, i) =>
                      _ModuleCard(module: byPriority[p]![i], graph: graph),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
          ],
        ),
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.validation});
  final GraphValidation validation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = validation.ok;
    return AppCard(
      color: ok ? AppColors.successLight : AppColors.dangerLight,
      child: Row(
        children: [
          Icon(ok ? Icons.verified : Icons.error_outline,
              color: ok ? AppColors.success : AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              ok
                  ? 'Grafo válido: acíclico (DAG), todas as dependências existem '
                      'e o isolamento de coleções é respeitado.'
                  : 'Problemas: ciclos=${validation.cycles.length}, '
                      'deps ausentes=${validation.missingDeps.length}, '
                      'conflitos de coleção=${validation.collectionConflicts.length}.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityHeader extends StatelessWidget {
  const _PriorityHeader({required this.priority});
  final ModulePriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
          decoration: BoxDecoration(
            color: priority.color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Text(priority.label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(priority.description, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _ModuleCard extends ConsumerWidget {
  const _ModuleCard({required this.module, required this.graph});
  final AppModule module;
  final ModuleGraph graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final deps = graph.dependenciesOf(module.id);
    final notifier = ref.watch(disabledModulesProvider.notifier);
    final disabledSet = ref.watch(disabledModulesProvider);
    final isDisabled = disabledSet.contains(module.id);
    final canToggle = notifier.canToggle(module.id);

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: AppCard(
        onTap: (module.route == null || isDisabled)
            ? null
            : () => context.go(module.route!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(module.icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(module.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (canToggle)
                  Switch.adaptive(
                    value: !isDisabled,
                    onChanged: (v) => notifier.setEnabled(module.id, v),
                  )
                else
                  Tooltip(
                    message: 'Módulo base (não pode ser desabilitado)',
                    child: Icon(Icons.lock_outline,
                        size: 16, color: theme.textTheme.bodySmall?.color),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: _StatusDot(status: module.status),
            ),
          const SizedBox(height: 4),
          Text(module.code, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Text(module.description,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  deps.isEmpty
                      ? 'Sem dependências'
                      : 'Depende de: ${deps.map((d) => d.title).join(', ')}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (module.ownedCollections.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.storage_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Escreve: ${module.ownedCollections.join(', ')}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final ModuleStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: status.color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
