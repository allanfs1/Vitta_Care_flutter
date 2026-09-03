import 'dart:math' as math;

/// Estados do ciclo de vida de um agendamento.
///
/// `reagendado` é um estado próprio, não um cancelamento. Reagendar preserva o
/// paciente no sistema **e** devolve a vaga; cancelar perde as duas coisas.
/// Colapsar os dois superestima a perda e apaga justamente o desfecho que a
/// intervenção mais tenta produzir.
enum EstadoAgendamento {
  agendado('Agendado', false),
  aguardandoConfirmacao('Aguardando confirmação', false),
  confirmado('Confirmado', false),
  compareceu('Compareceu', true),
  faltou('Faltou', true),
  cancelado('Cancelado', true),
  reagendado('Reagendado', true);

  const EstadoAgendamento(this.label, this.absorvente);

  final String label;

  /// Estado terminal: uma vez alcançado, não se sai dele.
  final bool absorvente;

  static List<EstadoAgendamento> get transitorios =>
      values.where((e) => !e.absorvente).toList();

  static List<EstadoAgendamento> get absorventes =>
      values.where((e) => e.absorvente).toList();
}

/// Uma transição observada no histórico.
class EventoTransicao {
  const EventoTransicao({
    required this.origem,
    required this.destino,
    this.diasAteConsulta = 0,
  });

  final EstadoAgendamento origem;
  final EstadoAgendamento destino;

  /// Quantos dias faltavam para a consulta quando a transição ocorreu.
  /// Indexar por isso é o que torna a cadeia não-homogênea.
  final int diasAteConsulta;
}

/// Matriz de transição. Cada linha é uma distribuição de probabilidade.
class MatrizTransicao {
  MatrizTransicao(this.linhas);

  /// `linhas[origem]![destino]` = P(origem → destino).
  final Map<EstadoAgendamento, Map<EstadoAgendamento, double>> linhas;

  double p(EstadoAgendamento de, EstadoAgendamento para) =>
      linhas[de]?[para] ?? 0.0;

  /// Toda linha soma 1 dentro da tolerância?
  bool get valida {
    for (final e in EstadoAgendamento.values) {
      final soma = (linhas[e] ?? const {}).values.fold(0.0, (a, b) => a + b);
      if ((soma - 1.0).abs() > 1e-9) return false;
    }
    return true;
  }

  /// Probabilidades de absorção partindo de [inicial], por iteração.
  ///
  /// Itera a distribuição até que a massa nos estados transitórios seja
  /// desprezível. Com absorventes bem formados isso converge rápido; o teto de
  /// iterações existe só para não travar diante de uma matriz malformada.
  Map<EstadoAgendamento, double> absorcaoDe(
    EstadoAgendamento inicial, {
    int maxIter = 2000,
    double tol = 1e-12,
  }) {
    var dist = <EstadoAgendamento, double>{inicial: 1.0};

    for (var it = 0; it < maxIter; it++) {
      final prox = <EstadoAgendamento, double>{};
      var massaTransitoria = 0.0;

      for (final entry in dist.entries) {
        final estado = entry.key;
        final massa = entry.value;
        if (massa <= 0) continue;

        if (estado.absorvente) {
          prox[estado] = (prox[estado] ?? 0) + massa;
          continue;
        }
        massaTransitoria += massa;
        final linha = linhas[estado] ?? const {};
        for (final t in linha.entries) {
          prox[t.key] = (prox[t.key] ?? 0) + massa * t.value;
        }
      }
      dist = prox;
      if (massaTransitoria < tol) break;
    }

    // Sobra em estados transitórios (linha sem saída, ou massa que ainda não
    // absorveu no teto de iterações) vira "cancelado" para manter a
    // distribuição fechada — e o teste de validade acusa a causa.
    //
    // Uma linha transitória VAZIA não transiciona: no laço acima ela não
    // contribui nada para `prox`, e a massa dela desaparece antes de chegar
    // aqui. Por isso a sobra é medida na distribuição da última iteração
    // **antes** do avanço, e não no que restou depois.
    final out = <EstadoAgendamento, double>{};
    var absorvida = 0.0;
    for (final e in dist.entries) {
      if (e.key.absorvente) {
        out[e.key] = e.value;
        absorvida += e.value;
      }
    }
    final resto = 1.0 - absorvida;
    if (resto > 1e-12) {
      out[EstadoAgendamento.cancelado] =
          (out[EstadoAgendamento.cancelado] ?? 0) + resto;
    }
    return out;
  }

  Map<String, Map<String, double>> toJson() => {
        for (final e in linhas.entries)
          e.key.name: {for (final t in e.value.entries) t.key.name: t.value},
      };
}

/// Faixa de dias até a consulta. A intervenção age em janelas específicas.
class FaixaDias {
  const FaixaDias(this.de, this.ate, this.rotulo);

  /// Limite superior (mais distante da consulta).
  final int de;

  /// Limite inferior (mais próximo).
  final int ate;

  final String rotulo;

  bool contem(int dias) => dias <= de && dias >= ate;

  /// Faixas padrão da especificação. A janela curta é onde o lembrete funciona.
  static const List<FaixaDias> padrao = [
    FaixaDias(30, 15, '30–15 dias'),
    FaixaDias(14, 8, '14–8 dias'),
    FaixaDias(7, 4, '7–4 dias'),
    FaixaDias(3, 2, '3–2 dias'),
    FaixaDias(1, 0, '1–0 dia'),
  ];
}

/// Estimação e manipulação de cadeias de Markov do fluxo de agendamento.
class MarkovEngine {
  const MarkovEngine._();

  /// Estima a matriz a partir de eventos observados, com suavização de
  /// Dirichlet.
  ///
  /// A pseudo-contagem [alpha] não é enfeite: sem ela, um estado nunca
  /// observado produz uma linha inteira de zeros — que não é distribuição de
  /// probabilidade e quebra a simulação em silêncio. Era o defeito da v1.0,
  /// que pedia suavização no texto e dividia contagens brutas no código.
  static MatrizTransicao estimar(
    List<EventoTransicao> eventos, {
    double alpha = 1.0,
  }) {
    final contagens = <EstadoAgendamento, Map<EstadoAgendamento, double>>{
      for (final o in EstadoAgendamento.values)
        o: {for (final d in EstadoAgendamento.values) d: alpha},
    };

    for (final e in eventos) {
      if (e.origem.absorvente) continue; // absorvente não transiciona
      contagens[e.origem]![e.destino] =
          (contagens[e.origem]![e.destino] ?? 0) + 1;
    }

    final linhas = <EstadoAgendamento, Map<EstadoAgendamento, double>>{};
    for (final o in EstadoAgendamento.values) {
      if (o.absorvente) {
        // Absorvente é auto-laço puro, sem suavização: 1,0 nele mesmo.
        linhas[o] = {o: 1.0};
        continue;
      }
      final linha = contagens[o]!;
      final soma = linha.values.fold(0.0, (a, b) => a + b);
      linhas[o] = {
        for (final d in EstadoAgendamento.values)
          if ((linha[d] ?? 0) > 0) d: (linha[d] ?? 0) / soma,
      };
    }
    return MatrizTransicao(linhas);
  }

  /// Uma matriz por faixa de dias até a consulta.
  ///
  /// Uma cadeia homogênea afirma que a chance de confirmar é a mesma faltando
  /// 30 dias ou faltando 1 — empiricamente falso, e apaga exatamente o sinal
  /// que a operação usa. Aplicar um delta uniforme em todas as faixas supõe que
  /// um lembrete enviado com 30 dias vale tanto quanto um enviado com 2.
  static Map<String, MatrizTransicao> estimarPorFaixa(
    List<EventoTransicao> eventos, {
    List<FaixaDias> faixas = FaixaDias.padrao,
    double alpha = 1.0,
  }) =>
      {
        for (final f in faixas)
          f.rotulo: estimar(
            eventos.where((e) => f.contem(e.diasAteConsulta)).toList(),
            alpha: alpha,
          ),
      };

  /// Empirical Bayes: segmento com pouco dado encosta na matriz global.
  ///
  /// Resolve partida a frio. [k] é o número de observações que dá peso 50/50 —
  /// abaixo disso o global domina, acima o segmento fala por si.
  static MatrizTransicao encolherPara(
    MatrizTransicao segmento,
    MatrizTransicao global, {
    required int nSegmento,
    double k = 50.0,
  }) {
    final w = nSegmento / (nSegmento + k);
    final linhas = <EstadoAgendamento, Map<EstadoAgendamento, double>>{};

    for (final o in EstadoAgendamento.values) {
      if (o.absorvente) {
        linhas[o] = {o: 1.0};
        continue;
      }
      final destinos = <EstadoAgendamento>{
        ...(segmento.linhas[o] ?? const {}).keys,
        ...(global.linhas[o] ?? const {}).keys,
      };
      final linha = <EstadoAgendamento, double>{};
      var soma = 0.0;
      for (final d in destinos) {
        final v = w * segmento.p(o, d) + (1 - w) * global.p(o, d);
        if (v > 0) {
          linha[d] = v;
          soma += v;
        }
      }
      // Renormaliza: a combinação convexa preserva a soma, mas erro de ponto
      // flutuante acumula ao longo de várias faixas.
      linhas[o] = soma > 0
          ? {for (final e in linha.entries) e.key: e.value / soma}
          : {EstadoAgendamento.cancelado: 1.0};
    }
    return MatrizTransicao(linhas);
  }

  /// Aplica a intervenção às linhas transitórias da matriz recebida.
  ///
  /// [reducaoFalta] e [reducaoCancelamento] são reduções relativas (0,20 = −20%
  /// da transição). A massa retirada vai para os desfechos cooperativos,
  /// mantendo a linha somando 1.
  ///
  /// **A seleção de faixa é responsabilidade de quem chama.** Para respeitar a
  /// cadeia não-homogênea, passe aqui a matriz de UMA faixa de dias — ver
  /// [estimarPorFaixa]. Os chamadores atuais passam [referencia], que é uma
  /// matriz única e homogênea: o efeito exibido é, portanto, uniforme em todas
  /// as faixas, o que superestima a intervenção. Isso é aceitável só porque a
  /// absorção resultante é ilustrativa — as contagens projetadas vêm das taxas
  /// agregadas no motor, não desta cadeia — e a tela declara a simplificação.
  ///
  /// A redução relativa vale **por transição**, não sobre a absorção final:
  /// parte da massa recuperada em `aguardando_confirmacao` volta a passar por
  /// `confirmado`, que tem seu próprio ramo de falta. Por isso uma redução
  /// pedida de 20% aparece como cerca de 19% na absorção — não é perda de
  /// precisão, é a cadeia sendo consistente consigo mesma.
  static MatrizTransicao aplicarIntervencao(
    MatrizTransicao base, {
    double reducaoFalta = 0.0,
    double reducaoCancelamento = 0.0,
    double deltaConfirmacao = 0.0,
    double fracaoReagendamento = 0.0,
  }) {
    final linhas = <EstadoAgendamento, Map<EstadoAgendamento, double>>{};

    for (final o in EstadoAgendamento.values) {
      if (o.absorvente) {
        linhas[o] = {o: 1.0};
        continue;
      }
      final orig = Map<EstadoAgendamento, double>.from(
          base.linhas[o] ?? const {});
      if (orig.isEmpty) {
        linhas[o] = {EstadoAgendamento.cancelado: 1.0};
        continue;
      }

      var liberado = 0.0;

      void reduzir(EstadoAgendamento alvo, double fator) {
        final atual = orig[alvo];
        if (atual == null || atual <= 0 || fator <= 0) return;
        final novo = atual * (1 - fator.clamp(0.0, 1.0));
        liberado += atual - novo;
        orig[alvo] = novo;
      }

      reduzir(EstadoAgendamento.faltou, reducaoFalta);
      reduzir(EstadoAgendamento.cancelado, reducaoCancelamento);

      // O delta de confirmação empurra massa de "aguardando" para "confirmado"
      // dentro da mesma linha, quando esse destino existe.
      if (deltaConfirmacao > 0 &&
          orig.containsKey(EstadoAgendamento.confirmado)) {
        final aguardando = orig[EstadoAgendamento.aguardandoConfirmacao] ?? 0;
        final move = aguardando * deltaConfirmacao.clamp(0.0, 1.0);
        if (move > 0) {
          orig[EstadoAgendamento.aguardandoConfirmacao] = aguardando - move;
          orig[EstadoAgendamento.confirmado] =
              (orig[EstadoAgendamento.confirmado] ?? 0) + move;
        }
      }

      // Para onde vai a massa liberada. Uma parte vira reagendamento — que é o
      // desfecho que a intervenção de fato produz quando alcança o paciente a
      // tempo: ele não some do sistema e a vaga volta para a agenda. O resto
      // segue para o destino cooperativo da própria linha.
      if (liberado > 0) {
        final fr = fracaoReagendamento.clamp(0.0, 1.0);
        if (fr > 0) {
          orig[EstadoAgendamento.reagendado] =
              (orig[EstadoAgendamento.reagendado] ?? 0) + liberado * fr;
        }
        final restante = liberado * (1 - fr);
        if (restante > 0) {
          final destino = orig.containsKey(EstadoAgendamento.compareceu)
              ? EstadoAgendamento.compareceu
              : (orig.containsKey(EstadoAgendamento.confirmado)
                  ? EstadoAgendamento.confirmado
                  : EstadoAgendamento.reagendado);
          orig[destino] = (orig[destino] ?? 0) + restante;
        }
      }

      final soma = orig.values.fold(0.0, (a, b) => a + b);
      linhas[o] = soma > 0
          ? {
              for (final e in orig.entries)
                if (e.value > 0) e.key: e.value / soma,
            }
          : {EstadoAgendamento.cancelado: 1.0};
    }
    return MatrizTransicao(linhas);
  }

  /// Matriz de referência da especificação, verificada por iteração.
  ///
  /// Absorção a partir de `agendado`: compareceu ≈ 69,0%, faltou ≈ 22,1%,
  /// cancelado ≈ 9,0% — consistente com o exemplo de API da seção 7.
  static MatrizTransicao referencia() => MatrizTransicao({
        EstadoAgendamento.agendado: {
          EstadoAgendamento.aguardandoConfirmacao: 0.66,
          EstadoAgendamento.confirmado: 0.28,
          EstadoAgendamento.cancelado: 0.06,
        },
        EstadoAgendamento.aguardandoConfirmacao: {
          EstadoAgendamento.confirmado: 0.82,
          EstadoAgendamento.cancelado: 0.02,
          EstadoAgendamento.faltou: 0.16,
        },
        EstadoAgendamento.confirmado: {
          EstadoAgendamento.compareceu: 0.84,
          EstadoAgendamento.faltou: 0.14,
          EstadoAgendamento.cancelado: 0.02,
        },
        for (final a in EstadoAgendamento.absorventes) a: {a: 1.0},
      });

  /// Distância máxima entre duas matrizes, para monitorar deriva.
  static double distanciaMaxima(MatrizTransicao a, MatrizTransicao b) {
    var maior = 0.0;
    for (final o in EstadoAgendamento.values) {
      for (final d in EstadoAgendamento.values) {
        final diff = (a.p(o, d) - b.p(o, d)).abs();
        if (diff > maior) maior = diff;
      }
    }
    return maior;
  }

  /// Entropia média das linhas transitórias — matriz muito concentrada em um
  /// destino costuma indicar amostra pequena demais, não determinismo real.
  static double entropiaMedia(MatrizTransicao m) {
    var soma = 0.0;
    var n = 0;
    for (final o in EstadoAgendamento.transitorios) {
      final linha = m.linhas[o] ?? const {};
      var h = 0.0;
      for (final p in linha.values) {
        if (p > 0) h -= p * math.log(p);
      }
      soma += h;
      n++;
    }
    return n == 0 ? 0 : soma / n;
  }
}
