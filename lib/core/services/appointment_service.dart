import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/enums.dart';
import 'mock_data.dart';

/// Fonte de agendamentos da clínica ativa (`tb_agendamentos`).
abstract class AppointmentService {
  /// Observa, em tempo real, os agendamentos da clínica [clinicId].
  Stream<List<Appointment>> watchForClinic(String clinicId);

  /// Observa, em tempo real, os agendamentos de um médico ([doctorId]),
  /// independente da clínica — base da agenda pública do médico (PM-09).
  Stream<List<Appointment>> watchForDoctor(String doctorId);

  /// Cria um novo agendamento (`tb_agendamentos`) — usado pelo agendamento
  /// manual da agenda (botão "+") e por outros fluxos de criação.
  Future<void> create(Appointment appointment);

  /// Persiste o novo [status] do agendamento [appointmentId] no documento.
  Future<void> updateStatus(String appointmentId, AppointmentStatus status);

  /// Persiste o novo horário ([newStart]) do agendamento [appointmentId],
  /// marcando-o como pré-agendado (fluxo de remarcação).
  Future<void> reschedule(String appointmentId, DateTime newStart);

  /// Busca o histórico de agendamentos da clínica para a calibração de Monte
  /// Carlo (fase F2). Retorna os últimos [dias] dias de `tb_agendamentos`
  /// enriquecidos com risco de `tb_faltas_data` / `dashboard_risco`.
  ///
  /// Diferente de [watchForClinic] — que observa a agenda operacional recente —
  /// este método faz uma leitura única, paginada, que pode abranger 120–180 dias.
  /// A calibração precisa de histórico; a agenda ao vivo não o fornece.
  Future<List<Appointment>> carregarHistoricoCalibracao(
    String clinicId, {
    int dias = 180,
  });
}

/// Implementação offline/testes — devolve os agendamentos simulados.
class MockAppointmentService implements AppointmentService {
  const MockAppointmentService();

  @override
  Stream<List<Appointment>> watchForClinic(String clinicId) async* {
    yield MockData.appointmentsFor(clinicId);
  }

  @override
  Stream<List<Appointment>> watchForDoctor(String doctorId) async* {
    // Junta os agendamentos de todas as clínicas simuladas e filtra pelo médico.
    final byId = <String, Appointment>{};
    for (final c in MockData.clinics) {
      for (final a in MockData.appointmentsFor(c.id)) {
        if (a.doctorId == doctorId) byId[a.id] = a;
      }
    }
    yield byId.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  // Offline: nada a persistir — o estado local do notifier basta.
  @override
  Future<void> create(Appointment appointment) async {}

  @override
  Future<void> updateStatus(String appointmentId, AppointmentStatus status) async {}

  @override
  Future<void> reschedule(String appointmentId, DateTime newStart) async {}

  @override
  Future<List<Appointment>> carregarHistoricoCalibracao(
    String clinicId, {
    int dias = 180,
  }) async {
    // Mock: retorna todos os agendamentos simulados da clínica (o histórico
    // demo é gerado separadamente pelo provider quando Firebase está inativo).
    return MockData.appointmentsFor(clinicId);
  }
}

/// Implementação Firestore — lê `tb_agendamentos` filtrando pela referência da
/// clínica logada. Os documentos referenciam a clínica em `idClinica` (e, em
/// cadastros antigos, `idclinica`) como `DocumentReference` para `tb_clinica`.
class FirestoreAppointmentService implements AppointmentService {
  FirestoreAppointmentService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<List<Appointment>> watchForClinic(String clinicId) {
    if (clinicId.isEmpty) {
      return Stream<List<Appointment>>.value(const []);
    }
    final clinicRef = _db.collection('tb_clinica').doc(clinicId);
    final col = _db.collection('tb_agendamentos');

    // Combina dois streams (campo `idClinica` e o legado `idclinica`),
    // deduplicando por id de documento — evita a necessidade de índice composto.
    //
    // Após montar a lista base, enriquece cada agendamento com dados de risco
    // de `dashboard_risco` (campo `appointmentId` → join direto). O risco nasce
    // no pipeline de IA e **não** vive em `tb_agendamentos` (ver database.md).
    // O enriquecimento é fire-and-forget: se falhar a query, emite sem risco.
    final controller = StreamController<List<Appointment>>();
    final pages = <String, Map<String, Appointment>>{'a': {}, 'b': {}};
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    
    // Contador de geração: garante que só a chamada MAIS RECENTE emite.
    // Sem isso, dois listeners disparando em sequência criam duas Futures
    // concorrentes; a mais antiga pode concluir DEPOIS e sobrescrever o
    // resultado correto com dados parciais (race condition).
    var gen = 0;

    Future<void> emitWithRisk() async {
      final myGen = ++gen; // captura a geração desta chamada

      final merged = <String, Appointment>{}
        ..addAll(pages['a']!)
        ..addAll(pages['b']!);
      if (merged.isEmpty) {
        if (myGen == gen && !controller.isClosed) controller.add(const []);
        return;
      }

      // Enriquecimento eager: busca risco em `dashboard_risco` para todos os
      // ids presentes no snapshot atual. Usa `whereIn` (limite 30 ids/query).
      final ids = merged.keys.toList();
      final riscoMap = <String, Map<String, dynamic>>{};
      try {
        // Particiona em lotes de 30 (limite do Firestore para `whereIn`).
        for (var i = 0; i < ids.length; i += 30) {
          final batch = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
          final snap = await _db
              .collection('dashboard_risco')
              .where('appointmentId', whereIn: batch)
              .get();
          // Se outra chamada mais recente já está rodando, abandona esta.
          if (myGen != gen) return;
          for (final d in snap.docs) {
            final apptId = d.data()['appointmentId']?.toString() ?? '';
            if (apptId.isNotEmpty) riscoMap[apptId] = d.data();
          }
        }
      } catch (_) {
        // Falha silenciosa — emite sem enriquecimento (comportamento anterior).
      }

      // Verificação final de geração antes de emitir.
      if (myGen != gen || controller.isClosed) return;

      // Mescla risco nos agendamentos que tiverem entrada em dashboard_risco.
      final result = <Appointment>[];
      for (final entry in merged.entries) {
        final a = entry.value;
        final risco = riscoMap[entry.key];
        if (risco == null) {
          result.add(a);
        } else {
          // Converte riscoPercent (0–100) → probabilidade (0–1) para RiskLevel.
          final pct = risco['riscoPercent'] ?? risco['risco'];
          final pFalta = pct is num ? pct.toDouble() / 100 : null;
          final nivel = pFalta != null
              ? RiskLevel.fromScore(pFalta)
              : RiskLevel.fromString(risco['riscoLabel']?.toString()) ??
                  a.patientRisk;
          result.add(a.copyWith(
            patientRisk: nivel,
            pFaltaPrevista: pFalta ?? a.pFaltaPrevista,
          ));
        }
      }

      result.sort((x, y) => x.start.compareTo(y.start));
      if (!controller.isClosed) controller.add(result);
    }

    void bind(String key, String field) {
      final sub =
          col.where(field, isEqualTo: clinicRef).snapshots().listen((snap) {
        final page = <String, Appointment>{};
        for (final doc in snap.docs) {
          try {
            final a = _fromDoc(doc.id, doc.data());
            if (a != null) page[doc.id] = a;
          } catch (_) {
            // Ignora documento malformado.
          }
        }
        pages[key] = page;
        emitWithRisk();
      }, onError: (_) {
        pages[key] = {};
        emitWithRisk();
      });
      subs.add(sub);
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    bind('a', 'idClinica');
    bind('b', 'idclinica');
    return controller.stream;
  }

  @override
  Stream<List<Appointment>> watchForDoctor(String doctorId) {
    if (doctorId.isEmpty) {
      return Stream<List<Appointment>>.value(const []);
    }
    final doctorRef = _db.collection('tb_medicos').doc(doctorId);
    final col = _db.collection('tb_agendamentos');

    // `idMedico` aparece como DocumentReference, id "cru" ou caminho
    // `tb_medicos/<id>`. Observa os três e deduplica por id de documento —
    // evita consulta sumir por diferença de tipo do campo.
    final controller = StreamController<List<Appointment>>();
    final pages = <String, Map<String, Appointment>>{
      'ref': {},
      'id': {},
      'path': {},
    };
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final merged = <String, Appointment>{}
        ..addAll(pages['ref']!)
        ..addAll(pages['id']!)
        ..addAll(pages['path']!);
      final list = merged.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      if (!controller.isClosed) controller.add(list);
    }

    void bind(String key, Object value) {
      final sub =
          col.where('idMedico', isEqualTo: value).snapshots().listen((snap) {
        final page = <String, Appointment>{};
        for (final doc in snap.docs) {
          try {
            final a = _fromDoc(doc.id, doc.data());
            if (a != null) page[doc.id] = a;
          } catch (_) {
            // Ignora documento malformado.
          }
        }
        pages[key] = page;
        emit();
      }, onError: (_) {
        pages[key] = {};
        emit();
      });
      subs.add(sub);
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    bind('ref', doctorRef);
    bind('id', doctorId);
    bind('path', 'tb_medicos/$doctorId');
    return controller.stream;
  }

  @override
  Future<void> create(Appointment a) {
    final col = _db.collection('tb_agendamentos');
    // Usa o id do próprio agendamento como id do documento (o leitor deduplica
    // por id) — assim a escrita otimista e o snapshot do servidor convergem.
    final ref = a.id.isEmpty ? col.doc() : col.doc(a.id);
    return ref.set({
      // Referências, no formato que `_fromDoc` sabe ler (DocumentReference).
      'idClinica': _db.collection('tb_clinica').doc(a.clinicId),
      'idMedico': _db.collection('tb_medicos').doc(a.doctorId),
      'idPaciente': a.patientId,
      'nomePaciente': a.patientName,
      'nomeMedico': a.doctorName,
      'especialidade': a.specialty,
      'dataConsulta': Timestamp.fromDate(a.start),
      'duracao': a.durationMinutes,
      'status': _statusLabel(a.status),
      'tipoConsulta': a.tipoConsulta,
      'modalidade': a.modalidade,
      'local': a.local,
      'motivo': a.motivo,
      'observacoes': a.observacoes,
      'crm': a.crm,
      'telefonePaciente': a.patientPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateStatus(String appointmentId, AppointmentStatus status) {
    if (appointmentId.isEmpty) return Future<void>.value();
    return _db
        .collection('tb_agendamentos')
        .doc(appointmentId)
        .update({'status': _statusLabel(status)});
  }

  @override
  Future<void> reschedule(String appointmentId, DateTime newStart) {
    if (appointmentId.isEmpty) return Future<void>.value();
    return _db.collection('tb_agendamentos').doc(appointmentId).update({
      'dataConsulta': Timestamp.fromDate(newStart),
      'status': _statusLabel(AppointmentStatus.pending),
    });
  }

  /// Busca o histórico histórico de [dias] dias para calibração de Monte Carlo.
  ///
  /// Estratégia em três camadas (custo mínimo de leitura):
  ///
  /// 1. Consulta paginada em `tb_agendamentos` filtrando por clínica e data.
  /// 2. Consulta em `tb_faltas_data` para enriquecer risco/probabilidade.
  /// 3. Consulta em `dashboard_risco` para cobrir consultas sem registro em
  ///    `tb_faltas_data`.
  ///
  /// Além disso, infere `completed` para agendamentos `confirmado`/`agendado`
  /// que ocorreram antes de ontem e não têm registro de falta — resolve o viés
  /// de "base que só registra fracasso" quando a clínica não dá baixa manual.
  @override
  Future<List<Appointment>> carregarHistoricoCalibracao(
    String clinicId, {
    int dias = 180,
  }) async {
    if (clinicId.isEmpty) return const [];

    final clinicRef = _db.collection('tb_clinica').doc(clinicId);
    final limite = Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: dias)),
    );
    // Ontem ao fim do dia — consultas confirmadas mais antigas que isso e sem
    // registro de falta são inferidas como realizadas.
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    final limiteInferencia = DateTime(
        ontem.year, ontem.month, ontem.day, 23, 59);

    // ── 1. Agendamentos da janela ─────────────────────────────────────────────
    final col = _db.collection('tb_agendamentos');
    // Map<id, dados> para deduplicar documentos que aparecem nos dois buckets.
    final docs = <String, Map<String, dynamic>>{};

    // Tamanho de página e teto de segurança da varredura.
    //
    // Antes disto era uma única página de 800 — e "paginada" no comentário da
    // classe era aspiracional, não real. Para uma clínica com >800 consultas
    // nos [dias] pedidos, `orderBy(dataConsulta, descending: true).limit(800)`
    // devolve só as mais recentes: 800 consultas a 50/dia são 16 dias, não os
    // 120–180 que a fase F2 exige. A aba de Calibração media exatamente isso
    // ("histórico curto: 16 dias") mesmo com `dias: 180` na chamada — o filtro
    // pedia 180 dias, o limite entregava 16.
    //
    // `_maxPaginas * _tamanhoPagina` é o teto real de leituras por chamada;
    // ainda existe por custo, mas agora é 5× maior e, principalmente,
    // percorre o período pedido em vez de parar na primeira página.
    const tamanhoPagina = 800;
    const maxPaginas = 5;

    Future<void> fetchPage(String field, Object value) async {
      try {
        DocumentSnapshot<Map<String, dynamic>>? cursor;
        for (var pagina = 0; pagina < maxPaginas; pagina++) {
          var q = col
              .where(field, isEqualTo: value)
              .where('dataConsulta', isGreaterThanOrEqualTo: limite)
              .orderBy('dataConsulta', descending: true)
              .limit(tamanhoPagina);
          if (cursor != null) q = q.startAfterDocument(cursor);

          final snap = await q.get();
          for (final d in snap.docs) {
            docs[d.id] = d.data();
          }
          // Página incompleta = não há mais documentos na janela: parar aqui
          // evita uma leitura extra que sempre voltaria vazia.
          if (snap.docs.length < tamanhoPagina) break;
          cursor = snap.docs.last;
        }
      } catch (_) {
        // Índice ausente ou permissão negada — segue sem esse bucket.
      }
    }

    await Future.wait([
      fetchPage('idClinica', clinicRef),
      fetchPage('idclinica', clinicRef),
    ]);

    if (docs.isEmpty) return const [];

    // ── 2. tb_faltas_data — risco e probabilidade por consulta ───────────────
    // Chave: appointmentId (campo `_debug_agendamentoId` ou `idConsulta.id`).
    //
    // Mesma paginação por cursor do passo 1, e pelo mesmo motivo: sem
    // `orderBy`, um corte em 800 devolve um subconjunto em ordem não garantida
    // pelo Firestore — para uma clínica com mais de 800 predições na janela, o
    // corte podia não ter interseção nenhuma com as consultas já carregadas, e
    // o enriquecimento de risco falhava silenciosamente mesmo havendo dado.
    final riscoMap = <String, Map<String, dynamic>>{};
    try {
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      for (var pagina = 0; pagina < maxPaginas; pagina++) {
        var q = _db
            .collection('tb_faltas_data')
            .where('idclinica', isEqualTo: clinicRef)
            .where('data_consulta', isGreaterThanOrEqualTo: limite)
            .orderBy('data_consulta', descending: true)
            .limit(tamanhoPagina);
        if (cursor != null) q = q.startAfterDocument(cursor);

        final snap = await q.get();
        for (final d in snap.docs) {
          final data = d.data();
          // Tenta associar pelo id do agendamento registrado no documento.
          final apptId = data['_debug_agendamentoId']?.toString() ??
              _refId(data['idConsulta']);
          if (apptId.isNotEmpty) riscoMap[apptId] = data;
        }
        if (snap.docs.length < tamanhoPagina) break;
        cursor = snap.docs.last;
      }
    } catch (_) {
      // Índice ausente ou permissão negada — calibra sem enriquecimento de risco.
    }

    // ── 3. dashboard_risco — fallback de risco por appointmentId ─────────────
    //
    // Mesma classe de bug dos passos 1 e 2, corrigida do mesmo jeito: uma
    // página de 500 não cobre clínica com mais documentos que isso.
    //
    // A ordenação aqui é por `FieldPath.documentId`, não por data. Ordenar por
    // `timestampConsulta` (o campo cronológico do schema) exigiria um índice
    // composto `(clinica, timestampConsulta)` que **não existe hoje** —
    // publicá-lo é passo de deploy separado, e pedir uma ordenação sem índice
    // não lança erro visível: cai no `catch` mudo abaixo e esta camada, que já
    // é o fallback de terceira linha, voltaria a ficar vazia sem ninguém
    // notar. Ordenar por id do documento não precisa de índice — funciona
    // hoje — e para esta camada a ordem cronológica não importa: o objetivo é
    // só não parar de enxergar risco na metade da clínica.
    final dashMap = <String, Map<String, dynamic>>{};
    try {
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      for (var pagina = 0; pagina < maxPaginas; pagina++) {
        var q = _db
            .collection('dashboard_risco')
            .where('clinica', isEqualTo: clinicId)
            .orderBy(FieldPath.documentId)
            .limit(tamanhoPagina);
        if (cursor != null) q = q.startAfterDocument(cursor);

        final snap = await q.get();
        for (final d in snap.docs) {
          final data = d.data();
          final apptId = data['appointmentId']?.toString() ?? '';
          if (apptId.isNotEmpty) dashMap[apptId] = data;
        }
        if (snap.docs.length < tamanhoPagina) break;
        cursor = snap.docs.last;
      }
    } catch (_) {
      // Falha silenciosa — segue sem este fallback de risco.
    }

    // ── 4. Montar Appointment com risco enriquecido e inferência de status ───
    final result = <Appointment>[];
    for (final entry in docs.entries) {
      final id = entry.key;
      final d = entry.value;
      final start = _parseStart(d);
      if (start == null) continue;

      // Status base do documento.
      var status = AppointmentStatus.fromString(d['status']?.toString());

      // Inferência: agendamento confirmado no passado sem registro de falta
      // → considera realizado. Resolve o viés quando a clínica não dá baixa.
      if (start.isBefore(limiteInferencia) &&
          (status == AppointmentStatus.confirmed ||
           status == AppointmentStatus.pending)) {
        status = AppointmentStatus.completed;
      }

      // Enriquecimento de risco: tb_faltas_data > dashboard_risco > campo local.
      final riscoData = riscoMap[id] ?? dashMap[id];
      Map<String, dynamic> merged;
      if (riscoData != null) {
        // Mescla os dados de risco sobre o documento do agendamento.
        merged = {...d};
        merged['probabilidade_falta'] =
            riscoData['probabilidade_falta'] ?? merged['probabilidade_falta'];
        merged['risco_falta'] =
            riscoData['risco_falta'] ?? merged['risco_falta'];
        merged['riscoPercent'] =
            riscoData['riscoPercent'] ?? riscoData['risco'] ?? merged['riscoPercent'];
      } else {
        merged = d;
      }

      try {
        final a = _fromDoc(id, merged);
        if (a != null) {
          // Aplica o status inferido.
          result.add(a.copyWith(status: status));
        }
      } catch (_) {
        // Documento malformado — descarta.
      }
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  /// Rótulo textual gravado em `tb_agendamentos` — delega ao mapeamento
  /// canônico do enum (`AppointmentStatus.apiLabel`), fonte única de escrita.
  String _statusLabel(AppointmentStatus s) => s.apiLabel;

  /// Converte um documento de `tb_agendamentos` em [Appointment]. Retorna `null`
  /// quando não há data válida (registro inutilizável para a agenda).
  Appointment? _fromDoc(String id, Map<String, dynamic> d) {
    final start = _parseStart(d);
    if (start == null) return null;

    return Appointment(
      id: id,
      clinicId: _refId(d['idClinica'] ?? d['idclinica']),
      patientId: _refId(d['idPaciente']),
      patientName:
          (d['nomePaciente'] ?? d['paciente'] ?? 'Paciente').toString(),
      doctorId: _refId(d['idMedico']),
      doctorName: (d['nomeMedico'] ?? d['medico'] ?? '').toString(),
      specialty: (d['especialidade'] ?? '').toString(),
      start: start,
      durationMinutes: _int(d['duracao'] ?? d['duracaoMinutos'], 30),
      status: AppointmentStatus.fromString(d['status']?.toString()),
      tipoConsulta: (d['tipoConsulta'] ?? 'Consulta').toString(),
      modalidade: (d['modalidade'] ?? 'Presencial').toString(),
      local: (d['local'] ?? d['unidade'] ?? '').toString(),
      motivo: (d['motivoConsulta'] ?? d['motivo'] ?? '').toString(),
      observacoes: (d['observacoes'] ?? '').toString(),
      crm: (d['crm'] ?? d['crmMedico'] ?? '').toString(),
      patientPhone:
          (d['telefonePaciente'] ?? d['telefone'] ?? '').toString(),
      // O risco canônico vive em `tb_faltas_data`, não aqui. Estes campos
      // existem quando o pipeline denormaliza a predição no agendamento; sem
      // eles o construtor cai em `RiskLevel.low` e a estratificação some.
      patientRisk: _risco(d) ?? RiskLevel.low,
      pFaltaPrevista: _prob(d['probabilidade_falta'] ?? d['probabilidadeFalta']),
    );
  }

  /// Faixa de risco a partir de qualquer campo conhecido, em ordem de
  /// precedência: probabilidade numérica > rótulo > escore.
  RiskLevel? _risco(Map<String, dynamic> d) {
    final p = _prob(d['probabilidade_falta'] ?? d['probabilidadeFalta']);
    if (p != null) return RiskLevel.fromScore(p);

    final rotulo = RiskLevel.fromString(
        (d['risco_falta'] ?? d['riscoFalta'] ?? d['risco'])?.toString());
    if (rotulo != null) return rotulo;

    final escore = _prob(d['riscoPercent']);
    if (escore != null) return RiskLevel.fromScore(escore / 100);
    return null;
  }

  double? _prob(dynamic v) {
    if (v is num) {
      final d = v.toDouble();
      return d >= 0 && d <= 1 ? d : null;
    }
    if (v is String) {
      final d = double.tryParse(v.replaceAll(',', '.'));
      return (d != null && d >= 0 && d <= 1) ? d : null;
    }
    return null;
  }

  /// Extrai o id de uma referência (`DocumentReference`) ou de uma string.
  String _refId(dynamic v) {
    if (v is DocumentReference) return v.id;
    if (v is String) {
      // Aceita caminhos como `tb_clinica/abc` → `abc`.
      return v.contains('/') ? v.split('/').last : v;
    }
    return '';
  }

  int _int(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Lê a data/hora da consulta. Aceita `dataConsulta` como `Timestamp`,
  /// `DateTime` ou string ISO; cai para `data` + `hora` quando necessário.
  DateTime? _parseStart(Map<String, dynamic> d) {
    final raw = d['dataConsulta'] ?? d['data'] ?? d['start'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final iso = DateTime.tryParse(raw);
      if (iso != null) return iso;
    }
    // Combinação `data` (Timestamp/String) + `hora` ("HH:mm").
    final data = d['data'];
    DateTime? base;
    if (data is Timestamp) {
      base = data.toDate();
    } else if (data is String) {
      base = DateTime.tryParse(data);
    }
    if (base == null) return null;
    final hora = d['hora']?.toString();
    if (hora != null && hora.contains(':')) {
      final parts = hora.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateTime(base.year, base.month, base.day, h, m);
    }
    return base;
  }
}
