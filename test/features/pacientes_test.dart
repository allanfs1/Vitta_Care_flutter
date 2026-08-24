import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/pacientes/pacientes_screen.dart';

/// Teste de widget do módulo Pacientes (PAC-01).
void main() {
  testWidgets('lista de pacientes renderiza e filtra por busca', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: PacientesScreen()),
      ),
    );
    await tester.pump();

    // Pacientes mock devem aparecer.
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('João Oliveira'), findsOneWidget);

    // Busca filtra a lista.
    await tester.enterText(find.byType(TextField), 'maria');
    await tester.pump();
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('João Oliveira'), findsNothing);
  });
}
