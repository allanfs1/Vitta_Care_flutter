import 'dart:math' as math;

import '../../core/models/appointment.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import 'monte_carlo_models.dart';

/// Motor de simulação de faltas e overbooking (lógica pura, sem Flutter e sem
/// Firebase — todo o conteúdo deste arquivo é testável em `dart test`).
///
/// Quatro decisões de modelagem sustentam o resto:
///
/// 1. **Faltas do mesmo dia não são independentes.** Chuva, feriado, greve de
///    transporte e ondas respiratórias empurram as faltas do dia na mesma
///    direção. A dependência entra por uma cópula gaussiana de um fator, que
///    preserva as probabilidades marginais exatamente — só a dispersão muda.
///
/// 2. **Três estados, não dois.** Cancelar com antecedência libera a vaga a
///    tempo de ser reocupada; faltar não libera nada. Tratar os dois como a
///    mesma coisa superestima a capacidade recuperável do dia.
///
/// 3. **Overbooking é decidido por slot, não por dia.** Uma falta às 16h não
///    libera capacidade para um encaixe às 9h.
///
/// 4. **A fila vem antes do overbooking.** Preencher uma vaga de fato liberada
///    não cria espera para ninguém; o encaixe especulativo cria.
class MonteCarloEngine {
  const MonteCarloEngine._();

  /// Denominador virtual usado quando a distribuição vem da forma fechada.
  static const int _escalaExata = 1000000000;

  /// Maior número de encaixes pré-avaliado por slot.
  static const int kMaxEncaixes = 12;

  // ── Utilidades numéricas ────────────────────────────────────────────

  /// Densidade da normal padrão.
  static double normalPdf(double z) =>
      math.exp(-0.5 * z * z) / math.sqrt(2 * math.pi);

  /// Inversa da normal padrão (algoritmo de Acklam), precisão ~1e-9.
  static double normalInv(double p) {
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
    const pLow = 0.02425;
    const pHigh = 1 - pLow;

    if (p < pLow) {
      final q = math.sqrt(-2 * math.log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
    if (p > pHigh) {
      final q = math.sqrt(-2 * math.log(1 - p));
      return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
    final q = p - 0.5;
    final r = q * q;
    return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r +
            a[5]) *
        q /
        (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
  }

  /// Aplica uma intervenção (lembrete, confirmação ativa) como **razão de
  /// chances**, não como delta aditivo sobre a probabilidade.
  ///
  /// Um delta aditivo (`p - 0.08`) produz probabilidade negativa em toda
  /// consulta com `p < 0.08` — defeito, não aproximação. A razão de chances
  /// mantém o resultado em (0, 1) para qualquer entrada.
  ///
  /// [oddsRatio] < 1 reduz a chance de falta.
  static double aplicarIntervencao(double p, double oddsRatio) {
    if (p <= 0) return 0;
    if (p >= 1) return 1;
    if (oddsRatio <= 0) return 0;
    final odds = (p / (1 - p)) * oddsRatio;
    return odds / (1 + odds);
  }

  /// PMF exata da Poisson-binomial por convolução dinâmica.
  ///
  /// Exata e O(n²) — para n = 220 são ~48 mil operações, microssegundos. No
  /// caso independente isto dispensa a simulação inteira e serve de oráculo
  /// para validar o amostrador.
  static List<double> poissonBinomialPmf(List<double> ps) {
    var pmf = <double>[1.0];
    for (final p in ps) {
      final pc = p.clamp(0.0, 1.0);
      final next = List<double>.filled(pmf.length + 1, 0.0);
      for (var k = 0; k < pmf.length; k++) {
        final v = pmf[k];
        if (v == 0) continue;
        next[k] += v * (1 - pc);
        next[k + 1] += v * pc;
      }
      pmf = next;
    }
    return pmf;
  }

  /// PMF binomial de `n` tentativas com probabilidade `q`.
  static List<double> binomialPmf(int n, double q) =>
      poissonBinomialPmf(List<double>.filled(n, q));

  /// Converte uma PMF exata em [Distribuicao] preservando a soma dos pesos.
  static Distribuicao _distribuicaoDePmf(List<double> pmf) {
    var media = 0.0;
    var segundo = 0.0;
    for (var k = 0; k < pmf.length; k++) {
      media += k * pmf[k];
      segundo += k * k * pmf[k];
    }
    final varianca = math.max(0.0, segundo - media * media);

    // Contagens por diferença de acumulados: a soma fecha exatamente na escala.
    final contagens = List<int>.filled(pmf.length, 0);
    var acum = 0.0;
    var anterior = 0;
    for (var k = 0; k < pmf.length; k++) {
      acum += pmf[k];
      final atual = (acum * _escalaExata).round().clamp(0, _escalaExata);
      contagens[k] = atual - anterior;
      anterior = atual;
    }

    return Distribuicao(
      contagens: contagens,
      total: anterior,
      media: media,
      desvio: math.sqrt(varianca),
    );
  }

  static Distribuicao _distribuicaoDeContagens(List<int> contagens, int total) {
    if (total == 0) {
      return Distribuicao(contagens: contagens, total: 0, media: 0, desvio: 0);
    }
    var media = 0.0;
    var segundo = 0.0;
    for (var k = 0; k < contagens.length; k++) {
      final n = contagens[k];
      if (n == 0) continue;
      media += k * n;
      segundo += k * k * n.toDouble();
    }
    media /= total;
    final varianca = math.max(0.0, segundo / total - media * media);
    return Distribuicao(
      contagens: contagens,
      total: total,
      media: media,
      desvio: math.sqrt(varianca),
    );
  }

  // ── Montagem da entrada ─────────────────────────────────────────────

  /// Extrai as consultas do dia com as probabilidades atribuídas.
  ///
  /// Cancelados já saíram da agenda e não entram; realizados e faltas são
  /// história, não previsão.
  static List<ConsultaRisco> montarConsultas({
    required DateTime data,
    required List<Appointment> agendamentos,
    ModeloRisco modelo = const ModeloRisco(),
    double oddsRatioIntervencao = 1.0,
  }) {
    bool mesmoDia(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final out = <ConsultaRisco>[];
    for (final a in agendamentos) {
      if (!mesmoDia(a.start, data)) continue;
      if (a.status != AppointmentStatus.pending &&
          a.status != AppointmentStatus.confirmed) {
        continue;
      }
      final base = modelo.pFaltaDe(a.patientRisk);
      final p = aplicarIntervencao(base, oddsRatioIntervencao);
      // A intervenção reduz a falta; parte de quem deixaria de faltar passa a
      // cancelar com aviso, que é justamente o desfecho que a intervenção
      // procura produzir. O excedente vai para a taxa de cancelamento.
      final cancelBase = modelo.pCancelSeguroDe(a.patientRisk);
      final migrado = math.max(0.0, base - p);
      final cancel = (cancelBase + migrado).clamp(0.0, 0.999 - p);
      out.add(ConsultaRisco(
        appointmentId: a.id,
        doctorId: a.doctorId,
        hour: a.start.hour,
        pFalta: p,
        pCancel: cancel,
        risco: a.patientRisk,
      ));
    }
    return out;
  }

  // ── Simulação ───────────────────────────────────────────────────────

  /// Executa a simulação do dia.
  ///
  /// Com `config.rho == 0` não simula nada: devolve as Poisson-binomiais
  /// exatas, sem semente, sem erro de amostragem. Esse caminho reproduz
  /// exatamente o modelo independente e é o oráculo dos testes do amostrador.
  /// Capacidades por slot, no formato `slotKey → [física, configurada]`.
  ///
  /// Extraído do [Doctor] aqui para que a simulação possa rodar em outro
  /// isolate recebendo apenas tipos simples — `Doctor` carrega bytes de foto e
  /// não vale a pena atravessar a fronteira.
  static Map<String, List<int>> mapaCapacidades({
    required DateTime data,
    required List<ConsultaRisco> consultas,
    required List<Doctor> medicos,
  }) {
    final medicoPorId = {for (final m in medicos) m.id: m};
    final wd = data.weekday;
    final out = <String, List<int>>{};
    for (final c in consultas) {
      if (out.containsKey(c.slotKey)) continue;
      final m = medicoPorId[c.doctorId];
      if (m == null) {
        out[c.slotKey] = [1, 1];
        continue;
      }
      final hhmm = '${c.hour.toString().padLeft(2, '0')}:00';
      final fisica = m.slotLimit < 1 ? 1 : m.slotLimit;
      out[c.slotKey] = [fisica, m.capacityAt(wd, hhmm)];
    }
    return out;
  }

  /// Nomes de exibição por id de médico.
  static Map<String, String> mapaNomes(List<Doctor> medicos) =>
      {for (final m in medicos) m.id: m.name};

  static SimulacaoResultado simular({
    required DateTime data,
    required List<ConsultaRisco> consultas,
    List<Doctor> medicos = const [],
    Map<String, List<int>>? capacidades,
    Map<String, String>? nomes,
    SimulacaoConfig config = const SimulacaoConfig(),
  }) {
    final inicio = DateTime.now();

    // Agrupa por slot (médico x hora) — a unidade real da decisão.
    final porSlot = <String, List<ConsultaRisco>>{};
    for (final c in consultas) {
      porSlot.putIfAbsent(c.slotKey, () => []).add(c);
    }

    final caps = capacidades ??
        mapaCapacidades(data: data, consultas: consultas, medicos: medicos);
    final nomeMap = nomes ?? mapaNomes(medicos);

    (int, int) capacidadesDe(String doctorId, int hour) {
      final v = caps['$doctorId|$hour'];
      if (v == null || v.length < 2) return (1, 1);
      return (v[0], v[1]);
    }

    String nomeDe(String doctorId) => nomeMap[doctorId] ?? doctorId;

    final varIndep =
        consultas.fold(0.0, (s, c) => s + c.pFalta * (1 - c.pFalta));

    final chaves = porSlot.keys.toList();

    late final Distribuicao faltas;
    late final Distribuicao cancelamentos;
    late final List<Distribuicao> presentesPorSlot;
    late final List<Distribuicao> liberadasPorSlot;
    var exato = false;
    var phi = 1.0;

    if (config.independente) {
      exato = true;
      faltas = _distribuicaoDePmf(
          poissonBinomialPmf([for (final c in consultas) c.pFalta]));
      cancelamentos = _distribuicaoDePmf(
          poissonBinomialPmf([for (final c in consultas) c.pCancel]));
      presentesPorSlot = [
        for (final k in chaves)
          _distribuicaoDePmf(
              poissonBinomialPmf([for (final c in porSlot[k]!) c.pComparece])),
      ];
      liberadasPorSlot = [
        for (final k in chaves)
          _distribuicaoDePmf(
              poissonBinomialPmf([for (final c in porSlot[k]!) c.pCancel])),
      ];
    } else {
      final r = _amostrar(
        consultas: consultas,
        porSlot: porSlot,
        chaves: chaves,
        config: config,
      );
      faltas = r.faltas;
      cancelamentos = r.cancelamentos;
      presentesPorSlot = r.presentes;
      liberadasPorSlot = r.liberadas;
      final varObs = faltas.desvio * faltas.desvio;
      phi = varIndep <= 0 ? 1.0 : varObs / varIndep;
    }

    // Monta os slots com risco pré-calculado e composição de risco.
    final slots = <SlotForecast>[];
    for (var s = 0; s < chaves.length; s++) {
      final lista = porSlot[chaves[s]]!;
      final doctorId = lista.first.doctorId;
      final hour = lista.first.hour;
      final (fisica, configurada) = capacidadesDe(doctorId, hour);
      final cap = config.baseCapacidade == BaseCapacidade.fisica
          ? fisica
          : configurada;

      final composicao = <RiskLevel, int>{};
      for (final c in lista) {
        composicao[c.risco] = (composicao[c.risco] ?? 0) + 1;
      }

      slots.add(SlotForecast(
        doctorId: doctorId,
        doctorName: nomeDe(doctorId),
        hour: hour,
        agendados: lista.length,
        capacidade: cap,
        capacidadeFisica: fisica,
        capacidadeConfigurada: configurada,
        presentes: presentesPorSlot[s],
        liberadasComAviso: liberadasPorSlot[s],
        riscoPorEncaixe:
            _riscoPorEncaixe(presentesPorSlot[s], cap, config),
        composicaoRisco: composicao,
      ));
    }
    slots.sort((a, b) => a.hour != b.hour
        ? a.hour - b.hour
        : a.doctorName.compareTo(b.doctorName));

    return SimulacaoResultado(
      data: data,
      config: config,
      consultas: consultas,
      faltas: faltas,
      cancelamentos: cancelamentos,
      slots: slots,
      exato: exato,
      duracao: DateTime.now().difference(inicio),
      phiObservado: phi,
      fila: _recomendarFila(slots),
    );
  }

  /// Risco de estouro para 0..[kMaxEncaixes] encaixes no slot.
  ///
  /// No modo conservador o encaixe comparece com certeza. No modo
  /// probabilístico a distribuição de presentes é convoluída com a binomial
  /// dos encaixes — o que ignora o fator comum do dia para eles e portanto é
  /// levemente otimista. Os dois modos são limites, não estimativa única.
  static List<double> _riscoPorEncaixe(
    Distribuicao presentes,
    int capacidade,
    SimulacaoConfig config,
  ) {
    final out = List<double>.filled(kMaxEncaixes + 1, 0.0);

    if (config.encaixeModo == EncaixeModo.certo) {
      for (var k = 0; k <= kMaxEncaixes; k++) {
        out[k] = presentes.probAcima(capacidade - k);
      }
      return out;
    }

    final q = (1 - config.pFaltaEncaixe).clamp(0.0, 1.0);
    // PMF dos presentes, normalizada.
    final base = [
      for (var i = 0; i < presentes.contagens.length; i++) presentes.pmf(i),
    ];
    for (var k = 0; k <= kMaxEncaixes; k++) {
      if (k == 0) {
        out[0] = presentes.probAcima(capacidade);
        continue;
      }
      final enc = binomialPmf(k, q);
      // P(base + enc > capacidade)
      var acima = 0.0;
      for (var i = 0; i < base.length; i++) {
        final pb = base[i];
        if (pb == 0) continue;
        for (var j = 0; j < enc.length; j++) {
          if (i + j > capacidade) acima += pb * enc[j];
        }
      }
      out[k] = acima.clamp(0.0, 1.0);
    }
    return out;
  }

  /// Dimensiona as chamadas da lista de espera pelo quartil inferior das vagas
  /// liberadas por cancelamento — não pela média, que erraria para cima em
  /// metade dos dias.
  static RecomendacaoFila _recomendarFila(List<SlotForecast> slots) {
    if (slots.isEmpty) return RecomendacaoFila.vazia;
    var total = 0;
    var p25 = 0;
    var p50 = 0;
    final detalhe = <String, int>{};
    for (final s in slots) {
      final seguro = s.liberadasComAviso.p25;
      p25 += seguro;
      p50 += s.liberadasComAviso.p50;
      if (seguro > 0) {
        detalhe['${s.doctorId}|${s.hour}'] = seguro;
        total += seguro;
      }
    }
    return RecomendacaoFila(
      chamadasSeguras: total,
      liberadasP25: p25,
      liberadasP50: p50,
      detalhePorSlot: detalhe,
    );
  }

  static _AmostraBruta _amostrar({
    required List<ConsultaRisco> consultas,
    required Map<String, List<ConsultaRisco>> porSlot,
    required List<String> chaves,
    required SimulacaoConfig config,
  }) {
    final n = consultas.length;
    final rng = math.Random(config.seed);
    final gauss = _GeradorNormal(rng);

    final rho = config.rho.clamp(0.0, 0.999);
    final raizRho = math.sqrt(rho);
    final raizComp = math.sqrt(1 - rho);

    // Limiares ordenados na escala latente: falta na cauda inferior, depois
    // cancelamento, o resto é comparecimento. Preserva as duas marginais.
    final zFalta = [for (final c in consultas) normalInv(c.pFalta)];
    final zCancel = [
      for (final c in consultas) normalInv(c.pFalta + c.pCancel),
    ];

    final indexPorId = <String, int>{};
    for (var i = 0; i < n; i++) {
      indexPorId[consultas[i].appointmentId] = i;
    }
    final indicesSlot = [
      for (final k in chaves)
        [for (final c in porSlot[k]!) indexPorId[c.appointmentId]!],
    ];

    final contFaltas = List<int>.filled(n + 1, 0);
    final contCancel = List<int>.filled(n + 1, 0);
    final contPresentes = [
      for (final idx in indicesSlot) List<int>.filled(idx.length + 1, 0),
    ];
    final contLiberadas = [
      for (final idx in indicesSlot) List<int>.filled(idx.length + 1, 0),
    ];

    final estado = List<int>.filled(n, 0); // 0 comparece, 1 cancela, 2 falta

    for (var run = 0; run < config.nRuns; run++) {
      // Fator comum do dia: o choque que move todos os desfechos juntos.
      final z = gauss.proximo();
      var faltas = 0;
      var cancelou = 0;
      for (var i = 0; i < n; i++) {
        final x = raizRho * z + raizComp * gauss.proximo();
        if (x <= zFalta[i]) {
          estado[i] = 2;
          faltas++;
        } else if (x <= zCancel[i]) {
          estado[i] = 1;
          cancelou++;
        } else {
          estado[i] = 0;
        }
      }
      contFaltas[faltas]++;
      contCancel[cancelou]++;

      for (var s = 0; s < indicesSlot.length; s++) {
        final idx = indicesSlot[s];
        var presentes = 0;
        var liberadas = 0;
        for (final i in idx) {
          final e = estado[i];
          if (e == 0) {
            presentes++;
          } else if (e == 1) {
            liberadas++;
          }
        }
        contPresentes[s][presentes]++;
        contLiberadas[s][liberadas]++;
      }
    }

    return _AmostraBruta(
      faltas: _distribuicaoDeContagens(contFaltas, config.nRuns),
      cancelamentos: _distribuicaoDeContagens(contCancel, config.nRuns),
      presentes: [
        for (final c in contPresentes)
          _distribuicaoDeContagens(c, config.nRuns),
      ],
      liberadas: [
        for (final c in contLiberadas)
          _distribuicaoDeContagens(c, config.nRuns),
      ],
    );
  }

  // ── Decisão de overbooking ──────────────────────────────────────────

  /// Avalia `+k` encaixes sobre o resultado já simulado.
  ///
  /// Não re-simula: todos os cenários são lidos da MESMA simulação, o que é
  /// exatamente a técnica de números aleatórios comuns — a comparação entre
  /// cenários fica livre do ruído de amostragem que dominaria a diferença.
  ///
  /// Os encaixes são alocados de forma gulosa nos slots de menor risco, e o
  /// cenário é julgado pelo **pior slot**, não pela média do dia.
  static CenarioOverbooking avaliarCenario(
    SimulacaoResultado r,
    int encaixes, {
    double limiteRisco = 0.05,
    double valorSlot = 180.0,
    double limiteEquidade = 1.25,
  }) {
    final slots = r.slots;
    if (slots.isEmpty) {
      return CenarioOverbooking(
        encaixes: encaixes,
        riscoMaximoSlot: 0,
        slotsAcimaDoLimite: 0,
        receitaEsperada: 0,
        ociosidadeEsperada: 0,
        aprovado: encaixes == 0,
        motivo: 'Sem slots na data.',
        alocacao: const [],
        equidade: EquidadeRelatorio.vazio,
      );
    }

    // Alocação gulosa: cada encaixe vai para o slot onde adiciona menos risco.
    final extras = List<int>.filled(slots.length, 0);
    for (var e = 0; e < encaixes; e++) {
      var melhor = -1;
      var melhorRisco = double.infinity;
      for (var i = 0; i < slots.length; i++) {
        final risco = slots[i].riscoEstouro(extras[i] + 1);
        if (risco < melhorRisco) {
          melhorRisco = risco;
          melhor = i;
        }
      }
      if (melhor < 0) break;
      extras[melhor]++;
    }

    var riscoMax = 0.0;
    var acima = 0;
    var presentesEsperados = 0.0;
    var ociosidade = 0.0;
    for (var i = 0; i < slots.length; i++) {
      final risco = slots[i].riscoEstouro(extras[i]);
      if (risco > riscoMax) riscoMax = risco;
      if (risco > limiteRisco) acima++;
      presentesEsperados += slots[i].presentes.media + extras[i];
      ociosidade += math.max(
          0.0, slots[i].capacidade - slots[i].presentes.media - extras[i]);
    }

    final equidade = avaliarEquidade(r, extras, limite: limiteEquidade);
    final aprovado = riscoMax <= limiteRisco && equidade.dentroDoLimite;

    final motivo = !equidade.dentroDoLimite
        ? 'Bloqueado por equidade: uma faixa de risco absorve '
            '${equidade.razaoMaxima.toStringAsFixed(2)}x a carga que sua '
            'presença na agenda justificaria.'
        : (aprovado
            ? 'Pior slot em ${(riscoMax * 100).toStringAsFixed(1)}%, dentro do '
                'limite de ${(limiteRisco * 100).toStringAsFixed(0)}%.'
            : '$acima slot(s) acima do limite; pior caso '
                '${(riscoMax * 100).toStringAsFixed(1)}%.');

    return CenarioOverbooking(
      encaixes: encaixes,
      riscoMaximoSlot: riscoMax,
      slotsAcimaDoLimite: acima,
      receitaEsperada: presentesEsperados * valorSlot,
      ociosidadeEsperada: ociosidade,
      aprovado: aprovado,
      motivo: motivo,
      alocacao: extras,
      equidade: equidade,
    );
  }

  /// Mede como a carga de overbooking se distribui entre as faixas de risco.
  ///
  /// Encaixar num slot aumenta a espera de todos os pacientes daquele slot. Se
  /// a alocação gulosa (que só olha risco de estouro) concentrar encaixes nos
  /// slots com mais pacientes de alto risco, ela transfere o custo da
  /// eficiência para quem já tem mais barreira de acesso.
  static EquidadeRelatorio avaliarEquidade(
    SimulacaoResultado r,
    List<int> alocacao, {
    double limite = 1.25,
  }) {
    final totalConsultas = r.consultas.length;
    if (totalConsultas == 0 || alocacao.isEmpty) {
      return EquidadeRelatorio.vazio;
    }

    final participacao = <RiskLevel, double>{};
    for (final entry in r.composicaoRisco.entries) {
      participacao[entry.key] = entry.value / totalConsultas;
    }

    final exposicao = <RiskLevel, double>{
      for (final f in RiskLevel.values) f: 0.0,
    };
    var totalEncaixes = 0;
    for (var i = 0; i < r.slots.length && i < alocacao.length; i++) {
      final k = alocacao[i];
      if (k == 0) continue;
      totalEncaixes += k;
      final s = r.slots[i];
      if (s.agendados == 0) continue;
      for (final entry in s.composicaoRisco.entries) {
        exposicao[entry.key] =
            (exposicao[entry.key] ?? 0) + k * (entry.value / s.agendados);
      }
    }

    if (totalEncaixes == 0) {
      return EquidadeRelatorio(
        exposicaoPorFaixa: exposicao,
        participacaoPorFaixa: participacao,
        razaoMaxima: 1.0,
        dentroDoLimite: true,
      );
    }

    var razaoMax = 0.0;
    for (final f in RiskLevel.values) {
      final part = participacao[f] ?? 0;
      if (part <= 0) continue;
      final expFrac = (exposicao[f] ?? 0) / totalEncaixes;
      final razao = expFrac / part;
      if (razao > razaoMax) razaoMax = razao;
    }
    if (razaoMax == 0) razaoMax = 1.0;

    return EquidadeRelatorio(
      exposicaoPorFaixa: exposicao,
      participacaoPorFaixa: participacao,
      razaoMaxima: razaoMax,
      dentroDoLimite: razaoMax <= limite,
    );
  }

  /// Maior número de encaixes que mantém todos os slots dentro do limite.
  ///
  /// Devolve 0 quando a agenda **já** excede o limite sem nenhum encaixe — um
  /// resultado que o modelo agregado tende a esconder.
  static int encaixesRecomendados(
    SimulacaoResultado r, {
    double limiteRisco = 0.05,
    double limiteEquidade = 1.25,
    int maximo = kMaxEncaixes,
  }) {
    if (!avaliarCenario(r, 0,
            limiteRisco: limiteRisco, limiteEquidade: limiteEquidade)
        .aprovado) {
      return 0;
    }
    var melhor = 0;
    for (var k = 1; k <= maximo; k++) {
      if (avaliarCenario(r, k,
              limiteRisco: limiteRisco, limiteEquidade: limiteEquidade)
          .aprovado) {
        melhor = k;
      } else {
        break;
      }
    }
    return melhor;
  }

  /// Varredura de cenários 0..[maximo] para exibição em tabela.
  static List<CenarioOverbooking> varrerCenarios(
    SimulacaoResultado r, {
    double limiteRisco = 0.05,
    double valorSlot = 180.0,
    double limiteEquidade = 1.25,
    int maximo = 6,
  }) =>
      [
        for (var k = 0; k <= maximo; k++)
          avaliarCenario(r, k,
              limiteRisco: limiteRisco,
              valorSlot: valorSlot,
              limiteEquidade: limiteEquidade),
      ];
}

class _AmostraBruta {
  const _AmostraBruta({
    required this.faltas,
    required this.cancelamentos,
    required this.presentes,
    required this.liberadas,
  });

  final Distribuicao faltas;
  final Distribuicao cancelamentos;
  final List<Distribuicao> presentes;
  final List<Distribuicao> liberadas;
}

/// Gerador de normais padrão pelo método polar de Marsaglia, guardando o par.
/// Evita `sin`/`cos` do Box-Muller no laço quente da simulação.
class _GeradorNormal {
  _GeradorNormal(this._rng);

  final math.Random _rng;
  double? _reserva;

  double proximo() {
    final r = _reserva;
    if (r != null) {
      _reserva = null;
      return r;
    }
    double u, v, s;
    do {
      u = _rng.nextDouble() * 2 - 1;
      v = _rng.nextDouble() * 2 - 1;
      s = u * u + v * v;
    } while (s >= 1 || s == 0);
    final f = math.sqrt(-2 * math.log(s) / s);
    _reserva = v * f;
    return u * f;
  }
}
