import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/patient.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import 'notas_clinicas_repository.dart';

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
  ClinicalNote(
    this.date,
    this.author,
    this.text, {
    this.id,
    DateTime? criadaEm,
  }) : criadaEm = criadaEm ?? DateTime.now();

  /// Rótulo pronto para exibição (ex.: "Ago 15 — Dr. Roberto Santos"). As
  /// notas de demonstração só têm isto; notas reais também têm [criadaEm].
  final String date;
  final String author;
  final String text;

  /// Id do documento no Firestore; nulo até a gravação terminar.
  final String? id;

  /// Quando a nota foi criada — usada para ordenar; as notas de demonstração
  /// usam a hora da criação do objeto, já que só têm o rótulo textual.
  final DateTime criadaEm;

  ClinicalNote copyWith({String? id, DateTime? criadaEm}) => ClinicalNote(
        date,
        author,
        text,
        id: id ?? this.id,
        criadaEm: criadaEm ?? this.criadaEm,
      );
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

  static List<ClinicalNote> notesFor(Patient p) => notesForId(p.id);

  /// Mesmas notas de demonstração, só que sem exigir o [Patient] inteiro —
  /// o repositório em memória popula por id, antes de qualquer tela ter
  /// carregado a lista de pacientes.
  static List<ClinicalNote> notesForId(String pacienteId) => [
        ClinicalNote('Ago 15 — Dr. Roberto Santos', 'Dr. Roberto Santos',
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
///
/// O estado em memória continua existindo — é o cache que a tela lê — mas
/// agora é alimentado e sustentado pelo [NotasClinicasRepository]. Cada
/// paciente carrega sob demanda, na primeira vez que a tela pede suas notas.
class ClinicalNotesNotifier extends StateNotifier<Map<String, List<ClinicalNote>>> {
  ClinicalNotesNotifier(this._repo, this._clinicaId) : super({});

  final NotasClinicasRepository _repo;
  final String _clinicaId;
  final Set<String> _carregando = {};

  /// Notas já conhecidas do paciente. Dispara o carregamento se ainda não
  /// tiver rodado — chame de um `build`, o resultado chega por rebuild.
  List<ClinicalNote> notes(Patient p) {
    final atuais = state[p.id];
    if (atuais != null) return atuais;
    _carregar(p.id);
    return PacienteData.notesFor(p);
  }

  Future<void> _carregar(String pacienteId) async {
    if (_clinicaId.isEmpty || !_carregando.add(pacienteId)) return;
    try {
      final notas = await _repo.carregar(_clinicaId, pacienteId);
      if (mounted) state = {...state, pacienteId: notas};
    } finally {
      _carregando.remove(pacienteId);
    }
  }

  Future<void> add(Patient p, ClinicalNote note) async {
    if (_clinicaId.isEmpty) {
      throw StateError('A clínica ativa ainda não carregou — aguarde para salvar a nota.');
    }
    final salva = await _repo.adicionar(_clinicaId, p.id, note);
    final atuais = state[p.id] ?? PacienteData.notesFor(p);
    state = {...state, p.id: [salva, ...atuais]};
  }
}

final notasClinicasRepositoryProvider = Provider<NotasClinicasRepository>((ref) {
  if (ref.watch(firebaseEnabledProvider)) {
    return FirestoreNotasClinicasRepository();
  }
  return MemoriaNotasClinicasRepository();
});

final clinicalNotesProvider =
    StateNotifierProvider<ClinicalNotesNotifier, Map<String, List<ClinicalNote>>>(
        (ref) => ClinicalNotesNotifier(
              ref.watch(notasClinicasRepositoryProvider),
              ref.watch(clinicaResolvidaProvider),
            ));
