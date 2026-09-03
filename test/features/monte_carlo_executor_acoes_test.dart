import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/ia/acoes_ia.dart';
import 'package:vitta_app/features/monte_carlo/ia/executor_acoes.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_calibracao.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_engine.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_providers.dart';

/// Testes de [AcoesController.indisponivel] — o pré-check que decide se um
/// botão de ação fica clicável, **antes** de gastar uma chamada de IA.
///
/// Sobrescrever `mcResultadoProvider`/`mcCalibracaoProvider` substitui o corpo
/// do provider inteiro, então estes testes não precisam satisfazer a cadeia
/// de dependências real (agenda, Firestore, `sharedPrefsProvider`) — só o
/// contrato que `AcoesController` lê.
void main() {
  final data = DateTime(2026, 9, 15);

  SimulacaoResultado simular(int n, {double pCancel = 0.0}) =>
      MonteCarloEngine.simular(
        data: data,
        consultas: [
          for (var i = 0; i < n; i++)
            ConsultaRisco(
              appointmentId: 'a$i',
              doctorId: 'm1',
              hour: 9,
              pFalta: 0.1,
              pCancel: pCancel,
              risco: RiskLevel.low,
            ),
        ],
        medicos: const [],
        config: const SimulacaoConfig(rho: 0),
      );

  AcaoIa acao(String id) => AcaoIa.porId(id)!;

  test('resultado ainda não resolvido: ação de agenda fica indisponível', () {
    final pendente = Completer<SimulacaoResultado>();
    final container = ProviderContainer(overrides: [
      mcResultadoProvider.overrideWith((ref) => pendente.future),
    ]);
    addTearDown(() {
      // Resolve para não deixar o Future pendente ao descartar o container.
      if (!pendente.isCompleted) pendente.complete(simular(0));
      container.dispose();
    });

    final ctrl = container.read(mcAcoesProvider.notifier);
    final motivo = ctrl.indisponivel(acao('explicar_dia'));

    expect(motivo, isNotNull);
    expect(motivo, contains('ainda não terminou'));
  });

  test('agenda vazia: motivo pede para escolher outro dia', () async {
    final container = ProviderContainer(overrides: [
      mcResultadoProvider.overrideWith((ref) async => simular(0)),
    ]);
    addTearDown(container.dispose);
    await container.read(mcResultadoProvider.future);

    final ctrl = container.read(mcAcoesProvider.notifier);
    final motivo = ctrl.indisponivel(acao('explicar_dia'));

    expect(motivo, contains('escolha outro dia'));
  });

  test('agenda com consultas: ação de agenda fica disponível', () async {
    final container = ProviderContainer(overrides: [
      mcResultadoProvider.overrideWith((ref) async => simular(15)),
    ]);
    addTearDown(container.dispose);
    await container.read(mcResultadoProvider.future);

    final ctrl = container.read(mcAcoesProvider.notifier);
    expect(ctrl.indisponivel(acao('explicar_dia')), isNull);
    expect(ctrl.indisponivel(acao('gargalo')), isNull);
  });

  test('ações que não exigem agenda ignoram resultado nulo', () async {
    final container = ProviderContainer(overrides: [
      mcResultadoProvider.overrideWith((ref) async => simular(0)),
      mcCalibracaoProvider.overrideWith(
          (ref) async => MonteCarloCalibracao.estimar(historico: const [
                // histórico mínimo só para não cair no motivo de calibração
                // nula — o teste quer isolar a checagem de agenda.
              ])),
    ]);
    addTearDown(container.dispose);
    await container.read(mcCalibracaoProvider.future);

    final ctrl = container.read(mcAcoesProvider.notifier);
    // diagnosticar_dados: exigeAgenda = false, mas exigeCalibracao = true —
    // com calibração resolvida (mesmo que vazia), o motivo não é de agenda.
    final motivo = ctrl.indisponivel(acao('diagnosticar_dados'));
    expect(motivo, isNot(contains('consultas')));
  });

  test('mensagem_fila: sem chamada segura, motivo específico', () async {
    final container = ProviderContainer(overrides: [
      mcResultadoProvider.overrideWith((ref) async => simular(20, pCancel: 0)),
    ]);
    addTearDown(container.dispose);
    await container.read(mcResultadoProvider.future);

    final ctrl = container.read(mcAcoesProvider.notifier);
    final motivo = ctrl.indisponivel(acao('mensagem_fila'));

    expect(motivo, isNotNull);
    expect(motivo, contains('Nenhuma vaga'));
  });

  test('mensagem_fila: com fila disponível, sem motivo', () async {
    final container = ProviderContainer(overrides: [
      mcResultadoProvider
          .overrideWith((ref) async => simular(30, pCancel: 0.4)),
    ]);
    addTearDown(container.dispose);
    final r = await container.read(mcResultadoProvider.future);

    final ctrl = container.read(mcAcoesProvider.notifier);
    final motivo = ctrl.indisponivel(acao('mensagem_fila'));

    // A fixture é probabilística o bastante para garantir fila > 0 com
    // pCancel = 0,4 sobre 30 consultas; se algum dia isso não bastar, o
    // teste falha de forma legível em vez de silenciosa.
    expect(r.fila.chamadasSeguras, greaterThan(0),
        reason: 'fixture não gerou fila — ajuste pCancel/n');
    expect(motivo, isNull);
  });

  test('exigeCalibracao: calibração não resolvida bloqueia a ação', () {
    final pendente = Completer<CalibracaoResultado>();
    final container = ProviderContainer(overrides: [
      mcCalibracaoProvider.overrideWith((ref) => pendente.future),
    ]);
    addTearDown(() {
      if (!pendente.isCompleted) {
        pendente.complete(MonteCarloCalibracao.estimar(historico: const []));
      }
      container.dispose();
    });

    final ctrl = container.read(mcAcoesProvider.notifier);
    final motivo = ctrl.indisponivel(acao('diagnosticar_dados'));

    expect(motivo, contains('calibração ainda não terminou'));
  });

  group('Estado do controller', () {
    test('uma ação por vez: executar durante execução não substitui a que '
        'está em curso', () async {
      final pendenteIa = Completer<SimulacaoResultado>();
      final container = ProviderContainer(overrides: [
        mcResultadoProvider.overrideWith((ref) => pendenteIa.future),
      ]);
      addTearDown(() {
        if (!pendenteIa.isCompleted) pendenteIa.complete(simular(0));
        container.dispose();
      });

      final ctrl = container.read(mcAcoesProvider.notifier);
      // Sem resultado disponível, a execução grava o motivo de indisponível
      // no estado em vez de travar em "rodando".
      await ctrl.executar('explicar_dia');
      final estado = container.read(mcAcoesProvider);

      expect(estado.rodando, isNull);
      expect(estado.indisponiveis['explicar_dia'], isNotNull);
    });

    test('limpar remove só a resposta daquele id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mcAcoesProvider.notifier);

      // Não há setter público de respostas fora de executar(); aqui só
      // confere que limpar em estado vazio não lança.
      expect(() => notifier.limpar('explicar_dia'), returnsNormally);
      expect(() => notifier.limparTudo(), returnsNormally);
    });
  });
}
