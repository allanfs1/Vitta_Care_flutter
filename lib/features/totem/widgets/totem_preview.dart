import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/totem_config.dart';
import '../providers/totem_config_provider.dart';

const _kInk = Color(0xFF11151C);

/// Pré-visualização **ao vivo** do totem. Observa o [totemConfigProvider], então
/// ao personalizar a configuração a prévia atualiza em tempo real. Tem abas para
/// alternar entre a tela **Início** e a página **Agendar/Remarcar**.
class TotemPreview extends ConsumerStatefulWidget {
  const TotemPreview({super.key});

  @override
  ConsumerState<TotemPreview> createState() => _TotemPreviewState();
}

class _TotemPreviewState extends ConsumerState<TotemPreview> {
  int _tab = 0; // 0 = início, 1 = agendar

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(totemConfigProvider);
    final accent = cfg.accentColor;
    final now = TimeOfDay.now();
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.visibility_outlined, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text('PRÉVIA EM TEMPO REAL',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _seg('Início', 0, accent),
              _seg('Agendar', 1, accent),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 380,
                  height: 600,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(cfg.scale)),
                    child: _tab == 0
                        ? _welcome(cfg, accent, clock)
                        : _schedule(cfg, accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _seg(String label, int index, Color accent) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6)
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: sel ? accent : Colors.grey[600])),
        ),
      ),
    );
  }

  BoxDecoration _bg(TotemConfig cfg) => BoxDecoration(
        gradient: cfg.gradientBackground
            ? const RadialGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFEEF3F7)],
                center: Alignment.topLeft,
                radius: 1.5,
              )
            : null,
        color: cfg.gradientBackground ? null : const Color(0xFFF6F8FB),
      );

  // ----------------------------------------------------------------- início
  Widget _welcome(TotemConfig cfg, Color accent, String clock) {
    return Container(
      decoration: _bg(cfg),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chip(Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.health_and_safety, color: accent, size: 18),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(cfg.clinicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _kInk)),
                ),
              ])),
              if (cfg.showClock)
                _chip(Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule, color: accent, size: 14),
                  const SizedBox(width: 6),
                  Text(clock,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _kInk)),
                ])),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _logo(cfg, accent),
                const SizedBox(height: 16),
                Text(cfg.welcomeTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: _kInk)),
                const SizedBox(height: 6),
                Text(cfg.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500])),
                const SizedBox(height: 28),
                if (cfg.allowAgendar)
                  _button(cfg.agendarButtonLabel == 'AGENDAR'
                          ? 'AGENDAR CONSULTA'
                          : cfg.agendarButtonLabel,
                      Icons.calendar_month, accent,
                      filled: true),
                if (cfg.allowAgendar && cfg.allowRemarcar)
                  const SizedBox(height: 12),
                if (cfg.allowRemarcar)
                  _button(cfg.remarcarButtonLabel == 'REMARCAR'
                          ? 'REMARCAR CONSULTA'
                          : cfg.remarcarButtonLabel,
                      Icons.edit_calendar, accent,
                      filled: false),
                if (!cfg.allowAgendar && !cfg.allowRemarcar)
                  Text('Nenhum fluxo habilitado',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w700)),
                if (cfg.showTutorial || cfg.showTestPrint) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (cfg.showTutorial)
                        _footerLink('COMO USAR', Icons.help_outline, accent),
                      if (cfg.showTutorial && cfg.showTestPrint)
                        const SizedBox(width: 16),
                      if (cfg.showTestPrint)
                        _footerLink('TESTAR IMPRESSÃO', Icons.print_outlined,
                            Colors.grey[500]!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo(TotemConfig cfg, Color accent) {
    final url = cfg.logoUrl.trim();
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.favorite, color: accent, size: 32),
    );
    if (!url.startsWith('http') && !url.startsWith('data:')) return fallback;
    return Image.network(
      url,
      height: 72,
      fit: BoxFit.contain,
      loadingBuilder: (c, child, progress) => progress == null
          ? child
          : const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      errorBuilder: (_, _, _) => fallback,
    );
  }

  // -------------------------------------------------------- agendar/remarcar
  Widget _schedule(TotemConfig cfg, Color accent) {
    const sampleSpecialties = [
      'Cardiologia', 'Pediatria', 'Ortopedia', 'Dermatologia', 'Clínico'
    ];
    final suggestions =
        sampleSpecialties.take(cfg.maxSuggestions.clamp(1, 5)).toList();

    return Container(
      decoration: _bg(cfg),
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cfg.showStepper) _stepperDots(accent),
              Text(cfg.agendarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900, color: accent)),
              const SizedBox(height: 16),
              if (cfg.showSuggestions) ...[
                _miniLabel('MAIS PROCURADAS'),
                const SizedBox(height: 6),
                _chips(suggestions, accent, trending: true),
                const SizedBox(height: 14),
              ],
              _miniLabel('ESPECIALIDADE'),
              const SizedBox(height: 6),
              _chips(const ['Todos', 'Cardiologia', 'Pediatria'], accent),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniLabel('DATA'),
                  if (cfg.showCalendarButton)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_month, size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text('CALENDÁRIO',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accent)),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (cfg.showWeekStrip) _weekRow(accent),
              const SizedBox(height: 14),
              if (cfg.showDoctorFilter) ...[
                _miniLabel('FILTRAR POR MÉDICO'),
                const SizedBox(height: 6),
                _chips(const ['Todos', 'Dr. Ana', 'Dr. Beto'], accent),
                const SizedBox(height: 14),
              ],
              _miniLabel('HORÁRIO'),
              const SizedBox(height: 6),
              _slots(cfg),
              const SizedBox(height: 18),
              _fullButton(cfg.agendarButtonLabel, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepperDots(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++) ...[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: i <= 2 ? accent : Colors.grey.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('$i',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: i <= 2 ? Colors.white : Colors.grey)),
            ),
            if (i < 4)
              Expanded(
                child: Container(
                    height: 2,
                    color: i < 2
                        ? accent
                        : Colors.grey.withValues(alpha: 0.2)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chips(List<String> labels, Color accent, {bool trending = false}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: i == 0
                  ? accent.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: i == 0
                      ? accent
                      : (trending
                          ? accent.withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.2))),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (trending) ...[
                Icon(Icons.trending_up,
                    size: 13,
                    color: i == 0 ? accent : accent.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
              ],
              Text(labels[i],
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _kInk)),
            ]),
          ),
      ],
    );
  }

  Widget _weekRow(Color accent) {
    const wd = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: i == 0 ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: i == 0
                        ? accent
                        : Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Text(wd[i],
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: i == 0 ? Colors.white70 : Colors.grey[500])),
                const SizedBox(height: 2),
                Text('${10 + i}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: i == 0 ? Colors.white : _kInk)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _slots(TotemConfig cfg) {
    // Mesma regra do totem real: grade no passo da duração da consulta, da
    // abertura ao fechamento, pulando o almoço. A prévia mostra só os 12
    // primeiros horários (amostra).
    final step = cfg.appointmentDuration < 5 ? 5 : cfg.appointmentDuration;
    final times = <String>[];
    for (var m = cfg.openHour * 60;
        m + step <= cfg.closeHour * 60 && times.length < 12;
        m += step) {
      final h = m ~/ 60;
      if (cfg.lunchBreakEnabled &&
          h >= cfg.lunchStartHour &&
          h < cfg.lunchEndHour) {
        continue;
      }
      times.add(
          '${h.toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
    }
    if (times.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('Nenhum horário disponível.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      );
    }
    const palette = [
      Color(0xFF2E9E5B), Color(0xFF2E9E5B), Color(0xFFF5A623), Color(0xFFE53935)
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < times.length; i++)
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: palette[i % palette.length].withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: palette[i % palette.length].withValues(alpha: 0.8)),
            ),
            alignment: Alignment.center,
            child: Text(times[i],
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _kInk)),
          ),
      ],
    );
  }

  Widget _fullButton(String label, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }

  Widget _miniLabel(String t) => Text(t,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: Colors.grey[500]));

  // -------------------------------------------------------------- comuns
  Widget _chip(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );

  Widget _button(String label, IconData icon, Color accent,
      {required bool filled}) {
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        color: filled ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            filled ? null : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: filled ? Colors.white : _kInk, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: filled ? Colors.white : _kInk,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 10)),
      ],
    );
  }
}
