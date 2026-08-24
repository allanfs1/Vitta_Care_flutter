import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/relatorio.dart';

/// Persistência dos relatórios (`tb_relatorio_ia`).
///
/// Coleção deliberadamente compartilhada com o agente de IA
/// (`agent_plans_service.saveReport`): relatório gerado pela IA e relatório
/// gerado na tela são a mesma coisa para quem lê, e antes viviam em lugares
/// diferentes — a tela mostrava um seed em memória e ignorava o que a IA
/// produzia.
///
/// O campo de clínica aqui é `idclinica`, não `clinicaId`: é o nome que a IA
/// já usa nesta coleção, e mudar quebraria os relatórios existentes.
abstract class RelatoriosRepository {
  Future<List<Relatorio>> carregar(String clinicaId);
  Future<void> salvar(String clinicaId, Relatorio relatorio);
}

class FirestoreRelatoriosRepository implements RelatoriosRepository {
  FirestoreRelatoriosRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String colecao = 'tb_relatorio_ia';
  static const int limite = 200;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(colecao);

  @override
  Future<List<Relatorio>> carregar(String clinicaId) async {
    if (clinicaId.isEmpty) return const [];
    // Sem `orderBy` na query (evita exigir índice composto); o volume cabe
    // folgado na ordenação em cliente.
    final snap =
        await _col.where('idclinica', isEqualTo: clinicaId).limit(limite).get();
    final out = snap.docs.map((d) => _deMapa(d.id, d.data())).toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<void> salvar(String clinicaId, Relatorio r) {
    return _col.doc(r.id).set({
      'idclinica': clinicaId,
      'titulo': r.title,
      'markdown': r.body,
      'tipoRelatorio': r.type.name,
      'periodo': r.period,
      'metricas': [
        for (final m in r.metrics) {'label': m.label, 'valor': m.value},
      ],
      'createdAt': Timestamp.fromDate(r.createdAt),
    }, SetOptions(merge: true));
  }

  /// Aceita tanto o formato desta tela quanto o que a IA grava — que só tem
  /// `titulo`, `markdown` e `tipoRelatorio` livre.
  static Relatorio _deMapa(String id, Map<String, dynamic> d) {
    final criado = d['createdAt'];
    return Relatorio(
      id: id,
      title: (d['titulo'] ?? 'Relatório').toString(),
      type: RelatorioType.values.firstWhere(
        (t) => t.name == d['tipoRelatorio'],
        // Relatório vindo do agente (`agente_multiagente`) é relatório de IA.
        orElse: () => RelatorioType.ia,
      ),
      createdAt: criado is Timestamp ? criado.toDate() : DateTime.now(),
      period: (d['periodo'] ?? '—').toString(),
      body: (d['markdown'] ?? d['conteudo'] ?? '').toString(),
      metrics: [
        for (final m in (d['metricas'] as List? ?? const []))
          if (m is Map)
            RelatorioMetric(
              (m['label'] ?? '').toString(),
              (m['valor'] ?? '').toString(),
            ),
      ],
    );
  }
}

/// Implementação em memória — modo demonstração e testes.
class MemoriaRelatoriosRepository implements RelatoriosRepository {
  MemoriaRelatoriosRepository([List<Relatorio> inicial = const []]) {
    for (final r in inicial) {
      _itens[r.id] = r;
    }
  }

  final Map<String, Relatorio> _itens = {};

  @override
  Future<List<Relatorio>> carregar(String clinicaId) async {
    final out = _itens.values.toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<void> salvar(String clinicaId, Relatorio relatorio) async =>
      _itens[relatorio.id] = relatorio;
}
