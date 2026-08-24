import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/widgets/async_states.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('EmptyView mostra mensagem e dispara a ação', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(EmptyView(
      message: 'Sem dados aqui',
      actionLabel: 'Recarregar',
      onAction: () => tapped = true,
    )));
    expect(find.text('Sem dados aqui'), findsOneWidget);
    await tester.tap(find.text('Recarregar'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorView mostra "Tentar novamente" quando há onRetry',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(ErrorView(
      message: 'Falhou',
      onRetry: () => retried = true,
    )));
    expect(find.text('Falhou'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retried, isTrue);
  });

  testWidgets('LoadingView renderiza o indicador', (tester) async {
    await tester.pumpWidget(_wrap(const LoadingView(message: 'Carregando…')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Carregando…'), findsOneWidget);
  });
}
