import 'dart:math' as math;

import 'monte_carlo_models.dart';

/// Métricas de qualidade de uma previsão **distribucional**.
///
/// Erro médio absoluto não serve aqui. O simulador não entrega um número, e sim
/// uma distribuição inteira; uma previsão pode acertar a média e mentir na
/// cauda — que é exatamente onde a decisão de overbooking mora. CRPS e pinball
/// medem a distribuição; cobertura mede se o intervalo declarado é honesto.
class MonteCarloMetrics {
  const MonteCarloMetrics._();

  /// **CRPS** (Continuous Ranked Probability Score) para previsão discreta.
  ///
  /// `CRPS = soma_k (F(k) - 1{k >= y})²`, onde `F` é a acumulada prevista e `y`
  /// o valor observado. Menor é melhor; zero só com previsão determinística
  /// perfeita. Generaliza o erro absoluto: se a previsão colapsar num ponto,
  /// o CRPS vira |previsto - observado|.
  static double crps(Distribuicao previsao, int observado) {
    if (previsao.total == 0) return double.nan;
    final n = math.max(previsao.contagens.length, observado + 1);
    var soma = 0.0;
    for (var k = 0; k < n; k++) {
      final f = previsao.cdf(k);
      final ind = k >= observado ? 1.0 : 0.0;
      final d = f - ind;
      soma += d * d;
    }
    return soma;
  }

  /// **Pinball loss** no quantil [q] — a perda que penaliza assimetricamente
  /// errar para cima e para baixo.
  ///
  /// É a métrica certa para o P95 de overbooking: subestimar a cauda (e lotar a
  /// sala) custa diferente de superestimar (e deixar cadeira vazia).
  static double pinball(int previsto, int observado, double q) {
    final d = observado - previsto;
    return d >= 0 ? q * d : (q - 1) * d;
  }

  /// Pinball no quantil [q] lido diretamente da distribuição.
  static double pinballDe(Distribuicao previsao, int observado, double q) =>
      pinball(previsao.quantil(q), observado, q);

  /// Cobertura empírica de um intervalo central: fração das observações que
  /// caíram dentro de `[quantil(inferior), quantil(superior)]`.
  ///
  /// Um intervalo de 90% que cobre 62% das observações não é conservador — é
  /// falso, e é assim que o modelo independente falha.
  static double cobertura(
    List<Distribuicao> previsoes,
    List<int> observados, {
    double inferior = 0.05,
    double superior = 0.95,
  }) {
    if (previsoes.isEmpty || previsoes.length != observados.length) {
      return double.nan;
    }
    var dentro = 0;
    for (var i = 0; i < previsoes.length; i++) {
      final lo = previsoes[i].quantil(inferior);
      final hi = previsoes[i].quantil(superior);
      final y = observados[i];
      if (y >= lo && y <= hi) dentro++;
    }
    return dentro / previsoes.length;
  }

  /// **PIT** (Probability Integral Transform) de uma observação.
  ///
  /// Se o modelo estiver bem calibrado, os PIT de muitas observações são
  /// aproximadamente uniformes em [0,1]. Concentração no meio indica previsão
  /// larga demais; nas pontas, estreita demais.
  ///
  /// Usa a versão randomizada para variáveis discretas, com o ponto médio do
  /// salto — evita o viés sistemático da versão ingênua.
  static double pit(Distribuicao previsao, int observado) {
    if (previsao.total == 0) return double.nan;
    final anterior = observado > 0 ? previsao.cdf(observado - 1) : 0.0;
    final atual = previsao.cdf(observado);
    return (anterior + atual) / 2;
  }

  /// **ECE** (Expected Calibration Error) sobre os PIT.
  ///
  /// Divide [0,1] em `bins` faixas e mede o desvio médio entre a frequência
  /// observada em cada faixa e a frequência uniforme esperada. Zero = calibrado.
  static double ece(
    List<Distribuicao> previsoes,
    List<int> observados, {
    int bins = 10,
  }) {
    if (previsoes.isEmpty || previsoes.length != observados.length) {
      return double.nan;
    }
    final cont = List<int>.filled(bins, 0);
    for (var i = 0; i < previsoes.length; i++) {
      final u = pit(previsoes[i], observados[i]);
      if (u.isNaN) continue;
      var b = (u * bins).floor();
      if (b < 0) b = 0;
      if (b >= bins) b = bins - 1;
      cont[b]++;
    }
    final n = previsoes.length;
    final esperado = 1.0 / bins;
    var soma = 0.0;
    for (final c in cont) {
      soma += (c / n - esperado).abs();
    }
    return soma / bins;
  }

  /// Resumo completo de um backtest.
  static AvaliacaoDistribucional avaliar(
    List<Distribuicao> previsoes,
    List<int> observados,
  ) {
    if (previsoes.isEmpty || previsoes.length != observados.length) {
      return AvaliacaoDistribucional.vazia;
    }
    var somaCrps = 0.0;
    var somaP50 = 0.0;
    var somaP95 = 0.0;
    for (var i = 0; i < previsoes.length; i++) {
      somaCrps += crps(previsoes[i], observados[i]);
      somaP50 += pinballDe(previsoes[i], observados[i], 0.50);
      somaP95 += pinballDe(previsoes[i], observados[i], 0.95);
    }
    final n = previsoes.length;
    return AvaliacaoDistribucional(
      amostras: n,
      crpsMedio: somaCrps / n,
      pinballP50: somaP50 / n,
      pinballP95: somaP95 / n,
      cobertura90: cobertura(previsoes, observados),
      ece: ece(previsoes, observados),
    );
  }
}

/// Resultado de um backtest distribucional.
class AvaliacaoDistribucional {
  const AvaliacaoDistribucional({
    required this.amostras,
    required this.crpsMedio,
    required this.pinballP50,
    required this.pinballP95,
    required this.cobertura90,
    required this.ece,
  });

  final int amostras;
  final double crpsMedio;
  final double pinballP50;
  final double pinballP95;

  /// Fração de dias em que o observado caiu dentro do intervalo P05–P95.
  /// Deveria ficar perto de 0,90.
  final double cobertura90;

  final double ece;

  static const AvaliacaoDistribucional vazia = AvaliacaoDistribucional(
    amostras: 0,
    crpsMedio: double.nan,
    pinballP50: double.nan,
    pinballP95: double.nan,
    cobertura90: double.nan,
    ece: double.nan,
  );

  /// Critério de saída da fase F2: cobertura dentro de ±5 pontos do nominal.
  bool get coberturaAceitavel =>
      !cobertura90.isNaN && (cobertura90 - 0.90).abs() <= 0.05;

  bool get temAmostras => amostras > 0;
}
