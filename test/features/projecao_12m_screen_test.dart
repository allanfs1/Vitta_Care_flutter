import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';
import 'package:vitta_app/features/projecao_12m/projecao_providers.dart';
import 'package:vitta_app/features/projecao_12m/projecao_screen.dart';

Future<void> _pump(WidgetTester tester, {Size? tamanho}) async {
  if (tamanho != null) {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  SharedPreferences.setMockInitialValues({'auth_logged_in': true});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        // Carga leve: o teste verifica a tela, não a precisão estatística.
        projConfigProvider
            .overrideWith((ref) => const ProjecaoConfig(nSimulacoes: 300)),
      ],
      child: const MaterialApp(home: Projecao12mScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('renderiza cabeçalho e o aviso de não calibrado', (tester) async {
    await _pump(tester, tamanho: const Size(1400, 1600));
    expect(find.text('Projeção de 12 meses'), findsOneWidget);
    expect(find.text('Projeção não calibrada com dados reais'), findsOneWidget);
  });

  testWidgets('mostra os dois cenários e a decomposição financeira',
      (tester) async {
    await _pump(tester, tamanho: const Size(1400, 1600));
    expect(find.text('CONTINUIDADE'), findsOneWidget);
    expect(find.text('COM AGENDA CLÍNICA'), findsOneWidget);
    expect(find.text('Receita defensável'), findsOneWidget);
    expect(find.text('Antecipação de demanda'), findsOneWidget);
  });

  testWidgets('exibe a absorção da cadeia de Markov', (tester) async {
    await _pump(tester, tamanho: const Size(1400, 1600));
    expect(find.text('Destino de um agendamento'), findsOneWidget);
    expect(find.text('Compareceu'), findsOneWidget);
    expect(find.text('Faltou'), findsOneWidget);
  });

  testWidgets('trocar intensidade muda a configuração', (tester) async {
    await _pump(tester, tamanho: const Size(1400, 1600));
    await tester.tap(find.text('Agressivo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final c = ProviderScope.containerOf(
        tester.element(find.byType(Projecao12mScreen)));
    expect(c.read(projConfigProvider).intensidade, IntensidadeCenario.agressivo);
    expect(c.read(projConfigProvider).intervencao.reducaoFalta, 0.32);
  });

  testWidgets('uma intervenção danosa aparece como perda, não como zero',
      (tester) async {
    // O painel não pode mostrar a mesma coisa para "não fez diferença" e para
    // "custou consultas" — é essa a diferença que o piloto existe para achar.
    SharedPreferences.setMockInitialValues({'auth_logged_in': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          projConfigProvider.overrideWith((ref) => const ProjecaoConfig(
                nSimulacoes: 400,
                intervencao: ParametrosIntervencao(
                  reducaoFalta: -0.6,
                  reducaoCancelamento: -0.6,
                  taxaReposicaoVaga: 0,
                ),
              )),
        ],
        child: const MaterialApp(home: Projecao12mScreen()),
      ),
    );
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Perda com a intervenção'), findsOneWidget);
    expect(find.text('Receita defensável'), findsNothing);
  });

  testWidgets('a aba de governança traz piso, usos proibidos e piloto',
      (tester) async {
    await _pump(tester, tamanho: const Size(1400, 2400));
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();

    expect(find.text('Maturidade do histórico'), findsOneWidget);
    expect(find.text('Poder do piloto'), findsOneWidget);
    expect(find.text('Piso de intervenção'), findsOneWidget);
    expect(find.text('Usos proibidos do escore'), findsOneWidget);
  });

  testWidgets('a aba de governança nomeia os usos que ficam bloqueados',
      (tester) async {
    await _pump(tester, tamanho: const Size(1400, 2400));
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();

    // Não basta a regra existir no código: quem opera precisa vê-la.
    expect(find.text('Exibir o escore ao paciente'), findsOneWidget);
    expect(find.text('Negar ou condicionar agendamento'), findsOneWidget);
    expect(find.text('Sobrepor agendamentos em cima de alto risco'),
        findsOneWidget);
  });

  for (final (nome, tamanho) in [
    ('desktop', Size(1400, 1200)),
    ('tablet', Size(900, 1400)),
    ('celular', Size(420, 1000)),
  ]) {
    testWidgets('não estoura o layout em $nome', (tester) async {
      await _pump(tester, tamanho: tamanho);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a governança não estoura o layout em $nome', (tester) async {
      await _pump(tester, tamanho: tamanho);
      await tester.tap(find.text('Governança'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
