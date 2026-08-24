import 'package:cloud_firestore/cloud_firestore.dart';

import 'aresta.dart';
import 'nota_enums.dart';

/// Métricas de grafo de uma nota (§4.2 › `metrics`). Escritas pela rotina
/// noturna ou recalculadas em memória pelo `GrafoMetricas`.
class NotaMetrics {
  const NotaMetrics({
    this.inDegree = 0,
    this.outDegree = 0,
    this.pagerank = 0,
    this.cluster = 0,
    this.intermediacao = 0,
  });

  final int inDegree;
  final int outDegree;
  final double pagerank;
  final int cluster;
  final double intermediacao;

  bool get orfa => inDegree == 0 && outDegree == 0;

  Map<String, dynamic> toMap() => {
        'inDegree': inDegree,
        'outDegree': outDegree,
        'pagerank': pagerank,
        'cluster': cluster,
        'centralidadeIntermediacao': intermediacao,
        'orfa': orfa,
      };

  static NotaMetrics fromMap(Map<String, dynamic>? m) {
    if (m == null) return const NotaMetrics();
    return NotaMetrics(
      inDegree: (m['inDegree'] as num?)?.toInt() ?? 0,
      outDegree: (m['outDegree'] as num?)?.toInt() ?? 0,
      pagerank: (m['pagerank'] as num?)?.toDouble() ?? 0,
      cluster: (m['cluster'] as num?)?.toInt() ?? 0,
      intermediacao: (m['centralidadeIntermediacao'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Uma nota do Cérebro — unidade atômica de conhecimento (§4.2).
///
/// O corpo (`conteudo`) só é carregado sob demanda: o boot do vault trabalha
/// com [NotaMeta] (mesma classe, `conteudo` vazio e [corpoCarregado] falso).
class Nota {
  Nota({
    required this.id,
    required this.clinicaId,
    required this.path,
    required this.titulo,
    this.aliases = const [],
    this.tipo = NotaTipo.nota,
    this.tags = const [],
    this.cor,
    this.conteudo = '',
    this.corpoCarregado = true,
    this.frontmatter = const {},
    this.outLinks = const [],
    this.entityRefs = const [],
    this.headings = const [],
    this.blocos = const {},
    this.wordCount = 0,
    this.charCount = 0,
    this.metrics = const NotaMetrics(),
    this.origem = NotaOrigem.humano,
    this.agenteId,
    this.confianca,
    this.revisadoPor,
    this.estado = NotaEstado.publicada,
    this.sensivel = false,
    this.fixada = false,
    this.favorita = false,
    this.versao = 1,
    this.embeddingVersao = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.deletedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ── Identidade ────────────────────────────────────────────────────────────
  final String id;
  final String clinicaId;
  final String path;
  final String titulo;
  final List<String> aliases;

  // ── Classificação ─────────────────────────────────────────────────────────
  final NotaTipo tipo;
  final List<String> tags;
  final int? cor;

  // ── Conteúdo ──────────────────────────────────────────────────────────────
  final String conteudo;

  /// `false` quando a nota veio do espelho leve (sem corpo) — §4.9.
  final bool corpoCarregado;
  final Map<String, dynamic> frontmatter;

  // ── Índice derivado ───────────────────────────────────────────────────────
  final List<Aresta> outLinks;
  final List<EntidadeRef> entityRefs;
  final List<Heading> headings;
  final Map<String, int> blocos;
  final int wordCount;
  final int charCount;
  final NotaMetrics metrics;

  // ── Proveniência ──────────────────────────────────────────────────────────
  final NotaOrigem origem;
  final String? agenteId;
  final double? confianca;
  final String? revisadoPor;
  final NotaEstado estado;
  final bool sensivel;
  final bool fixada;
  final bool favorita;

  // ── Versionamento ─────────────────────────────────────────────────────────
  final int versao;
  final int embeddingVersao;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime? deletedAt;

  // ── Derivados ─────────────────────────────────────────────────────────────

  /// Pasta da nota (`mocs/absenteismo.md` → `mocs`). Vazio na raiz.
  String get pasta {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '' : path.substring(0, i);
  }

  /// Nome do arquivo sem extensão.
  String get nomeArquivo {
    final base = path.substring(path.lastIndexOf('/') + 1);
    return base.toLowerCase().endsWith('.md')
        ? base.substring(0, base.length - 3)
        : base;
  }

  bool get ehDeAgente => origem == NotaOrigem.agente;
  bool get ehRascunho => estado == NotaEstado.rascunho;
  bool get arquivada => estado == NotaEstado.arquivada;
  bool get excluida => deletedAt != null;
  bool get revisada => revisadoPor != null && revisadoPor!.isNotEmpty;

  /// Tempo estimado de leitura (250 palavras por minuto), em segundos.
  int get tempoLeituraSeg => (wordCount / 250 * 60).round();

  /// Todas as chaves pelas quais esta nota pode ser referenciada em `[[ ]]`.
  List<String> get chavesDeResolucao => [
        path,
        path.toLowerCase().endsWith('.md')
            ? path.substring(0, path.length - 3)
            : path,
        nomeArquivo,
        titulo,
        ...aliases,
      ];

  Nota copyWith({
    String? path,
    String? titulo,
    List<String>? aliases,
    NotaTipo? tipo,
    List<String>? tags,
    int? cor,
    String? conteudo,
    bool? corpoCarregado,
    Map<String, dynamic>? frontmatter,
    List<Aresta>? outLinks,
    List<EntidadeRef>? entityRefs,
    List<Heading>? headings,
    Map<String, int>? blocos,
    int? wordCount,
    int? charCount,
    NotaMetrics? metrics,
    NotaOrigem? origem,
    String? agenteId,
    double? confianca,
    String? revisadoPor,
    NotaEstado? estado,
    bool? sensivel,
    bool? fixada,
    bool? favorita,
    int? versao,
    int? embeddingVersao,
    DateTime? updatedAt,
    String? updatedBy,
    DateTime? deletedAt,
  }) {
    return Nota(
      id: id,
      clinicaId: clinicaId,
      path: path ?? this.path,
      titulo: titulo ?? this.titulo,
      aliases: aliases ?? this.aliases,
      tipo: tipo ?? this.tipo,
      tags: tags ?? this.tags,
      cor: cor ?? this.cor,
      conteudo: conteudo ?? this.conteudo,
      corpoCarregado: corpoCarregado ?? this.corpoCarregado,
      frontmatter: frontmatter ?? this.frontmatter,
      outLinks: outLinks ?? this.outLinks,
      entityRefs: entityRefs ?? this.entityRefs,
      headings: headings ?? this.headings,
      blocos: blocos ?? this.blocos,
      wordCount: wordCount ?? this.wordCount,
      charCount: charCount ?? this.charCount,
      metrics: metrics ?? this.metrics,
      origem: origem ?? this.origem,
      agenteId: agenteId ?? this.agenteId,
      confianca: confianca ?? this.confianca,
      revisadoPor: revisadoPor ?? this.revisadoPor,
      estado: estado ?? this.estado,
      sensivel: sensivel ?? this.sensivel,
      fixada: fixada ?? this.fixada,
      favorita: favorita ?? this.favorita,
      versao: versao ?? this.versao,
      embeddingVersao: embeddingVersao ?? this.embeddingVersao,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  // ── Serialização ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'clinicaId': clinicaId,
        'path': path,
        'titulo': titulo,
        'aliases': aliases,
        'tipo': tipo.id,
        'tags': tags,
        if (cor != null) 'cor': cor,
        'conteudo': conteudo,
        'frontmatter': frontmatter,
        'outLinks': [for (final a in outLinks) a.para],
        'entityRefs': [for (final e in entityRefs) e.toMap()],
        'headings': [for (final h in headings) h.toMap()],
        'blocos': blocos,
        'wordCount': wordCount,
        'charCount': charCount,
        'tempoLeituraSeg': tempoLeituraSeg,
        'metrics': metrics.toMap(),
        'origem': origem.id,
        if (agenteId != null) 'agenteId': agenteId,
        if (confianca != null) 'confianca': confianca,
        if (revisadoPor != null) 'revisadoPor': revisadoPor,
        'estado': estado.id,
        'sensivel': sensivel,
        'fixada': fixada,
        'favorita': favorita,
        'versao': versao,
        'embeddingVersao': embeddingVersao,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'updatedBy': updatedBy,
        'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      };

  static Nota fromMap(String id, Map<String, dynamic> m) {
    final conteudo = (m['conteudo'] ?? '').toString();
    return Nota(
      id: id,
      clinicaId: (m['clinicaId'] ?? '').toString(),
      path: (m['path'] ?? '$id.md').toString(),
      titulo: (m['titulo'] ?? '').toString(),
      aliases: _strList(m['aliases']),
      tipo: NotaTipo.fromId(m['tipo'] as String?),
      tags: _strList(m['tags']),
      cor: (m['cor'] as num?)?.toInt(),
      conteudo: conteudo,
      corpoCarregado: m.containsKey('conteudo'),
      frontmatter: (m['frontmatter'] as Map?)?.cast<String, dynamic>() ?? const {},
      entityRefs: [
        for (final e in (m['entityRefs'] as List? ?? const []))
          if (e is Map)
            ...[EntidadeRef.fromMap(e.cast<String, dynamic>())].whereType<EntidadeRef>(),
      ],
      headings: [
        for (final h in (m['headings'] as List? ?? const []))
          if (h is Map) Heading.fromMap(h.cast<String, dynamic>()),
      ],
      blocos: ((m['blocos'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      wordCount: (m['wordCount'] as num?)?.toInt() ?? 0,
      charCount: (m['charCount'] as num?)?.toInt() ?? 0,
      metrics: NotaMetrics.fromMap((m['metrics'] as Map?)?.cast<String, dynamic>()),
      origem: NotaOrigem.fromId(m['origem'] as String?),
      agenteId: m['agenteId'] as String?,
      confianca: (m['confianca'] as num?)?.toDouble(),
      revisadoPor: m['revisadoPor'] as String?,
      estado: NotaEstado.fromId(m['estado'] as String?),
      sensivel: m['sensivel'] == true,
      fixada: m['fixada'] == true,
      favorita: m['favorita'] == true,
      versao: (m['versao'] as num?)?.toInt() ?? 1,
      embeddingVersao: (m['embeddingVersao'] as num?)?.toInt() ?? 0,
      createdAt: _data(m['createdAt']),
      updatedAt: _data(m['updatedAt']),
      createdBy: (m['createdBy'] ?? '').toString(),
      updatedBy: (m['updatedBy'] ?? '').toString(),
      deletedAt: m['deletedAt'] == null ? null : _data(m['deletedAt']),
    );
  }

  static List<String> _strList(Object? v) {
    if (v is List) return [for (final e in v) e.toString()];
    if (v is String && v.isNotEmpty) {
      return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static DateTime _data(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  String toString() => 'Nota($path, v$versao, ${tipo.id})';
}
