import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/status_badge.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_router.dart';
import '../ia/vigia/vigia_providers.dart';
import 'models/relatorio.dart';
import 'providers/relatorios_provider.dart';
import 'relatorio_detalhe_screen.dart';

/// Módulo Relatórios (REL-01..REL-04): lista de relatórios gerados + geração.
class RelatoriosScreen extends ConsumerWidget {
  const RelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatorios = ref.watch(relatoriosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGenerator(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Gerar relatório'),
      ),
      body: relatorios.isEmpty
          ? EmptyView(
              icon: Icons.description_outlined,
              message: 'Nenhum relatório ainda.\nGere o primeiro com a IA.',
              actionLabel: context.txt.t('relatorios.gerarRelatorio'),
              onAction: () => _openGenerator(context),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const _AvisoSugestoes(),
                for (var i = 0; i < relatorios.length; i++) ...[
                  _RelatorioTile(relatorio: relatorios[i]),
                  if (i < relatorios.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }

  void _openGenerator(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _GeneratorSheet(),
    );
  }
}

class _RelatorioTile extends StatelessWidget {
  const _RelatorioTile({required this.relatorio});
  final Relatorio relatorio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = relatorio;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RelatorioDetalheScreen(relatorioId: r.id)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: r.type.background,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(r.type.icon, color: r.type.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    StatusBadge(
                      label: r.type.label,
                      color: r.type.color,
                      background: r.type.background,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${r.period} • ${Fmt.dayMonth(r.createdAt)}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// Sheet de geração de relatório por tipo e período (REL-04).
class _GeneratorSheet extends ConsumerStatefulWidget {
  const _GeneratorSheet();

  @override
  ConsumerState<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends ConsumerState<_GeneratorSheet> {
  RelatorioType _type = RelatorioType.ia;
  String _period = 'Últimos 30 dias';
  bool _loading = false;

  static const _periods = [
    'Últimos 7 dias',
    'Últimos 30 dias',
    'Trimestre atual',
    'Ano atual',
  ];

  Future<void> _generate() async {
    setState(() => _loading = true);
    final clinic = ref.read(selectedClinicProvider);
    final body = await ref.read(aiServiceProvider).generateReport(clinicName: clinic.name);
    final relatorio = Relatorio(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      title: '${_type.label} — ${clinic.name}',
      type: _type,
      createdAt: DateTime.now(),
      period: _period,
      body: body,
      metrics: const [
        RelatorioMetric('Ocupação', '78%'),
        RelatorioMetric('Absenteísmo', '16%'),
        RelatorioMetric('Realocação', '72%'),
      ],
    );
    ref.read(relatoriosProvider.notifier).add(relatorio);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Relatório gerado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.txt.t('relatorios.gerarRelatorio'), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          Text(context.txt.t('relatorios.tipo'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final t in RelatorioType.values)
                ChoiceChip(
                  avatar: Icon(t.icon, size: 16, color: t.color),
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(context.txt.t('relatorios.periodo'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final p in _periods)
                ChoiceChip(
                  label: Text(p),
                  selected: _period == p,
                  onSelected: (_) => setState(() => _period = p),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Gerando…' : 'Gerar com IA'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ponte entre o relatório e a decisão que ele pede.
///
/// Quando o Vigia escreve um relatório, ele costuma propor rotinas junto. Sem
/// este aviso o gestor lê a análise, concorda, e nunca descobre que havia uma
/// ação esperando aprovação em outra tela.
class _AvisoSugestoes extends ConsumerWidget {
  const _AvisoSugestoes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentes = ref.watch(sugestoesPendentesCountProvider);
    if (pendentes == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.pending_actions_outlined,
              size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              pendentes == 1
                  ? 'A IA propôs 1 rotina de prevenção e ela aguarda sua aprovação.'
                  : 'A IA propôs $pendentes rotinas de prevenção e elas aguardam sua aprovação.',
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12.5),
            ),
            onPressed: () => context.go(AppRoutes.tarefasAgendadas),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }
}
