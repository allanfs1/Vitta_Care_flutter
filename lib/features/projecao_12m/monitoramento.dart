/// Monitoramento do motor em produção — gatilhos numéricos, não "erro acima do
/// limite".
///
/// A v1.0 dizia "re-treinar quando o erro subir" sem estabelecer qual limite, o
/// que na prática significa que ninguém re-treina até alguém reclamar. Aqui
/// cada sinal tem número, janela e ação.
///
/// A métrica mais importante — e a mais esquecida — é a **cobertura do
/// intervalo**: se o motor promete uma faixa de 90% e, ao longo de doze meses,
/// o realizado cai dentro dela em apenas metade dos meses, o produto está
/// errado mesmo que todas as outras métricas estejam boas. Foi exatamente essa
/// a falha da v1.0, e é a única métrica que a teria detectado.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'markov_engine.dart';

/// Um mês fechado: o que foi projetado e o que aconteceu.
@immutable
class MesRealizado {
  const MesRealizado({
    required this.rotulo,
    required this.p05,
    required this.p50,
    required this.p95,
    required this.realizado,
  });

  final String rotulo;
  final num p05;
  final num p50;
  final num p95;
  final num realizado;

  bool get dentroDoIntervalo => realizado >= p05 && realizado <= p95;

  /// Positivo quando o realizado ficou acima do previsto.
  num get desvio => realizado - p50;
}

/// Cobertura observada de um intervalo declarado.
@immutable
class CoberturaIntervalo {
  const CoberturaIntervalo({
    required this.meses,
    required this.dentro,
    required this.nominal,
  });

  final int meses;
  final int dentro;

  /// A cobertura que o intervalo promete — 0,90 para P05–P95.
  final double nominal;

  double get observada => meses == 0 ? 0 : dentro / meses;

  /// Erro-padrão binomial da cobertura observada. Com 12 meses a estimativa é
  /// grosseira, e dizer isso é mais honesto que citar duas casas decimais.
  double get erroPadrao {
    if (meses == 0) return 0;
    final p = observada;
    return math.sqrt(p * (1 - p) / meses);
  }

  /// Faixa de tolerância: dois erros-padrão em torno do nominal, com um piso
  /// para que 12 meses não gerem alarme a cada oscilação.
  double get tolerancia => math.max(0.15, 2 * erroPadrao);

  bool get calibrado => (observada - nominal).abs() <= tolerancia;

  /// Intervalo estreito demais — o caso perigoso, porque parece precisão.
  bool get estreitoDemais => observada < nominal - tolerancia;

  bool get largoDemais => observada > nominal + tolerancia;

  String get veredito {
    if (meses < 6) {
      return 'Apenas $meses mês(es) fechado(s): ainda não há base para julgar a '
          'cobertura. Continue medindo.';
    }
    if (estreitoDemais) {
      return 'O intervalo promete '
          '${(nominal * 100).round()}% e cobre '
          '${(observada * 100).round()}%. Está estreito demais — a projeção '
          'aparenta uma precisão que a operação não sustenta. Reveja as três '
          'camadas de incerteza antes de apresentar a faixa a um cliente.';
    }
    if (largoDemais) {
      return 'O intervalo cobre ${(observada * 100).round()}% contra '
          '${(nominal * 100).round()}% prometidos: está largo demais e a '
          'projeção perde utilidade para decisão.';
    }
    return 'Cobertura observada de ${(observada * 100).round()}% contra '
        '${(nominal * 100).round()}% prometidos. O intervalo se sustenta.';
  }

  static const CoberturaIntervalo vazia =
      CoberturaIntervalo(meses: 0, dentro: 0, nominal: 0.90);
}

/// Modelo que pode disparar re-treino.
enum ModeloMonitorado {
  forecast('Forecast', 'Mensal'),
  risco('Risco de falta', 'Mensal'),
  markov('Markov', 'Semanal'),
  simulador('Simulador', 'Sem treino próprio');

  const ModeloMonitorado(this.label, this.frequencia);
  final String label;
  final String frequencia;
}

/// Um gatilho numérico que disparou — ou não.
@immutable
class GatilhoRetreino {
  const GatilhoRetreino({
    required this.modelo,
    required this.sinal,
    required this.valor,
    required this.limite,
    required this.disparou,
    required this.acao,
  });

  final ModeloMonitorado modelo;
  final String sinal;
  final double valor;
  final double limite;
  final bool disparou;

  /// O que fazer quando dispara. Um sinal sem ação definida não é
  /// monitoramento — é registro histórico do momento em que quebrou.
  final String acao;
}

/// Cálculo dos sinais de produção.
class Monitoramento {
  const Monitoramento._();

  /// Fração de meses em que o realizado caiu dentro do intervalo declarado.
  static CoberturaIntervalo cobertura(
    List<MesRealizado> meses, {
    double nominal = 0.90,
  }) =>
      CoberturaIntervalo(
        meses: meses.length,
        dentro: meses.where((m) => m.dentroDoIntervalo).length,
        nominal: nominal,
      );

  /// Divergência de Jensen-Shannon entre duas matrizes de transição.
  ///
  /// Escolhida em vez da de Kullback-Leibler por duas razões práticas: é
  /// simétrica — a ordem das matrizes não muda o número — e é finita mesmo
  /// quando uma transição tem probabilidade zero na outra matriz, que é
  /// justamente o caso de um segmento pequeno.
  ///
  /// Devolve o **máximo** entre as linhas transitórias: uma cadeia que mudou
  /// muito numa linha e nada nas outras já mudou de comportamento, e a média
  /// esconderia isso.
  static double divergenciaJensenShannon(
    MatrizTransicao a,
    MatrizTransicao b,
  ) {
    var maior = 0.0;
    for (final o in EstadoAgendamento.transitorios) {
      var soma = 0.0;
      for (final d in EstadoAgendamento.values) {
        final p = a.p(o, d);
        final q = b.p(o, d);
        final m = (p + q) / 2;
        if (m <= 0) continue;
        if (p > 0) soma += 0.5 * p * (math.log(p / m) / math.ln2);
        if (q > 0) soma += 0.5 * q * (math.log(q / m) / math.ln2);
      }
      if (soma > maior) maior = soma;
    }
    return maior;
  }

  /// Gatilho do forecast: WAPE degradado ou cobertura fora da faixa.
  static List<GatilhoRetreino> gatilhosForecast({
    required double wapeObservado,
    required double wapeValidacao,
    required int periodosSeguidosAcima,
    CoberturaIntervalo? cobertura80,
  }) {
    final limite = wapeValidacao * 1.3;
    final gatilhos = <GatilhoRetreino>[
      GatilhoRetreino(
        modelo: ModeloMonitorado.forecast,
        sinal: 'WAPE > 1,3× o de validação por 2 períodos seguidos',
        valor: wapeObservado,
        limite: limite,
        disparou: wapeObservado > limite && periodosSeguidosAcima >= 2,
        acao: 'Re-treinar. Se não passar do portão contra o naive sazonal, '
            'cair para o baseline — que é mais barato e mais estável.',
      ),
    ];

    final c = cobertura80;
    if (c != null && c.meses >= 6) {
      gatilhos.add(GatilhoRetreino(
        modelo: ModeloMonitorado.forecast,
        sinal: 'Cobertura do intervalo de 80% fora da faixa 70–90%',
        valor: c.observada,
        limite: 0.70,
        disparou: c.observada < 0.70 || c.observada > 0.90,
        acao: 'Re-treinar e reavaliar a largura do intervalo antes de '
            'publicar nova projeção.',
      ));
    }
    return gatilhos;
  }

  /// Gatilho do modelo de risco: PR-AUC caiu ou ECE subiu.
  ///
  /// A calibração degrada **antes** da discriminação. Como o motor financeiro
  /// consome o nível e não a ordenação, o ECE é o sinal que importa primeiro.
  static List<GatilhoRetreino> gatilhosRisco({
    required double prAucAtual,
    required double prAucReferencia,
    required double ece,
  }) {
    final quedaRelativa = prAucReferencia <= 0
        ? 0.0
        : (prAucReferencia - prAucAtual) / prAucReferencia;
    return [
      GatilhoRetreino(
        modelo: ModeloMonitorado.risco,
        sinal: 'PR-AUC cai mais de 10% relativos',
        valor: quedaRelativa,
        limite: 0.10,
        disparou: quedaRelativa > 0.10,
        acao: 'Re-treinar com validação temporal.',
      ),
      GatilhoRetreino(
        modelo: ModeloMonitorado.risco,
        sinal: 'ECE > 0,05',
        valor: ece,
        limite: 0.05,
        disparou: ece > 0.05,
        acao: 'Recalibrar primeiro — isotônica em janela posterior. '
            'Re-treinar só se a calibração não resolver.',
      ),
    ];
  }

  /// Gatilho da cadeia: a matriz da janela divergiu da vigente.
  static GatilhoRetreino gatilhoMarkov({
    required MatrizTransicao vigente,
    required MatrizTransicao janela,
    double limite = 0.05,
  }) {
    final js = divergenciaJensenShannon(vigente, janela);
    return GatilhoRetreino(
      modelo: ModeloMonitorado.markov,
      sinal: 'Divergência de Jensen-Shannon > ${limite.toStringAsFixed(2)}',
      valor: js,
      limite: limite,
      disparou: js > limite,
      acao: 'Recalcular por segmento, com shrinkage para os pequenos.',
    );
  }

  /// Gatilho do simulador: o realizado saiu da faixa por dois meses.
  ///
  /// O simulador não tem treino próprio — o que muda são os **parâmetros de
  /// impacto**, e eles só se atualizam com resultado de piloto.
  static GatilhoRetreino gatilhoSimulador(List<MesRealizado> meses) {
    var seguidosFora = 0;
    var maior = 0;
    for (final m in meses) {
      if (m.dentroDoIntervalo) {
        seguidosFora = 0;
      } else {
        seguidosFora++;
        if (seguidosFora > maior) maior = seguidosFora;
      }
    }
    return GatilhoRetreino(
      modelo: ModeloMonitorado.simulador,
      sinal: 'Realizado fora do P05–P95 por 2 meses seguidos',
      valor: maior.toDouble(),
      limite: 2,
      disparou: maior >= 2,
      acao: 'Atualizar os parâmetros de impacto com o resultado observado e '
          'virar o campo de calibração para verdadeiro.',
    );
  }

  /// Atraso do ground truth: o desfecho de um agendamento só se conhece na data
  /// da consulta.
  ///
  /// Para um horizonte de agendamento de [diasAntecedenciaMedia] dias, a
  /// performance do modelo de risco só pode ser medida com esse atraso. Não é
  /// defeito do monitoramento — é propriedade do domínio, e a janela de alerta
  /// precisa nascer com ela, ou o painel mostra "sem dados" e alguém lê isso
  /// como "sem problema".
  static int janelaMinimaDeAlertaEmDias(int diasAntecedenciaMedia) =>
      diasAntecedenciaMedia + 7;
}
