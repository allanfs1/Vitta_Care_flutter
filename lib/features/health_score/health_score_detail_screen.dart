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

/// Tela de detalhe de Health Score de um paciente.
/// Exibe: card de classificação, evolução do score, trilha de eventos,
/// conduta operacional e canais de contato.
class HealthScoreDetailScreen extends ConsumerWidget {
  const HealthScoreDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final patient = MockData.healthScores.firstWhere(
      (s) => s.id == patientId,
      orElse: () => MockData.healthScores.first,
    );

    return Scaffold(
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ── Header com botão de voltar ────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.go(AppRoutes.healthScore),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      side: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico: ${patient.patientName} (${patient.classification.subtitle})',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Detalhamento de assiduidade e inteligência comportamental.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('DIAGNÓSTICO DE IA'),
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
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Classificação + Evolução ─────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card de classificação dark
                SizedBox(
                  width: 280,
                  child: _ClassificationCard(patient: patient),
                ),
                const SizedBox(width: AppSpacing.xl),
                // Gráfico de evolução
                Expanded(
                  child: _EvolutionChart(patient: patient),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Trilha de Eventos + Conduta ──────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trilha de Eventos
                Expanded(
                  flex: 3,
                  child: _EventTrail(patient: patient),
                ),
                const SizedBox(width: AppSpacing.xl),
                // Conduta Operacional + Contato
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _OperationalConduct(patient: patient),
                      const SizedBox(height: AppSpacing.xl),
                      _ContactChannels(patient: patient),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// Card dark com classificação ativa, pontuação e índice de confiabilidade.
class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({required this.patient});
  final PatientHealthScore patient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D29),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pinkAccent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Text(
              'CLASSIFICAÇÃO ATIVA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Nome da classificação
          Text(
            patient.classification.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Watermark shield
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.verified,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                Column(
                  children: [
                    Text(
                      patient.healthScore.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'PTS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Índice de Confiabilidade
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ÍNDICE DE CONFIABILIDADE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                'CONFIÁVEL',
                style: TextStyle(
                  color: AppColors.pinkAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: patient.healthScore / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: AppColors.pinkAccent,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de evolução do Health Score (area chart simplificado).
class _EvolutionChart extends StatelessWidget {
  const _EvolutionChart({required this.patient});
  final PatientHealthScore patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVOLUÇÃO DE HEALTH SCORE',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'VARIAÇÃO DA REPUTAÇÃO BASEADA NAS INTERAÇÕES PASSADAS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Gráfico simplificado
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Eixo Y
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final label in ['100', '75', '50', '25', '0'])
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                // Área do gráfico
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.pinkAccent,
                          AppColors.pinkAccent.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 3,
                        color: AppColors.pinkAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Eixo X
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final point in patient.scoreHistory.take(8))
                  Text(
                    point.date,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trilha de Eventos e Impactos (lista vertical com cards).
class _EventTrail extends StatelessWidget {
  const _EventTrail({required this.patient});
  final PatientHealthScore patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'TRILHA DE EVENTOS E IMPACTOS',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final event in patient.events) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: event.isPositive
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.danger.withValues(alpha: 0.1),
                  child: Icon(
                    event.isPositive
                        ? Icons.person_add_alt_1
                        : Icons.person_remove,
                    color: event.isPositive ? AppColors.success : AppColors.danger,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            event.date,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Icon(Icons.schedule, size: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            event.time,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Impacto
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.north_east,
                      size: 14,
                      color: event.isPositive ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${event.scoreImpact}',
                      style: TextStyle(
                        color: event.isPositive ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Card de "Conduta Operacional Recomendada".
class _OperationalConduct extends StatelessWidget {
  const _OperationalConduct({required this.patient});
  final PatientHealthScore patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'CONDUTA OPERACIONAL RECOMENDADA',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Diretrizes
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceAltDark : AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      'DIRETRIZES PARA RECEPÇÃO:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _directive(context, 'Paciente prioridade. Pode ser alocado em listas de espera urgentes.'),
                const SizedBox(height: AppSpacing.sm),
                _directive(context, 'Liberado para Check-in expresso via Totem sem triagem manual.'),
                const SizedBox(height: AppSpacing.sm),
                _directive(context, 'Isento de políticas restritivas de cancelamento.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _directive(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Canais de contato do paciente.
class _ContactChannels extends StatelessWidget {
  const _ContactChannels({required this.patient});
  final PatientHealthScore patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CANAIS DE CONTATO',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _contactRow(context, Icons.fingerprint, 'DOCUMENTO CPF', patient.patientCpf),
          const SizedBox(height: AppSpacing.lg),
          _contactRow(context, Icons.medical_services_outlined, 'MÉDICO DE REFERÊNCIA', patient.doctorName),
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 20,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
