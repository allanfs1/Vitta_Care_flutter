import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';
import 'package:vitta_app/features/projecao_12m/projecao_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_screen.dart';
import 'package:vitta_app/features/projecao_12m/monitoramento.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('scroll sobrevive a troca de aba?', (tester) async {
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

    final lv = find.byType(ListView).first;
    await tester.fling(lv, const Offset(0, -600), 2000);
    await tester.pumpAndSettle();
    final p1 = tester.state<ScrollableState>(find.byType(Scrollable).at(0))
        .position.pixels;
    // ignore: avoid_print
    print('offset apos rolar: $p1');
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cenários'));
    await tester.pumpAndSettle();
    final p2 = tester.state<ScrollableState>(find.byType(Scrollable).at(0))
        .position.pixels;
    // ignore: avoid_print
    print('offset apos voltar: $p2');
  });

  test('cobertura: 90% nominal vs faixa 70-90', () {
    // 12 meses, 11 dentro => cobertura 91,7% — perfeita para P05-P95.
    final meses = [
      for (var i = 0; i < 12; i++)
        MesRealizado(
            rotulo: 'm$i',
            realizado: i == 0 ? 200 : 100,
            p05: 90,
            p50: 100,
            p95: 110)
    ];
    final c = Monitoramento.cobertura(meses); // nominal default
    // ignore: avoid_print
    print('nominal=${c.nominal} observada=${c.observada} '
        'calibrado=${c.calibrado}');
    // ignore: avoid_print
    print('veredito: ${c.veredito}');
    final g = Monitoramento.gatilhosForecast(
      wapeObservado: 0.10,
      wapeValidacao: 0.12,
      periodosSeguidosAcima: 0,
      cobertura80: c,
    );
    for (final x in g) {
      // ignore: avoid_print
      print('gatilho "${x.sinal}" disparou=${x.disparou} valor=${x.valor}');
    }
  });
}
