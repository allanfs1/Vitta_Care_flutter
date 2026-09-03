import 'dart:math' as math;

import 'markov_engine.dart';
import 'projecao_amostradores.dart';
import 'projecao_models.dart';

/// Motor de projeção de 12 meses (lógica pura, sem Flutter e sem Firebase).
///
/// Cinco decisões sustentam o resto:
///
/// 1. **Três camadas de incerteza, não uma.** Forecast (quantos agendamentos
///    existirão), parâmetro (qual é a taxa verdadeira) e amostral (a realização
///    dado n e p). Propagar só a última produz um intervalo rotulado como 90%
///    que cobre cerca de metade dos futuros plausíveis.
///
/// 2. **As duas primeiras camadas são epistêmicas e persistem no horizonte.**
///    Existe **uma** taxa verdadeira de falta por mundo simulado, não doze;
///    e o erro do forecast tem componente de nível que acompanha o ano inteiro.
///    Re-sortear essas camadas a cada mês faz a incerteza se cancelar por
///    média e devolve, no agregado de 12 meses, exatamente a superconfiança
///    que a camada existe para corrigir.
///
/// 3. **Sorteio multinomial único.** Falta, cancelamento e comparecimento são
///    mutuamente exclusivos. Sortear falta sobre o total e cancelamento sobre o
///    resíduo faz a taxa pedida de 10% se realizar como 7,8%.
///
/// 4. **Capacidade é restrição dura.** Sem teto, a simulação projeta mais
///    atendimentos do que a agenda comporta — e fica mais otimista justamente
///    onde deveria esbarrar no limite físico.
///
/// 5. **Os dois cenários rodam no mesmo mundo.** Baseline e Agenda Clínica
///    compartilham demanda, taxa verdadeira e choques amostrais; a única
///    diferença entre eles são os parâmetros de intervenção. Sem isso, a
///    diferença entre cenários é dominada pelo ruído do gerador, e o intervalo
///    do ganho fica largo demais por um motivo que não é do negócio.
class ProjecaoEngine {
  const ProjecaoEngine._();

  /// Executa os dois cenários e a decomposição financeira.
  static ProjecaoResultado projetar(ProjecaoConfig config) {
    final inicio = DateTime.now();

    // Cadeia de referência e a mesma cadeia sob intervenção. Ela é ilustrativa:
    // mostra para onde vai um agendamento, e é onde `deltaConfirmacao` aparece.
    // As contagens projetadas vêm das taxas agregadas, não da cadeia.
    final matrizBase = MarkovEngine.referencia();
    final matrizInterv = MarkovEngine.aplicarIntervencao(
      matrizBase,
      reducaoFalta: config.intervencao.reducaoFalta,
      reducaoCancelamento: config.intervencao.reducaoCancelamento,
      deltaConfirmacao: config.intervencao.deltaConfirmacao,
      fracaoReagendamento: config.intervencao.fracaoReagendamento,
    );

    final absBase = matrizBase.absorcaoDe(EstadoAgendamento.agendado);
    final absInterv = matrizInterv.absorcaoDe(EstadoAgendamento.agendado);

    final par = _simularPar(config);

    final impacto = receitaIncremental(
      comparecimentosBase: par.a.comparecimentos.p50.toDouble(),
      comparecimentosAgenda: par.b.comparecimentos.p50.toDouble(),
      vagasRepostas: par.b.vagasRepostas.p50.toDouble(),
      valorConsulta: config.valorConsulta,
      fracaoDemandaNova: config.fracaoDemandaNova,
    );

    return ProjecaoResultado(
      config: config,
      baseline: par.a,
      agendaClinica: par.b,
      impacto: impacto,
      faltasEvitadas: par.faltasEvitadas,
      cancelamentosEvitados: par.cancelamentosEvitados,
      duracao: DateTime.now().difference(inicio),
      absorcaoBaseline: {
        for (final e in absBase.entries) e.key.name: e.value,
      },
      absorcaoIntervencao: {
        for (final e in absInterv.entries) e.key.name: e.value,
      },
    );
  }

  /// Simula baseline e cenário de intervenção **replicação a replicação, no
  /// mesmo mundo sorteado**.
  ///
  /// Todo choque aleatório é sorteado uma vez e entregue aos dois cenários. Por
  /// isso a diferença entre eles pode ser lida por replicação — e é essa
  /// diferença pareada, não a subtração de percentis marginais, que produz um
  /// intervalo de 90% honesto para o ganho.
  static _ParCenarios _simularPar(ProjecaoConfig config) {
    final rng = Amostradores(config.seed);
    final n = math.max(1, config.nSimulacoes);
    final meses = math.max(1, config.horizonteMeses);
    final teto = config.capacidadeMensal.toDouble();
    final nHist = math.max(1, config.nHistorico).toDouble();

    final a = _Acumulador(n, meses);
    final b = _Acumulador(n, meses);
    final difFaltas = List<int>.filled(n, 0);
    final difCancel = List<int>.filled(n, 0);

    // Redução negativa é permitida de propósito: quando o piloto mede o efeito
    // e ele sai contra, o motor precisa saber representar isso. Clampar em zero
    // faria "a intervenção piorou" virar "a intervenção não fez nada" — e é
    // justamente essa distinção que a fase de calibração existe para produzir.
    final reducaoFalta = config.intervencao.reducaoFalta.clamp(-1.0, 1.0);
    final reducaoCancel =
        config.intervencao.reducaoCancelamento.clamp(-1.0, 1.0);
    final taxaReposicao = config.intervencao.taxaReposicaoVaga.clamp(0.0, 1.0);

    for (var s = 0; s < n; s++) {
      // ── Camada 1a: o nível do forecast, comum a todo o horizonte ──────
      final zNivel = rng.normal();

      // ── Camada 2: a taxa verdadeira deste mundo, uma por replicação ───
      // Sorteada UMA vez para o ano: é incerteza sobre uma quantidade fixa e
      // desconhecida, não ruído mensal. O cenário B parte da mesma taxa
      // verdadeira e aplica a redução relativa sobre ela — é o que torna a
      // comparação entre cenários uma comparação, e não um ruído.
      final pFaltaA = rng.beta(
          math.max(1e-6, config.taxaFalta * nHist),
          math.max(1e-6, (1 - config.taxaFalta) * nHist));
      final pCancelA = rng.beta(
          math.max(1e-6, config.taxaCancelamento * nHist),
          math.max(1e-6, (1 - config.taxaCancelamento) * nHist));

      final probsA = _normalizar(pFaltaA, pCancelA);
      final probsB =
          _normalizar(pFaltaA * (1 - reducaoFalta), pCancelA * (1 - reducaoCancel));

      var mesesEstouroA = 0;
      var mesesEstouroB = 0;

      for (var m = 0; m < meses; m++) {
        // ── Camada 1b: o desvio do mês ──────────────────────────────────
        final zMes = rng.normal();
        final demanda = rng.lognormalDecomposta(
          config.agendamentosMensais.toDouble(),
          config.wapeForecast,
          config.rhoForecast,
          zNivel,
          zMes,
        );

        // ── Restrição de capacidade ─────────────────────────────────────
        // A demanda de referência é a MESMA nos dois cenários: a intervenção
        // não cria demanda nem capacidade. O que ela muda é o desfecho.
        final agendado = math.min(demanda, teto).round();
        final reprimida = math.max(0.0, demanda - teto).round();

        // ── Camada 3: choques amostrais, compartilhados ─────────────────
        final z1 = rng.normal();
        final z2 = rng.normal();
        final z3 = rng.normal();
        final z4 = rng.normal();
        final z5 = rng.normal();

        if (_mes(a, s, m, rng, agendado, reprimida, probsA, 0.0,
                [z1, z2], z3, [z4, z5]) >
            0) {
          mesesEstouroA++;
        }
        if (_mes(b, s, m, rng, agendado, reprimida, probsB, taxaReposicao,
                [z1, z2], z3, [z4, z5]) >
            0) {
          mesesEstouroB++;
        }
      }

      a.mesesEstouro[s] = mesesEstouroA;
      b.mesesEstouro[s] = mesesEstouroB;
      difFaltas[s] = a.faltas[s] - b.faltas[s];
      difCancel[s] = a.cancelamentos[s] - b.cancelamentos[s];
    }

    return _ParCenarios(
      a: a.fechar(),
      b: b.fechar(),
      // Percentil da diferença, não diferença de percentis: como os dois
      // cenários veem o mesmo mundo, a maior parte da incerteza se cancela — e
      // o que sobra é o efeito da intervenção, que é o que se quer medir.
      faltasEvitadas: Percentis.de(difFaltas),
      cancelamentosEvitados: Percentis.de(difCancel),
    );
  }

  /// Um mês de um cenário, alimentado por choques vindos de fora.
  ///
  /// Devolve a demanda reprimida **líquida** do mês — o que continuou sem
  /// caber depois de a reposição devolver vagas à agenda.
  static int _mes(
    _Acumulador acc,
    int s,
    int m,
    Amostradores rng,
    int agendado,
    int reprimida,
    List<double> probs,
    double taxaReposicao,
    List<double> zMultinomial,
    double zReposicao,
    List<double> zReposicaoDesfecho,
  ) {
    final partes = rng.multinomialComZ(agendado, probs, zMultinomial);
    var comp = partes[0];
    var falta = partes[1];
    var cancel = partes[2];

    // ── Reposição de vaga ─────────────────────────────────────────────────
    // Repor é reocupar uma vaga que um cancelamento devolveu. Não é demanda
    // nova empilhada sobre o forecast: aplicar a taxa sobre a demanda total
    // multiplicaria as vagas repostas pelo inverso da taxa de cancelamento e
    // inflaria toda a linha de antecipação de demanda. E, por reutilizar
    // capacidade já liberada, o mecanismo continua funcionando — e passa a
    // valer mais — justamente quando a agenda está cheia.
    var repostas = 0;
    if (taxaReposicao > 0 && cancel > 0) {
      repostas = rng.binomialComZ(cancel, taxaReposicao, zReposicao);
      if (repostas > 0) {
        final desfecho =
            rng.multinomialComZ(repostas, probs, zReposicaoDesfecho);
        comp += desfecho[0];
        falta += desfecho[1];
        cancel += desfecho[2];
      }
    }

    // Uma vaga reposta sai da lista de espera: quem não tinha cabido passa a
    // caber. Reportar a reprimida bruta no cenário B daria a impressão de que a
    // reposição não alivia a fila — quando aliviá-la é justamente o mecanismo.
    final reprimidaLiquida = math.max(0, reprimida - repostas);

    acc.agendamentos[s] += agendado + repostas;
    acc.comparecimentos[s] += comp;
    acc.faltas[s] += falta;
    acc.cancelamentos[s] += cancel;
    acc.vagasRepostas[s] += repostas;
    acc.reprimida[s] += reprimidaLiquida;
    acc.compPorMes[m][s] = comp;
    acc.reprimidaPorMes[m][s] = reprimidaLiquida;
    return reprimidaLiquida;
  }

  /// Normaliza as três categorias na ordem (comparecimento, falta,
  /// cancelamento).
  static List<double> _normalizar(double pFalta, double pCancel) {
    final f = pFalta.clamp(0.0, 1.0);
    final c = pCancel.clamp(0.0, 1.0);
    final comp = math.max(1e-9, 1.0 - f - c);
    final soma = comp + f + c;
    return [comp / soma, f / soma, c / soma];
  }

  /// Decompõe o ganho entre receita defensável e antecipação de demanda.
  ///
  /// [fracaoDemandaNova] é a parcela das vagas repostas ocupada por pacientes
  /// que **não** seriam atendidos dentro do horizonte. Deve ser medida no
  /// piloto, não arbitrada — até haver medição, use valor conservador e
  /// declare-o.
  ///
  /// Ganho negativo é representado, não zerado: uma intervenção que piora o
  /// resultado precisa aparecer, e é exatamente esse o desfecho que a fase de
  /// calibração existe para detectar.
  static ImpactoFinanceiro receitaIncremental({
    required double comparecimentosBase,
    required double comparecimentosAgenda,
    required double vagasRepostas,
    required double valorConsulta,
    double fracaoDemandaNova = 0.35,
  }) {
    final ganhoBruto = comparecimentosAgenda - comparecimentosBase;
    if (ganhoBruto == 0) return ImpactoFinanceiro.zero;

    if (ganhoBruto < 0) {
      // Perda não se decompõe em "defensável" e "antecipada": não há vaga
      // reposta a atribuir. Ela aparece inteira, com sinal.
      return ImpactoFinanceiro(
        consultasFaltaEvitada: ganhoBruto,
        consultasDemandaNova: 0,
        consultasAntecipadas: 0,
        receitaDefensavel: ganhoBruto * valorConsulta,
        receitaAntecipacao: 0,
      );
    }

    final porReposicao = math.min(math.max(0.0, vagasRepostas), ganhoBruto);
    final porFalta = math.max(0.0, ganhoBruto - porReposicao);

    final f = fracaoDemandaNova.clamp(0.0, 1.0);
    final nova = porReposicao * f;
    final antecipada = porReposicao * (1 - f);

    return ImpactoFinanceiro(
      consultasFaltaEvitada: porFalta,
      consultasDemandaNova: nova,
      consultasAntecipadas: antecipada,
      receitaDefensavel: (porFalta + nova) * valorConsulta,
      receitaAntecipacao: antecipada * valorConsulta,
    );
  }

  // ── Portão de aceite do forecast ────────────────────────────────────

  /// WAPE — erro percentual ponderado.
  static double wape(List<double> real, List<double> previsto) {
    if (real.isEmpty || real.length != previsto.length) return double.nan;
    var num = 0.0;
    var den = 0.0;
    for (var i = 0; i < real.length; i++) {
      num += (real[i] - previsto[i]).abs();
      den += real[i].abs();
    }
    return den == 0 ? double.nan : num / den;
  }

  /// Baseline ingênuo sazonal: o valor do mesmo mês do ano anterior.
  static List<double> naiveSazonal(List<double> serie, {int periodo = 12}) => [
        for (var i = 0; i < serie.length; i++)
          i >= periodo ? serie[i - periodo] : double.nan,
      ];

  /// Baseline de média móvel.
  static List<double> mediaMovel(List<double> serie, {int janela = 12}) {
    final out = List<double>.filled(serie.length, double.nan);
    for (var i = janela; i < serie.length; i++) {
      var s = 0.0;
      for (var k = i - janela; k < i; k++) {
        s += serie[k];
      }
      out[i] = s / janela;
    }
    return out;
  }

  /// Portão de aceite: o modelo precisa vencer o melhor baseline trivial.
  ///
  /// Se o ganho não existir, implante o baseline — é mais barato, mais estável,
  /// explicável em uma frase e não precisa de re-treino.
  static PortaoAceite portaoDeAceite({
    required List<double> real,
    required List<double> modelo,
    required List<double> naive,
    required List<double> mediaM,
    double ganhoMinimo = 0.10,
  }) {
    // Só compara nos índices em que todos os candidatos têm valor.
    final iR = <double>[], iM = <double>[], iN = <double>[], iMM = <double>[];
    final limite = [real.length, modelo.length, naive.length, mediaM.length]
        .reduce(math.min);
    for (var i = 0; i < limite; i++) {
      if (naive[i].isNaN || mediaM[i].isNaN || modelo[i].isNaN) continue;
      iR.add(real[i]);
      iM.add(modelo[i]);
      iN.add(naive[i]);
      iMM.add(mediaM[i]);
    }

    if (iR.isEmpty) {
      return const PortaoAceite(
        wapeModelo: double.nan,
        wapeBaseline: double.nan,
        ganhoRelativo: double.nan,
        aprovado: false,
        baselineVencedor: 'sem janela comparável',
        pontosComparados: 0,
      );
    }

    final wModelo = wape(iR, iM);
    final wNaive = wape(iR, iN);
    final wMedia = wape(iR, iMM);
    final melhorBaseline = math.min(wNaive, wMedia);
    final vencedor = wNaive <= wMedia ? 'naive sazonal' : 'média móvel';

    final ganho =
        melhorBaseline <= 0 ? 0.0 : (melhorBaseline - wModelo) / melhorBaseline;

    return PortaoAceite(
      wapeModelo: wModelo,
      wapeBaseline: melhorBaseline,
      ganhoRelativo: ganho,
      aprovado: ganho >= ganhoMinimo,
      baselineVencedor: vencedor,
      pontosComparados: iR.length,
    );
  }
}

/// Acumuladores por replicação de um cenário.
class _Acumulador {
  _Acumulador(this.n, this.meses)
      : agendamentos = List<int>.filled(n, 0),
        comparecimentos = List<int>.filled(n, 0),
        faltas = List<int>.filled(n, 0),
        cancelamentos = List<int>.filled(n, 0),
        vagasRepostas = List<int>.filled(n, 0),
        reprimida = List<int>.filled(n, 0),
        mesesEstouro = List<int>.filled(n, 0),
        compPorMes =
            List<List<int>>.generate(meses, (_) => List<int>.filled(n, 0)),
        reprimidaPorMes =
            List<List<int>>.generate(meses, (_) => List<int>.filled(n, 0));

  final int n;
  final int meses;
  final List<int> agendamentos;
  final List<int> comparecimentos;
  final List<int> faltas;
  final List<int> cancelamentos;
  final List<int> vagasRepostas;
  final List<int> reprimida;
  final List<int> mesesEstouro;
  final List<List<int>> compPorMes;
  final List<List<int>> reprimidaPorMes;

  ResultadoCenario fechar() {
    final percentis = [for (final m in compPorMes) Percentis.de(m)];
    return ResultadoCenario(
      agendamentos: Percentis.de(agendamentos),
      comparecimentos: Percentis.de(comparecimentos),
      faltas: Percentis.de(faltas),
      cancelamentos: Percentis.de(cancelamentos),
      vagasRepostas: Percentis.de(vagasRepostas),
      demandaReprimida: Percentis.de(reprimida),
      mesesComDemandaReprimida: Percentis.de(mesesEstouro).p50.toDouble(),
      probabilidadeEstouro:
          n == 0 ? 0 : mesesEstouro.where((v) => v > 0).length / n,
      porMes: [for (final p in percentis) p.p50.round()],
      porMesPercentis: percentis,
      demandaPorMes: [
        for (final rm in reprimidaPorMes)
          n == 0 ? 0.0 : rm.where((v) => v > 0).length / n,
      ],
    );
  }
}

/// Os dois cenários e as diferenças pareadas entre eles.
class _ParCenarios {
  const _ParCenarios({
    required this.a,
    required this.b,
    required this.faltasEvitadas,
    required this.cancelamentosEvitados,
  });

  final ResultadoCenario a;
  final ResultadoCenario b;
  final Percentis faltasEvitadas;
  final Percentis cancelamentosEvitados;
}
