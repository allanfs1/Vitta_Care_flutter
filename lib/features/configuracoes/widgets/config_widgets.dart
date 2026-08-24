import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

/// Bloco de configurações com título (Material You-like).
class ConfigSection extends StatelessWidget {
  const ConfigSection({super.key, required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// Linha com switch (CFG-05 etc.).
class ToggleSettingTile extends StatelessWidget {
  const ToggleSettingTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      secondary: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
  }
}

/// Linha de opção com valor à direita (abre seletor).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.onTap,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Seletor de cor por amostras (CFG-01).
class SwatchPicker extends StatelessWidget {
  const SwatchPicker({
    super.key,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c.toARGB32() == selected.toARGB32()
                      ? Colors.white
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  if (c.toARGB32() == selected.toARGB32())
                    BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8),
                ],
              ),
              child: c.toARGB32() == selected.toARGB32()
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Mini-preview da interface com as configurações atuais (CFG-01e / CFG-02e).
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar mock
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(theme.cardTheme.shape is RoundedRectangleBorder
                  ? AppSpacing.radiusSm
                  : AppSpacing.radiusSm),
            ),
            child: Row(
              children: const [
                Icon(Icons.favorite, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Vitta',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Título de exemplo', style: theme.textTheme.titleLarge),
          Text('Subtítulo da seção', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            'Este é um texto de corpo que reflete a fonte, o tamanho e o '
            'espaçamento escolhidos nas configurações.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Ação')),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(onPressed: () {}, child: const Text('Secundária')),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text('Badge',
                    style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Seletor segmentado simples (chips) para opções discretas.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelOf(o)),
            selected: o == selected,
            onSelected: (_) => onSelected(o),
          ),
      ],
    );
  }
}
