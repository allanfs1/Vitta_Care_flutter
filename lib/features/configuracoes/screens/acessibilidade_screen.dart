import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/app_settings.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';

/// CFG-04 — Acessibilidade.
class AcessibilidadeScreen extends ConsumerWidget {
  const AcessibilidadeScreen({super.key});

  static const _cbLabels = {
    ColorBlindFilter.none: 'Nenhum',
    ColorBlindFilter.protanopia: 'Protanopia',
    ColorBlindFilter.deuteranopia: 'Deuteranopia',
    ColorBlindFilter.tritanopia: 'Tritanopia',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Acessibilidade')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ConfigSection(
            title: 'Visão',
            children: [
              ToggleSettingTile(
                title: 'Alto contraste (CFG-04a)',
                subtitle: 'Bordas fortes e cores mais saturadas',
                icon: Icons.contrast,
                value: s.highContrast,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(highContrast: v)),
              ),
              ToggleSettingTile(
                title: 'Texto ampliado (CFG-04b)',
                subtitle: 'Escala mínima de 1,3× para leitura',
                icon: Icons.format_size,
                value: s.largerTouchTargets,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(largerTouchTargets: v)),
              ),
            ],
          ),
          ConfigSection(
            title: 'Daltonismo (CFG-04e)',
            subtitle: 'Aplica filtro de cor em toda a interface',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SegmentedChoice<ColorBlindFilter>(
                  options: ColorBlindFilter.values,
                  selected: s.colorBlindFilter,
                  labelOf: (f) => _cbLabels[f]!,
                  onSelected: (f) =>
                      ctrl.update((st) => st.copyWith(colorBlindFilter: f)),
                ),
              ),
            ],
          ),
          ConfigSection(
            title: 'Movimento e interação',
            children: [
              ToggleSettingTile(
                title: 'Reduzir movimento (CFG-04d)',
                subtitle: 'Desativa transições e micro-animações',
                icon: Icons.motion_photos_off,
                value: s.reduceMotion,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(reduceMotion: v)),
              ),
              ToggleSettingTile(
                title: 'Feedback tátil (CFG-04g)',
                subtitle: 'Vibração ao tocar em ações',
                icon: Icons.vibration,
                value: s.hapticFeedback,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(hapticFeedback: v)),
              ),
              ToggleSettingTile(
                title: 'Rótulos para leitor de tela (CFG-04c)',
                subtitle: 'Descrições adicionais em gráficos e ícones',
                icon: Icons.record_voice_over,
                value: s.screenReaderLabels,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(screenReaderLabels: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
