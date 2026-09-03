import 'dart:math' as math;

import '../../core/models/appointment.dart';
import '../../core/models/enums.dart';
import 'monte_carlo_engine.dart';
import 'monte_carlo_metrics.dart';
import 'monte_carlo_models.dart';

/// Taxa observada de um desfecho numa faixa de risco, com intervalo de Wilson.
///
/// O intervalo importa: uma taxa de 32% medida em 9 consultas não é a mesma
/// informação que 32% medida em 900, e usar as duas do mesmo jeito é como o
/// modelo passa a fingir precisão que não tem.
class TaxaObservada {
  const TaxaObservada({
    required this.risco,
    required this.total,
    required this.faltas,
    required this.cancelamentos,
  });

  final RiskLevel risco;
  final int total;
  final int faltas;
  final int cancelamentos;

  double get taxaFalta => total == 0 ? 0 : faltas / total;
  double get taxaCancelamento => total == 0 ? 0 : cancelamentos / total;

  /// Metade da largura do intervalo de Wilson 95% para a taxa de falta.
  /// Wilson e não Wald: com poucas observações ou taxa perto de 0, o Wald
  /// produz limites fora de [0,1].
  (double, double) get ic95Falta => _wilson(faltas, total);

  static (double, double) _wilson(int sucessos, int n) {
    if (n == 0) return (0, 1);
    const z = 1.959963985;
    final p = sucessos / n;
    final den = 1 + z * z / n;
    final centro = (p + z * z / (2 * n)) / den;
    final margem =
        z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den;
    return ((centro - margem).clamp(0.0, 1.0), (centro + margem).clamp(0.0, 1.0));
  }

  /// Amostra suficiente para substituir o padrão do modelo.
  bool get confiavel => total >= 50;
}

/// Severidade de um achado de integridade dos dados.
enum GravidadeAchado {
  /// Impede usar a calibração. O número medido não descreve a clínica.
  bloqueante,

  /// Não impede, mas muda a leitura.
  alerta,
}

/// Um problema encontrado nos dados de entrada, não no modelo.
class AchadoIntegridade {
  const AchadoIntegridade({
    required this.titulo,
    required this.detalhe,
    required this.gravidade,
    this.acao = '',
  });

  final String titulo;
  final String detalhe;
  final GravidadeAchado gravidade;

  /// O que precisa acontecer no produto para destravar.
  final String acao;

  bool get bloqueia => gravidade == GravidadeAchado.bloqueante;
}

/// Verifica se a entrada tem forma de dado real antes de deixar calibrar.
///
/// Existe porque um estimador honesto sobre uma base enviesada devolve um
/// número honesto sobre uma clínica que não existe. Taxa de falta de 68% com
/// zero atendimentos "realizados" não é uma clínica ruim: é uma base que só
/// registra fracasso.
class IntegridadeDados {
  const IntegridadeDados({required this.achados});

  final List<AchadoIntegridade> achados;

  static const IntegridadeDados ok = IntegridadeDados(achados: []);

  bool get temBloqueio => achados.any((a) => a.bloqueia);
  List<AchadoIntegridade> get bloqueios =>
      achados.where((a) => a.bloqueia).toList();
  List<AchadoIntegridade> get alertas =>
      achados.where((a) => !a.bloqueia).toList();
}

/// Contribuição de um dia para a estimativa de dispersão.
///
/// Guardar por dia (em vez de só a média) é o que permite reamostrar para obter
/// intervalo de confiança e recortar por mês sem reprocessar o histórico.
class DiaDispersao {
  const DiaDispersao({
    required this.mes,
    required this.phi,
    required this.rho,
  });

  final int mes;
  final double phi;
  final double rho;
}

/// Sobredispersão de um mês.
class DispersaoMensal {
  const DispersaoMensal({
    required this.mes,
    required this.phi,
    required this.rho,
    required this.dias,
  });

  final int mes;
  final double phi;
  final double rho;
  final int dias;

  static const List<String> nomes = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  String get nome => (mes >= 1 && mes <= 12) ? nomes[mes - 1] : '?';
}

/// Resultado da calibração (fase F2 do plano de implantação).
class CalibracaoResultado {
  const CalibracaoResultado({
    required this.taxas,
    required this.modeloCalibrado,
    required this.phi,
    required this.rhoEstimado,
    required this.diasAnalisados,
    required this.consultasAnalisadas,
    required this.avisos,
    required this.backtest,
    required this.integridade,
    required this.rhoIc95,
    required this.porMes,
  });

  /// Taxas observadas por faixa de risco.
  final Map<RiskLevel, TaxaObservada> taxas;

  /// Modelo de risco com as taxas medidas — só substitui o padrão nas faixas
  /// com amostra suficiente.
  final ModeloRisco modeloCalibrado;

  /// Sobredispersão observada: média dos resíduos padronizados ao quadrado.
  /// `1,0` = independência. Acima disso, as faltas se movem juntas.
  final double phi;

  /// Correlação latente implícita em [phi], para alimentar `SimulacaoConfig`.
  final double rhoEstimado;

  /// Intervalo de 95% do rho, por reamostragem de dias.
  ///
  /// Um módulo cuja tese é "propague a incerteza" não pode entregar o
  /// parâmetro de dependência como número seco. Se o intervalo contém zero, a
  /// evidência de dependência não é conclusiva com esse histórico.
  final (double, double) rhoIc95;

  /// Dispersão mês a mês — `phi` é sazonal, e congelá-lo subestima o risco
  /// fora da estação em que foi medido.
  final List<DispersaoMensal> porMes;

  /// A dependência é distinguível de zero com o histórico disponível?
  bool get rhoConclusivo => rhoIc95.$1 > 0.001;

  /// Amplitude bruta de phi entre o mês mais calmo e o mais agitado.
  ///
  /// Descritiva: com poucos dias por mês ela cresce só por ruído de amostragem.
  /// Para decidir se a sazonalidade é real, use [sazonalidadeSignificativa].
  double get amplitudeSazonal {
    final (min, max) = _extremosMensais();
    return max == null || min == null ? 0 : max.phi - min.phi;
  }

  /// A variação mensal de phi excede o que o ruído explicaria?
  ///
  /// Compara **todos** os meses contra a média, não o mês extremo contra o
  /// outro extremo. Comparar extremos é um teste de máximo disfarçado: com dez
  /// meses ruidosos, algum sempre se destaca, e corrigir isso exige um limiar
  /// tão alto que sazonalidade real deixa de ser detectada.
  ///
  /// `phi` de um mês com `n` dias tem variância aproximada `2·phi²/n`, então
  /// `Q = Σ nₘ(phiₘ − phi̅)² / (2·phi̅²)` segue uma qui-quadrado com `k−1` graus
  /// de liberdade sob homogeneidade.
  bool get sazonalidadeSignificativa => _heterogeneidade() != null;

  /// Quantos meses têm dias suficientes para entrar no teste.
  int get mesesTestaveis => porMes.where((m) => m.dias >= 8).length;

  /// O teste de heterogeneidade **pôde rodar**?
  ///
  /// Distinção que a tela precisa fazer: "testei e a variação cabe no ruído" e
  /// "não tinha meses suficientes para testar" são conclusões diferentes, e
  /// tratá-las como a mesma frase afirma calma onde há só falta de dado.
  bool get sazonalidadeTestavel => mesesTestaveis >= 4;

  /// Estatística Q e o valor crítico de 95%, quando há meses suficientes.
  (double, double)? _heterogeneidade() {
    final comDado = porMes.where((m) => m.dias >= 8).toList();
    if (comDado.length < 4) return null;

    var somaN = 0;
    var somaPhi = 0.0;
    for (final m in comDado) {
      somaN += m.dias;
      somaPhi += m.phi * m.dias;
    }
    if (somaN == 0) return null;
    final phiBarra = somaPhi / somaN;
    if (phiBarra <= 0) return null;

    var q = 0.0;
    for (final m in comDado) {
      final d = m.phi - phiBarra;
      q += m.dias * d * d;
    }
    q /= 2 * phiBarra * phiBarra;

    final v = (comDado.length - 1).toDouble();
    final critico = _quiQuadrado95(v);
    return q > critico ? (q, critico) : null;
  }

  /// Valor crítico de 95% da qui-quadrado por Wilson–Hilferty.
  static double _quiQuadrado95(double v) {
    if (v <= 0) return double.infinity;
    final t = 1 - 2 / (9 * v) + 1.6448536 * math.sqrt(2 / (9 * v));
    return v * t * t * t;
  }

  (DispersaoMensal?, DispersaoMensal?) _extremosMensais() {
    final comDado = porMes.where((m) => m.dias >= 8).toList();
    if (comDado.length < 3) return (null, null);
    DispersaoMensal? min, max;
    for (final m in comDado) {
      if (min == null || m.phi < min.phi) min = m;
      if (max == null || m.phi > max.phi) max = m;
    }
    return (min, max);
  }

  final int diasAnalisados;
  final int consultasAnalisadas;

  /// Limitações encontradas nos dados. Ler antes de confiar nos números.
  final List<String> avisos;

  /// Avaliação distribucional em janela de validação.
  final AvaliacaoDistribucional backtest;

  /// Problemas na **entrada**, não no modelo. Um bloqueio aqui invalida tudo
  /// acima dele.
  final IntegridadeDados integridade;

  /// Critério de saída da F2: dias suficientes e cobertura dentro do nominal.
  bool get aprovadoParaUso =>
      !integridade.temBloqueio &&
      diasAnalisados >= 120 &&
      backtest.coberturaAceitavel;

  /// Pode aplicar os parâmetros medidos à simulação.
  bool get podeAplicar => !integridade.temBloqueio && temDadosSuficientes;

  bool get temDadosSuficientes => diasAnalisados >= 30;
}

/// Estimador de calibração a partir do histórico da agenda.
///
/// Enquanto isto não roda contra a base real, os números do simulador são
/// internamente consistentes e **não descrevem clínica nenhuma**. Esta é a
/// fase que a v1.0 colocava depois do backtest — invertendo a ordem e criando
/// uma linha de base falsa contra a qual todo o resto seria comparado.
class MonteCarloCalibracao {
  const MonteCarloCalibracao._();

  /// Considera desfechos já conhecidos. Pendentes e confirmados no passado são
  /// ambíguos (ninguém deu baixa) e ficam de fora, com aviso.
  static bool _desfechoConhecido(AppointmentStatus s) =>
      s == AppointmentStatus.completed ||
      s == AppointmentStatus.noShow ||
      s == AppointmentStatus.cancelled;

  /// Estima taxas por faixa, sobredispersão e rho.
  ///
  /// [janelaDias] limita o histórico usado; [ate] permite reservar os dias mais
  /// recentes para validação (backtest fora da amostra).
  static CalibracaoResultado estimar({
    required List<Appointment> historico,
    DateTime? ate,
    int janelaDias = 180,
    int diasValidacao = 30,
  }) {
    final avisos = <String>[];
    final fim = ate ?? DateTime.now();
    final inicio = fim.subtract(Duration(days: janelaDias));

    final relevantes = historico
        .where((a) => a.start.isAfter(inicio) && a.start.isBefore(fim))
        .toList();

    final ambiguos = relevantes
        .where((a) => !_desfechoConhecido(a.status))
        .length;
    if (ambiguos > 0) {
      avisos.add(
          '$ambiguos consulta(s) no período sem desfecho registrado (ainda '
          'pendentes ou confirmadas). Ficaram de fora — se a clínica não dá '
          'baixa consistente, a taxa medida fica enviesada.');
    }

    final comDesfecho =
        relevantes.where((a) => _desfechoConhecido(a.status)).toList();

    if (comDesfecho.isEmpty) {
      return CalibracaoResultado(
        taxas: const {},
        modeloCalibrado: const ModeloRisco(),
        phi: 1.0,
        rhoEstimado: 0.0,
        diasAnalisados: 0,
        consultasAnalisadas: 0,
        avisos: [...avisos, 'Sem histórico com desfecho no período.'],
        backtest: AvaliacaoDistribucional.vazia,
        rhoIc95: (0.0, 0.0),
        porMes: const [],
        integridade: const IntegridadeDados(achados: [
          AchadoIntegridade(
            titulo: 'Nenhum desfecho no período',
            detalhe: 'Nenhuma consulta da janela tem status de realizado, '
                'falta ou cancelamento.',
            gravidade: GravidadeAchado.bloqueante,
            acao: 'Ampliar a janela ou verificar se a clínica registra baixa '
                'dos atendimentos.',
          ),
        ]),
      );
    }

    // A base não distingue "paciente cancelou" de "clínica cancelou". São
    // eventos operacionalmente opostos e aqui entram no mesmo balde.
    avisos.add(
        'O sistema registra um único status de cancelamento. Não há como '
        'separar cancelamento do paciente (que libera a vaga) de cancelamento '
        'da clínica (que não é desfecho do paciente). Enquanto esse campo não '
        'existir no transacional, a taxa de cancelamento está superestimada.');

    // ── Taxas por faixa ──────────────────────────────────────────────
    final porFaixa = <RiskLevel, List<Appointment>>{};
    for (final a in comDesfecho) {
      porFaixa.putIfAbsent(a.patientRisk, () => []).add(a);
    }

    final taxas = <RiskLevel, TaxaObservada>{};
    for (final f in RiskLevel.values) {
      final lista = porFaixa[f] ?? const <Appointment>[];
      taxas[f] = TaxaObservada(
        risco: f,
        total: lista.length,
        faltas:
            lista.where((a) => a.status == AppointmentStatus.noShow).length,
        cancelamentos:
            lista.where((a) => a.status == AppointmentStatus.cancelled).length,
      );
    }

    for (final f in RiskLevel.values) {
      final t = taxas[f]!;
      if (!t.confiavel) {
        avisos.add(
            'Faixa ${f.label}: apenas ${t.total} consulta(s) com desfecho — '
            'amostra insuficiente, mantido o valor padrão do modelo.');
      }
    }

    const padrao = ModeloRisco();
    final modelo = ModeloRisco(
      pBaixo: taxas[RiskLevel.low]!.confiavel
          ? taxas[RiskLevel.low]!.taxaFalta
          : padrao.pBaixo,
      pMedio: taxas[RiskLevel.medium]!.confiavel
          ? taxas[RiskLevel.medium]!.taxaFalta
          : padrao.pMedio,
      pAlto: taxas[RiskLevel.high]!.confiavel
          ? taxas[RiskLevel.high]!.taxaFalta
          : padrao.pAlto,
      pCancelBaixo: taxas[RiskLevel.low]!.confiavel
          ? taxas[RiskLevel.low]!.taxaCancelamento
          : padrao.pCancelBaixo,
      pCancelMedio: taxas[RiskLevel.medium]!.confiavel
          ? taxas[RiskLevel.medium]!.taxaCancelamento
          : padrao.pCancelMedio,
      pCancelAlto: taxas[RiskLevel.high]!.confiavel
          ? taxas[RiskLevel.high]!.taxaCancelamento
          : padrao.pCancelAlto,
    );

    // ── Sobredispersão e rho ─────────────────────────────────────────
    final porDia = <String, List<Appointment>>{};
    for (final a in comDesfecho) {
      final k = '${a.start.year}-${a.start.month}-${a.start.day}';
      porDia.putIfAbsent(k, () => []).add(a);
    }

    final diasDisp = _porDia(porDia.values.toList(), modelo);
    final estat = _agregar(diasDisp);
    final rhoIc = _bootstrapRho(diasDisp);
    final mensal = _porMes(diasDisp);
    if (porDia.length < 30) {
      avisos.add(
          'Apenas ${porDia.length} dia(s) com histórico. A estimativa de rho '
          'precisa de pelo menos 30 dias, e de 120 para ter o critério de '
          'saída da F2.');
    }

    // ── Backtest fora da amostra ─────────────────────────────────────
    final backtest = _backtest(
      historico: historico,
      modelo: modelo,
      rho: estat.rho,
      de: fim.subtract(Duration(days: diasValidacao)),
      ate: fim,
    );

    if (backtest.temAmostras && !backtest.coberturaAceitavel) {
      avisos.add(
          'Cobertura do intervalo P05–P95 ficou em '
          '${(backtest.cobertura90 * 100).toStringAsFixed(0)}% (esperado ~90%). '
          'O modelo ainda não está calibrado para decidir overbooking.');
    }

    return CalibracaoResultado(
      taxas: taxas,
      modeloCalibrado: modelo,
      phi: estat.phi,
      rhoEstimado: estat.rho,
      diasAnalisados: porDia.length,
      consultasAnalisadas: comDesfecho.length,
      avisos: avisos,
      backtest: backtest,
      rhoIc95: rhoIc,
      porMes: mensal,
      integridade: _verificarIntegridade(
        comDesfecho: comDesfecho,
        taxas: taxas,
        dias: porDia.length,
        phi: estat.phi,
        porMes: mensal,
        rhoIc: rhoIc,
      ),
    );
  }

  /// Procura sinais de que a entrada não tem forma de dado real.
  ///
  /// Roda **depois** de calcular tudo, de propósito: o painel mostra o número
  /// medido junto do motivo de ele não valer. Esconder o número deixaria a
  /// pessoa sem como conferir o diagnóstico.
  static IntegridadeDados _verificarIntegridade({
    required List<Appointment> comDesfecho,
    required Map<RiskLevel, TaxaObservada> taxas,
    required int dias,
    required double phi,
    List<DispersaoMensal> porMes = const [],
    (double, double) rhoIc = (0.0, 0.0),
  }) {
    final achados = <AchadoIntegridade>[];
    final total = comDesfecho.length;

    // 1. Base que só registra fracasso.
    final realizados = comDesfecho
        .where((a) => a.status == AppointmentStatus.completed)
        .length;
    if (total > 0 && realizados == 0) {
      achados.add(AchadoIntegridade(
        titulo: 'Nenhum atendimento marcado como realizado',
        detalhe:
            'As $total consultas com desfecho são todas falta ou cancelamento. '
            'A taxa medida não é a taxa de falta da clínica — é a proporção de '
            'faltas entre os agendamentos que alguém marcou como problema. '
            'Isso é viés de seleção, não medição.',
        gravidade: GravidadeAchado.bloqueante,
        acao: 'Garantir baixa de "realizado" no fluxo de atendimento, ou '
            'mapear o status que a clínica de fato usa.',
      ));
    } else if (total > 0 && realizados / total < 0.30) {
      achados.add(AchadoIntegridade(
        titulo: 'Poucos atendimentos marcados como realizados',
        detalhe: 'Apenas ${(realizados / total * 100).toStringAsFixed(0)}% das '
            'consultas com desfecho constam como realizadas. Se a baixa não '
            'for consistente, a taxa de falta sai inflada.',
        gravidade: GravidadeAchado.alerta,
      ));
    }

    // 2. Estratificação de risco que não existe.
    final faixasComDado =
        taxas.values.where((t) => t.total > 0).map((t) => t.risco).toList();
    if (total > 0 && faixasComDado.length <= 1) {
      final unica = faixasComDado.isEmpty ? null : faixasComDado.first;
      achados.add(AchadoIntegridade(
        titulo: 'Todas as consultas na mesma faixa de risco',
        detalhe:
            'As $total consultas caem em ${unica?.label ?? "uma única faixa"}. '
            'O modelo separa três faixas para atribuir três probabilidades; com '
            'uma faixa só, a estratificação é ficção e o risco individual não '
            'difere entre pacientes.',
        gravidade: GravidadeAchado.bloqueante,
        acao: 'Definir onde o risco do paciente nasce e carregá-lo no '
            'agendamento — hoje o campo não é lido do banco.',
      ));
    }

    // 3. Subdispersão: as faltas variando MENOS que o acaso independente.
    if (dias >= 10 && phi < 0.7) {
      achados.add(AchadoIntegridade(
        titulo: 'Sobredispersão abaixo de 1 (φ = ${phi.toStringAsFixed(2)})',
        detalhe:
            'As faltas variam menos entre dias do que o acaso independente '
            'produziria. Isso quase nunca acontece em agenda real — costuma '
            'indicar desfecho preenchido em lote ou por regra automática.',
        gravidade: GravidadeAchado.alerta,
      ));
    }

    // 4. Dependência não distinguível de zero.
    if (dias >= 30 && rhoIc.$2 > 0 && rhoIc.$1 <= 0.001) {
      achados.add(AchadoIntegridade(
        titulo: 'Dependência entre faltas ainda não é conclusiva',
        detalhe: 'O intervalo de 95% do ρ vai de '
            '${rhoIc.$1.toStringAsFixed(3)} a ${rhoIc.$2.toStringAsFixed(3)} — '
            'contém zero. Com este histórico não dá para afirmar que as faltas '
            'se movem juntas, só que podem.',
        gravidade: GravidadeAchado.alerta,
      ));
    }

    // 5. Sazonalidade: um rho único esconde a variação do ano.
    //
    // Testa heterogeneidade entre TODOS os meses, não o extremo contra o
    // extremo — comparar extremos exige um limiar tão alto que sazonalidade
    // real deixa de ser detectada.
    final comDado = porMes.where((m) => m.dias >= 8).toList();
    if (comDado.length >= 4) {
      var somaN = 0;
      var somaPhi = 0.0;
      for (final m in comDado) {
        somaN += m.dias;
        somaPhi += m.phi * m.dias;
      }
      final phiBarra = somaN > 0 ? somaPhi / somaN : 0.0;
      if (phiBarra > 0) {
        var q = 0.0;
        for (final m in comDado) {
          final d = m.phi - phiBarra;
          q += m.dias * d * d;
        }
        q /= 2 * phiBarra * phiBarra;

        final v = (comDado.length - 1).toDouble();
        final t = 1 - 2 / (9 * v) + 1.6448536 * math.sqrt(2 / (9 * v));
        final critico = v * t * t * t;

        if (q > critico) {
          DispersaoMensal? mMin, mMax;
          for (final m in comDado) {
            if (mMin == null || m.phi < mMin.phi) mMin = m;
            if (mMax == null || m.phi > mMax.phi) mMax = m;
          }
          achados.add(AchadoIntegridade(
            titulo: 'Sobredispersão varia ao longo do ano',
            detalhe: 'φ vai de ${mMin!.phi.toStringAsFixed(2)} em ${mMin.nome} '
                'a ${mMax!.phi.toStringAsFixed(2)} em ${mMax.nome}. A variação '
                'entre os ${comDado.length} meses excede o ruído '
                '(Q = ${q.toStringAsFixed(1)}, crítico ${critico.toStringAsFixed(1)}). '
                'Um ρ único congelado subestima o risco no mês agitado e o '
                'superestima no calmo.',
            gravidade: GravidadeAchado.alerta,
            acao: 'Reestimar ρ por janela móvel em vez de um valor anual.',
          ));
        }
      }
    }

    // 6. Janela curta demais para o critério de saída da F2.
    if (dias > 0 && dias < 120) {
      achados.add(AchadoIntegridade(
        titulo: 'Histórico curto: $dias dia(s)',
        detalhe: 'A fase F2 pede 120 dias. Aumentar o slider não resolve — ele '
            'filtra o que a agenda já carregou, não busca mais no banco.',
        gravidade: dias < 30
            ? GravidadeAchado.bloqueante
            : GravidadeAchado.alerta,
        acao: dias < 30
            ? 'Carregar histórico por consulta própria ao Firestore.'
            : '',
      ));
    }

    return IntegridadeDados(achados: achados);
  }

  /// Contribuição de cada dia para a dispersão.
  ///
  /// `phi` é a média dos resíduos padronizados ao quadrado — vale 1 sob
  /// independência e cresce quando as faltas do dia se movem juntas. Isso é
  /// robusto à composição variável dos dias, ao contrário de comparar a
  /// variância bruta entre dias com número diferente de consultas.
  ///
  /// A inversão para rho usa a aproximação de primeira ordem da cópula:
  /// `Cov(i,j) ≈ rho · pdf(z_i) · pdf(z_j)`, válida para rho pequeno — que é a
  /// faixa observada na prática (0,02 a 0,05).
  static List<DiaDispersao> _porDia(
    List<List<Appointment>> dias,
    ModeloRisco modelo,
  ) {
    final out = <DiaDispersao>[];

    for (final dia in dias) {
      if (dia.length < 5) continue; // dia curto demais para informar dispersão

      var mu = 0.0;
      var varIndep = 0.0;
      var somaPdf = 0.0;
      var somaPdf2 = 0.0;
      var observado = 0;

      for (final a in dia) {
        final p = (a.pFaltaPrevista ?? modelo.pFaltaDe(a.patientRisk))
            .clamp(1e-6, 1 - 1e-6);
        mu += p;
        varIndep += p * (1 - p);
        final z = MonteCarloEngine.normalInv(p);
        final d = MonteCarloEngine.normalPdf(z);
        somaPdf += d;
        somaPdf2 += d * d;
        if (a.status == AppointmentStatus.noShow) observado++;
      }

      if (varIndep <= 0) continue;
      final resid = observado - mu;
      final quad = resid * resid;
      final b = somaPdf * somaPdf - somaPdf2; // pares i != j

      out.add(DiaDispersao(
        mes: dia.first.start.month,
        phi: quad / varIndep,
        rho: b > 0 ? (quad - varIndep) / b : 0.0,
      ));
    }
    return out;
  }

  static ({double phi, double rho}) _agregar(List<DiaDispersao> dias) {
    if (dias.isEmpty) return (phi: 1.0, rho: 0.0);
    var sp = 0.0, sr = 0.0;
    for (final d in dias) {
      sp += d.phi;
      sr += d.rho;
    }
    return (
      phi: sp / dias.length,
      rho: (sr / dias.length).clamp(0.0, 0.5),
    );
  }

  /// Intervalo de 95% do rho por reamostragem de dias (bootstrap).
  ///
  /// Reamostra o **dia**, não a consulta: a dependência é justamente o que
  /// quebra a independência entre consultas do mesmo dia, então reamostrar
  /// consultas destruiria o efeito que se quer medir.
  static (double, double) _bootstrapRho(
    List<DiaDispersao> dias, {
    int repeticoes = 400,
    int seed = 20260902,
  }) {
    if (dias.length < 10) return (0.0, 0.0);
    final rng = math.Random(seed);
    final amostras = <double>[];

    for (var b = 0; b < repeticoes; b++) {
      var soma = 0.0;
      for (var i = 0; i < dias.length; i++) {
        soma += dias[rng.nextInt(dias.length)].rho;
      }
      amostras.add((soma / dias.length).clamp(0.0, 0.5));
    }
    amostras.sort();
    double q(double f) =>
        amostras[((amostras.length - 1) * f).round().clamp(0, amostras.length - 1)];
    return (q(0.025), q(0.975));
  }

  /// Agrega a dispersão por mês do calendário.
  static List<DispersaoMensal> _porMes(List<DiaDispersao> dias) {
    final grupos = <int, List<DiaDispersao>>{};
    for (final d in dias) {
      grupos.putIfAbsent(d.mes, () => []).add(d);
    }
    final out = <DispersaoMensal>[];
    for (final e in grupos.entries) {
      final ag = _agregar(e.value);
      out.add(DispersaoMensal(
        mes: e.key,
        phi: ag.phi,
        rho: ag.rho,
        dias: e.value.length,
      ));
    }
    out.sort((a, b) => a.mes - b.mes);
    return out;
  }

  /// Backtest fora da amostra: prevê cada dia da janela de validação com o
  /// modelo calibrado e compara com o que de fato aconteceu.
  static AvaliacaoDistribucional _backtest({
    required List<Appointment> historico,
    required ModeloRisco modelo,
    required double rho,
    required DateTime de,
    required DateTime ate,
  }) {
    final porDia = <String, List<Appointment>>{};
    for (final a in historico) {
      if (a.start.isBefore(de) || a.start.isAfter(ate)) continue;
      if (!_desfechoConhecido(a.status)) continue;
      final k = '${a.start.year}-${a.start.month}-${a.start.day}';
      porDia.putIfAbsent(k, () => []).add(a);
    }

    final previsoes = <Distribuicao>[];
    final observados = <int>[];

    for (final dia in porDia.values) {
      if (dia.length < 5) continue;
      final consultas = [
        for (final a in dia)
          ConsultaRisco(
            appointmentId: a.id,
            doctorId: a.doctorId,
            hour: a.start.hour,
            pFalta: modelo.pFaltaDe(a.patientRisk),
            pCancel: modelo.pCancelSeguroDe(a.patientRisk),
            risco: a.patientRisk,
          ),
      ];

      final r = MonteCarloEngine.simular(
        data: dia.first.start,
        consultas: consultas,
        medicos: const [],
        config: SimulacaoConfig(rho: rho, nRuns: 4000, seed: 20260902),
      );

      previsoes.add(r.faltas);
      observados.add(
          dia.where((a) => a.status == AppointmentStatus.noShow).length);
    }

    return MonteCarloMetrics.avaliar(previsoes, observados);
  }
}
