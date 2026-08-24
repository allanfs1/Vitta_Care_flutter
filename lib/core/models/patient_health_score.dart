/// Modelo de Health Score / Reputação do Paciente.
/// Mapeia os dados da coleção `patient_reputation`.
class PatientHealthScore {
  const PatientHealthScore({
    required this.id,
    required this.patientName,
    required this.patientCpf,
    required this.classification,
    required this.healthScore,
    required this.totalAppointments,
    required this.absences,
    required this.trend,
    required this.doctorName,
    this.phone,
    this.events = const [],
    this.scoreHistory = const [],
  });

  final String id;
  final String patientName;
  final String patientCpf;
  final HealthClassification classification;
  final int healthScore; // 0..100
  final int totalAppointments;
  final int absences;
  final double? trend; // variação mensal (ex: -0.3)
  final String doctorName;
  final String? phone;
  final List<PatientEvent> events;
  final List<ScorePoint> scoreHistory;

  String get initials {
    final parts =
        patientName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Classificação IA do paciente baseada no Health Score.
enum HealthClassification {
  diamante(
    label: 'DIAMANTE',
    subtitle: 'EXCELÊNCIA - DIAMANTE',
    minScore: 90,
  ),
  ouro(
    label: 'OURO',
    subtitle: 'ASSÍDUO - OURO',
    minScore: 70,
  ),
  prata(
    label: 'PRATA',
    subtitle: 'ATENÇÃO - PRATA',
    minScore: 40,
  ),
  bronze(
    label: 'BRONZE',
    subtitle: 'RISCO - BRONZE',
    minScore: 0,
  );

  const HealthClassification({
    required this.label,
    required this.subtitle,
    required this.minScore,
  });

  final String label;
  final String subtitle;
  final int minScore;

  static HealthClassification fromScore(int score) {
    if (score >= 90) return diamante;
    if (score >= 70) return ouro;
    if (score >= 40) return prata;
    return bronze;
  }
}

/// Evento na trilha de um paciente (comparecimento, falta, etc.).
class PatientEvent {
  const PatientEvent({
    required this.description,
    required this.date,
    required this.time,
    required this.scoreImpact,
    this.isPositive = true,
  });

  final String description;
  final String date; // dd/MM/yyyy
  final String time; // HH:mm
  final int scoreImpact;
  final bool isPositive;
}

/// Ponto no gráfico de evolução do health score.
class ScorePoint {
  const ScorePoint(this.date, this.score);

  final String date; // dd/MM
  final int score;
}
