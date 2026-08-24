import 'package:flutter/material.dart';

import '../data/models/nota_enums.dart';

/// Natureza de um nó do grafo (`obsidian.md` §7.1).
enum NoTipo { nota, entidade, tag, naoResolvido }

/// Um nó do grafo. **Não** carrega posição: as coordenadas vivem em arrays
/// `Float32List` dentro do [GrafoEngine] (§7.1 › "Layout de memória"), o que
/// elimina ponteiro-chasing no laço de física.
class GrafoNo {
  GrafoNo({
    required this.id,
    required this.rotulo,
    required this.noTipo,
    this.notaTipo,
    this.entidadeTipo,
    this.corManual,
    this.origemAgente = false,
    this.fixada = false,
  });

  final String id;
  final String rotulo;
  final NoTipo noTipo;
  final NotaTipo? notaTipo;
  final EntidadeTipo? entidadeTipo;
  final int? corManual;

  /// Nota escrita pela IA — ganha anel externo violeta (§10.5.3).
  final bool origemAgente;

  /// Nota fixada pelo usuário no Explorer (não confundir com nó travado
  /// por arrasto, que vive no engine).
  final bool fixada;

  // ── Métricas (preenchidas por GrafoMetricas) ──────────────────────────────
  int inDegree = 0;
  int outDegree = 0;
  double pagerank = 0;
  int cluster = 0;

  // ── Visual (recalculado a cada mudança de config/zoom) ────────────────────
  double raio = 4;
  Color cor = const Color(0xFF94A3B8);
  double opacidade = 1;

  int get grau => inDegree + outDegree;

  /// Cor padrão do nó, antes de grupos manuais e clusters (§10.5.3).
  Color get corPadrao {
    if (corManual != null) return Color(corManual!);
    switch (noTipo) {
      case NoTipo.entidade:
        return entidadeTipo?.cor ?? const Color(0xFF64748B);
      case NoTipo.tag:
        return const Color(0xFFFACC15);
      case NoTipo.naoResolvido:
        return const Color(0xFF475569);
      case NoTipo.nota:
        return notaTipo?.cor ?? const Color(0xFF94A3B8);
    }
  }

  /// Forma do nó — canal redundante à cor, exigido pela acessibilidade
  /// (§10.13): círculo = nota, losango = entidade, quadrado = tag.
  NoForma get forma {
    switch (noTipo) {
      case NoTipo.nota:
        return notaTipo == NotaTipo.moc ? NoForma.circulo : NoForma.circulo;
      case NoTipo.entidade:
        return entidadeTipo == EntidadeTipo.alerta || entidadeTipo == EntidadeTipo.score
            ? NoForma.triangulo
            : NoForma.losango;
      case NoTipo.tag:
        return NoForma.quadrado;
      case NoTipo.naoResolvido:
        return NoForma.circuloVazado;
    }
  }
}

enum NoForma { circulo, circuloVazado, losango, quadrado, triangulo }

/// Aresta do grafo, referenciando nós por **índice** (não por id) para que o
/// laço de simulação seja um acesso direto a array.
class GrafoAresta {
  GrafoAresta({
    required this.de,
    required this.para,
    required this.tipo,
    this.peso = 1,
  });

  final int de;
  final int para;
  final LinkTipo tipo;
  final double peso;

  double opacidade = 1;
  bool destacada = false;
}

/// Grafo montado — imutável em topologia; posições ficam no engine.
class Grafo {
  Grafo(this.nos, this.arestas)
      : indicePorId = {
          for (var i = 0; i < nos.length; i++) nos[i].id: i,
        };

  final List<GrafoNo> nos;
  final List<GrafoAresta> arestas;
  final Map<String, int> indicePorId;

  bool get vazio => nos.isEmpty;
  int get n => nos.length;

  int? indiceDe(String id) => indicePorId[id];

  /// Vizinhos diretos (entrada + saída) de um índice de nó.
  Set<int> vizinhos(int i) {
    final out = <int>{};
    for (final a in arestas) {
      if (a.de == i) out.add(a.para);
      if (a.para == i) out.add(a.de);
    }
    return out;
  }

  /// Conjunto de nós até [profundidade] saltos a partir de [origem] — base do
  /// modo foco (§7.8) e do grafo local (§7.7).
  Set<int> alcance(int origem, int profundidade) {
    final vistos = <int>{origem};
    var fronteira = <int>{origem};
    for (var d = 0; d < profundidade; d++) {
      final proxima = <int>{};
      for (final i in fronteira) {
        for (final v in vizinhos(i)) {
          if (vistos.add(v)) proxima.add(v);
        }
      }
      if (proxima.isEmpty) break;
      fronteira = proxima;
    }
    return vistos;
  }

  static final vazioConst = Grafo(const [], const []);
}

/// Configuração de forças e exibição, persistida por usuário (§10.5.2).
class ConfigGrafo {
  const ConfigGrafo({
    this.forcaCentro = 0.03,
    this.forcaRepulsao = 6.2,
    this.distanciaLinks = 52,
    this.atrito = 0.65,
    this.multiplicadorTamanho = 1.7,
    this.espessuraLinha = 0.9,
    this.mostrarTags = true,
    this.mostrarEntidades = true,
    this.mostrarNaoResolvidos = false,
    this.mostrarArquivadas = false,
    this.mostrarSetas = true,
    this.animarFluxo = false,
    this.modoFoco = true,
    this.profundidadeLocal = 2,
    this.rotulosAuto = true,
    this.mostrarRotulos = false,
    this.mostrarRotulosClusters = false,
    this.tamanhoRotulo = 1.0,
    this.colorirPorCluster = false,
    this.filtro = '',
    this.grupos = const [],
    this.tiposDesativados = const {},
    this.entidadesDesativadas = const {},
    this.clustersDesativados = const {},
  });

  final double forcaCentro;
  final double forcaRepulsao;
  final double distanciaLinks;
  final double atrito;
  final double multiplicadorTamanho;
  final double espessuraLinha;

  final bool mostrarTags;
  final bool mostrarEntidades;
  final bool mostrarNaoResolvidos;
  final bool mostrarArquivadas;
  final bool mostrarSetas;
  final bool animarFluxo;
  final bool modoFoco;
  final int profundidadeLocal;
  final bool rotulosAuto;
  final bool mostrarRotulos;
  final bool mostrarRotulosClusters;
  final double tamanhoRotulo;
  final bool colorirPorCluster;

  /// Tipos de notas desativados/ocultos no grafo (IDs de [NotaTipo]).
  final Set<String> tiposDesativados;

  /// Tipos de entidades operacionais desativados/ocultos no grafo (IDs de [EntidadeTipo]).
  final Set<String> entidadesDesativadas;

  /// Clusters desativados/ocultos quando [colorirPorCluster] está ativo.
  final Set<int> clustersDesativados;

  /// Indica se há algum filtro da legenda ativo.
  bool get temFiltrosLegendaAtivos =>
      tiposDesativados.isNotEmpty ||
      entidadesDesativadas.isNotEmpty ||
      clustersDesativados.isNotEmpty ||
      !mostrarTags ||
      !mostrarEntidades ||
      mostrarNaoResolvidos;

  /// Quantidade total de categorias desativadas ou filtradas.
  int get totalFiltrosLegendaAtivos =>
      tiposDesativados.length +
      entidadesDesativadas.length +
      clustersDesativados.length +
      (!mostrarTags ? 1 : 0) +
      (!mostrarEntidades ? 1 : 0) +
      (mostrarNaoResolvidos ? 1 : 0);

  /// Filtro no formato da busca (§6.5) aplicado ao grafo.
  final String filtro;

  final List<GrupoGrafo> grupos;

  ConfigGrafo copyWith({
    double? forcaCentro,
    double? forcaRepulsao,
    double? distanciaLinks,
    double? atrito,
    double? multiplicadorTamanho,
    double? espessuraLinha,
    bool? mostrarTags,
    bool? mostrarEntidades,
    bool? mostrarNaoResolvidos,
    bool? mostrarArquivadas,
    bool? mostrarSetas,
    bool? animarFluxo,
    bool? modoFoco,
    int? profundidadeLocal,
    bool? rotulosAuto,
    bool? mostrarRotulos,
    bool? mostrarRotulosClusters,
    double? tamanhoRotulo,
    bool? colorirPorCluster,
    String? filtro,
    List<GrupoGrafo>? grupos,
    Set<String>? tiposDesativados,
    Set<String>? entidadesDesativadas,
    Set<int>? clustersDesativados,
  }) =>
      ConfigGrafo(
        forcaCentro: forcaCentro ?? this.forcaCentro,
        forcaRepulsao: forcaRepulsao ?? this.forcaRepulsao,
        distanciaLinks: distanciaLinks ?? this.distanciaLinks,
        atrito: atrito ?? this.atrito,
        multiplicadorTamanho: multiplicadorTamanho ?? this.multiplicadorTamanho,
        espessuraLinha: espessuraLinha ?? this.espessuraLinha,
        mostrarTags: mostrarTags ?? this.mostrarTags,
        mostrarEntidades: mostrarEntidades ?? this.mostrarEntidades,
        mostrarNaoResolvidos: mostrarNaoResolvidos ?? this.mostrarNaoResolvidos,
        mostrarArquivadas: mostrarArquivadas ?? this.mostrarArquivadas,
        mostrarSetas: mostrarSetas ?? this.mostrarSetas,
        animarFluxo: animarFluxo ?? this.animarFluxo,
        modoFoco: modoFoco ?? this.modoFoco,
        profundidadeLocal: profundidadeLocal ?? this.profundidadeLocal,
        rotulosAuto: rotulosAuto ?? this.rotulosAuto,
        mostrarRotulos: mostrarRotulos ?? this.mostrarRotulos,
        mostrarRotulosClusters:
            mostrarRotulosClusters ?? this.mostrarRotulosClusters,
        tamanhoRotulo: tamanhoRotulo ?? this.tamanhoRotulo,
        colorirPorCluster: colorirPorCluster ?? this.colorirPorCluster,
        filtro: filtro ?? this.filtro,
        grupos: grupos ?? this.grupos,
        tiposDesativados: tiposDesativados ?? this.tiposDesativados,
        entidadesDesativadas: entidadesDesativadas ?? this.entidadesDesativadas,
        clustersDesativados: clustersDesativados ?? this.clustersDesativados,
      );

  Map<String, dynamic> toMap() => {
        'forcaCentro': forcaCentro,
        'forcaRepulsao': forcaRepulsao,
        'distanciaLinks': distanciaLinks,
        'atrito': atrito,
        'multiplicadorTamanho': multiplicadorTamanho,
        'espessuraLinha': espessuraLinha,
        'mostrarTags': mostrarTags,
        'mostrarEntidades': mostrarEntidades,
        'mostrarNaoResolvidos': mostrarNaoResolvidos,
        'mostrarArquivadas': mostrarArquivadas,
        'mostrarSetas': mostrarSetas,
        'animarFluxo': animarFluxo,
        'modoFoco': modoFoco,
        'profundidadeLocal': profundidadeLocal,
        'rotulosAuto': rotulosAuto,
        'mostrarRotulos': mostrarRotulos,
        'mostrarRotulosClusters': mostrarRotulosClusters,
        'tamanhoRotulo': tamanhoRotulo,
        'colorirPorCluster': colorirPorCluster,
        'filtro': filtro,
        'grupos': [for (final g in grupos) g.toMap()],
        'tiposDesativados': tiposDesativados.toList(),
        'entidadesDesativadas': entidadesDesativadas.toList(),
        'clustersDesativados': clustersDesativados.toList(),
      };

  static ConfigGrafo fromMap(Map<String, dynamic> m) => ConfigGrafo(
        forcaCentro: (m['forcaCentro'] as num?)?.toDouble() ?? 0.03,
        forcaRepulsao: (m['forcaRepulsao'] as num?)?.toDouble() ?? 6.2,
        distanciaLinks: (m['distanciaLinks'] as num?)?.toDouble() ?? 52,
        atrito: (m['atrito'] as num?)?.toDouble() ?? 0.65,
        multiplicadorTamanho: (m['multiplicadorTamanho'] as num?)?.toDouble() ?? 1.7,
        espessuraLinha: (m['espessuraLinha'] as num?)?.toDouble() ?? 0.9,
        mostrarTags: m['mostrarTags'] != false,
        mostrarEntidades: m['mostrarEntidades'] != false,
        mostrarNaoResolvidos: m['mostrarNaoResolvidos'] == true,
        mostrarArquivadas: m['mostrarArquivadas'] == true,
        mostrarSetas: m['mostrarSetas'] != false,
        animarFluxo: m['animarFluxo'] == true,
        modoFoco: m['modoFoco'] != false,
        profundidadeLocal: (m['profundidadeLocal'] as num?)?.toInt() ?? 2,
        rotulosAuto: m['rotulosAuto'] != false,
        mostrarRotulos: m['mostrarRotulos'] == true,
        mostrarRotulosClusters: m['mostrarRotulosClusters'] == true,
        tamanhoRotulo: (m['tamanhoRotulo'] as num?)?.toDouble() ?? 1.0,
        colorirPorCluster: m['colorirPorCluster'] == true,
        filtro: (m['filtro'] ?? '').toString(),
        grupos: [
          for (final g in (m['grupos'] as List? ?? const []))
            if (g is Map) GrupoGrafo.fromMap(g.cast<String, dynamic>()),
        ],
        tiposDesativados: (m['tiposDesativados'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
        entidadesDesativadas: (m['entidadesDesativadas'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
        clustersDesativados: (m['clustersDesativados'] as List?)
                ?.map((e) => (e as num).toInt())
                .toSet() ??
            const {},
      );
}

/// Regra `query → cor` de colorização manual (estilo *Groups* do Obsidian).
class GrupoGrafo {
  const GrupoGrafo({required this.nome, required this.query, required this.cor});

  final String nome;
  final String query;
  final int cor;

  Map<String, dynamic> toMap() => {'nome': nome, 'query': query, 'cor': cor};

  static GrupoGrafo fromMap(Map<String, dynamic> m) => GrupoGrafo(
        nome: (m['nome'] ?? '').toString(),
        query: (m['query'] ?? '').toString(),
        cor: (m['cor'] as num?)?.toInt() ?? 0xFF94A3B8,
      );

  /// Grupos padrão de um vault novo — refletem a paleta de §10.5.3.
  static const padrao = <GrupoGrafo>[
    GrupoGrafo(nome: 'MOCs', query: 'tag:#moc', cor: 0xFFF43F5E),
    GrupoGrafo(nome: 'Protocolos', query: 'tipo:protocolo', cor: 0xFF2E9E8F),
    GrupoGrafo(nome: 'Escritas pela IA', query: 'origem:agente', cor: 0xFF7C3AED),
  ];
}

/// Escopo do grafo exibido.
class GrafoEscopo {
  const GrafoEscopo.global()
      : notaFocal = null,
        profundidade = 0;

  const GrafoEscopo.local(String this.notaFocal, this.profundidade);

  final String? notaFocal;
  final int profundidade;

  bool get ehLocal => notaFocal != null;

  @override
  bool operator ==(Object other) =>
      other is GrafoEscopo &&
      other.notaFocal == notaFocal &&
      other.profundidade == profundidade;

  @override
  int get hashCode => Object.hash(notaFocal, profundidade);
}
