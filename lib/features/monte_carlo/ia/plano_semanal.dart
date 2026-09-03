import '../monte_carlo_engine.dart';
import '../monte_carlo_models.dart';

/// O plano de encaixes de vários dias, montado **em código**.
///
/// ## A divisão de trabalho que sustenta este módulo
///
/// | Quem | Faz o quê |
/// |---|---|
/// | Simulador | produz os números (encaixes, risco, receita, ociosidade) |
/// | Modelo de IA | **só interpreta** — prioriza, explica, alerta |
/// | [ValidadorNumeros] | confere que a IA não inventou nenhum número |
///
/// Não é preciosismo. Um número inventado aqui vira **decisão de agenda**: uma
/// clínica que encaixa 6 pacientes porque a IA disse "6" — quando a simulação
/// disse 2 — enche a sala de espera de gente real. O modelo não tem acesso à
/// aritmética; ele recebe o resultado pronto e escreve sobre ele.
///
/// É o mesmo desenho do módulo de Evidências: o código produz o fato, o modelo
/// explica, e uma checagem determinística recusa o que não bate.
class PlanoSemanal {
  const PlanoSemanal({required this.dias, required this.geradoEm});

  final List<DiaPlanejado> dias;
  final DateTime geradoEm;

  bool get vazio => dias.isEmpty;

  /// Dias com agenda de verdade. Feriado e domingo entram na varredura (para
  /// o gestor ver que foram olhados) mas não contam nas somas.
  List<DiaPlanejado> get comAgenda =>
      dias.where((d) => d.totalAgendados > 0).toList();

  int get totalEncaixes =>
      comAgenda.fold(0, (s, d) => s + d.encaixesRecomendados);

  double get receitaAdicional =>
      comAgenda.fold(0.0, (s, d) => s + d.receitaAdicional);

  /// Dias em que a recomendação é zero **apesar de haver agenda** — é onde o
  /// gestor precisa olhar, porque significa risco alto ou agenda já cheia.
  List<DiaPlanejado> get bloqueados =>
      comAgenda.where((d) => d.encaixesRecomendados == 0).toList();

  /// Dias com folga grande: ociosidade esperada alta e nenhum encaixe sugerido
  /// seria desperdício; aqui indica que **cabe mais** do que o limite permite.
  List<DiaPlanejado> get comFolga =>
      comAgenda.where((d) => d.ociosidadeEsperada >= 2.0).toList();

  /// Todos os números que o plano contém, para a validação da resposta da IA.
  Set<String> get numerosPermitidos {
    final n = <String>{};
    for (final d in dias) {
      n.addAll(d.numeros);
    }
    n.add('$totalEncaixes');
    n.add(receitaAdicional.round().toString());
    n.add('${comAgenda.length}');
    n.add('${bloqueados.length}');
    return n;
  }

  /// Resumo textual entregue ao modelo. É **a única fonte** que ele recebe.
  String paraPrompt() {
    final b = StringBuffer();
    b.writeln('PLANO DE ENCAIXES — ${comAgenda.length} dia(s) com agenda');
    b.writeln('Total recomendado: $totalEncaixes encaixe(s)');
    b.writeln('Receita adicional estimada: R\$ ${receitaAdicional.round()}');
    b.writeln();
    for (final d in dias) {
      b.writeln(d.paraPrompt());
    }
    return b.toString();
  }
}

/// Um dia da varredura.
class DiaPlanejado {
  const DiaPlanejado({
    required this.data,
    required this.totalAgendados,
    required this.encaixesRecomendados,
    required this.riscoMaximoSlot,
    required this.slotsAcimaDoLimite,
    required this.faltasEsperadas,
    required this.ociosidadeEsperada,
    required this.receitaAdicional,
    required this.motivo,
    this.erro,
  });

  /// O dia não pôde ser simulado (agenda indisponível, falha do motor).
  factory DiaPlanejado.falhou(DateTime data, String erro) => DiaPlanejado(
        data: data,
        totalAgendados: 0,
        encaixesRecomendados: 0,
        riscoMaximoSlot: 0,
        slotsAcimaDoLimite: 0,
        faltasEsperadas: 0,
        ociosidadeEsperada: 0,
        receitaAdicional: 0,
        motivo: 'Não simulado',
        erro: erro,
      );

  final DateTime data;
  final int totalAgendados;

  /// Quantos encaixes cabem mantendo **todos** os slots dentro do limite de
  /// risco e de equidade. Vem de `MonteCarloEngine.encaixesRecomendados`.
  final int encaixesRecomendados;

  final double riscoMaximoSlot;
  final int slotsAcimaDoLimite;
  final double faltasEsperadas;
  final double ociosidadeEsperada;
  final double receitaAdicional;
  final String motivo;
  final String? erro;

  bool get ok => erro == null;
  bool get temAgenda => totalAgendados > 0;

  /// Nível de atenção do dia — usado para colorir o cartão.
  ///
  /// Não é o "risco" da simulação: é **quanto o gestor precisa olhar**. Um dia
  /// tranquilo com 3 encaixes livres é verde; um dia cheio que não aceita
  /// nenhum encaixe é vermelho, ainda que a simulação esteja perfeita.
  AtencaoDia get atencao {
    if (!ok) return AtencaoDia.falha;
    if (!temAgenda) return AtencaoDia.semAgenda;
    if (slotsAcimaDoLimite > 0) return AtencaoDia.critico;
    if (encaixesRecomendados == 0) return AtencaoDia.cheio;
    if (ociosidadeEsperada >= 2.0) return AtencaoDia.folga;
    return AtencaoDia.ok;
  }

  /// Números deste dia, como aparecem no texto — base da validação.
  Set<String> get numeros => {
        '$totalAgendados',
        '$encaixesRecomendados',
        '$slotsAcimaDoLimite',
        faltasEsperadas.toStringAsFixed(1),
        faltasEsperadas.round().toString(),
        ociosidadeEsperada.toStringAsFixed(1),
        ociosidadeEsperada.round().toString(),
        receitaAdicional.round().toString(),
        (riscoMaximoSlot * 100).toStringAsFixed(1),
        (riscoMaximoSlot * 100).round().toString(),
        '${data.day}',
      };

  String paraPrompt() {
    if (!ok) return '- ${_dia()}: não foi possível simular ($erro)';
    if (!temAgenda) return '- ${_dia()}: sem agenda';
    return '- ${_dia()}: $totalAgendados agendados · '
        'recomenda $encaixesRecomendados encaixe(s) · '
        'risco máx. de slot ${(riscoMaximoSlot * 100).toStringAsFixed(1)}% · '
        '$slotsAcimaDoLimite slot(s) acima do limite · '
        'faltas esperadas ${faltasEsperadas.toStringAsFixed(1)} · '
        'ociosidade ${ociosidadeEsperada.toStringAsFixed(1)} · '
        'receita adicional R\$ ${receitaAdicional.round()} · $motivo';
  }

  String _dia() {
    const nomes = [
      'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo',
    ];
    final dd = data.day.toString().padLeft(2, '0');
    final mm = data.month.toString().padLeft(2, '0');
    return '$dd/$mm (${nomes[data.weekday - 1]})';
  }
}

/// Quanto o dia pede atenção do gestor.
enum AtencaoDia {
  ok('Dentro do esperado', 'Tranquilo'),
  folga('Sobra capacidade', 'Sobra'),
  cheio('Sem espaço para encaixe', 'Cheio'),
  critico('Slots acima do limite', 'Crítico'),
  semAgenda('Sem agenda', 'Sem agenda'),
  falha('Não simulado', 'Não simulado');

  const AtencaoDia(this.rotulo, this.curto);

  /// Texto completo — para a legenda e o estado vazio do cartão.
  final String rotulo;

  /// Uma palavra, para o selo. Um selo é uma pílula de ~90px: "Sem espaço para
  /// encaixe" não cabe ali em tela nenhuma, e forçar produz reticências que
  /// não comunicam nada.
  final String curto;

  bool get pedeAtencao => this == cheio || this == critico;
}

/// Roda a simulação para vários dias e monta o plano — **sem IA nenhuma**.
///
/// Separado do agente de propósito: este resultado é reprodutível (mesma
/// semente, mesma saída) e é o que a tela mostra mesmo quando a IA está fora
/// do ar. O modelo entra depois, só para interpretar.
class ExecutorPlano {
  const ExecutorPlano({
    required this.limiteRisco,
    required this.limiteEquidade,
    required this.valorSlot,
  });

  final double limiteRisco;
  final double limiteEquidade;
  final double valorSlot;

  /// Simula [dias] dias a partir de [inicio].
  ///
  /// [consultasDe] e [simular] são injetados para o teste rodar sem Riverpod e
  /// sem o isolate — o executor é lógica de orquestração, não de simulação.
  PlanoSemanal montar({
    required DateTime inicio,
    required int dias,
    required List<ConsultaRisco> Function(DateTime) consultasDe,
    required SimulacaoResultado Function(DateTime, List<ConsultaRisco>) simular,
  }) {
    final out = <DiaPlanejado>[];

    for (var i = 0; i < dias; i++) {
      final d = DateTime(inicio.year, inicio.month, inicio.day + i);
      try {
        final consultas = consultasDe(d);
        if (consultas.isEmpty) {
          out.add(DiaPlanejado(
            data: d,
            totalAgendados: 0,
            encaixesRecomendados: 0,
            riscoMaximoSlot: 0,
            slotsAcimaDoLimite: 0,
            faltasEsperadas: 0,
            ociosidadeEsperada: 0,
            receitaAdicional: 0,
            motivo: 'Sem agenda',
          ));
          continue;
        }

        final r = simular(d, consultas);
        final k = MonteCarloEngine.encaixesRecomendados(
          r,
          limiteRisco: limiteRisco,
          limiteEquidade: limiteEquidade,
        );
        final cenarios = MonteCarloEngine.varrerCenarios(
          r,
          limiteRisco: limiteRisco,
          valorSlot: valorSlot,
          limiteEquidade: limiteEquidade,
        );
        // O cenário do k recomendado carrega as métricas daquele plano.
        // Recalculá-las aqui daria números levemente diferentes por ruído de
        // amostragem — e dois números para a mesma coisa é pior que um.
        //
        // Não se fabrica um cenário quando a varredura vem vazia: um objeto
        // com zeros passaria por resultado de simulação, e "0 encaixes porque
        // está cheio" é indistinguível de "0 porque não simulou".
        CenarioOverbooking? escolhido;
        for (final c in cenarios) {
          if (c.encaixes == k) {
            escolhido = c;
            break;
          }
        }
        escolhido ??= cenarios.isEmpty ? null : cenarios.first;

        out.add(DiaPlanejado(
          data: d,
          totalAgendados: r.totalAgendados,
          encaixesRecomendados: k,
          riscoMaximoSlot: escolhido?.riscoMaximoSlot ?? 0,
          slotsAcimaDoLimite: escolhido?.slotsAcimaDoLimite ?? 0,
          faltasEsperadas: r.faltas.media,
          ociosidadeEsperada: escolhido?.ociosidadeEsperada ?? 0,
          receitaAdicional: k * valorSlot,
          motivo: escolhido?.motivo ?? 'Sem cenário viável',
        ));
      } catch (e) {
        // Um dia que falha não pode derrubar a semana inteira: o gestor ainda
        // precisa do plano dos outros seis.
        out.add(DiaPlanejado.falhou(d, '$e'));
      }
    }

    return PlanoSemanal(dias: out, geradoEm: DateTime.now());
  }
}
