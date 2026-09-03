import 'package:cloud_firestore/cloud_firestore.dart';

import 'paciente_data.dart';

/// Persistência das notas clínicas (PAC-05, `tb_notas_clinicas`).
///
/// A tela permitia adicionar uma nota clínica há tempos — o botão existe, o
/// diálogo existe — mas a nota só vivia em `StateNotifier`. Fechar a aba
/// apagava a observação que um médico ou enfermeiro acabou de registrar sobre
/// um paciente. Diferente de carga de atendimento ou config de UI, uma nota
/// clínica é exatamente o tipo de dado que não pode ser efêmero.
abstract class NotasClinicasRepository {
  /// Notas do paciente, mais recente primeiro.
  Future<List<ClinicalNote>> carregar(String clinicaId, String pacienteId);

  Future<ClinicalNote> adicionar(
    String clinicaId,
    String pacienteId,
    ClinicalNote nota,
  );
}

class FirestoreNotasClinicasRepository implements NotasClinicasRepository {
  FirestoreNotasClinicasRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String colecao = 'tb_notas_clinicas';

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(colecao);

  @override
  Future<List<ClinicalNote>> carregar(String clinicaId, String pacienteId) async {
    if (clinicaId.isEmpty || pacienteId.isEmpty) return const [];
    // Sem `orderBy` — evita exigir índice composto para um volume que cabe
    // folgado em ordenação no cliente (uma pasta de paciente, não o vault
    // inteiro).
    final snap = await _col
        .where('clinicaId', isEqualTo: clinicaId)
        .where('pacienteId', isEqualTo: pacienteId)
        .limit(200)
        .get();
    final out = snap.docs.map((d) => _deMapa(d.id, d.data())).toList();
    out.sort((a, b) => b.criadaEm.compareTo(a.criadaEm));
    return out;
  }

  @override
  Future<ClinicalNote> adicionar(
    String clinicaId,
    String pacienteId,
    ClinicalNote nota,
  ) async {
    final ref = await _col.add({
      'clinicaId': clinicaId,
      'pacienteId': pacienteId,
      'autor': nota.author,
      'texto': nota.text,
      'createdAt': Timestamp.fromDate(nota.criadaEm),
    });
    return nota.copyWith(id: ref.id);
  }

  static ClinicalNote _deMapa(String id, Map<String, dynamic> d) {
    final ts = d['createdAt'];
    final quando = ts is Timestamp ? ts.toDate() : DateTime.now();
    final autor = (d['autor'] ?? '').toString();
    return ClinicalNote(
      _rotuloData(quando, autor),
      autor,
      (d['texto'] ?? '').toString(),
      id: id,
      criadaEm: quando,
    );
  }

  static String _rotuloData(DateTime d, String autor) {
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    return '${meses[d.month - 1]} ${d.day.toString().padLeft(2, '0')} — $autor';
  }
}

/// Implementação em memória — modo demonstração e testes.
class MemoriaNotasClinicasRepository implements NotasClinicasRepository {
  final Map<String, List<ClinicalNote>> _porPaciente = {};

  String _chave(String clinicaId, String pacienteId) => '$clinicaId|$pacienteId';

  @override
  Future<List<ClinicalNote>> carregar(String clinicaId, String pacienteId) async {
    final lista = _porPaciente[_chave(clinicaId, pacienteId)];
    if (lista != null) return List.unmodifiable(lista);
    // Vault ainda não populado: mantém as notas de demonstração como ponto
    // de partida, igual ao comportamento anterior ao repositório.
    return PacienteData.notesForId(pacienteId);
  }

  @override
  Future<ClinicalNote> adicionar(
    String clinicaId,
    String pacienteId,
    ClinicalNote nota,
  ) async {
    final chave = _chave(clinicaId, pacienteId);
    final atuais = _porPaciente[chave] ?? PacienteData.notesForId(pacienteId);
    final comId = nota.copyWith(
      id: 'nc_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
    );
    _porPaciente[chave] = [comId, ...atuais];
    return comId;
  }
}
