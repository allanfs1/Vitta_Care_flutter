import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/projecao_engine.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';

void main() {
  test('composicao do ganho', () {
    const c = ProjecaoConfig(nSimulacoes: 8000);
    final r = ProjecaoEngine.projetar(c);
    final ganho = r.agendaClinica.comparecimentos.p50 -
        r.baseline.comparecimentos.p50;
    // ignore: avoid_print
    print('comparecimentos base p50=${r.baseline.comparecimentos.p50} '
        'agenda p50=${r.agendaClinica.comparecimentos.p50} ganho=$ganho');
    // ignore: avoid_print
    print('faltasEvitadas (pareado) p50=${r.faltasEvitadas.p50} '
        'p05=${r.faltasEvitadas.p05} p95=${r.faltasEvitadas.p95}');
    // ignore: avoid_print
    print('cancelamentosEvitados (pareado) p50=${r.cancelamentosEvitados.p50}');
    // ignore: avoid_print
    print('vagasRepostas p50=${r.agendaClinica.vagasRepostas.p50}');
    final i = r.impacto;
    // ignore: avoid_print
    print('LINHA UI "Consultas por falta evitada" = '
        '${i.consultasFaltaEvitada.toStringAsFixed(1)}');
    // ignore: avoid_print
    print('  mas faltas evitadas de verdade = ${r.faltasEvitadas.p50}');
    // ignore: avoid_print
    print('  e cancelamentos evitados = ${r.cancelamentosEvitados.p50}');
    // ignore: avoid_print
    print('  soma = ${r.faltasEvitadas.p50 + r.cancelamentosEvitados.p50}');
    // ignore: avoid_print
    print('receitaDefensavel=${i.receitaDefensavel} '
        'antecipacao=${i.receitaAntecipacao} '
        'superestimativa=${i.superestimativaIngenua}');
    // ignore: avoid_print
    print('temDemandaReprimida=${r.temDemandaReprimida} '
        'mesesReprimida=${r.agendaClinica.mesesComDemandaReprimida} '
        'pEstouro=${r.agendaClinica.probabilidadeEstouro} '
        'reprimidaP50=${r.agendaClinica.demandaReprimida.p50}');
    // ignore: avoid_print
    print('base reprimida p50=${r.baseline.demandaReprimida.p50} '
        'iguais? ${r.baseline.demandaReprimida.p50 ==
            r.agendaClinica.demandaReprimida.p50}');
  });
}
