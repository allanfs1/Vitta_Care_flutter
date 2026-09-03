// TEMPORARIO - auditoria estatistica 3. APAGAR.
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/projecao_engine.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';

void main() {
  test('spec fig.2 / tabela p.15: 1 mes, 1200 agend, falta 22%, cancel 10%', () {
    const cfg = ProjecaoConfig(
      horizonteMeses: 1,
      agendamentosMensais: 1200,
      capacidadeMensal: 100000,
      taxaFalta: 0.22,
      taxaCancelamento: 0.10,
      wapeForecast: 0.12,
      nHistorico: 800,
      nSimulacoes: 200000,
      intervencao: ParametrosIntervencao(
          reducaoFalta: 0, reducaoCancelamento: 0, taxaReposicaoVaga: 0),
    );
    final r = ProjecaoEngine.projetar(cfg);
    print('faltas          motor=${r.baseline.faltas.toMap()}    spec=204/262/332');
    print('cancelamentos   motor=${r.baseline.cancelamentos.toMap()}    spec=87/119/158');
    print('comparecimentos motor=${r.baseline.comparecimentos.toMap()}    spec=660/810/993');
    print('agendamentos    motor=${r.baseline.agendamentos.toMap()}');
  });

  test('taxas realizadas no agregado (spec: 0,0999 contra alvo 0,1000)', () {
    const cfg = ProjecaoConfig(
      horizonteMeses: 12,
      agendamentosMensais: 1200,
      capacidadeMensal: 100000,
      taxaFalta: 0.22,
      taxaCancelamento: 0.10,
      nHistorico: 800,
      nSimulacoes: 40000,
      intervencao: ParametrosIntervencao(
          reducaoFalta: 0, reducaoCancelamento: 0, taxaReposicaoVaga: 0),
    );
    final r = ProjecaoEngine.projetar(cfg);
    final ag = r.baseline.agendamentos.p50;
    print('falta realizada  = ${(r.baseline.faltas.p50 / ag).toStringAsFixed(5)} '
        '(alvo 0.22000)');
    print('cancel realizada = '
        '${(r.baseline.cancelamentos.p50 / ag).toStringAsFixed(5)} (alvo 0.10000)');
  });

  test('intensidades: faixa do efeito vs banda declarada', () {
    for (final i in IntensidadeCenario.values) {
      final r = ProjecaoEngine.projetar(ProjecaoConfig(
        nSimulacoes: 6000,
        intensidade: i,
        intervencao: ParametrosIntervencao.de(i),
      ));
      print('${i.name.padRight(12)} faltasEvitadas=${r.faltasEvitadas.toMap()} '
          'receitaDefensavel=${r.impacto.receitaDefensavel.round()}');
    }
  });
}
