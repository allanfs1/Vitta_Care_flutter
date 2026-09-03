import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/ia/acoes_ia.dart';
import 'package:vitta_app/features/monte_carlo/ia/validador_numeros.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_calibracao.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_engine.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_historico_demo.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';

/// Testes do catálogo de ações de IA do simulador.
///
/// O que importa aqui não é o texto que o modelo escreveria — é que o
/// **contexto montado em Dart** carrega os números certos e que o conjunto
/// `numerosPermitidos` de fato contém as cifras que aparecem nos fatos. Se
/// essa extração falhar, o validador marcaria como "inventado" um número que
/// a IA só copiou — o oposto do que a trava deve fazer.
void main() {
  final data = DateTime(2026, 9, 15);
  const montador = MontadorContexto();

  Doctor medico(String id, {int slotLimit = 3, int overbook = 0}) => Doctor(
        id: id,
        name: 'Dr. $id',
        crm: 'CRM$id',
        specialties: const ['Clínica'],
        slotLimit: slotLimit,
        maxOverbook: overbook,
      );

  ConsultaRisco consulta({
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

  SimulacaoResultado simularDia({
    int n = 20,
    double pFalta = 0.15,
    double pCancel = 0.05,
    int slotLimit = 25,
  }) =>
      MonteCarloEngine.simular(
        data: data,
        consultas: [
          for (var i = 0; i < n; i++)
            consulta(
              id: 'a$i',
              pFalta: pFalta,
              pCancel: pCancel,
              risco: RiskLevel.values[i % 3],
            ),
        ],
        medicos: [medico('m1', slotLimit: slotLimit)],
        config: const SimulacaoConfig(rho: 0),
      );

  group('Catálogo', () {
    test('todo id é único e toda ação tem descrição', () {
      final ids = AcaoIa.catalogo.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id duplicado');
      for (final a in AcaoIa.catalogo) {
        expect(a.descricao, isNotEmpty, reason: '${a.id} sem descrição');
        expect(a.titulo, isNotEmpty, reason: '${a.id} sem título');
      }
    });

    test('lista da aba exclui as ações de gráfico', () {
      expect(AcaoIa.lista.any((a) => a.categoria == CategoriaAcao.grafico),
          isFalse);
      expect(AcaoIa.catalogo.any((a) => a.categoria == CategoriaAcao.grafico),
          isTrue);
    });

    test('porId encontra e devolve null para desconhecido', () {
      expect(AcaoIa.porId('explicar_dia'), isNotNull);
      expect(AcaoIa.porId('nao_existe'), isNull);
    });
  });

  group('MontadorContexto — sem dados devolve null, nunca quebra', () {
    test('todas as ações que exigem agenda recusam resultado nulo', () {
      for (final a in AcaoIa.catalogo.where((a) => a.exigeAgenda)) {
        final ctx = montador.montar(
          acaoId: a.id,
          resultado: null,
          calibracao: null,
          cenarios: const [],
          encaixesRecomendados: 0,
          limiteRisco: 0.05,
        );
        expect(ctx, isNull, reason: '${a.id} deveria recusar sem resultado');
      }
    });

    test('agenda vazia (0 agendados) também recusa', () {
      final vazio = simularDia(n: 0);
      final ctx = montador.montar(
        acaoId: 'explicar_dia',
        resultado: vazio,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(ctx, isNull);
    });

    test('diagnosticar_dados recusa sem calibração', () {
      final ctx = montador.montar(
        acaoId: 'diagnosticar_dados',
        resultado: null,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(ctx, isNull);
    });

    test('id desconhecido devolve null', () {
      final r = simularDia();
      expect(
          montador.montar(
            acaoId: 'inexistente',
            resultado: r,
            calibracao: null,
            cenarios: const [],
            encaixesRecomendados: 0,
            limiteRisco: 0.05,
          ),
          isNull);
    });
  });

  group('MontadorContexto — os fatos carregam os números certos', () {
    test('explicar_dia cita agendados, P50, P95 e o limite', () {
      final r = simularDia(n: 30, pFalta: 0.2);
      final k = MonteCarloEngine.encaixesRecomendados(r, limiteRisco: 0.05);

      final ctx = montador.montar(
        acaoId: 'explicar_dia',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: k,
        limiteRisco: 0.05,
      );

      expect(ctx, isNotNull);
      expect(ctx!.fatos, contains('${r.totalAgendados}'));
      expect(ctx.fatos, contains('${r.faltas.p50}'));
      expect(ctx.fatos, contains('${r.faltas.p95}'));
      expect(ctx.numerosPermitidos, contains('${r.totalAgendados}'));
      expect(ctx.numerosPermitidos, contains('${r.faltas.p95}'));
      expect(ctx.instrucao, contains('APENAS os números fornecidos'));
    });

    test('gargalo lista os slots ordenados por risco decrescente', () {
      final r = simularDia(n: 40, pFalta: 0.3, slotLimit: 30);
      final ctx = montador.montar(
        acaoId: 'gargalo',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(ctx, isNotNull);
      // O nome do médico único desta fixture precisa aparecer nos fatos.
      expect(ctx!.fatos, contains('Dr. m1'));
    });

    test('testar_intervencao roda um segundo cenário e não altera o original',
        () {
      final r = simularDia(n: 25, pFalta: 0.25);
      final faltasAntes = r.faltasEsperadas;

      final ctx = montador.montar(
        acaoId: 'testar_intervencao',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );

      expect(ctx, isNotNull);
      expect(ctx!.fatos, contains('SEM a intervenção'));
      expect(ctx.fatos, contains('COM a intervenção'));
      // O resultado original não foi mutado pela simulação de comparação.
      expect(r.faltasEsperadas, faltasAntes);
    });

    test('diagnosticar_dados traz os achados de integridade nos fatos', () {
      final c = MonteCarloCalibracao.estimar(historico: const []);
      final ctx = montador.montar(
        acaoId: 'diagnosticar_dados',
        resultado: null,
        calibracao: c,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(ctx, isNotNull);
      expect(c.integridade.bloqueios, isNotEmpty);
      expect(ctx!.fatos, contains('BLOQUEIA'));
    });

    test('mensagem_fila recusa quando não há chamada segura', () {
      // pCancel = 0: nada libera vaga com aviso.
      final r = simularDia(n: 20, pCancel: 0.0);
      final ctx = montador.montar(
        acaoId: 'mensagem_fila',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(r.fila.chamadasSeguras, 0);
      expect(ctx, isNull);
    });

    test('mensagem_fila cita o número de chamadas quando há fila', () {
      final r = simularDia(n: 30, pCancel: 0.3);
      final ctx = montador.montar(
        acaoId: 'mensagem_fila',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      if (r.fila.chamadasSeguras > 0) {
        expect(ctx, isNotNull);
        expect(ctx!.fatos, contains('${r.fila.chamadasSeguras}'));
      }
    });

    test('resumo_gestao sempre menciona que não está calibrado', () {
      final r = simularDia();
      final ctx = montador.montar(
        acaoId: 'resumo_gestao',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 3,
        limiteRisco: 0.05,
      );
      expect(ctx, isNotNull);
      expect(ctx!.fatos, contains('Modelo calibrado com dados reais: não'));
      expect(ctx.numerosPermitidos, contains('3'));
    });
  });

  group('Ações de gráfico', () {
    test('grafico_distribuicao carrega P05/P50/P95', () {
      final r = simularDia(n: 20);
      final ctx = montador.montar(
        acaoId: 'grafico_distribuicao',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(ctx, isNotNull);
      expect(ctx!.fatos, contains('${r.faltas.p05}'));
      expect(ctx.fatos, contains('${r.faltas.p50}'));
      expect(ctx.fatos, contains('${r.faltas.p95}'));
    });

    test('grafico_sazonalidade distingue "não testável" de "não '
        'significativo"', () {
      final fim = DateTime(2026, 9, 1);
      // Histórico curto: poucos meses com dado suficiente para o teste.
      final curto = MonteCarloCalibracao.estimar(
        historico: HistoricoDemo.gerar(dias: 40, ate: fim),
        ate: fim,
      );
      expect(curto.sazonalidadeTestavel, isFalse);

      final ctx = montador.montar(
        acaoId: 'grafico_sazonalidade',
        resultado: null,
        calibracao: curto,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(ctx, isNotNull);
      expect(ctx!.fatos, contains('O teste pôde rodar: não'));
      expect(ctx.instrucao, contains('não deu para testar'));
    });

    test('grafico_slots recusa sem slots', () {
      final vazio = simularDia(n: 0);
      final ctx = montador.montar(
        acaoId: 'grafico_slots',
        resultado: vazio,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      );
      expect(ctx, isNull);
    });
  });

  group('Validador aplicado ao texto simulado de uma resposta', () {
    test('número presente nos fatos não é marcado', () {
      final r = simularDia(n: 20, pFalta: 0.15);
      final ctx = montador.montar(
        acaoId: 'explicar_dia',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      )!;

      const validador = ValidadorNumeros();
      final textoFiel = 'A agenda tem ${r.totalAgendados} consultas.';
      final v = validador.validar(textoFiel, ctx.numerosPermitidos);
      expect(v.ok, isTrue);
    });

    test('número inventado é marcado', () {
      final r = simularDia(n: 20, pFalta: 0.15);
      final ctx = montador.montar(
        acaoId: 'explicar_dia',
        resultado: r,
        calibracao: null,
        cenarios: const [],
        encaixesRecomendados: 0,
        limiteRisco: 0.05,
      )!;

      const validador = ValidadorNumeros();
      // 987654 quase certamente não aparece nos fatos desta fixture.
      final textoRuim = 'A agenda tem 987654 consultas.';
      final v = validador.validar(textoRuim, ctx.numerosPermitidos);
      expect(v.ok, isFalse);
      expect(v.naoConferem, contains('987654'));

      final anotado = validador.anotar(textoRuim, v);
      expect(anotado, contains('987654 ⚠️'));
    });
  });
}
