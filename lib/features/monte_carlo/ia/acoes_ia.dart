import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/utils/num_ptbr.dart';
import '../monte_carlo_calibracao.dart';
import '../monte_carlo_engine.dart';
import '../monte_carlo_models.dart';

/// Catálogo de ações de IA do simulador.
///
/// ## Por que um catálogo, e não um chat livre
///
/// Chat aberto sobre uma tela de números convida a pergunta que o modelo não
/// pode responder — "quantos encaixes eu abro?" respondido de cabeça, sem
/// rodar a simulação. Cada ação aqui **recebe o resultado já calculado** e só
/// escreve a leitura. O modelo interpreta; ele não conta.
///
/// ## As três travas, iguais às do planejador
///
/// 1. **Não calcula.** O `contexto` de cada ação é montado em Dart a partir do
///    resultado determinístico da simulação.
/// 2. **Não aplica.** Toda saída é texto. Nada é gravado na agenda.
/// 3. **Não passa sem conferência.** `numerosPermitidos` alimenta o
///    `ValidadorNumeros`, que marca qualquer cifra que não veio da simulação.
enum CategoriaAcao {
  leitura('Leitura', Icons.visibility_outlined),
  diagnostico('Diagnóstico', Icons.troubleshoot),
  cenario('Cenário', Icons.alt_route),
  redacao('Redação', Icons.edit_note),

  /// Explicação de um gráfico específico. Disparada pelo ícone ao lado do
  /// gráfico, não pela lista da aba de IA.
  grafico('Gráfico', Icons.insert_chart_outlined);

  const CategoriaAcao(this.label, this.icone);
  final String label;
  final IconData icone;
}

/// Uma ação disponível na aba de IA.
@immutable
class AcaoIa {
  const AcaoIa({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.categoria,
    required this.icone,
    required this.exigeAgenda,
    this.exigeCalibracao = false,
  });

  final String id;
  final String titulo;

  /// O que a ação responde — em uma frase, na linguagem de quem opera.
  final String descricao;

  final CategoriaAcao categoria;
  final IconData icone;

  /// Precisa de consultas na data selecionada.
  final bool exigeAgenda;

  /// Precisa de histórico calibrado.
  final bool exigeCalibracao;

  static const List<AcaoIa> catalogo = [
    AcaoIa(
      id: 'explicar_dia',
      titulo: 'Explicar este dia',
      descricao:
          'Por que a recomendação é esta, em linguagem de recepção — sem '
          'jargão de estatística.',
      categoria: CategoriaAcao.leitura,
      icone: Icons.wb_incandescent_outlined,
      exigeAgenda: true,
    ),
    AcaoIa(
      id: 'gargalo',
      titulo: 'Achar o gargalo',
      descricao:
          'Qual médico e qual hora estão puxando o risco do dia, e o que dá '
          'para fazer neles.',
      categoria: CategoriaAcao.diagnostico,
      icone: Icons.filter_center_focus,
      exigeAgenda: true,
    ),
    AcaoIa(
      id: 'testar_intervencao',
      titulo: 'Testar uma intervenção',
      descricao:
          'Roda o dia com lembrete ativo e compara: quanto a falta cai e '
          'quantos encaixes isso libera.',
      categoria: CategoriaAcao.cenario,
      icone: Icons.compare_arrows,
      exigeAgenda: true,
    ),
    AcaoIa(
      id: 'diagnosticar_dados',
      titulo: 'Diagnosticar a calibração',
      descricao:
          'Lê os achados de integridade e diz o que consertar primeiro nos '
          'dados — em ordem de impacto.',
      categoria: CategoriaAcao.diagnostico,
      icone: Icons.biotech_outlined,
      exigeAgenda: false,
      exigeCalibracao: true,
    ),
    AcaoIa(
      id: 'risco_equidade',
      titulo: 'Revisar equidade',
      descricao:
          'Verifica se o overbooking recomendado recai sempre nos mesmos '
          'pacientes e explica a leitura.',
      categoria: CategoriaAcao.diagnostico,
      icone: Icons.balance,
      exigeAgenda: true,
    ),
    AcaoIa(
      id: 'mensagem_fila',
      titulo: 'Redigir chamada da fila',
      descricao:
          'Escreve a mensagem para chamar quem está na lista de espera, com '
          'as vagas que de fato abriram.',
      categoria: CategoriaAcao.redacao,
      icone: Icons.forum_outlined,
      exigeAgenda: true,
    ),
    AcaoIa(
      id: 'resumo_gestao',
      titulo: 'Resumo para a gestão',
      descricao:
          'Um parágrafo com o essencial do dia, pronto para colar em ata ou '
          'mensagem de grupo.',
      categoria: CategoriaAcao.redacao,
      icone: Icons.summarize_outlined,
      exigeAgenda: true,
    ),
    // ── Explicações de gráfico ────────────────────────────────────────
    //
    // Passam pelo mesmo validador das outras, mas são disparadas pelo ícone ao
    // lado de cada gráfico. Ficam fora de [lista] para não duplicar a oferta.
    AcaoIa(
      id: 'grafico_distribuicao',
      titulo: 'Explicar a distribuição de faltas',
      descricao:
          'O que as barras e as marcas P05/P50/P95 querem dizer nesta data.',
      categoria: CategoriaAcao.grafico,
      icone: Icons.bar_chart,
      exigeAgenda: true,
    ),
    AcaoIa(
      id: 'grafico_composicao',
      titulo: 'Explicar a composição da agenda',
      descricao: 'Quem está exposto às decisões desta tela.',
      categoria: CategoriaAcao.grafico,
      icone: Icons.donut_small_outlined,
      exigeAgenda: true,
    ),
    AcaoIa(
      id: 'grafico_sazonalidade',
      titulo: 'Explicar a sobredispersão do ano',
      descricao: 'Se a variação entre meses é sinal ou ruído.',
      categoria: CategoriaAcao.grafico,
      icone: Icons.show_chart,
      exigeAgenda: false,
      exigeCalibracao: true,
    ),
    AcaoIa(
      id: 'grafico_slots',
      titulo: 'Explicar o risco por slot',
      descricao: 'A tabela de médico × hora, lida em ordem de urgência.',
      categoria: CategoriaAcao.grafico,
      icone: Icons.grid_on,
      exigeAgenda: true,
    ),
  ];

  /// Ações que aparecem na lista da aba de IA (sem as de gráfico).
  static List<AcaoIa> get lista =>
      catalogo.where((a) => a.categoria != CategoriaAcao.grafico).toList();

  static AcaoIa? porId(String id) =>
      catalogo.where((a) => a.id == id).firstOrNull;
}

/// Contexto factual de uma ação: o que a IA recebe, e os números que ela pode
/// citar.
@immutable
class ContextoAcao {
  const ContextoAcao({
    required this.instrucao,
    required this.fatos,
    required this.numerosPermitidos,
  });

  /// Instrução de sistema específica da ação.
  final String instrucao;

  /// Os dados, já calculados, em texto.
  final String fatos;

  /// Cifras que apareceram nos fatos — o conjunto que o validador aceita.
  final Set<String> numerosPermitidos;

  String get prompt => '$instrucao\n\nDADOS DA SIMULAÇÃO:\n$fatos';
}

/// Monta o contexto de cada ação a partir do resultado determinístico.
///
/// Tudo aqui é Dart puro: o modelo nunca vê a agenda, só o resumo que este
/// arquivo produz. É o que torna a saída conferível.
class MontadorContexto {
  const MontadorContexto();

  static const String _regras = '''
Você lê o resultado de uma simulação de agenda clínica e escreve para quem
opera a recepção — não para estatístico.

REGRAS ABSOLUTAS:
- Use APENAS os números fornecidos nos dados. Nunca calcule, estime ou
  arredonde um número novo. Se um número não está nos dados, não o escreva.
- Não invente nome de paciente, médico ou horário que não esteja nos dados.
- Nada do que você escrever é aplicado automaticamente. Escreva como sugestão.
- Português do Brasil, direto, sem jargão. Não use "outrossim", "ademais",
  "é importante ressaltar".
- No máximo 5 frases curtas, salvo instrução em contrário.''';

  ContextoAcao? montar({
    required String acaoId,
    required SimulacaoResultado? resultado,
    required CalibracaoResultado? calibracao,
    required List<CenarioOverbooking> cenarios,
    required int encaixesRecomendados,
    required double limiteRisco,
  }) {
    switch (acaoId) {
      case 'explicar_dia':
        return _explicarDia(resultado, encaixesRecomendados, limiteRisco);
      case 'gargalo':
        return _gargalo(resultado, limiteRisco);
      case 'testar_intervencao':
        return _intervencao(resultado, limiteRisco);
      case 'diagnosticar_dados':
        return _diagnosticar(calibracao);
      case 'risco_equidade':
        return _equidade(resultado, cenarios, encaixesRecomendados);
      case 'mensagem_fila':
        return _mensagemFila(resultado);
      case 'resumo_gestao':
        return _resumo(resultado, encaixesRecomendados);
      case 'grafico_distribuicao':
        return grafDistribuicao(resultado);
      case 'grafico_composicao':
        return grafComposicao(resultado);
      case 'grafico_sazonalidade':
        return grafSazonalidade(calibracao);
      case 'grafico_slots':
        return grafSlots(resultado, limiteRisco);
      default:
        return null;
    }
  }

  // ── Ações ──────────────────────────────────────────────────────────

  ContextoAcao? _explicarDia(
      SimulacaoResultado? r, int encaixes, double limite) {
    if (r == null || r.totalAgendados == 0) return null;
    final emRisco = r.slotsEmRisco(limite);

    final fatos = StringBuffer()
      ..writeln('Data: ${_data(r.data)}')
      ..writeln('Consultas agendadas: ${r.totalAgendados}')
      ..writeln('Faltas esperadas (média): ${_n(r.faltasEsperadas, 1)}')
      ..writeln('Faltas no dia típico (P50): ${r.faltas.p50}')
      ..writeln('Faltas no dia ruim (P95): ${r.faltas.p95}')
      ..writeln('Cancelamentos com aviso esperados: '
          '${_n(r.cancelamentosEsperados, 1)}')
      ..writeln('Pacientes que podem ser chamados da fila: '
          '${r.fila.chamadasSeguras}')
      ..writeln('Encaixes recomendados: $encaixes')
      ..writeln('Slots acima do limite de risco: ${emRisco.length} '
          'de ${r.slots.length}')
      ..writeln('Limite de risco por slot: ${_pct(limite)}');

    if (emRisco.isNotEmpty) {
      final pior = emRisco.first;
      fatos.writeln('Pior slot: ${pior.doctorName} às ${pior.hour}h, '
          'com ${pior.agendados} agendados para ${pior.capacidade} de '
          'capacidade e ${_pct(pior.riscoEstouro(0))} de risco de estouro');
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: explique em até 4 frases por que a recomendação de encaixes '
          'é a que está nos dados. Diga o que a recepção deve fazer hoje. '
          'Se os encaixes recomendados forem 0, explique que isso significa '
          'que a agenda já está apertada — não que o sistema falhou.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? _gargalo(SimulacaoResultado? r, double limite) {
    if (r == null || r.slots.isEmpty) return null;
    final ordenados = [...r.slots]
      ..sort((a, b) => b.riscoEstouro(0).compareTo(a.riscoEstouro(0)));
    final top = ordenados.take(5).toList();

    final fatos = StringBuffer()
      ..writeln('Data: ${_data(r.data)}')
      ..writeln('Total de slots (médico x hora): ${r.slots.length}')
      ..writeln('Limite de risco tolerado: ${_pct(limite)}')
      ..writeln('')
      ..writeln('Cinco slots de maior risco:');
    for (final s in top) {
      fatos.writeln('- ${s.doctorName}, ${s.hour}h: ${s.agendados} agendados, '
          'capacidade ${s.capacidade}, presentes P95 ${s.presentes.p95}, '
          'risco ${_pct(s.riscoEstouro(0))}, '
          '${_pct(s.fracaoAltoRisco, casas: 0)} de pacientes de alto risco');
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: aponte qual slot é o gargalo e por quê. Em seguida sugira '
          'no máximo 2 ações concretas que a recepção pode tomar naquele slot '
          '(exemplos: confirmar ativamente os pacientes daquele horário, '
          'remanejar um paciente de baixo risco para outro dia). '
          'Não sugira aumentar capacidade — isso não é decisão da recepção.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? _intervencao(SimulacaoResultado? r, double limite) {
    if (r == null || r.totalAgendados == 0) return null;

    // Roda o mesmo dia com lembrete ativo. Determinístico, em Dart.
    const oddsRatio = 0.6; // redução típica de falta com confirmação ativa
    final comLembrete = r.consultas
        .map((c) => ConsultaRisco(
              appointmentId: c.appointmentId,
              doctorId: c.doctorId,
              hour: c.hour,
              pFalta: MonteCarloEngine.aplicarIntervencao(c.pFalta, oddsRatio),
              pCancel: c.pCancel,
              risco: c.risco,
            ))
        .toList();

    final depois = MonteCarloEngine.simular(
      data: r.data,
      consultas: comLembrete,
      capacidades: {
        for (final s in r.slots)
          '${s.doctorId}|${s.hour}': [s.capacidadeFisica, s.capacidadeConfigurada],
      },
      nomes: {for (final s in r.slots) s.doctorId: s.doctorName},
      config: r.config,
    );

    final kAntes = MonteCarloEngine.encaixesRecomendados(r, limiteRisco: limite);
    final kDepois =
        MonteCarloEngine.encaixesRecomendados(depois, limiteRisco: limite);

    final fatos = StringBuffer()
      ..writeln('Cenário testado: confirmação ativa por lembrete, com efeito '
          'de razão de chances 0,6 (hipótese setorial, não medida nesta '
          'clínica)')
      ..writeln('')
      ..writeln('SEM a intervenção:')
      ..writeln('- Faltas esperadas: ${_n(r.faltasEsperadas, 1)}')
      ..writeln('- Faltas P95: ${r.faltas.p95}')
      ..writeln('- Encaixes recomendados: $kAntes')
      ..writeln('')
      ..writeln('COM a intervenção:')
      ..writeln('- Faltas esperadas: ${_n(depois.faltasEsperadas, 1)}')
      ..writeln('- Faltas P95: ${depois.faltas.p95}')
      ..writeln('- Encaixes recomendados: $kDepois')
      ..writeln('')
      ..writeln('Consultas que receberiam o lembrete: ${r.totalAgendados}');

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: compare os dois cenários em até 4 frases. Deixe claro que '
          'o efeito de 0,6 é hipótese, não medição desta clínica — e que o '
          'ganho só se confirma medindo. Se os encaixes recomendados não '
          'mudarem, diga isso: significa que o gargalo não é a falta.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? _diagnosticar(CalibracaoResultado? c) {
    if (c == null) return null;

    final fatos = StringBuffer()
      ..writeln('Dias de histórico analisados: ${c.diasAnalisados} '
          '(a fase F2 pede 120)')
      ..writeln('Consultas com desfecho: ${c.consultasAnalisadas}')
      ..writeln('Sobredispersão observada: ${_n(c.phi, 2)}')
      ..writeln('Correlação estimada: ${_n(c.rhoEstimado, 3)}, '
          'intervalo de 95% de ${_n(c.rhoIc95.$1, 3)} a '
          '${_n(c.rhoIc95.$2, 3)}')
      ..writeln('Dependência conclusiva: ${c.rhoConclusivo ? "sim" : "não"}')
      ..writeln('Pode aplicar os parâmetros medidos: '
          '${c.podeAplicar ? "sim" : "não"}');

    if (c.backtest.temAmostras) {
      fatos.writeln('Cobertura do intervalo P05-P95: '
          '${_pct(c.backtest.cobertura90, casas: 0)} (esperado perto de 90%)');
    }

    fatos.writeln('');
    for (final f in RiskLevel.values) {
      final t = c.taxas[f];
      if (t == null || t.total == 0) continue;
      fatos.writeln('Faixa ${f.label}: ${t.total} consultas, '
          'taxa de falta ${_pct(t.taxaFalta)}, '
          'amostra ${t.confiavel ? "suficiente" : "pequena"}');
    }

    if (c.integridade.achados.isNotEmpty) {
      fatos.writeln('');
      fatos.writeln('Problemas encontrados nos dados:');
      for (final a in c.integridade.achados) {
        fatos.writeln('- [${a.bloqueia ? "BLOQUEIA" : "atenção"}] '
            '${a.titulo}: ${a.detalhe}'
            '${a.acao.isNotEmpty ? " | Ação: ${a.acao}" : ""}');
      }
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: liste em ordem de impacto o que precisa ser consertado nos '
          'dados para a calibração valer, no máximo 4 itens. Cada item: o que '
          'está errado e quem conserta (recepção, TI, ou fornecedor do '
          'sistema). Não repita o texto dos problemas — resuma e priorize. '
          'Se não houver nada bloqueando, diga em uma frase e pare.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? _equidade(SimulacaoResultado? r,
      List<CenarioOverbooking> cenarios, int encaixes) {
    if (r == null || r.totalAgendados == 0) return null;

    final cenario = cenarios
        .where((c) => c.encaixes == (encaixes > 0 ? encaixes : 1))
        .firstOrNull;
    if (cenario == null) return null;

    final eq = cenario.equidade;
    final fatos = StringBuffer()
      ..writeln('Cenário avaliado: ${cenario.encaixes} encaixe(s)')
      ..writeln('Razão máxima de exposição: ${_n(eq.razaoMaxima, 2)} '
          '(1,00 significa carga proporcional à presença na agenda)')
      ..writeln('Dentro do limite: ${eq.dentroDoLimite ? "sim" : "não"}')
      ..writeln('');

    for (final f in RiskLevel.values) {
      final part = eq.participacaoPorFaixa[f] ?? 0;
      final exp = eq.exposicaoPorFaixa[f] ?? 0;
      if (part <= 0) continue;
      fatos.writeln('Faixa ${f.label}: ${_pct(part, casas: 0)} da agenda, '
          'absorve ${_n(exp, 2)} encaixe(s)');
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: explique em até 4 frases se o overbooking recomendado está '
          'recaindo desproporcionalmente sobre alguma faixa de risco, e por '
          'que isso importa: encaixar num horário aumenta a espera de TODOS '
          'os pacientes daquele horário, e pacientes de alto risco costumam '
          'ser os de menor renda e maior distância. Não use a palavra '
          '"discriminação" — descreva o efeito.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? _mensagemFila(SimulacaoResultado? r) {
    if (r == null || r.fila.chamadasSeguras <= 0) return null;

    final fatos = StringBuffer()
      ..writeln('Data: ${_data(r.data)}')
      ..writeln('Pacientes que podem ser chamados: '
          '${r.fila.chamadasSeguras}')
      ..writeln('Vagas liberadas por cancelamento (quartil inferior): '
          '${r.fila.liberadasP25}')
      ..writeln('Vagas liberadas (mediana): ${r.fila.liberadasP50}')
      ..writeln('');
    if (r.fila.detalhePorSlot.isNotEmpty) {
      fatos.writeln('Distribuição por horário:');
      for (final e in r.fila.detalhePorSlot.entries.take(8)) {
        final partes = e.key.split('|');
        final nome = r.slots
                .where((s) => s.doctorId == partes.first)
                .firstOrNull
                ?.doctorName ??
            partes.first;
        fatos.writeln('- $nome, ${partes.last}h: ${e.value} vaga(s)');
      }
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: escreva UMA mensagem curta de WhatsApp para o paciente da '
          'lista de espera, oferecendo a vaga. Máximo 3 frases. Tom cordial e '
          'direto, sem emoji em excesso (no máximo um). Deixe um espaço '
          'marcado como [NOME] e outro como [HORÁRIO] para a recepção '
          'preencher. Não prometa nada que os dados não digam. '
          'Depois da mensagem, escreva uma linha dizendo quantos pacientes '
          'podem ser chamados.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? _resumo(SimulacaoResultado? r, int encaixes) {
    if (r == null || r.totalAgendados == 0) return null;

    final fatos = StringBuffer()
      ..writeln('Data: ${_data(r.data)}')
      ..writeln('Agendados: ${r.totalAgendados}')
      ..writeln('Faltas esperadas: ${_n(r.faltasEsperadas, 1)}')
      ..writeln('Faltas P50: ${r.faltas.p50}, P95: ${r.faltas.p95}')
      ..writeln('Cancelamentos com aviso: '
          '${_n(r.cancelamentosEsperados, 1)}')
      ..writeln('Chamadas seguras da fila: ${r.fila.chamadasSeguras}')
      ..writeln('Encaixes recomendados: $encaixes')
      ..writeln('Slots no total: ${r.slots.length}')
      ..writeln('Sobredispersão da simulação: '
          '${r.exato ? "1,00 (modelo independente)" : _n(r.phiObservado, 2)}')
      ..writeln('Execuções da simulação: ${r.config.nRuns}')
      ..writeln('Modelo calibrado com dados reais: não');

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: escreva UM parágrafo de até 5 frases, pronto para colar em '
          'mensagem de grupo da gestão. Comece pelo número que decide '
          '(encaixes recomendados). Termine mencionando que a projeção não '
          'está calibrada com dados reais desta clínica.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  // ── Explicações de gráfico ─────────────────────────────────────────

  ContextoAcao? grafDistribuicao(SimulacaoResultado? r) {
    if (r == null || r.totalAgendados == 0) return null;
    final f = r.faltas;

    final fatos = StringBuffer()
      ..writeln('Gráfico: histograma do número de faltas do dia.')
      ..writeln('Cada barra é um número possível de faltas; a altura é quantas '
          'vezes aquele número apareceu nas execuções da simulação.')
      ..writeln('')
      ..writeln('Agendados: ${r.totalAgendados}')
      ..writeln('P05, o dia bom: ${f.p05} faltas')
      ..writeln('P50, o dia típico: ${f.p50} faltas')
      ..writeln('P95, o dia ruim: ${f.p95} faltas')
      ..writeln('Média: ${_n(f.media, 1)}')
      ..writeln('Desvio: ${_n(f.desvio, 2)}')
      ..writeln('Largura entre P05 e P95: ${f.p95 - f.p05} faltas')
      ..writeln('Execuções: ${r.config.nRuns}')
      ..writeln('Veio de forma fechada exata: ${r.exato ? "sim" : "não"}');

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: explique este gráfico em até 4 frases para quem nunca viu '
          'histograma. Diga o que a LARGURA significa na prática — a diferença '
          'entre um dia bom e um dia ruim — e por que o P95 é o número que '
          'decide overbooking, e não a média.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? grafComposicao(SimulacaoResultado? r) {
    if (r == null || r.totalAgendados == 0) return null;
    final comp = r.composicaoRisco;

    final fatos = StringBuffer()
      ..writeln('Gráfico: composição da agenda por faixa de risco de falta.')
      ..writeln('Total de consultas: ${r.totalAgendados}');
    for (final f in RiskLevel.values) {
      final q = comp[f] ?? 0;
      if (q == 0) continue;
      fatos.writeln('Faixa ${f.label}: $q consultas, '
          '${_pct(q / r.totalAgendados, casas: 0)} da agenda');
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: em até 3 frases, diga o que esta composição implica para o '
          'dia. Se uma única faixa concentrar quase tudo, avise que a '
          'estratificação pode não estar chegando do banco — e que nesse caso '
          'o risco individual não difere entre pacientes.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? grafSazonalidade(CalibracaoResultado? c) {
    if (c == null || c.porMes.isEmpty) return null;

    final fatos = StringBuffer()
      ..writeln('Gráfico: sobredispersão (phi) mês a mês.')
      ..writeln('phi igual a 1,00 significa faltas independentes entre si.')
      ..writeln('phi acima de 1 significa que as faltas do mesmo dia se movem '
          'juntas — chuva, feriado, greve de transporte.')
      ..writeln('')
      ..writeln('Meses com dias suficientes para o teste: '
          '${c.mesesTestaveis}, e o teste precisa de 4')
      ..writeln('O teste pôde rodar: ${c.sazonalidadeTestavel ? "sim" : "não"}')
      ..writeln('A variação supera o ruído: '
          '${c.sazonalidadeSignificativa ? "sim" : "não"}')
      ..writeln('');
    for (final m in c.porMes) {
      fatos.writeln('${m.nome}: phi ${_n(m.phi, 2)}, ${m.dias} dias');
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: em até 4 frases, explique se a variação entre os meses é '
          'sinal ou ruído. Se o teste não pôde rodar por falta de meses, diga '
          'isso claramente: "não deu para testar" não é a mesma coisa que '
          '"testei e não há sazonalidade". Cada mês tem poucos dias, então a '
          'barra isolada é ruidosa.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  ContextoAcao? grafSlots(SimulacaoResultado? r, double limite) {
    if (r == null || r.slots.isEmpty) return null;

    final ordenados = [...r.slots]
      ..sort((a, b) => b.riscoEstouro(0).compareTo(a.riscoEstouro(0)));
    final acima = r.slotsEmRisco(limite);

    final fatos = StringBuffer()
      ..writeln('Tabela: risco de estouro por slot, médico por hora.')
      ..writeln('Total de slots: ${r.slots.length}')
      ..writeln('Slots acima do limite de ${_pct(limite, casas: 0)}: '
          '${acima.length}')
      ..writeln('Capacidade de referência: ${r.config.baseCapacidade.label}')
      ..writeln('');
    for (final s in ordenados.take(6)) {
      fatos.writeln('- ${s.doctorName}, ${s.hour}h: ${s.agendados} agendados '
          'para capacidade ${s.capacidade}, presentes P95 '
          '${s.presentes.p95}, risco ${_pct(s.riscoEstouro(0))}');
    }

    return ContextoAcao(
      instrucao: '$_regras\n\n'
          'TAREFA: explique em até 4 frases como ler esta tabela e por que a '
          'decisão é tomada pelo PIOR slot, não pela média do dia — uma falta '
          'às 16h não libera vaga às 9h. Aponte qual linha merece atenção '
          'primeiro.',
      fatos: fatos.toString(),
      numerosPermitidos: _numeros(fatos.toString()),
    );
  }

  // ── Utilidades ─────────────────────────────────────────────────────

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _n(num v, int casas) => NumPtBr.dec(v, casas: casas);
  static String _pct(num v, {int casas = 1}) =>
      NumPtBr.pct(v, casas: casas);

  /// Extrai do texto de fatos toda cifra que a IA está autorizada a citar.
  ///
  /// Deliberadamente generoso: melhor aceitar um número que o modelo copiou
  /// corretamente do que alarmar por um valor legítimo. O validador só precisa
  /// pegar a cifra **inventada**.
  static Set<String> _numeros(String fatos) {
    final re = RegExp(r'\d+(?:[.,]\d+)?');
    return re.allMatches(fatos).map((m) => m.group(0)!).toSet();
  }
}
