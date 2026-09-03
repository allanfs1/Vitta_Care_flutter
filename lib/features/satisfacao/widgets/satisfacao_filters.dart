import 'package:flutter/material.dart';

import '../../../core/i18n/textos.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

class SatisfacaoFilters extends StatelessWidget {
  const SatisfacaoFilters({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Filtros de Auditoria',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Primeira linha de inputs
            Row(
              children: [
                Expanded(child: _buildField(context, label: context.txt.t('satisfacao.pacienteNome'), hint: 'Nome...', prefixIcon: Icons.person_outline)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _buildField(context, label: context.txt.t('satisfacao.eMail'), hint: 'Email do paciente...', prefixIcon: Icons.email_outlined)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _buildField(context, label: 'CPF', hint: '000.000.000-00', prefixIcon: Icons.badge_outlined)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _buildField(context, label: 'PROTOCOLO', hint: 'Ex: 240501...', prefixIcon: Icons.receipt_long_outlined)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Segunda linha de inputs
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildField(context, label: context.txt.t('satisfacao.inicio'), hint: 'dd/mm/aaaa', suffixIcon: Icons.calendar_today_outlined)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _buildField(context, label: 'FIM', hint: 'dd/mm/aaaa', suffixIcon: Icons.calendar_today_outlined)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOTA GERAL',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : AppColors.background,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: 'Todas as notas',
                            items: const [
                              DropdownMenuItem(value: 'Todas as notas', child: Text('Todas as notas')),
                              DropdownMenuItem(value: '5 Estrelas', child: Text('5 Estrelas')),
                              DropdownMenuItem(value: 'Críticos (≤ 3)', child: Text('Críticos (≤ 3)')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                
                // Botões de Ação
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                        child: const Text('LIMPAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('BUSCAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: 18,
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required String label,
    required String hint,
    IconData? prefixIcon,
    IconData? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18) : null,
            filled: true,
            fillColor: isDark ? Colors.grey[800] : AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
