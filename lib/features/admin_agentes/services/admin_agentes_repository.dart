import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/agent_model.dart';
import '../models/queue_model.dart';

/// Persistência dos agentes de atendimento e das filas.
///
/// Antes o cadastro vivia só em `StateNotifier`: criar um agente, mudar a
/// disponibilidade ou montar uma fila se perdia ao fechar o app. Como o
/// roteamento de tickets (§3.1) depende dessa configuração, ela precisa ser
/// a mesma em qualquer dispositivo — daí o repositório.
abstract class AdminAgentesRepository {
  Future<List<AgentModel>> carregarAgentes(String clinicaId);
  Future<void> salvarAgente(String clinicaId, AgentModel agente);
  Future<void> excluirAgente(String agenteId);

  Future<List<QueueModel>> carregarFilas(String clinicaId);
  Future<void> salvarFila(String clinicaId, QueueModel fila);
  Future<void> excluirFila(String filaId);
}

/// Implementação Firestore — `tb_agentes` e `tb_filas`, ambas particionadas
/// por `clinicaId`.
class FirestoreAdminAgentesRepository implements AdminAgentesRepository {
  FirestoreAdminAgentesRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String colecaoAgentes = 'tb_agentes';
  static const String colecaoFilas = 'tb_filas';

  @override
  Future<List<AgentModel>> carregarAgentes(String clinicaId) async {
    if (clinicaId.isEmpty) return const [];
    final snap = await _db
        .collection(colecaoAgentes)
        .where('clinicaId', isEqualTo: clinicaId)
        .get();
    final out = snap.docs
        .map((d) => AgentModel.fromFirestore(d.id, d.data()))
        .toList();
    out.sort((a, b) => a.nomeOperacional.compareTo(b.nomeOperacional));
    return out;
  }

  @override
  Future<void> salvarAgente(String clinicaId, AgentModel agente) {
    return _db
        .collection(colecaoAgentes)
        .doc(agente.id)
        .set(agente.toFirestore(clinicaId), SetOptions(merge: true));
  }

  @override
  Future<void> excluirAgente(String agenteId) =>
      _db.collection(colecaoAgentes).doc(agenteId).delete();

  @override
  Future<List<QueueModel>> carregarFilas(String clinicaId) async {
    if (clinicaId.isEmpty) return const [];
    final snap = await _db
        .collection(colecaoFilas)
        .where('clinicaId', isEqualTo: clinicaId)
        .get();
    final out =
        snap.docs.map((d) => QueueModel.fromFirestore(d.id, d.data())).toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<void> salvarFila(String clinicaId, QueueModel fila) {
    return _db
        .collection(colecaoFilas)
        .doc(fila.id)
        .set(fila.toFirestore(clinicaId), SetOptions(merge: true));
  }

  @override
  Future<void> excluirFila(String filaId) =>
      _db.collection(colecaoFilas).doc(filaId).delete();
}

/// Implementação em memória — modo demonstração e testes. Mantém o mesmo
/// contrato para que a UI não precise saber em qual modo está.
class MemoriaAdminAgentesRepository implements AdminAgentesRepository {
  MemoriaAdminAgentesRepository({
    List<AgentModel> agentes = const [],
    List<QueueModel> filas = const [],
  }) {
    for (final a in agentes) {
      _agentes[a.id] = a;
    }
    for (final f in filas) {
      _filas[f.id] = f;
    }
  }

  final Map<String, AgentModel> _agentes = {};
  final Map<String, QueueModel> _filas = {};

  @override
  Future<List<AgentModel>> carregarAgentes(String clinicaId) async =>
      _agentes.values.toList();

  @override
  Future<void> salvarAgente(String clinicaId, AgentModel agente) async =>
      _agentes[agente.id] = agente;

  @override
  Future<void> excluirAgente(String agenteId) async => _agentes.remove(agenteId);

  @override
  Future<List<QueueModel>> carregarFilas(String clinicaId) async =>
      _filas.values.toList();

  @override
  Future<void> salvarFila(String clinicaId, QueueModel fila) async =>
      _filas[fila.id] = fila;

  @override
  Future<void> excluirFila(String filaId) async => _filas.remove(filaId);
}
