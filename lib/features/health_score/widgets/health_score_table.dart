import 'package:flutter/material.dart';

import '../../../core/models/patient_health_score.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

class HealthScoreTable extends StatelessWidget {
  const HealthScoreTable({
    super.key,
    required this.scores,
    this.onTap,
  });

  final List<PatientHealthScore> scores;
  final void Function(PatientHealthScore)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _headerCell('PACIENTE / IDENTIDADE', theme, isDark)),
                Expanded(flex: 2, child: _headerCell('CLASSIFICAÇÃO IA', theme, isDark, center: true)),
                Expanded(flex: 2, child: _headerCell('HEALTH SCORE', theme, isDark, center: true)),
                Expanded(flex: 1, child: _headerCell('TENDÊNCIA', theme, isDark, center: true)),
                Expanded(flex: 2, child: _headerCell('ASSIDUIDADE (FALTAS)', theme, isDark, center: true)),
                Expanded(flex: 1, child: _headerCell('AÇÃO', theme, isDark, center: true)),
              ],
            ),
          ),
          // Linhas
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: scores.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? AppColors.borderDark : AppColors.border,
            ),
            itemBuilder: (_, i) => _buildRow(context, scores[i], isDark),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, ThemeData theme, bool isDark, {bool center = false}) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildRow(BuildContext context, PatientHealthScore score, bool isDark) {
    final theme = Theme.of(context);
    final classColor = _classColor(score.classification);

    return InkWell(
      onTap: () => onTap?.call(score),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            // Paciente / Identidade
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDark
                        ? AppColors.surfaceAltDark
                        : AppColors.background,
                    child: Text(
                      score.initials,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score.patientName} (${score.classification.subtitle})',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(Icons.call, size: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              score.patientCpf,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Classificação IA
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: classColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(color: classColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: classColor),
                      const SizedBox(width: 4),
                      Text(
                        score.classification.label,
                        style: TextStyle(
                          color: classColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Health Score
            Expanded(
              flex: 2,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SCORE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: classColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Text(
                        score.healthScore.toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: classColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Progress bar
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score.healthScore / 100,
                          backgroundColor: isDark
                              ? AppColors.surfaceAltDark
                              : AppColors.background,
                          color: classColor,
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tendência
            Expanded(
              flex: 1,
              child: Center(
                child: score.trend != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            score.trend! >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 16,
                            color: score.trend! >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${score.trend! >= 0 ? '+' : ''}${score.trend!.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: score.trend! >= 0
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '—',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            // Assiduidade (Faltas)
            Expanded(
              flex: 2,
              child: Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${score.absences}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' / OF',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: '\nTOTAL: ${score.totalAppointments}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Ação
            Expanded(
              flex: 1,
              child: Center(
                child: IconButton(
                  onPressed: () => onTap?.call(score),
                  icon: Icon(
                    Icons.chevron_right,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _classColor(HealthClassification c) {
    switch (c) {
      case HealthClassification.diamante:
        return const Color(0xFF4F46E5);
      case HealthClassification.ouro:
        return const Color(0xFFD97706);
      case HealthClassification.prata:
        return const Color(0xFF6B7280);
      case HealthClassification.bronze:
        return const Color(0xFFDC2626);
    }
  }
}
