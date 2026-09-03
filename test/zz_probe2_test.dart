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
import 'package:vitta_app/features/projecao_12m/widgets/proj_governanca.dart';

int execs = 0;

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('estado observado em modo demo', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_logged_in': true});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    // deixa o stream do mock emitir
    c.listen(appointmentsProvider, (_, __) {});
    await tester.pump(const Duration(milliseconds: 50));
    final ags = c.read(appointmentsProvider);
    // ignore: avoid_print
    print('appointments: ${ags.length}');
    // ignore: avoid_print
    print('volume observado: ${c.read(projVolumeObservadoProvider)}');
    final h = c.read(projHistoricoObservadoProvider);
    // ignore: avoid_print
    print('historico: $h');
    final pf = c.read(projPartidaAFrioProvider);
    // ignore: avoid_print
    print('maturidade=${pf.maturidade.label} k=${pf.kShrinkage} '
        'wapeSugerido=${pf.wapeSugerido} nEfetivo=${pf.nHistoricoEfetivo} '
        'peso=${pf.pesoDoSegmento(pf.desfechosObservados)}');
    // ignore: avoid_print
    print('config nHistorico=${c.read(projConfigProvider).nHistorico} '
        'wape=${c.read(projConfigProvider).wapeForecast}');
    final piloto = c.read(projPilotoProvider);
    // ignore: avoid_print
    print('piloto viavel=${piloto.viavel} meses=${piloto.mesesNecessarios}');
  });

  testWidgets('quantas re-execucoes num arraste de slider', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
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
    execs = 0;
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(200, 0));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('re-execucoes num unico arraste: $execs');
  });

  testWidgets('governanca isolada em dark, 380px', (tester) async {
    tester.view.physicalSize = const Size(380, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: SingleChildScrollView(
              padding: EdgeInsets.all(16), child: ProjGovernanca()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('ex: ${tester.takeException()}');
    // coleta cores efetivas dos textos
    final textos = tester.widgetList<Text>(find.byType(Text));
    final cores = <String, int>{};
    for (final t in textos) {
      final col = t.style?.color;
      if (col != null) {
        final k = '#${col.toARGB32().toRadixString(16).padLeft(8, '0')}';
        cores[k] = (cores[k] ?? 0) + 1;
      }
    }
    // ignore: avoid_print
    print('cores explicitas em dark: $cores');
    // ignore: avoid_print
    print('total textos: ${textos.length}');
  });
}
