/// Partida a frio — a clínica que ainda não tem histórico na plataforma.
///
/// Na venda esse é o caso mais comum, e é exatamente a situação em que nenhum
/// dos três modelos pode ser treinado. Sem uma resposta explícita, a
/// alternativa que sobra é inventar números.
///
/// O shrinkage hierárquico é a resposta técnica: com `n` pequeno o peso recai
/// sobre a matriz global do cohort e, à medida que a clínica acumula desfechos,
/// a estimativa migra suavemente para o comportamento próprio. Sem
/// descontinuidade, sem "ligar o modelo" num dia arbitrário, e com o intervalo
/// estreitando na medida em que a evidência realmente cresce.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'projecao_models.dart';

/// Quanto histórico a clínica tem na plataforma.
enum MaturidadeHistorico {
  semHistorico(
    'Sem histórico',
    possivel: 'Matriz global do cohort e faixas setoriais amplas. A simulação '
        'é ilustrativa, e precisa estar marcada como tal.',
    naoPrometer: 'Nenhuma projeção específica desta clínica.',
  ),
  ateTresMeses(
    '1 a 3 meses',
    possivel: 'Forecast por baseline sazonal do cohort; Markov com shrinkage '
        'forte.',
    naoPrometer: 'Nada com intervalo estreito — o P05–P95 será largo, e deve '
        'permanecer largo.',
  ),
  ateOnzeMeses(
    '4 a 11 meses',
    possivel: 'Forecast próprio, sem sazonalidade anual confiável. O risco '
        'individual começa a ser útil.',
    naoPrometer: 'Efeito sazonal de 12 meses.',
  ),
  completo(
    '12 meses ou mais',
    possivel: 'Pipeline completo: forecast sazonal, risco calibrado e Markov '
        'por segmento.',
    naoPrometer: '',
  );

  const MaturidadeHistorico(
    this.label, {
    required this.possivel,
    required this.naoPrometer,
  });

  final String label;

  /// O que dá para fazer com esse histórico.
  final String possivel;

  /// O que não se pode prometer — vazio quando não há restrição.
  final String naoPrometer;

  /// A projeção desta clínica é apenas ilustrativa?
  bool get apenasIlustrativa => this == MaturidadeHistorico.semHistorico;

  static MaturidadeHistorico de(int mesesDeHistorico) {
    if (mesesDeHistorico <= 0) return MaturidadeHistorico.semHistorico;
    if (mesesDeHistorico <= 3) return MaturidadeHistorico.ateTresMeses;
    if (mesesDeHistorico <= 11) return MaturidadeHistorico.ateOnzeMeses;
    return MaturidadeHistorico.completo;
  }
}

/// O que a maturidade do histórico implica para os parâmetros da simulação.
@immutable
class AjustePartidaAFrio {
  const AjustePartidaAFrio({
    required this.maturidade,
    required this.mesesDeHistorico,
    required this.desfechosObservados,
    required this.kShrinkage,
    required this.wapeSugerido,
    required this.nHistoricoEfetivo,
  });

  final MaturidadeHistorico maturidade;
  final int mesesDeHistorico;
  final int desfechosObservados;

  /// Força do shrinkage para a matriz global do cohort. Quanto menos histórico,
  /// maior — o global precisa dominar até a clínica falar por si.
  final double kShrinkage;

  /// WAPE que a projeção deve assumir enquanto não houver forecast próprio
  /// validado. Um erro de previsão pequeno é uma afirmação sobre a qualidade do
  /// modelo, e uma clínica sem histórico não tem modelo.
  final double wapeSugerido;

  /// Força do prior Beta: quantos desfechos sustentam de fato as taxas.
  ///
  /// Usar um `nHistorico` grande sem ter os desfechos correspondentes é a
  /// forma mais silenciosa de estreitar o intervalo indevidamente — a camada
  /// de parâmetro passa a afirmar uma precisão que não foi observada.
  final int nHistoricoEfetivo;

  /// Peso que a clínica tem contra o cohort, entre 0 e 1.
  double pesoDoSegmento(int nSegmento) =>
      nSegmento / (nSegmento + kShrinkage);

  /// Aplica os ajustes a uma configuração de projeção.
  ProjecaoConfig aplicar(ProjecaoConfig base) => base.copyWith(
        wapeForecast: math.max(base.wapeForecast, wapeSugerido),
        nHistorico: math.min(base.nHistorico, nHistoricoEfetivo),
      );

  String get resumo {
    final restricao = maturidade.naoPrometer.isEmpty
        ? ''
        : ' Não prometer: ${maturidade.naoPrometer}';
    return '${maturidade.label} — ${maturidade.possivel}$restricao';
  }
}

/// Traduz histórico observado em parâmetros defensáveis.
class PartidaAFrio {
  const PartidaAFrio._();

  /// `k` de referência: número de observações que dá peso 50/50 entre o
  /// segmento e o cohort quando o histórico já é maduro.
  static const double kMaduro = 50.0;

  /// Deriva os ajustes a partir do que a clínica de fato tem.
  ///
  /// [desfechosObservados] são agendamentos **já fechados** — compareceu,
  /// faltou, cancelou. Agendamento futuro não sustenta estimativa de taxa.
  static AjustePartidaAFrio avaliar({
    required int mesesDeHistorico,
    required int desfechosObservados,
    double wapeAlvo = 0.12,
  }) {
    final m = MaturidadeHistorico.de(mesesDeHistorico);
    final desfechos = math.max(0, desfechosObservados);

    // Quanto menos histórico, mais o cohort precisa dominar; e quanto mais
    // larga a incerteza declarada, mais honesta a faixa.
    final (k, fatorWape) = switch (m) {
      MaturidadeHistorico.semHistorico => (400.0, 2.5),
      MaturidadeHistorico.ateTresMeses => (200.0, 1.8),
      MaturidadeHistorico.ateOnzeMeses => (100.0, 1.3),
      MaturidadeHistorico.completo => (kMaduro, 1.0),
    };

    return AjustePartidaAFrio(
      maturidade: m,
      mesesDeHistorico: math.max(0, mesesDeHistorico),
      desfechosObservados: desfechos,
      kShrinkage: k,
      wapeSugerido: (wapeAlvo * fatorWape).clamp(0.0, 0.90),
      // O prior nunca pode ser mais forte que a evidência que existe. O piso de
      // 1 evita divisão por zero na Beta sem fingir observação nenhuma.
      nHistoricoEfetivo: math.max(1, desfechos),
    );
  }
}
