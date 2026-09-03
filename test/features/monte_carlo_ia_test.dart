import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/ia/plano_semanal.dart';
import 'package:vitta_app/features/monte_carlo/ia/validador_numeros.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_engine.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';

/// Testes da camada de IA do Simulador.
///
/// O que mais importa aqui é a **trava de números**: a saída deste módulo vira
/// decisão de agenda, e um número inventado enche uma sala de espera real.

ConsultaRisco _consulta(String id, int hora, {double pFalta = 0.2}) =>
    ConsultaRisco(
      appointmentId: id,
      doctorId: 'm1',
      hour: hora,
      pFalta: pFalta,
      pCancel: 0.05,
      risco: RiskLevel.medium,
    );

/// Agenda de um dia: [n] consultas distribuídas em horas cheias.
List<ConsultaRisco> _agenda(int n, {double pFalta = 0.2}) =>
    List.generate(n, (i) => _consulta('a$i', 8 + (i % 8), pFalta: pFalta));

SimulacaoResultado _simular(DateTime d, List<ConsultaRisco> c) =>
    MonteCarloEngine.simular(
      data: d,
      consultas: c,
      config: const SimulacaoConfig(nRuns: 2000, seed: 42),
    );

void main() {
  group('ValidadorNumeros', () {
    const v = ValidadorNumeros();

    test('aceita número que veio da simulação', () {
      final r = v.validar('Cabem 12 encaixes e sobram 480 reais.',
          {'12', '480'});
      expect(r.ok, isTrue);
      expect(r.conferem, containsAll(['12', '480']));
      expect(v.aviso(r), isNull);
    });

    test('acusa número inventado', () {
      // O caso perigoso: a simulação disse 2, o texto diz 6.
      final r = v.validar('Recomendo 6 encaixes na terça.', {'2', '18'});
      expect(r.ok, isFalse);
      expect(r.naoConferem, ['6']);
      expect(v.aviso(r), contains('não veio da simulação'));
    });

    test('marca no texto em vez de apagar', () {
      const texto = 'Recomendo 6 encaixes.';
      final r = v.validar(texto, {'2'});
      final anotado = v.anotar(texto, r);
      // Apagar deixaria "Recomendo encaixes", afirmando o mesmo sem nada que
      // denuncie o problema.
      expect(anotado, contains('6'));
      expect(anotado, contains('⚠️'));
    });

    test('NÃO acusa percentual, hora, ordinal nem data', () {
      // Exigir estes no conjunto encheria a tela de alarme falso, e alarme
      // falso treina o gestor a ignorar o aviso.
      final r = v.validar(
        'Risco de 5% às 14h no 1º dia, em 02/09, contra 100% da meta.',
        {'42'},
      );
      expect(r.naoConferem, isEmpty, reason: 'nada aqui é cifra da simulação');
    });

    test('normaliza milhar e decimal', () {
      // 1.234 e 1234 são o mesmo número; 2,5 e 2.5 também.
      expect(v.validar('R\$ 1.234 previstos', {'1234'}).ok, isTrue);
      expect(v.validar('ociosidade de 2,5 vagas', {'2.5'}).ok, isTrue);
      expect(v.validar('média de 3.0 faltas', {'3'}).ok, isTrue);
    });

    test('texto sem número nenhum passa e é sinalizado', () {
      final r = v.validar('A semana está tranquila.', {'7'});
      expect(r.ok, isTrue);
      expect(r.semNumeros, isTrue);
    });

    test('não duplica o mesmo número', () {
      final r = v.validar('12 hoje, 12 amanhã, 12 sempre.', {'12'});
      expect(r.citados, ['12']);
    });
  });

  group('ExecutorPlano', () {
    const executor = ExecutorPlano(
      limiteRisco: 0.05,
      limiteEquidade: 1.25,
      valorSlot: 180,
    );

    test('varre a janela inteira, um dia por vez', () {
      final plano = executor.montar(
        inicio: DateTime(2026, 9, 7),
        dias: 5,
        consultasDe: (_) => _agenda(16),
        simular: _simular,
      );
      expect(plano.dias.length, 5);
      expect(plano.dias.first.data.day, 7);
      expect(plano.dias.last.data.day, 11);
    });

    test('dia sem agenda não entra nas somas', () {
      final plano = executor.montar(
        inicio: DateTime(2026, 9, 7),
        dias: 3,
        // Só o dia do meio tem agenda.
        consultasDe: (d) => d.day == 8 ? _agenda(16) : const [],
        simular: _simular,
      );
      expect(plano.dias.length, 3);
      expect(plano.comAgenda.length, 1);
      expect(plano.dias.first.atencao, AtencaoDia.semAgenda);
    });

    test('um dia que falha não derruba a semana', () {
      // O gestor ainda precisa do plano dos outros dias.
      final plano = executor.montar(
        inicio: DateTime(2026, 9, 7),
        dias: 4,
        consultasDe: (d) {
          if (d.day == 9) throw StateError('agenda indisponível');
          return _agenda(16);
        },
        simular: _simular,
      );
      expect(plano.dias.length, 4);
      final falho = plano.dias.firstWhere((x) => x.data.day == 9);
      expect(falho.ok, isFalse);
      expect(falho.atencao, AtencaoDia.falha);
      expect(plano.comAgenda.length, 3, reason: 'os outros três seguem');
    });

    test('a receita adicional é derivada do valor do slot', () {
      final plano = executor.montar(
        inicio: DateTime(2026, 9, 7),
        dias: 1,
        consultasDe: (_) => _agenda(16),
        simular: _simular,
      );
      final d = plano.dias.single;
      expect(d.receitaAdicional, d.encaixesRecomendados * 180);
    });

    test('é reprodutível: mesma semente, mesmo plano', () {
      // É o que permite o gestor conferir depois o que foi decidido.
      PlanoSemanal rodar() => executor.montar(
            inicio: DateTime(2026, 9, 7),
            dias: 3,
            consultasDe: (_) => _agenda(16),
            simular: _simular,
          );
      final a = rodar();
      final b = rodar();
      expect(
        a.dias.map((d) => d.encaixesRecomendados),
        b.dias.map((d) => d.encaixesRecomendados),
      );
      expect(a.totalEncaixes, b.totalEncaixes);
    });

    test('agenda cheia de faltantes libera encaixe; agenda vazia, não', () {
      // Sanidade do domínio: mais faltas esperadas ⇒ mais espaço para encaixe.
      final muitasFaltas = executor.montar(
        inicio: DateTime(2026, 9, 7),
        dias: 1,
        consultasDe: (_) => _agenda(24, pFalta: 0.45),
        simular: _simular,
      );
      final poucasFaltas = executor.montar(
        inicio: DateTime(2026, 9, 7),
        dias: 1,
        consultasDe: (_) => _agenda(24, pFalta: 0.02),
        simular: _simular,
      );
      expect(
        muitasFaltas.dias.single.encaixesRecomendados,
        greaterThanOrEqualTo(poucasFaltas.dias.single.encaixesRecomendados),
      );
    });
  });

  group('PlanoSemanal', () {
    PlanoSemanal plano(List<DiaPlanejado> dias) =>
        PlanoSemanal(dias: dias, geradoEm: DateTime(2026, 9, 6));

    DiaPlanejado dia({
      int dia = 7,
      int agendados = 16,
      int encaixes = 2,
      int acimaDoLimite = 0,
      double ociosidade = 1.0,
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
        );

    test('separa os dias que pedem atenção', () {
      final p = plano([
        dia(dia: 7),
        dia(dia: 8, encaixes: 0),
        dia(dia: 9, acimaDoLimite: 2),
        dia(dia: 10, agendados: 0, encaixes: 0),
      ]);
      expect(p.comAgenda.length, 3);
      expect(p.bloqueados.map((d) => d.data.day), [8]);
      expect(p.dias[1].atencao, AtencaoDia.cheio);
      expect(p.dias[2].atencao, AtencaoDia.critico);
      expect(p.dias[2].atencao.pedeAtencao, isTrue);
      expect(p.dias[0].atencao.pedeAtencao, isFalse);
    });

    test('folga é sinalizada como oportunidade, não como problema', () {
      final p = plano([dia(ociosidade: 3.5)]);
      expect(p.dias.single.atencao, AtencaoDia.folga);
      expect(p.comFolga.length, 1);
      expect(p.dias.single.atencao.pedeAtencao, isFalse);
    });

    test('o prompt entrega todos os dias, inclusive os sem agenda', () {
      // O gestor precisa ver que o dia foi olhado, não apenas omitido.
      final texto = plano([dia(dia: 7), dia(dia: 8, agendados: 0)]).paraPrompt();
      expect(texto, contains('07/09'));
      expect(texto, contains('08/09'));
      expect(texto, contains('sem agenda'));
    });

    test('os números permitidos cobrem o que o prompt mostra', () {
      // Se um número aparece no prompt e não no conjunto permitido, a IA seria
      // acusada de inventar o que nós mesmos demos a ela.
      final p = plano([dia(dia: 7, agendados: 16, encaixes: 2)]);
      const v = ValidadorNumeros();
      final r = v.validar(p.paraPrompt(), p.numerosPermitidos);
      expect(r.naoConferem, isEmpty,
          reason: 'o próprio prompt tem de passar na validação');
    });

    test('totais somam só os dias com agenda', () {
      final p = plano([
        dia(dia: 7, encaixes: 2),
        dia(dia: 8, encaixes: 3),
        dia(dia: 9, agendados: 0, encaixes: 0),
      ]);
      expect(p.totalEncaixes, 5);
      expect(p.receitaAdicional, 5 * 180);
    });
  });
}
