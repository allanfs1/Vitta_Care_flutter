import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';
import 'package:vitta_app/features/projecao_12m/projecao_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_screen.dart';
import 'package:vitta_app/features/projecao_12m/projecao_engine.dart';

int builds = 0;

Future<ProviderContainer> _pump(WidgetTester tester,
    {required Size tamanho, ThemeData? tema}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'auth_logged_in': true});
  final prefs = await SharedPreferences.getInstance();
  builds = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        projConfigProvider
            .overrideWith((ref) => const ProjecaoConfig(nSimulacoes: 300)),
        projResultadoProvider.overrideWith((ref) async {
          final c = ref.watch(projConfigProvider);
          builds++;
          await Future<void>.delayed(Duration.zero);
          return ProjecaoEngine.projetar(c);
        }),
      ],
      child: MaterialApp(theme: tema, home: const Projecao12mScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return ProviderScope.containerOf(
      tester.element(find.byType(Projecao12mScreen)));
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  for (final w in [320.0, 360.0, 380.0, 400.0]) {
    testWidgets('380 governanca w=$w', (tester) async {
      await _pump(tester, tamanho: Size(w, 1000));
      expect(tester.takeException(), isNull, reason: 'aba cenarios w=$w');
      await tester.tap(find.text('Governança'));
      await tester.pumpAndSettle();
      final ex = tester.takeException();
      // ignore: avoid_print
      print('W=$w governanca excecao: $ex');
    });
  }

  testWidgets('dark mode nao lanca', (tester) async {
    await _pump(tester, tamanho: const Size(380, 1000), tema: ThemeData.dark());
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('dark ex: ${tester.takeException()}');
  });

  testWidgets('troca de aba nao re-executa simulacao', (tester) async {
    await _pump(tester, tamanho: const Size(1400, 1600));
    // ignore: avoid_print
    print('builds apos primeiro render: $builds');
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('builds apos ir para governanca: $builds');
    await tester.tap(find.text('Cenários'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('builds apos voltar: $builds');
  });

  testWidgets('scroll da aba cenarios sobrevive a troca?', (tester) async {
    await _pump(tester, tamanho: const Size(420, 800));
    final lista = find.byType(Scrollable).at(0);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final pos1 = tester.state<ScrollableState>(lista).position.pixels;
    // ignore: avoid_print
    print('offset antes da troca: $pos1');
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cenários'));
    await tester.pumpAndSettle();
    final pos2 = tester
        .state<ScrollableState>(find.byType(Scrollable).at(0))
        .position
        .pixels;
    // ignore: avoid_print
    print('offset depois da troca: $pos2');
  });

  test('tempo de projetar no padrao', () {
    for (final n in [300, 4000]) {
      final sw = Stopwatch()..start();
      final r = ProjecaoEngine.projetar(ProjecaoConfig(nSimulacoes: n));
      sw.stop();
      // ignore: avoid_print
      print('nSim=$n -> ${sw.elapsedMilliseconds} ms  (duracao interna '
          '${r.duracao.inMilliseconds} ms)');
    }
  });
}
