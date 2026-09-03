import 'dart:math' as math;

/// Amostradores que o `dart:math` não traz e a simulação de 12 meses precisa.
///
/// A propagação de incerteza da especificação usa três distribuições que não
/// existem na biblioteca padrão: **lognormal** (incerteza do forecast),
/// **Beta** (incerteza do parâmetro) e **multinomial** (incerteza amostral).
/// Sem elas o intervalo declarado como 90% cobre ~46% dos futuros — que é
/// exatamente o defeito D1 corrigido nesta versão.
class Amostradores {
  Amostradores(int seed) : _rng = math.Random(seed);

  final math.Random _rng;
  double? _reservaNormal;

  double uniforme() => _rng.nextDouble();

  /// Normal padrão pelo método polar de Marsaglia, guardando o par.
  double normal() {
    final r = _reservaNormal;
    if (r != null) {
      _reservaNormal = null;
      return r;
    }
    double u, v, s;
    do {
      u = _rng.nextDouble() * 2 - 1;
      v = _rng.nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);
    final f = math.sqrt(-2 * math.log(s) / s);
    _reservaNormal = v * f;
    return u * f;
  }

  /// Lognormal com **média igual a [media]**.
  ///
  /// A correção `-sigma²/2` no parâmetro de locação é o que mantém a média no
  /// valor pedido; sem ela a simulação inteira fica enviesada para cima. A
  /// lognormal é a escolha certa para o forecast porque preserva positividade:
  /// número de agendamentos não pode ser negativo, e uma normal simétrica
  /// produziria valores negativos na cauda para clínicas de baixo volume.
  double lognormalComMedia(double media, double wape) {
    if (media <= 0) return 0;
    final sigma = math.sqrt(math.log(1 + wape * wape));
    final mu = math.log(media) - sigma * sigma / 2;
    return math.exp(mu + sigma * normal());
  }

  /// Gamma(forma, 1) — método de Marsaglia e Tsang.
  double gamma(double forma) {
    if (forma <= 0) return 0;
    if (forma < 1) {
      // Impulso de Johnk/Best para forma < 1.
      final u = _rng.nextDouble();
      return gamma(forma + 1) * math.pow(u, 1 / forma).toDouble();
    }
    final d = forma - 1.0 / 3.0;
    final c = 1.0 / math.sqrt(9 * d);
    while (true) {
      double x, v;
      do {
        x = normal();
        v = 1 + c * x;
      } while (v <= 0);
      v = v * v * v;
      final u = _rng.nextDouble();
      final x2 = x * x;
      if (u < 1 - 0.0331 * x2 * x2) return d * v;
      if (math.log(u) < 0.5 * x2 + d * (1 - v + math.log(v))) return d * v;
    }
  }

  /// Beta(a, b) via razão de duas Gamma.
  ///
  /// É a posterior de uma taxa observada: `a = p·n`, `b = (1−p)·n`, com `n` o
  /// número de desfechos que sustentam a estimativa. Uma taxa de 22% medida em
  /// 80 casos e a mesma taxa medida em 8.000 produzem intervalos muito
  /// diferentes — tratar as duas como constante conhecida é o defeito D1.
  double beta(double a, double b) {
    if (a <= 0) return 0;
    if (b <= 0) return 1;
    final x = gamma(a);
    final y = gamma(b);
    final s = x + y;
    return s <= 0 ? 0.5 : x / s;
  }

  /// Binomial(n, p) sorteando o próprio desvio normal.
  int binomial(int n, double p) => binomialComZ(n, p, normal());

  /// Binomial(n, p) a partir de um desvio normal **já sorteado**.
  ///
  /// Receber `z` de fora é o que torna possível usar **números aleatórios
  /// comuns** entre dois cenários: A e B veem o mesmo choque e a diferença
  /// entre eles deixa de ser dominada pelo ruído do gerador. Sem isso, comparar
  /// dois cenários exige uma amostra muito maior para enxergar o mesmo efeito.
  ///
  /// O critério de troca é a **variância**, não `n`: a aproximação normal só
  /// vale quando `n·p·(1−p)` é razoável. Usar `n ≥ 60` sozinho quebra a
  /// marginal quando `p` é pequeno — o arredondamento acumula massa no zero e
  /// puxa a média para cima. Abaixo do limiar o sorteio é exato, por inversão
  /// da acumulada com o uniforme derivado do mesmo `z`, o que preserva o
  /// pareamento entre cenários também nesse ramo.
  int binomialComZ(int n, double p, double z) {
    if (n <= 0) return 0;
    final pc = p.clamp(0.0, 1.0);
    if (pc <= 0) return 0;
    if (pc >= 1) return n;

    final variancia = n * pc * (1 - pc);
    if (variancia < 9) return _binomialInversa(n, pc, phi(z));

    // `round` é a correção de continuidade: o valor inteiro k representa o
    // intervalo [k−½, k+½) da normal contínua.
    final v = (n * pc + math.sqrt(variancia) * z).round();
    return v < 0 ? 0 : (v > n ? n : v);
  }

  /// Inversão da acumulada binomial. Monótona em `u` e em `p`, que é a
  /// propriedade que sustenta o pareamento.
  int _binomialInversa(int n, double p, double u) {
    final q = 1 - p;
    var termo = math.pow(q, n).toDouble();
    var acumulado = termo;
    var k = 0;
    while (acumulado < u && k < n) {
      termo *= (n - k) / (k + 1) * (p / q);
      acumulado += termo;
      k++;
    }
    return k;
  }

  /// Acumulada da normal padrão — a ponte entre um desvio normal e o uniforme
  /// equivalente.
  static double phi(double z) => 0.5 * (1 + _erf(z / math.sqrt2));

  /// Função erro, aproximação de Abramowitz e Stegun 7.1.26.
  static double _erf(double x) {
    final sinal = x < 0 ? -1.0 : 1.0;
    final z = x.abs();
    const c = 0.3275911;
    const a = [0.254829592, -0.284496736, 1.421413741, -1.453152027, 1.061405429];
    final t = 1.0 / (1.0 + c * z);
    var soma = 0.0;
    var potencia = t;
    for (final coef in a) {
      soma += coef * potencia;
      potencia *= t;
    }
    return sinal * (1 - soma * math.exp(-z * z));
  }

  /// Multinomial: reparte [n] entre as categorias de [probs].
  ///
  /// Feito por binomiais condicionais sucessivas, o que **garante por
  /// construção** que a soma das categorias é exatamente `n`. Era o defeito D2:
  /// sortear falta sobre o total e cancelamento sobre o resíduo faz a taxa de
  /// cancelamento pedida de 10% se realizar como 7,8%.
  List<int> multinomial(int n, List<double> probs) {
    final k = probs.length;
    final out = List<int>.filled(k, 0);
    if (n <= 0 || k == 0) return out;

    var restante = n;
    var restanteProb = probs.fold(0.0, (s, p) => s + math.max(0.0, p));
    if (restanteProb <= 0) {
      out[0] = n;
      return out;
    }

    for (var i = 0; i < k - 1 && restante > 0; i++) {
      final p = math.max(0.0, probs[i]);
      final condicional = (p / restanteProb).clamp(0.0, 1.0);
      final x = binomial(restante, condicional);
      out[i] = x;
      restante -= x;
      restanteProb -= p;
      if (restanteProb <= 0) break;
    }
    out[k - 1] += restante;
    return out;
  }

  /// Multinomial com desvios normais **já sorteados**, um por categoria menos
  /// uma.
  ///
  /// Mesma decomposição condicional de [multinomial] — e portanto a mesma
  /// garantia de soma exata —, só que alimentada por choques de fora. É o que
  /// permite rodar baseline e cenário de intervenção sobre o mesmo mundo
  /// sorteado, com as taxas sendo a única diferença entre os dois.
  List<int> multinomialComZ(int n, List<double> probs, List<double> zs) {
    final k = probs.length;
    final out = List<int>.filled(k, 0);
    if (n <= 0 || k == 0) return out;

    var restante = n;
    var restanteProb = probs.fold(0.0, (s, p) => s + math.max(0.0, p));
    if (restanteProb <= 0) {
      out[0] = n;
      return out;
    }

    for (var i = 0; i < k - 1 && restante > 0; i++) {
      final p = math.max(0.0, probs[i]);
      final condicional = (p / restanteProb).clamp(0.0, 1.0);
      final x = binomialComZ(restante, condicional, zs[i % zs.length]);
      out[i] = x;
      restante -= x;
      restanteProb -= p;
      if (restanteProb <= 0) break;
    }
    out[k - 1] += restante;
    return out;
  }

  /// Lognormal do forecast com o erro **decomposto** em nível e mês.
  ///
  /// O erro de previsão não é independente mês a mês. Uma parte dele é de
  /// **nível** — a série inteira calibrada para o patamar errado, mudança de
  /// mix, tendência não capturada — e persiste por todo o horizonte; a outra é
  /// idiossincrática do mês. Sortear tudo como idiossincrático faz o erro do
  /// total anual valer `WAPE/√12`, isto é, a banda de 12 meses sai 3,46× mais
  /// estreita do que o próprio WAPE declarado do modelo permite afirmar.
  ///
  /// [rho] é a fração da **variância** que persiste ao longo do horizonte.
  /// Passe [zNivel] uma única vez por replicação e [zMes] a cada mês.
  double lognormalDecomposta(
    double media,
    double wape,
    double rho,
    double zNivel,
    double zMes,
  ) {
    if (media <= 0) return 0;
    final sigma = math.sqrt(math.log(1 + wape * wape));
    final r = rho.clamp(0.0, 1.0);
    final mu = math.log(media) - sigma * sigma / 2;
    return math.exp(mu +
        sigma * (math.sqrt(r) * zNivel + math.sqrt(1 - r) * zMes));
  }
}

/// Percentis de uma amostra já ordenável.
class Percentis {
  const Percentis({required this.p05, required this.p50, required this.p95});

  final num p05;
  final num p50;
  final num p95;

  /// Largura do intervalo — a medida que o defeito D1 estreitava indevidamente.
  num get largura => p95 - p05;

  static Percentis de(List<num> amostra) {
    if (amostra.isEmpty) return const Percentis(p05: 0, p50: 0, p95: 0);
    final ord = [...amostra]..sort();
    num q(double f) {
      final i = ((ord.length - 1) * f).round().clamp(0, ord.length - 1);
      return ord[i];
    }

    return Percentis(p05: q(0.05), p50: q(0.50), p95: q(0.95));
  }

  Map<String, num> toMap() => {'p05': p05, 'p50': p50, 'p95': p95};
}
