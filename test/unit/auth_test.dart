import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/services/app_providers.dart';

import '../helpers.dart';

/// Testes do fluxo de autenticação (LOGIN / CADASTRO / RESET / PLANO).
/// Usa o `MockAuthService` (padrão), validando a máquina de estados do
/// `AuthController` independentemente do Firebase.
void main() {
  test('começa não autenticado sem preferências', () async {
    final c = await makeContainer();
    expect(c.read(authProvider).isAuthenticated, false);
  });

  test('restaura sessão a partir das preferências', () async {
    final c = await makeContainer(prefs: {
      'auth_logged_in': true,
      'auth_plan_id': 'plan_pro',
    });
    final state = c.read(authProvider);
    expect(state.isAuthenticated, true);
    expect(state.hasPlan, true);
    expect(c.read(activePlanProvider)?.id, 'plan_pro');
  });

  test('cadastro autentica mas sem plano; escolher plano completa', () async {
    final c = await makeContainer();
    final err = await c.read(authProvider.notifier).register(
        email: 'novo@vitta.app', password: 'F0rte@Senha');
    expect(err, isNull);
    expect(c.read(authProvider).isAuthenticated, true);
    expect(c.read(authProvider).hasPlan, false);

    await c.read(authProvider.notifier).choosePlan('plan_basic');
    expect(c.read(authProvider).hasPlan, true);
    expect(c.read(activePlanProvider)?.name, 'Essencial');
  });

  test('login e logout alternam o estado', () async {
    final c = await makeContainer();
    final err = await c.read(authProvider.notifier)
        .login(email: 'gestor@vitta.app', password: 'F0rte@Senha');
    expect(err, isNull);
    expect(c.read(authProvider).isAuthenticated, true);
    expect(c.read(authProvider).email, 'gestor@vitta.app');

    await c.read(authProvider.notifier).logout();
    expect(c.read(authProvider).isAuthenticated, false);
  });

  test('resetPassword retorna sucesso (sem erro) no mock', () async {
    final c = await makeContainer();
    final err = await c.read(authProvider.notifier).resetPassword('a@b.com');
    expect(err, isNull);
  });

  test('login com Google autentica via mock', () async {
    final c = await makeContainer();
    final err = await c.read(authProvider.notifier).loginWithGoogle();
    expect(err, isNull);
    expect(c.read(authProvider).isAuthenticated, true);
    expect(c.read(authProvider).email, contains('@'));
  });

  test('mock indica Firebase desabilitado (banner de setup)', () async {
    final c = await makeContainer();
    expect(c.read(firebaseEnabledProvider), false);
  });

  group('biometria', () {
    test('habilitar/desabilitar persiste a preferência', () async {
      final c = await makeContainer();
      expect(c.read(authProvider.notifier).biometricEnabled, false);
      await c.read(authProvider.notifier).setBiometricEnabled(true);
      expect(c.read(authProvider.notifier).biometricEnabled, true);
    });

    test('completeBiometricLogin restaura a sessão salva', () async {
      final c = await makeContainer(prefs: {
        'auth_logged_in': true,
        'auth_email': 'gestor@vitta.app',
        'auth_biometric_enabled': true,
      });
      final notifier = c.read(authProvider.notifier);
      expect(notifier.hasSavedSession, true);
      final err = await notifier.completeBiometricLogin();
      expect(err, isNull);
      expect(c.read(authProvider).email, 'gestor@vitta.app');
    });

    test('completeBiometricLogin falha sem sessão salva', () async {
      final c = await makeContainer();
      final err = await c.read(authProvider.notifier).completeBiometricLogin();
      expect(err, isNotNull);
    });
  });
}
