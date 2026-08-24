import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models/aresta.dart';
import '../index/busca_service.dart';
import '../index/vault_index.dart';
import 'grafo_metricas.dart';
import 'grafo_modelo.dart';

/// Converte o [VaultIndex] em um [Grafo] pronto para simular e pintar
/// (`obsidian.md` §7.1 e §10.5.2).
class GrafoBuilder {
  const GrafoBuilder(this.index, this.busca);

  final VaultIndex index;
  final BuscaService busca;

  /// Teto de nós — acima disso, corta pelos de maior PageRank (§10.5.5).
  static const int maxNos = 3000;

  ResultadoGrafo construir({
    required ConfigGrafo config,
    GrafoEscopo escopo = const GrafoEscopo.global(),
  }) {
    // ── 1. Universo de notas permitido pelo filtro ──────────────────────────
    Set<String>? permitidas;
    if (config.filtro.trim().isNotEmpty) {
      permitidas = busca
          .buscar(config.filtro, limite: 100000)
          .map((r) => r.nota.id)
          .toSet();
    }

    final nos = <GrafoNo>[];
    final indicePorId = <String, int>{};

    void addNo(GrafoNo no) {
      if (indicePorId.containsKey(no.id)) return;
      indicePorId[no.id] = nos.length;
      nos.add(no);
    }

    // ── 2. Nós de nota ──────────────────────────────────────────────────────
    for (final nota in index.notas.values) {
      if (nota.excluida) continue;
      if (nota.arquivada && !config.mostrarArquivadas) continue;
      if (config.tiposDesativados.contains(nota.tipo.id)) continue;
      if (permitidas != null && !permitidas.contains(nota.id)) continue;
      addNo(GrafoNo(
        id: nota.id,
        rotulo: nota.titulo.isNotEmpty ? nota.titulo : nota.nomeArquivo,
        noTipo: NoTipo.nota,
        notaTipo: nota.tipo,
        corManual: nota.cor,
        origemAgente: nota.ehDeAgente,
        fixada: nota.fixada,
      ));
    }

    // ── 3. Arestas + nós auxiliares (tags, entidades, quebrados) ───────────
    final arestas = <GrafoAresta>[];
    for (final entry in index.forward.entries) {
      final deIdx = indicePorId[entry.key];
      if (deIdx == null) continue;

      for (final a in entry.value) {
        if (a.ehTag && !config.mostrarTags) continue;
        if (a.ehEntidade && !config.mostrarEntidades) continue;
        if (a.ehNaoResolvido && !config.mostrarNaoResolvidos) continue;

        var paraIdx = indicePorId[a.para];
        if (paraIdx == null) {
          final auxiliar = _noAuxiliar(a, config);
          if (auxiliar == null) continue; // nota filtrada fora
          addNo(auxiliar);
          paraIdx = indicePorId[a.para]!;
        }
        if (deIdx == paraIdx) continue;

        arestas.add(GrafoAresta(
          de: deIdx,
          para: paraIdx,
          tipo: a.tipo,
          peso: a.peso,
        ));
      }
    }

    var grafo = Grafo(nos, arestas);
    final metricas = GrafoMetricas.calcular(grafo);

    // ── 3.5. Filtro de clusters desativados (Louvain) ───────────────────────
    if (config.colorirPorCluster && config.clustersDesativados.isNotEmpty) {
      final manter = <int>{};
      for (var i = 0; i < grafo.n; i++) {
        if (!config.clustersDesativados.contains(grafo.nos[i].cluster)) {
          manter.add(i);
        }
      }
      if (manter.length < grafo.n) {
        grafo = _subgrafo(grafo, manter);
        GrafoMetricas.calcular(grafo);
      }
    }

    // ── 4. Recorte por escopo local ────────────────────────────────────────
    if (escopo.ehLocal) {
      final focal = grafo.indiceDe(escopo.notaFocal!);
      if (focal != null) {
        final alcance = grafo.alcance(focal, escopo.profundidade);
        grafo = _subgrafo(grafo, alcance);
        GrafoMetricas.calcular(grafo);
      }
    } else if (grafo.n > maxNos) {
      // ── 5. Corte por relevância ──────────────────────────────────────────
      final ordenados = List.generate(grafo.n, (i) => i)
        ..sort((a, b) => grafo.nos[b].pagerank.compareTo(grafo.nos[a].pagerank));
      grafo = _subgrafo(grafo, ordenados.take(maxNos).toSet());
      GrafoMetricas.calcular(grafo);
    }

    // ── 6. Cor e raio ───────────────────────────────────────────────────────
    _aplicarCores(grafo, config);
    _aplicarRaios(grafo, config);

    return ResultadoGrafo(
      grafo: grafo,
      metricas: metricas,
      truncado: nos.length > grafo.n && !escopo.ehLocal,
      totalOriginal: nos.length,
    );
  }

  GrafoNo? _noAuxiliar(Aresta a, ConfigGrafo config) {
    if (a.ehTag) {
      return GrafoNo(
        id: a.para,
        rotulo: '#${a.para.substring(4)}',
        noTipo: NoTipo.tag,
      );
    }
    if (a.ehEntidade) {
      final ref = EntidadeRef.parse(a.para);
      if (ref == null) return null;
      if (config.entidadesDesativadas.contains(ref.tipo.id)) return null;
      return GrafoNo(
        id: a.para,
        rotulo: a.alias.isNotEmpty ? a.alias : '${ref.tipo.label} ${ref.id}',
        noTipo: NoTipo.entidade,
        entidadeTipo: ref.tipo,
      );
    }
    if (a.ehNaoResolvido) {
      return GrafoNo(
        id: a.para,
        rotulo: a.alias.isNotEmpty ? a.alias : a.para.substring(1),
        noTipo: NoTipo.naoResolvido,
      );
    }
    return null; // nota que foi filtrada fora do grafo
  }

  Grafo _subgrafo(Grafo original, Set<int> manter) {
    final novoIndice = <int, int>{};
    final nos = <GrafoNo>[];
    for (var i = 0; i < original.n; i++) {
      if (!manter.contains(i)) continue;
      novoIndice[i] = nos.length;
      nos.add(original.nos[i]);
    }
    final arestas = <GrafoAresta>[];
    for (final a in original.arestas) {
      final de = novoIndice[a.de];
      final para = novoIndice[a.para];
      if (de == null || para == null) continue;
      arestas.add(GrafoAresta(de: de, para: para, tipo: a.tipo, peso: a.peso));
    }
    return Grafo(nos, arestas);
  }

  /// Precedência de cor (§10.5.3): grupo manual > cor da nota > cluster > tipo.
  void _aplicarCores(Grafo grafo, ConfigGrafo config) {
    final porGrupo = <String, int>{};
    for (final g in config.grupos) {
      if (g.query.trim().isEmpty) continue;
      for (final r in busca.buscar(g.query, limite: 100000)) {
        porGrupo.putIfAbsent(r.nota.id, () => g.cor);
      }
    }

    for (final no in grafo.nos) {
      final doGrupo = porGrupo[no.id];
      if (doGrupo != null) {
        no.cor = Color(doGrupo);
      } else if (no.corManual != null) {
        no.cor = Color(no.corManual!);
      } else if (config.colorirPorCluster && no.noTipo == NoTipo.nota) {
        no.cor = paletaCluster[no.cluster % paletaCluster.length];
      } else {
        no.cor = no.corPadrao;
      }
      no.opacidade = 1;
    }
  }

  void _aplicarRaios(Grafo grafo, ConfigGrafo config) {
    for (final no in grafo.nos) {
      no.raio = raioDe(no, grafo.n, config);
    }
  }

  /// Raio do nó com escala logarítmica refinada (evita nós gigantes e sobreposições).
  static double raioDe(GrafoNo no, int nTotal, ConfigGrafo config) {
    final mult = config.multiplicadorTamanho / 1.7;

    // Tags & Entidades não devem crescer descontroladamente
    if (no.noTipo == NoTipo.tag) {
      final r = (3.0 + 0.8 * math.log(1.0 + no.grau)) * mult;
      return r.clamp(2.5, 6.0);
    }
    if (no.noTipo == NoTipo.entidade) {
      final r = (3.2 + 1.0 * math.log(1.0 + no.grau)) * mult;
      return r.clamp(2.5, 6.5);
    }
    if (no.noTipo == NoTipo.naoResolvido) {
      return (2.5 * mult).clamp(2.0, 4.5);
    }

    // Para notas: escala logarítmica elegante no padrão estelar do Obsidian
    final grauLog = math.log(1.0 + no.grau);
    final prFactor = math.sqrt((no.pagerank * nTotal).clamp(0.5, 12.0));
    final base = 2.4 + 1.1 * grauLog + 0.7 * prFactor;
    final r = base * mult;
    return r.clamp(2.2, 12.5);
  }

  /// Paleta de clusters moderna, vibrante e harmoniosa.
  static const paletaCluster = <Color>[
    Color(0xFF38BDF8),
    Color(0xFF818CF8),
    Color(0xFF34D399),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
    Color(0xFFA78BFA),
    Color(0xFFFB7185),
    Color(0xFF2DD4BF),
    Color(0xFF60A5FA),
    Color(0xFFF97316),
    Color(0xFF94A3B8),
  ];
}

class ResultadoGrafo {
  const ResultadoGrafo({
    required this.grafo,
    required this.metricas,
    required this.truncado,
    required this.totalOriginal,
  });

  final Grafo grafo;
  final ResultadoMetricas metricas;

  /// `true` quando o grafo foi cortado pelo teto de [GrafoBuilder.maxNos].
  final bool truncado;
  final int totalOriginal;
}
