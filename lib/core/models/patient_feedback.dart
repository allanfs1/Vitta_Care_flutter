import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Avaliação de Satisfação do Paciente (NPS/Feedbacks)
/// Mapeia os dados da coleção `tb_avaliacoes`.
class PatientFeedback {
  const PatientFeedback({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.patientEmail,
    required this.patientCpf,
    required this.protocol,
    required this.createdAt,
    required this.systemRating,
    required this.unitRating,
    required this.teamRating,
  });

  final String id;
  final String patientName;
  final String patientId; // ex: #89923783
  final String? patientEmail;
  final String? patientCpf;
  final String? protocol;
  final DateTime createdAt;
  final int systemRating; // 1 a 5
  final int unitRating;   // 1 a 5
  final int teamRating;   // 1 a 5

  /// Média aritmética das notas
  double get averageRating => (systemRating + unitRating + teamRating) / 3;

  /// Retorna `true` se a média for menor ou igual a 3, ou alguma nota for muito baixa (indicativo de crítico).
  bool get isCritical => averageRating <= 3.0 || systemRating <= 2 || unitRating <= 2 || teamRating <= 2;

  factory PatientFeedback.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime createdAt = DateTime.now();
    if (data['created_at'] is Timestamp) {
      createdAt = (data['created_at'] as Timestamp).toDate();
    } else if (data['created_at'] is String) {
      createdAt = DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now();
    }

    return PatientFeedback(
      id: id,
      patientName: data['patient_name']?.toString() ?? 'Paciente Desconhecido',
      patientId: data['patient_id']?.toString() ?? '',
      patientEmail: data['patient_email']?.toString(),
      patientCpf: data['patient_cpf']?.toString(),
      protocol: data['protocol']?.toString(),
      createdAt: createdAt,
      systemRating: (data['system_rating'] as num?)?.toInt() ?? 5,
      unitRating: (data['unit_rating'] as num?)?.toInt() ?? 5,
      teamRating: (data['team_rating'] as num?)?.toInt() ?? 5,
    );
  }
}
