import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../models/totem_config.dart';
import '../models/totem_profile.dart';
import '../providers/totem_config_provider.dart';
import '../providers/totem_profiles_provider.dart';
import 'totem_preview.dart';

/// Painel de configuração completa do Totem (marca, interface, sugestões,
/// fluxos, regras de agendamento, sessão e funcionamento). Usado tanto pelo
/// acesso oculto no totem (long-press no logo) quanto pela página de
/// Configurações do sistema.
class TotemConfigPanel extends ConsumerStatefulWidget {
  const TotemConfigPanel({super.key});

  @override
  ConsumerState<TotemConfigPanel> createState() => _TotemConfigPanelState();
}

class _TotemConfigPanelState extends ConsumerState<TotemConfigPanel> {
  late final TextEditingController _clinic;
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _footer;
  late final TextEditingController _logo;
  late final TextEditingController _agTitle;
  late final TextEditingController _reTitle;
  late final TextEditingController _agBtn;
  late final TextEditingController _reBtn;
  late final TextEditingController _confLink;
  late final TextEditingController _pin;

  /// Cor da própria interface de configuração (segue o tema do app). A cor de
  /// destaque do totem NÃO é usada aqui — ela só afeta o totem e a prévia.
  late Color _chrome;

  static const _swatches = [
    0xFFFF3B30, 0xFF2563EB, 0xFF1FAA59, 0xFF7C3AED, 0xFFF59E0B, 0xFF0EA5E9,
  ];

  @override
  void initState() {
    super.initState();
    final c = ref.read(totemConfigProvider);
    _clinic = TextEditingController(text: c.clinicName);
    _title = TextEditingController(text: c.welcomeTitle);
    _subtitle = TextEditingController(text: c.welcomeSubtitle);
    _footer = TextEditingController(text: c.ticketFooter);
    _logo = TextEditingController(text: c.logoUrl);
    _agTitle = TextEditingController(text: c.agendarTitle);
    _reTitle = TextEditingController(text: c.remarcarTitle);
    _agBtn = TextEditingController(text: c.agendarButtonLabel);
    _reBtn = TextEditingController(text: c.remarcarButtonLabel);
    _confLink = TextEditingController(text: c.confirmationLink);
    _pin = TextEditingController(text: c.adminPin);
  }

  @override
  void dispose() {
    _clinic.dispose();
    _title.dispose();
    _subtitle.dispose();
    _footer.dispose();
    _logo.dispose();
    _agTitle.dispose();
    _reTitle.dispose();
    _agBtn.dispose();
    _reBtn.dispose();
    _confLink.dispose();
    _pin.dispose();
    super.dispose();
  }

  /// Aplica uma mutação sobre o estado ATUAL do provider (e não sobre o `cfg`
  /// capturado no closure do build) — evita que edições em sequência rápida
  /// revertam a alteração anterior (stale closure; ver totem_test.md F-1).
  void _set(TotemConfig Function(TotemConfig) mutate) {
    final c = mutate(ref.read(totemConfigProvider));
    ref.read(totemConfigProvider.notifier).update(c);
    // Com um perfil selecionado, salva a alteração automaticamente nele.
    final active = ref.read(activeTotemProfileProvider);
    if (active != null) {
      ref.read(totemProfilesProvider.notifier).save(active, c);
    }
  }

  /// Reflete uma config nos campos de texto (ao trocar de perfil / resetar).
  void _syncControllers(TotemConfig c) {
    _clinic.text = c.clinicName;
    _title.text = c.welcomeTitle;
    _subtitle.text = c.welcomeSubtitle;
    _footer.text = c.ticketFooter;
    _logo.text = c.logoUrl;
    _agTitle.text = c.agendarTitle;
    _reTitle.text = c.remarcarTitle;
    _agBtn.text = c.agendarButtonLabel;
    _reBtn.text = c.remarcarButtonLabel;
    _confLink.text = c.confirmationLink;
    _pin.text = c.adminPin;
  }

  /// Aplica um perfil: carrega a config (override salvo ou preset) no totem.
  void _applyProfile(TotemProfile p) {
    final cfg = ref.read(totemProfilesProvider.notifier).configFor(p.id);
    ref.read(totemConfigProvider.notifier).update(cfg);
    ref.read(activeTotemProfileProvider.notifier).state = p.id;
    _syncControllers(cfg);
  }

  String _profileLabel(String id) {
    for (final p in kTotemProfiles) {
      if (p.id == id) return p.label;
    }
    return id;
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  /// Especialidades disponíveis para a pré-seleção padrão.
  List<String> _specialtyOptions(TotemConfig cfg) {
    final all = <String>{};
    for (final d in ref.watch(clinicDoctorsProvider).where((d) => d.active)) {
      all.addAll(d.specialties);
    }
    final list = ['Todos', ...(all.toList()..sort())];
    if (!list.contains(cfg.defaultSpecialty)) list.add(cfg.defaultSpecialty);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(totemConfigProvider);
    _chrome = Theme.of(context).colorScheme.primary;
    final active = ref.watch(activeTotemProfileProvider);
    final overrides = ref.watch(totemProfilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração do Totem'),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(totemConfigProvider.notifier).reset();
              ref.read(activeTotemProfileProvider.notifier).state = null;
              _syncControllers(const TotemConfig());
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Padrões'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final controls = ListView(
            padding: const EdgeInsets.all(16),
            children: [
          _section('PERFIS'),
          Text(
              'Aplique um preset de unidade e ajuste o que precisar. '
              'Com um perfil selecionado, as mudanças são salvas '
              'automaticamente nele.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in kTotemProfiles)
                ChoiceChip(
                  avatar: Icon(p.icon,
                      size: 16, color: active == p.id ? _chrome : null),
                  label: Text(p.label),
                  selected: active == p.id,
                  selectedColor: _chrome.withValues(alpha: 0.15),
                  side: active == p.id
                      ? BorderSide(color: _chrome, width: 1.5)
                      : null,
                  onSelected: (_) => _applyProfile(p),
                ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.cloud_done_outlined, size: 15, color: _chrome),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    overrides.containsKey(active)
                        ? 'Alterações salvas automaticamente em '
                            '"${_profileLabel(active)}".'
                        : 'As alterações serão salvas automaticamente em '
                            '"${_profileLabel(active)}".',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _chrome),
                  ),
                ),
                if (overrides.containsKey(active))
                  TextButton.icon(
                    onPressed: () {
                      ref.read(totemProfilesProvider.notifier).restore(active);
                      _applyProfile(kTotemProfiles.firstWhere(
                          (p) => p.id == active,
                          orElse: () => kTotemProfiles.first));
                      _snack('Perfil "${_profileLabel(active)}" '
                          'restaurado ao padrão.');
                    },
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Restaurar'),
                  ),
              ],
            ),
          ],

          _section('MARCA E TEXTOS'),
          _textField('Nome da unidade', _clinic,
              (v) => _set((cur) => cur.copyWith(clinicName: v))),
          _textField('Título de boas-vindas', _title,
              (v) => _set((cur) => cur.copyWith(welcomeTitle: v))),
          _textField('Subtítulo', _subtitle,
              (v) => _set((cur) => cur.copyWith(welcomeSubtitle: v))),
          _logoField(cfg),
          const SizedBox(height: 8),
          const Text('Cor de destaque',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          _colorRow(cfg),

          _section('TELA INICIAL'),
          _switch('Botão "Como usar o totem"', cfg.showTutorial,
              (v) => _set((cur) => cur.copyWith(showTutorial: v))),
          _switch('Botão "Testar impressão"', cfg.showTestPrint,
              (v) => _set((cur) => cur.copyWith(showTestPrint: v))),

          _section('INTERFACE'),
          _switch('Relógio no topo', cfg.showClock,
              (v) => _set((cur) => cur.copyWith(showClock: v))),
          _switch('Cartão do médico', cfg.showDoctorCard,
              (v) => _set((cur) => cur.copyWith(showDoctorCard: v))),
          _switch('Indicador de ocupação (overbooking)', cfg.showOccupancy,
              (v) => _set((cur) => cur.copyWith(showOccupancy: v))),
          _switch('Fundo com gradiente', cfg.gradientBackground,
              (v) => _set((cur) => cur.copyWith(gradientBackground: v))),
          _slider('Tamanho da fonte', cfg.scale, 0.8, 1.4,
              '${(cfg.scale * 100).round()}%',
              (v) => _set((cur) => cur.copyWith(scale: v))),

          _section('SUGESTÕES'),
          _switch('Mostrar "Mais procuradas"', cfg.showSuggestions,
              (v) => _set((cur) => cur.copyWith(showSuggestions: v))),
          if (cfg.showSuggestions)
            _slider('Qtd. de sugestões', cfg.maxSuggestions.toDouble(), 1, 8,
                '${cfg.maxSuggestions}',
                (v) => _set((cur) => cur.copyWith(maxSuggestions: v.round())),
                divisions: 7),

          _section('AGENDAR / REMARCAR'),
          _textField('Título "Agendar"', _agTitle,
              (v) => _set((cur) => cur.copyWith(agendarTitle: v))),
          _textField('Título "Remarcar"', _reTitle,
              (v) => _set((cur) => cur.copyWith(remarcarTitle: v))),
          _textField('Rótulo do botão (agendar)', _agBtn,
              (v) => _set((cur) => cur.copyWith(agendarButtonLabel: v))),
          _textField('Rótulo do botão (remarcar)', _reBtn,
              (v) => _set((cur) => cur.copyWith(remarcarButtonLabel: v))),
          _switch('Indicador de progresso (passos)', cfg.showStepper,
              (v) => _set((cur) => cur.copyWith(showStepper: v))),
          _switch('Faixa de dias da semana', cfg.showWeekStrip,
              (v) => _set((cur) => cur.copyWith(showWeekStrip: v))),
          _switch('Botão "Abrir calendário"', cfg.showCalendarButton,
              (v) => _set((cur) => cur.copyWith(showCalendarButton: v))),
          _switch('Filtro por médico', cfg.showDoctorFilter,
              (v) => _set((cur) => cur.copyWith(showDoctorFilter: v))),

          _section('FLUXOS'),
          _switch('Permitir "Agendar consulta"', cfg.allowAgendar,
              (v) => _set((cur) => cur.copyWith(allowAgendar: v))),
          _switch('Permitir "Remarcar consulta"', cfg.allowRemarcar,
              (v) => _set((cur) => cur.copyWith(allowRemarcar: v))),
          _switch('Permitir agendar sem cadastro', cfg.allowGuestScheduling,
              (v) => _set((cur) => cur.copyWith(allowGuestScheduling: v))),
          _switch('Exigir telefone no cadastro', cfg.requirePhone,
              (v) => _set((cur) => cur.copyWith(requirePhone: v))),
          _switch('Botão de imprimir comprovante', cfg.printEnabled,
              (v) => _set((cur) => cur.copyWith(printEnabled: v))),
          _textField('Rodapé do comprovante', _footer,
              (v) => _set((cur) => cur.copyWith(ticketFooter: v))),
          _switch('Confirmação por WhatsApp (Z-API)', cfg.confirmViaWhatsapp,
              (v) => _set((cur) => cur.copyWith(confirmViaWhatsapp: v))),
          if (cfg.confirmViaWhatsapp)
            _textField('Link de confirmação (WhatsApp)', _confLink,
                (v) => _set((cur) => cur.copyWith(confirmationLink: v))),

          _section('REGRAS DE AGENDAMENTO'),
          _dropdown('Especialidade padrão', cfg.defaultSpecialty,
              _specialtyOptions(cfg),
              (v) => _set((cur) => cur.copyWith(defaultSpecialty: v))),
          _slider('Duração da consulta', cfg.appointmentDuration.toDouble(), 15,
              60, '${cfg.appointmentDuration} min',
              (v) => _set((cur) => cur.copyWith(appointmentDuration: v.round())),
              divisions: 9),
          _slider('Agendar até', cfg.maxDaysAhead.toDouble(), 7, 365,
              '${cfg.maxDaysAhead} dias',
              (v) => _set((cur) => cur.copyWith(maxDaysAhead: v.round()))),
          _slider('Antecedência no comprovante', cfg.arrivalMinutes.toDouble(),
              0, 60, '${cfg.arrivalMinutes} min',
              (v) => _set((cur) => cur.copyWith(arrivalMinutes: v.round())),
              divisions: 12),
          _slider(
              'Máx. consultas por dia (por paciente)',
              cfg.maxPerDay.toDouble(),
              0,
              5,
              cfg.maxPerDay == 0 ? 'Ilimitado' : '${cfg.maxPerDay}',
              (v) => _set((cur) => cur.copyWith(maxPerDay: v.round())),
              divisions: 5),
          _slider(
              'Máx. consultas ativas (por paciente)',
              cfg.maxActivePerPatient.toDouble(),
              0,
              10,
              cfg.maxActivePerPatient == 0
                  ? 'Ilimitado'
                  : '${cfg.maxActivePerPatient}',
              (v) => _set((cur) => cur.copyWith(maxActivePerPatient: v.round())),
              divisions: 10),

          _section('SESSÃO'),
          _slider('Tempo de inatividade', cfg.sessionTimeout.toDouble(), 30, 300,
              '${cfg.sessionTimeout}s',
              (v) => _set((cur) => cur.copyWith(sessionTimeout: v.round())),
              divisions: 27),
          _slider('Aviso antes de expirar', cfg.warningSeconds.toDouble(), 5, 30,
              '${cfg.warningSeconds}s',
              (v) => _set((cur) => cur.copyWith(warningSeconds: v.round())),
              divisions: 25),
          _slider('Retorno automático (sucesso)',
              cfg.successAutoReturn.toDouble(), 5, 60, '${cfg.successAutoReturn}s',
              (v) => _set((cur) => cur.copyWith(successAutoReturn: v.round())),
              divisions: 11),

          _section('SEGURANÇA'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              maxLength: 8,
              onChanged: (v) => _set((cur) =>
                  cur.copyWith(adminPin: v.replaceAll(RegExp(r'\D'), ''))),
              decoration: const InputDecoration(
                labelText: 'PIN do painel (vazio = sem PIN)',
                helperText: 'Com um PIN definido, o toque longo no logo do '
                    'totem pede o código antes de abrir esta configuração.',
                helperMaxLines: 2,
                counterText: '',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          _section('FUNCIONAMENTO'),
          _stepper('Abre às', cfg.openHour, 0, 12,
              (v) => _set((cur) => cur.copyWith(openHour: v)), suffix: 'h'),
          _stepper('Fecha às (seg–sex)', cfg.closeHour, 13, 24,
              (v) => _set((cur) => cur.copyWith(closeHour: v)), suffix: 'h'),
          _switch('Abre aos sábados', cfg.openSaturday,
              (v) => _set((cur) => cur.copyWith(openSaturday: v))),
          if (cfg.openSaturday)
            _stepper('Fecha aos sábados', cfg.saturdayCloseHour, 8, 24,
                (v) => _set((cur) => cur.copyWith(saturdayCloseHour: v)), suffix: 'h'),
          _switch('Abre aos domingos', cfg.openSunday,
              (v) => _set((cur) => cur.copyWith(openSunday: v))),
          _switch('Intervalo de almoço (bloqueia horários)',
              cfg.lunchBreakEnabled,
              (v) => _set((cur) => cur.copyWith(lunchBreakEnabled: v))),
          if (cfg.lunchBreakEnabled) ...[
            _stepper('Almoço começa', cfg.lunchStartHour, 10, 15, (v) {
              // Mantém o fim sempre depois do início (senão não bloqueia nada).
              _set((cur) => cur.copyWith(
                  lunchStartHour: v,
                  lunchEndHour:
                      cur.lunchEndHour <= v ? v + 1 : cur.lunchEndHour));
            }, suffix: 'h'),
            _stepper('Almoço termina', cfg.lunchEndHour, cfg.lunchStartHour + 1,
                16, (v) => _set((cur) => cur.copyWith(lunchEndHour: v)), suffix: 'h'),
          ],
          const SizedBox(height: 24),
            ],
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: controls),
                const VerticalDivider(width: 1),
                const SizedBox(
                  width: 400,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: TotemPreview(),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Container(
                height: 280,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black.withValues(alpha: 0.03),
                child: const TotemPreview(),
              ),
              const Divider(height: 1),
              Expanded(child: controls),
            ],
          );
        },
      ),
    );
  }

  // ---- pieces
  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t,
            style: TextStyle(
                color: _chrome,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1)),
      );

  Widget _textField(
      String label, TextEditingController c, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  /// Campo de URL do logo com miniatura ao vivo (loading / ok / erro). Deixa
  /// claro que o valor é salvo e se o link realmente carrega (na web, imagens
  /// sem CORS não aparecem).
  Widget _logoField(TotemConfig cfg) {
    final url = cfg.logoUrl.trim();
    final valid = url.startsWith('http') || url.startsWith('data:');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: !valid
                ? Icon(Icons.image_outlined, color: Colors.grey[400])
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))),
                    errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined,
                        color: Colors.grey[400]),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _logo,
              onChanged: (v) => _set((cur) => cur.copyWith(logoUrl: v)),
              decoration: InputDecoration(
                labelText: 'URL do logo (vazio = ícone padrão)',
                helperText: 'Link https direto p/ PNG/JPG. Imagens sem CORS '
                    'podem não carregar na web.',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: url.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Limpar',
                        onPressed: () {
                          _logo.clear();
                          _set((cur) => cur.copyWith(logoUrl: ''));
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _switch(String label, bool value, void Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      activeThumbColor: _chrome,
      onChanged: onChanged,
    );
  }

  Widget _slider(String label, double value, double min, double max,
      String display, void Function(double) onChanged,
      {int? divisions}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(display, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: _chrome,
        onChanged: onChanged,
      ),
    ]);
  }

  Widget _stepper(String label, int value, int min, int max,
      void Function(int) onChanged,
      {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null),
        Text('$value$suffix',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null),
      ]),
    );
  }

  Widget _colorRow(TotemConfig cfg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 10,
        children: [
          for (final c in _swatches)
            GestureDetector(
              onTap: () => _set((cur) => cur.copyWith(accent: c)),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: cfg.accent == c ? Colors.black : Colors.transparent,
                      width: 3),
                ),
                child: cfg.accent == c
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
