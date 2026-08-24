import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/ia/widgets/smart_scheduling_card.dart';

/// Teste de widget da regra de negócio IA-01: agendamento inteligente é
/// exclusivo de clínicas privadas (B2B).
Widget _host(Widget child) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('clínica não-B2B vê recurso bloqueado', (tester) async {
    await tester.pumpWidget(_host(const SmartSchedulingCard(isB2B: false)));
    expect(find.textContaining('exclusivo para Clínicas Privadas'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Sugerir horários'), findsNothing);
  });

  testWidgets('clínica B2B tem o recurso ativo', (tester) async {
    await tester.pumpWidget(_host(const SmartSchedulingCard(isB2B: true)));
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Sugerir horários'), findsOneWidget);
  });
}
