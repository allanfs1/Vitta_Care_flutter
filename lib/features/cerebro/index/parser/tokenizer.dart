import '../../data/models/aresta.dart';
import '../../data/models/nota_enums.dart';
import 'mascara_codigo.dart';

/// Resultado bruto de uma varredura do corpo da nota (`obsidian.md` §6.3).
///
/// As arestas saem daqui **não resolvidas**: o campo `para` carrega o alvo
/// literal do wikilink. O `ResolvedorLink` (§5.2) é quem converte para
/// `nt_...` (nota real) ou `?titulo` (link quebrado).
class Achados {
  Achados({
    required this.arestas,
    required this.entidades,
    required this.tags,
    required this.headings,
    required this.blocos,
    required this.textoPlano,
    required this.tarefasTotal,
    required this.tarefasFeitas,
  });

  final List<Aresta> arestas;
  final List<EntidadeRef> entidades;
  final List<String> tags;
  final List<Heading> headings;
  final Map<String, int> blocos;

  /// Corpo sem sintaxe — base para busca textual, trigramas e embeddings.
  final String textoPlano;

  final int tarefasTotal;
  final int tarefasFeitas;
}

/// Varredura de passe único sobre o corpo da nota. O(n) no tamanho do texto.
class Tokenizer {
  Tokenizer(this.corpo, {MascaraCodigo? mascara})
      : mascara = mascara ?? MascaraCodigo.analisar(corpo),
        _linhasInicio = _indexarLinhas(corpo);

  final String corpo;
  final MascaraCodigo mascara;
  final List<int> _linhasInicio;

  static final _reTag =
      RegExp(r'#([A-Za-zÀ-ÿ][\wÀ-ÿ\-]*(?:/[\wÀ-ÿ\-]+)*)');
  static final _reBloco = RegExp(r'\^([A-Za-z][A-Za-z0-9\-]*)\s*$');
  static final _reHeading = RegExp(r'(#{1,6})\s+(.+)$');
  static final _reTarefa = RegExp(r'^\s*[-*+]\s+\[( |x|X)\]\s');

  Achados varrer() {
    final arestas = <Aresta>[];
    final entidades = <EntidadeRef>[];
    final tags = <String>[];
    final headings = <Heading>[];
    final blocos = <String, int>{};
    final plano = StringBuffer();
    var tarefasTotal = 0;
    var tarefasFeitas = 0;

    final n = corpo.length;
    var i = 0;
    var inicioLinha = true;

    while (i < n) {
      // Zona proibida (código, URL, comentário): copia literal e pula.
      if (mascara.bloqueado(i)) {
        final fim = mascara.fimDaZona(i);
        plano.write(corpo.substring(i, fim));
        i = fim <= i ? i + 1 : fim;
        inicioLinha = i > 0 && corpo[i - 1] == '\n';
        continue;
      }

      final c = corpo[i];

      // ── Heading ATX ───────────────────────────────────────────────────────
      if (inicioLinha && c == '#') {
        final fimLinha = _fimLinha(i);
        final m = _reHeading.matchAsPrefix(corpo, i);
        if (m != null && m.end <= fimLinha) {
          final texto = _limparInline(m.group(2)!.trim());
          headings.add(Heading(
            nivel: m.group(1)!.length,
            texto: texto,
            linha: _linhaDe(i),
          ));
          plano
            ..write(texto)
            ..write('\n');
          i = m.end;
          inicioLinha = false;
          continue;
        }
      }

      // ── Tarefa "- [ ] " / "- [x] " ────────────────────────────────────────
      if (inicioLinha) {
        final fimLinha = _fimLinha(i);
        final linha = corpo.substring(i, fimLinha);
        final t = _reTarefa.firstMatch(linha);
        if (t != null) {
          tarefasTotal++;
          if (t.group(1)!.toLowerCase() == 'x') tarefasFeitas++;
        }
      }

      // ── Wikilink / embed / entity-link ────────────────────────────────────
      final ehEmbed = c == '!' && i + 2 < n && corpo[i + 1] == '[' && corpo[i + 2] == '[';
      final ehLink = c == '[' && i + 1 < n && corpo[i + 1] == '[';
      if (ehEmbed || ehLink) {
        final abre = i + (ehEmbed ? 3 : 2);
        final fecha = corpo.indexOf(']]', abre);
        if (fecha > 0) {
          final bruto = corpo.substring(abre, fecha).trim();
          final consumido = _processarLink(
            bruto: bruto,
            ehEmbed: ehEmbed,
            posicao: i,
            fimPosicao: fecha + 2,
            arestas: arestas,
            entidades: entidades,
            plano: plano,
          );
          if (consumido) {
            i = fecha + 2;
            inicioLinha = false;
            continue;
          }
        }
      }

      // ── Tag hierárquica ───────────────────────────────────────────────────
      if (c == '#' && _fronteiraEsquerda(i)) {
        final m = _reTag.matchAsPrefix(corpo, i);
        if (m != null) {
          final tag = m.group(1)!;
          tags.add(tag);
          arestas.add(Aresta(
            de: '',
            para: 'tag:${tag.toLowerCase()}',
            tipo: LinkTipo.tag,
            linha: _linhaDe(i),
          ));
          plano.write(tag);
          i = m.end;
          inicioLinha = false;
          continue;
        }
      }

      // ── Âncora de bloco no fim da linha ───────────────────────────────────
      if (c == '^' && i > 0 && corpo[i - 1] == ' ') {
        final fimLinha = _fimLinha(i);
        final m = _reBloco.matchAsPrefix(corpo, i);
        if (m != null && m.end >= fimLinha) {
          blocos['^${m.group(1)!}'] = _linhaDe(i);
          i = m.end;
          inicioLinha = false;
          continue;
        }
      }

      plano.write(c);
      inicioLinha = c == '\n';
      i++;
    }

    return Achados(
      arestas: arestas,
      entidades: entidades,
      tags: tags,
      headings: headings,
      blocos: blocos,
      textoPlano: plano.toString(),
      tarefasTotal: tarefasTotal,
      tarefasFeitas: tarefasFeitas,
    );
  }

  /// Interpreta o miolo de um `[[...]]`. Devolve `false` quando o conteúdo é
  /// inválido (ex.: `[[]]`), caso em que o chamador trata como texto literal.
  bool _processarLink({
    required String bruto,
    required bool ehEmbed,
    required int posicao,
    required int fimPosicao,
    required List<Aresta> arestas,
    required List<EntidadeRef> entidades,
    required StringBuffer plano,
  }) {
    if (bruto.isEmpty) return false;

    // Separa o alias no PRIMEIRO pipe: "[[a|b|c]]" → alvo a, alias "b|c".
    String alvoParte = bruto;
    var alias = '';
    final pipe = bruto.indexOf('|');
    if (pipe >= 0) {
      alvoParte = bruto.substring(0, pipe).trim();
      alias = bruto.substring(pipe + 1).trim();
    }
    if (alvoParte.isEmpty) return false;

    final linha = _linhaDe(posicao);
    final contexto = _contexto(posicao, fimPosicao);

    // ── Entity-link: [[@tipo:id]] ─────────────────────────────────────────
    if (alvoParte.startsWith('@')) {
      final ref = EntidadeRef.parse(alvoParte);
      if (ref != null) {
        entidades.add(ref);
        arestas.add(Aresta(
          de: '',
          para: ref.chave,
          tipo: LinkTipo.entidade,
          alias: alias,
          linha: linha,
          contexto: contexto,
        ));
        plano.write(alias.isNotEmpty ? alias : ref.tipo.label);
        return true;
      }
      // Tipo desconhecido → cai para wikilink comum (caso-limite 13).
    }

    // ── Âncora (#heading) e bloco (^id) ───────────────────────────────────
    var alvo = alvoParte;
    var ancora = '';
    var bloco = '';
    final hash = alvo.indexOf('#');
    if (hash >= 0) {
      final resto = alvo.substring(hash + 1).trim();
      alvo = alvo.substring(0, hash).trim();
      if (resto.startsWith('^')) {
        bloco = resto.substring(1);
      } else {
        ancora = resto;
      }
    } else {
      final circ = alvo.indexOf('^');
      if (circ > 0) {
        bloco = alvo.substring(circ + 1).trim();
        alvo = alvo.substring(0, circ).trim();
      }
    }

    // `[[#secao]]` — referência interna à própria nota; não gera aresta.
    if (alvo.isEmpty) {
      plano.write(alias.isNotEmpty ? alias : (ancora.isNotEmpty ? ancora : bloco));
      return true;
    }

    arestas.add(Aresta(
      de: '',
      para: alvo,
      tipo: ehEmbed ? LinkTipo.embed : LinkTipo.wiki,
      alias: alias,
      ancora: ancora,
      bloco: bloco,
      linha: linha,
      contexto: contexto,
    ));
    plano.write(alias.isNotEmpty ? alias : alvo);
    return true;
  }

  /// `#` só inicia tag quando precedido por início de texto, espaço ou
  /// pontuação de abertura — nunca por letra, `/` ou outro `#`.
  bool _fronteiraEsquerda(int i) {
    if (i == 0) return true;
    final anterior = corpo[i - 1];
    if (anterior == '/' || anterior == '#') return false;
    return RegExp(r'[\s(\[{>,;:*_"' r"'" r']').hasMatch(anterior);
  }

  int _fimLinha(int i) {
    final j = corpo.indexOf('\n', i);
    return j < 0 ? corpo.length : j;
  }

  /// Número da linha (1-based) de um offset. Busca binária.
  int _linhaDe(int offset) {
    var lo = 0;
    var hi = _linhasInicio.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_linhasInicio[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  /// ~180 caracteres em volta da ocorrência, com espaços colapsados —
  /// preview exibido no painel de backlinks.
  String _contexto(int inicio, int fim) {
    final de = (inicio - 100).clamp(0, corpo.length);
    final ate = (fim + 80).clamp(0, corpo.length);
    var trecho = corpo.substring(de, ate).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (de > 0) trecho = '…$trecho';
    if (ate < corpo.length) trecho = '$trecho…';
    return trecho;
  }

  /// Remove marcação inline de um trecho curto (usado em títulos de heading).
  static String _limparInline(String s) => s
      .replaceAll(RegExp(r'\[\[([^\]|]*\|)?'), '')
      .replaceAll(']]', '')
      .replaceAll(RegExp(r'[*_`~]'), '')
      .trim();

  static List<int> _indexarLinhas(String s) {
    final out = <int>[0];
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) == 10) out.add(i + 1);
    }
    return out;
  }
}
