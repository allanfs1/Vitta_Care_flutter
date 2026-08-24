import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/app_card.dart';
import 'widgets/agent_table.dart';
import 'widgets/new_agent_modal.dart';
import 'widgets/queue_management_tab.dart';

class AdminAgentesScreen extends ConsumerStatefulWidget {
  const AdminAgentesScreen({super.key});

  @override
  ConsumerState<AdminAgentesScreen> createState() => _AdminAgentesScreenState();
}

class _AdminAgentesScreenState extends ConsumerState<AdminAgentesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppHeader(
            title: 'Gestão de Atendimento',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.people_outline, size: 20),
                            SizedBox(width: AppSpacing.sm),
                            Text('AGENTES E CREDENCIAIS'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.grid_view, size: 20),
                            SizedBox(width: AppSpacing.sm),
                            Text('SETORES / FILAS'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Tab 1: Agentes e Credenciais
                  AppCard(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Credenciais da Equipe',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'VISUALIZE O LOGIN E O PIN DE CADA ATENDENTE.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              FilledButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const NewAgentModal(),
                                  );
                                },
                                icon: const Icon(Icons.person_add_outlined),
                                label: const Text('NOVO ATENDENTE'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF3B30),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        const Expanded(child: AgentTable()),
                      ],
                    ),
                  ),
                  // Tab 2: Setores / Filas
                  const QueueManagementTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
