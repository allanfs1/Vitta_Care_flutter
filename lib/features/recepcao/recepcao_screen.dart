import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../assistente/assistant_anchors.dart';
import '../assistente/assistant_tours.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../navigation/app_router.dart';
import 'models/manchester_priority.dart';
import 'recepcao_provider.dart';
import 'widgets/acolhimento_modal.dart';

// Import the tabs
import 'widgets/tabs/fila_geral_tab.dart';
import 'widgets/tabs/finalizados_tab.dart';
import 'widgets/tabs/indicadores_tab.dart';
import 'widgets/tabs/kanban_clinico_tab.dart';
import 'widgets/tabs/meus_pacientes_tab.dart';
import 'widgets/tabs/mural_clinica_tab.dart';

class RecepcaoScreen extends ConsumerStatefulWidget {
  const RecepcaoScreen({super.key});

  @override
  ConsumerState<RecepcaoScreen> createState() => _RecepcaoScreenState();
}

class _RecepcaoScreenState extends ConsumerState<RecepcaoScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 6 tabs in total (WhatsApp was removed)
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recepcaoProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AvisoDemonstracao(),
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: AppSpacing.md,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Acolhimento e Classificação de Risco',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFF3B30),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fila por risco, demanda espontânea e linhas de cuidado da unidade.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: () => ref.read(recepcaoProvider.notifier).resetAndPopulate(),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('RESETAR E POPULAR SISTEMA'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFEBEB),
                        foregroundColor: const Color(0xFFFF3B30),
                        elevation: 0,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(recepcaoProvider.notifier).clearAll(),
                      icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                      label: const Text('Limpar Tudo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3B30),
                        side: const BorderSide(color: Color(0xFFFFCDD2)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.recepcaoMonitor),
                      icon: const Icon(Icons.connected_tv, size: 18),
                      label: const Text('Abrir Monitor'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3B30),
                        side: const BorderSide(color: Color(0xFFFFCDD2)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.totem),
                      icon: const Icon(Icons.tablet_mac, size: 18),
                      label: const Text('Abrir Totem'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3B30),
                        side: const BorderSide(color: Color(0xFFFFCDD2)),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const AcolhimentoModal(),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo Acolhimento'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? theme.colorScheme.onSurface : Colors.black87,
                        foregroundColor: isDark ? theme.colorScheme.surface : Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // KPIs — distribuição da fila por cor de risco (Manchester)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.md;
                final cols = constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 480
                        ? 2
                        : 1;
                final itemWidth =
                    (constraints.maxWidth - spacing * (cols - 1)) / cols;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final p in ManchesterPriority.values)
                      SizedBox(
                        width: itemWidth,
                        child: _buildRiskKpi(
                            context, p, state.riskCounts[p] ?? 0, state),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // TABS & CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // TAB BAR ROW
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 750),
                            child: ClipRect(
                              child: Theme(
                                data: theme.copyWith(
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                ),
                                child: AssistantTarget(
                                  anchorId: HelpAnchors.recepTabs,
                                  child: TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  dividerColor: Colors.transparent,
                                  tabAlignment: TabAlignment.start,
                                  indicator: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  labelColor: theme.colorScheme.onSurface,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  unselectedLabelColor: theme.colorScheme.primary,
                                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  tabs: const [
                                    Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('MEUS PACIENTES'))),
                                    Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('FILA GERAL'))),
                                    Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('KANBAN CLÍNICO'))),
                                    Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('FINALIZADOS'))),
                                    Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Icon(Icons.bar_chart, size: 14), SizedBox(width: 4), Text('INDICADORES')]))),
                                    Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Icon(Icons.campaign, size: 14), SizedBox(width: 4), Text('MURAL DA CLÍNICA')]))),
                                  ],
                                ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 250,
                            height: 40,
                            child: TextField(
                              onChanged: (v) => ref
                                  .read(recepcaoSearchProvider.notifier)
                                  .state = v,
                              decoration: InputDecoration(
                                hintText: 'Buscar nome, senha ou protocolo...',
                                hintStyle: TextStyle(color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // TAB VIEWS
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          MeusPacientesTab(),
                          FilaGeralTab(),
                          KanbanClinicoTab(),
                          FinalizadosTab(),
                          IndicadoresTab(),
                          MuralClinicaTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildRiskKpi(
    BuildContext context,
    ManchesterPriority priority,
    int waiting,
    RecepcaoState state,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final breaches = state.waiting
        .where((e) => e.manchester == priority && e.slaBreached(now))
        .length;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: priority.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  priority.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _slaLabel(priority),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$waiting',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900, color: priority.color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'EM ESPERA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (breaches > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: Color(0xFFFF3B30)),
                      const SizedBox(width: 4),
                      Text(
                        '$breaches SLA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFFF3B30),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _slaLabel(ManchesterPriority p) => switch (p) {
        ManchesterPriority.red => 'IMEDIATO',
        ManchesterPriority.orange => '10 MIN',
        ManchesterPriority.yellow => '60 MIN',
        ManchesterPriority.green => '120 MIN',
      };
}

/// Faixa que declara que a fila não está ligada ao banco.
///
/// O módulo tem um modelo local rico (triagem Manchester, sinais vitais,
/// microárea/ACS) que **não corresponde** ao schema das coleções de produção
/// declaradas no `ModuleRegistry` (`queue_realoc`, `tb_confirmationHistory`).
/// Persistir sem reconciliar os dois inventaria um terceiro modelo para a mesma
/// fila, então a decisão foi adiada — e enquanto isso a tela precisa dizer o
/// que é. Uma recepção que perde a fila num reload sem avisar é pior que uma
/// que avisa. Ver `.specify/ATENCAO.md`.
class _AvisoDemonstracao extends StatelessWidget {
  const _AvisoDemonstracao();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 15, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Módulo em demonstração — a fila não é gravada no banco e será '
              'reiniciada ao recarregar a página.',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
