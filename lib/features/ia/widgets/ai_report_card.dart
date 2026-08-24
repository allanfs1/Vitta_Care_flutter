import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

/// IA-03 — card que gera e exibe um relatório textual de insights.
/// Reutilizado pelo módulo de Absenteísmo (AB-07) e pela tela de IA.
class AiReportCard extends ConsumerStatefulWidget {
  const AiReportCard({super.key});

  @override
  ConsumerState<AiReportCard> createState() => _AiReportCardState();
}

class _AiReportCardState extends ConsumerState<AiReportCard> {
  bool _loading = false;
  String? _report;

  Future<void> _generate() async {
    setState(() => _loading = true);
    final clinic = ref.read(selectedClinicProvider);
    final report =
        await ref.read(aiServiceProvider).generateReport(clinicName: clinic.name);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _report = report;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: AppColors.infoLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Análise por IA — DeepSeek V4',
                    style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Gerando relatório…'),
                ],
              ),
            )
          else if (_report != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: MarkdownBody(
                data: _report!,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium,
                  h1: theme.textTheme.titleLarge,
                  h2: theme.textTheme.titleMedium,
                  h3: theme.textTheme.titleSmall,
                  listBullet: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else
            Text(
              'Gere um relatório com tendências, insights e recomendações '
              'baseado nos dados da clínica.',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: Text(_report == null ? 'Gerar relatório' : 'Regenerar'),
            ),
          ),
        ],
      ),
    );
  }
}
