import 'package:flutter/material.dart';

/// Configuração completa do Totem (interface + comportamento do sistema),
/// persistida em SharedPreferences.
class TotemConfig {
  const TotemConfig({
    // Marca / textos
    this.clinicName = 'Agenda Clínica',
    this.welcomeTitle = 'Bem-vindo',
    this.welcomeSubtitle = 'Toque para começar o autoatendimento',
    this.accent = 0xFFFF3B30,
    this.logoUrl = '',
    // Interface
    this.showClock = true,
    this.showDoctorCard = true,
    this.showOccupancy = true,
    this.scale = 1.0,
    this.gradientBackground = true,
    // Tela inicial
    this.showTutorial = true,
    this.showTestPrint = true,
    // Páginas Agendar / Remarcar
    this.agendarTitle = 'Agendar Consulta',
    this.remarcarTitle = 'Remarcar Consulta',
    this.agendarButtonLabel = 'AGENDAR',
    this.remarcarButtonLabel = 'REMARCAR',
    this.showStepper = true,
    this.showWeekStrip = true,
    this.showCalendarButton = true,
    this.showDoctorFilter = true,
    // Sugestões (especialidades mais procuradas)
    this.showSuggestions = true,
    this.maxSuggestions = 4,
    // Fluxos
    this.allowAgendar = true,
    this.allowRemarcar = true,
    this.allowGuestScheduling = true,
    this.requirePhone = false,
    this.printEnabled = true,
    this.ticketFooter = '',
    this.confirmViaWhatsapp = false,
    this.confirmationLink =
        'https://api-wriqcan55q-uc.a.run.app/sendConfirmationEmail',
    // Regras de agendamento
    this.defaultSpecialty = 'Todos',
    this.appointmentDuration = 30,
    this.maxDaysAhead = 365,
    this.arrivalMinutes = 15,
    this.maxPerDay = 1,
    this.maxActivePerPatient = 3,
    // Sistema
    this.sessionTimeout = 120,
    this.warningSeconds = 10,
    this.successAutoReturn = 18,
    this.adminPin = '',
    // Funcionamento (horários)
    this.openHour = 8,
    this.closeHour = 17,
    this.openSaturday = true,
    this.saturdayCloseHour = 12,
    this.openSunday = false,
    this.lunchBreakEnabled = false,
    this.lunchStartHour = 12,
    this.lunchEndHour = 13,
  });

  // Marca / textos
  final String clinicName;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final int accent; // cor de destaque (ARGB)
  final String logoUrl; // logo exibido na tela inicial/comprovante (vazio = coração)

  // Interface
  final bool showClock;
  final bool showDoctorCard;
  final bool showOccupancy;
  final double scale;
  final bool gradientBackground;

  // Tela inicial
  final bool showTutorial; // botão "Como usar o totem"
  final bool showTestPrint; // botão "Testar impressão"

  // Páginas Agendar / Remarcar
  final String agendarTitle; // título da página no modo agendar
  final String remarcarTitle; // título da página no modo remarcar
  final String agendarButtonLabel; // rótulo do botão de ação (agendar)
  final String remarcarButtonLabel; // rótulo do botão de ação (remarcar)
  final bool showStepper; // indicador de progresso (passos)
  final bool showWeekStrip; // faixa rápida de dias da semana
  final bool showCalendarButton; // botão "Abrir calendário"
  final bool showDoctorFilter; // chips de "Filtrar por médico"

  // Sugestões
  final bool showSuggestions; // mostra a linha "MAIS PROCURADAS"
  final int maxSuggestions; // nº de chips de sugestão

  // Fluxos
  final bool allowAgendar;
  final bool allowRemarcar;
  final bool allowGuestScheduling; // agendar sem cadastro (CPF não encontrado)
  final bool requirePhone; // exige telefone no cadastro do totem
  final bool printEnabled;
  final String ticketFooter; // rodapé do comprovante (tela de sucesso)
  final bool confirmViaWhatsapp; // envia confirmação por WhatsApp (Z-API)
  final String confirmationLink; // link de confirmação enviado no WhatsApp

  // Regras de agendamento
  final String defaultSpecialty; // especialidade pré-selecionada
  final int appointmentDuration; // duração da consulta (min)
  final int maxDaysAhead; // limite de dias à frente para agendar
  final int arrivalMinutes; // antecedência sugerida no comprovante
  final int maxPerDay; // máx. consultas do paciente no mesmo dia (0 = ilimitado)
  final int maxActivePerPatient; // máx. consultas ativas/futuras (0 = ilimitado)

  // Sistema
  final int sessionTimeout; // segundos de inatividade
  final int warningSeconds; // aviso antes de expirar
  final int successAutoReturn; // retorno automático na tela de sucesso
  final String adminPin; // PIN do painel de config (vazio = sem PIN)

  // Funcionamento
  final int openHour;
  final int closeHour;
  final bool openSaturday;
  final int saturdayCloseHour;
  final bool openSunday;
  final bool lunchBreakEnabled; // bloqueia horários no intervalo de almoço
  final int lunchStartHour;
  final int lunchEndHour;

  Color get accentColor => Color(accent);

  TotemConfig copyWith({
    String? clinicName,
    String? welcomeTitle,
    String? welcomeSubtitle,
    int? accent,
    String? logoUrl,
    bool? showClock,
    bool? showDoctorCard,
    bool? showOccupancy,
    double? scale,
    bool? gradientBackground,
    bool? showTutorial,
    bool? showTestPrint,
    String? agendarTitle,
    String? remarcarTitle,
    String? agendarButtonLabel,
    String? remarcarButtonLabel,
    bool? showStepper,
    bool? showWeekStrip,
    bool? showCalendarButton,
    bool? showDoctorFilter,
    bool? showSuggestions,
    int? maxSuggestions,
    bool? allowAgendar,
    bool? allowRemarcar,
    bool? allowGuestScheduling,
    bool? requirePhone,
    bool? printEnabled,
    String? ticketFooter,
    bool? confirmViaWhatsapp,
    String? confirmationLink,
    String? defaultSpecialty,
    int? appointmentDuration,
    int? maxDaysAhead,
    int? arrivalMinutes,
    int? maxPerDay,
    int? maxActivePerPatient,
    int? sessionTimeout,
    int? warningSeconds,
    int? successAutoReturn,
    String? adminPin,
    int? openHour,
    int? closeHour,
    bool? openSaturday,
    int? saturdayCloseHour,
    bool? openSunday,
    bool? lunchBreakEnabled,
    int? lunchStartHour,
    int? lunchEndHour,
  }) {
    return TotemConfig(
      clinicName: clinicName ?? this.clinicName,
      welcomeTitle: welcomeTitle ?? this.welcomeTitle,
      welcomeSubtitle: welcomeSubtitle ?? this.welcomeSubtitle,
      accent: accent ?? this.accent,
      logoUrl: logoUrl ?? this.logoUrl,
      showClock: showClock ?? this.showClock,
      showDoctorCard: showDoctorCard ?? this.showDoctorCard,
      showOccupancy: showOccupancy ?? this.showOccupancy,
      scale: scale ?? this.scale,
      gradientBackground: gradientBackground ?? this.gradientBackground,
      showTutorial: showTutorial ?? this.showTutorial,
      showTestPrint: showTestPrint ?? this.showTestPrint,
      agendarTitle: agendarTitle ?? this.agendarTitle,
      remarcarTitle: remarcarTitle ?? this.remarcarTitle,
      agendarButtonLabel: agendarButtonLabel ?? this.agendarButtonLabel,
      remarcarButtonLabel: remarcarButtonLabel ?? this.remarcarButtonLabel,
      showStepper: showStepper ?? this.showStepper,
      showWeekStrip: showWeekStrip ?? this.showWeekStrip,
      showCalendarButton: showCalendarButton ?? this.showCalendarButton,
      showDoctorFilter: showDoctorFilter ?? this.showDoctorFilter,
      showSuggestions: showSuggestions ?? this.showSuggestions,
      maxSuggestions: maxSuggestions ?? this.maxSuggestions,
      allowAgendar: allowAgendar ?? this.allowAgendar,
      allowRemarcar: allowRemarcar ?? this.allowRemarcar,
      allowGuestScheduling: allowGuestScheduling ?? this.allowGuestScheduling,
      requirePhone: requirePhone ?? this.requirePhone,
      printEnabled: printEnabled ?? this.printEnabled,
      ticketFooter: ticketFooter ?? this.ticketFooter,
      confirmViaWhatsapp: confirmViaWhatsapp ?? this.confirmViaWhatsapp,
      confirmationLink: confirmationLink ?? this.confirmationLink,
      defaultSpecialty: defaultSpecialty ?? this.defaultSpecialty,
      appointmentDuration: appointmentDuration ?? this.appointmentDuration,
      maxDaysAhead: maxDaysAhead ?? this.maxDaysAhead,
      arrivalMinutes: arrivalMinutes ?? this.arrivalMinutes,
      maxPerDay: maxPerDay ?? this.maxPerDay,
      maxActivePerPatient: maxActivePerPatient ?? this.maxActivePerPatient,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      warningSeconds: warningSeconds ?? this.warningSeconds,
      successAutoReturn: successAutoReturn ?? this.successAutoReturn,
      adminPin: adminPin ?? this.adminPin,
      openHour: openHour ?? this.openHour,
      closeHour: closeHour ?? this.closeHour,
      openSaturday: openSaturday ?? this.openSaturday,
      saturdayCloseHour: saturdayCloseHour ?? this.saturdayCloseHour,
      openSunday: openSunday ?? this.openSunday,
      lunchBreakEnabled: lunchBreakEnabled ?? this.lunchBreakEnabled,
      lunchStartHour: lunchStartHour ?? this.lunchStartHour,
      lunchEndHour: lunchEndHour ?? this.lunchEndHour,
    );
  }

  Map<String, dynamic> toJson() => {
        'clinicName': clinicName,
        'welcomeTitle': welcomeTitle,
        'welcomeSubtitle': welcomeSubtitle,
        'accent': accent,
        'logoUrl': logoUrl,
        'showClock': showClock,
        'showDoctorCard': showDoctorCard,
        'showOccupancy': showOccupancy,
        'scale': scale,
        'gradientBackground': gradientBackground,
        'showTutorial': showTutorial,
        'showTestPrint': showTestPrint,
        'agendarTitle': agendarTitle,
        'remarcarTitle': remarcarTitle,
        'agendarButtonLabel': agendarButtonLabel,
        'remarcarButtonLabel': remarcarButtonLabel,
        'showStepper': showStepper,
        'showWeekStrip': showWeekStrip,
        'showCalendarButton': showCalendarButton,
        'showDoctorFilter': showDoctorFilter,
        'showSuggestions': showSuggestions,
        'maxSuggestions': maxSuggestions,
        'allowAgendar': allowAgendar,
        'allowRemarcar': allowRemarcar,
        'allowGuestScheduling': allowGuestScheduling,
        'requirePhone': requirePhone,
        'printEnabled': printEnabled,
        'ticketFooter': ticketFooter,
        'confirmViaWhatsapp': confirmViaWhatsapp,
        'confirmationLink': confirmationLink,
        'defaultSpecialty': defaultSpecialty,
        'appointmentDuration': appointmentDuration,
        'maxDaysAhead': maxDaysAhead,
        'arrivalMinutes': arrivalMinutes,
        'maxPerDay': maxPerDay,
        'maxActivePerPatient': maxActivePerPatient,
        'sessionTimeout': sessionTimeout,
        'warningSeconds': warningSeconds,
        'successAutoReturn': successAutoReturn,
        'adminPin': adminPin,
        'openHour': openHour,
        'closeHour': closeHour,
        'openSaturday': openSaturday,
        'saturdayCloseHour': saturdayCloseHour,
        'openSunday': openSunday,
        'lunchBreakEnabled': lunchBreakEnabled,
        'lunchStartHour': lunchStartHour,
        'lunchEndHour': lunchEndHour,
      };

  factory TotemConfig.fromJson(Map<String, dynamic> j) {
    const def = TotemConfig();
    return TotemConfig(
      clinicName: j['clinicName'] as String? ?? def.clinicName,
      welcomeTitle: j['welcomeTitle'] as String? ?? def.welcomeTitle,
      welcomeSubtitle: j['welcomeSubtitle'] as String? ?? def.welcomeSubtitle,
      accent: j['accent'] as int? ?? def.accent,
      logoUrl: j['logoUrl'] as String? ?? def.logoUrl,
      showClock: j['showClock'] as bool? ?? def.showClock,
      showDoctorCard: j['showDoctorCard'] as bool? ?? def.showDoctorCard,
      showOccupancy: j['showOccupancy'] as bool? ?? def.showOccupancy,
      scale: (j['scale'] as num?)?.toDouble() ?? def.scale,
      gradientBackground:
          j['gradientBackground'] as bool? ?? def.gradientBackground,
      showTutorial: j['showTutorial'] as bool? ?? def.showTutorial,
      showTestPrint: j['showTestPrint'] as bool? ?? def.showTestPrint,
      agendarTitle: j['agendarTitle'] as String? ?? def.agendarTitle,
      remarcarTitle: j['remarcarTitle'] as String? ?? def.remarcarTitle,
      agendarButtonLabel:
          j['agendarButtonLabel'] as String? ?? def.agendarButtonLabel,
      remarcarButtonLabel:
          j['remarcarButtonLabel'] as String? ?? def.remarcarButtonLabel,
      showStepper: j['showStepper'] as bool? ?? def.showStepper,
      showWeekStrip: j['showWeekStrip'] as bool? ?? def.showWeekStrip,
      showCalendarButton:
          j['showCalendarButton'] as bool? ?? def.showCalendarButton,
      showDoctorFilter: j['showDoctorFilter'] as bool? ?? def.showDoctorFilter,
      showSuggestions: j['showSuggestions'] as bool? ?? def.showSuggestions,
      maxSuggestions: j['maxSuggestions'] as int? ?? def.maxSuggestions,
      allowAgendar: j['allowAgendar'] as bool? ?? def.allowAgendar,
      allowRemarcar: j['allowRemarcar'] as bool? ?? def.allowRemarcar,
      allowGuestScheduling:
          j['allowGuestScheduling'] as bool? ?? def.allowGuestScheduling,
      requirePhone: j['requirePhone'] as bool? ?? def.requirePhone,
      printEnabled: j['printEnabled'] as bool? ?? def.printEnabled,
      ticketFooter: j['ticketFooter'] as String? ?? def.ticketFooter,
      confirmViaWhatsapp:
          j['confirmViaWhatsapp'] as bool? ?? def.confirmViaWhatsapp,
      confirmationLink: j['confirmationLink'] as String? ?? def.confirmationLink,
      defaultSpecialty: j['defaultSpecialty'] as String? ?? def.defaultSpecialty,
      appointmentDuration:
          j['appointmentDuration'] as int? ?? def.appointmentDuration,
      maxDaysAhead: j['maxDaysAhead'] as int? ?? def.maxDaysAhead,
      arrivalMinutes: j['arrivalMinutes'] as int? ?? def.arrivalMinutes,
      maxPerDay: j['maxPerDay'] as int? ?? def.maxPerDay,
      maxActivePerPatient:
          j['maxActivePerPatient'] as int? ?? def.maxActivePerPatient,
      sessionTimeout: j['sessionTimeout'] as int? ?? def.sessionTimeout,
      warningSeconds: j['warningSeconds'] as int? ?? def.warningSeconds,
      successAutoReturn:
          j['successAutoReturn'] as int? ?? def.successAutoReturn,
      adminPin: j['adminPin'] as String? ?? def.adminPin,
      openHour: j['openHour'] as int? ?? def.openHour,
      closeHour: j['closeHour'] as int? ?? def.closeHour,
      openSaturday: j['openSaturday'] as bool? ?? def.openSaturday,
      saturdayCloseHour:
          j['saturdayCloseHour'] as int? ?? def.saturdayCloseHour,
      openSunday: j['openSunday'] as bool? ?? def.openSunday,
      lunchBreakEnabled:
          j['lunchBreakEnabled'] as bool? ?? def.lunchBreakEnabled,
      lunchStartHour: j['lunchStartHour'] as int? ?? def.lunchStartHour,
      lunchEndHour: j['lunchEndHour'] as int? ?? def.lunchEndHour,
    );
  }
}
