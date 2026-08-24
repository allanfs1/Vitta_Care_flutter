import 'dart:math' as math;

import '../data/models/aresta.dart';
import '../data/models/nota.dart';
import '../data/models/nota_enums.dart';
import 'texto_busca.dart';
import 'vault_index.dart';

/// Sinônimos clínicos em PT-BR para expansão de busca.
///
/// Quando o usuário digita "paciente", a busca também localiza "cliente"; ao
/// digitar "médico" encontra "doutor", etc. Cada grupo é bidirecional.
const _sinonimos = <List<String>>[
  ['paciente', 'cliente'],
  ['consulta', 'agendamento', 'atendimento'],
  ['medico', 'doutor', 'dr'],
  ['protocolo', 'procedimento', 'rotina'],
  ['absenteismo', 'falta', 'ausencia', 'no-show', 'noshow'],
  ['overbooking', 'sobrecarga', 'excesso'],
  ['satisfacao', 'nps', 'avaliacao'],
  ['risco', 'alerta', 'critico'],
  ['equipe', 'time', 'colaborador'],
  ['recepcao', 'checkin', 'check-in', 'entrada'],
  ['whatsapp', 'mensagem', 'chat'],
  ['relatorio', 'report', 'dashboard'],
  ['tarefa', 'task', 'acao'],
  ['cerebro', 'vault', 'base de conhecimento'],
];

/// Trecho de contexto exibido no resultado de busca.
class TrechoBusca {
  const TrechoBusca(this.texto, this.linha, this.inicioDestaque, this.fimDestaque);

  final String texto;
  final int linha;
  final int inicioDestaque;
  final int fimDestaque;
}

class ResultadoBusca {
  const ResultadoBusca(this.nota, this.score, this.trechos);

  final Nota nota;
  final double score;
  final List<TrechoBusca> trechos;
}

/// Consulta já interpretada — resultado do parse dos operadores de §6.5.
class ConsultaBusca {
  ConsultaBusca({
    this.termos = const [],
    this.termosExpandidos = const [],
    this.frases = const [],
    this.exclusoes = const [],
    this.tags = const [],
    this.paths = const [],
    this.arquivos = const [],
    this.tipos = const [],
    this.origens = const [],
    this.estados = const [],
    this.entidades = const [],
    this.somenteOrfas = false,
    this.criadaApos,
    this.editadaApos,
    this.confiancaMin,
  });

  final List<String> termos;

  /// Termos originais + sinônimos clínicos expandidos.
  final List<String> termosExpandidos;
  final List<String> frases;
  final List<String> exclusoes;
  final List<String> tags;
  final List<String> paths;
  final List<String> arquivos;
  final List<NotaTipo> tipos;
  final List<NotaOrigem> origens;
  final List<NotaEstado> estados;
  final List<String> entidades;
  final bool somenteOrfas;
  final DateTime? criadaApos;
  final DateTime? editadaApos;

  /// Filtro de confiança mínima para notas de IA (operador `confianca:>0.8`).
  final double? confiancaMin;

  bool get vazia =>
      termos.isEmpty &&
      frases.isEmpty &&
      tags.isEmpty &&
      paths.isEmpty &&
      arquivos.isEmpty &&
      tipos.isEmpty &&
      origens.isEmpty &&
      estados.isEmpty &&
      entidades.isEmpty &&
      !somenteOrfas &&
      criadaApos == null &&
      editadaApos == null &&
      confiancaMin == null;

  bool get temFiltro =>
      tags.isNotEmpty ||
      paths.isNotEmpty ||
      arquivos.isNotEmpty ||
      tipos.isNotEmpty ||
      origens.isNotEmpty ||
      estados.isNotEmpty ||
      entidades.isNotEmpty ||
      somenteOrfas ||
      criadaApos != null ||
      editadaApos != null ||
      confiancaMin != null;
}

/// Busca textual com ranking híbrido (`obsidian.md` §6.5).
///
/// Combina correspondência de título/alias/tag, um BM25 simplificado sobre o
/// corpo, centralidade no grafo e recência.
class BuscaService {
  BuscaService(this.index);

  final VaultIndex index;

  static final _reOperador = RegExp(
    r'(\w+):("[^"]+"|\S+)',
  );
  static final _reFrase = RegExp(r'"([^"]+)"');

  /// Interpreta a string digitada pelo usuário.
  ConsultaBusca interpretar(String bruta) {
    var texto = bruta.trim();
    if (texto.isEmpty) return ConsultaBusca();

    final tags = <String>[];
    final paths = <String>[];
    final arquivos = <String>[];
    final tipos = <NotaTipo>[];
    final origens = <NotaOrigem>[];
    final estados = <NotaEstado>[];
    final entidades = <String>[];
    var orfas = false;
    DateTime? criadaApos;
    DateTime? editadaApos;
    double? confiancaMin;

    texto = texto.replaceAllMapped(_reOperador, (m) {
      final chave = m.group(1)!.toLowerCase();
      var valor = m.group(2)!;
      if (valor.startsWith('"') && valor.endsWith('"')) {
        valor = valor.substring(1, valor.length - 1);
      }
      switch (chave) {
        case 'tag':
          tags.add(valor.startsWith('#') ? valor.substring(1).toLowerCase() : valor.toLowerCase());
          return '';
        case 'path':
        case 'pasta':
          paths.add(valor.toLowerCase());
          return '';
        case 'file':
        case 'arquivo':
          arquivos.add(valor.toLowerCase());
          return '';
        case 'tipo':
          tipos.add(NotaTipo.fromId(valor.toLowerCase()));
          return '';
        case 'origem':
        case 'agente':
          // `agente:true` é alias conveniente de `origem:agente`
          if (chave == 'agente') {
            origens.add(NotaOrigem.agente);
          } else {
            origens.add(NotaOrigem.fromId(valor.toLowerCase()));
          }
          return '';
        case 'estado':
          estados.add(NotaEstado.fromId(valor.toLowerCase()));
          return '';
        case 'entidade':
          entidades.add(valor.startsWith('@') ? valor : '@$valor');
          return '';
        case 'orfa':
          orfas = valor.toLowerCase() != 'false';
          return '';
        case 'criada':
          criadaApos = _dataDe(valor);
          return '';
        case 'editada':
          editadaApos = _dataDe(valor);
          return '';
        case 'confianca':
        case 'confiança':
          final limpo = valor.replaceAll(RegExp(r'[><=]'), '');
          confiancaMin = double.tryParse(limpo);
          return '';
        default:
          return m.group(0)!;
      }
    });

    final frases = <String>[];
    texto = texto.replaceAllMapped(_reFrase, (m) {
      frases.add(m.group(1)!.toLowerCase());
      return '';
    });

    final termos = <String>[];
    final exclusoes = <String>[];
    for (final parte in texto.split(RegExp(r'\s+'))) {
      final p = parte.trim();
      if (p.isEmpty || p.toUpperCase() == 'OR' || p.toUpperCase() == 'E') continue;
      if (p.startsWith('-') && p.length > 1) {
        exclusoes.add(removerAcentos(p.substring(1).toLowerCase()));
      } else if (p.startsWith('#') && p.length > 1) {
        tags.add(p.substring(1).toLowerCase());
      } else {
        termos.add(removerAcentos(p.toLowerCase()));
      }
    }

    // Expande termos com sinônimos clínicos
    final termosExpandidos = _expandirSinonimos(termos);

    return ConsultaBusca(
      termos: termos,
      termosExpandidos: termosExpandidos,
      frases: frases,
      exclusoes: exclusoes,
      tags: tags,
      paths: paths,
      arquivos: arquivos,
      tipos: tipos,
      origens: origens,
      estados: estados,
      entidades: entidades,
      somenteOrfas: orfas,
      criadaApos: criadaApos,
      editadaApos: editadaApos,
      confiancaMin: confiancaMin,
    );
  }

  /// Expande termos com sinônimos clínicos bidirecionais.
  static List<String> _expandirSinonimos(List<String> termos) {
    final expandidos = <String>{...termos};
    for (final termo in termos) {
      for (final grupo in _sinonimos) {
        if (grupo.any((s) => removerAcentos(s) == termo)) {
          for (final sinonimo in grupo) {
            expandidos.add(removerAcentos(sinonimo));
          }
        }
      }
    }
    return expandidos.toList();
  }

  /// Executa a busca e devolve os resultados ordenados por score.
  List<ResultadoBusca> buscar(String consultaBruta, {int limite = 60}) {
    final q = interpretar(consultaBruta);
    if (q.vazia) return const [];

    final orfasIds = q.somenteOrfas
        ? index.orfas.map((n) => n.id).toSet()
        : const <String>{};

    final agora = DateTime.now();
    final out = <ResultadoBusca>[];

    for (final nota in index.notas.values) {
      if (nota.excluida) continue;
      if (!_passaFiltros(nota, q, orfasIds)) continue;

      final score = _pontuar(nota, q, agora);
      if (score <= 0 && q.termos.isNotEmpty) continue;
      if (score <= 0 && q.frases.isNotEmpty) continue;

      // Trecho ainda não: extrair snippet exige varrer a nota linha a linha, e
      // a esmagadora maioria destes candidatos não sobrevive ao corte abaixo.
      out.add(ResultadoBusca(nota, score, const []));
    }

    out.sort((a, b) => b.score.compareTo(a.score));
    final topo = out.length > limite ? out.sublist(0, limite) : out;
    return [
      for (final r in topo) ResultadoBusca(r.nota, r.score, _trechos(r.nota, q)),
    ];
  }

  bool _passaFiltros(Nota nota, ConsultaBusca q, Set<String> orfasIds) {
    if (q.somenteOrfas && !orfasIds.contains(nota.id)) return false;
    if (q.tipos.isNotEmpty && !q.tipos.contains(nota.tipo)) return false;
    if (q.origens.isNotEmpty && !q.origens.contains(nota.origem)) return false;
    if (q.estados.isNotEmpty && !q.estados.contains(nota.estado)) return false;

    if (q.tags.isNotEmpty) {
      final tem = q.tags.any((t) => nota.tags.any((nt) => nt == t || nt.startsWith('$t/')));
      if (!tem) return false;
    }
    if (q.paths.isNotEmpty) {
      final p = nota.path.toLowerCase();
      if (!q.paths.any(p.startsWith)) return false;
    }
    if (q.arquivos.isNotEmpty) {
      final f = nota.nomeArquivo.toLowerCase();
      if (!q.arquivos.any(f.contains)) return false;
    }
    if (q.entidades.isNotEmpty) {
      final refs = nota.entityRefs.map((e) => e.chave).toSet();
      if (!q.entidades.any(refs.contains)) return false;
    }
    if (q.criadaApos != null && nota.createdAt.isBefore(q.criadaApos!)) return false;
    if (q.editadaApos != null && nota.updatedAt.isBefore(q.editadaApos!)) return false;

    // Filtro de confiança mínima para notas de IA
    if (q.confiancaMin != null) {
      if (!nota.ehDeAgente) return false;
      final conf = nota.confianca ?? 0;
      if (conf < q.confiancaMin!) return false;
    }

    if (q.exclusoes.isNotEmpty) {
      final texto = index.textoBusca(nota.id);
      for (final ex in q.exclusoes) {
        if (texto.corpo.contains(ex) || texto.titulo.contains(ex)) return false;
      }
    }
    return true;
  }

  double _pontuar(Nota nota, ConsultaBusca q, DateTime agora) {
    // Só filtros, sem termos: ordena por relevância estrutural.
    if (q.termos.isEmpty && q.frases.isEmpty) {
      return 1.0 +
          0.6 * math.log(1 + nota.metrics.inDegree) +
          0.4 * _recencia(nota.updatedAt, agora) +
          (nota.fixada ? 0.3 : 0) +
          _boostTipoBase(nota);
    }

    // Já normalizado na indexação — ver `VaultIndex.textoBusca`.
    final texto = index.textoBusca(nota.id);
    final titulo = texto.titulo;
    final aliases = texto.aliases;
    final corpo = texto.corpo;
    final arquivo = texto.arquivo;

    var score = 0.0;
    var casouAlgo = false;

    for (final frase in q.frases) {
      final f = removerAcentos(frase);
      if (corpo.contains(f) || titulo.contains(f)) {
        score += 3.0;
        casouAlgo = true;
      }
    }

    // Busca usando termos originais (peso cheio) e sinônimos expandidos (peso parcial)
    for (final termo in q.termos) {
      final (s, casou) = _pontuarTermo(termo, titulo, aliases, corpo, arquivo, texto, nota, 1.0);
      score += s;
      if (casou) casouAlgo = true;
    }

    // Sinônimos expandidos recebem peso reduzido (60%) para não poluir
    for (final termo in q.termosExpandidos) {
      if (q.termos.contains(termo)) continue; // já pontuou acima
      final (s, casou) = _pontuarTermo(termo, titulo, aliases, corpo, arquivo, texto, nota, 0.6);
      score += s;
      if (casou) casouAlgo = true;
    }

    if (!casouAlgo) return 0;

    score += 0.6 * math.log(1 + nota.metrics.inDegree);
    score += 0.4 * _recencia(nota.updatedAt, agora);
    if (nota.fixada) score += 0.3;
    if (nota.arquivada) score -= 2.0;
    if (nota.ehRascunho) score -= 0.4;

    // Boost por tipo operacional — protocolos e MOCs sobem quando a consulta
    // contém termos clínicos, dando prioridade a fontes de autoridade.
    score += _boostTipoBase(nota);

    return score;
  }

  /// Pontua um único termo contra os campos da nota. [peso] escala o resultado
  /// (1.0 para termos originais, 0.6 para sinônimos expandidos).
  (double, bool) _pontuarTermo(
    String termo,
    String titulo,
    List<String> aliases,
    String corpo,
    String arquivo,
    TextoBusca texto,
    Nota nota,
    double peso,
  ) {
    var score = 0.0;
    var casou = false;

    if (titulo == termo) {
      score += 3.0 * peso;
      casou = true;
    } else if (titulo.startsWith(termo)) {
      score += 1.5 * peso;
      casou = true;
    } else if (titulo.contains(termo)) {
      score += 1.0 * peso;
      casou = true;
    }

    if (aliases.any((a) => a == termo)) {
      score += 2.0 * peso;
      casou = true;
    }
    if (arquivo.contains(termo)) {
      score += 0.8 * peso;
      casou = true;
    }
    if (texto.tags.any((t) => t.contains(termo))) {
      score += 1.2 * peso;
      casou = true;
    }

    final ocorrencias = _contarOcorrencias(corpo, termo);
    if (ocorrencias > 0) {
      // BM25 simplificado: saturação por frequência, normalizada pelo tamanho.
      final tf = ocorrencias.toDouble();
      final norm = 1.0 + (nota.wordCount / 500.0);
      score += peso * (tf * 2.2) / (tf + 1.2 * norm);
      casou = true;
    } else if (!casou && _fuzzy(titulo, termo)) {
      // Tolerância a erro de digitação (§6.5) — só quando nada mais casou.
      score += 0.7 * peso;
      casou = true;
    }

    return (score, casou);
  }

  /// Boost base por tipo de nota — fontes de autoridade operacional sobem.
  static double _boostTipoBase(Nota nota) {
    if (nota.tipo == NotaTipo.protocolo) return 0.5;
    if (nota.tipo == NotaTipo.moc) return 0.4;
    if (nota.tipo == NotaTipo.decisao) return 0.35;
    if (nota.tipo == NotaTipo.conceito) return 0.2;
    return 0;
  }

  List<TrechoBusca> _trechos(Nota nota, ConsultaBusca q) {
    if (nota.conteudo.isEmpty) return const [];
    // Inclui sinônimos expandidos na busca de trechos para maior cobertura
    final alvos = <String>{...q.frases, ...q.termos, ...q.termosExpandidos}
        .toList();
    if (alvos.isEmpty) return const [];

    final out = <TrechoBusca>[];
    final linhas = nota.conteudo.split('\n');
    for (var i = 0; i < linhas.length && out.length < 5; i++) {
      final linha = linhas[i];
      final normal = removerAcentos(linha.toLowerCase());
      for (final alvo in alvos) {
        final pos = normal.indexOf(alvo);
        if (pos < 0) continue;
        final de = math.max(0, pos - 45);
        final ate = math.min(linha.length, pos + alvo.length + 75);
        final texto = (de > 0 ? '…' : '') + linha.substring(de, ate).trim();
        out.add(TrechoBusca(
          texto,
          i + 1,
          pos - de + (de > 0 ? 1 : 0),
          pos - de + alvo.length + (de > 0 ? 1 : 0),
        ));
        break;
      }
    }
    return out;
  }

  static int _contarOcorrencias(String texto, String termo) {
    if (termo.isEmpty) return 0;
    var n = 0;
    var i = texto.indexOf(termo);
    while (i >= 0) {
      n++;
      i = texto.indexOf(termo, i + termo.length);
    }
    return n;
  }

  /// Similaridade por trigramas (Jaccard adaptativo) para tolerar erro de
  /// digitação. Termos longos (≥ 6 chars) usam threshold mais baixo (0.28)
  /// para capturar mais variações ortográficas.
  static bool _fuzzy(String a, String b) {
    if (b.length < 4) return false;
    final ta = _trigramas(a);
    final tb = _trigramas(b);
    if (ta.isEmpty || tb.isEmpty) return false;
    final inter = ta.intersection(tb).length;
    final uniao = ta.union(tb).length;
    // Threshold adaptativo: termos longos são mais tolerantes a erros.
    final threshold = b.length >= 6 ? 0.28 : 0.35;
    return uniao > 0 && inter / uniao >= threshold;
  }

  static Set<String> _trigramas(String s) {
    final out = <String>{};
    final t = ' $s ';
    for (var i = 0; i + 3 <= t.length; i++) {
      out.add(t.substring(i, i + 3));
    }
    return out;
  }

  static double _recencia(DateTime quando, DateTime agora) {
    final dias = agora.difference(quando).inDays.toDouble();
    return math.exp(-dias / 45.0);
  }

  static DateTime? _dataDe(String valor) {
    var v = valor;
    if (v.startsWith('>') || v.startsWith('<')) v = v.substring(1);
    return DateTime.tryParse(v);
  }
}
