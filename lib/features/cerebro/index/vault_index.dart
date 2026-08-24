import '../data/models/aresta.dart';
import '../data/models/nota.dart';
import '../data/models/nota_enums.dart';
import 'parser/parser_vfm.dart';
import 'texto_busca.dart';

/// Resultado da resolução de um `[[alvo]]` (`obsidian.md` §5.2).
class ResolucaoLink {
  const ResolucaoLink({
    required this.estado,
    required this.alvoBruto,
    this.notaId,
    this.entidade,
    this.candidatos = const [],
  });

  final LinkEstado estado;
  final String alvoBruto;
  final String? notaId;
  final EntidadeRef? entidade;

  /// Preenchido quando [estado] é [LinkEstado.ambiguo].
  final List<String> candidatos;

  /// Chave do nó no grafo.
  String get chaveNo {
    switch (estado) {
      case LinkEstado.resolvido:
        return notaId!;
      case LinkEstado.entidade:
        return entidade!.chave;
      case LinkEstado.ambiguo:
        return candidatos.first;
      case LinkEstado.quebrado:
        return '?${chaveNormalizada(alvoBruto)}';
    }
  }
}

/// Os 6 índices globais do vault (`obsidian.md` §6.2), mantidos em memória e
/// atualizados de forma **incremental** — nunca reconstruídos por completo
/// durante a edição.
class VaultIndex {
  VaultIndex();

  /// Metadados de todas as notas vivas, por id.
  final Map<String, Nota> notas = {};

  /// 1. Arestas de saída, por id de nota (já resolvidas).
  final Map<String, List<Aresta>> forward = {};

  /// 2. Arestas de entrada, por chave de nó alvo (`nt_…`, `@tipo:id`, `tag:x`,
  ///    `?titulo`).
  final Map<String, List<Aresta>> back = {};

  /// 3. Chave normalizada → ids de nota que respondem por ela. Mais de um id
  ///    significa ambiguidade (§5.2 › etapa 8).
  final Map<String, List<String>> alias = {};

  /// 4. Tag (e cada prefixo hierárquico) → ids de nota.
  final Map<String, Set<String>> tags = {};

  /// Ids de nota que possuem ao menos um link quebrado apontando para a chave.
  final Map<String, Set<String>> _quebradosPorChave = {};

  /// Notas por pasta — alimenta o Explorer sem varrer tudo a cada build.
  final Map<String, Set<String>> pastas = {};

  // ── Índices reversos (nota → chaves que ela registrou) ────────────────────
  //
  // Existem só para tornar a *remoção* barata. Sem eles, desindexar uma nota
  // exigia varrer `alias`, `tags` e `pastas` inteiros procurando o id — o que
  // torna a indexação do vault O(N²): reindexar 3.000 notas levava 75 s,
  // porque cada uma percorria os ~6.000 aliases já registrados.
  final Map<String, List<String>> _aliasDaNota = {};
  final Map<String, List<String>> _tagsDaNota = {};
  final Map<String, String> _pastaDaNota = {};

  /// Path exato → id. Resolver `[[pasta/nota]]` varria `notas.values` inteiro,
  /// o que custava O(notas) **por link**: num vault de 3.000 notas com 21.000
  /// arestas isso dava ~68 milhões de comparações de string só no boot.
  final Map<String, String> _idPorPath = {};

  /// Texto de cada nota já normalizado para busca.
  ///
  /// A busca normalizava o corpo inteiro de **todas** as notas a cada consulta
  /// — a cada tecla digitada, portanto. Num vault de 3.000 notas isso são
  /// vários MB de `toLowerCase()` + `removerAcentos()` por keystroke. O texto
  /// só muda quando a nota é reindexada, então o lugar dele é aqui.
  final Map<String, TextoBusca> _textoBusca = {};

  /// Forma normalizada da nota (ver [_textoBusca]). Nunca nula para nota viva.
  TextoBusca textoBusca(String notaId) =>
      _textoBusca[notaId] ?? const TextoBusca.vazio();

  // -- Derivados memoizados --------------------------------------------------
  //
  // `orfas`, `linksQuebrados` e `totalArestas` varrem o vault inteiro. A status
  // bar, o rail e o painel de sugestoes pediam os tres a cada build - varreduras
  // O(N) disparadas por um hover. Sao caros de calcular e baratos de guardar:
  // mudam so quando o indice muda.
  int _versao = 0;
  int _versaoDerivados = -1;
  List<Nota>? _orfasCache;
  Map<String, List<Aresta>>? _quebradosCache;
  int _arestasCache = 0;

  void _invalidar() => _versao++;

  void _recalcularSePreciso() {
    if (_versaoDerivados == _versao) return;
    _versaoDerivados = _versao;

    var arestas = 0;
    for (final l in forward.values) {
      arestas += l.length;
    }
    _arestasCache = arestas;

    final orfas = <Nota>[];
    for (final n in notas.values) {
      final saida = forward[n.id]?.where((a) => !a.ehTag).length ?? 0;
      final entrada = back[n.id]?.length ?? 0;
      if (saida == 0 && entrada == 0) orfas.add(n);
    }
    _orfasCache = orfas;

    final quebrados = <String, List<Aresta>>{};
    back.forEach((chave, arestas) {
      if (chave.startsWith('?')) quebrados[chave.substring(1)] = arestas;
    });
    _quebradosCache = quebrados;
  }

  int get totalNotas => notas.length;

  int get totalArestas {
    _recalcularSePreciso();
    return _arestasCache;
  }

  // ── Escrita ───────────────────────────────────────────────────────────────

  /// Indexa (ou reindexa) uma nota a partir do seu AST. Devolve a nota
  /// enriquecida com os campos derivados e as arestas já resolvidas.
  ///
  /// Caminho de **edição** (uma nota por vez). Para carregar o vault inteiro
  /// use [indexarLote], que resolve os links em uma passada só.
  Nota indexar(Nota base, NotaAst ast) {
    // Remove o que existia antes (mantendo a nota no mapa até o fim).
    _limparDerivados(base.id);
    final nota = _registrar(base, ast);
    final comArestas = _resolverArestasDe(nota, ast);
    // Uma nota nova pode "consertar" links quebrados de outras notas.
    _reconciliarQuebrados(comArestas);
    return comArestas;
  }

  /// Indexa o vault inteiro em **uma** passada de resolução.
  ///
  /// O boot fazia duas passadas completas — a primeira registrava as chaves, a
  /// segunda reparseava tudo para religar os links que na primeira ainda não
  /// tinham alvo. Separar "registrar" de "resolver" dá o mesmo resultado sem
  /// reparse e sem reindexação: quando as arestas começam a ser resolvidas,
  /// todas as notas já respondem por suas chaves.
  ///
  /// [bases] e [asts] devem ter o mesmo comprimento e a mesma ordem.
  ///
  /// Produz exatamente as mesmas arestas e os mesmos links quebrados que o
  /// caminho antigo. A única diferença observável é o **desempate de links
  /// ambíguos** (§5.2 › etapa 8): quando duas notas respondem pela mesma
  /// chave, vence a primeira registrada. Antes vencia quem a reindexação da
  /// segunda passada tivesse reinserido por último — arbitrário e instável
  /// entre execuções.
  void indexarLote(List<Nota> bases, List<NotaAst> asts) {
    assert(bases.length == asts.length);
    final registradas = registrarFaixa(bases, asts, 0, bases.length);
    resolverFaixa(registradas, asts, 0, registradas.length);
    atualizarGraus();
  }

  /// Fase 1 de [indexarLote] sobre a faixa `[de, ate)` — registra as chaves das
  /// notas sem resolver nenhum link. Devolve as notas já enriquecidas.
  ///
  /// Exposta em faixas para que o boot possa ceder a thread entre os lotes: um
  /// vault grande custa mais de um frame para indexar, e travar a UI inteira
  /// nesse intervalo é o que faz a tela "pesar" mesmo quando o total é rápido.
  List<Nota> registrarFaixa(
      List<Nota> bases, List<NotaAst> asts, int de, int ate) {
    final out = <Nota>[];
    for (var i = de; i < ate; i++) {
      _limparDerivados(bases[i].id);
      out.add(_registrar(bases[i], asts[i]));
    }
    return out;
  }

  /// Fase 2 de [indexarLote] sobre a faixa `[de, ate)` — resolve as arestas.
  /// Só é correta depois de [registrarFaixa] ter coberto **todas** as notas.
  void resolverFaixa(
      List<Nota> registradas, List<NotaAst> asts, int de, int ate) {
    for (var i = de; i < ate; i++) {
      _resolverArestasDe(registradas[i], asts[i]);
    }
  }

  /// Enriquece a nota com o que veio do AST e registra suas chaves, tags e
  /// pasta — sem tocar em arestas.
  Nota _registrar(Nota base, NotaAst ast) {
    final titulo = ast.titulo.isNotEmpty ? ast.titulo : base.nomeArquivo;
    final tipo = ast.tipo ?? _inferirTipo(base.path, ast) ?? base.tipo;

    final nota = base.copyWith(
      titulo: titulo,
      aliases: ast.aliases,
      tipo: tipo,
      tags: ast.tags,
      frontmatter: ast.frontmatter,
      headings: ast.headings,
      blocos: ast.blocos,
      wordCount: ast.wordCount,
      charCount: ast.charCount,
    );

    notas[nota.id] = nota;
    _idPorPath[nota.path] = nota.id;
    _textoBusca[nota.id] = TextoBusca.de(nota);
    _registrarChaves(nota);
    _registrarTags(nota);
    _registrarPasta(nota);
    return nota;
  }

  /// Resolve as arestas de saída da nota e devolve a versão final dela.
  Nota _resolverArestasDe(Nota nota, NotaAst ast) {
    final resolvidas = <Aresta>[];
    for (final bruta in ast.arestas) {
      final aresta = _resolverAresta(nota.id, bruta);
      if (aresta == null) continue; // self-link (caso-limite 16)
      resolvidas.add(aresta);
    }
    forward[nota.id] = resolvidas;
    for (final a in resolvidas) {
      back.putIfAbsent(a.para, () => []).add(a);
      if (a.ehNaoResolvido) {
        _quebradosPorChave.putIfAbsent(a.para, () => {}).add(nota.id);
      }
    }

    final finalizada =
        nota.copyWith(outLinks: resolvidas, metrics: _metricasDe(nota.id));
    notas[nota.id] = finalizada;
    _invalidar();
    return finalizada;
  }

  /// Remove uma nota do índice (arquivamento ou exclusão).
  void remover(String notaId) {
    final nota = notas.remove(notaId);
    if (nota == null) return;
    _limparDerivados(notaId);
    // Links que apontavam para ela voltam a ser quebrados.
    final entrantes = back.remove(notaId) ?? const <Aresta>[];
    for (final a in entrantes) {
      final lista = forward[a.de];
      if (lista == null) continue;
      final i = lista.indexOf(a);
      if (i < 0) continue;
      final chaveQuebrada = '?${chaveNormalizada(a.alias.isNotEmpty ? a.alias : nota.titulo)}';
      final nova = Aresta(
        de: a.de,
        para: chaveQuebrada,
        tipo: a.tipo,
        alias: a.alias,
        ancora: a.ancora,
        bloco: a.bloco,
        linha: a.linha,
        contexto: a.contexto,
        peso: a.peso,
      );
      lista[i] = nova;
      back.putIfAbsent(chaveQuebrada, () => []).add(nova);
      _quebradosPorChave.putIfAbsent(chaveQuebrada, () => {}).add(a.de);
    }
    _invalidar();
  }

  void limpar() {
    notas.clear();
    forward.clear();
    back.clear();
    alias.clear();
    tags.clear();
    pastas.clear();
    _quebradosPorChave.clear();
    _aliasDaNota.clear();
    _tagsDaNota.clear();
    _pastaDaNota.clear();
    _idPorPath.clear();
    _textoBusca.clear();
    _invalidar();
  }

  // ── Leitura ───────────────────────────────────────────────────────────────

  Nota? porId(String id) => notas[id];

  Nota? porPath(String path) {
    final id = _idPorPath[path];
    if (id != null) return notas[id];
    for (final n in notas.values) {
      if (n.path == path) return n;
    }
    return null;
  }

  /// Resolve um alvo de wikilink seguindo as 9 etapas de §5.2.
  ResolucaoLink resolver(String alvoBruto) {
    final alvo = alvoBruto.trim();
    if (alvo.isEmpty) {
      return ResolucaoLink(estado: LinkEstado.quebrado, alvoBruto: alvoBruto);
    }

    // Entity-link.
    if (alvo.startsWith('@')) {
      final ref = EntidadeRef.parse(alvo);
      if (ref != null) {
        return ResolucaoLink(
          estado: LinkEstado.entidade,
          alvoBruto: alvoBruto,
          entidade: ref,
        );
      }
    }

    // Path exato (case-sensitive) — etapas 1 e 2, agora por lookup direto.
    final porPathExato = _idPorPath[alvo] ?? _idPorPath['$alvo.md'];
    if (porPathExato != null) {
      return ResolucaoLink(
        estado: LinkEstado.resolvido,
        alvoBruto: alvoBruto,
        notaId: porPathExato,
      );
    }

    // Etapas 3 a 7 — tudo pelo índice de chaves normalizadas.
    final candidatos = alias[chaveNormalizada(alvo)];
    if (candidatos == null || candidatos.isEmpty) {
      return ResolucaoLink(estado: LinkEstado.quebrado, alvoBruto: alvoBruto);
    }
    if (candidatos.length == 1) {
      return ResolucaoLink(
        estado: LinkEstado.resolvido,
        alvoBruto: alvoBruto,
        notaId: candidatos.first,
      );
    }
    return ResolucaoLink(
      estado: LinkEstado.ambiguo,
      alvoBruto: alvoBruto,
      candidatos: List.unmodifiable(candidatos),
      notaId: candidatos.first,
    );
  }

  /// Menções vinculadas (backlinks) de um nó.
  List<Aresta> backlinks(String chaveNo) =>
      List.unmodifiable(back[chaveNo] ?? const <Aresta>[]);

  List<Aresta> linksDe(String notaId) =>
      List.unmodifiable(forward[notaId] ?? const <Aresta>[]);

  /// Notas sem nenhuma conexão (grau 0) — §7.6.
  List<Nota> get orfas {
    _recalcularSePreciso();
    return _orfasCache!;
  }

  /// Links que apontam para notas inexistentes, agrupados por alvo.
  Map<String, List<Aresta>> get linksQuebrados {
    _recalcularSePreciso();
    return _quebradosCache!;
  }

  /// Contagem por tag, já incluindo os prefixos hierárquicos.
  Map<String, int> get contagemTags =>
      {for (final e in tags.entries) e.key: e.value.length};

  /// Todas as pastas conhecidas, ordenadas.
  List<String> get todasPastas {
    final out = pastas.keys.where((p) => p.isNotEmpty).toList()..sort();
    return out;
  }

  NotaMetrics _metricasDe(String id) {
    final saida = forward[id]?.where((a) => !a.ehTag).length ?? 0;
    final entrada = back[id]?.length ?? 0;
    final atual = notas[id]?.metrics ?? const NotaMetrics();
    return NotaMetrics(
      inDegree: entrada,
      outDegree: saida,
      pagerank: atual.pagerank,
      cluster: atual.cluster,
      intermediacao: atual.intermediacao,
    );
  }

  /// Recalcula in/outDegree de todas as notas. Chamado após uma carga em lote.
  void atualizarGraus() {
    for (final id in notas.keys.toList()) {
      notas[id] = notas[id]!.copyWith(metrics: _metricasDe(id));
    }
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  Aresta? _resolverAresta(String deId, Aresta bruta) {
    if (bruta.tipo == LinkTipo.tag || bruta.tipo == LinkTipo.entidade) {
      return Aresta(
        de: deId,
        para: bruta.para,
        tipo: bruta.tipo,
        alias: bruta.alias,
        linha: bruta.linha,
        contexto: bruta.contexto,
        peso: bruta.peso,
      );
    }

    final r = resolver(bruta.para);
    final chave = r.chaveNo;
    if (chave == deId) return null; // self-link não entra no grafo

    return Aresta(
      de: deId,
      para: chave,
      tipo: bruta.tipo,
      alias: bruta.alias,
      ancora: bruta.ancora,
      bloco: bruta.bloco,
      linha: bruta.linha,
      contexto: bruta.contexto,
      peso: bruta.peso,
    );
  }

  void _limparDerivados(String notaId) {
    _invalidar();
    final antigas = forward.remove(notaId) ?? const <Aresta>[];
    for (final a in antigas) {
      final lista = back[a.para];
      if (lista == null) continue;
      lista.removeWhere((x) => x.de == notaId && x.chave == a.chave);
      if (lista.isEmpty) back.remove(a.para);
      if (a.ehNaoResolvido) {
        _quebradosPorChave[a.para]?.remove(notaId);
        if (_quebradosPorChave[a.para]?.isEmpty ?? false) {
          _quebradosPorChave.remove(a.para);
        }
      }
    }
    // Toca apenas as chaves que ESTA nota registrou (ver índices reversos).
    for (final k in _aliasDaNota.remove(notaId) ?? const <String>[]) {
      final lista = alias[k];
      if (lista == null) continue;
      lista.remove(notaId);
      if (lista.isEmpty) alias.remove(k);
    }
    for (final t in _tagsDaNota.remove(notaId) ?? const <String>[]) {
      final ids = tags[t];
      if (ids == null) continue;
      ids.remove(notaId);
      if (ids.isEmpty) tags.remove(t);
    }
    _textoBusca.remove(notaId);
    final pathAntigo = notas[notaId]?.path;
    if (pathAntigo != null && _idPorPath[pathAntigo] == notaId) {
      _idPorPath.remove(pathAntigo);
    }
    final pastaAntiga = _pastaDaNota.remove(notaId);
    if (pastaAntiga != null) {
      final ids = pastas[pastaAntiga];
      if (ids != null) {
        ids.remove(notaId);
        // A pasta em si continua no mapa mesmo vazia: ela ainda pode ser
        // ancestral de outra pasta viva, e a árvore do Explorer a espera.
      }
    }
  }

  void _registrarChaves(Nota nota) {
    final minhas = <String>[];
    for (final chave in nota.chavesDeResolucao) {
      if (chave.trim().isEmpty) continue;
      final k = chaveNormalizada(chave);
      final lista = alias.putIfAbsent(k, () => []);
      if (!lista.contains(nota.id)) lista.add(nota.id);
      minhas.add(k);
    }
    if (minhas.isNotEmpty) _aliasDaNota[nota.id] = minhas;
  }

  void _registrarTags(Nota nota) {
    for (final t in nota.tags) {
      tags.putIfAbsent(t, () => {}).add(nota.id);
    }
    if (nota.tags.isNotEmpty) _tagsDaNota[nota.id] = nota.tags.toList();
  }

  void _registrarPasta(Nota nota) {
    pastas.putIfAbsent(nota.pasta, () => {}).add(nota.id);
    _pastaDaNota[nota.id] = nota.pasta;
    // Registra também as pastas ancestrais para a árvore do Explorer.
    var p = nota.pasta;
    while (p.contains('/')) {
      p = p.substring(0, p.lastIndexOf('/'));
      pastas.putIfAbsent(p, () => {});
    }
  }

  /// Ao criar/renomear uma nota, links quebrados que agora casam com ela são
  /// religados sem exigir reindexação do vault inteiro.
  void _reconciliarQuebrados(Nota nova) {
    if (_quebradosPorChave.isEmpty) return;
    final chaves = {
      for (final c in nova.chavesDeResolucao)
        if (c.trim().isNotEmpty) '?${chaveNormalizada(c)}',
    };
    for (final chaveQuebrada in chaves) {
      final origens = _quebradosPorChave.remove(chaveQuebrada);
      if (origens == null) continue;
      final pendentes = back.remove(chaveQuebrada) ?? const <Aresta>[];
      for (final a in pendentes) {
        final lista = forward[a.de];
        if (lista == null) continue;
        final i = lista.indexWhere((x) => x.chave == a.chave);
        if (i < 0) continue;
        final nova2 = Aresta(
          de: a.de,
          para: nova.id,
          tipo: a.tipo,
          alias: a.alias,
          ancora: a.ancora,
          bloco: a.bloco,
          linha: a.linha,
          contexto: a.contexto,
          peso: a.peso,
        );
        lista[i] = nova2;
        back.putIfAbsent(nova.id, () => []).add(nova2);
      }
      for (final origem in origens) {
        final n = notas[origem];
        if (n != null) {
          notas[origem] = n.copyWith(outLinks: forward[origem] ?? const []);
        }
      }
    }
  }

  /// Heurística de tipo quando o frontmatter não declara: pasta e formato.
  static NotaTipo? _inferirTipo(String path, NotaAst ast) {
    final p = path.toLowerCase();
    if (p.startsWith('diario/')) return NotaTipo.diario;
    if (p.startsWith('mocs/')) return NotaTipo.moc;
    if (p.startsWith('protocolos/')) return NotaTipo.protocolo;
    if (p.startsWith('padroes/') || p.startsWith('agente/')) return NotaTipo.analise;
    if (p.startsWith('templates/')) return NotaTipo.template;
    if (p.startsWith('decisoes/')) return NotaTipo.decisao;
    if (p.startsWith('reunioes/')) return NotaTipo.reuniao;
    if (ast.tags.contains('moc')) return NotaTipo.moc;
    return null;
  }
}
