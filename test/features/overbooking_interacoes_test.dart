import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/overbooking/overbooking_screen.dart';

/// Testes de interação do painel de Overbooking (item R8 da varredura de QA):
/// navegação por data e controles do motor de realocação.
Future<void> _pumpOverbooking(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'auth_logged_in': true,
    'auth_plan_id': 'plan_pro',
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: OverbookingScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('inicia em "Hoje" e navega entre os dias pelas setas',
      (tester) async {
    await _pumpOverbooking(tester);

    // O cabeçalho começa no dia atual.
    expect(find.text('Hoje'), findsOneWidget);

    // Avança um dia → deixa de ser "Hoje".
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('Hoje'), findsNothing);

    // Volta um dia → retorna para "Hoje".
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(find.text('Hoje'), findsOneWidget);
  });

  testWidgets('aba Realocação mostra o seletor de modo do motor (padrão Sugestão)',
      (tester) async {
    await _pumpOverbooking(tester);

    await tester.tap(find.text('Realocação'));
    await tester.pump();
    await tester.pumpAndSettle();

    // O DropdownButton do motor inicia no modo padrão "Sugestão".
    expect(find.text('Motor de realocação'), findsOneWidget);
    expect(find.text('Sugestão'), findsWidgets);
  });
}
