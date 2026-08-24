import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/app_settings.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';

/// CFG-02 — Tipografia (fonte, escala, peso, espaçamento) com preview.
class TipografiaScreen extends ConsumerWidget {
  const TipografiaScreen({super.key});

  static const _scales = <(double, String)>[
    (0.85, 'Muito pequena'),
    (0.92, 'Pequena'),
    (1.0, 'Normal'),
    (1.1, 'Grande'),
    (1.25, 'Muito grande'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final scales = _scales.map((e) => e.$1).toList();
    final found = _scales.indexWhere((e) => (e.$1 - s.fontScale).abs() < 0.01);
    final scaleIndex = found < 0 ? 2 : found;
    String labelAt(int i) => _scales[i].$2;

    return Scaffold(
      appBar: AppBar(title: const Text('Tipografia')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const ThemePreviewCard(),
          ConfigSection(
            title: 'Família de fontes (CFG-02a)',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final f in kFontFamilies)
                      ChoiceChip(
                        label: Text(f),
                        selected: s.fontFamily == f,
                        onSelected: (_) => ctrl.setFontFamily(f),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ConfigSection(
            title: 'Tamanho da fonte (CFG-02b)',
            subtitle: labelAt(scaleIndex),
            children: [
              Slider(
                value: scaleIndex.toDouble(),
                min: 0,
                max: (scales.length - 1).toDouble(),
                divisions: scales.length - 1,
                label: labelAt(scaleIndex),
                onChanged: (v) => ctrl.setFontScale(scales[v.round()]),
              ),
            ],
          ),
          ConfigSection(
            title: 'Peso e espaçamento',
            children: [
              ToggleSettingTile(
                title: 'Texto do corpo em negrito (CFG-02c)',
                subtitle: 'Headers permanecem sempre em destaque',
                value: s.bodyBold,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(bodyBold: v)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Espaçamento entre linhas (CFG-02d)'),
                    SegmentedChoice<double>(
                      options: const [1.2, 1.5, 1.8],
                      selected: s.lineHeight,
                      labelOf: (v) => v == 1.2
                          ? 'Compacto'
                          : v == 1.8
                              ? 'Espaçoso'
                              : 'Normal',
                      onSelected: (v) =>
                          ctrl.update((st) => st.copyWith(lineHeight: v)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
