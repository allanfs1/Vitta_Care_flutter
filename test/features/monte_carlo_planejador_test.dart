import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/monte_carlo/ia/agente_simulacao.dart';
import 'package:vitta_app/features/monte_carlo/ia/mc_ia_providers.dart';
import 'package:vitta_app/features/monte_carlo/ia/plano_semanal.dart';
import 'package:vitta_app/features/monte_carlo/ia/validador_numeros.dart';
import 'package:vitta_app/features/monte_carlo/widgets/mc_planejador_tab.dart';

/// Testes da aba Planejador — a interface gráfica da IA do Simulador.
///
/// O que se verifica aqui é a **separação entre cálculo e opinião**: os
/// números da simulação têm de aparecer mesmo quando a IA falha, porque o
/// produto desta aba são eles.

DiaPlanejado _dia({
  int dia = 7,
  int agendados = 16,
  int encaixes = 2,
  int acimaDoLimite = 0,
  double ociosidade = 1.0,
  String? erro,
}) =>
    DiaPlanejado(
      data: DateTime(2026, 9, dia),
      totalAgendados: agendados,
      encaixesRecomendados: encaixes,
      riscoMaximoSlot: 0.03,
      slotsAcimaDoLimite: acimaDoLimite,
      faltasEsperadas: 3.2,
      ociosidadeEsperada: ociosidade,
      receitaAdicional: encaixes * 180.0,
      motivo: 'ok',
      erro: erro,
    );

PlanoSemanal _plano([List<DiaPlanejado>? dias]) => PlanoSemanal(
      dias: dias ??
          [
            _dia(dia: 7, encaixes: 2),
            _dia(dia: 8, encaixes: 3),
            _dia(dia: 9, encaixes: 0),
          ],
      geradoEm: DateTime(2026, 9, 6),
    );

/// Estado pronto, com ou sem análise da IA.
EstadoPlano _pronto({SugestaoPlano? sugestao, PlanoSemanal? plano}) {
  final p = plano ?? _plano();
  return EstadoPlano(
    fase: FasePlano.pronto,
    plano: p,
    sugestao: sugestao ?? SugestaoPlano(plano: p, analise: '**O essencial** — a semana comporta 5 encaixes.'),
    diaAtual: p.dias.length,
    diasTotal: p.dias.length,
  );
}

/// Notifier que devolve um estado fixo, sem rodar simulação nenhuma.
class _NotifierFixo extends PlanoNotifier {
  _NotifierFixo(super.ref, this._fixo) {
    state = _fixo;
  }
  final EstadoPlano _fixo;

  @override
  Future<void> gerar({DateTime? inicio}) async {}
}

late SharedPreferences _prefs;

Widget _app(EstadoPlano estado) => ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(_prefs),
        planoSemanalProvider.overrideWith((ref) => _NotifierFixo(ref, estado)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: McPlanejadorTab()),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  group('estado inicial', () {
    testWidgets('explica o que a aba faz e que nada é aplicado sozinho',
        (tester) async {
      await tester.pumpWidget(_app(const EstadoPlano()));
      await tester.pumpAndSettle();

      expect(find.text('Planejar a semana de uma vez'), findsOneWidget);
      // A regra do projeto: rotina de IA nasce como proposta. Se a tela não
      // disser isso, o gestor supõe que algo já foi feito na agenda.
      expect(find.textContaining('Nenhum encaixe é criado por aqui'),
          findsOneWidget);
      expect(find.text('Montar plano'), findsOneWidget);
    });

    testWidgets('oferece as três janelas', (tester) async {
      await tester.pumpWidget(_app(const EstadoPlano()));
      await tester.pumpAndSettle();
      expect(find.text('3 dias'), findsOneWidget);
      expect(find.text('7 dias'), findsOneWidget);
      expect(find.text('14 dias'), findsOneWidget);
    });
  });

  group('progresso', () {
    testWidgets('mostra o dia atual, não uma barra sem informação',
        (tester) async {
      await tester.pumpWidget(_app(const EstadoPlano(
        fase: FasePlano.simulando,
        diaAtual: 3,
        diasTotal: 7,
      )));
      await tester.pump();

      // "3 de 7" diz quanto falta; uma barra girando faz a tela parecer travada.
      expect(find.textContaining('Simulando dia 3 de 7'), findsOneWidget);
      // O botão continua na tela, mas desabilitado — sumir faria o controle
      // "pular" e o usuário perder a referência de onde clicar de novo.
      final botao = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(botao.onPressed, isNull);
    });

    testWidgets('separa simular de interpretar', (tester) async {
      await tester.pumpWidget(_app(const EstadoPlano(
        fase: FasePlano.interpretando,
        diaAtual: 7,
        diasTotal: 7,
      )));
      await tester.pump();
      expect(find.textContaining('Analisando o plano'), findsOneWidget);
    });
  });

  group('plano pronto', () {
    testWidgets('mostra o total, a receita e um cartão por dia',
        (tester) async {
      await tester.pumpWidget(_app(_pronto()));
      await tester.pumpAndSettle();

      expect(find.text('Encaixes na janela'), findsOneWidget);
      expect(find.text('5'), findsWidgets, reason: '2 + 3 encaixes');
      expect(find.text('Receita adicional'), findsOneWidget);
      expect(find.text('Plano por dia'), findsOneWidget);

      // Um cartão por dia, com o número em destaque.
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('o dia sem espaço aparece marcado, não escondido',
        (tester) async {
      await tester.pumpWidget(_app(_pronto()));
      await tester.pumpAndSettle();
      // É justamente onde o gestor precisa olhar. O selo usa o rótulo curto
      // ("Cheio") porque uma pílula de ~90px não comporta a frase inteira.
      expect(find.text('Cheio'), findsOneWidget);
      expect(find.text('+0'), findsOneWidget);
    });

    testWidgets('dia que falhou não some da faixa', (tester) async {
      final p = _plano([
        _dia(dia: 7),
        _dia(dia: 8, erro: 'agenda indisponível', agendados: 0, encaixes: 0),
      ]);
      await tester.pumpWidget(_app(_pronto(plano: p)));
      await tester.pumpAndSettle();

      // Omitir daria a impressão de que o dia foi olhado e estava tranquilo.
      expect(find.text('Não simulado'), findsOneWidget);
    });
  });

  group('separação entre cálculo e opinião', () {
    testWidgets('a análise da IA é rotulada como tal', (tester) async {
      await tester.pumpWidget(_app(_pronto()));
      await tester.pumpAndSettle();

      expect(find.text('Leitura da IA'), findsOneWidget);
      expect(find.textContaining('Texto gerado por IA'), findsOneWidget);
      expect(find.text('Conferido'), findsOneWidget);
    });

    testWidgets('IA fora do ar NÃO derruba o plano', (tester) async {
      final p = _plano();
      await tester.pumpWidget(_app(_pronto(
        plano: p,
        sugestao: SugestaoPlano.semIa(p, 'HTTP 503'),
      )));
      await tester.pumpAndSettle();

      // O produto da aba são os números — eles continuam.
      expect(find.text('Encaixes na janela'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.textContaining('leitura por IA não está disponível'),
          findsOneWidget);
      expect(find.textContaining('continua válido'), findsOneWidget);
    });

    testWidgets('número inventado pela IA é denunciado na tela',
        (tester) async {
      const v = ValidadorNumeros();
      final p = _plano();
      // A IA "recomendou" 99 — número que não existe na simulação.
      const texto = 'Recomendo 99 encaixes na terça.';
      final validacao = v.validar(texto, p.numerosPermitidos);

      await tester.pumpWidget(_app(_pronto(
        plano: p,
        sugestao: SugestaoPlano(
          plano: p,
          analise: v.anotar(texto, validacao),
          validacao: validacao,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Não conferido'), findsOneWidget);
      expect(find.textContaining('não veio da simulação'), findsOneWidget);
      // Marcado, não apagado: a frase continua visível com o alerta.
      expect(find.textContaining('99'), findsWidgets);
    });
  });

  group('responsividade', () {
    testWidgets('cabe em tela estreita', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_app(_pronto()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('e em tela larga', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_app(_pronto()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Plano por dia'), findsOneWidget);
    });
  });
}
