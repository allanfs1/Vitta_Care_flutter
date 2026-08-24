import 'package:flutter/material.dart';

import 'totem_config.dart';

/// Perfil de configuração do totem: um preset nomeado de [TotemConfig] voltado
/// a um tipo de unidade de saúde. Os 5 perfis abaixo são os padrões embutidos;
/// o usuário pode sobrescrever cada um salvando a configuração atual.
class TotemProfile {
  const TotemProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.config,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final TotemConfig config;
}

/// Presets embutidos (fonte da verdade quando não há override salvo).
const List<TotemProfile> kTotemProfiles = [
  TotemProfile(
    id: 'ubs',
    label: 'UBS',
    description: 'Unidade Básica de Saúde',
    icon: Icons.local_hospital_outlined,
    config: TotemConfig(
      clinicName: 'UBS',
      welcomeTitle: 'Bem-vindo à UBS',
      welcomeSubtitle: 'Atenção Básica — toque para começar',
      accent: 0xFF1FAA59,
      openHour: 7,
      closeHour: 17,
      openSaturday: false,
      openSunday: false,
      lunchBreakEnabled: true,
      lunchStartHour: 12,
      lunchEndHour: 13,
      appointmentDuration: 20,
      allowGuestScheduling: true,
      ticketFooter: 'Compareça à recepção com este comprovante.',
    ),
  ),
  TotemProfile(
    id: 'upa',
    label: 'UPA',
    description: 'Unidade de Pronto Atendimento (24h)',
    icon: Icons.emergency_outlined,
    config: TotemConfig(
      clinicName: 'UPA 24h',
      welcomeTitle: 'Pronto Atendimento',
      welcomeSubtitle: 'Retire sua senha de atendimento',
      accent: 0xFFE53935,
      agendarTitle: 'Novo Atendimento',
      agendarButtonLabel: 'GERAR SENHA',
      allowRemarcar: false,
      showSuggestions: false,
      showDoctorFilter: false,
      showCalendarButton: false,
      showWeekStrip: false,
      openHour: 0,
      closeHour: 24,
      openSaturday: true,
      saturdayCloseHour: 24,
      openSunday: true,
      lunchBreakEnabled: false,
      sessionTimeout: 60,
      warningSeconds: 10,
      successAutoReturn: 12,
      arrivalMinutes: 0,
      appointmentDuration: 15,
      maxPerDay: 0, // urgência: sem limite por dia
      maxActivePerPatient: 0,
    ),
  ),
  TotemProfile(
    id: 'aps',
    label: 'APS',
    description: 'Atenção Primária à Saúde',
    icon: Icons.health_and_safety_outlined,
    config: TotemConfig(
      clinicName: 'APS',
      welcomeTitle: 'Atenção Primária',
      welcomeSubtitle: 'Agende ou remarque sua consulta',
      accent: 0xFF2563EB,
      openHour: 7,
      closeHour: 18,
      openSaturday: true,
      saturdayCloseHour: 12,
      lunchBreakEnabled: true,
      appointmentDuration: 20,
      allowGuestScheduling: true,
    ),
  ),
  TotemProfile(
    id: 'clinica_popular',
    label: 'Clínica Popular',
    description: 'Atendimento acessível, alto volume',
    icon: Icons.volunteer_activism_outlined,
    config: TotemConfig(
      clinicName: 'Clínica Popular',
      welcomeTitle: 'Clínica Popular',
      welcomeSubtitle: 'Consultas acessíveis — comece aqui',
      accent: 0xFF7C3AED,
      openHour: 8,
      closeHour: 20,
      openSaturday: true,
      saturdayCloseHour: 14,
      appointmentDuration: 20,
      requirePhone: true,
      ticketFooter: 'Apresente este comprovante na recepção.',
    ),
  ),
  TotemProfile(
    id: 'clinica_normal',
    label: 'Clínica Normal',
    description: 'Clínica privada / consultório',
    icon: Icons.medical_services_outlined,
    config: TotemConfig(
      clinicName: 'Clínica',
      welcomeTitle: 'Bem-vindo',
      welcomeSubtitle: 'Agende sua consulta com conforto',
      accent: 0xFFFF3B30,
      openHour: 8,
      closeHour: 18,
      openSaturday: true,
      saturdayCloseHour: 12,
      appointmentDuration: 30,
      showDoctorCard: true,
      requirePhone: true,
      ticketFooter: 'Chegue com antecedência. Bom atendimento!',
    ),
  ),
];
