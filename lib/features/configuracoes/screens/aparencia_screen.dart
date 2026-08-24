import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/app_settings.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';

/// CFG-01 — Aparência (cores, paletas, fundo) com preview em tempo real.
class AparenciaScreen extends ConsumerWidget {
  const AparenciaScreen({super.key});

  static const _backgrounds = [
    Color(0xFFFFFFFF),
    Color(0xFFF4F6FA),
    Color(0xFFEAEFF6),
    Color(0xFF0F1320),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const ThemePreviewCard(),
          ConfigSection(
            title: 'Paletas (CFG-01d)',
            subtitle: 'Conjuntos de cores curados',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final p in AppPalette.all)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: p.primary, radius: 8),
                        label: Text(p.label),
                        selected: s.paletteId == p.id,
                        onSelected: (_) => ctrl.applyPalette(p),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ConfigSection(
            title: 'Cor primária (CFG-01a)',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SwatchPicker(
                  colors: AppSettings.swatchOptions,
                  selected: s.primary,
                  onSelected: ctrl.setPrimary,
                ),
              ),
            ],
          ),
          ConfigSection(
            title: 'Cor de destaque (CFG-01b)',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SwatchPicker(
                  colors: AppSettings.swatchOptions,
                  selected: s.accent,
                  onSelected: ctrl.setAccent,
                ),
              ),
            ],
          ),
          ConfigSection(
            title: 'Cor de fundo (CFG-01c)',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SwatchPicker(
                  colors: _backgrounds,
                  selected: s.background,
                  onSelected: ctrl.setBackground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
