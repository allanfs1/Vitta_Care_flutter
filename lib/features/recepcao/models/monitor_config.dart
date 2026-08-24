import 'package:flutter/material.dart';

/// Densidade do monitor: simples (só a chamada), avançado (com painéis) ou
/// lista (painel de chamadas que rola até a chamada atual).
enum MonitorDensity { simples, avancado, lista }

/// Orientação do arranjo: horizontal (paisagem) ou vertical (retrato).
enum MonitorOrientation { horizontal, vertical }

/// Tema visual do monitor.
enum MonitorThemeMode { escuro, claro, contraste }

/// Forma de exibição do nome do paciente (privacidade / LGPD).
enum NameDisplay { completo, primeiroNome, mascarado, iniciais }

extension NameDisplayX on NameDisplay {
  String get label => switch (this) {
        NameDisplay.completo => 'Completo',
        NameDisplay.primeiroNome => 'Primeiro nome',
        NameDisplay.mascarado => 'Mascarado (LGPD)',
        NameDisplay.iniciais => 'Iniciais',
      };
}

/// Paleta de cores derivada do tema do monitor.
class MonitorPalette {
  const MonitorPalette({
    required this.bg,
    required this.panel,
    required this.panelAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  final Color bg;
  final Color panel;
  final Color panelAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
}

/// Configuração completa do Monitor da Recepção.
class MonitorConfig {
  const MonitorConfig({
    this.density = MonitorDensity.avancado,
    this.orientation = MonitorOrientation.horizontal,
    this.themeMode = MonitorThemeMode.escuro,
    this.accent = const Color(0xFFFF3B30),
    this.scale = 1.0,
    this.gradient = false,
    this.title = 'MONITOR DA RECEPÇÃO',
    this.showPhoto = true,
    this.nameDisplay = NameDisplay.completo,
    this.showLocal = true,
    this.showAttendant = true,
    this.showRiskBadge = true,
    this.showWaitTime = true,
    this.showClock = true,
    this.useRiskAsAccent = true,
    this.sound = true,
    this.voiceRate = 0.95,
    this.voicePitch = 1.0,
    this.announceRepeat = 1,
    this.pulse = true,
    this.autoCall = true,
    this.autoScroll = true,
    this.autoAdvance = false,
    this.autoAdvanceSeconds = 15,
    this.pauseWhenEmpty = true,
    this.warnBeforeAdvance = true,
  });

  // Layout
  final MonitorDensity density;
  final MonitorOrientation orientation;

  // Aparência
  final MonitorThemeMode themeMode;
  final Color accent;
  final double scale; // escala de fonte (0.8–1.8)
  final bool gradient;
  final String title;

  // Conteúdo / privacidade
  final bool showPhoto;
  final NameDisplay nameDisplay;
  final bool showLocal;
  final bool showAttendant;
  final bool showRiskBadge;
  final bool showWaitTime;
  final bool showClock;

  /// Usa a cor de risco como destaque do cartão (senão usa [accent]).
  final bool useRiskAsAccent;

  // Voz / comportamento
  final bool sound;
  final double voiceRate; // 0.5–1.3
  final double voicePitch; // 0.7–1.4
  final int announceRepeat; // 1–3
  final bool pulse;

  /// Chamada automática de agendados quando chega o horário.
  final bool autoCall;
  final bool autoScroll;

  /// Avança a chamada automaticamente em intervalo fixo ("chamar próximo").
  final bool autoAdvance;

  /// Intervalo (segundos) entre chamadas automáticas no modo auto-avanço.
  final int autoAdvanceSeconds;

  /// Pausa o auto-avanço enquanto não houver ninguém na fila.
  final bool pauseWhenEmpty;

  /// Emite aviso sonoro/visual nos segundos finais antes da troca automática.
  final bool warnBeforeAdvance;

  MonitorPalette get palette => switch (themeMode) {
        MonitorThemeMode.escuro => const MonitorPalette(
            bg: Color(0xFF0E1116),
            panel: Color(0xFF161B22),
            panelAlt: Color(0xFF21262D),
            textPrimary: Colors.white,
            textSecondary: Colors.white70,
            border: Color(0xFF30363D),
          ),
        MonitorThemeMode.claro => const MonitorPalette(
            bg: Color(0xFFEDEFF3),
            panel: Colors.white,
            panelAlt: Color(0xFFF1F3F6),
            textPrimary: Color(0xFF11151C),
            textSecondary: Color(0xFF5B6471),
            border: Color(0xFFD8DCE3),
          ),
        MonitorThemeMode.contraste => const MonitorPalette(
            bg: Colors.black,
            panel: Color(0xFF0A0A0A),
            panelAlt: Color(0xFF161616),
            textPrimary: Color(0xFFFFFF00),
            textSecondary: Colors.white,
            border: Color(0xFFFFFF00),
          ),
      };

  /// Aplica a forma de exibição do nome (privacidade).
  String formatName(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '—';
    switch (nameDisplay) {
      case NameDisplay.completo:
        return name;
      case NameDisplay.primeiroNome:
        return parts.first;
      case NameDisplay.iniciais:
        return parts.map((p) => p[0].toUpperCase()).join('');
      case NameDisplay.mascarado:
        final first = parts.first;
        final rest = parts.skip(1).map((p) => '${p[0].toUpperCase()}.');
        return [first, ...rest].join(' ');
    }
  }

  MonitorConfig copyWith({
    MonitorDensity? density,
    MonitorOrientation? orientation,
    MonitorThemeMode? themeMode,
    Color? accent,
    double? scale,
    bool? gradient,
    String? title,
    bool? showPhoto,
    NameDisplay? nameDisplay,
    bool? showLocal,
    bool? showAttendant,
    bool? showRiskBadge,
    bool? showWaitTime,
    bool? showClock,
    bool? useRiskAsAccent,
    bool? sound,
    double? voiceRate,
    double? voicePitch,
    int? announceRepeat,
    bool? pulse,
    bool? autoCall,
    bool? autoScroll,
    bool? autoAdvance,
    int? autoAdvanceSeconds,
    bool? pauseWhenEmpty,
    bool? warnBeforeAdvance,
  }) {
    return MonitorConfig(
      density: density ?? this.density,
      orientation: orientation ?? this.orientation,
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      scale: scale ?? this.scale,
      gradient: gradient ?? this.gradient,
      title: title ?? this.title,
      showPhoto: showPhoto ?? this.showPhoto,
      nameDisplay: nameDisplay ?? this.nameDisplay,
      showLocal: showLocal ?? this.showLocal,
      showAttendant: showAttendant ?? this.showAttendant,
      showRiskBadge: showRiskBadge ?? this.showRiskBadge,
      showWaitTime: showWaitTime ?? this.showWaitTime,
      showClock: showClock ?? this.showClock,
      useRiskAsAccent: useRiskAsAccent ?? this.useRiskAsAccent,
      sound: sound ?? this.sound,
      voiceRate: voiceRate ?? this.voiceRate,
      voicePitch: voicePitch ?? this.voicePitch,
      announceRepeat: announceRepeat ?? this.announceRepeat,
      pulse: pulse ?? this.pulse,
      autoCall: autoCall ?? this.autoCall,
      autoScroll: autoScroll ?? this.autoScroll,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      autoAdvanceSeconds: autoAdvanceSeconds ?? this.autoAdvanceSeconds,
      pauseWhenEmpty: pauseWhenEmpty ?? this.pauseWhenEmpty,
      warnBeforeAdvance: warnBeforeAdvance ?? this.warnBeforeAdvance,
    );
  }

  Map<String, dynamic> toJson() => {
        'density': density.index,
        'orientation': orientation.index,
        'themeMode': themeMode.index,
        'accent': accent.toARGB32(),
        'scale': scale,
        'gradient': gradient,
        'title': title,
        'showPhoto': showPhoto,
        'nameDisplay': nameDisplay.index,
        'showLocal': showLocal,
        'showAttendant': showAttendant,
        'showRiskBadge': showRiskBadge,
        'showWaitTime': showWaitTime,
        'showClock': showClock,
        'useRiskAsAccent': useRiskAsAccent,
        'sound': sound,
        'voiceRate': voiceRate,
        'voicePitch': voicePitch,
        'announceRepeat': announceRepeat,
        'pulse': pulse,
        'autoCall': autoCall,
        'autoScroll': autoScroll,
        'autoAdvance': autoAdvance,
        'autoAdvanceSeconds': autoAdvanceSeconds,
        'pauseWhenEmpty': pauseWhenEmpty,
        'warnBeforeAdvance': warnBeforeAdvance,
      };

  factory MonitorConfig.fromJson(Map<String, dynamic> j) {
    T pick<T>(List<T> values, Object? idx, T fallback) {
      if (idx is int && idx >= 0 && idx < values.length) return values[idx];
      return fallback;
    }

    const def = MonitorConfig();
    return MonitorConfig(
      density: pick(MonitorDensity.values, j['density'], def.density),
      orientation:
          pick(MonitorOrientation.values, j['orientation'], def.orientation),
      themeMode: pick(MonitorThemeMode.values, j['themeMode'], def.themeMode),
      accent: j['accent'] is int ? Color(j['accent'] as int) : def.accent,
      scale: (j['scale'] as num?)?.toDouble() ?? def.scale,
      gradient: j['gradient'] as bool? ?? def.gradient,
      title: j['title'] as String? ?? def.title,
      showPhoto: j['showPhoto'] as bool? ?? def.showPhoto,
      nameDisplay:
          pick(NameDisplay.values, j['nameDisplay'], def.nameDisplay),
      showLocal: j['showLocal'] as bool? ?? def.showLocal,
      showAttendant: j['showAttendant'] as bool? ?? def.showAttendant,
      showRiskBadge: j['showRiskBadge'] as bool? ?? def.showRiskBadge,
      showWaitTime: j['showWaitTime'] as bool? ?? def.showWaitTime,
      showClock: j['showClock'] as bool? ?? def.showClock,
      useRiskAsAccent: j['useRiskAsAccent'] as bool? ?? def.useRiskAsAccent,
      sound: j['sound'] as bool? ?? def.sound,
      voiceRate: (j['voiceRate'] as num?)?.toDouble() ?? def.voiceRate,
      voicePitch: (j['voicePitch'] as num?)?.toDouble() ?? def.voicePitch,
      announceRepeat: j['announceRepeat'] as int? ?? def.announceRepeat,
      pulse: j['pulse'] as bool? ?? def.pulse,
      autoCall: j['autoCall'] as bool? ?? def.autoCall,
      autoScroll: j['autoScroll'] as bool? ?? def.autoScroll,
      autoAdvance: j['autoAdvance'] as bool? ?? def.autoAdvance,
      autoAdvanceSeconds:
          j['autoAdvanceSeconds'] as int? ?? def.autoAdvanceSeconds,
      pauseWhenEmpty: j['pauseWhenEmpty'] as bool? ?? def.pauseWhenEmpty,
      warnBeforeAdvance:
          j['warnBeforeAdvance'] as bool? ?? def.warnBeforeAdvance,
    );
  }
}
