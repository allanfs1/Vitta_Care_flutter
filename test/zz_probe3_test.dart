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

int execs = 0;
int screenBuilds = 0;

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('arraste realista de slider', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auth_logged_in': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        projResultadoProvider.overrideWith((ref) async {
          final cfg = ref.watch(projConfigProvider);
          execs++;
          await Future<void>.delayed(Duration.zero);
          return ProjecaoEngine.projetar(cfg.copyWith(nSimulacoes: 50));
        }),
      ],
      child: const MaterialApp(home: Projecao12mScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final slider = find.byType(Slider).first;
    final c0 = tester.getCenter(slider);
    execs = 0;
    final g = await tester.startGesture(c0);
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('re-execucoes num arraste de 30 passos: $execs');

    // custo real de UMA execucao no padrao de producao
    final sw = Stopwatch()..start();
    ProjecaoEngine.projetar(const ProjecaoConfig());
    sw.stop();
    // ignore: avoid_print
    print('custo de 1 execucao (nSim=4000 padrao): ${sw.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print('=> bloqueio estimado no arraste: ${execs * sw.elapsedMilliseconds} ms');
  });
}
