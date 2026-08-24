import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';

/// CFG-05 — Notificações (push, e-mail, sons, não perturbe).
class NotificacoesScreen extends ConsumerWidget {
  const NotificacoesScreen({super.key});

  static const _pushLabels = {
    'novo_agendamento': 'Novo agendamento',
    'cancelamento': 'Cancelamento',
    'lembrete': 'Lembrete de consulta',
    'alerta_risco': 'Alerta de risco',
    'relatorio': 'Relatório gerado',
    'ticket': 'Ticket atribuído',
  };
  static const _emailLabels = {
    'resumo_diario': 'Resumo diário',
    'alertas_criticos': 'Alertas críticos',
    'relatorios_semanais': 'Relatórios semanais',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ConfigSection(
            title: 'Push (CFG-05a)',
            children: [
              for (final e in _pushLabels.entries)
                ToggleSettingTile(
                  title: e.value,
                  value: s.pushToggles[e.key] ?? true,
                  onChanged: (v) => ctrl.togglePush(e.key, v),
                ),
            ],
          ),
          ConfigSection(
            title: 'E-mail (CFG-05b)',
            children: [
              for (final e in _emailLabels.entries)
                ToggleSettingTile(
                  title: e.value,
                  value: s.emailToggles[e.key] ?? false,
                  onChanged: (v) => ctrl.toggleEmail(e.key, v),
                ),
            ],
          ),
          ConfigSection(
            title: 'Sons e silêncio',
            children: [
              ToggleSettingTile(
                title: 'Som de notificação (CFG-05c)',
                value: s.soundEnabled,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(soundEnabled: v)),
              ),
              OptionTile(
                title: 'Início do não perturbe (CFG-05d)',
                icon: Icons.bedtime_outlined,
                value: s.dndStart ?? '—',
                onTap: () => _pickTime(context, ctrl, isStart: true, current: s.dndStart),
              ),
              OptionTile(
                title: 'Fim do não perturbe',
                icon: Icons.wb_sunny_outlined,
                value: s.dndEnd ?? '—',
                onTap: () => _pickTime(context, ctrl, isStart: false, current: s.dndEnd),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    SettingsController ctrl, {
    required bool isStart,
    String? current,
  }) async {
    final parts = (current ?? '22:00').split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 22,
        minute: int.tryParse(parts.last) ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    ctrl.update((st) =>
        isStart ? st.copyWith(dndStart: value) : st.copyWith(dndEnd: value));
  }
}
