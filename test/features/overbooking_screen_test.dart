import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/widgets/async_states.dart';
import 'package:vitta_app/features/overbooking/overbooking_screen.dart';

/// Testes de widget do painel de Overbooking (item R8 da varredura de QA).
/// A tela depende de `sharedPrefsProvider` (via clínica/agendamentos), por isso
/// seguimos o mesmo padrão de override de `test/widget_test.dart`.
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
  // Evita pumpAndSettle por causa das animações dos gráficos/skeletons.
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('mostra o título e as 4 abas do painel', (tester) async {
    await _pumpOverbooking(tester);

    expect(find.text('Overbooking'), findsOneWidget);
    expect(find.text('Visão Geral'), findsOneWidget);
    expect(find.text('Pacientes do Dia'), findsOneWidget);
    expect(find.text('Realocação'), findsOneWidget);
    expect(find.text('Decisões'), findsOneWidget);
  });

  testWidgets('aba Realocação exibe o motor com "Gerar sugestões"',
      (tester) async {
    await _pumpOverbooking(tester);

    await tester.tap(find.text('Realocação'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Motor de realocação'), findsOneWidget);
    expect(find.text('Gerar sugestões'), findsOneWidget);
  });

  testWidgets('aba Decisões começa vazia (estado inicial de auditoria)',
      (tester) async {
    await _pumpOverbooking(tester);

    await tester.tap(find.text('Decisões'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Sem realocações aplicadas ainda → EmptyView de auditoria.
    expect(find.byType(EmptyView), findsOneWidget);
    expect(
      find.textContaining('Nenhuma decisão registrada'),
      findsOneWidget,
    );
  });

  testWidgets('aba Pacientes do Dia mostra os chips de filtro', (tester) async {
    await _pumpOverbooking(tester);

    await tester.tap(find.text('Pacientes do Dia'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Os ChoiceChips de filtro trazem o rótulo + contagem, ex.: "Todos (N)".
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.textContaining('Todos ('), findsOneWidget);
  });
}
