import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';

/// Paletas pré-definidas (CFG-01d).
class AppPalette {
  const AppPalette(this.id, this.label, this.primary, this.accent, this.background);
  final String id;
  final String label;
  final Color primary;
  final Color accent;
  final Color background;

  static const institucional = AppPalette('institucional', 'Institucional',
      Color(0xFF1B53D0), Color(0xFF2E9E8F), Color(0xFFF4F6FA));
  static const urgencia = AppPalette('urgencia', 'Urgência',
      Color(0xFFC62828), Color(0xFFC77700), Color(0xFFF7F4F4));
  static const premium = AppPalette('premium', 'Premium',
      Color(0xFF7C3AED), Color(0xFF1B53D0), Color(0xFFF6F4FB));
  static const neutro = AppPalette('neutro', 'Neutro',
      Color(0xFF374151), Color(0xFF2E9E8F), Color(0xFFF5F6F8));
  static const altoContraste = AppPalette('alto_contraste', 'Alto Contraste',
      Color(0xFF0033CC), Color(0xFF008000), Color(0xFFFFFFFF));

  static const all = [institucional, urgencia, premium, neutro, altoContraste];

  static AppPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => institucional);
}

/// Famílias de fonte disponíveis (CFG-02a).
const kFontFamilies = ['Inter', 'Poppins', 'Roboto', 'Outfit', 'Nunito', 'Open Sans'];

/// Filtros de daltonismo (CFG-04e).
enum ColorBlindFilter { none, protanopia, deuteranopia, tritanopia }

/// Modelo central de preferências (Módulo 9). Persistido como JSON.
@immutable
class AppSettings {
  const AppSettings({
    this.primaryColor = 0xFF1B53D0,
    this.accentColor = 0xFF2E9E8F,
    this.backgroundColor = 0xFFF4F6FA,
    this.paletteId = 'institucional',
    this.fontFamily = 'Inter',
    this.fontScale = 1.0,
    this.bodyBold = false,
    this.lineHeight = 1.5,
    this.themeMode = ThemeMode.dark,
    this.contrastLevel = 0.0,
    this.borderRadius = 16,
    this.animationsEnabled = true,
    this.useClinicTheme = false,
    this.highContrast = false,
    this.reduceMotion = false,
    this.largerTouchTargets = false,
    this.hapticFeedback = true,
    this.colorBlindFilter = ColorBlindFilter.none,
    this.screenReaderLabels = false,
    this.pushToggles = kDefaultPush,
    this.emailToggles = kDefaultEmail,
    this.soundEnabled = true,
    this.dndStart,
    this.dndEnd,
    this.locale = 'pt_BR',
    this.dateFormat = 'dd/MM/yyyy',
    this.use24HourFormat = true,
    this.timezone = 'America/Sao_Paulo',
    this.developerMode = false,
    this.logoBase64,
    this.showNextAppointmentsCarousel = true,
  });

  // Aparência
  final int primaryColor;
  final int accentColor;
  final int backgroundColor;
  final String paletteId;

  // Tipografia
  final String fontFamily;
  final double fontScale;
  final bool bodyBold;
  final double lineHeight;

  // Tema
  final ThemeMode themeMode;
  final double contrastLevel;
  final double borderRadius;
  final bool animationsEnabled;
  final bool useClinicTheme;
  final bool showNextAppointmentsCarousel;

  // Acessibilidade
  final bool highContrast;
  final bool reduceMotion;
  final bool largerTouchTargets;
  final bool hapticFeedback;
  final ColorBlindFilter colorBlindFilter;
  final bool screenReaderLabels;

  // Notificações
  final Map<String, bool> pushToggles;
  final Map<String, bool> emailToggles;
  final bool soundEnabled;
  final String? dndStart;
  final String? dndEnd;

  // Avançado
  final String locale;
  final String dateFormat;
  final bool use24HourFormat;
  final String timezone;
  final bool developerMode;

  /// Logotipo personalizado da marca (PNG em base64). `null` = logo padrão.
  final String? logoBase64;

  /// Bytes decodificados do logotipo (ou `null`).
  Uint8List? get logoBytes {
    if (logoBase64 == null || logoBase64!.isEmpty) return null;
    try {
      return base64Decode(logoBase64!);
    } catch (_) {
      return null;
    }
  }

  static const kDefaultPush = {
    'novo_agendamento': true,
    'cancelamento': true,
    'lembrete': true,
    'alerta_risco': true,
    'relatorio': false,
    'ticket': true,
  };
  static const kDefaultEmail = {
    'resumo_diario': false,
    'alertas_criticos': true,
    'relatorios_semanais': true,
  };

  Color get primary => Color(primaryColor);
  Color get accent => Color(accentColor);
  Color get background => Color(backgroundColor);

  /// Reduzir movimento desliga animações de fato.
  bool get effectiveAnimations => animationsEnabled && !reduceMotion;

  /// Defaults por tipo de unidade (CFG / personalização do ambiente).
  static AppSettings defaultsFor(ClinicType type) {
    final palette = switch (type) {
      ClinicType.upa => AppPalette.urgencia,
      ClinicType.privada => AppPalette.premium,
      _ => AppPalette.institucional,
    };
    return AppSettings(
      paletteId: palette.id,
      primaryColor: palette.primary.toARGB32(),
      accentColor: palette.accent.toARGB32(),
      backgroundColor: palette.background.toARGB32(),
    );
  }

  AppSettings applyPalette(AppPalette p) => copyWith(
        paletteId: p.id,
        primaryColor: p.primary.toARGB32(),
        accentColor: p.accent.toARGB32(),
        backgroundColor: p.background.toARGB32(),
      );

  AppSettings copyWith({
    int? primaryColor,
    int? accentColor,
    int? backgroundColor,
    String? paletteId,
    String? fontFamily,
    double? fontScale,
    bool? bodyBold,
    double? lineHeight,
    ThemeMode? themeMode,
    double? contrastLevel,
    double? borderRadius,
    bool? animationsEnabled,
    bool? useClinicTheme,
    bool? highContrast,
    bool? reduceMotion,
    bool? largerTouchTargets,
    bool? hapticFeedback,
    ColorBlindFilter? colorBlindFilter,
    bool? screenReaderLabels,
    Map<String, bool>? pushToggles,
    Map<String, bool>? emailToggles,
    bool? soundEnabled,
    String? dndStart,
    String? dndEnd,
    String? locale,
    String? dateFormat,
    bool? use24HourFormat,
    String? timezone,
    bool? developerMode,
    String? logoBase64,
    bool clearLogo = false,
    bool? showNextAppointmentsCarousel,
  }) {
    return AppSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      paletteId: paletteId ?? this.paletteId,
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      bodyBold: bodyBold ?? this.bodyBold,
      lineHeight: lineHeight ?? this.lineHeight,
      themeMode: themeMode ?? this.themeMode,
      contrastLevel: contrastLevel ?? this.contrastLevel,
      borderRadius: borderRadius ?? this.borderRadius,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      useClinicTheme: useClinicTheme ?? this.useClinicTheme,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      largerTouchTargets: largerTouchTargets ?? this.largerTouchTargets,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      colorBlindFilter: colorBlindFilter ?? this.colorBlindFilter,
      screenReaderLabels: screenReaderLabels ?? this.screenReaderLabels,
      pushToggles: pushToggles ?? this.pushToggles,
      emailToggles: emailToggles ?? this.emailToggles,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
      locale: locale ?? this.locale,
      dateFormat: dateFormat ?? this.dateFormat,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      timezone: timezone ?? this.timezone,
      developerMode: developerMode ?? this.developerMode,
      logoBase64: clearLogo ? null : (logoBase64 ?? this.logoBase64),
      showNextAppointmentsCarousel: showNextAppointmentsCarousel ?? this.showNextAppointmentsCarousel,
    );
  }

  Map<String, dynamic> toJson() => {
        'primaryColor': primaryColor,
        'accentColor': accentColor,
        'backgroundColor': backgroundColor,
        'paletteId': paletteId,
        'fontFamily': fontFamily,
        'fontScale': fontScale,
        'bodyBold': bodyBold,
        'lineHeight': lineHeight,
        'themeMode': themeMode.name,
        'contrastLevel': contrastLevel,
        'borderRadius': borderRadius,
        'animationsEnabled': animationsEnabled,
        'useClinicTheme': useClinicTheme,
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
        'largerTouchTargets': largerTouchTargets,
        'hapticFeedback': hapticFeedback,
        'colorBlindFilter': colorBlindFilter.name,
        'screenReaderLabels': screenReaderLabels,
        'pushToggles': pushToggles,
        'emailToggles': emailToggles,
        'soundEnabled': soundEnabled,
        'dndStart': dndStart,
        'dndEnd': dndEnd,
        'locale': locale,
        'dateFormat': dateFormat,
        'use24HourFormat': use24HourFormat,
        'timezone': timezone,
        'developerMode': developerMode,
        'logoBase64': logoBase64,
        'showNextAppointmentsCarousel': showNextAppointmentsCarousel,
      };

  String encode() => jsonEncode(toJson());

  static AppSettings decode(String? source) {
    if (source == null || source.isEmpty) return const AppSettings();
    try {
      return fromJson(jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  static AppSettings fromJson(Map<String, dynamic> j) {
    Map<String, bool> boolMap(dynamic v, Map<String, bool> fallback) {
      if (v is Map) {
        return {for (final e in v.entries) e.key.toString(): e.value == true};
      }
      return fallback;
    }

    return AppSettings(
      primaryColor: (j['primaryColor'] as num?)?.toInt() ?? 0xFF1B53D0,
      accentColor: (j['accentColor'] as num?)?.toInt() ?? 0xFF2E9E8F,
      backgroundColor: (j['backgroundColor'] as num?)?.toInt() ?? 0xFFF4F6FA,
      paletteId: j['paletteId']?.toString() ?? 'institucional',
      fontFamily: j['fontFamily']?.toString() ?? 'Inter',
      fontScale: (j['fontScale'] as num?)?.toDouble() ?? 1.0,
      bodyBold: j['bodyBold'] == true,
      lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? 1.5,
      themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'], orElse: () => ThemeMode.light),
      contrastLevel: (j['contrastLevel'] as num?)?.toDouble() ?? 0.0,
      borderRadius: (j['borderRadius'] as num?)?.toDouble() ?? 16,
      animationsEnabled: j['animationsEnabled'] != false,
      useClinicTheme: j['useClinicTheme'] == true,
      highContrast: j['highContrast'] == true,
      reduceMotion: j['reduceMotion'] == true,
      largerTouchTargets: j['largerTouchTargets'] == true,
      hapticFeedback: j['hapticFeedback'] != false,
      colorBlindFilter: ColorBlindFilter.values.firstWhere(
          (f) => f.name == j['colorBlindFilter'],
          orElse: () => ColorBlindFilter.none),
      screenReaderLabels: j['screenReaderLabels'] == true,
      pushToggles: boolMap(j['pushToggles'], kDefaultPush),
      emailToggles: boolMap(j['emailToggles'], kDefaultEmail),
      soundEnabled: j['soundEnabled'] != false,
      dndStart: j['dndStart']?.toString(),
      dndEnd: j['dndEnd']?.toString(),
      locale: j['locale']?.toString() ?? 'pt_BR',
      dateFormat: j['dateFormat']?.toString() ?? 'dd/MM/yyyy',
      use24HourFormat: j['use24HourFormat'] != false,
      timezone: j['timezone']?.toString() ?? 'America/Sao_Paulo',
      developerMode: j['developerMode'] == true,
      logoBase64: j['logoBase64']?.toString(),
      showNextAppointmentsCarousel: j['showNextAppointmentsCarousel'] != false,
    );
  }

  /// Cor de fallback do tema padrão (para o color picker).
  static const swatchOptions = [
    AppColors.primary,
    Color(0xFF7C3AED),
    AppColors.secondary,
    AppColors.danger,
    Color(0xFF0EA5E9),
    Color(0xFFEA580C),
    Color(0xFF374151),
    Color(0xFF059669),
  ];
}
