import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/assistente/assistant_controller.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_providers.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_screen.dart';

/// Testes de widget do Simulador. Segue o padrão de override de
/// `sharedPrefsProvider` usado no painel de Overbooking.
Future<void> _pump(
  WidgetTester tester, {
  Size? tamanho,
  List<Override> extras = const [],
}) async {
  if (tamanho != null) {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  SharedPreferences.setMockInitialValues({
    'auth_logged_in': true,
    'auth_plan_id': 'plan_pro',
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...extras],
      child: const MaterialApp(home: MonteCarloScreen()),
    ),
  );
  // A simulação é assíncrona de propósito (cede um tique para o indicador de
  // carregamento pintar); alguns pumps bastam para o resultado chegar.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _abrir(WidgetTester tester, String aba) async {
  await tester.tap(find.widgetWithText(Tab, aba));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  group('Aba Decisão', () {
    testWidgets('renderiza cabeçalho, abas e KPIs', (tester) async {
      await _pump(tester);

      expect(find.text('Simulador de Agenda'), findsOneWidget);
      // "Decisão" também é coluna da tabela de cenários — buscar a aba.
      expect(find.widgetWithText(Tab, 'Decisão'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Calibração'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Parâmetros'), findsOneWidget);

      // "Agendados" aparece no KPI e no cabeçalho da tabela de slots.
      expect(find.text('Agendados'), findsAtLeastNWidgets(1));
      expect(find.text('Faltas esperadas'), findsOneWidget);
      expect(find.text('Cancelam com aviso'), findsOneWidget);
      expect(find.text('Sobredispersão φ'), findsOneWidget);
    });

    testWidgets('a lista de espera aparece antes do overbooking',
        (tester) async {
      await _pump(tester);

      final fila = find.textContaining('lista de espera');
      final cenarios = find.text('Cenários de overbooking');
      expect(fila, findsAtLeastNWidgets(1));
      expect(cenarios, findsOneWidget);

      final yFila = tester.getTopLeft(fila.first).dy;
      final yCenarios = tester.getTopLeft(cenarios).dy;
      expect(yFila, lessThan(yCenarios),
          reason: 'a fila é a alavanca que vem antes do encaixe');
    });

    testWidgets('mostra as seções de decisão por slot', (tester) async {
      await _pump(tester);

      expect(find.text('Distribuição de faltas do dia'), findsOneWidget);
      expect(find.text('Cenários de overbooking'), findsOneWidget);
      expect(find.text('Risco por slot (médico × hora)'), findsOneWidget);
      expect(find.text('Composição da agenda'), findsOneWidget);
    });

    testWidgets('a tabela de cenários traz a coluna de equidade',
        (tester) async {
      await _pump(tester, tamanho: const Size(1600, 1200));
      expect(find.text('Equidade'), findsOneWidget);
    });

    testWidgets('rho = 0 troca o rodapé para a forma fechada exata',
        (tester) async {
      await _pump(tester, extras: [
        mcConfigProvider.overrideWith((ref) => const SimulacaoConfig(rho: 0)),
      ]);

      expect(find.textContaining('Forma fechada (Poisson-binomial)'),
          findsOneWidget);
    });
  });

  group('Aba Calibração', () {
    testWidgets('exibe veredito, taxas e limitações', (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Calibração');

      expect(find.text('Taxas observadas por faixa de risco'), findsOneWidget);
      expect(find.text('Limitações dos dados'), findsOneWidget);
      expect(find.text('Aplicar à simulação'), findsOneWidget);
    });

    testWidgets('avisa que o histórico é sintético no modo demonstração',
        (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Calibração');

      expect(find.text('Histórico sintético (modo demonstração)'),
          findsOneWidget);
      expect(find.textContaining('Nenhum deles descreve uma clínica real'),
          findsOneWidget);
    });

    testWidgets('com histórico sintético o botão de aplicar habilita',
        (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Calibração');

      final botao =
          find.widgetWithText(FilledButton, 'Aplicar parâmetros medidos');
      expect(botao, findsOneWidget);
      // O histórico gerado tem 210 dias e as três faixas de risco: passa nas
      // travas de integridade que a base vazia não passava.
      expect(tester.widget<FilledButton>(botao).onPressed, isNotNull);
    });

    testWidgets('mostra a sazonalidade de φ mês a mês', (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Calibração');

      expect(find.text('Sobredispersão ao longo do ano'), findsOneWidget);
    });
  });

  group('Aba Parâmetros', () {
    testWidgets('traz modelo, política e execução', (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Parâmetros');

      expect(find.text('Modelo'), findsOneWidget);
      expect(find.text('Política de decisão'), findsOneWidget);
      expect(find.text('Execução'), findsOneWidget);
      expect(find.text('Capacidade de referência'), findsOneWidget);
      expect(find.text('Como o encaixe entra na conta'), findsOneWidget);
    });

    testWidgets('trocar a base de capacidade altera a simulação',
        (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Parâmetros');

      await tester.tap(find.text(BaseCapacidade.configurada.label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(
          tester.element(find.byType(MonteCarloScreen)));
      expect(container.read(mcConfigProvider).baseCapacidade,
          BaseCapacidade.configurada);
    });
  });

  group('Layout responsivo', () {
    for (final (nome, tamanho) in [
      ('desktop', Size(1400, 1000)),
      ('tablet', Size(900, 1200)),
      ('celular', Size(420, 900)),
    ]) {
      testWidgets('não estoura o layout em $nome', (tester) async {
        await _pump(tester, tamanho: tamanho);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Ícone de ajuda no header', () {
    testWidgets('abre o tour do simulador', (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));

      final container = ProviderScope.containerOf(
          tester.element(find.byType(MonteCarloScreen)));
      expect(container.read(assistantProvider).activeTour, isNull);

      await tester.tap(find.byTooltip('Como usar o Simulador'));
      await tester.pump();

      final estado = container.read(assistantProvider);
      expect(estado.activeTour?.id, 'simulador');
      expect(estado.isOpen, isTrue);
    });
  });

  group('Aba Ações de IA', () {
    testWidgets('lista o catálogo de leituras, sem as de gráfico',
        (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Ações de IA');

      expect(find.text('O que a IA pode ler para você'), findsOneWidget);
      expect(find.text('Explicar este dia'), findsOneWidget);
      expect(find.text('Achar o gargalo'), findsOneWidget);
      expect(find.text('Redigir chamada da fila'), findsOneWidget);
      // As ações de gráfico vivem só nos ícones ao lado dos gráficos.
      expect(find.text('Explicar a distribuição de faltas'), findsNothing);
    });

    testWidgets('cada ação tem um botão para pedir a leitura',
        (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      await _abrir(tester, 'Ações de IA');

      expect(find.widgetWithText(FilledButton, 'Ler'), findsWidgets);
    });
  });

  group('Ícone de IA nos gráficos', () {
    testWidgets('aparece ao lado do histograma de faltas', (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      expect(find.text('Explicar'), findsAtLeastNWidgets(1));
    });

    testWidgets('aparece ao lado da tabela de risco por slot',
        (tester) async {
      await _pump(tester, tamanho: const Size(1400, 1400));
      // Pelo menos dois ícones "Explicar": distribuição e slots, ambos na
      // aba Decisão.
      expect(find.text('Explicar'), findsAtLeastNWidgets(2));
    });
  });
}
