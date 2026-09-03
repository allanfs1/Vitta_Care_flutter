import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../assistente/assistant_anchors.dart';
import '../assistente/assistant_controller.dart';
import '../assistente/assistant_tours.dart';
import 'monte_carlo_providers.dart';
import 'widgets/mc_acoes_ia.dart';
import 'widgets/mc_calibracao_tab.dart';
import 'widgets/mc_comuns.dart';
import 'widgets/mc_decisao_tab.dart';
import 'widgets/mc_parametros_tab.dart';
import 'widgets/mc_planejador_tab.dart';

/// Simulador de Monte Carlo da agenda.
///
/// Responde a uma pergunta operacional: **quantos pacientes cabem amanhã sem
/// estourar a sala de espera?** A resposta sai da distribuição inteira de
/// faltas, não da média — é limitada pelo pior slot do dia (uma falta às 16h
/// não abre vaga às 9h) e passa antes pela lista de espera, que preenche vaga
/// de fato liberada sem criar espera para ninguém.
class MonteCarloScreen extends ConsumerStatefulWidget {
  const MonteCarloScreen({super.key});

  @override
  ConsumerState<MonteCarloScreen> createState() => _MonteCarloScreenState();
}

class _MonteCarloScreenState extends ConsumerState<MonteCarloScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void initState() {
    super.initState();
    // Libera a ponte no painel de Overbooking a partir daqui.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(mcSessaoAtivaProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mcDataProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    void mover(int dias) => ref.read(mcDataProvider.notifier).state =
        DateTime(data.year, data.month, data.day + dias);

    return Scaffold(
      backgroundColor: dark ? AppColors.backgroundDark : AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                  child: AssistantTarget(
                    anchorId: HelpAnchors.simHeader,
                    child: _Cabecalho(
                      data: data,
                      hoje: _mesmoDia(data, DateTime.now()),
                      onMover: mover,
                      onHoje: () {
                        final n = DateTime.now();
                        ref.read(mcDataProvider.notifier).state =
                            DateTime(n.year, n.month, n.day);
                      },
                      onAjuda: () => ref
                          .read(assistantProvider.notifier)
                          .startTour('simulador'),
                    ),
                  ),
                ),
                AssistantTarget(
                  anchorId: HelpAnchors.simTabs,
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Decisão'),
                      // O planejador vem logo depois da Decisão: quem entende
                      // o dia quer a semana em seguida. Ações de IA lê o que
                      // as duas primeiras já calcularam. Calibração e
                      // Parâmetros são ajuste, e ficam no fim.
                      Tab(
                        icon: Icon(Icons.auto_awesome, size: 16),
                        iconMargin: EdgeInsets.zero,
                        text: 'Planejador',
                      ),
                      Tab(
                        icon: Icon(Icons.smart_toy_outlined, size: 16),
                        iconMargin: EdgeInsets.zero,
                        text: 'Ações de IA',
                      ),
                      Tab(text: 'Calibração'),
                      Tab(text: 'Parâmetros'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _Rolagem(child: const _AbaDecisao()),
                      _Rolagem(child: const McPlanejadorTab()),
                      _Rolagem(
                        child: AssistantTarget(
                          anchorId: HelpAnchors.simAcoesIa,
                          child: const McAcoesIa(),
                        ),
                      ),
                      _Rolagem(child: const McCalibracaoTab()),
                      _Rolagem(child: const McParametrosTab()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rolagem extends StatelessWidget {
  const _Rolagem({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
        padding: AppSpacing.pageInsets,
        children: [child],
      );
}

class _AbaDecisao extends ConsumerWidget {
  const _AbaDecisao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mcResultadoProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => McCartao(
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Falha na simulação: $e')),
          ],
        ),
      ),
      data: (r) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          McDecisaoTab(resultado: r),
          if (r.totalAgendados > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            McComposicaoRisco(resultado: r),
          ],
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.data,
    required this.hoje,
    required this.onMover,
    required this.onHoje,
    required this.onAjuda,
  });

  final DateTime data;
  final bool hoje;
  final void Function(int) onMover;
  final VoidCallback onHoje;
  final VoidCallback onAjuda;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Simulador de Agenda',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  )),
              const SizedBox(height: 2),
              Text(
                'Distribuição de faltas, lista de espera e overbooking por slot',
                style: TextStyle(
                  fontSize: 12,
                  color: dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        AssistantTarget(
          anchorId: HelpAnchors.simAjuda,
          child: IconButton(
            onPressed: onAjuda,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Como usar o Simulador',
          ),
        ),
        IconButton(
          onPressed: () => onMover(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Dia anterior',
        ),
        TextButton(
          onPressed: onHoje,
          child: Text(
            hoje ? 'Hoje' : Fmt.shortDate(data),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: () => onMover(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo dia',
        ),
      ],
    );
  }
}
