import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/doctor.dart';
import 'mock_data.dart';

/// Fonte da equipe médica da clínica ativa (`tb_medicos`).
abstract class DoctorService {
  /// Valor síncrono inicial (offline/primeiro frame) enquanto o stream carrega.
  List<Doctor> seed(String clinicId);

  /// Observa, em tempo real, os médicos da clínica [clinicId] (`idclinica`).
  Stream<List<Doctor>> watchForClinic(String clinicId);

  /// Observa todos os médicos (`tb_medicos`) — catálogo global usado em
  /// seleções que não dependem da clínica ativa (totem, detalhe da consulta).
  Stream<List<Doctor>> watchAll();

  /// Cria ou atualiza o documento do médico em `tb_medicos`.
  Future<void> upsert(Doctor doctor);

  /// Persiste o status ativo/inativo (`status`) do médico.
  Future<void> setActive(String doctorId, bool active);

  /// Busca um médico por id (`tb_medicos/{id}`), independente da clínica —
  /// usado pela agenda pública do médico.
  Future<Doctor?> fetchById(String id);
}

/// Implementação offline/testes — usa os médicos simulados, filtrando pela
/// clínica quando houver vínculo e caindo para todos quando não houver
/// (evita lista vazia em dados mock/legados).
class MockDoctorService implements DoctorService {
  const MockDoctorService();

  List<Doctor> _forClinic(String clinicId) {
    final linked =
        MockData.doctors.where((d) => d.clinicId == clinicId).toList();
    return linked.isNotEmpty ? linked : MockData.doctors;
  }

  @override
  List<Doctor> seed(String clinicId) => _forClinic(clinicId);

  @override
  Stream<List<Doctor>> watchForClinic(String clinicId) async* {
    yield _forClinic(clinicId);
  }

  @override
  Stream<List<Doctor>> watchAll() async* {
    yield MockData.doctors;
  }

  // Offline: nada a persistir — o estado local do notifier basta.
  @override
  Future<void> upsert(Doctor doctor) async {}

  @override
  Future<void> setActive(String doctorId, bool active) async {}

  @override
  Future<Doctor?> fetchById(String id) async {
    for (final d in MockData.doctors) {
      if (d.id == id) return d;
    }
    return null;
  }
}

/// Implementação Firestore — lê/escreve `tb_medicos` filtrando pela referência
/// da clínica logada. O vínculo com a clínica é `idclinica` (`DocumentReference`
/// para `tb_clinica`; em cadastros antigos pode vir como string/caminho).
class FirestoreDoctorService implements DoctorService {
  FirestoreDoctorService([FirebaseFirestore? db, FirebaseStorage? storage])
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tb_medicos');

  @override
  List<Doctor> seed(String clinicId) => const [];

  @override
  Stream<List<Doctor>> watchForClinic(String clinicId) {
    if (clinicId.isEmpty) {
      return Stream<List<Doctor>>.value(const []);
    }
    final clinicRef = _db.collection('tb_clinica').doc(clinicId);

    // `idclinica` aparece em três formatos entre cadastros: DocumentReference,
    // id "cru" (string) ou caminho "tb_clinica/<id>". Observa os três e
    // deduplica por id de documento — evita médico sumir por diferença de tipo.
    final controller = StreamController<List<Doctor>>();
    final pages = <String, Map<String, Doctor>>{'ref': {}, 'id': {}, 'path': {}};
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final merged = <String, Doctor>{}
        ..addAll(pages['ref']!)
        ..addAll(pages['id']!)
        ..addAll(pages['path']!);
      final list = merged.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (!controller.isClosed) controller.add(list);
    }

    void bind(String key, Object value) {
      final sub =
          _col.where('idclinica', isEqualTo: value).snapshots().listen((snap) {
        final page = <String, Doctor>{};
        for (final doc in snap.docs) {
          try {
            page[doc.id] = _fromDoc(doc.id, doc.data());
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

    bind('ref', clinicRef);
    bind('id', clinicId);
    bind('path', 'tb_clinica/$clinicId');
    return controller.stream;
  }

  @override
  Stream<List<Doctor>> watchAll() {
    return _col.snapshots().map((snap) {
      final doctors = <Doctor>[];
      for (final doc in snap.docs) {
        try {
          doctors.add(_fromDoc(doc.id, doc.data()));
        } catch (_) {
          // Ignora documento malformado.
        }
      }
      doctors.sort((a, b) => a.name.compareTo(b.name));
      return doctors;
    });
  }

  @override
  Future<void> upsert(Doctor d) async {
    // Se há uma foto recém-escolhida (bytes locais), envia ao Storage e usa a
    // URL pública como `fotoPerfil`. Se o upload falhar, segue sem bloquear o
    // cadastro (mantém a URL anterior, se houver).
    var photoUrl = d.photoUrl;
    final bytes = d.photoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      try {
        photoUrl = await _uploadPhoto(d.id, bytes);
      } catch (_) {
        // Mantém `photoUrl` atual; a foto continua disponível localmente.
      }
    }

    final data = <String, dynamic>{
      'nomeCompleto': d.name,
      'crm': d.crm,
      'especialidades': d.specialties,
      'idclinica': _db.collection('tb_clinica').doc(d.clinicId),
      'email': d.email ?? '',
      'telefone': d.phone ?? '',
      'endereco': d.address ?? '',
      'biografia': d.bio ?? '',
      'experiencia': d.experience ?? '',
      'status': d.active,
      'tiket': d.ticket,
      'scalaMedico': d.scaleHours,
      'dataAtualizacao': FieldValue.serverTimestamp(),
      if (photoUrl != null && photoUrl.isNotEmpty) 'fotoPerfil': photoUrl,
      if (d.createdAt != null)
        'dataCriacao': Timestamp.fromDate(d.createdAt!)
      else
        'dataCriacao': FieldValue.serverTimestamp(),
    };
    // `set` com merge cria (novo) ou atualiza (edição) mantendo campos extras
    // do documento (estatísticas, configurações de overbooking, etc.).
    await _col.doc(d.id).set(data, SetOptions(merge: true));
  }

  /// Envia a foto do médico para `medicos/<id>/perfil.jpg` e retorna a URL de
  /// download.
  Future<String> _uploadPhoto(String doctorId, Uint8List bytes) async {
    final ref = _storage.ref('medicos/$doctorId/perfil.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  @override
  Future<void> setActive(String doctorId, bool active) {
    if (doctorId.isEmpty) return Future<void>.value();
    return _col.doc(doctorId).update({
      'status': active,
      'dataAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Doctor?> fetchById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return _fromDoc(doc.id, data);
  }

  Doctor _fromDoc(String id, Map<String, dynamic> d) {
    final stats = (d['estatisticas'] as Map?)?.cast<String, dynamic>() ?? {};
    return Doctor(
      id: id,
      name: (d['nomeCompleto'] ?? d['nome'] ?? 'Sem nome').toString(),
      crm: (d['crm'] ?? '').toString(),
      specialties: _stringList(d['especialidades']),
      clinicId: _refId(d['idclinica'] ?? d['idClinica']),
      photoUrl: (d['fotoPerfil'] ?? d['photoUrl'])?.toString(),
      email: (d['email'] ?? '').toString(),
      phone: (d['telefone'] ?? '').toString(),
      address: (d['endereco'] ?? '').toString(),
      bio: (d['biografia'] ?? '').toString(),
      experience: (d['experiencia'] ?? '').toString(),
      active: d['status'] is bool ? d['status'] as bool : true,
      ticket: _num(d['tiket']).toDouble(),
      scaleHours: _num(d['scalaMedico'], 8).toInt(),
      monthlyConsultations: _num(stats['totalConsultasMes']).toInt(),
      occupancyRate: _rate(stats['taxaOcupacaoMedia']),
      absenceRate: _rate(stats['mediaFaltas']),
      maxOverbook: _num(d['maxOverbook']).toInt(),
      createdAt: _date(d['dataCriacao']),
      updatedAt: _date(d['dataAtualizacao']),
    );
  }

  String _refId(dynamic v) {
    if (v is DocumentReference) return v.id;
    if (v is String) return v.contains('/') ? v.split('/').last : v;
    return '';
  }

  List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  num _num(dynamic v, [num fallback = 0]) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Normaliza taxas para 0..1 — aceita tanto fração (0.82) quanto
  /// porcentagem (82) gravada no Firestore.
  double _rate(dynamic v) {
    final n = _num(v).toDouble();
    return n > 1 ? n / 100 : n;
  }

  DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
