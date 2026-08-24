import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/patient.dart';
import '../../core/theme/app_colors.dart';

/// Estado de uma etapa da jornada do paciente (PAC-03).
enum JourneyState { done, current, pending }

class JourneyStep {
  const JourneyStep(this.title, this.subtitle, this.state, this.icon);
  final String title;
  final String subtitle;
  final JourneyState state;
  final IconData icon;
}

/// Item do histórico de presença (PAC-04).
class AttendanceItem {
  const AttendanceItem(this.specialty, this.date, this.attended);
  final String specialty;
  final String date;
  final bool attended;
}

/// Nota clínica (PAC-05).
class ClinicalNote {
  const ClinicalNote(this.date, this.author, this.text);
  final String date;
  final String author;
  final String text;
}

/// Dados complementares (mock) da jornada/histórico/notas por paciente.
/// Deriva, em produção, de `tb_agendamentos`, `tb_historico` e notas clínicas.
class PacienteData {
  PacienteData._();

  static List<JourneyStep> journeyFor(Patient p) {
    final highRisk = p.riskScore >= 0.66;
    return [
      const JourneyStep('Agendado', 'Out 12', JourneyState.done, Icons.event),
      const JourneyStep('Confirmado por SMS', 'Out 14', JourneyState.done, Icons.sms),
      JourneyStep(
        'Pré-check',
        highRisk ? 'Pendente' : 'Em andamento',
        highRisk ? JourneyState.pending : JourneyState.current,
        Icons.monitor_heart_outlined,
      ),
      const JourneyStep('Consulta', 'Aguardando', JourneyState.pending, Icons.medical_services_outlined),
    ];
  }

  static List<AttendanceItem> historyFor(Patient p) => const [
        AttendanceItem('Retorno Cardiologia', 'Set 28', true),
        AttendanceItem('Clínica Geral', 'Ago 15', true),
        AttendanceItem('Vacinação', 'Jun 02', true),
        AttendanceItem('Dermatologia', 'Mai 20', false),
      ];

  static List<ClinicalNote> notesFor(Patient p) => const [
        ClinicalNote('Ago 15 — Dr. Roberto Santos',
            'Dr. Roberto Santos',
            'Paciente apresenta hipertensão leve. Ajuste de Lisinopril para 20mg/dia. '
                'Orientado sobre redução de sódio. Retorno em 1 mês.'),
        ClinicalNote('Jun 02 — Enf. Ana Lima', 'Enf. Ana Lima',
            'Aplicada vacina anual da gripe. Sem reações adversas imediatas.'),
      ];

  static Color journeyColor(JourneyState s) => switch (s) {
        JourneyState.done => AppColors.primary,
        JourneyState.current => AppColors.primary,
        JourneyState.pending => AppColors.textTertiary,
      };
}

/// Notas clínicas editáveis por paciente (PAC-05: adicionar nota).
class ClinicalNotesNotifier extends StateNotifier<Map<String, List<ClinicalNote>>> {
  ClinicalNotesNotifier() : super({});

  List<ClinicalNote> notes(Patient p) => state[p.id] ?? PacienteData.notesFor(p);

  void add(Patient p, ClinicalNote note) {
    final current = notes(p);
    state = {...state, p.id: [note, ...current]};
  }
}

final clinicalNotesProvider =
    StateNotifierProvider<ClinicalNotesNotifier, Map<String, List<ClinicalNote>>>(
        (ref) => ClinicalNotesNotifier());
