import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';

/// CFG-03 — Tema (modo, contraste, cantos, animações).
class TemaScreen extends ConsumerWidget {
  const TemaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const ThemePreviewCard(),
          ConfigSection(
            title: 'Modo do tema (CFG-03a)',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Claro')),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Escuro')),
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('Auto')),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => ctrl.setThemeMode(v.first),
                ),
              ),
            ],
          ),
          ConfigSection(
            title: 'Contraste (CFG-03b)',
            subtitle: s.contrastLevel < 0.33
                ? 'Suave'
                : s.contrastLevel < 0.66
                    ? 'Normal'
                    : 'Alto contraste',
            children: [
              Slider(
                value: s.contrastLevel,
                divisions: 2,
                label: s.contrastLevel < 0.33
                    ? 'Suave'
                    : s.contrastLevel < 0.66
                        ? 'Normal'
                        : 'Alto',
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(contrastLevel: v)),
              ),
            ],
          ),
          ConfigSection(
            title: 'Cantos dos componentes (CFG-03c)',
            subtitle: '${s.borderRadius.round()}px',
            children: [
              Slider(
                value: s.borderRadius,
                min: 0,
                max: 24,
                divisions: 3,
                label: switch (s.borderRadius.round()) {
                  0 => 'Quadrado',
                  8 => 'Suave',
                  24 => 'Pílula',
                  _ => 'Arredondado',
                },
                onChanged: (v) => ctrl.setBorderRadius(v),
              ),
            ],
          ),
          ConfigSection(
            title: 'Animações',
            children: [
              ToggleSettingTile(
                title: 'Micro-animações e transições (CFG-03d)',
                subtitle: 'Desligue em dispositivos mais lentos',
                value: s.animationsEnabled,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(animationsEnabled: v)),
              ),
              ToggleSettingTile(
                title: 'Usar tema da clínica (CFG-03e)',
                subtitle: 'Aplica as cores institucionais definidas no plano',
                value: s.useClinicTheme,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(useClinicTheme: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
