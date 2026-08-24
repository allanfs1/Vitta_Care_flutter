import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/core/widgets/app_avatar.dart';
import 'package:vitta_app/core/widgets/kpi_card.dart';
import 'package:vitta_app/core/widgets/status_badge.dart';

/// Testes de widget dos componentes reutilizáveis do Design System.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StatusBadge.appointment exibe rótulo do status', (tester) async {
    await tester.pumpWidget(_host(StatusBadge.appointment(AppointmentStatus.confirmed)));
    expect(find.text('Confirmado'), findsOneWidget);
  });

  testWidgets('StatusBadge.risk prefixa o nível', (tester) async {
    await tester.pumpWidget(_host(StatusBadge.risk(RiskLevel.high)));
    expect(find.text('Risco Alto'), findsOneWidget);
  });

  testWidgets('KpiCard mostra valor, sufixo e variação', (tester) async {
    await tester.pumpWidget(_host(const KpiCard(
      kpi: Kpi(label: 'Ocupação', value: '78', suffix: '%', delta: 3.2),
    )));
    expect(find.text('Ocupação'), findsOneWidget);
    // O valor "78%" é renderizado via RichText.
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(richTexts.any((r) => r.text.toPlainText().contains('78%')), isTrue);
    expect(find.text('+3.2%'), findsOneWidget);
  });

  testWidgets('AppAvatar renderiza iniciais quando não há imagem', (tester) async {
    await tester.pumpWidget(_host(const AppAvatar(initials: 'CS')));
    expect(find.text('CS'), findsOneWidget);
  });
}
