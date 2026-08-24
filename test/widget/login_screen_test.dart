import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/services/biometric_service.dart';
import 'package:vitta_app/features/auth/login_screen.dart';

/// Teste de widget da página de login: métodos alternativos e estados de setup.
Future<Widget> _host({bool biometric = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      biometricServiceProvider.overrideWithValue(
        MockBiometricService(available: biometric),
      ),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('mostra Google, criar conta e banner de modo demonstração',
      (tester) async {
    await tester.pumpWidget(await _host());
    await tester.pump();

    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Criar conta'), findsWidgets);
    expect(find.text('Primeiro acesso?'), findsOneWidget);
    // Como o serviço padrão é o mock, o Firebase está "desabilitado".
    expect(find.text('Modo demonstração'), findsOneWidget);
  });

  testWidgets('botão de digital não aparece quando biometria indisponível',
      (tester) async {
    await tester.pumpWidget(await _host(biometric: false));
    await tester.pump();
    expect(find.text('Entrar com digital'), findsNothing);
  });
}
