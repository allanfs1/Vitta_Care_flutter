import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Ícone padrão ao lado de cada gráfico para gerar um relatório de IA com
/// feedbacks e insights que ajudam na leitura do gráfico.
class AiInsightButton extends StatelessWidget {
  const AiInsightButton({
    super.key,
    required this.chartTitle,
    required this.summary,
    this.compact = false,
  });

  /// Título do gráfico (usado no relatório).
  final String chartTitle;

  /// Resumo textual dos dados do gráfico, passado para a IA.
  final String summary;

  /// Versão compacta (apenas o ícone, menor).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Gerar análise por IA',
      child: InkWell(
        onTap: () => _showInsight(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Container(
          padding: EdgeInsets.all(compact ? 5 : 7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Icon(Icons.auto_awesome,
              size: compact ? 16 : 18, color: AppColors.primary),
        ),
      ),
    );
  }

  void _showInsight(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: _InsightSheet(chartTitle: chartTitle, summary: summary),
      ),
    );
  }
}

class _InsightSheet extends ConsumerStatefulWidget {
  const _InsightSheet({required this.chartTitle, required this.summary});
  final String chartTitle;
  final String summary;

  @override
  ConsumerState<_InsightSheet> createState() => _InsightSheetState();
}

class _InsightSheetState extends ConsumerState<_InsightSheet> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(aiServiceProvider)
        .chartInsight(chartTitle: widget.chartTitle, summary: widget.summary);
  }

  void _regenerate() {
    setState(() {
      _future = ref
          .read(aiServiceProvider)
          .chartInsight(chartTitle: widget.chartTitle, summary: widget.summary);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Insights — ${widget.chartTitle}',
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Análise gerada por IA (Azure / DeepSeek V4).',
              style: theme.textTheme.bodySmall),
          const Divider(height: AppSpacing.xl),
          Expanded(
            child: FutureBuilder<String>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.md),
                        Text('Analisando o gráfico…'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Não foi possível gerar a análise.',
                          style: theme.textTheme.bodyMedium));
                }
                return SingleChildScrollView(
                  child: Text(snapshot.data ?? '',
                      style: theme.textTheme.bodyMedium),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: _regenerate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerar'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Relatório salvo (demo).')),
                  );
                },
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Salvar relatório'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
