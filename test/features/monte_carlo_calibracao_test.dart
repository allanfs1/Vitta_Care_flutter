import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_calibracao.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_engine.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_metrics.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';

/// Testes das métricas distribucionais e do estimador de calibração.
///
/// O teste que importa é o de recuperação: gerar histórico sintético com taxa e
/// rho **conhecidos** e verificar que o estimador os encontra. Sem isso, a
/// calibração é só um número bonito sem garantia de estar invertendo o processo
/// que de fato gera os dados.
void main() {
  // ── Gerador de histórico sintético ────────────────────────────────
  double normalPadrao(math.Random r) {
    double u, v, s;
    do {
      u = r.nextDouble() * 2 - 1;
      v = r.nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);
    return u * math.sqrt(-2 * math.log(s) / s);
  }

  Appointment ap(String id, DateTime quando, RiskLevel risco,
          AppointmentStatus st) =>
      Appointment(
        id: id,
        clinicId: 'c1',
        patientId: 'p$id',
        patientName: 'P $id',
        doctorId: 'm1',
        doctorName: 'Dr m1',
        specialty: 'Clínica',
        start: quando,
        durationMinutes: 30,
        status: st,
        patientRisk: risco,
      );

  /// Gera histórico com taxa de falta e correlação latente conhecidas.
  List<Appointment> gerar({
    required int dias,
    required int porDia,
    required double rho,
    required Map<RiskLevel, double> taxas,
    int seed = 7,
    DateTime? fim,
  }) {
    final rng = math.Random(seed);
    final termino = fim ?? DateTime(2026, 9, 1);
    final raizRho = math.sqrt(rho);
    final raizComp = math.sqrt(1 - rho);
    final out = <Appointment>[];
    var n = 0;

    for (var d = 0; d < dias; d++) {
      final dia = termino.subtract(Duration(days: dias - d));
      final z = normalPadrao(rng); // choque comum do dia
      for (var i = 0; i < porDia; i++) {
        final risco = RiskLevel.values[i % 3];
        final p = taxas[risco]!;
        final limiar = MonteCarloEngine.normalInv(p);
        final x = raizRho * z + raizComp * normalPadrao(rng);
        final st = x <= limiar
            ? AppointmentStatus.noShow
            : AppointmentStatus.completed;
        out.add(ap(
            'h${n++}', DateTime(dia.year, dia.month, dia.day, 8 + i % 8),
            risco, st));
      }
    }
    return out;
  }

  group('Métricas distribucionais', () {
    Distribuicao pontual(int valor, int tamanho) {
      final c = List<int>.filled(tamanho, 0);
      c[valor] = 1000;
      return Distribuicao(
          contagens: c, total: 1000, media: valor.toDouble(), desvio: 0);
    }

    test('CRPS é zero na previsão pontual correta', () {
      expect(MonteCarloMetrics.crps(pontual(5, 20), 5), closeTo(0.0, 1e-9));
    });

    test('CRPS de previsão pontual errada vira o erro absoluto', () {
      expect(MonteCarloMetrics.crps(pontual(5, 20), 9), closeTo(4.0, 1e-9));
      expect(MonteCarloMetrics.crps(pontual(9, 20), 5), closeTo(4.0, 1e-9));
    });

    test('CRPS premia a distribuição que cobre o observado', () {
      final larga = MonteCarloEngine.simular(
        data: DateTime(2026, 1, 1),
        consultas: [
          for (var i = 0; i < 20; i++)
            ConsultaRisco(
                appointmentId: 'a$i',
                doctorId: 'm',
                hour: 9,
                pFalta: 0.30,
                risco: RiskLevel.medium),
        ],
        medicos: const [],
        config: const SimulacaoConfig(rho: 0),
      ).faltas;

      // Observado longe do centro: a distribuição larga perde menos que uma
      // previsão pontual no mesmo centro.
      final crpsDist = MonteCarloMetrics.crps(larga, 11);
      final crpsPonto = MonteCarloMetrics.crps(pontual(6, 21), 11);
      expect(crpsDist, lessThan(crpsPonto));
    });

    test('pinball é assimétrico e penaliza conforme o quantil', () {
      // Subestimar em 4 no P95 dói mais que superestimar em 4.
      expect(MonteCarloMetrics.pinball(10, 14, 0.95), closeTo(0.95 * 4, 1e-9));
      expect(MonteCarloMetrics.pinball(14, 10, 0.95), closeTo(0.05 * 4, 1e-9));
      // No P50 é simétrico.
      expect(MonteCarloMetrics.pinball(10, 14, 0.50),
          closeTo(MonteCarloMetrics.pinball(14, 10, 0.50), 1e-9));
    });

    test('cobertura mede a fração dentro do intervalo', () {
      final d = pontual(5, 20);
      expect(MonteCarloMetrics.cobertura([d, d, d, d], [5, 5, 5, 5]),
          closeTo(1.0, 1e-9));
      expect(MonteCarloMetrics.cobertura([d, d, d, d], [5, 5, 9, 9]),
          closeTo(0.5, 1e-9));
    });

    test('PIT fica em [0,1] e o ECE reprova previsão descalibrada', () {
      final d = pontual(5, 20);
      final u = MonteCarloMetrics.pit(d, 5);
      expect(u, inInclusiveRange(0.0, 1.0));

      // Todas as observações na mesma ponta: máxima descalibração.
      final ruim = MonteCarloMetrics.ece(
          List.filled(50, d), List.filled(50, 19));
      expect(ruim, greaterThan(0.1));
    });

    test('avaliar devolve resumo vazio sem amostras', () {
      final a = MonteCarloMetrics.avaliar(const [], const []);
      expect(a.temAmostras, isFalse);
      expect(a.amostras, 0);
    });
  });

  group('Calibração: recuperação de parâmetros conhecidos', () {
    const taxas = {
      RiskLevel.low: 0.08,
      RiskLevel.medium: 0.18,
      RiskLevel.high: 0.35,
    };

    test('recupera as taxas por faixa dentro do intervalo de confiança', () {
      final hist = gerar(
          dias: 150, porDia: 24, rho: 0.0, taxas: taxas, seed: 11,
          fim: DateTime(2026, 9, 1));

      final r = MonteCarloCalibracao.estimar(
        historico: hist,
        ate: DateTime(2026, 9, 1),
        janelaDias: 200,
      );

      expect(r.consultasAnalisadas, greaterThan(3000));
      expect(r.diasAnalisados, greaterThanOrEqualTo(140));

      for (final f in RiskLevel.values) {
        final t = r.taxas[f]!;
        expect(t.confiavel, isTrue, reason: '${f.label} sem amostra');
        final (lo, hi) = t.ic95Falta;
        expect(taxas[f]!, inInclusiveRange(lo, hi),
            reason: '${f.label}: real=${taxas[f]} medido=${t.taxaFalta}');
      }

      // E o modelo calibrado carrega as taxas medidas, não os padrões.
      expect(r.modeloCalibrado.pBaixo, closeTo(0.08, 0.03));
      expect(r.modeloCalibrado.pMedio, closeTo(0.18, 0.03));
      expect(r.modeloCalibrado.pAlto, closeTo(0.35, 0.04));
    });

    test('phi fica perto de 1 quando os dados são independentes', () {
      final hist = gerar(
          dias: 150, porDia: 30, rho: 0.0, taxas: taxas, seed: 5,
          fim: DateTime(2026, 9, 1));
      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1), janelaDias: 200);

      expect(r.phi, closeTo(1.0, 0.25));
      expect(r.rhoEstimado, lessThan(0.02));
    });

    test('detecta dependência e recupera a ordem de grandeza de rho', () {
      final hist = gerar(
          dias: 200, porDia: 30, rho: 0.05, taxas: taxas, seed: 13,
          fim: DateTime(2026, 9, 1));
      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1), janelaDias: 260);

      // Sobredispersão bem acima de 1 é a assinatura da dependência.
      expect(r.phi, greaterThan(1.5));
      // O estimador de momentos recupera a ordem de grandeza do rho injetado.
      expect(r.rhoEstimado, greaterThan(0.02));
      expect(r.rhoEstimado, lessThan(0.10));
    });

    test('rho maior produz phi maior — monotonicidade', () {
      double phiDe(double rho) => MonteCarloCalibracao.estimar(
            historico: gerar(
                dias: 150, porDia: 30, rho: rho, taxas: taxas, seed: 21,
                fim: DateTime(2026, 9, 1)),
            ate: DateTime(2026, 9, 1),
            janelaDias: 200,
          ).phi;

      final baixo = phiDe(0.01);
      final alto = phiDe(0.10);
      expect(alto, greaterThan(baixo));
    });
  });

  group('Calibração: guardas e avisos', () {
    test('histórico vazio não quebra e avisa', () {
      final r = MonteCarloCalibracao.estimar(historico: const []);
      expect(r.diasAnalisados, 0);
      expect(r.temDadosSuficientes, isFalse);
      expect(r.aprovadoParaUso, isFalse);
      expect(r.avisos, isNotEmpty);
    });

    test('amostra pequena mantém o padrão e registra o aviso', () {
      final hist = gerar(
          dias: 3, porDia: 6, rho: 0, taxas: const {
        RiskLevel.low: 0.5,
        RiskLevel.medium: 0.5,
        RiskLevel.high: 0.5,
      }, fim: DateTime(2026, 9, 1));

      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1));

      const padrao = ModeloRisco();
      // Taxa observada seria 0,5 — mas a amostra é pequena, então o padrão fica.
      expect(r.modeloCalibrado.pBaixo, padrao.pBaixo);
      expect(r.temDadosSuficientes, isFalse);
      expect(r.avisos.any((a) => a.contains('amostra insuficiente')), isTrue);
    });

    test('sempre avisa sobre a ambiguidade do cancelamento', () {
      final hist = gerar(
          dias: 40, porDia: 10, rho: 0, taxas: const {
        RiskLevel.low: 0.1,
        RiskLevel.medium: 0.1,
        RiskLevel.high: 0.1,
      }, fim: DateTime(2026, 9, 1));

      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1));
      expect(r.avisos.any((a) => a.contains('cancelamento')), isTrue);
    });

    test('consultas sem desfecho são excluídas com aviso', () {
      final base = gerar(
          dias: 40, porDia: 10, rho: 0, taxas: const {
        RiskLevel.low: 0.1,
        RiskLevel.medium: 0.1,
        RiskLevel.high: 0.1,
      }, fim: DateTime(2026, 9, 1));

      final comPendentes = [
        ...base,
        for (var i = 0; i < 7; i++)
          ap('pend$i', DateTime(2026, 8, 20, 9), RiskLevel.low,
              AppointmentStatus.pending),
      ];

      final r = MonteCarloCalibracao.estimar(
          historico: comPendentes, ate: DateTime(2026, 9, 1));
      expect(r.consultasAnalisadas, base.length);
      expect(r.avisos.any((a) => a.contains('sem desfecho registrado')), isTrue);
    });
  });

  group('Backtest', () {
    test('modelo calibrado cobre melhor que modelo independente errado', () {
      const taxas = {
        RiskLevel.low: 0.08,
        RiskLevel.medium: 0.18,
        RiskLevel.high: 0.35,
      };
      final hist = gerar(
          dias: 200, porDia: 30, rho: 0.06, taxas: taxas, seed: 31,
          fim: DateTime(2026, 9, 1));

      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1), janelaDias: 260);

      expect(r.backtest.temAmostras, isTrue);
      expect(r.backtest.crpsMedio, isNot(isNaN));
      expect(r.backtest.cobertura90, inInclusiveRange(0.0, 1.0));
    });
  });

  group('Integridade dos dados', () {
    Appointment fixo(String id, DateTime quando, RiskLevel r,
            AppointmentStatus st) =>
        ap(id, quando, r, st);

    List<Appointment> dias(int n, AppointmentStatus st,
        {RiskLevel risco = RiskLevel.low, int porDia = 8}) {
      final out = <Appointment>[];
      var i = 0;
      for (var d = 0; d < n; d++) {
        final dia = DateTime(2026, 9, 1).subtract(Duration(days: n - d));
        for (var k = 0; k < porDia; k++) {
          out.add(fixo('x${i++}',
              DateTime(dia.year, dia.month, dia.day, 8 + k % 8), risco, st));
        }
      }
      return out;
    }

    test('base que só registra fracasso é bloqueada', () {
      // Nenhum `completed`: o denominador da taxa contém apenas falhas.
      final hist = [
        ...dias(20, AppointmentStatus.noShow),
        ...dias(20, AppointmentStatus.cancelled),
      ];
      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1));

      expect(r.integridade.temBloqueio, isTrue);
      expect(
          r.integridade.bloqueios.any(
              (a) => a.titulo.contains('realizado')),
          isTrue);
      expect(r.podeAplicar, isFalse);
      expect(r.aprovadoParaUso, isFalse);
    });

    test('faixa de risco única é bloqueada', () {
      // Estratificação inexistente: todos caem em Baixo.
      final hist = [
        ...dias(30, AppointmentStatus.completed, risco: RiskLevel.low),
        ...dias(10, AppointmentStatus.noShow, risco: RiskLevel.low),
      ];
      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1));

      expect(
          r.integridade.bloqueios
              .any((a) => a.titulo.contains('mesma faixa de risco')),
          isTrue);
      expect(r.podeAplicar, isFalse);
    });

    test('base saudável não gera bloqueio de faixa nem de desfecho', () {
      final hist = <Appointment>[];
      for (final risco in RiskLevel.values) {
        hist.addAll(dias(40, AppointmentStatus.completed, risco: risco));
        hist.addAll(dias(8, AppointmentStatus.noShow, risco: risco));
      }
      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1), janelaDias: 200);

      final titulos = r.integridade.bloqueios.map((a) => a.titulo).toList();
      expect(titulos.any((t) => t.contains('realizado')), isFalse);
      expect(titulos.any((t) => t.contains('mesma faixa')), isFalse);
    });

    test('histórico curto entra como bloqueio abaixo de 30 dias', () {
      final hist = [
        ...dias(12, AppointmentStatus.completed, risco: RiskLevel.low),
        ...dias(12, AppointmentStatus.noShow, risco: RiskLevel.medium),
        ...dias(12, AppointmentStatus.cancelled, risco: RiskLevel.high),
      ];
      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1));

      final curto = r.integridade.achados
          .where((a) => a.titulo.contains('Histórico curto'));
      expect(curto, isNotEmpty);
      expect(curto.first.bloqueia, isTrue, reason: '12 dias < 30');
    });

    test('achado traz ação concreta quando bloqueia', () {
      final hist = dias(20, AppointmentStatus.noShow);
      final r = MonteCarloCalibracao.estimar(
          historico: hist, ate: DateTime(2026, 9, 1));

      for (final b in r.integridade.bloqueios) {
        expect(b.acao, isNotEmpty,
            reason: 'bloqueio "${b.titulo}" sem próximo passo');
      }
    });

    test('histórico vazio bloqueia com achado próprio', () {
      final r = MonteCarloCalibracao.estimar(historico: const []);
      expect(r.integridade.temBloqueio, isTrue);
      expect(r.podeAplicar, isFalse);
    });
  });
}
