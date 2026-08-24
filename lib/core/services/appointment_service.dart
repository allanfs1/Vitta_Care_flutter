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
    final controller = StreamController<List<Appointment>>();
    final pages = <String, Map<String, Appointment>>{'a': {}, 'b': {}};
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final merged = <String, Appointment>{}
        ..addAll(pages['a']!)
        ..addAll(pages['b']!);
      final list = merged.values.toList()
        ..sort((x, y) => x.start.compareTo(y.start));
      if (!controller.isClosed) controller.add(list);
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
    );
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
