import 'package:flutter/material.dart';

/// Linha de cuidado / grupo programático da APS.
enum CareLine {
  geral('Demanda geral', Icons.medical_services_outlined),
  preNatal('Pré-natal', Icons.pregnant_woman_outlined),
  puericultura('Puericultura', Icons.child_care_outlined),
  hiperdia('HiperDia', Icons.favorite_outline),
  saudeMental('Saúde mental', Icons.psychology_outlined);

  const CareLine(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Origem da procura na unidade.
enum AttendanceType {
  espontanea('Demanda espontânea'),
  agendada('Agendada');

  const AttendanceType(this.label);

  final String label;
}
