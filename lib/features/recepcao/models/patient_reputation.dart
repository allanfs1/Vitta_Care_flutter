import 'package:flutter/material.dart';

/// Faixa de reputação do paciente (§5 — coleção `patient_reputation`).
enum ReputationTier {
  gold('Ouro', Color(0xFFFFC107)),
  silver('Prata', Color(0xFF90A4AE)),
  bronze('Bronze', Color(0xFFA1887F));

  const ReputationTier(this.label, this.color);

  final String label;
  final Color color;
}

/// Reputação de presença do paciente, usada na prevenção de no-show (§5).
class PatientReputation {
  const PatientReputation({
    required this.score,
    required this.tier,
  });

  /// 0–100. Quanto maior, mais confiável o comparecimento.
  final int score;
  final ReputationTier tier;

  /// `true` dispara o selo "ALERTA CRÍTICO": bronze ou score abaixo de 50.
  bool get isCritical => tier == ReputationTier.bronze || score < 50;
}
