import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/risco_calibracao.dart';

/// Calibração do escore de risco.
///
/// O critério que estes testes protegem é o da especificação: **ECE ≤ 0,03 e
/// Brier melhor que a taxa-base constante** antes de o escore poder multiplicar
/// dinheiro. Um escore que ordena bem e erra o nível passa despercebido em
/// qualquer métrica de ordenação — e é justamente ele que envenena a projeção
/// financeira.
void main() {
  group('ECE e Brier', () {
    test('escore perfeitamente calibrado tem ECE próximo de zero', () {
      // 10 faixas, cada uma com frequência real igual à confiança prometida.
      final previsto = <double>[];
      final observado = <int>[];
      for (var f = 0; f < 10; f++) {
        final p = (f + 0.5) / 10;
        const n = 1000;
        for (var i = 0; i < n; i++) {
          previsto.add(p);
          observado.add(i < (p * n).round() ? 1 : 0);
        }
      }
      expect(RiscoCalibracao.ece(previsto, observado), lessThan(0.005));
    });

    test('escore que erra o nível é reprovado mesmo ordenando bem', () {
      // Ordenação perfeita, nível inflado: o modelo diz o dobro do que ocorre.
      final rng = math.Random(11);
      final verdadeiro = <double>[];
      final previsto = <double>[];
      final observado = <int>[];
      for (var i = 0; i < 8000; i++) {
        final p = rng.nextDouble() * 0.4;
        verdadeiro.add(p);
        previsto.add((p * 2).clamp(0.0, 1.0));
        observado.add(rng.nextDouble() < p ? 1 : 0);
      }

      final bom = RiscoCalibracao.diagnosticar(verdadeiro, observado);
      final inflado = RiscoCalibracao.diagnosticar(previsto, observado);

      expect(bom.eceAceitavel, isTrue);
      expect(inflado.eceAceitavel, isFalse,
          reason: 'inflar o nível preserva a ordenação e destrói a calibração');
      expect(inflado.vies, greaterThan(0.1));
      // A ordenação é idêntica nos dois: a diferença é só de nível.
      expect(RiscoCalibracao.prAuc(previsto, observado),
          closeTo(RiscoCalibracao.prAuc(verdadeiro, observado), 1e-9));
    });

    test('Brier da taxa-base é o piso que o modelo precisa bater', () {
      final rng = math.Random(3);
      final previsto = <double>[];
      final observado = <int>[];
      for (var i = 0; i < 5000; i++) {
        final p = rng.nextBool() ? 0.05 : 0.45;
        previsto.add(p);
        observado.add(rng.nextDouble() < p ? 1 : 0);
      }
      final d = RiscoCalibracao.diagnosticar(previsto, observado);
      expect(d.brierMelhorQueTaxaBase, isTrue);
      expect(d.ganhoSobreTaxaBase, greaterThan(0.1));
      expect(d.podeAlimentarFinanceiro, isTrue);
    });

    test('escore sem informação não bate a taxa-base', () {
      final rng = math.Random(17);
      const taxa = 0.22;
      final observado = [
        for (var i = 0; i < 5000; i++) rng.nextDouble() < taxa ? 1 : 0,
      ];
      // Escore aleatório, descorrelacionado do desfecho.
      final previsto = [
        for (var i = 0; i < 5000; i++) taxa + (rng.nextDouble() - 0.5) * 0.1,
      ];
      final d = RiscoCalibracao.diagnosticar(previsto, observado);
      expect(d.brierMelhorQueTaxaBase, isFalse);
      expect(d.podeAlimentarFinanceiro, isFalse);
    });

    test('escores iguais a 1 entram na conta do ECE', () {
      // Um modelo que diz 100% e acerta metade das vezes está gravemente
      // descalibrado. Descartar a faixa fechada esconderia exatamente isso.
      final previsto = List<double>.filled(1000, 1.0);
      final observado = [for (var i = 0; i < 1000; i++) i.isEven ? 1 : 0];
      expect(RiscoCalibracao.ece(previsto, observado), closeTo(0.5, 0.01));
    });
  });

  group('Regressão isotônica', () {
    test('é monótona não-decrescente por construção', () {
      final rng = math.Random(5);
      final previsto = <double>[];
      final observado = <int>[];
      for (var i = 0; i < 3000; i++) {
        final p = rng.nextDouble();
        previsto.add(p);
        // Relação monótona com ruído — o PAV precisa recuperar a tendência.
        observado.add(rng.nextDouble() < p * 0.6 ? 1 : 0);
      }
      final cal = CalibradorIsotonico.ajustar(previsto, observado);

      var anterior = -1.0;
      for (var x = 0.0; x <= 1.0; x += 0.01) {
        final y = cal.aplicar(x);
        expect(y, greaterThanOrEqualTo(anterior - 1e-9),
            reason: 'a isotônica não pode descer em x=$x');
        expect(y, inInclusiveRange(0.0, 1.0));
        anterior = y;
      }
    });

    test('preserva a ordenação — recalibrar não bagunça a fila', () {
      final rng = math.Random(23);
      final previsto = [for (var i = 0; i < 2000; i++) rng.nextDouble()];
      final observado = [
        for (final p in previsto) rng.nextDouble() < p * 0.5 ? 1 : 0,
      ];
      final cal = CalibradorIsotonico.ajustar(previsto, observado);
      final depois = cal.aplicarTodos(previsto);

      for (var i = 0; i < previsto.length; i++) {
        for (var j = i + 1; j < i + 12 && j < previsto.length; j++) {
          if (previsto[i] < previsto[j]) {
            expect(depois[i], lessThanOrEqualTo(depois[j] + 1e-9));
          }
        }
      }
    });

    test('corrige o nível de um escore inflado', () {
      final rng = math.Random(31);
      List<double> escores(int n, math.Random r) =>
          [for (var i = 0; i < n; i++) (r.nextDouble() * 0.5 * 2).clamp(0.0, 1.0)];

      // Janela de ajuste e janela de teste, ambas com o mesmo viés.
      final pAjuste = escores(6000, rng);
      final yAjuste = [
        for (final p in pAjuste) rng.nextDouble() < p / 2 ? 1 : 0,
      ];
      final pTeste = escores(6000, rng);
      final yTeste = [
        for (final p in pTeste) rng.nextDouble() < p / 2 ? 1 : 0,
      ];

      final r = RiscoCalibracao.calibrarEAvaliar(
        previstoAjuste: pAjuste,
        observadoAjuste: yAjuste,
        previstoTeste: pTeste,
        observadoTeste: yTeste,
      );

      expect(r.antes.eceAceitavel, isFalse,
          reason: 'o escore chega inflado — é essa a razão de existir a etapa');
      expect(r.depois.ece, lessThan(r.antes.ece));
      expect(r.depois.eceAceitavel, isTrue);
      expect(r.depois.podeAlimentarFinanceiro, isTrue);
    });

    test('prende nas pontas em vez de extrapolar', () {
      final cal = CalibradorIsotonico.ajustar(
        [0.2, 0.4, 0.6, 0.8],
        [0, 0, 1, 1],
      );
      expect(cal.aplicar(0.0), cal.aplicar(0.1));
      expect(cal.aplicar(1.0), cal.aplicar(0.9));
      expect(cal.aplicar(-5), inInclusiveRange(0.0, 1.0));
      expect(cal.aplicar(5), inInclusiveRange(0.0, 1.0));
    });

    test('conjunto vazio devolve a identidade, não uma exceção', () {
      final cal = CalibradorIsotonico.ajustar(const [], const []);
      expect(cal.vazio, isTrue);
      expect(cal.aplicar(0.37), closeTo(0.37, 1e-12));
    });
  });

  group('PR-AUC', () {
    test('modelo sem informação fica na taxa-base', () {
      final rng = math.Random(41);
      const taxa = 0.2;
      final observado = [
        for (var i = 0; i < 20000; i++) rng.nextDouble() < taxa ? 1 : 0,
      ];
      final previsto = [for (var i = 0; i < 20000; i++) rng.nextDouble()];
      expect(RiscoCalibracao.prAuc(previsto, observado), closeTo(taxa, 0.02));
    });

    test('ordenação perfeita chega a 1', () {
      final observado = [for (var i = 0; i < 1000; i++) i < 200 ? 1 : 0];
      final previsto = [
        for (var i = 0; i < 1000; i++) i < 200 ? 0.9 - i * 1e-4 : 0.1,
      ];
      expect(RiscoCalibracao.prAuc(previsto, observado), closeTo(1.0, 1e-6));
    });
  });
}
