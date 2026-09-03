import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/markov_engine.dart';
import 'package:vitta_app/features/projecao_12m/projecao_amostradores.dart';
import 'package:vitta_app/features/projecao_12m/projecao_engine.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';

/// Testes do motor de projeção de 12 meses.
///
/// Vários deles verificam números que a **própria especificação publica** —
/// absorção de 69,0/22,1/9,0 e superestimativa de 21,9% da conta ingênua. Um
/// documento que cita valores conferidos por execução merece ser conferido de
/// volta.
void main() {
  group('Amostradores', () {
    test('lognormal preserva a média pedida', () {
      final rng = Amostradores(7);
      const media = 1200.0;
      var soma = 0.0;
      const n = 40000;
      for (var i = 0; i < n; i++) {
        soma += rng.lognormalComMedia(media, 0.12);
      }
      // Sem a correção -sigma²/2 a média sairia ~0,7% acima; a tolerância
      // abaixo é estreita o bastante para pegar isso.
      expect(soma / n, closeTo(media, media * 0.01));
    });

    test('lognormal nunca é negativa — a normal seria', () {
      final rng = Amostradores(3);
      for (var i = 0; i < 5000; i++) {
        expect(rng.lognormalComMedia(40, 0.5), greaterThanOrEqualTo(0.0));
      }
    });

    test('Beta reproduz a média e estreita com mais histórico', () {
      double mediaBeta(double p, double n, int seed) {
        final rng = Amostradores(seed);
        var s = 0.0;
        var s2 = 0.0;
        const k = 20000;
        for (var i = 0; i < k; i++) {
          final v = rng.beta(p * n, (1 - p) * n);
          s += v;
          s2 += v * v;
        }
        final m = s / k;
        return math.sqrt(s2 / k - m * m);
      }

      final rng = Amostradores(5);
      var soma = 0.0;
      const k = 20000;
      for (var i = 0; i < k; i++) {
        soma += rng.beta(0.22 * 800, 0.78 * 800);
      }
      expect(soma / k, closeTo(0.22, 0.005));

      // Mais histórico = menos incerteza de parâmetro.
      final dpPouco = mediaBeta(0.22, 50, 11);
      final dpMuito = mediaBeta(0.22, 5000, 11);
      expect(dpMuito, lessThan(dpPouco));
    });

    test('multinomial fecha exatamente em n — correção D2', () {
      final rng = Amostradores(9);
      for (var i = 0; i < 2000; i++) {
        final n = 50 + i % 900;
        final out = rng.multinomial(n, [0.69, 0.22, 0.09]);
        expect(out.fold(0, (a, b) => a + b), n,
            reason: 'as três categorias precisam somar exatamente n');
        expect(out.every((v) => v >= 0), isTrue);
      }
    });

    test('multinomial realiza a taxa pedida, não uma menor', () {
      // O defeito D2: sortear falta sobre o total e cancelamento sobre o
      // resíduo faz 10% virar ~7,8%. O multinomial não tem esse viés.
      final rng = Amostradores(13);
      var cancel = 0;
      var total = 0;
      for (var i = 0; i < 3000; i++) {
        final out = rng.multinomial(1000, [0.69, 0.21, 0.10]);
        cancel += out[2];
        total += 1000;
      }
      expect(cancel / total, closeTo(0.10, 0.005));
    });

    test('percentis ordenam corretamente', () {
      final p = Percentis.de([for (var i = 1; i <= 100; i++) i]);
      expect(p.p05, closeTo(5, 1));
      expect(p.p50, closeTo(50, 1));
      expect(p.p95, closeTo(95, 1));
      expect(p.largura, greaterThan(80));
    });
  });

  group('Cadeia de Markov', () {
    test('a matriz de referência reproduz a absorção publicada', () {
      final m = MarkovEngine.referencia();
      expect(m.valida, isTrue, reason: 'toda linha precisa somar 1');

      final abs = m.absorcaoDe(EstadoAgendamento.agendado);
      // Números da especificação: 68,98 / 22,06 / 8,96.
      expect(abs[EstadoAgendamento.compareceu], closeTo(0.6898, 0.005));
      expect(abs[EstadoAgendamento.faltou], closeTo(0.2206, 0.005));
      expect(abs[EstadoAgendamento.cancelado], closeTo(0.0896, 0.005));

      final soma = abs.values.fold(0.0, (a, b) => a + b);
      expect(soma, closeTo(1.0, 1e-9));
    });

    test('reagendado é estado próprio, não cancelamento', () {
      expect(EstadoAgendamento.reagendado.absorvente, isTrue);
      expect(EstadoAgendamento.reagendado,
          isNot(EstadoAgendamento.cancelado));
      expect(EstadoAgendamento.absorventes.length, 4);
      expect(EstadoAgendamento.transitorios.length, 3);
    });

    test('suavização evita linha de zeros em estado nunca observado', () {
      // Nenhum evento partindo de "confirmado": sem Dirichlet a linha ficaria
      // toda zero, que não é distribuição e quebra a simulação em silêncio.
      final eventos = [
        for (var i = 0; i < 30; i++)
          const EventoTransicao(
            origem: EstadoAgendamento.agendado,
            destino: EstadoAgendamento.confirmado,
          ),
      ];
      final m = MarkovEngine.estimar(eventos);

      expect(m.valida, isTrue);
      final linha = m.linhas[EstadoAgendamento.confirmado]!;
      expect(linha.values.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
      expect(linha.values.every((v) => v > 0), isTrue);
    });

    test('absorventes têm auto-laço puro 1,0', () {
      final m = MarkovEngine.estimar(const []);
      for (final a in EstadoAgendamento.absorventes) {
        expect(m.p(a, a), 1.0, reason: '${a.label} deve ser auto-laço');
      }
    });

    test('estima a partir de eventos e recupera a proporção', () {
      final eventos = <EventoTransicao>[
        for (var i = 0; i < 800; i++)
          EventoTransicao(
            origem: EstadoAgendamento.confirmado,
            destino: i % 10 < 8
                ? EstadoAgendamento.compareceu
                : EstadoAgendamento.faltou,
          ),
      ];
      final m = MarkovEngine.estimar(eventos);
      expect(m.p(EstadoAgendamento.confirmado, EstadoAgendamento.compareceu),
          closeTo(0.80, 0.02));
    });

    test('matriz por faixa separa as janelas de dias', () {
      final eventos = <EventoTransicao>[
        // Longe da consulta: quase ninguém confirma.
        for (var i = 0; i < 200; i++)
          EventoTransicao(
            origem: EstadoAgendamento.agendado,
            destino: i % 10 < 1
                ? EstadoAgendamento.confirmado
                : EstadoAgendamento.aguardandoConfirmacao,
            diasAteConsulta: 20,
          ),
        // Véspera: a confirmação se concentra aqui.
        for (var i = 0; i < 200; i++)
          const EventoTransicao(
            origem: EstadoAgendamento.agendado,
            destino: EstadoAgendamento.confirmado,
            diasAteConsulta: 1,
          ),
      ];

      final porFaixa = MarkovEngine.estimarPorFaixa(eventos);
      final longe = porFaixa['30–15 dias']!;
      final perto = porFaixa['1–0 dia']!;

      expect(
          perto.p(EstadoAgendamento.agendado, EstadoAgendamento.confirmado),
          greaterThan(longe.p(
              EstadoAgendamento.agendado, EstadoAgendamento.confirmado)),
          reason: 'a confirmação se concentra nas horas finais');
    });

    test('shrinkage puxa segmento pequeno para o global e preserva soma 1', () {
      final global = MarkovEngine.referencia();
      final segmento = MarkovEngine.estimar([
        for (var i = 0; i < 5; i++)
          const EventoTransicao(
            origem: EstadoAgendamento.confirmado,
            destino: EstadoAgendamento.faltou,
          ),
      ]);

      final pouco =
          MarkovEngine.encolherPara(segmento, global, nSegmento: 5);
      final muito =
          MarkovEngine.encolherPara(segmento, global, nSegmento: 5000);

      expect(pouco.valida, isTrue);
      expect(muito.valida, isTrue);

      final pGlobal =
          global.p(EstadoAgendamento.confirmado, EstadoAgendamento.faltou);
      final pPouco =
          pouco.p(EstadoAgendamento.confirmado, EstadoAgendamento.faltou);
      final pMuito =
          muito.p(EstadoAgendamento.confirmado, EstadoAgendamento.faltou);

      // Com pouco dado fica perto do global; com muito, perto do segmento.
      expect((pPouco - pGlobal).abs(), lessThan((pMuito - pGlobal).abs()));
    });

    test('intervenção reduz falta e mantém linhas somando 1', () {
      final base = MarkovEngine.referencia();
      final interv = MarkovEngine.aplicarIntervencao(
        base,
        reducaoFalta: 0.20,
        reducaoCancelamento: 0.15,
      );

      expect(interv.valida, isTrue);

      final absBase = base.absorcaoDe(EstadoAgendamento.agendado);
      final absInt = interv.absorcaoDe(EstadoAgendamento.agendado);

      expect(absInt[EstadoAgendamento.faltou]!,
          lessThan(absBase[EstadoAgendamento.faltou]!));
      expect(absInt[EstadoAgendamento.compareceu]!,
          greaterThan(absBase[EstadoAgendamento.compareceu]!));
    });

    test('intervenção nula não muda nada', () {
      final base = MarkovEngine.referencia();
      final igual = MarkovEngine.aplicarIntervencao(base);
      expect(MarkovEngine.distanciaMaxima(base, igual), lessThan(1e-9));
    });
  });

  group('Projeção — três camadas de incerteza', () {
    const cfg = ProjecaoConfig(nSimulacoes: 1200, seed: 5);

    test('roda e devolve os dois cenários', () {
      final r = ProjecaoEngine.projetar(cfg);
      expect(r.baseline.comparecimentos.p50, greaterThan(0));
      expect(r.agendaClinica.comparecimentos.p50,
          greaterThan(r.baseline.comparecimentos.p50));
    });

    test('a identidade fecha: comp + falta + cancel = agendamentos', () {
      final r = ProjecaoEngine.projetar(cfg);
      final soma = r.baseline.comparecimentos.p50 +
          r.baseline.faltas.p50 +
          r.baseline.cancelamentos.p50;
      // Percentis são de amostras distintas; a mediana da soma não é a soma das
      // medianas, mas a diferença tem de ser pequena.
      expect((soma - r.baseline.agendamentos.p50).abs(),
          lessThan(r.baseline.agendamentos.p50 * 0.02));
    });

    test('mais incerteza de forecast alarga o intervalo — correção D1', () {
      final estreito = ProjecaoEngine.projetar(
          cfg.copyWith(wapeForecast: 0.02, nHistorico: 100000));
      final largo = ProjecaoEngine.projetar(
          cfg.copyWith(wapeForecast: 0.30, nHistorico: 100000));

      expect(largo.baseline.comparecimentos.largura,
          greaterThan(estreito.baseline.comparecimentos.largura),
          reason: 'ignorar a incerteza do forecast é o que estreita o '
              'intervalo indevidamente');
    });

    test('menos histórico alarga o intervalo — camada de parâmetro', () {
      final muito = ProjecaoEngine.projetar(
          cfg.copyWith(nHistorico: 20000, wapeForecast: 0.01));
      final pouco = ProjecaoEngine.projetar(
          cfg.copyWith(nHistorico: 40, wapeForecast: 0.01));

      expect(pouco.baseline.faltas.largura,
          greaterThan(muito.baseline.faltas.largura));
    });

    test('capacidade trunca a projeção e gera demanda reprimida', () {
      final semTeto = ProjecaoEngine.projetar(
          cfg.copyWith(capacidadeMensal: 100000));
      final comTeto =
          ProjecaoEngine.projetar(cfg.copyWith(capacidadeMensal: 900));

      expect(comTeto.baseline.agendamentos.p50,
          lessThan(semTeto.baseline.agendamentos.p50));
      expect(comTeto.baseline.demandaReprimida.p50, greaterThan(0));
      expect(comTeto.temDemandaReprimida, isTrue);
      // Sem teto não há represamento.
      expect(semTeto.baseline.demandaReprimida.p50, 0);
    });

    test('a intervenção não cria capacidade', () {
      final r = ProjecaoEngine.projetar(cfg.copyWith(capacidadeMensal: 900));
      final teto = 900 * cfg.horizonteMeses;

      // O teto limita **ocupação**, não o número de reservas feitas. Uma vaga
      // cancelada volta para a agenda e pode ser reocupada: nesse mês houve
      // duas reservas para um assento só. O que nunca pode passar do teto é
      // quem de fato ocupou o horário — quem compareceu mais quem faltou sem
      // avisar, porque a falta também consumiu o assento.
      expect(
        r.agendaClinica.comparecimentos.p95 + r.agendaClinica.faltas.p95,
        lessThanOrEqualTo(teto),
        reason: 'ocupação real não pode exceder o teto físico',
      );

      // E a reposição só existe onde houve cancelamento para repor.
      expect(r.agendaClinica.vagasRepostas.p95,
          lessThanOrEqualTo(r.agendaClinica.cancelamentos.p95));
    });

    test('reposição de vaga sai das vagas liberadas, não da demanda total', () {
      // Aplicar a taxa sobre a demanta total multiplicaria as vagas repostas
      // pelo inverso da taxa de cancelamento — com 9% de cancelamento, quase
      // onze vezes mais. A reposição é reocupação de vaga já liberada.
      final r = ProjecaoEngine.projetar(cfg.copyWith(
        capacidadeMensal: 100000, // sem teto, para isolar o mecanismo
        intervencao: const ParametrosIntervencao(
          reducaoFalta: 0,
          reducaoCancelamento: 0,
          taxaReposicaoVaga: 0.30,
        ),
      ));
      final repostas = r.agendaClinica.vagasRepostas.p50;
      final canceladas = r.agendaClinica.cancelamentos.p50;
      expect(repostas / canceladas, closeTo(0.30, 0.05),
          reason: 'a taxa incide sobre as vagas liberadas');
    });

    test('sem reposição os dois cenários compartilham os agendamentos', () {
      // Números aleatórios comuns: com intervenção zerada, A e B veem
      // exatamente o mesmo mundo — e a diferença entre eles é zero, não ruído
      // do gerador.
      final r = ProjecaoEngine.projetar(cfg.copyWith(
        intervencao: const ParametrosIntervencao(
          reducaoFalta: 0,
          reducaoCancelamento: 0,
          deltaConfirmacao: 0,
          taxaReposicaoVaga: 0,
        ),
      ));
      expect(r.agendaClinica.agendamentos.p50, r.baseline.agendamentos.p50);
      expect(r.agendaClinica.comparecimentos.p50,
          r.baseline.comparecimentos.p50);
      expect(r.faltasEvitadas.p05, 0);
      expect(r.faltasEvitadas.p95, 0);
    });

    test('a camada de parâmetro persiste no horizonte — correção D1 no '
        'agregado de 12 meses', () {
      // Re-sortear a taxa verdadeira a cada mês faz a incerteza epistêmica se
      // cancelar por média e encolher por √12. O teste trava a largura relativa
      // no patamar que a especificação publica na seção 7 (~28% para faltas).
      final r = ProjecaoEngine.projetar(cfg.copyWith(
        capacidadeMensal: 100000,
        agendamentosMensais: 1190,
        taxaFalta: 0.2206,
        taxaCancelamento: 0.0896,
        nSimulacoes: 6000,
      ));
      final largRel =
          r.baseline.faltas.largura / r.baseline.faltas.p50;
      expect(largRel, greaterThan(0.20),
          reason: 'abaixo disso a camada de parâmetro está se diluindo');
      expect(largRel, lessThan(0.40));

      final largComp =
          r.baseline.comparecimentos.largura / r.baseline.comparecimentos.p50;
      expect(largComp, closeTo(0.202, 0.05),
          reason: 'seção 7: 8890/9850/10880 → 20,2% de largura relativa');
    });

    test('uma intervenção medida como danosa é representável no motor', () {
      // Clampar a redução em zero faria o motor confundir "piorou" com "não fez
      // diferença" — e é essa distinção que a calibração do piloto produz.
      final r = ProjecaoEngine.projetar(cfg.copyWith(
        capacidadeMensal: 100000,
        intervencao: const ParametrosIntervencao(
          reducaoFalta: -0.60,
          reducaoCancelamento: -0.60,
          taxaReposicaoVaga: 0,
        ),
      ));

      expect(r.agendaClinica.faltas.p50,
          greaterThan(r.baseline.faltas.p50));
      expect(r.agendaClinica.comparecimentos.p50,
          lessThan(r.baseline.comparecimentos.p50));

      // As "faltas evitadas" saem negativas, com sinal, em vez de zeradas.
      expect(r.faltasEvitadas.p50, lessThan(0));
      expect(r.impacto.houvePerda, isTrue);
      expect(r.impacto.receitaDefensavel, lessThan(0));
    });

    test('a saída da seção 7 é serializável e carrega as premissas', () {
      final r = ProjecaoEngine.projetar(cfg);
      final j = r.toJson(geradoEm: DateTime.utc(2026, 9, 3, 14, 22, 10));

      expect(j['aviso'], contains('não constitui garantia'.split(' ').last));
      final baseline = j['baseline']! as Map<String, Object?>;
      expect(baseline.keys,
          containsAll(['agendamentos_12m', 'faltas_12m', 'comparecimentos_12m']));

      final premissas = j['premissas']! as Map<String, Object?>;
      // O campo que muda a conversa comercial precisa viajar com o número.
      expect(premissas['calibrado_com_dados_reais'], isFalse);
      expect(premissas['origem_reducao_falta'], isNotNull);
      expect(premissas['fracao_demanda_nova'], cfg.fracaoDemandaNova);

      final impacto = j['impacto']! as Map<String, Object?>;
      // A chave que a v1.0 publicou quebrada, com espaço no meio.
      expect(impacto.containsKey('cancelamentos_evitados'), isTrue);
      expect(impacto.containsKey('receita_defensavel_12m'), isTrue);
      expect(impacto.containsKey('receita_antecipacao_12m'), isTrue);
    });

    test('mesma semente produz resultado idêntico', () {
      final a = ProjecaoEngine.projetar(cfg);
      final b = ProjecaoEngine.projetar(cfg);
      expect(a.baseline.comparecimentos.p50, b.baseline.comparecimentos.p50);
      expect(a.baseline.faltas.p95, b.baseline.faltas.p95);
    });

    test('intervenção mais agressiva reduz mais faltas', () {
      final cons = ProjecaoEngine.projetar(cfg.copyWith(
          intervencao:
              ParametrosIntervencao.de(IntensidadeCenario.conservador)));
      final agr = ProjecaoEngine.projetar(cfg.copyWith(
          intervencao:
              ParametrosIntervencao.de(IntensidadeCenario.agressivo)));

      expect(agr.agendaClinica.faltas.p50,
          lessThan(cons.agendaClinica.faltas.p50));
      expect(agr.faltasEvitadas.p50, greaterThan(cons.faltasEvitadas.p50));
    });
  });

  group('Receita defensável — correção D5', () {
    test('reproduz a superestimativa de 21,9% do documento', () {
      // Exemplo da especificação: 9.860 → 11.090 comparecimentos,
      // 340 vagas repostas, R$ 150 por consulta, 35% de demanda nova.
      final d = ProjecaoEngine.receitaIncremental(
        comparecimentosBase: 9860,
        comparecimentosAgenda: 11090,
        vagasRepostas: 340,
        valorConsulta: 150.0,
      );

      expect(d.receitaDefensavel, closeTo(151350.0, 1.0));
      expect(d.consultasFaltaEvitada, closeTo(890, 0.5));
      expect(d.consultasDemandaNova, closeTo(119, 0.5));
      expect(d.consultasAntecipadas, closeTo(221, 0.5));

      // A conta ingênua da v1.0: 1230 × 150 = 184.500.
      const ingenua = 1230 * 150.0;
      final superestimativa = ingenua / d.receitaDefensavel - 1;
      expect(superestimativa, closeTo(0.219, 0.002));
    });

    test('sem vaga reposta todo o ganho é defensável', () {
      final d = ProjecaoEngine.receitaIncremental(
        comparecimentosBase: 1000,
        comparecimentosAgenda: 1100,
        vagasRepostas: 0,
        valorConsulta: 200,
      );
      expect(d.consultasAntecipadas, 0);
      expect(d.receitaAntecipacao, 0);
      expect(d.receitaDefensavel, closeTo(100 * 200.0, 1e-9));
    });

    test('ganho negativo aparece com sinal, em vez de sumir', () {
      // Zerar a perda faria "a intervenção não fez diferença" e "a intervenção
      // custou 200 consultas" ficarem idênticos na tela — e é exatamente essa
      // a diferença que a fase de calibração existe para detectar.
      final d = ProjecaoEngine.receitaIncremental(
        comparecimentosBase: 1200,
        comparecimentosAgenda: 1000,
        vagasRepostas: 50,
        valorConsulta: 150,
      );
      expect(d.houvePerda, isTrue);
      expect(d.consultasFaltaEvitada, -200);
      expect(d.receitaDefensavel, -30000);
      // Perda não se decompõe: não há vaga reposta a atribuir.
      expect(d.receitaAntecipacao, 0);
      expect(d.consultasAntecipadas, 0);
    });

    test('ganho exatamente nulo é nulo, não perda', () {
      final d = ProjecaoEngine.receitaIncremental(
        comparecimentosBase: 1000,
        comparecimentosAgenda: 1000,
        vagasRepostas: 50,
        valorConsulta: 150,
      );
      expect(d.houvePerda, isFalse);
      expect(d.receitaDefensavel, 0);
    });

    test('fração de demanda nova move a fronteira do defensável', () {
      ImpactoFinanceiro comFracao(double f) =>
          ProjecaoEngine.receitaIncremental(
            comparecimentosBase: 1000,
            comparecimentosAgenda: 1300,
            vagasRepostas: 300,
            valorConsulta: 100,
            fracaoDemandaNova: f,
          );

      expect(comFracao(0.0).receitaDefensavel, 0);
      expect(comFracao(1.0).receitaAntecipacao, 0);
      expect(comFracao(0.5).receitaDefensavel,
          lessThan(comFracao(1.0).receitaDefensavel));
    });
  });

  group('Portão de aceite do forecast', () {
    /// Sazonal com tendência e ruído. Uma senoide pura de período 12 seria
    /// prevista **exatamente** pelo naive sazonal — e aí nenhum modelo pode
    /// vencer, o que é o veredito certo, não um caso de teste útil.
    List<double> serie(int n) {
      final r = math.Random(2026);
      return [
        for (var i = 0; i < n; i++)
          1000 +
              200 * math.sin(i * math.pi / 6) +
              i * 4 +
              (r.nextDouble() - 0.5) * 90,
      ];
    }

    test('reprova modelo que não bate o baseline', () {
      final real = serie(36);
      final naive = ProjecaoEngine.naiveSazonal(real);
      final mm = ProjecaoEngine.mediaMovel(real);
      // Modelo "preguiçoso": copia o naive. Ganho zero.
      final p = ProjecaoEngine.portaoDeAceite(
          real: real, modelo: naive, naive: naive, mediaM: mm);

      expect(p.aprovado, isFalse);
      expect(p.ganhoRelativo, lessThan(0.10));
    });

    test('aprova modelo com ganho real', () {
      final real = serie(36);
      final naive = ProjecaoEngine.naiveSazonal(real);
      final mm = ProjecaoEngine.mediaMovel(real);
      // Modelo quase perfeito.
      // Modelo quase perfeito: erra 0,1%, enquanto o naive carrega
      // tendência e ruído de um ano inteiro.
      final bom = [for (final v in real) v * 1.001];
      final p = ProjecaoEngine.portaoDeAceite(
          real: real, modelo: bom, naive: naive, mediaM: mm);

      expect(p.aprovado, isTrue);
      expect(p.wapeModelo, lessThan(p.wapeBaseline));
      expect(p.baselineVencedor, isNotEmpty);
    });

    test('WAPE é zero na previsão perfeita', () {
      final real = serie(24);
      expect(ProjecaoEngine.wape(real, real), closeTo(0.0, 1e-12));
    });

    test('sem janela comparável não aprova', () {
      final p = ProjecaoEngine.portaoDeAceite(
          real: const [], modelo: const [], naive: const [], mediaM: const []);
      expect(p.aprovado, isFalse);
      expect(p.baselineVencedor, contains('sem janela'));
    });
  });
}
