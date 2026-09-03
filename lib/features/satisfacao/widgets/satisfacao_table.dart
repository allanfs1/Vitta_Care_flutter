import 'package:flutter/material.dart';

import '../../../core/i18n/textos.dart';
import 'package:intl/intl.dart';

import '../../../core/models/patient_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';

class SatisfacaoTable extends StatelessWidget {
  const SatisfacaoTable({
    super.key,
    required this.feedbacks,
  });

  final List<PatientFeedback> feedbacks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da Tabela
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildHeaderCell('DATA / HORÁRIO', theme, isDark)),
                Expanded(flex: 3, child: _buildHeaderCell('PACIENTE', theme, isDark)),
                Expanded(flex: 2, child: _buildHeaderCell('NOTA SISTEMA', theme, isDark, center: true)),
                Expanded(flex: 2, child: _buildHeaderCell('NOTA UNIDADE', theme, isDark, center: true)),
                Expanded(flex: 2, child: _buildHeaderCell('NOTA EQUIPE', theme, isDark, center: true)),
                Expanded(flex: 1, child: _buildHeaderCell('MÉDIA', theme, isDark, center: true)),
                Expanded(flex: 2, child: _buildHeaderCell('AÇÕES', theme, isDark, center: true)),
              ],
            ),
          ),
          
          // Linhas da Tabela
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: feedbacks.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? AppColors.borderDark : AppColors.border,
            ),
            itemBuilder: (context, index) {
              return _buildRow(context, feedbacks[index], isDark);
            },
          ),
          
          // Rodapé (Paginação)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXIBINDO ${feedbacks.length} DE ${feedbacks.length} FEEDBACKS FILTRADOS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: null,
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                      child: Text(
                        'PÁGINA 1 / 1',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: null,
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, ThemeData theme, bool isDark, {bool center = false}) {
    return Text(
      title,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildRow(BuildContext context, PatientFeedback feedback, bool isDark) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Data / Horário
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(feedback.createdAt),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('HH:mm').format(feedback.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Paciente
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person_outline, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              feedback.patientName,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (feedback.isCritical) ...[
                            const SizedBox(width: AppSpacing.sm),
                            StatusBadge(
                              label: context.txt.t('satisfacao.critico'),
                              color: AppColors.danger,
                              background: AppColors.dangerLight,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        feedback.patientId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Notas
          Expanded(flex: 2, child: Center(child: _buildStars(feedback.systemRating))),
          Expanded(flex: 2, child: Center(child: _buildStars(feedback.unitRating))),
          Expanded(flex: 2, child: Center(child: _buildStars(feedback.teamRating))),
          
          // Média
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                decoration: BoxDecoration(
                  color: feedback.isCritical 
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  feedback.averageRating.toStringAsFixed(0),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: feedback.isCritical ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          
          // Ações
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(Icons.chat_bubble_outline, Colors.green),
                const SizedBox(width: AppSpacing.xs),
                _buildActionButton(Icons.info_outline, AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                _buildActionButton(Icons.assignment_outlined, isDark ? Colors.white : Colors.black87),
                const SizedBox(width: AppSpacing.xs),
                _buildActionButton(Icons.delete_outline, AppColors.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          Icons.star,
          size: 16,
          color: index < rating ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2),
        );
      }),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
