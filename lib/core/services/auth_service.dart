import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Resultado de uma operação de autenticação.
class AuthResult {
  const AuthResult.success(this.email)
      : ok = true,
        error = null;
  const AuthResult.failure(this.error)
      : ok = false,
        email = null;

  final bool ok;
  final String? error;
  final String? email;
}

/// Contrato de autenticação compartilhado (módulo auth).
abstract class AuthService {
  Future<AuthResult> signIn({required String email, required String password});
  Future<AuthResult> register({required String email, required String password});
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> sendPasswordReset(String email);
  Future<void> signOut();

  /// E-mail do usuário logado atualmente, se houver.
  String? get currentEmail;

  /// UID do usuário logado (Firebase), se houver.
  String? get currentUid;

  /// `true` quando o Firebase inicializou (login real disponível). `false`
  /// indica modo de demonstração (serviço simulado) — usado para o banner de setup.
  bool get isFirebaseEnabled;

  /// Emite mudanças no estado de autenticação (login/logout).
  Stream<String?> authStateChanges();
}

/// Implementação real usando **Firebase Authentication** (módulos prontos do
/// Firebase: e-mail/senha, recuperação de senha).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  bool get isFirebaseEnabled => true;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u?.email);

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return AuthResult.success(cred.user?.email ?? email);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_message(e));
    }
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      return AuthResult.success(cred.user?.email ?? email);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_message(e));
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Evita reutilizar silenciosamente a sessão Google já aberta no
      // navegador: encerra a sessão atual e força a escolha de conta.
      await _auth.signOut();
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      final cred = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
      return AuthResult.success(cred.user?.email ?? '');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_message(e));
    } catch (e) {
      return AuthResult.failure('Falha no login com Google: $e');
    }
  }

  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(email);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_message(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Traduz os códigos do Firebase Auth para mensagens em pt-BR.
  String _message(FirebaseAuthException e) {
    // Log do código bruto para diagnóstico (visível no console / DevTools).
    debugPrint('FirebaseAuthException: code=${e.code} message=${e.message}');
    switch (e.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Esta conta está desativada.';
      case 'user-not-found':
        return 'Não há conta com este e-mail. Crie uma conta primeiro.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-credential':
        return 'Credenciais inválidas. Verifique o e-mail e a senha, ou '
            'crie uma conta caso ainda não tenha.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Faça login.';
      case 'weak-password':
        return 'Senha muito fraca (mínimo de 6 caracteres no Firebase).';
      case 'operation-not-allowed':
        return 'Login por e-mail/senha não está habilitado no Firebase. '
            'Ative o provedor "Email/Password" no console.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Falha de conexão. Verifique sua internet.';
      case 'api-key-not-valid':
      case 'invalid-api-key':
        return 'Configuração do Firebase inválida (API key). Rode '
            '`flutterfire configure`.';
      default:
        return e.message ?? 'Erro de autenticação (${e.code}).';
    }
  }
}

/// Implementação simulada para desenvolvimento offline e testes (sem Firebase).
class MockAuthService implements AuthService {
  String? _email;

  @override
  bool get isFirebaseEnabled => false;

  @override
  String? get currentEmail => _email;

  @override
  String? get currentUid => _email == null ? null : 'mock-uid';

  @override
  Stream<String?> authStateChanges() => const Stream<String?>.empty();

  @override
  Future<AuthResult> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _email = 'usuario.google@gmail.com';
    return AuthResult.success(_email!);
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _email = email;
    return AuthResult.success(email);
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _email = email;
    return AuthResult.success(email);
  }

  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return AuthResult.success(email);
  }

  @override
  Future<void> signOut() async => _email = null;
}
