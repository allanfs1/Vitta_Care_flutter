import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_calibracao.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_engine.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_persistencia.dart';

/// Testes do mapeamento para Firestore. As funções de documento são puras e
/// não dependem de `Timestamp`, então rodam sem inicializar o Firebase.
void main() {
  final data = DateTime(2026, 9, 15);

  SimulacaoResultado simular({double rho = 0}) => MonteCarloEngine.simular(
        data: data,
        consultas: [
          for (var i = 0; i < 12; i++)
            ConsultaRisco(
              appointmentId: 'a$i',
              doctorId: 'm1',
              hour: 9 + (i % 3),
              pFalta: 0.12,
              pCancel: 0.06,
              risco: RiskLevel.values[i % 3],
            ),
        ],
        medicos: [
          Doctor(
            id: 'm1',
            name: 'Dr. Teste',
            crm: 'CRM1',
            specialties: const ['Clínica'],
            slotLimit: 3,
            maxOverbook: 1,
          ),
        ],
        config: SimulacaoConfig(rho: rho, nRuns: 2000, seed: 9),
      );

  group('Documento de execução', () {
    test('carrega os parâmetros junto do resultado', () {
      final doc = execucaoDoc('cl_1', simular());

      // Um P95 sem o rho, a semente e a labelVersion que o produziram é um
      // número órfão — impossível de reproduzir ou comparar.
      expect(doc['idclinica'], 'cl_1');
      expect(doc['labelVersion'], kLabelVersion);
      final par = doc['parametros'] as Map<String, dynamic>;
      expect(par['rho'], 0);
      expect(par['seed'], 9);
      expect(par['baseCapacidade'], BaseCapacidade.fisica.name);
      expect(par['encaixeModo'], EncaixeModo.certo.name);
      expect((par['taxas'] as Map)['baixo'], isA<double>());
    });

    test('grava os três estados e a fila', () {
      final doc = execucaoDoc('cl_1', simular());
      expect((doc['faltas'] as Map)['p95'], isA<int>());
      expect((doc['cancelamentos'] as Map)['esperados'], isA<double>());
      expect((doc['fila'] as Map)['chamadasSeguras'], isA<int>());
    });

    test('cada slot leva as duas capacidades, não só a usada', () {
      final doc = execucaoDoc('cl_1', simular());
      final slots = doc['slots'] as List;
      expect(slots, isNotEmpty);
      final s = slots.first as Map<String, dynamic>;
      expect(s['capacidade'], isA<int>());
      expect(s['capacidadeFisica'], 3);
      expect(s['capacidadeConfigurada'], 4);
      expect(s['riscoEstouro'], isA<double>());
    });

    test('não contém Timestamp — datas ficam como DateTime', () {
      final doc = execucaoDoc('cl_1', simular());
      expect(doc['data'], isA<DateTime>());
    });

    test('marca o caminho exato quando rho = 0', () {
      expect(execucaoDoc('cl_1', simular(rho: 0))['exato'], isTrue);
      expect(execucaoDoc('cl_1', simular(rho: 0.05))['exato'], isFalse);
    });
  });

  group('Documento de decisão', () {
    test('liga a decisão à execução que a justificou', () {
      final doc = decisaoDoc(
        'cl_1',
        execucaoId: 'exec_123',
        encaixesAprovados: 3,
        ator: 'recepcao@clinica',
        justificativa: 'Dentro do limite de risco e equidade.',
      );
      expect(doc['execucaoId'], 'exec_123');
      expect(doc['encaixesAprovados'], 3);
      expect(doc['decisao'], 'overbooking_mc');
      expect(doc['idclinica'], 'cl_1');
    });
  });

  group('Documento de calibração', () {
    test('preserva taxas, backtest e avisos', () {
      final c = MonteCarloCalibracao.estimar(historico: const []);
      final doc = calibracaoDoc('cl_1', c);

      expect(doc['idclinica'], 'cl_1');
      expect(doc['diasAnalisados'], 0);
      expect(doc['aprovadoParaUso'], isFalse);
      expect(doc['avisos'], isA<List>());
      expect((doc['avisos'] as List), isNotEmpty);
      expect(doc['backtest'], isA<Map>());
    });
  });

  group('Repositório mock', () {
    test('não persiste nada e não quebra', () async {
      const repo = MockMonteCarloRepositorio();
      expect(await repo.salvarExecucao('cl_1', simular()), isNull);
      expect(
          await repo.salvarCalibracao(
              'cl_1', MonteCarloCalibracao.estimar(historico: const [])),
          isNull);
      await repo.registrarDecisao('cl_1',
          execucaoId: 'x', encaixesAprovados: 0, ator: 'a', justificativa: 'b');
    });
  });
}
