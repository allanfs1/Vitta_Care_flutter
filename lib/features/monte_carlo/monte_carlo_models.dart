import 'package:flutter/foundation.dart';

import '../../core/models/enums.dart';

/// Versão do rótulo de "falta" (§4 da especificação). Toda métrica histórica
/// precisa ser recalculada quando isto muda — comparar séries com rótulos
/// diferentes é comparar coisas diferentes.
const String kLabelVersion = 'falta-v2.1';

/// Desfecho de uma consulta agendada.
///
/// Três estados, não dois. A distinção importa porque um **cancelamento com
/// antecedência libera a vaga a tempo de ser reocupada**; uma falta não libera
/// nada — a cadeira fica vazia e o horário do médico é perdido.
enum EstadoConsulta {
  comparece('Compareceu'),
  cancela('Cancelou com antecedência'),
  falta('Faltou sem avisar');

  const EstadoConsulta(this.label);
  final String label;
}

/// Qual capacidade serve de referência para o risco de estouro.
///
/// `Doctor.capacityAt()` já devolve `slotLimit + overbook`, ou seja, a clínica
/// pode ter overbooking configurado. Medir o risco contra esse número significa
/// empilhar encaixes **em cima** do overbooking existente.
enum BaseCapacidade {
  /// `slotLimit` — cadeira e tempo de fato disponíveis. Leitura conservadora.
  fisica('Capacidade física (slotLimit)'),

  /// `capacityAt()` — inclui o overbooking já configurado para o médico/período.
  configurada('Capacidade configurada (com overbook)');

  const BaseCapacidade(this.label);
  final String label;
}

/// Como o paciente de encaixe entra na conta de risco.
enum EncaixeModo {
  /// O encaixe comparece com certeza. Limite superior do risco — conservador.
  certo('Comparecimento certo (conservador)'),

  /// O encaixe também pode faltar, com `pFaltaEncaixe`.
  ///
  /// Convolui a distribuição do slot com a Poisson-binomial dos encaixes.
  /// **Ignora o fator comum do dia para os encaixes**, portanto é levemente
  /// otimista: num dia de chuva o encaixe falta junto com os demais. Use os
  /// dois modos como limites inferior e superior, não como estimativa única.
  probabilistico('Encaixe também pode faltar (otimista)');

  const EncaixeModo(this.label);
  final String label;
}

/// Modelo de risco: converte o [RiskLevel] categórico do agendamento nas
/// probabilidades marginais dos três desfechos.
///
/// As taxas são calibráveis por clínica — os padrões abaixo são um ponto de
/// partida, NÃO uma medição. `MonteCarloCalibracao` substitui estes valores
/// pela taxa observada na base real.
@immutable
class ModeloRisco {
  const ModeloRisco({
    this.pBaixo = 0.06,
    this.pMedio = 0.15,
    this.pAlto = 0.32,
    this.pCancelBaixo = 0.03,
    this.pCancelMedio = 0.06,
    this.pCancelAlto = 0.10,
  });

  /// Probabilidade de falta (não comparece, sem avisar) por faixa de risco.
  final double pBaixo;
  final double pMedio;
  final double pAlto;

  /// Probabilidade de cancelamento com antecedência por faixa de risco.
  final double pCancelBaixo;
  final double pCancelMedio;
  final double pCancelAlto;

  double pFaltaDe(RiskLevel r) => switch (r) {
        RiskLevel.low => pBaixo,
        RiskLevel.medium => pMedio,
        RiskLevel.high => pAlto,
      };

  double pCancelDe(RiskLevel r) => switch (r) {
        RiskLevel.low => pCancelBaixo,
        RiskLevel.medium => pCancelMedio,
        RiskLevel.high => pCancelAlto,
      };

  /// Garante que falta + cancelamento não passem de 1 (a sobra é comparecer).
  double pCancelSeguroDe(RiskLevel r) {
    final f = pFaltaDe(r);
    final c = pCancelDe(r);
    final soma = f + c;
    return soma <= 0.999 ? c : (0.999 - f).clamp(0.0, 1.0);
  }

  ModeloRisco copyWith({
    double? pBaixo,
    double? pMedio,
    double? pAlto,
    double? pCancelBaixo,
    double? pCancelMedio,
    double? pCancelAlto,
  }) =>
      ModeloRisco(
        pBaixo: pBaixo ?? this.pBaixo,
        pMedio: pMedio ?? this.pMedio,
        pAlto: pAlto ?? this.pAlto,
        pCancelBaixo: pCancelBaixo ?? this.pCancelBaixo,
        pCancelMedio: pCancelMedio ?? this.pCancelMedio,
        pCancelAlto: pCancelAlto ?? this.pCancelAlto,
      );
}

/// Configuração de uma simulação.
@immutable
class SimulacaoConfig {
  const SimulacaoConfig({
    this.nRuns = 20000,
    this.seed = 42,
    this.rho = 0.03,
    this.modeloRisco = const ModeloRisco(),
    this.baseCapacidade = BaseCapacidade.fisica,
    this.encaixeModo = EncaixeModo.certo,
    this.pFaltaEncaixe = 0.15,
    this.labelVersion = kLabelVersion,
  });

  /// Número de execuções. 20.000 é suficiente: sob rho = 0,03 o erro de Monte
  /// Carlo do P95 já estabiliza aí — 50.000 gasta 2,5x mais para mover um
  /// número que parou.
  final int nRuns;

  /// Semente determinística: a mesma entrada produz o mesmo resultado.
  final int seed;

  /// Correlação latente entre desfechos do mesmo dia.
  ///
  /// `rho = 0` desliga a dependência e reproduz **exatamente** o modelo
  /// independente da v1.0 — nesse caso a distribuição tem forma fechada e o
  /// motor usa a Poisson-binomial exata em vez de simular.
  ///
  /// Valores típicos medidos: 0,02 a 0,05. Sobe em período de chuva, férias
  /// escolares e ondas respiratórias — reestimar semanalmente.
  final double rho;

  final ModeloRisco modeloRisco;

  /// Contra qual capacidade o risco de estouro é medido.
  final BaseCapacidade baseCapacidade;

  /// Como o encaixe entra na conta.
  final EncaixeModo encaixeModo;

  /// Probabilidade de falta atribuída ao paciente de encaixe. Encaixes são
  /// tipicamente pacientes chamados de última hora, com adesão diferente da
  /// média da agenda — por isso é um parâmetro separado.
  final double pFaltaEncaixe;

  final String labelVersion;

  bool get independente => rho <= 0;

  SimulacaoConfig copyWith({
    int? nRuns,
    int? seed,
    double? rho,
    ModeloRisco? modeloRisco,
    BaseCapacidade? baseCapacidade,
    EncaixeModo? encaixeModo,
    double? pFaltaEncaixe,
  }) =>
      SimulacaoConfig(
        nRuns: nRuns ?? this.nRuns,
        seed: seed ?? this.seed,
        rho: rho ?? this.rho,
        modeloRisco: modeloRisco ?? this.modeloRisco,
        baseCapacidade: baseCapacidade ?? this.baseCapacidade,
        encaixeModo: encaixeModo ?? this.encaixeModo,
        pFaltaEncaixe: pFaltaEncaixe ?? this.pFaltaEncaixe,
        labelVersion: labelVersion,
      );
}

/// Uma consulta candidata, já com as probabilidades atribuídas.
@immutable
class ConsultaRisco {
  const ConsultaRisco({
    required this.appointmentId,
    required this.doctorId,
    required this.hour,
    required this.pFalta,
    required this.risco,
    this.pCancel = 0.0,
  });

  final String appointmentId;
  final String doctorId;
  final int hour;

  /// Não comparece e não avisa.
  final double pFalta;

  /// Cancela com antecedência — libera a vaga a tempo.
  final double pCancel;

  final RiskLevel risco;

  double get pComparece => (1 - pFalta - pCancel).clamp(0.0, 1.0);

  /// Chave do slot (médico x hora) — a unidade em que o overbooking realmente
  /// acontece. Uma falta às 16h não libera capacidade para um encaixe às 9h.
  String get slotKey => '$doctorId|$hour';
}

/// Distribuição empírica de uma contagem inteira.
@immutable
class Distribuicao {
  const Distribuicao({
    required this.contagens,
    required this.total,
    required this.media,
    required this.desvio,
  });

  /// `contagens[k]` = número de execuções em que o valor observado foi `k`.
  final List<int> contagens;
  final int total;
  final double media;
  final double desvio;

  /// Quantil empírico. [q] em 0..1.
  int quantil(double q) {
    if (total == 0) return 0;
    final alvo = q * total;
    var acum = 0;
    for (var k = 0; k < contagens.length; k++) {
      acum += contagens[k];
      if (acum >= alvo) return k;
    }
    return contagens.length - 1;
  }

  int get p05 => quantil(0.05);
  int get p25 => quantil(0.25);
  int get p50 => quantil(0.50);
  int get p75 => quantil(0.75);
  int get p95 => quantil(0.95);

  /// P(valor > limite).
  double probAcima(int limite) {
    if (total == 0) return 0;
    if (limite < 0) return 1.0;
    var n = 0;
    for (var k = limite + 1; k < contagens.length; k++) {
      n += contagens[k];
    }
    return n / total;
  }

  /// P(valor >= limite).
  double probPeloMenos(int limite) =>
      limite <= 0 ? 1.0 : probAcima(limite - 1);

  /// Função de distribuição acumulada em `k`: P(valor <= k).
  double cdf(int k) {
    if (total == 0) return 1.0;
    if (k < 0) return 0.0;
    var n = 0;
    final lim = k >= contagens.length ? contagens.length - 1 : k;
    for (var i = 0; i <= lim; i++) {
      n += contagens[i];
    }
    return n / total;
  }

  /// Probabilidade normalizada de observar exatamente `k`.
  double pmf(int k) {
    if (total == 0 || k < 0 || k >= contagens.length) return 0.0;
    return contagens[k] / total;
  }
}

/// Previsão para um slot (médico x hora) — onde o overbooking é decidido.
@immutable
class SlotForecast {
  const SlotForecast({
    required this.doctorId,
    required this.doctorName,
    required this.hour,
    required this.agendados,
    required this.capacidade,
    required this.capacidadeFisica,
    required this.capacidadeConfigurada,
    required this.presentes,
    required this.liberadasComAviso,
    required this.riscoPorEncaixe,
    required this.composicaoRisco,
  });

  final String doctorId;
  final String doctorName;
  final int hour;
  final int agendados;

  /// Capacidade efetivamente usada no cálculo do risco (conforme
  /// `SimulacaoConfig.baseCapacidade`).
  final int capacidade;

  /// `slotLimit` do médico — cadeira e tempo.
  final int capacidadeFisica;

  /// `capacityAt()` — já inclui o overbooking configurado.
  final int capacidadeConfigurada;

  /// Distribuição do número de pacientes que efetivamente comparecem.
  final Distribuicao presentes;

  /// Distribuição das vagas liberadas por cancelamento com antecedência —
  /// as únicas reocupáveis de forma planejada.
  final Distribuicao liberadasComAviso;

  /// `riscoPorEncaixe[k]` = risco de estouro com `k` encaixes neste slot.
  /// Pré-calculado pelo motor porque depende do modo de encaixe.
  final List<double> riscoPorEncaixe;

  /// Quantas consultas do slot estão em cada faixa de risco — insumo da
  /// análise de equidade.
  final Map<RiskLevel, int> composicaoRisco;

  /// Risco de o slot estourar a capacidade com [k] encaixes adicionais.
  double riscoEstouro(int k) {
    if (k < 0) return riscoPorEncaixe.isEmpty ? 0 : riscoPorEncaixe[0];
    if (k < riscoPorEncaixe.length) return riscoPorEncaixe[k];
    return 1.0;
  }

  /// Vagas ociosas esperadas (capacidade não usada), em média.
  double get ociosidadeMedia {
    final livre = capacidade - presentes.media;
    return livre < 0 ? 0 : livre;
  }

  /// Fração de pacientes de alto risco no slot.
  double get fracaoAltoRisco {
    if (agendados == 0) return 0;
    return (composicaoRisco[RiskLevel.high] ?? 0) / agendados;
  }
}

/// Avaliação de um cenário de overbooking (+k encaixes).
@immutable
class CenarioOverbooking {
  const CenarioOverbooking({
    required this.encaixes,
    required this.riscoMaximoSlot,
    required this.slotsAcimaDoLimite,
    required this.receitaEsperada,
    required this.ociosidadeEsperada,
    required this.aprovado,
    required this.motivo,
    required this.alocacao,
    required this.equidade,
  });

  /// Número de encaixes adicionais avaliados.
  final int encaixes;

  /// Maior risco de estouro entre todos os slots — a decisão é limitada pelo
  /// pior slot, não pela média do dia.
  final double riscoMaximoSlot;

  final int slotsAcimaDoLimite;
  final double receitaEsperada;
  final double ociosidadeEsperada;
  final bool aprovado;
  final String motivo;

  /// Quantos encaixes foram alocados em cada slot (mesma ordem de
  /// `SimulacaoResultado.slots`).
  final List<int> alocacao;

  /// Como a carga de overbooking se distribui entre as faixas de risco.
  final EquidadeRelatorio equidade;
}

/// Distribuição da carga de overbooking entre faixas de risco de paciente.
///
/// Overbooking não é neutro: encaixar em um slot aumenta a espera de **todos**
/// os pacientes daquele slot. Se a política concentrar encaixes nos slots com
/// mais pacientes de alto risco — que na base costumam ser os de menor renda e
/// maior distância — ela transfere sistematicamente o custo da eficiência para
/// quem já tem mais barreira de acesso.
@immutable
class EquidadeRelatorio {
  const EquidadeRelatorio({
    required this.exposicaoPorFaixa,
    required this.participacaoPorFaixa,
    required this.razaoMaxima,
    required this.dentroDoLimite,
  });

  /// Encaixes que recaem sobre pacientes de cada faixa, ponderados pela
  /// composição do slot.
  final Map<RiskLevel, double> exposicaoPorFaixa;

  /// Fração da agenda que cada faixa representa.
  final Map<RiskLevel, double> participacaoPorFaixa;

  /// Maior razão entre exposição e participação. `1,0` = carga proporcional;
  /// acima disso, alguma faixa está absorvendo mais overbooking do que a sua
  /// presença na agenda justificaria.
  final double razaoMaxima;

  final bool dentroDoLimite;

  static const EquidadeRelatorio vazio = EquidadeRelatorio(
    exposicaoPorFaixa: {},
    participacaoPorFaixa: {},
    razaoMaxima: 1.0,
    dentroDoLimite: true,
  );
}

/// Recomendação de chamadas da lista de espera (UC-09).
///
/// A fila é a alavanca a ser usada **antes** do overbooking: preencher uma vaga
/// que foi de fato liberada não cria espera para ninguém, enquanto o encaixe
/// especulativo cria. Só o que sobra depois disso deveria virar overbooking.
@immutable
class RecomendacaoFila {
  const RecomendacaoFila({
    required this.chamadasSeguras,
    required this.liberadasP25,
    required this.liberadasP50,
    required this.detalhePorSlot,
  });

  /// Quantos pacientes da fila podem ser chamados com folga — dimensionado
  /// pelo quartil inferior das vagas liberadas, não pela média.
  final int chamadasSeguras;

  final int liberadasP25;
  final int liberadasP50;

  /// Chamadas seguras por slot (`slotKey` → quantidade).
  final Map<String, int> detalhePorSlot;

  static const RecomendacaoFila vazia = RecomendacaoFila(
    chamadasSeguras: 0,
    liberadasP25: 0,
    liberadasP50: 0,
    detalhePorSlot: {},
  );
}

/// Resultado completo de uma simulação do dia.
@immutable
class SimulacaoResultado {
  const SimulacaoResultado({
    required this.data,
    required this.config,
    required this.consultas,
    required this.faltas,
    required this.cancelamentos,
    required this.slots,
    required this.exato,
    required this.duracao,
    required this.phiObservado,
    required this.fila,
  });

  final DateTime data;
  final SimulacaoConfig config;
  final List<ConsultaRisco> consultas;

  /// Distribuição do total de faltas do dia (sem aviso).
  final Distribuicao faltas;

  /// Distribuição do total de cancelamentos com antecedência.
  final Distribuicao cancelamentos;

  final List<SlotForecast> slots;

  /// `true` quando a distribuição veio da forma fechada (Poisson-binomial)
  /// em vez de amostragem — acontece com `rho = 0`, sem erro de amostragem.
  final bool exato;

  final Duration duracao;

  /// Fator de sobredispersão observado: Var[S] / Var_independente[S].
  /// `1,0` significa independência; acima disso há dependência entre faltas.
  final double phiObservado;

  /// Quantos pacientes da lista de espera cabem sem criar overbooking.
  final RecomendacaoFila fila;

  int get totalAgendados => consultas.length;

  /// Soma das probabilidades individuais = faltas esperadas (forma fechada).
  double get faltasEsperadas => consultas.fold(0.0, (s, c) => s + c.pFalta);

  double get cancelamentosEsperados =>
      consultas.fold(0.0, (s, c) => s + c.pCancel);

  /// Slots com risco de estouro acima do limite, sem nenhum encaixe.
  List<SlotForecast> slotsEmRisco(double limite) =>
      slots.where((s) => s.riscoEstouro(0) > limite).toList()
        ..sort((a, b) => b.riscoEstouro(0).compareTo(a.riscoEstouro(0)));

  /// Composição da agenda por faixa de risco.
  Map<RiskLevel, int> get composicaoRisco {
    final m = <RiskLevel, int>{};
    for (final c in consultas) {
      m[c.risco] = (m[c.risco] ?? 0) + 1;
    }
    return m;
  }
}
