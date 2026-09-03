// TEMPORARIO - auditoria estatistica 4. APAGAR.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/projecao_amostradores.dart';
import 'package:vitta_app/features/projecao_12m/projecao_engine.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';

void main() {
  test('causa raiz: math.pow(q,n) subnormal/zero', () {
    for (final c in [
      [250, 0.03],
      [300, 0.03],
      [250, 0.02],
      [204, 0.0196],
      [200, 0.03],
    ]) {
      final n = (c[0] as num).toInt();
      final q = (c[1] as num).toDouble();
      print('n=$n q=$q -> pow=${math.pow(q, n)}  '
          'ln-necessario=${(n * math.log(1 / q)).toStringAsFixed(1)} '
          '(underflow acima de ~745)');
    }
  });

  test('regiao quebrada: varredura n x p', () {
    print('n\\p   0.970   0.980   0.990   0.995');
    for (final n in [100, 150, 200, 250, 300, 400, 500, 700, 900, 1200]) {
      final linha = StringBuffer('${n.toString().padLeft(4)} ');
      for (final p in [0.97, 0.98, 0.99, 0.995]) {
        final rng = Amostradores(3);
        var soma = 0.0;
        const m = 4000;
        for (var i = 0; i < m; i++) {
          soma += rng.binomialComZ(n, p, rng.normal());
        }
        final erro = soma / m - n * p;
        final v = n * p * (1 - p);
        final tag = v >= 9 ? 'N' : 'I';
        linha.write('${'$tag${erro.toStringAsFixed(2)}'.padLeft(8)}');
      }
      print(linha);
    }
    print('(N=ramo normal, I=ramo inverso; valor = vies da media, '
        'deveria ser ~0)');
  });

  test('caminho 2: condicional falta|nao-comparecimento', () {
    // taxaFalta alta + cancelamento minimo => p condicional -> 1
    for (final ag in [300, 400, 500, 700, 1000]) {
      final cfg = ProjecaoConfig(
        agendamentosMensais: ag,
        capacidadeMensal: 4000,
        taxaFalta: 0.50,
        taxaCancelamento: 0.01,
        nHistorico: 800,
        nSimulacoes: 2000,
        intervencao: const ParametrosIntervencao(taxaReposicaoVaga: 0),
      );
      final r = ProjecaoEngine.projetar(cfg);
      print('ag=$ag  cancel p50=${r.baseline.cancelamentos.p50} '
          '(esperado ~${(ag * 12 * 0.01).round()})  '
          'falta p50=${r.baseline.faltas.p50} '
          '(esperado ~${(ag * 12 * 0.50).round()})');
    }
  });
}
