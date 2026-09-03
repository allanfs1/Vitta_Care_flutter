/// Poder estatístico do piloto — quantos agendamentos são necessários para que
/// o resultado signifique alguma coisa.
///
/// "Comparar com grupo de controle" só produz conclusão se a amostra for
/// suficiente para detectar o efeito procurado. Um piloto subdimensionado
/// termina com um resultado não-significativo que **não distingue "não
/// funciona" de "não medimos o bastante"** — e essa ambiguidade é fatal para a
/// conversa comercial, porque o cliente lembra do número prometido e não do
/// intervalo de confiança.
///
/// Este arquivo existe para que o N seja calculado **antes** de começar, nunca
/// depois de terminar.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Resultado do dimensionamento para uma redução relativa buscada.
@immutable
class DimensionamentoPiloto {
  const DimensionamentoPiloto({
    required this.reducaoRelativa,
    required this.taxaBase,
    required this.taxaEsperada,
    required this.nPorBraco,
    required this.alfa,
    required this.poder,
  });

  /// Redução relativa da taxa de falta que se quer detectar (0,20 = −20%).
  final double reducaoRelativa;

  /// Taxa de falta observada hoje, ponto de partida do cálculo.
  final double taxaBase;

  /// Taxa que o braço tratado teria se o efeito buscado for real.
  final double taxaEsperada;

  /// Agendamentos necessários **em cada braço**.
  final int nPorBraco;

  final double alfa;
  final double poder;

  int get nTotal => nPorBraco * 2;

  /// Meses de piloto a um dado volume mensal, considerando os dois braços.
  double mesesPara(int agendamentosPorMes) =>
      agendamentosPorMes <= 0 ? double.infinity : nTotal / agendamentosPorMes;
}

/// Veredito sobre a viabilidade de um piloto concreto.
@immutable
class ViabilidadePiloto {
  const ViabilidadePiloto({
    required this.dimensionamento,
    required this.agendamentosPorMes,
    required this.mesesDisponiveis,
    required this.mesesNecessarios,
  });

  final DimensionamentoPiloto dimensionamento;
  final int agendamentosPorMes;
  final double mesesDisponiveis;
  final double mesesNecessarios;

  bool get viavel => mesesNecessarios <= mesesDisponiveis;

  /// Menor redução que o piloto consegue provar no prazo disponível — a
  /// pergunta honesta quando o efeito buscado não cabe na janela.
  ///
  /// Devolve `null` quando nem a redução mais grosseira cabe: nesse caso o
  /// piloto não é de eficácia, e insistir produz o resultado ambíguo que a
  /// seção 16 existe para evitar.
  double? get menorReducaoDetectavel {
    for (var r = 0.05; r <= 0.80; r += 0.01) {
      final d = PoderPiloto.dimensionar(
        reducaoRelativa: r,
        taxaBase: dimensionamento.taxaBase,
        alfa: dimensionamento.alfa,
        poder: dimensionamento.poder,
      );
      if (d.mesesPara(agendamentosPorMes) <= mesesDisponiveis) return r;
    }
    return null;
  }

  /// O que dizer quando o piloto não sustenta uma conclusão de eficácia.
  ///
  /// Duas saídas legítimas: agrupar clínicas pequenas num piloto multicêntrico,
  /// ou declarar desde o início que o piloto é de **viabilidade operacional**,
  /// medindo adesão e tempo de resposta em vez de redução de falta.
  String get recomendacao {
    if (viavel) {
      return 'O piloto detecta uma redução de '
          '${(dimensionamento.reducaoRelativa * 100).round()}% em '
          '${mesesNecessarios.toStringAsFixed(1)} meses, dentro dos '
          '${mesesDisponiveis.toStringAsFixed(1)} disponíveis.';
    }
    final menor = menorReducaoDetectavel;
    if (menor != null) {
      return 'Nesta janela o piloto só prova reduções a partir de '
          '${(menor * 100).round()}%. Para o efeito buscado seriam '
          '${mesesNecessarios.toStringAsFixed(1)} meses. Prometer evidência '
          'antes disso é prometer o que a estatística não entrega.';
    }
    return 'Este volume não sustenta um piloto de eficácia na janela dada. '
        'Duas saídas legítimas: agrupar várias clínicas num piloto '
        'multicêntrico, ou declarar desde o início que o piloto é de '
        'viabilidade operacional — medindo adesão e tempo de resposta, não '
        'redução de falta.';
  }
}

/// Cálculo de tamanho de amostra para o piloto da Agenda Clínica.
class PoderPiloto {
  const PoderPiloto._();

  /// Reduções relativas apresentadas na tabela de referência.
  static const List<double> reducoesPadrao = [0.10, 0.15, 0.20, 0.30, 0.40];

  /// Volumes mensais típicos, do consultório à rede.
  static const List<int> volumesPadrao = [400, 800, 1200, 2000];

  /// Tamanho de amostra por braço — teste bilateral de duas proporções.
  ///
  /// Usa a variância **agrupada** sob a hipótese nula no termo de α e a
  /// variância separada no termo de poder, que é a forma padrão do cálculo e a
  /// que reproduz a tabela da especificação: 5.361 / 2.336 / 1.287 / 547 / 293
  /// por braço para reduções de 10/15/20/30/40% partindo de 22% de falta.
  ///
  /// O arredondamento é para cima: meio agendamento não existe, e arredondar
  /// para baixo entrega um piloto que fica logo abaixo do poder pedido.
  static DimensionamentoPiloto dimensionar({
    required double reducaoRelativa,
    double taxaBase = 0.22,
    double alfa = 0.05,
    double poder = 0.80,
  }) {
    final p1 = taxaBase.clamp(1e-6, 1 - 1e-6);
    final p2 = (p1 * (1 - reducaoRelativa.clamp(0.0, 1.0)))
        .clamp(1e-6, 1 - 1e-6)
        .toDouble();

    final delta = (p1 - p2).abs();
    if (delta < 1e-9) {
      return DimensionamentoPiloto(
        reducaoRelativa: reducaoRelativa,
        taxaBase: p1.toDouble(),
        taxaEsperada: p2,
        nPorBraco: 1 << 30, // efeito nulo não é detectável a nenhum custo
        alfa: alfa,
        poder: poder,
      );
    }

    final zAlfa = probit(1 - alfa / 2);
    final zBeta = probit(poder);
    final pBarra = (p1 + p2) / 2;

    final termoNulo = zAlfa * math.sqrt(2 * pBarra * (1 - pBarra));
    final termoAlt =
        zBeta * math.sqrt(p1 * (1 - p1) + p2 * (1 - p2));
    final n = math.pow(termoNulo + termoAlt, 2) / (delta * delta);

    return DimensionamentoPiloto(
      reducaoRelativa: reducaoRelativa,
      taxaBase: p1.toDouble(),
      taxaEsperada: p2,
      nPorBraco: n.ceil(),
      alfa: alfa,
      poder: poder,
    );
  }

  /// Tabela de dimensionamento para as reduções pedidas.
  static List<DimensionamentoPiloto> tabela({
    List<double> reducoes = reducoesPadrao,
    double taxaBase = 0.22,
    double alfa = 0.05,
    double poder = 0.80,
  }) =>
      [
        for (final r in reducoes)
          dimensionar(
            reducaoRelativa: r,
            taxaBase: taxaBase,
            alfa: alfa,
            poder: poder,
          ),
      ];

  /// Avalia um piloto concreto: este volume, nesta janela, prova o efeito?
  static ViabilidadePiloto avaliar({
    required int agendamentosPorMes,
    required double mesesDisponiveis,
    double reducaoRelativa = 0.20,
    double taxaBase = 0.22,
    double alfa = 0.05,
    double poder = 0.80,
  }) {
    final d = dimensionar(
      reducaoRelativa: reducaoRelativa,
      taxaBase: taxaBase,
      alfa: alfa,
      poder: poder,
    );
    return ViabilidadePiloto(
      dimensionamento: d,
      agendamentosPorMes: agendamentosPorMes,
      mesesDisponiveis: mesesDisponiveis,
      mesesNecessarios: d.mesesPara(agendamentosPorMes),
    );
  }

  /// Quantil da normal padrão — aproximação racional de Acklam.
  ///
  /// `dart:math` não traz a inversa da normal, e ela é necessária para que α e
  /// poder sejam **parâmetros**, não constantes chumbadas. O erro relativo é da
  /// ordem de 1,15 × 10⁻⁹ — folgado para dimensionar amostra, e suficiente para
  /// reproduzir a tabela da especificação até a unidade.
  ///
  /// Não há passo de refinamento por Newton/Halley de propósito: ele exigiria
  /// uma acumulada normal, e as aproximações usuais dela erram na casa de
  /// 10⁻⁷ — refinar com elas **pioraria** o resultado em vez de melhorá-lo.
  static double probit(double p) {
    if (p <= 0) return double.negativeInfinity;
    if (p >= 1) return double.infinity;

    const a = [
      -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
      1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00,
    ];
    const b = [
      -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
      6.680131188771972e+01, -1.328068155288572e+01,
    ];
    const c = [
      -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
      -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00,
    ];
    const d = [
      7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
      3.754408661907416e+00,
    ];
    const pBaixo = 0.02425;
    const pAlto = 1 - pBaixo;

    double bruto;
    if (p < pBaixo) {
      final q = math.sqrt(-2 * math.log(p));
      bruto = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else if (p <= pAlto) {
      final q = p - 0.5;
      final r = q * q;
      bruto = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r +
              a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    } else {
      final q = math.sqrt(-2 * math.log(1 - p));
      bruto = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }

    return bruto;
  }
}
