/// Equidade e uso responsável do escore de falta.
///
/// Um modelo de falta em saúde não é um modelo de churn. Ele orienta a
/// distribuição de um recurso escasso — atenção — entre pessoas.
///
/// A probabilidade de faltar correlaciona fortemente com transporte, renda,
/// vínculo informal, escolaridade e distância até a unidade. Um modelo bem
/// ajustado aprende esses padrões **mesmo sem receber renda ou raça como
/// variável**, porque bairro, canal de agendamento e histórico funcionam como
/// proxies. Se a plataforma usar o escore para reduzir esforço com quem tem
/// alto risco, ela transfere sistematicamente acesso dos mais vulneráveis para
/// os menos vulneráveis, com aparência de neutralidade técnica.
///
/// Por isso as regras deste arquivo são **executáveis**, não recomendações: o
/// piso de intervenção é verificado em tempo de execução e os usos proibidos
/// lançam exceção. Uma diretriz de treinamento de equipe não sobrevive à
/// próxima refatoração; uma invariante no código, sim.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'risco_calibracao.dart';

// ─────────────────────────────────────────────────────────────────────────
// 8.1 — O piso de intervenção
// ─────────────────────────────────────────────────────────────────────────

/// Canal de contato com o paciente.
enum CanalContato {
  whatsapp('WhatsApp'),
  sms('SMS'),
  ligacao('Ligação');

  const CanalContato(this.label);
  final String label;
}

/// Plano de contato de um agendamento.
///
/// O escore de risco **só escala o esforço**. Ele nunca subtrai serviço: um
/// paciente de alto risco recebe mais lembretes, mais canais e contato mais
/// próximo da data — nunca menos vaga, menos prioridade de reagendamento ou
/// menos tempo de consulta.
@immutable
class PlanoContato {
  const PlanoContato({
    required this.lembretes,
    required this.canais,
    this.reservaVaga = true,
    this.contatoHumano48h = false,
  });

  final int lembretes;
  final List<CanalContato> canais;

  /// A vaga é reservada. **Nunca é `false`** — ver [PisoIntervencao].
  final bool reservaVaga;

  final bool contatoHumano48h;

  /// O piso: o mínimo que todo agendamento recebe, independentemente de escore.
  static const PlanoContato piso = PlanoContato(
    lembretes: 1,
    canais: [CanalContato.whatsapp],
  );

  /// Este plano respeita o piso [base]?
  bool respeitaPiso(PlanoContato base) =>
      reservaVaga &&
      lembretes >= base.lembretes &&
      base.canais.every(canais.contains);

  @override
  String toString() => 'PlanoContato(lembretes: $lembretes, '
      'canais: ${canais.map((c) => c.label).join(', ')}, '
      'reservaVaga: $reservaVaga, contatoHumano48h: $contatoHumano48h)';
}

/// Lançada quando um plano de contato ficaria abaixo do piso.
class PisoIntervencaoViolado implements Exception {
  PisoIntervencaoViolado(this.motivo, this.plano, this.piso);

  final String motivo;
  final PlanoContato plano;
  final PlanoContato piso;

  @override
  String toString() => 'PisoIntervencaoViolado: $motivo\n'
      '  plano: $plano\n  piso:  $piso';
}

/// O piso de intervenção como invariante executável.
class PisoIntervencao {
  const PisoIntervencao._();

  /// Limiar de risco moderado — acima dele o esforço sobe um degrau.
  static const double limiarModerado = 0.30;

  /// Limiar de risco alto — acima dele entra contato humano.
  static const double limiarAlto = 0.55;

  /// Monta o plano de contato a partir do escore.
  ///
  /// O escore só **acrescenta** esforço; o resultado é validado contra o piso
  /// antes de sair da função. A validação usa exceção e não `assert` de
  /// propósito: `assert` é removido em build de release, e é exatamente em
  /// produção que a invariante precisa valer.
  static PlanoContato plano(double escoreRisco,
      {PlanoContato piso = PlanoContato.piso}) {
    var lembretes = piso.lembretes;
    final canais = <CanalContato>{...piso.canais};
    var humano = piso.contatoHumano48h;

    if (escoreRisco >= limiarModerado) {
      lembretes = math.max(lembretes, 2);
      canais.addAll([CanalContato.whatsapp, CanalContato.sms]);
    }
    if (escoreRisco >= limiarAlto) {
      lembretes = math.max(lembretes, 3);
      canais.addAll(CanalContato.values);
      humano = true;
    }

    final resultado = PlanoContato(
      lembretes: lembretes,
      canais: canais.toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
      contatoHumano48h: humano,
    );
    return validar(resultado, piso: piso);
  }

  /// Verifica a invariante e devolve o próprio plano, para encadear.
  ///
  /// Use ao receber um plano de fora — de configuração, de outro módulo ou do
  /// banco. O piso precisa valer para todo plano que chega ao paciente, não só
  /// para os que esta classe montou.
  static PlanoContato validar(PlanoContato plano,
      {PlanoContato piso = PlanoContato.piso}) {
    if (!plano.reservaVaga) {
      throw PisoIntervencaoViolado(
          'a vaga nunca é retirada por risco', plano, piso);
    }
    if (plano.lembretes < piso.lembretes) {
      throw PisoIntervencaoViolado(
          'o escore não pode reduzir o número de lembretes', plano, piso);
    }
    if (!piso.canais.every(plano.canais.contains)) {
      throw PisoIntervencaoViolado(
          'o escore não pode remover um canal do piso', plano, piso);
    }
    return plano;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 8.2 — Usos proibidos
// ─────────────────────────────────────────────────────────────────────────

/// Para que o escore está sendo pedido.
///
/// Enumerar o uso na chamada obriga quem consome o escore a declarar a
/// finalidade — e é a declaração que torna o bloqueio possível. Um escore que
/// circula sem finalidade declarada acaba, mais cedo ou mais tarde, num uso que
/// ninguém aprovou.
enum UsoEscore {
  priorizarContato('Priorizar esforço de contato', true, ''),
  dimensionarLembretes('Dimensionar lembretes e canais', true, ''),
  projetarCenario('Projetar cenário agregado', true, ''),
  monitorarEquidade('Monitorar equidade por subgrupo', true, ''),

  negarAgendamento(
    'Negar ou condicionar agendamento',
    false,
    'Restringe acesso a serviço de saúde por predição estatística sobre a '
        'pessoa.',
  ),
  overbookingSobreAltoRisco(
    'Sobrepor agendamentos em cima de alto risco',
    false,
    'Se o paciente comparece, ele espera ou é dispensado — a penalidade recai '
        'sobre quem já tem menos acesso.',
  ),
  exibirAoPaciente(
    'Exibir o escore ao paciente',
    false,
    'Não é diagnóstico, não é acionável por ele e estigmatiza.',
  ),
  exibirNoAtendimento(
    'Exibir o escore ao profissional durante o atendimento',
    false,
    'Contamina a decisão clínica com uma predição administrativa.',
  ),
  cobrarTaxa(
    'Cobrar taxa ou penalidade calculada do escore',
    false,
    'Converte predição em sanção financeira antes de qualquer fato.',
  ),
  elegibilidadeDePlano(
    'Decidir contratação de plano ou elegibilidade',
    false,
    'Uso fora da finalidade declarada; problema direto de LGPD.',
  );

  const UsoEscore(this.label, this.permitido, this.porQueProibido);

  final String label;
  final bool permitido;

  /// Vazio quando o uso é permitido.
  final String porQueProibido;

  static List<UsoEscore> get proibidos =>
      values.where((u) => !u.permitido).toList();

  static List<UsoEscore> get permitidos =>
      values.where((u) => u.permitido).toList();
}

/// Lançada quando o escore é pedido para um uso proibido.
class UsoProibidoDoEscore implements Exception {
  UsoProibidoDoEscore(this.uso);

  final UsoEscore uso;

  @override
  String toString() =>
      'UsoProibidoDoEscore: ${uso.label}. ${uso.porQueProibido}';
}

/// Porta única de acesso ao escore de risco.
class GuardaEscore {
  const GuardaEscore._();

  /// Devolve o escore se a finalidade for permitida; lança se não for.
  ///
  /// Chame isto no ponto em que o escore sai do modelo para o resto do
  /// aplicativo. Documentar os usos proibidos numa tabela não impede nenhum
  /// deles; uma exceção, sim.
  static double liberar(double escore, UsoEscore uso) {
    if (!uso.permitido) throw UsoProibidoDoEscore(uso);
    return escore;
  }

  static bool permitido(UsoEscore uso) => uso.permitido;
}

// ─────────────────────────────────────────────────────────────────────────
// 8.3 — Métricas de equidade por subgrupo
// ─────────────────────────────────────────────────────────────────────────

/// Uma observação usada para medir equidade.
@immutable
class ObservacaoEquidade {
  const ObservacaoEquidade({
    required this.subgrupo,
    required this.escore,
    required this.faltou,
    this.intervencaoAplicada = false,
  });

  /// Unidade, faixa etária, território — o eixo que se quer monitorar.
  final String subgrupo;

  final double escore;
  final bool faltou;
  final bool intervencaoAplicada;
}

/// Desempenho do modelo dentro de um subgrupo.
@immutable
class MetricaSubgrupo {
  const MetricaSubgrupo({
    required this.subgrupo,
    required this.n,
    required this.ece,
    required this.recall,
    required this.taxaIntervencao,
    required this.taxaFalta,
    this.taxaFaltaBaseline,
  });

  final String subgrupo;
  final int n;

  /// Calibração dentro do subgrupo. Um modelo com PR-AUC global excelente pode
  /// ser sistematicamente pior calibrado para uma unidade específica.
  final double ece;

  /// O modelo identifica alto risco tão bem aqui quanto nos outros grupos?
  final double recall;

  /// Quem está de fato recebendo o esforço adicional.
  final double taxaIntervencao;

  /// Taxa de falta observada no período.
  final double taxaFalta;

  /// Taxa de falta antes da intervenção, quando conhecida.
  final double? taxaFaltaBaseline;

  /// Amostra suficiente para que a métrica de calibração signifique algo.
  bool get amostraSuficiente => n >= 300;

  /// Este subgrupo saiu **pior** do que entrou?
  ///
  /// É a pergunta mais importante das quatro: um piloto pode reduzir a falta
  /// agregada em 20% concentrando todo o ganho em quem já comparecia mais.
  /// Tecnicamente é sucesso; em saúde pública é o contrário do objetivo.
  bool get piorouEmRelacaoAoBaseline {
    final base = taxaFaltaBaseline;
    if (base == null) return false;
    return taxaFalta > base + 1e-9;
  }
}

/// Painel de equidade — o agregado esconde o que este painel mostra.
@immutable
class PainelEquidade {
  const PainelEquidade({
    required this.subgrupos,
    required this.limiarAltoRisco,
    this.limiteEce = 0.05,
    this.limiteRazaoRecall = 1.25,
  });

  final List<MetricaSubgrupo> subgrupos;
  final double limiarAltoRisco;

  /// ECE ≤ 0,05 em todo subgrupo com n ≥ 300.
  final double limiteEce;

  /// Razão entre maior e menor recall ≤ 1,25.
  final double limiteRazaoRecall;

  List<MetricaSubgrupo> get comAmostraSuficiente =>
      subgrupos.where((s) => s.amostraSuficiente).toList();

  /// Subgrupos cuja calibração está fora do critério — só entre os que têm
  /// amostra para sustentar a afirmação.
  List<MetricaSubgrupo> get eceForaDoCriterio =>
      comAmostraSuficiente.where((s) => s.ece > limiteEce).toList();

  /// Razão entre o maior e o menor recall. Acima do limite, o modelo enxerga
  /// risco melhor em uns grupos que em outros — e o esforço segue essa visão.
  double get razaoRecall {
    final rs = comAmostraSuficiente.map((s) => s.recall).toList();
    if (rs.length < 2) return 1.0;
    final maior = rs.reduce(math.max);
    final menor = rs.reduce(math.min);
    if (menor <= 0) return double.infinity;
    return maior / menor;
  }

  bool get recallEquilibrado => razaoRecall <= limiteRazaoRecall;

  List<MetricaSubgrupo> get subgruposQuePioraram =>
      subgrupos.where((s) => s.piorouEmRelacaoAoBaseline).toList();

  bool get nenhumSubgrupoPior => subgruposQuePioraram.isEmpty;

  /// O painel inteiro aprova?
  bool get aprovado =>
      eceForaDoCriterio.isEmpty && recallEquilibrado && nenhumSubgrupoPior;

  /// Diferença entre a maior e a menor taxa de intervenção. Divergência não é
  /// defeito por si — exige justificativa clínica registrada.
  double get amplitudeIntervencao {
    if (subgrupos.isEmpty) return 0;
    final ts = subgrupos.map((s) => s.taxaIntervencao).toList();
    return ts.reduce(math.max) - ts.reduce(math.min);
  }

  static const PainelEquidade vazio =
      PainelEquidade(subgrupos: [], limiarAltoRisco: 0.55);
}

/// Cálculo das métricas de equidade.
class Equidade {
  const Equidade._();

  /// Mede desempenho por subgrupo, não apenas no agregado.
  ///
  /// [faltaBaseline] traz a taxa de falta de cada subgrupo antes da
  /// intervenção; sem ela a última — e mais importante — verificação fica
  /// indisponível, e o painel diz isso em vez de fingir que passou.
  static PainelEquidade medir(
    List<ObservacaoEquidade> obs, {
    double limiarAltoRisco = PisoIntervencao.limiarAlto,
    Map<String, double> faltaBaseline = const {},
    double limiteEce = 0.05,
    double limiteRazaoRecall = 1.25,
    int nFaixasEce = 10,
  }) {
    final porGrupo = <String, List<ObservacaoEquidade>>{};
    for (final o in obs) {
      porGrupo.putIfAbsent(o.subgrupo, () => []).add(o);
    }

    final metricas = <MetricaSubgrupo>[];
    for (final e in porGrupo.entries) {
      final grupo = e.value;
      final n = grupo.length;
      if (n == 0) continue;

      final escores = [for (final o in grupo) o.escore];
      final desfechos = [for (final o in grupo) o.faltou ? 1 : 0];

      var faltas = 0;
      var faltasCapturadas = 0;
      var comIntervencao = 0;
      for (final o in grupo) {
        if (o.faltou) {
          faltas++;
          if (o.escore >= limiarAltoRisco) faltasCapturadas++;
        }
        if (o.intervencaoAplicada) comIntervencao++;
      }

      metricas.add(MetricaSubgrupo(
        subgrupo: e.key,
        n: n,
        ece: RiscoCalibracao.ece(escores, desfechos, nFaixas: nFaixasEce),
        // Recall na faixa de alto risco: das faltas que aconteceram, quantas o
        // modelo tinha sinalizado. Sem faltas no período não há recall a medir,
        // e 1,0 seria uma afirmação que o dado não sustenta — usa-se 0 e a
        // amostra insuficiente cuida do resto.
        recall: faltas == 0 ? 0.0 : faltasCapturadas / faltas,
        taxaIntervencao: comIntervencao / n,
        taxaFalta: faltas / n,
        taxaFaltaBaseline: faltaBaseline[e.key],
      ));
    }

    metricas.sort((a, b) => a.subgrupo.compareTo(b.subgrupo));
    return PainelEquidade(
      subgrupos: metricas,
      limiarAltoRisco: limiarAltoRisco,
      limiteEce: limiteEce,
      limiteRazaoRecall: limiteRazaoRecall,
    );
  }
}
