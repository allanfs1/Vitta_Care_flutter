import 'enums.dart';

/// Paciente / usuário atendido. Deriva de `users` e `patient_reputation`.
class Patient {
  const Patient({
    required this.id,
    required this.name,
    this.cpf,
    this.phone,
    this.email,
    this.photoUrl,
    this.age,
    this.gender,
    this.riskScore = 0,
    this.absencesYtd = 0,
    this.attendedYtd = 0,
  });

  final String id;
  final String name;
  final String? cpf;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final int? age;
  final String? gender;

  /// Score 0..1 de risco de falta (IA — AB-06 / dashboard_risco).
  final double riskScore;
  final int absencesYtd;
  final int attendedYtd;

  RiskLevel get riskLevel => RiskLevel.fromScore(riskScore);

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
