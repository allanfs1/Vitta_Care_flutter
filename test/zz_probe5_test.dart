import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';
import 'package:vitta_app/features/projecao_12m/projecao_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_screen.dart';

double _off(WidgetTester t) {
  final lv = find.byType(ListView).first;
  return t.state<ScrollableState>(
      find.descendant(of: lv, matching: find.byType(Scrollable)).first
  ).position.pixels;
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('scroll sobrevive?', (tester) async {
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auth_logged_in': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        projConfigProvider
            .overrideWith((r) => const ProjecaoConfig(nSimulacoes: 200)),
      ],
      child: const MaterialApp(home: Projecao12mScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('listviews: ${tester.widgetList(find.byType(ListView)).length}');
    await tester.drag(find.byType(ListView).first, const Offset(0, -400),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('offset apos rolar: ${_off(tester)}');
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cenários'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('offset apos voltar: ${_off(tester)}');
  });
}
