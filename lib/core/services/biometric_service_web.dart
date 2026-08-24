import 'dart:js_interop';

import 'biometric_service.dart';

// Bindings para as funções expostas por `web/webauthn.js` (window.vittaBiometric).
@JS('vittaBiometric.isAvailable')
external JSPromise<JSBoolean> _jsIsAvailable();

@JS('vittaBiometric.isEnrolled')
external JSBoolean _jsIsEnrolled();

@JS('vittaBiometric.enroll')
external JSPromise<JSBoolean> _jsEnroll(JSString accountName);

@JS('vittaBiometric.authenticate')
external JSPromise<JSBoolean> _jsAuthenticate();

/// Biometria no navegador via WebAuthn/passkeys (Windows Hello / Touch ID /
/// digital). Delega ao helper JS para a cerimônia WebAuthn; cada chamada é
/// protegida porque `vittaBiometric` pode não existir (script não carregado).
class WebAuthnBiometricService implements BiometricService {
  const WebAuthnBiometricService();

  @override
  Future<bool> isAvailable() async {
    try {
      final r = await _jsIsAvailable().toDart;
      return r.toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isEnrolled() async {
    try {
      return _jsIsEnrolled().toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> enroll({String reason = '', String? accountName}) async {
    try {
      final r = await _jsEnroll((accountName ?? 'vitta-user').toJS).toDart;
      return r.toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({String reason = ''}) async {
    try {
      final r = await _jsAuthenticate().toDart;
      return r.toDart;
    } catch (_) {
      return false;
    }
  }
}

BiometricService createBiometricService() => const WebAuthnBiometricService();
