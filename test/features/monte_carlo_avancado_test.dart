import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_engine.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';

/// Testes das capacidades acrescentadas depois do motor base: três estados,
/// base de capacidade, modo de encaixe, equidade e lista de espera.
void main() {
  final data = DateTime(2026, 9, 15);

  Doctor medico(String id, {int slotLimit = 3, int overbook = 0}) => Doctor(
        id: id,
        name: 'Dr. $id',
        crm: 'CRM$id',
        specialties: const ['Clínica'],
        slotLimit: slotLimit,
        maxOverbook: overbook,
      );

  ConsultaRisco c({
    required String id,
    double pFalta = 0.10,
    double pCancel = 0.0,
    int hour = 9,
    String doctorId = 'm1',
    RiskLevel risco = RiskLevel.medium,
  }) =>
      ConsultaRisco(
        appointmentId: id,
        doctorId: doctorId,
        hour: hour,
        pFalta: pFalta,
        pCancel: pCancel,
        risco: risco,
      );

  group('Modelo de três estados', () {
    test('cancelamento é contado separado da falta e preserva as marginais',
        () {
      final consultas = [
        for (var i = 0; i < 60; i++)
          c(id: 'a$i', pFalta: 0.12, pCancel: 0.08),
      ];

      final exato = MonteCarloEngine.simular(
        data: data,
        consultas: consultas,
        medicos: [medico('m1', slotLimit: 60)],
        config: const SimulacaoConfig(rho: 0),
      );

      expect(exato.faltas.media, closeTo(60 * 0.12, 1e-6));
      expect(exato.cancelamentos.media, closeTo(60 * 0.08, 1e-6));

      // Com dependência as marginais têm de continuar iguais — só a dispersão
      // muda. É a mesma propriedade que reprovou o deslocamento de log-odds,
      // agora com dois estados simultâneos.
      final amostrado = MonteCarloEngine.simular(
        data: data,
        consultas: consultas,
        medicos: [medico('m1', slotLimit: 60)],
        config: const SimulacaoConfig(rho: 0.05, nRuns: 20000, seed: 3),
      );

      expect(amostrado.faltas.media, closeTo(60 * 0.12, 0.25));
      expect(amostrado.cancelamentos.media, closeTo(60 * 0.08, 0.25));
    });

    test('presentes = agendados - faltas - cancelamentos', () {
      final consultas = [
        for (var i = 0; i < 20; i++)
          c(id: 'a$i', pFalta: 0.10, pCancel: 0.10),
      ];
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: consultas,
        medicos: [medico('m1', slotLimit: 20)],
        config: const SimulacaoConfig(rho: 0),
      );

      final slot = r.slots.single;
      // E[presentes] = n * (1 - pFalta - pCancel)
      expect(slot.presentes.media, closeTo(20 * 0.80, 1e-6));
      expect(slot.liberadasComAviso.media, closeTo(20 * 0.10, 1e-6));
    });

    test('só o cancelamento alimenta a fila; a falta não libera nada', () {
      // Duas agendas com o mesmo total de ausências, repartido diferente.
      final soFalta = [
        for (var i = 0; i < 30; i++) c(id: 'a$i', pFalta: 0.30, pCancel: 0.0),
      ];
      final soCancel = [
        for (var i = 0; i < 30; i++) c(id: 'b$i', pFalta: 0.0, pCancel: 0.30),
      ];

      final rf = MonteCarloEngine.simular(
        data: data, consultas: soFalta,
        medicos: [medico('m1', slotLimit: 30)],
        config: const SimulacaoConfig(rho: 0),
      );
      final rc = MonteCarloEngine.simular(
        data: data, consultas: soCancel,
        medicos: [medico('m1', slotLimit: 30)],
        config: const SimulacaoConfig(rho: 0),
      );

      expect(rf.fila.chamadasSeguras, 0);
      expect(rc.fila.chamadasSeguras, greaterThan(0));
      // A ociosidade é a mesma; o que muda é poder planejar o preenchimento.
      expect(rf.slots.single.presentes.media,
          closeTo(rc.slots.single.presentes.media, 1e-6));
    });
  });

  group('Base de capacidade', () {
    test('física e configurada dão números diferentes quando há overbook', () {
      final consultas = [
        for (var i = 0; i < 4; i++) c(id: 'a$i', pFalta: 0.10),
      ];
      final med = [medico('m1', slotLimit: 3, overbook: 2)];

      final fisica = MonteCarloEngine.simular(
        data: data, consultas: consultas, medicos: med,
        config: const SimulacaoConfig(
            rho: 0, baseCapacidade: BaseCapacidade.fisica),
      );
      final configurada = MonteCarloEngine.simular(
        data: data, consultas: consultas, medicos: med,
        config: const SimulacaoConfig(
            rho: 0, baseCapacidade: BaseCapacidade.configurada),
      );

      expect(fisica.slots.single.capacidade, 3);
      expect(configurada.slots.single.capacidade, 5);
      // Os dois números continuam disponíveis nos dois modos.
      expect(fisica.slots.single.capacidadeConfigurada, 5);
      expect(configurada.slots.single.capacidadeFisica, 3);

      // Medir contra a capacidade já inflada esconde risco.
      expect(fisica.slots.single.riscoEstouro(0),
          greaterThan(configurada.slots.single.riscoEstouro(0)));
    });
  });

  group('Modo de encaixe', () {
    test('probabilístico dá risco menor que o conservador — são limites', () {
      final consultas = [
        for (var i = 0; i < 5; i++) c(id: 'a$i', pFalta: 0.10),
      ];
      final med = [medico('m1', slotLimit: 5)];

      final certo = MonteCarloEngine.simular(
        data: data, consultas: consultas, medicos: med,
        config: const SimulacaoConfig(rho: 0, encaixeModo: EncaixeModo.certo),
      );
      final prob = MonteCarloEngine.simular(
        data: data, consultas: consultas, medicos: med,
        config: const SimulacaoConfig(
            rho: 0,
            encaixeModo: EncaixeModo.probabilistico,
            pFaltaEncaixe: 0.20),
      );

      for (var k = 1; k <= 4; k++) {
        expect(prob.slots.single.riscoEstouro(k),
            lessThanOrEqualTo(certo.slots.single.riscoEstouro(k)),
            reason: 'k=$k');
      }
      // Sem encaixe os dois modos coincidem.
      expect(prob.slots.single.riscoEstouro(0),
          closeTo(certo.slots.single.riscoEstouro(0), 1e-9));
    });

    test('risco é monotônico no número de encaixes', () {
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: [for (var i = 0; i < 4; i++) c(id: 'a$i', pFalta: 0.15)],
        medicos: [medico('m1', slotLimit: 6)],
        config: const SimulacaoConfig(rho: 0),
      );
      final s = r.slots.single;
      for (var k = 1; k <= MonteCarloEngine.kMaxEncaixes; k++) {
        expect(s.riscoEstouro(k), greaterThanOrEqualTo(s.riscoEstouro(k - 1)),
            reason: 'k=$k');
      }
    });
  });

  group('Equidade', () {
    test('carga proporcional passa; concentração em uma faixa é bloqueada', () {
      // Slot A: só baixo risco, muita folga. Slot B: só alto risco, folga igual.
      final consultas = <ConsultaRisco>[
        for (var i = 0; i < 2; i++)
          c(id: 'lo$i', hour: 9, risco: RiskLevel.low, pFalta: 0.06),
        for (var i = 0; i < 2; i++)
          c(id: 'hi$i', hour: 14, risco: RiskLevel.high, pFalta: 0.06),
      ];

      final r = MonteCarloEngine.simular(
        data: data,
        consultas: consultas,
        medicos: [medico('m1', slotLimit: 8)],
        config: const SimulacaoConfig(rho: 0),
      );

      // Alocação artificial: todos os encaixes no slot de alto risco.
      final soAlto = MonteCarloEngine.avaliarEquidade(r, [0, 4]);
      expect(soAlto.razaoMaxima, greaterThan(1.5));
      expect(soAlto.dentroDoLimite, isFalse);

      // Alocação equilibrada entre os dois slots.
      final equilibrado = MonteCarloEngine.avaliarEquidade(r, [2, 2]);
      expect(equilibrado.razaoMaxima, closeTo(1.0, 0.01));
      expect(equilibrado.dentroDoLimite, isTrue);
    });

    test('sem encaixes a equidade é neutra', () {
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: [c(id: 'a', risco: RiskLevel.high)],
        medicos: [medico('m1')],
        config: const SimulacaoConfig(rho: 0),
      );
      final e = MonteCarloEngine.avaliarEquidade(r, [0]);
      expect(e.razaoMaxima, 1.0);
      expect(e.dentroDoLimite, isTrue);
    });

    test('a trava de equidade pode reduzir os encaixes recomendados', () {
      final consultas = <ConsultaRisco>[
        for (var i = 0; i < 3; i++)
          c(id: 'lo$i', hour: 9, risco: RiskLevel.low, pFalta: 0.05),
        for (var i = 0; i < 3; i++)
          c(id: 'hi$i', hour: 14, risco: RiskLevel.high, pFalta: 0.40),
      ];
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: consultas,
        medicos: [medico('m1', slotLimit: 10)],
        config: const SimulacaoConfig(rho: 0),
      );

      final semTrava = MonteCarloEngine.encaixesRecomendados(
          r, limiteEquidade: 999);
      final comTrava = MonteCarloEngine.encaixesRecomendados(
          r, limiteEquidade: 1.10);

      expect(comTrava, lessThanOrEqualTo(semTrava));
    });
  });

  group('Lista de espera', () {
    test('dimensiona pelo quartil inferior, não pela média', () {
      final consultas = [
        for (var i = 0; i < 40; i++) c(id: 'a$i', pFalta: 0.05, pCancel: 0.25),
      ];
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: consultas,
        medicos: [medico('m1', slotLimit: 40)],
        config: const SimulacaoConfig(rho: 0),
      );

      final liberadas = r.slots.single.liberadasComAviso;
      expect(r.fila.chamadasSeguras, liberadas.p25);
      // O quartil inferior é conservador em relação à média.
      expect(r.fila.chamadasSeguras, lessThan(liberadas.media.ceil()));
      expect(r.fila.liberadasP50, greaterThanOrEqualTo(r.fila.liberadasP25));
    });

    test('agenda sem cancelamento não gera chamadas', () {
      final r = MonteCarloEngine.simular(
        data: data,
        consultas: [for (var i = 0; i < 10; i++) c(id: 'a$i', pCancel: 0)],
        medicos: [medico('m1', slotLimit: 10)],
        config: const SimulacaoConfig(rho: 0),
      );
      expect(r.fila.chamadasSeguras, 0);
      expect(r.fila.detalhePorSlot, isEmpty);
    });
  });
}
