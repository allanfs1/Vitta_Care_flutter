import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../agent/ia_suggestions.dart';

/// Painel de autocomplete/atalhos exibido acima do input do chat e do agente.
/// Mostra sugestões agrupadas por categoria, filtradas pelo texto digitado.
class IaSuggestionsPanel extends StatelessWidget {
  const IaSuggestionsPanel({
    super.key,
    required this.query,
    required this.onSelect,
    this.maxHeight = 280,
  });

  final String query;
  final void Function(String prompt) onSelect;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final cats = filterSuggestions(query);
    if (cats.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          shrinkWrap: true,
          children: [
            for (final c in cats) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 4),
                child: Row(
                  children: [
                    Icon(c.icon, size: 15, color: AppColors.pinkAccent),
                    const SizedBox(width: 6),
                    Text(
                      c.title.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              for (final item in c.items)
                InkWell(
                  onTapDown: (_) => onSelect(item),
                  onTap: () {}, // Mantém o visual do InkWell
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.north_east,
                            size: 13, color: AppColors.textTertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
