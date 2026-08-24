import '../../data/models/aresta.dart';
import '../../data/models/nota_enums.dart';
import 'frontmatter.dart';
import 'mascara_codigo.dart';
import 'tokenizer.dart';

/// Árvore/resumo estruturado de uma nota após o parse (`obsidian.md` §6.1).
class NotaAst {
  const NotaAst({
    required this.frontmatter,
    required this.corpo,
    required this.linhasFrontmatter,
    required this.titulo,
    required this.aliases,
    required this.tipo,
    required this.tags,
    required this.arestas,
    required this.entidades,
    required this.headings,
    required this.blocos,
    required this.textoPlano,
    required this.wordCount,
    required this.charCount,
    required this.tarefasTotal,
    required this.tarefasFeitas,
  });

  final Map<String, dynamic> frontmatter;
  final String corpo;
  final int linhasFrontmatter;

  /// H1 do corpo, ou `titulo` do frontmatter, ou vazio (o chamador cai para
  /// o nome do arquivo).
  final String titulo;
  final List<String> aliases;
  final NotaTipo? tipo;

  /// Tags do corpo (`#tag`) unidas às do frontmatter, **expandidas** com todos
  /// os prefixos hierárquicos: `operacao/absenteismo` gera também `operacao`.
  final List<String> tags;

  /// Arestas com `para` ainda **não resolvido** para wikilinks.
  final List<Aresta> arestas;
  final List<EntidadeRef> entidades;
  final List<Heading> headings;
  final Map<String, int> blocos;
  final String textoPlano;
  final int wordCount;
  final int charCount;
  final int tarefasTotal;
  final int tarefasFeitas;

  static const vazio = NotaAst(
    frontmatter: {},
    corpo: '',
    linhasFrontmatter: 0,
    titulo: '',
    aliases: [],
    tipo: null,
    tags: [],
    arestas: [],
    entidades: [],
    headings: [],
    blocos: {},
    textoPlano: '',
    wordCount: 0,
    charCount: 0,
    tarefasTotal: 0,
    tarefasFeitas: 0,
  );
}

/// Orquestra o pipeline de parsing do VFM: frontmatter → máscara de código →
/// tokenizer → agregação.
///
/// Custo alvo: uma nota de 50 KB em ≤ 8 ms no desktop (§6.1).
class ParserVFM {
  const ParserVFM();

  NotaAst parse(String texto) {
    if (texto.isEmpty) return NotaAst.vazio;

    final fm = Frontmatter.separar(texto);
    final corpo = fm.corpo;
    final mascara = MascaraCodigo.analisar(corpo);
    final achados = Tokenizer(corpo, mascara: mascara).varrer();

    // ── Título: H1 > frontmatter.titulo > vazio ──────────────────────────────
    var titulo = '';
    for (final h in achados.headings) {
      if (h.nivel == 1) {
        titulo = h.texto;
        break;
      }
    }
    if (titulo.isEmpty) {
      final t = fm.dados['titulo'] ?? fm.dados['title'];
      if (t != null) titulo = t.toString();
    }

    // ── Tags: corpo + frontmatter, expandidas por hierarquia ────────────────
    final tags = <String>{};
    void addTag(String t) {
      var limpa = t.trim();
      if (limpa.startsWith('#')) limpa = limpa.substring(1);
      limpa = limpa.toLowerCase();
      if (limpa.isEmpty) return;
      final partes = limpa.split('/');
      final acc = StringBuffer();
      for (var i = 0; i < partes.length; i++) {
        if (i > 0) acc.write('/');
        acc.write(partes[i]);
        tags.add(acc.toString());
      }
    }

    for (final t in achados.tags) {
      addTag(t);
    }
    final fmTags = fm.dados['tags'] ?? fm.dados['tag'];
    if (fmTags is List) {
      for (final t in fmTags) {
        addTag(t.toString());
      }
    } else if (fmTags is String) {
      for (final t in fmTags.split(RegExp(r'[,\s]+'))) {
        addTag(t);
      }
    }

    // ── Aliases do frontmatter ──────────────────────────────────────────────
    final aliases = <String>[];
    final fmAliases = fm.dados['aliases'] ?? fm.dados['alias'];
    if (fmAliases is List) {
      for (final a in fmAliases) {
        final s = a.toString().trim();
        if (s.isNotEmpty) aliases.add(s);
      }
    } else if (fmAliases is String && fmAliases.trim().isNotEmpty) {
      for (final a in fmAliases.split(',')) {
        final s = a.trim();
        if (s.isNotEmpty) aliases.add(s);
      }
    }

    // ── Arestas de tag: dedup e peso somado ─────────────────────────────────
    final arestas = _fundirPorChave(achados.arestas);

    final tipoFm = fm.dados['tipo'] ?? fm.dados['type'];

    return NotaAst(
      frontmatter: fm.dados,
      corpo: corpo,
      linhasFrontmatter: fm.linhasConsumidas,
      titulo: titulo,
      aliases: aliases,
      tipo: tipoFm == null ? null : NotaTipo.fromId(tipoFm.toString()),
      tags: tags.toList()..sort(),
      arestas: arestas,
      entidades: achados.entidades.toSet().toList(),
      headings: achados.headings,
      blocos: achados.blocos,
      textoPlano: achados.textoPlano,
      wordCount: _contarPalavras(achados.textoPlano),
      charCount: corpo.length,
      tarefasTotal: achados.tarefasTotal,
      tarefasFeitas: achados.tarefasFeitas,
    );
  }

  /// Duas ocorrências do mesmo link viram **uma** aresta com peso 2
  /// (caso-limite 1 de §6.3). Preserva a primeira linha/contexto.
  static List<Aresta> _fundirPorChave(List<Aresta> brutas) {
    final porChave = <String, Aresta>{};
    for (final a in brutas) {
      final existente = porChave[a.chave];
      if (existente == null) {
        porChave[a.chave] = a.comPeso(a.tipo.pesoBase);
      } else {
        porChave[a.chave] = existente.comPeso(existente.peso + a.tipo.pesoBase);
      }
    }
    return porChave.values.toList();
  }

  static int _contarPalavras(String texto) {
    var total = 0;
    var dentro = false;
    for (var i = 0; i < texto.length; i++) {
      final c = texto.codeUnitAt(i);
      final ehEspaco = c == 32 || c == 9 || c == 10 || c == 13;
      if (ehEspaco) {
        dentro = false;
      } else if (!dentro) {
        dentro = true;
        total++;
      }
    }
    return total;
  }
}
