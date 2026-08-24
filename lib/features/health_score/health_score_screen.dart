import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/patient_health_score.dart';
import '../../core/services/mock_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../navigation/app_router.dart';
import 'widgets/health_score_kpi_cards.dart';
import 'widgets/health_score_table.dart';
import 'widgets/tendencia_reputacao_dialog.dart';

class HealthScoreScreen extends ConsumerStatefulWidget {
  const HealthScoreScreen({super.key});

  @override
  ConsumerState<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends ConsumerState<HealthScoreScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scores = MockData.healthScores;

    // Contadores para KPIs
    final elite = scores.where((s) => s.classification == HealthClassification.diamante).length;
    final assiduos = scores.where((s) => s.classification == HealthClassification.ouro).length;
    final atencao = scores.where((s) => s.classification == HealthClassification.prata).length;
    final risco = scores.where((s) => s.classification == HealthClassification.bronze).length;

    // Filtra pacientes pelo campo de busca
    final filtered = _searchQuery.isEmpty
        ? scores
        : scores.where((s) =>
            s.patientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.patientCpf.contains(_searchQuery)).toList();

    return Scaffold(
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ── Header ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Score do Paciente',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Auditoria comportamental baseada em assiduidade histórica.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showTendenciaDialog(context),
                      icon: const Icon(Icons.show_chart, size: 18),
                      label: const Text('TENDÊNCIA GLOBAL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pinkAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.lg,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('EXPORTAR CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.lg,
                        ),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.border,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('SINCRONIZAR SCORES'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.textPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.lg,
                        ),
                      ),
                    ),
                    // Ícone de impressão
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.print_outlined,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          side: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── KPI Cards ───────────────────────────────
            HealthScoreKpiCards(
              elite: elite,
              assiduos: assiduos,
              atencao: atencao,
              risco: risco,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Search + Filters ────────────────────────
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome ou CPF do paciente...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.border,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.surfaceAltDark : AppColors.background,
                        ),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.filter_alt_outlined, size: 18),
                      label: const Text('FILTROS AVANÇADOS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: 18,
                        ),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.refresh, size: 20),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          side: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Tabela ──────────────────────────────────
            HealthScoreTable(
              scores: filtered,
              onTap: (patient) {
                context.go('${AppRoutes.healthScore}/${patient.id}');
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _showTendenciaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const TendenciaReputacaoDialog(),
    );
  }
}
