import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_engine.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';

/// Testes de propriedade do motor de Monte Carlo.
///
/// O teste central não é "rodou sem erro": é comparar o amostrador com a
/// **Poisson-binomial exata**, que tem forma fechada no caso independente. Um
/// oráculo exato reprova erros que testes de fumaça (p = 0, p = 1) não pegam.
void main() {
  final data = DateTime(2026, 9, 15, 0, 0);

  Doctor medico(String id, {int slotLimit = 3, int overbook = 0}) => Doctor(
        id: id,
        name: 'Dr. $id',
        crm: 'CRM$id',
        specialties: const ['Clínica'],
        slotLimit: slotLimit,
        maxOverbook: overbook,
      );

  List<ConsultaRisco> consultas(List<double> ps, {String doctorId = 'm1', int hour = 9}) => [
        for (var i = 0; i < ps.length; i++)
          ConsultaRisco(
            appointmentId: 'a$i',
            doctorId: doctorId,
            hour: hour,
            pFalta: ps[i],
            risco: RiskLevel.medium,
          ),
      ];

  group('Poisson-binomial exata (oráculo)', () {
    test('reduz ao binomial quando todos os p são iguais', () {
      const n = 20;
      const p = 0.3;
      final pmf = MonteCarloEngine.poissonBinomialPmf(List.filled(n, p));

      double binom(int k) {
        var c = 1.0;
        for (var i = 0; i < k; i++) {
          c = c * (n - i) / (i + 1);
        }
        return c * math.pow(p, k) * math.pow(1 - p, n - k);
      }

      expect(pmf.length, n + 1);
      for (var k = 0; k <= n; k++) {
        expect(pmf[k], closeTo(binom(k), 1e-12));
      }
    });

    test('soma 1 e reproduz média e variância em forma fechada', () {
      final ps = [for (var i = 0; i < 60; i++) 0.02 + (i % 17) * 0.03];
      final pmf = MonteCarloEngine.poissonBinomialPmf(ps);

      final soma = pmf.fold(0.0, (a, b) => a + b);
      expect(soma, closeTo(1.0, 1e-12));

      var media = 0.0;
      var seg = 0.0;
      for (var k = 0; k < pmf.length; k++) {
        media += k * pmf[k];
        seg += k * k * pmf[k];
      }
      final varPmf = seg - media * media;

      final esperadaMedia = ps.fold(0.0, (a, p) => a + p);
      final esperadaVar = ps.fold(0.0, (a, p) => a + p * (1 - p));

      expect(media, closeTo(esperadaMedia, 1e-10));
      expect(varPmf, closeTo(esperadaVar, 1e-10));
    });
  });

  group('Amostrador validado contra o oráculo exato', () {
    test('com rho = 0 o motor usa a forma fechada e marca exato', () {
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: consultas([for (var i = 0; i < 40; i++) 0.05 + (i % 9) * 0.03]),
        medicos: [medico('m1', slotLimit: 40)],
        config: const SimulacaoConfig(rho: 0),
      );

      expect(r.exato, isTrue);
      expect(r.phiObservado, closeTo(1.0, 1e-9));
      expect(r.faltas.media, closeTo(r.faltasEsperadas, 1e-9));
    });

    test('amostrador com rho→0 converge para a distribuição exata', () {
      final ps = [for (var i = 0; i < 50; i++) 0.04 + (i % 11) * 0.04];

      final exato = MonteCarloEngine.simular(
        data: data,
        consultas: consultas(ps),
        medicos: [medico('m1', slotLimit: 50)],
        config: const SimulacaoConfig(rho: 0),
      );

      // rho minúsculo força o caminho de amostragem, mantendo a independência
      // praticamente intacta — é assim que se testa o amostrador de verdade.
      final amostrado = MonteCarloEngine.simular(
        data: data,
        consultas: consultas(ps),
        medicos: [medico('m1', slotLimit: 50)],
        config: const SimulacaoConfig(rho: 1e-9, nRuns: 30000, seed: 7),
      );

      expect(amostrado.exato, isFalse);
      expect(amostrado.faltas.media, closeTo(exato.faltas.media, 0.08));
      expect(amostrado.faltas.desvio, closeTo(exato.faltas.desvio, 0.08));
      expect(amostrado.faltas.p50, closeTo(exato.faltas.p50, 1));
      expect(amostrado.faltas.p95, closeTo(exato.faltas.p95, 1));
    });
  });

  group('Dependência entre faltas', () {
    final ps = [for (var i = 0; i < 220; i++) 0.05 + (i % 13) * 0.02];

    test('a cópula preserva as marginais: a média não muda com rho', () {
      final esperada = ps.fold(0.0, (a, p) => a + p);
      for (final rho in [1e-9, 0.03, 0.10, 0.20]) {
        final r = MonteCarloEngine.simular(
          data: data,
          consultas: consultas(ps),
          medicos: [medico('m1', slotLimit: 220)],
          config: SimulacaoConfig(rho: rho, nRuns: 20000, seed: 11),
        );
        // Esta é a propriedade que reprovou o deslocamento de log-odds:
        // a dependência pode mudar a dispersão, nunca a média.
        expect(r.faltas.media, closeTo(esperada, 0.25),
            reason: 'média deslocou em rho=$rho');
      }
    });

    test('rho positivo alarga a cauda e eleva o P95', () {
      final semDep = MonteCarloEngine.simular(
        data: data,
        consultas: consultas(ps),
        medicos: [medico('m1', slotLimit: 220)],
        config: const SimulacaoConfig(rho: 0),
      );
      final comDep = MonteCarloEngine.simular(
        data: data,
        consultas: consultas(ps),
        medicos: [medico('m1', slotLimit: 220)],
        config: const SimulacaoConfig(rho: 0.03, nRuns: 20000, seed: 3),
      );

      expect(comDep.faltas.desvio, greaterThan(semDep.faltas.desvio));
      expect(comDep.faltas.p95, greaterThan(semDep.faltas.p95));
      expect(comDep.phiObservado, greaterThan(1.5));
    });
  });

  group('Intervenção por razão de chances', () {
    test('nunca produz probabilidade fora de (0,1)', () {
      for (final p in [0.001, 0.01, 0.05, 0.2, 0.5, 0.9, 0.999]) {
        for (final or in [0.1, 0.5, 0.9, 1.0, 2.0, 10.0]) {
          final novo = MonteCarloEngine.aplicarIntervencao(p, or);
          expect(novo, greaterThan(0.0), reason: 'p=$p or=$or');
          expect(novo, lessThan(1.0), reason: 'p=$p or=$or');
        }
      }
    });

    test('o delta aditivo da v1.0 quebraria nas mesmas entradas', () {
      // Documenta por que a razão de chances substituiu o delta: em toda
      // consulta de baixo risco o delta aditivo cai abaixo de zero.
      const delta = -0.08;
      final baixos = [0.01, 0.03, 0.06];
      for (final p in baixos) {
        expect(p + delta, lessThan(0.0));
        expect(MonteCarloEngine.aplicarIntervencao(p, 0.6), greaterThan(0.0));
      }
    });

    test('razão de chances < 1 reduz a probabilidade monotonicamente', () {
      const p = 0.3;
      final a = MonteCarloEngine.aplicarIntervencao(p, 0.4);
      final b = MonteCarloEngine.aplicarIntervencao(p, 0.7);
      expect(a, lessThan(b));
      expect(b, lessThan(p));
      expect(MonteCarloEngine.aplicarIntervencao(p, 1.0), closeTo(p, 1e-12));
    });
  });

  group('Determinismo e reprodutibilidade', () {
    test('mesma semente produz resultado idêntico', () {
      final ps = [for (var i = 0; i < 80; i++) 0.05 + (i % 7) * 0.03];
      List<int> rodar(int seed) => MonteCarloEngine.simular(
            data: data,
            consultas: consultas(ps),
            medicos: [medico('m1', slotLimit: 80)],
            config: SimulacaoConfig(rho: 0.03, nRuns: 5000, seed: seed),
          ).faltas.contagens;

      expect(rodar(99), equals(rodar(99)));
      expect(rodar(99), isNot(equals(rodar(100))));
    });
  });

  group('Overbooking por slot', () {
    test('slots separados não compartilham capacidade', () {
      // Duas horas, mesma capacidade. A 9h está lotada, a 15h vazia.
      // O modelo agregado do dia diria "há folga"; o por slot não.
      final cs = <ConsultaRisco>[
        ...consultas([0.05, 0.05, 0.05, 0.05, 0.05], hour: 9),
        ...consultas([0.05], hour: 15).map((c) => ConsultaRisco(
              appointmentId: '${c.appointmentId}_t',
              doctorId: c.doctorId,
              hour: 15,
              pFalta: c.pFalta,
              risco: c.risco,
            )),
      ];

      final r = MonteCarloEngine.simular(
        data: data,
        consultas: cs,
        medicos: [medico('m1', slotLimit: 3)],
        config: const SimulacaoConfig(rho: 0),
      );

      expect(r.slots.length, 2);
      final nove = r.slots.firstWhere((s) => s.hour == 9);
      final quinze = r.slots.firstWhere((s) => s.hour == 15);

      expect(nove.agendados, 5);
      expect(nove.capacidade, 3);
      expect(quinze.agendados, 1);

      // 5 agendados com p=0,05 sobre capacidade 3: estouro quase certo.
      expect(nove.riscoEstouro(0), greaterThan(0.9));
      // O slot vazio não tem risco nenhum.
      expect(quinze.riscoEstouro(0), lessThan(0.01));

      // E o cenário do dia é reprovado pelo pior slot, não pela média.
      final c0 = MonteCarloEngine.avaliarCenario(r, 0);
      expect(c0.aprovado, isFalse);
      expect(MonteCarloEngine.encaixesRecomendados(r), 0);
    });

    test('agenda folgada aceita encaixes; o limite é respeitado', () {
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: consultas([0.2, 0.2], hour: 10),
        medicos: [medico('m1', slotLimit: 6)],
        config: const SimulacaoConfig(rho: 0),
      );

      final k = MonteCarloEngine.encaixesRecomendados(r, limiteRisco: 0.05);
      expect(k, greaterThan(0));

      final aprovado = MonteCarloEngine.avaliarCenario(r, k);
      expect(aprovado.aprovado, isTrue);
      expect(aprovado.riscoMaximoSlot, lessThanOrEqualTo(0.05));

      final excedido = MonteCarloEngine.avaliarCenario(r, k + 3);
      expect(excedido.riscoMaximoSlot,
          greaterThanOrEqualTo(aprovado.riscoMaximoSlot));
    });

    test('ignorar a dependência subestima o risco de estouro', () {
      // Mesma agenda, apenas rho muda. É o núcleo da correção.
      final ps = [for (var i = 0; i < 40; i++) 0.12];
      final indep = MonteCarloEngine.simular(
        data: data,
        consultas: consultas(ps, hour: 8),
        medicos: [medico('m1', slotLimit: 36)],
        config: const SimulacaoConfig(rho: 0),
      );
      final dep = MonteCarloEngine.simular(
        data: data,
        consultas: consultas(ps, hour: 8),
        medicos: [medico('m1', slotLimit: 36)],
        config: const SimulacaoConfig(rho: 0.05, nRuns: 20000, seed: 5),
      );

      final kIndep = MonteCarloEngine.encaixesRecomendados(indep);
      final kDep = MonteCarloEngine.encaixesRecomendados(dep);

      // O modelo independente autoriza pelo menos tantos encaixes quanto o
      // dependente — nunca menos. É por isso que ele "parece mais seguro".
      expect(kIndep, greaterThanOrEqualTo(kDep));
    });
  });

  group('Montagem a partir da agenda real', () {
    test('só entram consultas pendentes e confirmadas do dia', () {
      Appointment ap(String id, AppointmentStatus st, DateTime quando) =>
          Appointment(
            id: id,
            clinicId: 'c1',
            patientId: 'p$id',
            patientName: 'Paciente $id',
            doctorId: 'm1',
            doctorName: 'Dr. m1',
            specialty: 'Clínica',
            start: quando,
            durationMinutes: 30,
            status: st,
            patientRisk: RiskLevel.medium,
          );

      final lista = [
        ap('1', AppointmentStatus.confirmed, DateTime(2026, 9, 15, 9)),
        ap('2', AppointmentStatus.pending, DateTime(2026, 9, 15, 10)),
        ap('3', AppointmentStatus.cancelled, DateTime(2026, 9, 15, 11)),
        ap('4', AppointmentStatus.completed, DateTime(2026, 9, 15, 12)),
        ap('5', AppointmentStatus.noShow, DateTime(2026, 9, 15, 13)),
        ap('6', AppointmentStatus.confirmed, DateTime(2026, 9, 16, 9)),
      ];

      final cs = MonteCarloEngine.montarConsultas(
        data: DateTime(2026, 9, 15),
        agendamentos: lista,
      );

      expect(cs.map((c) => c.appointmentId).toList(), ['1', '2']);
      expect(cs.every((c) => c.pFalta > 0 && c.pFalta < 1), isTrue);
    });

    test('a intervenção é aplicada na montagem sem sair de (0,1)', () {
      final lista = [
        for (final r in RiskLevel.values)
          Appointment(
            id: r.name,
            clinicId: 'c1',
            patientId: 'p',
            patientName: 'P',
            doctorId: 'm1',
            doctorName: 'Dr',
            specialty: 'Clínica',
            start: DateTime(2026, 9, 15, 9),
            durationMinutes: 30,
            status: AppointmentStatus.confirmed,
            patientRisk: r,
          ),
      ];

      final cs = MonteCarloEngine.montarConsultas(
        data: DateTime(2026, 9, 15),
        agendamentos: lista,
        oddsRatioIntervencao: 0.55,
      );

      expect(cs.length, 3);
      for (final c in cs) {
        expect(c.pFalta, greaterThan(0.0));
        expect(c.pFalta, lessThan(1.0));
      }
    });
  });

  group('Casos de borda', () {
    test('agenda vazia não quebra', () {
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: const [],
        medicos: [medico('m1')],
        config: const SimulacaoConfig(rho: 0.03, nRuns: 100),
      );
      expect(r.totalAgendados, 0);
      expect(r.slots, isEmpty);
      expect(MonteCarloEngine.avaliarCenario(r, 0).aprovado, isTrue);
    });

    test('p = 0 e p = 1 se comportam como certeza', () {
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: consultas([0.0, 0.0, 1.0]),
        medicos: [medico('m1', slotLimit: 3)],
        config: const SimulacaoConfig(rho: 0),
      );
      expect(r.faltas.p50, 1);
      expect(r.faltas.media, closeTo(1.0, 1e-9));
    });

    test('normalInv é consistente com valores conhecidos', () {
      expect(MonteCarloEngine.normalInv(0.5), closeTo(0.0, 1e-9));
      expect(MonteCarloEngine.normalInv(0.975), closeTo(1.959963985, 1e-6));
      expect(MonteCarloEngine.normalInv(0.025), closeTo(-1.959963985, 1e-6));
      expect(MonteCarloEngine.normalInv(0.05), closeTo(-1.644853627, 1e-6));
    });
  });
}
