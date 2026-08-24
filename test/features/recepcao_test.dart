import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/recepcao/recepcao_screen.dart';

import '../helpers.dart';

/// Testes do módulo Recepção (painel de balcão, layout em abas).
void main() {
  // A Recepção é uma tela de balcão (desktop): viewport amplo evita overflow
  // de altura na superfície padrão de teste.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1400, 1100);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('renderiza as abas do painel de recepção', (tester) async {
    await tester.pumpWidget(await wrap(const RecepcaoScreen()));
    await settle(tester);

    expect(find.text('FILA GERAL'), findsOneWidget);
    expect(find.text('KANBAN CLÍNICO'), findsOneWidget);
    expect(find.text('FINALIZADOS'), findsOneWidget);
  });

  testWidgets('exibe as ações principais do balcão', (tester) async {
    await tester.pumpWidget(await wrap(const RecepcaoScreen()));
    await settle(tester);

    expect(find.text('Novo Acolhimento'), findsOneWidget);
    expect(find.text('Abrir Monitor'), findsOneWidget);
    expect(find.text('Abrir Totem'), findsOneWidget);
  });
}
