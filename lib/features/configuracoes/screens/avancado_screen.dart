import 'package:flutter/material.dart';

import '../../../core/i18n/idioma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/app_settings.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';

/// CFG-07 — Configurações Avançadas (idioma, formatos, fuso, dev, sobre, reset).
class AvancadoScreen extends ConsumerStatefulWidget {
  const AvancadoScreen({super.key});

  @override
  ConsumerState<AvancadoScreen> createState() => _AvancadoScreenState();
}

class _AvancadoScreenState extends ConsumerState<AvancadoScreen> {
  static const _version = '1.0.0 (build 1)';
  int _versionTaps = 0;

  /// Derivado de [Idioma] em vez de repetido aqui: acrescentar um idioma é um
  /// item de enum, e não uma edição em dois lugares que é fácil deixar pela
  /// metade — foi assim que a tela ficou oferecendo três idiomas enquanto o
  /// app só tinha strings em português.
  static Map<String, String> get _locales => {
        for (final i in Idioma.values) i.chave: '${i.bandeira}  ${i.rotulo}',
      };
  static const _dateFormats = {
    'dd/MM/yyyy': 'DD/MM/AAAA',
    'MM/dd/yyyy': 'MM/DD/AAAA',
    'yyyy-MM-dd': 'AAAA-MM-DD',
  };
  static const _timezones = [
    'America/Sao_Paulo',
    'America/Manaus',
    'America/Bahia',
    'UTC',
  ];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Avançado')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ConfigSection(
            title: 'Interface da Home',
            children: [
              ToggleSettingTile(
                title: 'Carrossel de Agendamentos',
                subtitle: 'Exibe os próximos atendimentos no topo da tela inicial',
                icon: Icons.view_carousel_outlined,
                value: s.showNextAppointmentsCarousel,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(showNextAppointmentsCarousel: v)),
              ),
            ],
          ),
          ConfigSection(
            title: 'Idioma e região',
            children: [
              OptionTile(
                title: 'Idioma',
                icon: Icons.translate,
                value: _locales[s.locale] ?? s.locale,
                onTap: () => _pickFromMap(
                  context,
                  title: 'Idioma',
                  options: _locales,
                  current: s.locale,
                  onSelected: (v) => ctrl.update((st) => st.copyWith(locale: v)),
                ),
              ),
              OptionTile(
                title: 'Formato de data (CFG-07b)',
                icon: Icons.calendar_today_outlined,
                value: _dateFormats[s.dateFormat] ?? s.dateFormat,
                onTap: () => _pickFromMap(
                  context,
                  title: 'Formato de data',
                  options: _dateFormats,
                  current: s.dateFormat,
                  onSelected: (v) =>
                      ctrl.update((st) => st.copyWith(dateFormat: v)),
                ),
              ),
              ToggleSettingTile(
                title: 'Usar formato 24h (CFG-07c)',
                subtitle: s.use24HourFormat ? '14:30' : '02:30 PM',
                icon: Icons.schedule,
                value: s.use24HourFormat,
                onChanged: (v) =>
                    ctrl.update((st) => st.copyWith(use24HourFormat: v)),
              ),
              OptionTile(
                title: 'Fuso horário (CFG-07d)',
                icon: Icons.public,
                value: s.timezone,
                onTap: () => _pickFromList(
                  context,
                  title: 'Fuso horário',
                  options: _timezones,
                  current: s.timezone,
                  onSelected: (v) =>
                      ctrl.update((st) => st.copyWith(timezone: v)),
                ),
              ),
            ],
          ),
          ConfigSection(
            title: 'Desenvolvedor',
            children: [
              if (s.developerMode)
                ToggleSettingTile(
                  title: 'Modo desenvolvedor (CFG-07e)',
                  subtitle: 'Logs, indicadores de performance e inspetor',
                  icon: Icons.developer_mode,
                  value: s.developerMode,
                  onChanged: (v) =>
                      ctrl.update((st) => st.copyWith(developerMode: v)),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Toque 7× na versão do app para ativar o modo desenvolvedor.',
                  ),
                ),
            ],
          ),
          ConfigSection(
            title: 'Sobre o aplicativo (CFG-07f)',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Versão'),
                trailing: Text(_version),
                onTap: _onVersionTap,
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Termos de Uso'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Política de Privacidade'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: const Text('Licenças open source'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                    context: context, applicationName: 'Vitta'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _confirmRestore(context, ctrl),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restaurar padrões (CFG-07g)'),
          ),
        ],
      ),
    );
  }

  void _onVersionTap() {
    final s = ref.read(settingsProvider);
    if (s.developerMode) return;
    setState(() => _versionTaps++);
    if (_versionTaps >= 7) {
      ref.read(settingsProvider.notifier)
          .update((st) => st.copyWith(developerMode: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modo desenvolvedor ativado.')),
      );
    } else if (_versionTaps >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 600),
          content: Text(
              'Faltam ${7 - _versionTaps} toques para o modo desenvolvedor.'),
        ),
      );
    }
  }

  Future<void> _confirmRestore(BuildContext context, SettingsController ctrl) async {
    final clinic = ref.read(selectedClinicProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar padrões'),
        content: Text(
            'Todas as configurações visuais voltarão ao padrão da unidade '
            '${clinic.type.label}. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok == true) {
      ctrl.restoreDefaults(defaults: AppSettings.defaultsFor(clinic.type));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações restauradas.')),
        );
      }
    }
  }

  Future<void> _pickFromMap(
    BuildContext context, {
    required String title,
    required Map<String, String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) =>
      _pickFromList(
        context,
        title: title,
        options: options.keys.toList(),
        current: current,
        onSelected: onSelected,
        labelOf: (k) => options[k] ?? k,
      );

  Future<void> _pickFromList(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
    String Function(String)? labelOf,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final o in options)
              ListTile(
                title: Text(labelOf?.call(o) ?? o),
                trailing: o == current
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, o),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }
}
