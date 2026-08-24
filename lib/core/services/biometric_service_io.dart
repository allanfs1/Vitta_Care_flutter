import 'package:local_auth/local_auth.dart';

import 'biometric_service.dart';

/// Biometria nativa (Windows/Android/iOS) via `local_auth`.
///
/// No nativo o autenticador é o do próprio SO: não há "credencial" a guardar,
/// então `isEnrolled` equivale a `isAvailable` e `enroll` apenas confirma a
/// digital uma vez.
class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isEnrolled() => isAvailable();

  @override
  Future<bool> enroll({
    String reason = 'Confirme sua identidade para ativar a biometria',
    String? accountName,
  }) =>
      authenticate(reason: reason);

  @override
  Future<bool> authenticate({
    String reason = 'Confirme sua identidade para entrar',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // permite PIN/senha do dispositivo como fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

BiometricService createBiometricService() => LocalAuthBiometricService();
