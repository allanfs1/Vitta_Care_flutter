import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/patient_reputation.dart';

/// Consulta de reputação do paciente (§5). Hoje é um mock determinístico por
/// nome; em produção consultaria `patient_reputation` pelo CPF.
class ReputationService {
  const ReputationService();

  /// Tabela mock de reputações conhecidas (por nome do paciente).
  static const Map<String, PatientReputation> _known = {
    'Ricardo Dias':
        PatientReputation(score: 32, tier: ReputationTier.bronze),
    'Letícia Lima':
        PatientReputation(score: 88, tier: ReputationTier.gold),
    'Carlos Eduardo':
        PatientReputation(score: 47, tier: ReputationTier.bronze),
    'Fernanda Gomes':
        PatientReputation(score: 72, tier: ReputationTier.silver),
  };

  PatientReputation reputationOf(String patientName) {
    final hit = _known[patientName.trim()];
    if (hit != null) return hit;

    // Fallback determinístico para nomes desconhecidos, garantindo
    // estabilidade visual entre rebuilds.
    final score = 50 + (patientName.hashCode.abs() % 50); // 50–99
    final tier = score >= 80
        ? ReputationTier.gold
        : score >= 65
            ? ReputationTier.silver
            : ReputationTier.bronze;
    return PatientReputation(score: score, tier: tier);
  }
}

final reputationServiceProvider =
    Provider<ReputationService>((ref) => const ReputationService());
