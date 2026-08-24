import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../navigation/app_router.dart';
import '../models/agent_model.dart';
import '../providers/agent_provider.dart';
import 'feedback_gravacao.dart';

class AgentTable extends ConsumerWidget {
  const AgentTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final theme = Theme.of(context);

    if (agents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: Text('Nenhum atendente cadastrado.')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingTextStyle: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
              dataRowMaxHeight: 80,
              dataRowMinHeight: 80,
              columnSpacing: AppSpacing.md,
              columns: const [
                DataColumn(label: Text('ATENDENTE (LOGIN)')),
                DataColumn(label: Text('SENHA (PIN)')),
                DataColumn(label: Text('DISPONIBILIDADE')),
                DataColumn(label: Text('SETORES')),
                DataColumn(label: Text('CARGA')),
                DataColumn(label: Text('AÇÕES')),
              ],
              rows: agents.map((agent) => _buildRow(context, ref, agent)).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildRow(BuildContext context, WidgetRef ref, AgentModel agent) {
    final theme = Theme.of(context);

    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(agent.nomeOperacional,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(agent.email,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key, color: Color(0xFFFF3B30), size: 16),
                const SizedBox(width: 8),
                Text(
                  agent.pin.split('').join(' '),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFFF3B30),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: agent.disponibilidade.color.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AgentAvailability>(
                value: agent.disponibilidade,
                icon: Icon(Icons.keyboard_arrow_down,
                    color: agent.disponibilidade.color),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: agent.disponibilidade.color,
                ),
                onChanged: (val) {
                  if (val != null) {
                    comFeedback(
                      context,
                      () => ref
                          .read(agentsProvider.notifier)
                          .updateAvailability(agent.id, val),
                    );
                  }
                },
                items: [
                  for (final status in AgentAvailability.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(
                        status.label,
                        style: TextStyle(color: status.color),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        DataCell(
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: agent.setores.map((setor) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  setor,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFFF3B30),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ATIVOS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  )),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(text: '${agent.cargaAtivos} '),
                    TextSpan(
                      text: '/ ${agent.cargaMaxima}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.desktop_windows_outlined, color: Color(0xFFFF3B30)),
                onPressed: () =>
                    context.go('${AppRoutes.agentDashboard}/${agent.id}'),
                tooltip: 'Ver Dashboard',
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edição de atendente em breve.')),
                  );
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30)),
                onPressed: () => _confirmRemove(context, ref, agent),
                tooltip: 'Remover',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, AgentModel agent) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover atendente'),
        content: Text(
            'Deseja remover ${agent.nomeOperacional}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await comFeedback(
        context,
        () => ref.read(agentsProvider.notifier).removeAgent(agent.id),
      );
    }
  }
}
