import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'mock_data.dart';

/// Carrega o perfil do usuário autenticado a partir da coleção `users`.
abstract class UserService {
  /// Busca o usuário pelo `uid` do Firebase Auth (ou `null` se não achar).
  Future<AppUser?> fetchByUid(String uid);

  /// Busca o usuário pelo `email` — chave estável compartilhada entre o
  /// Firebase Auth e a coleção `users` (os `uid` podem divergir após migração).
  Future<AppUser?> fetchByEmail(String email);

  /// Busca um usuário/paciente pelo **CPF** na coleção `users` (usado pelo
  /// totem). Aceita CPF com ou sem máscara.
  Future<AppUser?> fetchByCpf(String cpf);

  /// Grava as alterações de perfil em `users/{id}` e devolve o usuário salvo.
  ///
  /// Escrita **parcial** (merge): só os campos de [AppUser.toFirestore] são
  /// tocados, para que uma edição de perfil nunca apague `roles`, `idclinica`
  /// ou qualquer campo administrado fora do app.
  Future<AppUser> salvar(AppUser user);
}

/// Erro de gravação de perfil já traduzido para linguagem de usuário.
class UserServiceException implements Exception {
  const UserServiceException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Implementação real: consulta `users` onde `uid == <authUid>` (ou doc por id).
class FirestoreUserService implements UserService {
  FirestoreUserService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<AppUser?> fetchByUid(String uid) async {
    // 1) documento cujo id é o próprio uid — caminho confiável: as regras do
    //    Firestore normalmente permitem `get` do próprio doc (users/{uid}),
    //    mas BLOQUEIAM list/queries na coleção. Por isso vem primeiro.
    final byDoc = await _db.collection('users').doc(uid).get();
    if (byDoc.exists) {
      return AppUser.fromFirestore(byDoc.id, byDoc.data()!);
    }
    // 2) fallback: campo `uid` (pode ser negado por regras de list → ignora).
    try {
      final byField = await _db
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (byField.docs.isNotEmpty) {
        final d = byField.docs.first;
        return AppUser.fromFirestore(d.id, d.data());
      }
    } catch (_) {
      // Query bloqueada por regras de segurança — segue sem ela.
    }
    return null;
  }

  @override
  Future<AppUser?> fetchByEmail(String email) async {
    final candidates = <String>{email.trim(), email.trim().toLowerCase()};
    for (final value in candidates) {
      if (value.isEmpty) continue;
      try {
        final snap = await _db
            .collection('users')
            .where('email', isEqualTo: value)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final d = snap.docs.first;
          return AppUser.fromFirestore(d.id, d.data());
        }
      } catch (_) {
        // Query bloqueada por regras de segurança (list) — ignora.
      }
    }
    return null;
  }

  @override
  Future<AppUser?> fetchByCpf(String cpf) async {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return null;
    final masked =
        '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
    // Tenta o CPF numérico e o mascarado (a base pode guardar de qualquer forma).
    for (final value in [digits, masked]) {
      try {
        final snap = await _db
            .collection('users')
            .where('cpf', isEqualTo: value)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final d = snap.docs.first;
          return AppUser.fromFirestore(d.id, d.data());
        }
      } catch (_) {
        // Query bloqueada por regras — tenta o próximo formato.
      }
    }
    return null;
  }

  @override
  Future<AppUser> salvar(AppUser user) async {
    if (user.id.isEmpty) {
      throw const UserServiceException(
        'Perfil sem identificador — faça login novamente para salvar.',
      );
    }
    try {
      await _db
          .collection('users')
          .doc(user.id)
          .set(user.toFirestore(), SetOptions(merge: true));
      return user;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const UserServiceException(
          'Você não tem permissão para alterar este perfil.',
        );
      }
      throw UserServiceException('Não foi possível salvar: ${e.code}');
    }
  }
}

/// Implementação simulada (offline/testes): retorna o usuário mock.
///
/// [salvar] guarda em memória para que a UI se comporte igual nos dois modos —
/// o perfil editado sobrevive à navegação dentro da sessão, e só não atravessa
/// o fechamento do app (não há banco por trás).
class MockUserService implements UserService {
  const MockUserService();

  static AppUser? _salvo;

  @override
  Future<AppUser?> fetchByUid(String uid) async =>
      _salvo ?? MockData.usuarioAtual;

  @override
  Future<AppUser?> fetchByEmail(String email) async =>
      _salvo ?? MockData.usuarioAtual;

  @override
  Future<AppUser> salvar(AppUser user) async => _salvo = user;

  @override
  Future<AppUser?> fetchByCpf(String cpf) async {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    for (final p in MockData.patients) {
      if ((p.cpf ?? '').replaceAll(RegExp(r'\D'), '') == digits) {
        final parts = p.name.split(RegExp(r'\s+'));
        return AppUser(
          id: p.id,
          firstName: parts.first,
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
          email: p.email,
          phone: p.phone,
          cpf: p.cpf,
        );
      }
    }
    return null;
  }
}
