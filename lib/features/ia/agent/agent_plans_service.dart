import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';

/// Serviço de persistência para planos multi-agente e relatórios de IA.
/// Isolamento multi-tenant: todo documento é carimbado com [idclinica].
class AgentPlansService {
  AgentPlansService(this._db);

  final FirebaseFirestore _db;

  // ── Coleções ────────────────────────────────────────────────────────────────
  CollectionReference get _plans => _db.collection('tb_agent_plans');
  CollectionReference get _reports => _db.collection('tb_relatorio_ia');
  CollectionReference get _scheduled => _db.collection('tb_scheduled_reports');

  /// Grava um plano finalizado em `tb_agent_plans`. Retorna o id do documento.
  Future<String> savePlan({
    required String objective,
    required List<Map<String, dynamic>> tasks,
    required String synthesis,
    required String clinicaId,
  }) async {
    final ref = await _plans.add({
      'objetivo': objective,
      'tasks': tasks,
      'sintese': synthesis,
      'idclinica': clinicaId,
      'status': 'done',
      'origem': 'app',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Grava um relatório em `tb_relatorio_ia` E em `tb_scheduled_reports`.
  Future<void> saveReport({
    required String titulo,
    required String conteudoMarkdown,
    required String clinicaId,
    String tipoRelatorio = 'agente_multiagente',
  }) async {
    final timestamp = FieldValue.serverTimestamp();

    await Future.wait([
      _reports.add({
        'titulo': titulo,
        'markdown': conteudoMarkdown,
        'idclinica': clinicaId,
        'tipoRelatorio': tipoRelatorio,
        'createdAt': timestamp,
      }),
      _scheduled.add({
        'titulo': titulo,
        'conteudo': conteudoMarkdown,
        'idclinica': clinicaId,
        'tipoRelatorio': tipoRelatorio,
        'createdAt': timestamp,
      }),
    ]);
  }

  /// Stream de planos salvos para a clínica. Ordenação por `createdAt` desc
  /// feita em memória para evitar índice composto no Firestore.
  Stream<List<Map<String, dynamic>>> watchPlans(String clinicaId) {
    return _plans
        .where('idclinica', isEqualTo: clinicaId)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return _normalize(d.id, data);
      }).toList();
      docs.sort((a, b) {
        final dA = a['createdAt'] as String? ?? '';
        final dB = b['createdAt'] as String? ?? '';
        return dB.compareTo(dA);
      });
      return docs;
    });
  }

  /// Stream de relatórios de IA para a clínica. Ordenação em memória.
  Stream<List<Map<String, dynamic>>> watchReports(String clinicaId) {
    return _reports
        .where('idclinica', isEqualTo: clinicaId)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return _normalize(d.id, data);
      }).toList();
      docs.sort((a, b) {
        final dA = a['createdAt'] as String? ?? '';
        final dB = b['createdAt'] as String? ?? '';
        return dB.compareTo(dA);
      });
      return docs;
    });
  }

  /// Converte [Timestamp] → ISO-8601 string e injeta o [id] do documento.
  Map<String, dynamic> _normalize(String id, Map<String, dynamic> data) {
    final result = <String, dynamic>{'id': id};
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is Timestamp) {
        result[entry.key] = v.toDate().toIso8601String();
      } else {
        result[entry.key] = v;
      }
    }
    
    // Fallbacks caso o documento possua a chave com outro nome
    if (result['titulo'] == null || result['titulo'].toString().trim().isEmpty) {
      final t = result['title'] ?? result['nome'] ?? result['name'] ?? result['assunto'];
      if (t != null && t.toString().trim().isNotEmpty) {
        result['titulo'] = t;
      }
    }

    return result;
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Instância do serviço. Usa `FirebaseFirestore.instance` diretamente;
/// aceitável pois o Firebase é inicializado antes dos providers em `main`.
final agentPlansServiceProvider = Provider<AgentPlansService>((ref) {
  return AgentPlansService(FirebaseFirestore.instance);
});

/// Stream dos planos salvos para a clínica ativa.
final savedPlansProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final clinicaId = ref.watch(selectedClinicIdProvider);
  if (clinicaId.isEmpty) return const Stream.empty();
  return ref.read(agentPlansServiceProvider).watchPlans(clinicaId);
});

/// Stream dos relatórios de IA para a clínica ativa.
final savedReportsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final clinicaId = ref.watch(selectedClinicIdProvider);
  if (clinicaId.isEmpty) return const Stream.empty();
  return ref.read(agentPlansServiceProvider).watchReports(clinicaId);
});
