import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/markov_engine.dart';
import 'package:vitta_app/features/projecao_12m/monitoramento.dart';
import 'package:vitta_app/features/projecao_12m/partida_a_frio.dart';
import 'package:vitta_app/features/projecao_12m/piloto_poder.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';
import 'package:vitta_app/features/projecao_12m/vazamento_guard.dart';

/// Governança do motor: vazamento, poder do piloto, partida a frio e
/// monitoramento.
///
/// Vários destes testes conferem números que a **própria especificação
/// publica** — a tabela de tamanho de amostra da seção 16, verificada aqui até
/// a unidade. Um documento que diz ter calculado os valores merece ser
/// conferido de volta.
void main() {
  group('Guarda de vazamento', () {
    test('variável de tratamento é bloqueada no treino', () {
      for (final f in CatalogoFeatures.deTratamento) {
        expect(GuardaVazamento.limpo([f.nome]), isFalse,
            reason: '${f.nome} é decidida pela intervenção que se quer avaliar');
      }
      expect(CatalogoFeatures.deTratamento.map((f) => f.nome),
          containsAll(['lembrete_enviado', 'quantidade_lembretes']));
    });

    test('variável pós-fato é bloqueada — o modelo não seria servível', () {
      expect(
        () => GuardaVazamento.exigirLimpo(['tempo_ate_confirmacao_horas']),
        throwsA(isA<VazamentoDetectado>()),
      );
    });

    test('o alvo não é preditor de si mesmo', () {
      expect(GuardaVazamento.limpo(['status_final']), isFalse);
    });

    test('conjunto legítimo passa', () {
      expect(
        GuardaVazamento.limpo([
          'dias_antecedencia',
          'canal_agendamento',
          'especialidade',
          'historico_faltas',
          'historico_cancelamentos',
          'confirmacao',
        ]),
        isTrue,
      );
    });

    test('coluna desconhecida é suspeita, não aprovada', () {
      // Numa tabela de saúde, a coluna que ninguém classificou é onde o
      // vazamento costuma entrar.
      final achados = GuardaVazamento.analisar(['renda_familiar_estimada']);
      expect(achados, hasLength(1));
      expect(achados.single.disponibilidade, isNull);
      expect(achados.single.motivo, contains('fora do catálogo'));
    });

    test('filtrar deixa passar só o que pode treinar', () {
      final restou = GuardaVazamento.filtrar([
        'dias_antecedencia',
        'lembrete_enviado',
        'tempo_ate_confirmacao_horas',
        'historico_faltas',
        'status_final',
      ]);
      expect(restou, ['dias_antecedencia', 'historico_faltas']);
    });

    test('a exceção nomeia todas as colunas problemáticas de uma vez', () {
      try {
        GuardaVazamento.exigirLimpo(
            ['dias_antecedencia', 'lembrete_enviado', 'status_final']);
        fail('deveria ter lançado');
      } on VazamentoDetectado catch (e) {
        expect(e.achados, hasLength(2));
        expect(e.toString(), contains('lembrete_enviado'));
        expect(e.toString(), contains('status_final'));
      }
    });

    test('capacidade ofertada e tentativas sem vaga estão no catálogo', () {
      // Sem elas a demanda observada é confundida com demanda real: quando a
      // agenda esgota, o excedente é censurado à direita e some.
      expect(CatalogoFeatures.de('capacidade_ofertada'), isNotNull);
      expect(CatalogoFeatures.de('tentativas_sem_vaga'), isNotNull);
      expect(GuardaVazamento.limpo(['capacidade_ofertada']), isTrue);
    });
  });

  group('Poder do piloto', () {
    test('reproduz a tabela de tamanho de amostra da especificação', () {
      // Teste bilateral de duas proporções, α = 0,05, poder 80%, taxa-base 22%.
      const alvo = [(0.10, 5361), (0.15, 2336), (0.20, 1287), (0.30, 547), (0.40, 293)];
      for (final (reducao, esperado) in alvo) {
        final d = PoderPiloto.dimensionar(reducaoRelativa: reducao);
        expect(d.nPorBraco, esperado,
            reason: 'redução de ${(reducao * 100).round()}%');
        expect(d.nTotal, esperado * 2);
      }
    });

    test('reproduz a tabela de meses por volume da clínica', () {
      final d = PoderPiloto.dimensionar(reducaoRelativa: 0.20);
      const esperado = {400: 6.4, 800: 3.2, 1200: 2.1, 2000: 1.3};
      for (final e in esperado.entries) {
        expect(d.mesesPara(e.key), closeTo(e.value, 0.05));
      }
    });

    test('a taxa esperada do braço tratado bate com a publicada', () {
      const alvo = [(0.10, 0.198), (0.15, 0.187), (0.20, 0.176), (0.30, 0.154)];
      for (final (reducao, taxa) in alvo) {
        expect(PoderPiloto.dimensionar(reducaoRelativa: reducao).taxaEsperada,
            closeTo(taxa, 0.0005));
      }
    });

    test('efeito menor exige amostra maior — monotonia', () {
      var anterior = 0;
      for (final r in [0.40, 0.30, 0.20, 0.15, 0.10]) {
        final n = PoderPiloto.dimensionar(reducaoRelativa: r).nPorBraco;
        expect(n, greaterThan(anterior));
        anterior = n;
      }
    });

    test('mais poder exige mais amostra', () {
      final p80 = PoderPiloto.dimensionar(reducaoRelativa: 0.20, poder: 0.80);
      final p90 = PoderPiloto.dimensionar(reducaoRelativa: 0.20, poder: 0.90);
      expect(p90.nPorBraco, greaterThan(p80.nPorBraco));
    });

    test('clínica pequena não prova 20% em 90 dias — e o texto diz isso', () {
      final v = PoderPiloto.avaliar(
        agendamentosPorMes: 400,
        mesesDisponiveis: 3,
      );
      expect(v.viavel, isFalse);
      expect(v.mesesNecessarios, closeTo(6.4, 0.05));
      expect(v.recomendacao, contains('estatística não entrega'));
    });

    test('clínica de 800/mês prova 20% em pouco mais de 3 meses', () {
      final v = PoderPiloto.avaliar(
        agendamentosPorMes: 800,
        mesesDisponiveis: 4,
      );
      expect(v.viavel, isTrue);
      expect(v.recomendacao, contains('detecta'));
    });

    test('quando o efeito buscado não cabe, informa o que cabe', () {
      final v = PoderPiloto.avaliar(
        agendamentosPorMes: 600,
        mesesDisponiveis: 3,
        reducaoRelativa: 0.10,
      );
      expect(v.viavel, isFalse);
      final menor = v.menorReducaoDetectavel;
      expect(menor, isNotNull);
      expect(menor!, greaterThan(0.10));
      expect(
        PoderPiloto.dimensionar(reducaoRelativa: menor)
            .mesesPara(600),
        lessThanOrEqualTo(3.0),
      );
    });

    test('volume ínfimo não sustenta piloto de eficácia nenhum', () {
      final v = PoderPiloto.avaliar(
        agendamentosPorMes: 30,
        mesesDisponiveis: 2,
        reducaoRelativa: 0.20,
      );
      expect(v.menorReducaoDetectavel, isNull);
      expect(v.recomendacao, contains('viabilidade operacional'));
    });

    test('probit reproduz os quantis conhecidos', () {
      expect(PoderPiloto.probit(0.975), closeTo(1.959964, 1e-5));
      expect(PoderPiloto.probit(0.80), closeTo(0.8416212, 1e-5));
      expect(PoderPiloto.probit(0.50), closeTo(0.0, 1e-9));
      expect(PoderPiloto.probit(0.025), closeTo(-1.959964, 1e-5));
      expect(PoderPiloto.probit(0.999), closeTo(3.090232, 1e-4));
    });
  });

  group('Partida a frio', () {
    test('as quatro faixas da especificação existem e classificam', () {
      expect(MaturidadeHistorico.de(0), MaturidadeHistorico.semHistorico);
      expect(MaturidadeHistorico.de(2), MaturidadeHistorico.ateTresMeses);
      expect(MaturidadeHistorico.de(3), MaturidadeHistorico.ateTresMeses);
      expect(MaturidadeHistorico.de(4), MaturidadeHistorico.ateOnzeMeses);
      expect(MaturidadeHistorico.de(11), MaturidadeHistorico.ateOnzeMeses);
      expect(MaturidadeHistorico.de(12), MaturidadeHistorico.completo);
      expect(MaturidadeHistorico.de(60), MaturidadeHistorico.completo);
    });

    test('menos histórico = shrinkage mais forte e incerteza maior', () {
      final novo =
          PartidaAFrio.avaliar(mesesDeHistorico: 0, desfechosObservados: 0);
      final medio =
          PartidaAFrio.avaliar(mesesDeHistorico: 6, desfechosObservados: 3000);
      final maduro =
          PartidaAFrio.avaliar(mesesDeHistorico: 24, desfechosObservados: 20000);

      expect(novo.kShrinkage, greaterThan(medio.kShrinkage));
      expect(medio.kShrinkage, greaterThan(maduro.kShrinkage));
      expect(novo.wapeSugerido, greaterThan(maduro.wapeSugerido));
      expect(maduro.kShrinkage, PartidaAFrio.kMaduro);
    });

    test('o peso migra suavemente do cohort para a clínica', () {
      final a = PartidaAFrio.avaliar(
          mesesDeHistorico: 2, desfechosObservados: 800);
      // Sem descontinuidade: o peso cresce monotonicamente com n.
      var anterior = -1.0;
      for (final n in [0, 10, 50, 200, 800, 5000]) {
        final w = a.pesoDoSegmento(n);
        expect(w, greaterThan(anterior));
        expect(w, inInclusiveRange(0.0, 1.0));
        anterior = w;
      }
      expect(a.pesoDoSegmento(0), 0.0, reason: 'sem dado, só o cohort fala');
    });

    test('o prior Beta nunca é mais forte que a evidência observada', () {
      // Usar nHistorico grande sem ter os desfechos é a forma mais silenciosa
      // de estreitar o intervalo indevidamente.
      final a = PartidaAFrio.avaliar(
          mesesDeHistorico: 1, desfechosObservados: 120);
      expect(a.nHistoricoEfetivo, 120);

      const base = ProjecaoConfig();
      final ajustada = a.aplicar(base);
      expect(ajustada.nHistorico, lessThanOrEqualTo(base.nHistorico));
      expect(ajustada.nHistorico, 120);
      expect(ajustada.wapeForecast, greaterThan(base.wapeForecast));
    });

    test('clínica sem histórico produz projeção apenas ilustrativa', () {
      final a =
          PartidaAFrio.avaliar(mesesDeHistorico: 0, desfechosObservados: 0);
      expect(a.maturidade.apenasIlustrativa, isTrue);
      expect(a.maturidade.naoPrometer, contains('Nenhuma projeção'));
      expect(a.resumo, contains('Não prometer'));
    });

    test('histórico completo não impõe restrição', () {
      final a = PartidaAFrio.avaliar(
          mesesDeHistorico: 18, desfechosObservados: 15000);
      expect(a.maturidade.naoPrometer, isEmpty);
      expect(a.maturidade.apenasIlustrativa, isFalse);
    });
  });

  group('Monitoramento', () {
    List<MesRealizado> meses(List<int> realizados,
            {int p05 = 80, int p50 = 100, int p95 = 120}) =>
        [
          for (var i = 0; i < realizados.length; i++)
            MesRealizado(
              rotulo: 'M${i + 1}',
              p05: p05,
              p50: p50,
              p95: p95,
              realizado: realizados[i],
            ),
        ];

    test('cobertura conta os meses dentro da faixa', () {
      final c = Monitoramento.cobertura(
          meses([85, 90, 100, 110, 119, 130, 70, 95, 105, 99, 101, 88]));
      expect(c.meses, 12);
      expect(c.dentro, 10);
      expect(c.observada, closeTo(10 / 12, 1e-9));
    });

    test('intervalo estreito demais é o caso perigoso — parece precisão', () {
      // Metade dos meses fora de uma faixa rotulada como 90%: foi exatamente
      // essa a falha que a revisão da especificação corrige.
      final c = Monitoramento.cobertura(
          meses([50, 150, 60, 140, 55, 145, 100, 100, 100, 100, 100, 100]));
      expect(c.observada, closeTo(0.5, 1e-9));
      expect(c.estreitoDemais, isTrue);
      expect(c.calibrado, isFalse);
      expect(c.veredito, contains('estreito demais'));
    });

    test('cobertura próxima do nominal aprova', () {
      final c = Monitoramento.cobertura(
          meses([85, 90, 100, 110, 119, 100, 95, 105, 99, 101, 88, 130]));
      expect(c.observada, closeTo(11 / 12, 1e-9));
      expect(c.calibrado, isTrue);
    });

    test('poucos meses não autorizam veredito', () {
      final c = Monitoramento.cobertura(meses([50, 150]));
      expect(c.veredito, contains('ainda não há base'));
    });

    test('divergência de Jensen-Shannon é zero para matrizes iguais', () {
      final m = MarkovEngine.referencia();
      expect(Monitoramento.divergenciaJensenShannon(m, m), closeTo(0, 1e-12));
    });

    test('Jensen-Shannon é simétrica e finita com zeros', () {
      final a = MarkovEngine.referencia();
      final b = MarkovEngine.aplicarIntervencao(a,
          reducaoFalta: 0.50, reducaoCancelamento: 0.50);
      final ab = Monitoramento.divergenciaJensenShannon(a, b);
      final ba = Monitoramento.divergenciaJensenShannon(b, a);
      expect(ab, closeTo(ba, 1e-12), reason: 'a ordem não pode mudar o número');
      expect(ab, greaterThan(0));
      expect(ab.isFinite, isTrue);
      expect(ab, lessThanOrEqualTo(1.0));
    });

    test('gatilho do Markov dispara acima do limite', () {
      final a = MarkovEngine.referencia();
      final quieto = MarkovEngine.aplicarIntervencao(a, reducaoFalta: 0.01);
      // O limite de 0,05 da especificação é conservador: nesta cadeia ele
      // corresponde a zerar por completo falta e cancelamento (JS ≈ 0,096).
      // Uma redução de 50% mexe bem menos — JS ≈ 0,013 — e não dispara.
      final ruidoso = MarkovEngine.aplicarIntervencao(a,
          reducaoFalta: 1.0, reducaoCancelamento: 1.0);

      expect(
          Monitoramento.gatilhoMarkov(vigente: a, janela: quieto).disparou,
          isFalse);
      final g = Monitoramento.gatilhoMarkov(vigente: a, janela: ruidoso);
      expect(g.disparou, isTrue);
      expect(g.acao, contains('shrinkage'));
    });

    test('ECE acima de 0,05 manda recalibrar antes de re-treinar', () {
      final gs = Monitoramento.gatilhosRisco(
          prAucAtual: 0.40, prAucReferencia: 0.41, ece: 0.09);
      final ece = gs.firstWhere((g) => g.sinal.contains('ECE'));
      expect(ece.disparou, isTrue);
      expect(ece.acao, contains('Recalibrar primeiro'));

      final prauc = gs.firstWhere((g) => g.sinal.contains('PR-AUC'));
      expect(prauc.disparou, isFalse,
          reason: 'calibração degrada antes da discriminação');
    });

    test('gatilho do forecast exige dois períodos seguidos', () {
      expect(
        Monitoramento.gatilhosForecast(
                wapeObservado: 0.20,
                wapeValidacao: 0.12,
                periodosSeguidosAcima: 1)
            .first
            .disparou,
        isFalse,
      );
      expect(
        Monitoramento.gatilhosForecast(
                wapeObservado: 0.20,
                wapeValidacao: 0.12,
                periodosSeguidosAcima: 2)
            .first
            .disparou,
        isTrue,
      );
    });

    test('gatilho do simulador exige dois meses seguidos fora', () {
      // Alternar dentro/fora não dispara; dois seguidos sim.
      expect(
        Monitoramento.gatilhoSimulador(
                meses([50, 100, 150, 100, 50, 100, 100, 100, 100, 100, 100, 100]))
            .disparou,
        isFalse,
      );
      expect(
        Monitoramento.gatilhoSimulador(
                meses([100, 100, 50, 40, 100, 100, 100, 100, 100, 100, 100, 100]))
            .disparou,
        isTrue,
      );
    });

    test('a janela de alerta nasce com o atraso do desfecho', () {
      // O desfecho só se conhece na data da consulta: medir performance com
      // janela menor que a antecedência mostra "sem dados", que alguém lê como
      // "sem problema".
      expect(Monitoramento.janelaMinimaDeAlertaEmDias(30),
          greaterThanOrEqualTo(30));
    });
  });
}
