// A implementação concreta é escolhida em tempo de compilação:
//  - nativo (Windows/Android/iOS): `local_auth` (digital / Windows Hello).
//  - web: WebAuthn/passkeys (Windows Hello / Touch ID / digital via navegador).
import 'biometric_service_io.dart'
    if (dart.library.js_interop) 'biometric_service_web.dart' as impl;

/// Serviço de autenticação biométrica local (digital / Windows Hello / passkey).
///
/// AGENTS.md › LOGIN: "cadastro biométrico usando digital salva no computador".
/// A biometria desbloqueia a **sessão já salva** localmente — não substitui a
/// verificação de credenciais do Firebase, atua como camada de bloqueio do app.
abstract class BiometricService {
  /// O dispositivo/navegador suporta biometria de plataforma com verificação
  /// de usuário?
  Future<bool> isAvailable();

  /// Já existe uma credencial biométrica registrada neste dispositivo/navegador?
  /// (No nativo equivale a "suporta"; na web, se há uma passkey criada.)
  Future<bool> isEnrolled();

  /// Registra/ativa a biometria neste dispositivo. Na web cria uma passkey
  /// (WebAuthn → Windows Hello/Touch ID); no nativo apenas confirma a digital.
  /// [accountName] rotula a credencial (ex.: e-mail do usuário). Retorna `true`
  /// em sucesso.
  Future<bool> enroll({String reason, String? accountName});

  /// Solicita a autenticação biométrica. Retorna `true` se autenticou.
  Future<bool> authenticate({String reason});
}

/// Cria a implementação adequada à plataforma atual.
BiometricService createBiometricService() => impl.createBiometricService();

/// Implementação para testes/offline: biometria indisponível por padrão.
class MockBiometricService implements BiometricService {
  MockBiometricService({
    this.available = false,
    this.willSucceed = true,
    this.enrolled = false,
  });

  final bool available;
  final bool willSucceed;
  final bool enrolled;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> isEnrolled() async => enrolled;

  @override
  Future<bool> enroll({String reason = '', String? accountName}) async =>
      willSucceed;

  @override
  Future<bool> authenticate({String reason = ''}) async => willSucceed;
}
