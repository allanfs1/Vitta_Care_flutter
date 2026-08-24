import 'nota_enums.dart';

/// Uma aresta do grafo do Cérebro (`obsidian.md` §4.4).
///
/// [de] é sempre o id de uma nota real. [para] pode ser:
///  - `nt_...`         — outra nota
///  - `@tipo:id`       — entidade operacional (ponte, §bridge)
///  - `tag:nome`       — tag
///  - `?titulo`        — link não resolvido (nó fantasma)
class Aresta {
  const Aresta({
    required this.de,
    required this.para,
    this.tipo = LinkTipo.wiki,
    this.alias = '',
    this.ancora = '',
    this.bloco = '',
    this.linha = 0,
    this.contexto = '',
    this.peso = 1.0,
  });

  final String de;
  final String para;
  final LinkTipo tipo;

  /// Texto exibido quando o link usa `[[alvo|alias]]`.
  final String alias;

  /// `#heading` do destino.
  final String ancora;

  /// `^blocoId` do destino.
  final String bloco;

  /// Linha (1-based) da ocorrência na nota de origem.
  final int linha;

  /// ~120 caracteres em volta da ocorrência, para preview do backlink.
  final String contexto;

  final double peso;

  bool get ehEntidade => para.startsWith('@');
  bool get ehTag => para.startsWith('tag:');
  bool get ehNaoResolvido => para.startsWith('?');

  /// Rótulo do alvo para exibição (sem o prefixo técnico).
  String get alvoLegivel {
    if (ehTag) return '#${para.substring(4)}';
    if (ehNaoResolvido) return para.substring(1);
    return alias.isNotEmpty ? alias : para;
  }

  /// Chave de identidade: duas arestas iguais (mesmo par + tipo + âncora)
  /// são fundidas somando o peso durante a indexação.
  String get chave => '$de→$para|${tipo.id}|$ancora|$bloco';

  Aresta comPeso(double novoPeso) => Aresta(
        de: de,
        para: para,
        tipo: tipo,
        alias: alias,
        ancora: ancora,
        bloco: bloco,
        linha: linha,
        contexto: contexto,
        peso: novoPeso,
      );

  Map<String, dynamic> toMap(String clinicaId) => {
        'clinicaId': clinicaId,
        'de': de,
        'para': para,
        'tipo': tipo.id,
        if (alias.isNotEmpty) 'alias': alias,
        if (ancora.isNotEmpty) 'ancora': ancora,
        if (bloco.isNotEmpty) 'bloco': bloco,
        'linha': linha,
        'contexto': contexto,
        'peso': peso,
      };

  static Aresta fromMap(Map<String, dynamic> m) => Aresta(
        de: (m['de'] ?? '').toString(),
        para: (m['para'] ?? '').toString(),
        tipo: LinkTipo.fromId(m['tipo'] as String?),
        alias: (m['alias'] ?? '').toString(),
        ancora: (m['ancora'] ?? '').toString(),
        bloco: (m['bloco'] ?? '').toString(),
        linha: (m['linha'] as num?)?.toInt() ?? 0,
        contexto: (m['contexto'] ?? '').toString(),
        peso: (m['peso'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  bool operator ==(Object other) => other is Aresta && other.chave == chave;

  @override
  int get hashCode => chave.hashCode;

  @override
  String toString() => 'Aresta($de → $para, ${tipo.id}, peso $peso)';
}

/// Referência a uma entidade operacional citada por uma nota.
class EntidadeRef {
  const EntidadeRef(this.tipo, this.id);

  final EntidadeTipo tipo;
  final String id;

  /// Chave usada como id de nó do grafo: `@medico:med_44`.
  String get chave => '@${tipo.id}:$id';

  static EntidadeRef? parse(String chave) {
    if (!chave.startsWith('@')) return null;
    final i = chave.indexOf(':');
    if (i < 2) return null;
    final tipo = EntidadeTipo.fromId(chave.substring(1, i));
    if (tipo == null) return null;
    final id = chave.substring(i + 1);
    return id.isEmpty ? null : EntidadeRef(tipo, id);
  }

  Map<String, dynamic> toMap() => {'tipo': tipo.id, 'id': id};

  static EntidadeRef? fromMap(Map<String, dynamic> m) {
    final tipo = EntidadeTipo.fromId(m['tipo'] as String?);
    final id = (m['id'] ?? '').toString();
    if (tipo == null || id.isEmpty) return null;
    return EntidadeRef(tipo, id);
  }

  @override
  bool operator ==(Object other) => other is EntidadeRef && other.chave == chave;

  @override
  int get hashCode => chave.hashCode;

  @override
  String toString() => chave;
}

/// Um heading extraído da nota — alimenta o painel Sumário e a resolução
/// de `[[nota#heading]]`.
class Heading {
  const Heading({
    required this.nivel,
    required this.texto,
    required this.linha,
  });

  final int nivel;
  final String texto;
  final int linha;

  String get slug => slugify(texto);

  Map<String, dynamic> toMap() =>
      {'nivel': nivel, 'texto': texto, 'slug': slug, 'linha': linha};

  static Heading fromMap(Map<String, dynamic> m) => Heading(
        nivel: (m['nivel'] as num?)?.toInt() ?? 1,
        texto: (m['texto'] ?? '').toString(),
        linha: (m['linha'] as num?)?.toInt() ?? 0,
      );
}

/// Normaliza um texto para uso como âncora/chave de índice: minúsculas,
/// sem acento, espaços viram hífen.
String slugify(String texto) {
  final semAcento = removerAcentos(texto.toLowerCase());
  return semAcento
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-');
}

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

/// Tabela de code unit acentuado → code unit sem acento.
///
/// Substitui o `_comAcento.indexOf(ch)` que a versão anterior fazia por
/// caractere: numa busca sobre o corpo das notas isso era uma varredura linear
/// de 24 caracteres para cada letra de cada nota.
final Map<int, int> _mapaAcentos = {
  for (var i = 0; i < _comAcento.length; i++)
    _comAcento.codeUnitAt(i): _semAcento.codeUnitAt(i),
};

/// Remove acentos preservando o restante dos caracteres. Usado em toda
/// normalização de chave (aliases, busca, tags).
///
/// Caminho rápido para texto puro ASCII — a esmagadora maioria das linhas de
/// uma nota —, que devolve a própria string sem alocar nada.
String removerAcentos(String s) {
  var precisa = false;
  for (var i = 0; i < s.length; i++) {
    if (s.codeUnitAt(i) > 127) {
      precisa = true;
      break;
    }
  }
  if (!precisa) return s;

  final unidades = List<int>.filled(s.length, 0);
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    unidades[i] = c > 127 ? (_mapaAcentos[c] ?? c) : c;
  }
  return String.fromCharCodes(unidades);
}

/// Chave canônica de resolução de link: minúscula, sem acento, sem `.md`,
/// espaços colapsados.
String chaveNormalizada(String s) {
  var t = s.trim();
  if (t.toLowerCase().endsWith('.md')) t = t.substring(0, t.length - 3);
  return removerAcentos(t.toLowerCase()).replaceAll(RegExp(r'\s+'), ' ');
}
