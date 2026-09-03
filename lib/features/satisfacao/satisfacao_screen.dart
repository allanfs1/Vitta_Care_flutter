import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/mock_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import 'widgets/satisfacao_filters.dart';
import 'widgets/satisfacao_kpi_cards.dart';
import 'widgets/satisfacao_table.dart';

class SatisfacaoScreen extends ConsumerWidget {
  const SatisfacaoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Obtendo dados do MockData para a tela
    final feedbacks = MockData.patientFeedbacks;
    final totalFeedbacks = feedbacks.length;
    final criticos = feedbacks.where((f) => f.isCritical).length;
    final mediaGeral = feedbacks.isEmpty 
      ? 0.0 
      : feedbacks.map((f) => f.averageRating).reduce((a, b) => a + b) / totalFeedbacks;
    
    // Simplificando o NPS para o mockup (Promotores - Detratores)
    // Para simplificar, vou calcular algo fictício baseado nos dados
    final nps = feedbacks.isEmpty ? 0 : 20; 

    return Scaffold(
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Satisfação do Paciente',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Gestão estratégica de NPS e auditoria de qualidade.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.blueAccent, // Tom azul claro do mockup
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('ANÁLISE DE DADOS'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('SEED AUDITORIA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('EXPORTAR CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            
            // KPIs
            SatisfacaoKpiCards(
              mediaGeral: mediaGeral,
              nps: nps,
              totalFeedbacks: totalFeedbacks,
              criticos: criticos,
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Filtros
            const SatisfacaoFilters(),
            const SizedBox(height: AppSpacing.xl),
            
            // Tabela de Dados
            SatisfacaoTable(feedbacks: feedbacks),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
