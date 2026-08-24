import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Color;

import '../data/models/aresta.dart';
import '../data/models/nota.dart';
import '../data/models/nota_enums.dart';
import '../index/busca_service.dart';
import '../index/vault_index.dart';

/// Intencao detectada antes de o Agente consultar o modelo remoto.
///
/// O classificador eh deliberadamente local e deterministico: a busca continua
/// util sem rede e da ao modelo remoto candidatos com evidencias concretas.
enum AgentSearchIntent {
  discover,
  overview,
  causes,
  impacts,
  path,
  risk,
  gaps,
  decision,
  protocol,
  timeline,
}

extension AgentSearchIntentLabel on AgentSearchIntent {
  String get label => switch (this) {
        AgentSearchIntent.discover => 'Descobrir conhecimento',
        AgentSearchIntent.overview => 'Visao estrategica',
        AgentSearchIntent.causes => 'Rastrear causas',
        AgentSearchIntent.impacts => 'Mapear impactos',
        AgentSearchIntent.path => 'Encontrar conexao',
        AgentSearchIntent.risk => 'Priorizar riscos',
        AgentSearchIntent.gaps => 'Encontrar lacunas',
        AgentSearchIntent.decision => 'Localizar autoridade',
        AgentSearchIntent.protocol => 'Buscar protocolo',
        AgentSearchIntent.timeline => 'Rastrear historico',
      };

  String get promptExample => switch (this) {
        AgentSearchIntent.discover => 'O que sabemos sobre confirmacao?',
        AgentSearchIntent.overview => 'Quais sao os hubs mais importantes?',
        AgentSearchIntent.causes => 'Quais causas explicam o absenteismo?',
        AgentSearchIntent.impacts => 'Que impacto tem o overbooking?',
        AgentSearchIntent.path => 'Mostre a conexao entre agenda e risco',
        AgentSearchIntent.risk => 'Quais riscos precisam de atencao?',
        AgentSearchIntent.gaps => 'Onde estao as lacunas de conhecimento?',
        AgentSearchIntent.decision => 'Qual protocolo orienta a confirmacao?',
        AgentSearchIntent.protocol => 'Como tratar paciente de risco?',
        AgentSearchIntent.timeline => 'Historico de decisoes sobre absenteismo',
      };

  Color get intentColor => switch (this) {
        AgentSearchIntent.discover => const Color(0xFF0EA5E9),
        AgentSearchIntent.overview => const Color(0xFFF43F5E),
        AgentSearchIntent.causes => const Color(0xFFF59E0B),
        AgentSearchIntent.impacts => const Color(0xFF7C3AED),
        AgentSearchIntent.path => const Color(0xFF2E9E8F),
        AgentSearchIntent.risk => const Color(0xFFC62828),
        AgentSearchIntent.gaps => const Color(0xFFC77700),
        AgentSearchIntent.decision => const Color(0xFF1B53D0),
        AgentSearchIntent.protocol => const Color(0xFF10B981),
        AgentSearchIntent.timeline => const Color(0xFF64748B),
      };
}

/// Evidencia de uma nota retornada pelo Agente. Nao contem cadeia de
/// pensamento: so razoes verificaveis para o usuario inspecionar no grafo.
class AgentSearchEvidence {
  const AgentSearchEvidence({
    required this.noteId,
    required this.score,
    this.reasons = const [],
  });

  final String noteId;
  final double score;
  final List<String> reasons;
}

/// Resultado local enriquecido para a interface e para ancorar a analise IA.
class AgentSearchAnalysis {
  const AgentSearchAnalysis({
    required this.intent,
    required this.evidence,
    required this.summary,
    required this.confidence,
    this.recommendations = const [],
    this.structuralInsights = const [],
    this.remoteValidated = false,
  });

  final AgentSearchIntent intent;
  final List<AgentSearchEvidence> evidence;
  final String summary;
  final double confidence;
  final List<String> recommendations;

  /// Insights topologicos da analise (ex: "hub com 15 conexoes",
  /// "ponte entre clusters").
  final List<String> structuralInsights;
  final bool remoteValidated;

  Set<String> get noteIds => {for (final item in evidence) item.noteId};

  AgentSearchAnalysis copyWith({
    List<AgentSearchEvidence>? evidence,
    String? summary,
    double? confidence,
    List<String>? recommendations,
    List<String>? structuralInsights,
    bool? remoteValidated,
  }) =>
      AgentSearchAnalysis(
        intent: intent,
        evidence: evidence ?? this.evidence,
        summary: summary ?? this.summary,
        confidence: confidence ?? this.confidence,
        recommendations: recommendations ?? this.recommendations,
        structuralInsights: structuralInsights ?? this.structuralInsights,
        remoteValidated: remoteValidated ?? this.remoteValidated,
      );
}

/// Motor de recuperacao aumentada local do modo Agente.
///
/// Combina busca textual, autoridade operacional, centralidade do grafo e
/// topologia. O modelo remoto recebe apenas o conjunto ja recuperado e nunca
/// eh a unica fonte de resultados.
class AgentSearchEngine {
  AgentSearchEngine(this._index);

  final VaultIndex _index;

  AgentSearchAnalysis analyze(String rawQuery, {int limit = 10}) {
    final query = rawQuery.trim();
    final intent = detectIntent(query);
    final notes = _index.notas.values.where((note) => !note.excluida).toList();
    if (query.isEmpty || notes.isEmpty) {
      return AgentSearchAnalysis(
        intent: intent,
        evidence: const [],
        summary: notes.isEmpty
            ? 'Ainda nao ha notas indexadas no Cerebro.'
            : 'Descreva o que voce quer investigar para o Agente montar uma analise.',
        confidence: 0,
        recommendations: _recommendations(intent),
      );
    }

    final scores = <String, _ScoredNote>{};
    final lexicalQuery = _lexicalQuery(query);
    final lexical = BuscaService(_index).buscar(lexicalQuery, limite: 80);
    for (final result in lexical) {
      _add(scores, result.nota, result.score * 3.0, 'Correspondencia com a consulta');
    }

    switch (intent) {
      case AgentSearchIntent.overview:
        for (final note in notes) {
          _add(scores, note, _centrality(note) * 2.0, 'No central da rede');
        }
      case AgentSearchIntent.causes:
        _expandCauses(scores, notes);
      case AgentSearchIntent.impacts:
        _expandImpacts(scores, notes);
      case AgentSearchIntent.path:
        _expandPath(scores, query);
      case AgentSearchIntent.risk:
        _addRiskSignals(scores, notes, query);
      case AgentSearchIntent.gaps:
        _addGaps(scores, notes);
      case AgentSearchIntent.decision:
        _addAuthorities(scores, notes);
      case AgentSearchIntent.discover:
        _expandDiscover(scores, notes);
      case AgentSearchIntent.protocol:
        _expandProtocol(scores, notes);
      case AgentSearchIntent.timeline:
        _expandTimeline(scores, notes);
    }

    if (scores.isEmpty) {
      for (final note in notes) {
        _add(scores, note, _centrality(note), 'Referencia relevante no Cerebro');
      }
    }

    final evidence = scores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final top = evidence.take(limit).map((item) => item.toEvidence()).toList();
    final confidence = _confidence(top, lexical.isNotEmpty, intent);
    final insights = _structuralInsights(top, notes);

    return AgentSearchAnalysis(
      intent: intent,
      evidence: top,
      summary: _summary(intent, top.length, lexical.isNotEmpty),
      confidence: confidence,
      recommendations: _recommendations(intent),
      structuralInsights: insights,
    );
  }

  static AgentSearchIntent detectIntent(String rawQuery) {
    final query = removerAcentos(rawQuery.toLowerCase());
    if (RegExp(r'\b(entre|caminho|conexao|conectar|ligacao|relacao)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.path;
    }
    if (RegExp(r'\b(causa|causas|por que|porque|raiz|origem|motivo|explica|explicar)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.causes;
    }
    if (RegExp(r'\b(impacto|impactos|efeito|efeitos|consequencia|afeta|resulta)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.impacts;
    }
    if (RegExp(r'\b(risco|riscos|critico|criticos|alerta|urgente|prioridade|perigo)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.risk;
    }
    if (RegExp(r'\b(lacuna|lacunas|orf|quebrad|desatualiz|falta de|pendente|incompleto)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.gaps;
    }
    if (RegExp(r'\b(como tratar|como fazer|passo a passo|fluxo de|rotina de|checklist|etapas)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.protocol;
    }
    if (RegExp(r'\b(protocolo|decisao|decisoes|procedimento|diretriz|norma|regra)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.decision;
    }
    if (RegExp(r'\b(historico|cronologia|evolucao|quando|linha do tempo|ultimo|ultima|recente|passado)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.timeline;
    }
    if (RegExp(r'\b(resumo|panorama|visao geral|hubs|importante|principais|estrateg|mapa|estrutura)\b')
        .hasMatch(query)) {
      return AgentSearchIntent.overview;
    }
    return AgentSearchIntent.discover;
  }

  void _expandDiscover(Map<String, _ScoredNote> scores, List<Nota> notes) {
    final seedIds = scores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final seed in seedIds.take(5)) {
      final note = seed.note;
      for (final edge in _index.forward[note.id] ?? const []) {
        final target = _index.porId(edge.para);
        if (target != null) {
          _add(scores, target, 1.8 + _centrality(target) * .35,
              'Relacionado a "${note.titulo}"');
          for (final hop2 in (_index.forward[target.id] ?? const []).take(2)) {
            final t2 = _index.porId(hop2.para);
            if (t2 != null && t2.id != note.id) {
              _add(scores, t2, 0.8 + _centrality(t2) * .2,
                  'Conexao indireta via "${target.titulo}"');
            }
          }
        }
      }
    }
    _addCoCitationBoost(scores, seedIds.take(5).map((s) => s.note).toList());
    if (scores.isEmpty) {
      for (final note in notes) {
        _add(scores, note, _centrality(note), 'No central da rede');
      }
    }
  }

  void _expandCauses(Map<String, _ScoredNote> scores, List<Nota> notes) {
    _expandDiscover(scores, notes);
    final seeds = scores.values.toList();
    for (final seed in seeds.take(8)) {
      for (final edge in _index.back[seed.note.id] ?? const []) {
        final cause = _index.porId(edge.de);
        if (cause != null) {
          _add(scores, cause, 3.4 + _centrality(cause) * .4,
              'Aponta para "${seed.note.titulo}"');
        }
      }
    }
  }

  void _expandImpacts(Map<String, _ScoredNote> scores, List<Nota> notes) {
    _expandDiscover(scores, notes);
    final seeds = scores.values.toList();
    for (final seed in seeds.take(8)) {
      for (final edge in _index.forward[seed.note.id] ?? const []) {
        final impact = _index.porId(edge.para);
        if (impact != null) {
          _add(scores, impact, 3.4 + _centrality(impact) * .4,
              'Impacto conectado a "${seed.note.titulo}"');
        }
      }
    }
  }

  void _expandPath(Map<String, _ScoredNote> scores, String query) {
    final pair = _extractPathPair(query);
    if (pair == null) return;
    final fromMatches = BuscaService(_index).buscar(pair.$1, limite: 1);
    final toMatches = BuscaService(_index).buscar(pair.$2, limite: 1);
    final from = fromMatches.isEmpty ? null : fromMatches.first.nota;
    final to = toMatches.isEmpty ? null : toMatches.first.nota;
    if (from == null || to == null) return;

    final path = _shortestPath(from.id, to.id);
    if (path == null) return;
    for (var i = 0; i < path.length; i++) {
      final note = _index.porId(path[i]);
      if (note != null) {
        _add(scores, note, 12 - i * .35, i == 0 || i == path.length - 1
            ? 'Extremidade da conexao solicitada'
            : 'Ponte no caminho entre as notas');
      }
    }
  }

  void _addRiskSignals(
      Map<String, _ScoredNote> scores, List<Nota> notes, String query) {
    _expandDiscover(scores, notes);
    final tokens = _tokens(query).toSet();
    const riskTokens = {'risco', 'alerta', 'critico', 'critica', 'urgente', 'falha', 'erro'};
    for (final note in notes) {
      final text = _searchable(note);
      final hasSignal = riskTokens.any(text.contains) ||
          tokens.any((token) => text.contains(token)) &&
              note.entityRefs.any((entity) =>
                  entity.tipo == EntidadeTipo.alerta ||
                  entity.tipo == EntidadeTipo.score);
      if (hasSignal) {
        _add(scores, note, 5.5 + _centrality(note) * .45,
            'Sinal de risco ou alerta operacional');
      }
    }
  }

  void _addGaps(Map<String, _ScoredNote> scores, List<Nota> notes) {
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    for (final note in notes) {
      final broken = (_index.forward[note.id] ?? const []).any((edge) => edge.ehNaoResolvido);
      if (note.metrics.orfa) {
        _add(scores, note, 7.5, 'Nota orfa: sem conexoes no grafo');
      }
      if (broken) {
        _add(scores, note, 8.5, 'Contem ligacao ainda nao resolvida');
      }
      if (note.updatedAt.isBefore(cutoff)) {
        _add(scores, note, 3.2, 'Conhecimento sem revisao ha mais de 180 dias');
      }
      if (note.ehRascunho) {
        _add(scores, note, 3.8, 'Rascunho que precisa de revisao');
      }
    }
  }

  void _addAuthorities(Map<String, _ScoredNote> scores, List<Nota> notes) {
    _expandDiscover(scores, notes);
    for (final note in notes) {
      if (note.tipo.ehAutoridade || note.tipo == NotaTipo.moc) {
        _add(scores, note, 5.0 + _centrality(note) * .55,
            note.tipo.ehAutoridade
                ? 'Fonte operacional de autoridade'
                : 'Mapa central de conhecimento');
      }
    }
  }

  void _expandProtocol(Map<String, _ScoredNote> scores, List<Nota> notes) {
    _expandDiscover(scores, notes);
    for (final note in notes) {
      if (note.tipo == NotaTipo.protocolo) {
        _add(scores, note, 7.0 + _centrality(note) * .5,
            'Protocolo operacional');
      }
      if (note.tipo == NotaTipo.decisao) {
        _add(scores, note, 4.5 + _centrality(note) * .4,
            'Decisao que orienta procedimento');
      }
      if (note.tags.any((t) =>
          t.contains('sop') || t.contains('checklist') || t.contains('fluxo'))) {
        _add(scores, note, 5.5, 'Nota marcada como procedimento operacional');
      }
    }
  }

  void _expandTimeline(Map<String, _ScoredNote> scores, List<Nota> notes) {
    _expandDiscover(scores, notes);
    final agora = DateTime.now();
    for (final nota in notes) {
      if (nota.tipo == NotaTipo.diario || nota.tipo == NotaTipo.reuniao) {
        final diasAtras = agora.difference(nota.updatedAt).inDays;
        final boost = math.max(0.5, 4.0 - diasAtras / 30.0);
        _add(scores, nota, boost, 'Registro cronologico (${nota.tipo.label})');
      }
    }
    final entries = scores.values.toList()
      ..sort((a, b) => b.note.updatedAt.compareTo(a.note.updatedAt));
    for (var i = 0; i < entries.length; i++) {
      entries[i].score += (entries.length - i) * 0.3;
    }
  }

  void _addCoCitationBoost(Map<String, _ScoredNote> scores, List<Nota> seeds) {
    final alvosCompartilhados = <String, int>{};
    for (final seed in seeds) {
      for (final edge in _index.forward[seed.id] ?? const []) {
        if (!edge.ehTag) {
          alvosCompartilhados[edge.para] =
              (alvosCompartilhados[edge.para] ?? 0) + 1;
        }
      }
    }
    for (final entry in alvosCompartilhados.entries) {
      if (entry.value >= 2) {
        final nota = _index.porId(entry.key);
        if (nota != null) {
          _add(scores, nota, 2.5 * entry.value,
              'Co-citada por ${entry.value} fontes relevantes');
        }
      }
    }
  }

  void _add(Map<String, _ScoredNote> scores, Nota note, double score,
      String reason) {
    final current = scores.putIfAbsent(note.id, () => _ScoredNote(note));
    current.score += score;
    if (!current.reasons.contains(reason) && current.reasons.length < 3) {
      current.reasons.add(reason);
    }
  }

  double _centrality(Nota note) =>
      math.log(1 + note.metrics.inDegree + note.metrics.outDegree) +
      note.metrics.pagerank * 20 +
      note.metrics.intermediacao * 4 +
      (note.fixada ? .5 : 0);

  (String, String)? _extractPathPair(String rawQuery) {
    final match = RegExp(r'entre\s+(.+?)\s+(?:e|com)\s+(.+?)(?:[?.!,]|$)',
            caseSensitive: false)
        .firstMatch(rawQuery);
    if (match == null) return null;
    final first = match.group(1)?.trim() ?? '';
    final second = match.group(2)?.trim() ?? '';
    return first.isEmpty || second.isEmpty ? null : (first, second);
  }

  List<String>? _shortestPath(String source, String target) {
    if (source == target) return [source];
    final queue = Queue<String>()..add(source);
    final previous = <String, String?>{source: null};
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final neighbors = <String>{
        for (final edge in _index.forward[current] ?? const []) edge.para,
        for (final edge in _index.back[current] ?? const []) edge.de,
      };
      for (final next in neighbors) {
        if (_index.porId(next) == null || previous.containsKey(next)) continue;
        previous[next] = current;
        if (next == target) {
          final path = <String>[];
          String? cursor = target;
          while (cursor != null) {
            path.add(cursor);
            cursor = previous[cursor];
          }
          return path.reversed.toList();
        }
        previous[next] = current;
        queue.add(next);
      }
    }
    return null;
  }

  String _lexicalQuery(String query) {
    const stopWords = {
      'o', 'a', 'os', 'as', 'de', 'da', 'do', 'das', 'dos', 'em', 'para',
      'por', 'que', 'com', 'e', 'um', 'uma', 'quais', 'qual', 'mostre',
      'encontre', 'me', 'sobre', 'entre', 'como', 'fazer', 'sao',
    };
    final terms = query
        .split(RegExp(r'\s+'))
        .where((word) =>
            word.length > 2 &&
            !stopWords.contains(removerAcentos(word.toLowerCase())))
        .toList();
    return terms.isEmpty ? query : terms.join(' ');
  }

  Iterable<String> _tokens(String raw) => _lexicalQuery(raw)
      .split(RegExp(r'\s+'))
      .map((term) => removerAcentos(term.toLowerCase()))
      .where((term) => term.length > 2);

  String _searchable(Nota note) => removerAcentos(
      '${note.titulo} ${note.tags.join(' ')} ${note.conteudo}'.toLowerCase());

  double _confidence(List<AgentSearchEvidence> evidence, bool lexicalFound,
      AgentSearchIntent intent) {
    if (evidence.isEmpty) return .12;
    var confidence = .42 + math.min(.28, evidence.first.score / 30);
    if (lexicalFound) confidence += .12;
    if (intent != AgentSearchIntent.discover) confidence += .08;
    return confidence.clamp(.12, .95);
  }

  String _summary(AgentSearchIntent intent, int count, bool lexicalFound) {
    final subject = switch (intent) {
      AgentSearchIntent.discover => 'as referencias mais proximas da consulta',
      AgentSearchIntent.overview =>
        'os hubs que organizam esta area do Cerebro',
      AgentSearchIntent.causes =>
        'possiveis causas e seus antecedentes conectados',
      AgentSearchIntent.impacts => 'os efeitos e dependencias a jusante',
      AgentSearchIntent.path =>
        'as pontes que conectam os conceitos pedidos',
      AgentSearchIntent.risk => 'os sinais que merecem priorizacao',
      AgentSearchIntent.gaps => 'lacunas, rascunhos e conexoes pendentes',
      AgentSearchIntent.decision =>
        'protocolos, decisoes e mapas de autoridade',
      AgentSearchIntent.protocol =>
        'procedimentos e rotinas operacionais aplicaveis',
      AgentSearchIntent.timeline =>
        'registros cronologicos e evolucao temporal',
    };
    if (count == 0) {
      return 'Ainda nao ha evidencias suficientes para $subject.';
    }
    final metodo = lexicalFound
        ? ', combinando texto, estrutura do grafo e co-citacao'
        : '';
    return 'Encontrei $count evidencias para $subject$metodo.';
  }

  List<String> _recommendations(AgentSearchIntent intent) => switch (intent) {
        AgentSearchIntent.causes => const [
            'Peca os impactos para seguir os efeitos.',
            'Use "entre A e B" para revelar a cadeia de conexao.',
          ],
        AgentSearchIntent.impacts => const [
            'Peca as causas para voltar a origem do problema.',
            'Abra uma nota destacada para validar a evidencia.',
          ],
        AgentSearchIntent.risk => const [
            'Peca "qual protocolo orienta este risco?".',
            'Investigue a conexao entre risco e absenteismo.',
          ],
        AgentSearchIntent.gaps => const [
            'Conecte notas orfas a um MOC ou protocolo.',
            'Revise as ligacoes pendentes antes de publicar.',
          ],
        AgentSearchIntent.protocol => const [
            'Consulte "quais riscos?" para ver alertas associados.',
            'Use "historico de X" para ver evolucao do protocolo.',
          ],
        AgentSearchIntent.timeline => const [
            'Peca "causas de X" para entender a origem.',
            'Use "impactos de X" para mapear consequencias.',
          ],
        _ => const [
            'Clique em uma evidencia para foca-la no grafo.',
            'Use uma pergunta de causa, impacto, risco ou conexao para aprofundar.',
          ],
      };

  List<String> _structuralInsights(
      List<AgentSearchEvidence> evidence, List<Nota> allNotes) {
    final insights = <String>[];
    if (evidence.isEmpty) return insights;

    for (final ev in evidence.take(3)) {
      final nota = _index.porId(ev.noteId);
      if (nota == null) continue;
      final grau = nota.metrics.inDegree + nota.metrics.outDegree;
      if (grau >= 8) {
        insights.add('"${nota.titulo}" eh um hub com $grau conexoes na rede');
      }
      if (nota.tipo == NotaTipo.moc) {
        insights.add(
            '"${nota.titulo}" eh um Mapa de Conteudo (MOC) que organiza esta area');
      }
    }

    final clusters = <int>{
      for (final ev in evidence)
        _index.porId(ev.noteId)?.metrics.cluster ?? 0
    };
    clusters.remove(0);
    if (clusters.length >= 2) {
      insights.add(
          'As evidencias cruzam ${clusters.length} clusters distintos do grafo');
    }

    final orfas = evidence.where((ev) {
      final n = _index.porId(ev.noteId);
      return n != null && n.metrics.orfa;
    }).length;
    if (orfas > 0) {
      insights.add(
          '$orfas evidencia${orfas == 1 ? ' esta' : 's estao'} '
          'desconectada${orfas == 1 ? '' : 's'} do grafo');
    }

    return insights;
  }
}

class _ScoredNote {
  _ScoredNote(this.note);

  final Nota note;
  double score = 0;
  final List<String> reasons = [];

  AgentSearchEvidence toEvidence() => AgentSearchEvidence(
        noteId: note.id,
        score: score,
        reasons: List.unmodifiable(reasons),
      );
}
