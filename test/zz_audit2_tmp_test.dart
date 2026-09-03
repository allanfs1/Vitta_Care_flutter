// TEMPORARIO - auditoria estatistica 2. APAGAR.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/projecao_amostradores.dart';
import 'package:vitta_app/features/projecao_12m/projecao_engine.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';

const outDir =
    r'C:\Users\micro\AppData\Local\Temp\claude\C--Users-micro-OneDrive-Documentos-AntiyGravity-Flutter-vitta-app\1d851834-f8d7-405a-bc56-0f35f148aeee\scratchpad\out';

void main() {
  test('A. underflow ponta a ponta com config dentro dos sliders', () {
    // sliders: agendamentosMensais [100,4000], taxaFalta [0.02,0.50],
    // taxaCancelamento [0.01,0.35], nHistorico [30,800]
    for (final ag in [150, 200, 250, 300, 400, 600, 900, 1190]) {
      final cfg = ProjecaoConfig(
        agendamentosMensais: ag,
        capacidadeMensal: 4000,
        taxaFalta: 0.02,
        taxaCancelamento: 0.01,
        nHistorico: 800,
        nSimulacoes: 2000,
        intervencao: const ParametrosIntervencao(taxaReposicaoVaga: 0),
      );
      final r = ProjecaoEngine.projetar(cfg);
      final esperadoFaltas = ag * 12 * 0.02;
      final esperadoCancel = ag * 12 * 0.01;
      print('ag=$ag  faltas p50=${r.baseline.faltas.p50} '
          '(esperado ~${esperadoFaltas.round()})  '
          'cancel p50=${r.baseline.cancelamentos.p50} '
          '(esperado ~${esperadoCancel.round()})  '
          'comp p50=${r.baseline.comparecimentos.p50} '
          'agend p50=${r.baseline.agendamentos.p50}  '
          'largura faltas=${r.baseline.faltas.largura}');
    }
  });

  test('A2. binomialComZ direto na regiao quebrada', () {
    print('n,p,var,q^n,media_sim,media_teo,sd_sim,sd_teo');
    for (final c in [
      [150, 0.97],
      [200, 0.97],
      [250, 0.97],
      [300, 0.97],
      [250, 0.98],
      [250, 0.99],
      [900, 0.995],
      [250, 0.03],
      [250, 0.02],
    ]) {
      final n = (c[0] as num).toInt();
      final p = (c[1] as num).toDouble();
      final rng = Amostradores(9);
      var soma = 0.0, soma2 = 0.0;
      const m = 20000;
      for (var i = 0; i < m; i++) {
        final k = rng.binomialComZ(n, p, rng.normal());
        soma += k;
        soma2 += k * k;
      }
      final med = soma / m;
      final sd = math.sqrt(soma2 / m - med * med);
      final qn = math.pow(1 - p, n);
      print('$n,$p,${(n * p * (1 - p)).toStringAsFixed(2)},$qn,'
          '${med.toStringAsFixed(3)},${(n * p).toStringAsFixed(3)},'
          '${sd.toStringAsFixed(3)},${math.sqrt(n * p * (1 - p)).toStringAsFixed(3)}');
    }
  });

  test('B. descontinuidade no limiar var=9 no pareamento', () {
    // dois cenarios com p ligeiramente diferente e n tal que um cai em cada ramo
    final sb = StringBuffer('caso,nA,pA,nB,pB,dif\n');
    void par(String caso, int nA, double pA, int nB, double pB) {
      final rng = Amostradores(21);
      for (var i = 0; i < 40000; i++) {
        final z = rng.normal();
        final a = rng.binomialComZ(nA, pA, z);
        final b = rng.binomialComZ(nB, pB, z);
        sb.writeln('$caso,$nA,$pA,$nB,$pB,${a - b}');
      }
    }

    // ambos no ramo exato (var 8.1 e 7.3)
    par('ambos_inv', 90, 0.10, 90, 0.09);
    // A no ramo normal (var 9.0), B no exato (var 8.2)  <-- straddle
    par('straddle', 100, 0.10, 100, 0.09);
    // ambos no ramo normal
    par('ambos_norm', 200, 0.10, 200, 0.09);
    File('$outDir\\straddle.csv').writeAsStringSync(sb.toString());
  });

  test('C. incerteza do tamanho de efeito ausente', () {
    const cfg = ProjecaoConfig(nSimulacoes: 4000);
    final r = ProjecaoEngine.projetar(cfg);
    print('reducaoFalta FIXA em 0.20 -> faltasEvitadas '
        '${r.faltasEvitadas.toMap()} largura=${r.faltasEvitadas.largura}');
    // varredura do proprio parametro
    final sb = StringBuffer('red,p05,p50,p95\n');
    for (var i = 0; i <= 20; i++) {
      final red = 0.05 + 0.30 * i / 20;
      final rr = ProjecaoEngine.projetar(ProjecaoConfig(
        nSimulacoes: 1500,
        intervencao: ParametrosIntervencao(reducaoFalta: red),
      ));
      sb.writeln('$red,${rr.faltasEvitadas.p05},${rr.faltasEvitadas.p50},'
          '${rr.faltasEvitadas.p95}');
    }
    File('$outDir\\efeito.csv').writeAsStringSync(sb.toString());
    print(File('$outDir\\efeito.csv').readAsStringSync());
  });

  test('D. taxas altas: _normalizar com f+c>1', () {
    for (final nh in [800, 200, 30]) {
      final cfg = ProjecaoConfig(
        taxaFalta: 0.50,
        taxaCancelamento: 0.35,
        nHistorico: nh,
        nSimulacoes: 3000,
        capacidadeMensal: 4000,
        intervencao: const ParametrosIntervencao(taxaReposicaoVaga: 0),
      );
      final r = ProjecaoEngine.projetar(cfg);
      final ag = r.baseline.agendamentos.p50;
      print('nHist=$nh  taxa falta realizada='
          '${(r.baseline.faltas.p50 / ag).toStringAsFixed(4)} (pedida 0.5000)  '
          'cancel realizada=${(r.baseline.cancelamentos.p50 / ag).toStringAsFixed(4)}'
          ' (pedida 0.3500)');
    }
  });

  test('E. cobertura do intervalo pareado', () {
    // roda o motor com varias seeds e ve se o p50 de uma corrida cai
    // dentro do P05-P95 de outra (auto-consistencia da banda)
    final p50s = <num>[];
    late Percentis banda;
    for (var s = 1; s <= 40; s++) {
      final r = ProjecaoEngine.projetar(
          ProjecaoConfig(seed: s, nSimulacoes: 4000));
      if (s == 1) banda = r.faltasEvitadas;
      p50s.add(r.faltasEvitadas.p50);
    }
    p50s.sort();
    print('banda seed1: ${banda.toMap()}');
    print('p50 sobre 40 seeds: min=${p50s.first} max=${p50s.last} '
        'mediana=${p50s[20]}');
  });

  test('F. reposicao quando NAO ha demanda reprimida', () {
    const cfg = ProjecaoConfig(
      agendamentosMensais: 800,
      capacidadeMensal: 4000, // folga enorme: reprimida sempre 0
      nSimulacoes: 2000,
      intervencao: ParametrosIntervencao(taxaReposicaoVaga: 0.30),
    );
    final r = ProjecaoEngine.projetar(cfg);
    print('folga: reprimida p95=${r.baseline.demandaReprimida.p95} '
        'repostas p50=${r.agendaClinica.vagasRepostas.p50} '
        'agendA=${r.baseline.agendamentos.p50} '
        'agendB=${r.agendaClinica.agendamentos.p50}');
  });
}
