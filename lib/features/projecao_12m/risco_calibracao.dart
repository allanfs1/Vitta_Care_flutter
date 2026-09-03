/// Calibração do escore de risco de falta — sem ela o escore não pode
/// alimentar receita.
///
/// AUC mede **ordenação**. Um modelo pode ordenar perfeitamente e ainda dizer
/// "40%" onde a taxa real é 22%. Como o motor de cenários multiplica esse
/// escore por valor de consulta, um escore descalibrado contamina toda a
/// projeção financeira: ordenar bem serve para priorizar a fila, projetar
/// faturamento exige **probabilidade calibrada**.
///
/// Na prática o primeiro sinal de que um modelo de risco envelheceu não é a
/// queda do PR-AUC — é o ECE subindo. O modelo continua ordenando bem e já
/// erra o nível. Monitorar só ordenação deixa passar meses de projeção
/// enviesada.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Uma faixa da curva de confiabilidade: o que o modelo prometeu × o que
/// aconteceu.
@immutable
class FaixaConfiabilidade {
  const FaixaConfiabilidade({
    required this.inicio,
    required this.fim,
    required this.n,
    required this.confiancaMedia,
    required this.frequenciaReal,
  });

  final double inicio;
  final double fim;

  /// Quantas observações caíram nesta faixa.
  final int n;

  /// Média do escore previsto na faixa.
  final double confiancaMedia;

  /// Fração que de fato faltou.
  final double frequenciaReal;

  /// Positivo = o modelo promete mais risco do que se realiza.
  double get desvio => confiancaMedia - frequenciaReal;
}

/// Diagnóstico de calibração de um conjunto de escores.
@immutable
class DiagnosticoCalibracao {
  const DiagnosticoCalibracao({
    required this.n,
    required this.ece,
    required this.brier,
    required this.brierTaxaBase,
    required this.taxaBase,
    required this.escoreMedio,
    required this.faixas,
    this.limiteEce = 0.03,
  });

  final int n;

  /// Expected Calibration Error — erro médio entre confiança e frequência.
  final double ece;

  /// Brier score do modelo.
  final double brier;

  /// Brier de um modelo trivial que sempre responde a taxa-base. É o piso que
  /// o modelo precisa bater: se não bater, o escore não acrescenta informação.
  final double brierTaxaBase;

  final double taxaBase;
  final double escoreMedio;

  final List<FaixaConfiabilidade> faixas;

  /// Critério de aceite antes de conectar o escore ao motor financeiro.
  final double limiteEce;

  bool get eceAceitavel => ece <= limiteEce;

  bool get brierMelhorQueTaxaBase => brier < brierTaxaBase;

  /// Só um escore que passa nos dois critérios pode multiplicar dinheiro.
  bool get podeAlimentarFinanceiro => eceAceitavel && brierMelhorQueTaxaBase;

  /// Ganho relativo de Brier sobre o modelo trivial (Brier skill score).
  double get ganhoSobreTaxaBase =>
      brierTaxaBase <= 0 ? 0 : 1 - brier / brierTaxaBase;

  /// Viés global: o modelo promete mais risco do que se realiza?
  double get vies => escoreMedio - taxaBase;

  String get veredito {
    if (podeAlimentarFinanceiro) {
      return 'Escore calibrado (ECE ${ece.toStringAsFixed(3)} ≤ '
          '${limiteEce.toStringAsFixed(2)}) e melhor que a taxa-base. Pode '
          'alimentar a projeção financeira.';
    }
    if (!eceAceitavel && !brierMelhorQueTaxaBase) {
      return 'Escore descalibrado (ECE ${ece.toStringAsFixed(3)}) e sem ganho '
          'sobre a taxa-base. Não conecte ao financeiro: use a taxa histórica.';
    }
    if (!eceAceitavel) {
      return 'Escore ordena melhor que a taxa-base, mas erra o nível '
          '(ECE ${ece.toStringAsFixed(3)} > ${limiteEce.toStringAsFixed(2)}). '
          'Serve para priorizar a fila, não para projetar faturamento — '
          'recalibre antes.';
    }
    return 'Escore calibrado, porém sem ganho de Brier sobre a taxa-base: '
        'ele acerta o nível médio e não distingue os casos.';
  }

  static const DiagnosticoCalibracao vazio = DiagnosticoCalibracao(
    n: 0,
    ece: 0,
    brier: 0,
    brierTaxaBase: 0,
    taxaBase: 0,
    escoreMedio: 0,
    faixas: [],
  );
}

/// Regressão isotônica ajustada por *pool adjacent violators*.
///
/// É a etapa obrigatória depois do AutoML: ajusta a calibração numa janela
/// temporal **posterior** ao treino. Calibrar na própria janela de treino
/// devolve um número bonito e um modelo que erra o nível em produção.
///
/// A função ajustada é monótona não-decrescente, o que preserva a ordenação do
/// modelo original — recalibrar nunca piora a fila de prioridade, só corrige o
/// nível.
@immutable
class CalibradorIsotonico {
  const CalibradorIsotonico._(this._x, this._y);

  final List<double> _x;
  final List<double> _y;

  bool get vazio => _x.isEmpty;

  int get pontos => _x.length;

  /// Ajusta sobre pares (escore previsto, desfecho observado 0/1).
  ///
  /// [pesos] permite agregar observações idênticas; quando omitido cada par
  /// pesa 1.
  static CalibradorIsotonico ajustar(
    List<double> previsto,
    List<num> observado, {
    List<double>? pesos,
  }) {
    final n = math.min(previsto.length, observado.length);
    if (n == 0) return const CalibradorIsotonico._([], []);

    final idx = List<int>.generate(n, (i) => i)
      ..sort((a, b) => previsto[a].compareTo(previsto[b]));

    // Blocos do PAV. Como os pontos entram em ordem crescente de x, o x do
    // bloco é sempre o do último ponto absorvido — o maior dele.
    final xBloco = <double>[];
    final somaBloco = <double>[];
    final pesoBloco = <double>[];

    for (final i in idx) {
      final x = previsto[i];
      var peso = pesos?[i] ?? 1.0;
      var soma = observado[i].toDouble() * peso;

      // Enquanto o bloco anterior tiver média maior, a monotonia está violada:
      // funde os dois e repete, que é exatamente o *pool adjacent violators*.
      while (xBloco.isNotEmpty &&
          somaBloco.last / pesoBloco.last >= soma / peso) {
        soma += somaBloco.removeLast();
        peso += pesoBloco.removeLast();
        xBloco.removeLast();
      }
      xBloco.add(x);
      somaBloco.add(soma);
      pesoBloco.add(peso);
    }

    return CalibradorIsotonico._(
      xBloco,
      [
        for (var b = 0; b < xBloco.length; b++)
          (somaBloco[b] / pesoBloco[b]).clamp(0.0, 1.0),
      ],
    );
  }

  /// Aplica a calibração. Fora do intervalo ajustado, prende nas pontas —
  /// extrapolar uma isotônica inventa probabilidade onde não houve observação.
  double aplicar(double p) {
    if (_x.isEmpty) return p.clamp(0.0, 1.0);
    if (p <= _x.first) return _y.first;
    if (p >= _x.last) return _y.last;

    // Busca binária pelo intervalo que contém p.
    var lo = 0;
    var hi = _x.length - 1;
    while (hi - lo > 1) {
      final meio = (lo + hi) ~/ 2;
      if (_x[meio] <= p) {
        lo = meio;
      } else {
        hi = meio;
      }
    }
    final dx = _x[hi] - _x[lo];
    if (dx <= 0) return _y[hi];
    final t = (p - _x[lo]) / dx;
    return (_y[lo] + t * (_y[hi] - _y[lo])).clamp(0.0, 1.0);
  }

  List<double> aplicarTodos(List<double> ps) =>
      [for (final p in ps) aplicar(p)];
}

/// Métricas de calibração e o portão que libera o escore para o financeiro.
class RiscoCalibracao {
  const RiscoCalibracao._();

  /// Expected Calibration Error — média ponderada de |confiança − frequência|.
  ///
  /// A faixa final é fechada à direita para que escores exatamente iguais a 1
  /// contem. Descartá-los tiraria da conta justamente as previsões mais
  /// confiantes, que é onde um erro de calibração custa mais caro.
  static double ece(
    List<double> previsto,
    List<num> observado, {
    int nFaixas = 10,
  }) {
    final f = faixas(previsto, observado, nFaixas: nFaixas);
    final n = math.min(previsto.length, observado.length);
    if (n == 0) return 0;
    var erro = 0.0;
    for (final b in f) {
      erro += (b.n / n) * (b.confiancaMedia - b.frequenciaReal).abs();
    }
    return erro;
  }

  /// Brier score — erro quadrático médio da probabilidade.
  static double brier(List<double> previsto, List<num> observado) {
    final n = math.min(previsto.length, observado.length);
    if (n == 0) return 0;
    var soma = 0.0;
    for (var i = 0; i < n; i++) {
      final d = previsto[i] - observado[i].toDouble();
      soma += d * d;
    }
    return soma / n;
  }

  /// Curva de confiabilidade em faixas de largura igual.
  static List<FaixaConfiabilidade> faixas(
    List<double> previsto,
    List<num> observado, {
    int nFaixas = 10,
  }) {
    final n = math.min(previsto.length, observado.length);
    if (n == 0 || nFaixas <= 0) return const [];

    final contagem = List<int>.filled(nFaixas, 0);
    final somaP = List<double>.filled(nFaixas, 0);
    final somaY = List<double>.filled(nFaixas, 0);

    for (var i = 0; i < n; i++) {
      final p = previsto[i].clamp(0.0, 1.0);
      final b = math.min((p * nFaixas).floor(), nFaixas - 1);
      contagem[b]++;
      somaP[b] += p;
      somaY[b] += observado[i].toDouble();
    }

    return [
      for (var b = 0; b < nFaixas; b++)
        if (contagem[b] > 0)
          FaixaConfiabilidade(
            inicio: b / nFaixas,
            fim: (b + 1) / nFaixas,
            n: contagem[b],
            confiancaMedia: somaP[b] / contagem[b],
            frequenciaReal: somaY[b] / contagem[b],
          ),
    ];
  }

  /// Diagnóstico completo, com o piso da taxa-base já calculado.
  static DiagnosticoCalibracao diagnosticar(
    List<double> previsto,
    List<num> observado, {
    int nFaixas = 10,
    double limiteEce = 0.03,
  }) {
    final n = math.min(previsto.length, observado.length);
    if (n == 0) return DiagnosticoCalibracao.vazio;

    var somaY = 0.0;
    var somaP = 0.0;
    for (var i = 0; i < n; i++) {
      somaY += observado[i].toDouble();
      somaP += previsto[i];
    }
    final taxaBase = somaY / n;

    return DiagnosticoCalibracao(
      n: n,
      ece: ece(previsto, observado, nFaixas: nFaixas),
      brier: brier(previsto, observado),
      brierTaxaBase:
          brier(List<double>.filled(n, taxaBase), observado.take(n).toList()),
      taxaBase: taxaBase,
      escoreMedio: somaP / n,
      faixas: faixas(previsto, observado, nFaixas: nFaixas),
      limiteEce: limiteEce,
    );
  }

  /// Ajusta a isotônica numa janela e mede o efeito na mesma janela de
  /// aplicação — o par (antes, depois) que justifica a etapa de calibração.
  ///
  /// [previstoAjuste]/[observadoAjuste] devem vir de uma janela temporal
  /// **posterior** ao treino do modelo e **anterior** à janela de aplicação.
  static ({
    CalibradorIsotonico calibrador,
    DiagnosticoCalibracao antes,
    DiagnosticoCalibracao depois,
  }) calibrarEAvaliar({
    required List<double> previstoAjuste,
    required List<num> observadoAjuste,
    required List<double> previstoTeste,
    required List<num> observadoTeste,
    int nFaixas = 10,
    double limiteEce = 0.03,
  }) {
    final cal = CalibradorIsotonico.ajustar(previstoAjuste, observadoAjuste);
    return (
      calibrador: cal,
      antes: diagnosticar(previstoTeste, observadoTeste,
          nFaixas: nFaixas, limiteEce: limiteEce),
      depois: diagnosticar(cal.aplicarTodos(previstoTeste), observadoTeste,
          nFaixas: nFaixas, limiteEce: limiteEce),
    );
  }

  /// PR-AUC — precisão média, métrica primária quando o evento é minoritário.
  ///
  /// A ROC-AUC de um evento raro parece boa mesmo quando o modelo é inútil na
  /// faixa que interessa; a PR-AUC não perdoa isso. O piso de comparação é a
  /// própria taxa-base: um modelo sem informação tem PR-AUC igual a ela.
  static double prAuc(List<double> previsto, List<num> observado) {
    final n = math.min(previsto.length, observado.length);
    if (n == 0) return 0;

    final idx = List<int>.generate(n, (i) => i)
      ..sort((a, b) => previsto[b].compareTo(previsto[a]));

    final positivos = observado.take(n).fold<double>(
        0, (a, b) => a + (b.toDouble() > 0.5 ? 1 : 0));
    if (positivos == 0) return 0;

    var tp = 0.0;
    var fp = 0.0;
    var soma = 0.0;
    for (var k = 0; k < n; k++) {
      if (observado[idx[k]].toDouble() > 0.5) {
        tp++;
        soma += tp / (tp + fp + 1e-12); // precisão no ponto de cada acerto
      } else {
        fp++;
      }
    }
    return soma / positivos;
  }
}
