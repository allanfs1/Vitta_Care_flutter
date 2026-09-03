import 'package:flutter/foundation.dart';

import 'projecao_amostradores.dart';

/// Intensidade do pacote de intervenção.
enum IntensidadeCenario {
  conservador('Conservador'),
  base('Base'),
  agressivo('Agressivo');

  const IntensidadeCenario(this.label);
  final String label;
}

/// De onde veio cada hipótese de impacto.
///
/// Existe para que o número apresentado ao cliente possa ser reconstruído
/// depois. Uma projeção sem procedência é uma promessa.
enum OrigemHipotese {
  hipoteseSetorial('Hipótese conservadora setorial'),
  pilotoInterno('Piloto interno medido'),
  literatura('Literatura publicada'),
  arbitrada('Arbitrada — sem evidência');

  const OrigemHipotese(this.label);
  final String label;
}

/// Parâmetros de intervenção, **por mecanismo**.
///
/// Nunca um delta global único: separar por mecanismo deixa o cenário auditável
/// e permite substituir cada parâmetro por efeito medido, um a um, conforme a
/// evidência chega.
@immutable
class ParametrosIntervencao {
  const ParametrosIntervencao({
    this.reducaoFalta = 0.20,
    this.reducaoCancelamento = 0.15,
    this.deltaConfirmacao = 0.10,
    this.taxaReposicaoVaga = 0.05,
    this.fracaoReagendamento = 0.40,
    this.origemReducaoFalta = OrigemHipotese.hipoteseSetorial,
    this.origemConfirmacao = OrigemHipotese.hipoteseSetorial,
  });

  /// Redução relativa da taxa de falta (0,20 = −20% da taxa).
  ///
  /// Aceita valor **negativo**: quando o piloto mede o efeito e ele sai contra,
  /// o cenário precisa saber dizer isso. Um motor que só representa melhora
  /// transforma "piorou" em "não fez diferença".
  final double reducaoFalta;

  /// Redução relativa da taxa de cancelamento. Também aceita valor negativo.
  final double reducaoCancelamento;

  /// Acréscimo relativo de confirmação na janela em que a intervenção age.
  final double deltaConfirmacao;

  /// Fração das vagas liberadas que é efetivamente reposta.
  final double taxaReposicaoVaga;

  /// Fração da massa recuperada de falta e cancelamento que vira
  /// **reagendamento** em vez de comparecimento direto.
  ///
  /// Reagendar não é cancelar: preserva o paciente no sistema **e** devolve a
  /// vaga. Sem este parâmetro a cadeia nunca alcança o estado `reagendado` —
  /// e some da tela justamente o desfecho que a intervenção mais tenta
  /// produzir, o que faz o benefício parecer menor do que é.
  final double fracaoReagendamento;

  final OrigemHipotese origemReducaoFalta;
  final OrigemHipotese origemConfirmacao;

  /// Pacote pré-definido por intensidade.
  static ParametrosIntervencao de(IntensidadeCenario i) => switch (i) {
        IntensidadeCenario.conservador => const ParametrosIntervencao(
            reducaoFalta: 0.10,
            reducaoCancelamento: 0.07,
            deltaConfirmacao: 0.05,
            taxaReposicaoVaga: 0.02,
          ),
        IntensidadeCenario.base => const ParametrosIntervencao(),
        IntensidadeCenario.agressivo => const ParametrosIntervencao(
            reducaoFalta: 0.32,
            reducaoCancelamento: 0.24,
            deltaConfirmacao: 0.18,
            taxaReposicaoVaga: 0.09,
          ),
      };

  ParametrosIntervencao copyWith({
    double? reducaoFalta,
    double? reducaoCancelamento,
    double? deltaConfirmacao,
    double? taxaReposicaoVaga,
    double? fracaoReagendamento,
  }) =>
      ParametrosIntervencao(
        reducaoFalta: reducaoFalta ?? this.reducaoFalta,
        reducaoCancelamento: reducaoCancelamento ?? this.reducaoCancelamento,
        deltaConfirmacao: deltaConfirmacao ?? this.deltaConfirmacao,
        taxaReposicaoVaga: taxaReposicaoVaga ?? this.taxaReposicaoVaga,
        fracaoReagendamento: fracaoReagendamento ?? this.fracaoReagendamento,
        origemReducaoFalta: origemReducaoFalta,
        origemConfirmacao: origemConfirmacao,
      );
}

/// Configuração de uma projeção de 12 meses.
@immutable
class ProjecaoConfig {
  const ProjecaoConfig({
    this.horizonteMeses = 12,
    this.agendamentosMensais = 1190,
    this.capacidadeMensal = 1300,
    this.valorConsulta = 150.0,
    this.taxaFalta = 0.22,
    this.taxaCancelamento = 0.09,
    this.wapeForecast = 0.12,
    this.rhoForecast = 0.15,
    this.nHistorico = 800,
    this.fracaoDemandaNova = 0.35,
    this.nSimulacoes = 4000,
    this.seed = 42,
    this.intensidade = IntensidadeCenario.base,
    this.intervencao = const ParametrosIntervencao(),
    this.calibradoComDadosReais = false,
  });

  final int horizonteMeses;

  /// Volume mensal previsto de agendamentos (saída do forecast).
  final int agendamentosMensais;

  /// Teto físico da agenda. **A intervenção não cria capacidade.**
  final int capacidadeMensal;

  final double valorConsulta;

  /// Taxas condicionais observadas no histórico.
  final double taxaFalta;
  final double taxaCancelamento;

  /// Erro percentual do forecast — alimenta a camada (1) de incerteza.
  final double wapeForecast;

  /// Fração da variância do erro de forecast que **persiste ao longo do
  /// horizonte**, em vez de se renovar a cada mês.
  ///
  /// Erro de previsão não é ruído branco: parte dele é de nível — a série
  /// inteira no patamar errado — e acompanha os doze meses. Tratar tudo como
  /// independente faz a banda anual valer `WAPE/√12`, ou seja, 3,46× mais
  /// estreita do que o próprio WAPE do modelo autoriza. O padrão de 0,15 é o
  /// valor que reproduz a saída ilustrativa da especificação; `0` reproduz a
  /// hipótese de independência, e nesse caso a tela precisa dizer isso.
  final double rhoForecast;

  /// Número de desfechos observados que sustentam as taxas. É a força do prior
  /// Beta: quanto maior, mais estreita a camada (2) de incerteza.
  final int nHistorico;

  /// Fração das vagas repostas ocupada por pacientes que **não** seriam
  /// atendidos dentro do horizonte. Deve ser medida, não arbitrada.
  final double fracaoDemandaNova;

  final int nSimulacoes;
  final int seed;

  final IntensidadeCenario intensidade;
  final ParametrosIntervencao intervencao;

  /// Enquanto `false`, toda projeção é hipótese — e o painel precisa dizer.
  final bool calibradoComDadosReais;

  ProjecaoConfig copyWith({
    int? horizonteMeses,
    int? agendamentosMensais,
    int? capacidadeMensal,
    double? valorConsulta,
    double? taxaFalta,
    double? taxaCancelamento,
    double? wapeForecast,
    double? rhoForecast,
    int? nHistorico,
    double? fracaoDemandaNova,
    int? nSimulacoes,
    int? seed,
    IntensidadeCenario? intensidade,
    ParametrosIntervencao? intervencao,
  }) =>
      ProjecaoConfig(
        horizonteMeses: horizonteMeses ?? this.horizonteMeses,
        agendamentosMensais: agendamentosMensais ?? this.agendamentosMensais,
        capacidadeMensal: capacidadeMensal ?? this.capacidadeMensal,
        valorConsulta: valorConsulta ?? this.valorConsulta,
        taxaFalta: taxaFalta ?? this.taxaFalta,
        taxaCancelamento: taxaCancelamento ?? this.taxaCancelamento,
        wapeForecast: wapeForecast ?? this.wapeForecast,
        rhoForecast: rhoForecast ?? this.rhoForecast,
        nHistorico: nHistorico ?? this.nHistorico,
        fracaoDemandaNova: fracaoDemandaNova ?? this.fracaoDemandaNova,
        nSimulacoes: nSimulacoes ?? this.nSimulacoes,
        seed: seed ?? this.seed,
        intensidade: intensidade ?? this.intensidade,
        intervencao: intervencao ?? this.intervencao,
        calibradoComDadosReais: calibradoComDadosReais,
      );
}

/// Resultado de um cenário sobre o horizonte inteiro.
@immutable
class ResultadoCenario {
  const ResultadoCenario({
    required this.agendamentos,
    required this.comparecimentos,
    required this.faltas,
    required this.cancelamentos,
    required this.vagasRepostas,
    required this.demandaReprimida,
    required this.mesesComDemandaReprimida,
    required this.probabilidadeEstouro,
    required this.porMes,
    required this.porMesPercentis,
    required this.demandaPorMes,
  });

  final Percentis agendamentos;
  final Percentis comparecimentos;
  final Percentis faltas;
  final Percentis cancelamentos;

  /// Vagas liberadas por cancelamento que foram efetivamente reocupadas.
  ///
  /// Contadas dentro da replicação, não inferidas da diferença de medianas
  /// entre cenários: reposição é um mecanismo, e um mecanismo se mede, não se
  /// deduz da sobra de outra conta.
  final Percentis vagasRepostas;

  /// O que não coube na capacidade. **É resultado de negócio, não erro da
  /// simulação** — justifica ampliar agenda.
  final Percentis demandaReprimida;

  /// Número mediano de meses, dentro de uma replicação, em que a demanda
  /// estourou o teto.
  ///
  /// Contar "meses em que mais de 5% das replicações estouraram" produzia uma
  /// métrica degenerada: como todo mês tem a mesma distribuição, o valor só
  /// podia ser 0 ou 12. Aqui a contagem acontece **dentro** de cada replicação
  /// e só depois se tira a mediana, o que varia continuamente com a capacidade.
  final double mesesComDemandaReprimida;

  /// Probabilidade de estourar o teto em pelo menos um mês do horizonte.
  final double probabilidadeEstouro;

  /// Mediana de comparecimentos mês a mês, para o gráfico.
  final List<int> porMes;

  /// Percentis (P05, P50, P95) de comparecimentos por mês — para bandas de
  /// confiança.
  final List<Percentis> porMesPercentis;

  /// Fração de replicações que estouram o teto em cada mês — para heatmap
  /// de risco de capacidade.
  final List<double> demandaPorMes;

  Map<String, Object?> toJson() => {
        'agendamentos_12m': agendamentos.toMap(),
        'comparecimentos_12m': comparecimentos.toMap(),
        'faltas_12m': faltas.toMap(),
        'cancelamentos_12m': cancelamentos.toMap(),
        'vagas_repostas_12m': vagasRepostas.toMap(),
      };
}

/// Decomposição do ganho financeiro.
///
/// Uma vaga reposta preenchida por paciente que já estava na base e seria
/// atendido no mês seguinte **não é receita nova**: é antecipação de demanda.
/// No horizonte ela aparece uma vez, não duas.
@immutable
class ImpactoFinanceiro {
  const ImpactoFinanceiro({
    required this.consultasFaltaEvitada,
    required this.consultasDemandaNova,
    required this.consultasAntecipadas,
    required this.receitaDefensavel,
    required this.receitaAntecipacao,
  });

  final double consultasFaltaEvitada;
  final double consultasDemandaNova;
  final double consultasAntecipadas;

  /// O que pode ser apresentado como ganho.
  final double receitaDefensavel;

  /// O que existe, mas já existiria — reportado à parte, nunca somado.
  final double receitaAntecipacao;

  double get receitaTotalBruta => receitaDefensavel + receitaAntecipacao;

  /// Quanto a conta ingênua (tudo como receita nova) superestimaria.
  double get superestimativaIngenua =>
      receitaDefensavel <= 0 ? 0 : receitaTotalBruta / receitaDefensavel - 1;

  /// A intervenção piorou o resultado.
  ///
  /// Precisa ser representável: é exatamente o desfecho que a fase de
  /// calibração existe para detectar, e um painel que mostra zero tanto para
  /// "não fez diferença" quanto para "causou mil faltas a mais" não permite
  /// descobrir isso.
  bool get houvePerda => consultasFaltaEvitada < 0;

  Map<String, Object?> toJson() => {
        'consultas_falta_evitada': consultasFaltaEvitada,
        'consultas_demanda_nova': consultasDemandaNova,
        'consultas_antecipadas': consultasAntecipadas,
        'receita_defensavel_12m': receitaDefensavel,
        'receita_antecipacao_12m': receitaAntecipacao,
      };

  static const ImpactoFinanceiro zero = ImpactoFinanceiro(
    consultasFaltaEvitada: 0,
    consultasDemandaNova: 0,
    consultasAntecipadas: 0,
    receitaDefensavel: 0,
    receitaAntecipacao: 0,
  );
}

/// Resultado completo da projeção: os dois cenários lado a lado.
@immutable
class ProjecaoResultado {
  const ProjecaoResultado({
    required this.config,
    required this.baseline,
    required this.agendaClinica,
    required this.impacto,
    required this.faltasEvitadas,
    required this.cancelamentosEvitados,
    required this.duracao,
    required this.absorcaoBaseline,
    required this.absorcaoIntervencao,
  });

  final ProjecaoConfig config;

  /// Cenário A — continuidade.
  final ResultadoCenario baseline;

  /// Cenário B — com Agenda Clínica.
  final ResultadoCenario agendaClinica;

  final ImpactoFinanceiro impacto;

  final Percentis faltasEvitadas;
  final Percentis cancelamentosEvitados;

  final Duration duracao;

  /// Probabilidades de absorção da cadeia, antes e depois da intervenção.
  final Map<String, double> absorcaoBaseline;
  final Map<String, double> absorcaoIntervencao;

  /// Largura relativa do intervalo de comparecimentos — a medida que o defeito
  /// D1 estreitava indevidamente.
  double get larguraRelativa {
    final p50 = baseline.comparecimentos.p50;
    if (p50 == 0) return 0;
    return baseline.comparecimentos.largura / p50;
  }

  /// A seção 5.3 manda **reportar sempre** as duas grandezas — teto e o que
  /// não coube. Basta a cauda existir; não é preciso que a mediana estoure.
  bool get temDemandaReprimida =>
      baseline.demandaReprimida.p95 > 0 ||
      agendaClinica.demandaReprimida.p95 > 0;

  /// Saída auditável da projeção — o formato da seção 7.
  ///
  /// Existe para que **qualquer número apresentado ao cliente possa ser
  /// reconstruído depois**. Por isso as premissas viajam junto com o resultado:
  /// um intervalo sem a procedência das hipóteses que o geraram é uma promessa
  /// disfarçada de projeção.
  ///
  /// [geradoEm] é injetado pelo chamador em vez de lido do relógio aqui, para
  /// que o resultado continue puro e reproduzível em teste.
  Map<String, Object?> toJson({DateTime? geradoEm}) => {
        'meta': {
          if (geradoEm != null) 'gerado_em': geradoEm.toUtc().toIso8601String(),
          'horizonte_meses': config.horizonteMeses,
          'n_simulacoes': config.nSimulacoes,
          'seed': config.seed,
          'wape_forecast': config.wapeForecast,
          'rho_forecast': config.rhoForecast,
          'n_historico': config.nHistorico,
          'duracao_ms': duracao.inMilliseconds,
        },
        'baseline': baseline.toJson(),
        'agenda_clinica': agendaClinica.toJson(),
        'impacto': {
          'faltas_evitadas': faltasEvitadas.toMap(),
          'cancelamentos_evitados': cancelamentosEvitados.toMap(),
          ...impacto.toJson(),
        },
        'restricoes': {
          'capacidade_mensal': config.capacidadeMensal,
          'meses_com_demanda_reprimida':
              agendaClinica.mesesComDemandaReprimida,
          'probabilidade_estouro': agendaClinica.probabilidadeEstouro,
          'demanda_reprimida_12m': agendaClinica.demandaReprimida.toMap(),
        },
        'premissas': {
          'intensidade': config.intensidade.name,
          'reducao_falta': config.intervencao.reducaoFalta,
          'reducao_cancelamento': config.intervencao.reducaoCancelamento,
          'delta_confirmacao': config.intervencao.deltaConfirmacao,
          'taxa_reposicao_vaga': config.intervencao.taxaReposicaoVaga,
          'origem_reducao_falta': config.intervencao.origemReducaoFalta.name,
          'origem_delta_confirmacao': config.intervencao.origemConfirmacao.name,
          'fracao_demanda_nova': config.fracaoDemandaNova,
          'valor_consulta': config.valorConsulta,
          'taxa_falta_historica': config.taxaFalta,
          'taxa_cancelamento_historica': config.taxaCancelamento,
          'calibrado_com_dados_reais': config.calibradoComDadosReais,
        },
        'aviso': 'Projeção probabilística. Não constitui garantia de '
            'resultado.',
      };
}

/// Resultado do portão de aceite do forecast.
///
/// Um projeto de forecasting sem esse portão costuma entregar complexidade sem
/// ganho, e ninguém percebe porque ninguém mediu a alternativa.
@immutable
class PortaoAceite {
  const PortaoAceite({
    required this.wapeModelo,
    required this.wapeBaseline,
    required this.ganhoRelativo,
    required this.aprovado,
    required this.baselineVencedor,
    required this.pontosComparados,
  });

  final double wapeModelo;
  final double wapeBaseline;
  final double ganhoRelativo;
  final bool aprovado;

  /// Qual baseline trivial o modelo teve de bater.
  final String baselineVencedor;

  /// Sobre quantos pontos a comparação foi feita.
  ///
  /// Um portão aprovado sobre três meses não é o mesmo que um portão aprovado
  /// sobre dois anos, e quem lê o veredito precisa saber qual dos dois recebeu.
  final int pontosComparados;

  String get veredito {
    if (pontosComparados == 0) {
      return 'Sem janela de validação comparável: não há como afirmar que o '
          'modelo vence o baseline trivial.';
    }
    final pct = (ganhoRelativo * 100);
    if (aprovado) {
      return 'O modelo reduz o WAPE em ${pct.toStringAsFixed(1)}% sobre o '
          '$baselineVencedor, em $pontosComparados ponto(s). Aprovado.';
    }
    return 'Ganho de ${pct.toStringAsFixed(1)}% sobre o $baselineVencedor em '
        '$pontosComparados ponto(s) — abaixo do mínimo. Implante o baseline: '
        'é mais barato, mais estável e explicável em uma frase.';
  }
}
