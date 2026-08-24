import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/clinic.dart';
import 'mock_data.dart';

abstract class ClinicService {
  Stream<List<Clinic>> watchClinics();

  /// Busca uma clínica pelo campo `email` da `tb_clinica`.
  /// Permite login com o e-mail da clínica (em vez do e-mail pessoal do usuário).
  Future<Clinic?> fetchByEmail(String email);
}

class MockClinicService implements ClinicService {
  const MockClinicService();

  @override
  Stream<List<Clinic>> watchClinics() async* {
    yield MockData.clinics;
  }

  @override
  Future<Clinic?> fetchByEmail(String email) async {
    final e = email.trim().toLowerCase();
    for (final c in MockData.clinics) {
      if (c.email?.toLowerCase() == e) return c;
    }
    return null;
  }
}

class FirestoreClinicService implements ClinicService {
  FirestoreClinicService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<List<Clinic>> watchClinics() {
    return _db.collection('tb_clinica').snapshots().map((snap) {
      final clinics = <Clinic>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          if (data['deleted'] == true) continue;
          clinics.add(Clinic.fromFirestore(doc.id, data));
        } catch (e) {
          // Log ou ignora documento malformado
        }
      }
      return clinics;
    });
  }

  @override
  Future<Clinic?> fetchByEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return null;
    // Busca pelo campo `email` na coleção `tb_clinica`.
    final snap = await _db
        .collection('tb_clinica')
        .where('email', isEqualTo: e)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final d = snap.docs.first;
      return Clinic.fromFirestore(d.id, d.data());
    }
    // Tenta sem normalizar (alguns cadastros mantêm case original).
    if (e != email.trim()) {
      final snap2 = await _db
          .collection('tb_clinica')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (snap2.docs.isNotEmpty) {
        final d = snap2.docs.first;
        return Clinic.fromFirestore(d.id, d.data());
      }
    }
    return null;
  }
}
