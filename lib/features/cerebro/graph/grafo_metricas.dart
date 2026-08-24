import 'dart:math' as math;
import 'dart:typed_data';

import 'grafo_modelo.dart';

/// Métricas estruturais do grafo (`obsidian.md` §7.6).
///
/// PageRank define o **tamanho** do nó; Louvain define a **cor** quando não há
/// grupo manual; componentes conexos alimentam o painel de Ilhas.
class GrafoMetricas {
  GrafoMetricas._();

  /// Calcula tudo de uma vez e escreve nos nós. Determinístico — nenhuma
  /// fonte de aleatoriedade — para que as cores não dancem entre sessões
  /// (mitigação R11 de §19).
  static ResultadoMetricas calcular(Grafo grafo) {
    final graus = _graus(grafo);
    final pr = pagerank(grafo);
    final clusters = louvain(grafo);
    final comps = componentes(grafo);

    for (var i = 0; i < grafo.n; i++) {
      final no = grafo.nos[i];
      no.inDegree = graus.entrada[i];
      no.outDegree = graus.saida[i];
      no.pagerank = pr[i];
      no.cluster = clusters[i];
    }

    return ResultadoMetricas(
      pagerank: pr,
      clusters: clusters,
      componentes: comps,
      nComponentes: comps.isEmpty ? 0 : (comps.reduce(math.max) + 1),
      densidade: grafo.n < 2
          ? 0
          : 2 * grafo.arestas.length / (grafo.n * (grafo.n - 1)),
    );
  }

  // ── PageRank ──────────────────────────────────────────────────────────────

  /// PageRank ponderado, damping 0,85, até 40 iterações ou Δ < 1e-6.
  static Float64List pagerank(
    Grafo grafo, {
    double damping = 0.85,
    int maxIter = 40,
    double tolerancia = 1e-6,
  }) {
    final n = grafo.n;
    final pr = Float64List(n);
    if (n == 0) return pr;

    final inicial = 1.0 / n;
    for (var i = 0; i < n; i++) {
      pr[i] = inicial;
    }

    // Soma de pesos de saída por nó.
    final somaSaida = Float64List(n);
    for (final a in grafo.arestas) {
      somaSaida[a.de] += a.peso * a.tipo.pesoBase;
    }

    final proximo = Float64List(n);
    for (var iter = 0; iter < maxIter; iter++) {
      var massaSumidouro = 0.0;
      for (var i = 0; i < n; i++) {
        proximo[i] = 0;
        if (somaSaida[i] == 0) massaSumidouro += pr[i];
      }

      for (final a in grafo.arestas) {
        final peso = a.peso * a.tipo.pesoBase;
        if (somaSaida[a.de] == 0) continue;
        proximo[a.para] += pr[a.de] * peso / somaSaida[a.de];
      }

      final base = (1 - damping) / n + damping * massaSumidouro / n;
      var delta = 0.0;
      for (var i = 0; i < n; i++) {
        final v = base + damping * proximo[i];
        delta += (v - pr[i]).abs();
        proximo[i] = v;
      }
      pr.setAll(0, proximo);
      if (delta < tolerancia) break;
    }
    return pr;
  }

  // ── Louvain ───────────────────────────────────────────────────────────────

  /// Detecção de comunidades por modularidade (uma fase de refinamento local
  /// seguida de contração, repetida até estabilizar).
  ///
  /// Trabalha sobre a versão **não-dirigida** do grafo. Determinístico: os nós
  /// são varridos em ordem de índice, sem embaralhamento.
  static Int32List louvain(Grafo grafo, {double resolucao = 1.0}) {
    final n = grafo.n;
    final comunidade = Int32List(n);
    for (var i = 0; i < n; i++) {
      comunidade[i] = i;
    }
    if (n == 0 || grafo.arestas.isEmpty) return comunidade;

    // Lista de adjacência não-dirigida com pesos agregados.
    final adj = List<Map<int, double>>.generate(n, (_) => <int, double>{});
    var m2 = 0.0; // 2m — soma de todos os pesos, contada duas vezes
    for (final a in grafo.arestas) {
      if (a.de == a.para) continue;
      final p = a.peso;
      adj[a.de].update(a.para, (v) => v + p, ifAbsent: () => p);
      adj[a.para].update(a.de, (v) => v + p, ifAbsent: () => p);
      m2 += 2 * p;
    }
    if (m2 == 0) return comunidade;

    final grau = Float64List(n);
    for (var i = 0; i < n; i++) {
      for (final p in adj[i].values) {
        grau[i] += p;
      }
    }

    final somaTot = Float64List(n);
    for (var i = 0; i < n; i++) {
      somaTot[i] = grau[i];
    }

    var melhorou = true;
    var rodadas = 0;
    while (melhorou && rodadas < 12) {
      melhorou = false;
      rodadas++;
      for (var i = 0; i < n; i++) {
        final cAtual = comunidade[i];
        somaTot[cAtual] -= grau[i];

        // Peso de i para cada comunidade vizinha.
        final pesoPara = <int, double>{};
        adj[i].forEach((j, p) {
          pesoPara.update(comunidade[j], (v) => v + p, ifAbsent: () => p);
        });

        var melhorC = cAtual;
        var melhorGanho = (pesoPara[cAtual] ?? 0) -
            resolucao * somaTot[cAtual] * grau[i] / m2;

        pesoPara.forEach((c, peso) {
          if (c == cAtual) return;
          final ganho = peso - resolucao * somaTot[c] * grau[i] / m2;
          // Desempate determinístico pelo menor índice de comunidade.
          if (ganho > melhorGanho + 1e-12 ||
              (ganho > melhorGanho - 1e-12 && c < melhorC)) {
            melhorGanho = ganho;
            melhorC = c;
          }
        });

        somaTot[melhorC] += grau[i];
        if (melhorC != cAtual) {
          comunidade[i] = melhorC;
          melhorou = true;
        }
      }
    }

    return _compactar(comunidade);
  }

  // ── Componentes conexos ───────────────────────────────────────────────────

  /// Rótulo de componente conexo por nó (union-find). Componente 0 é o maior.
  static Int32List componentes(Grafo grafo) {
    final n = grafo.n;
    final pai = Int32List(n);
    for (var i = 0; i < n; i++) {
      pai[i] = i;
    }

    int achar(int x) {
      var r = x;
      while (pai[r] != r) {
        r = pai[r];
      }
      // Compressão de caminho.
      var c = x;
      while (pai[c] != r) {
        final prox = pai[c];
        pai[c] = r;
        c = prox;
      }
      return r;
    }

    for (final a in grafo.arestas) {
      final ra = achar(a.de);
      final rb = achar(a.para);
      if (ra != rb) pai[ra] = rb;
    }

    final raiz = Int32List(n);
    for (var i = 0; i < n; i++) {
      raiz[i] = achar(i);
    }

    // Ordena os componentes por tamanho (o maior vira 0).
    final tamanho = <int, int>{};
    for (var i = 0; i < n; i++) {
      tamanho.update(raiz[i], (v) => v + 1, ifAbsent: () => 1);
    }
    final ordenados = tamanho.keys.toList()
      ..sort((a, b) {
        final c = tamanho[b]!.compareTo(tamanho[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    final rotulo = {for (var i = 0; i < ordenados.length; i++) ordenados[i]: i};

    final out = Int32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = rotulo[raiz[i]]!;
    }
    return out;
  }

  // ── Caminho mínimo ────────────────────────────────────────────────────────

  /// Menor caminho entre dois nós (BFS bidirecional) — base da tool
  /// `cerebro_caminho` (§9.2). Devolve a sequência de índices ou `null`.
  static List<int>? caminhoMinimo(Grafo grafo, int de, int para,
      {int maxSaltos = 6}) {
    if (de == para) return [de];
    final n = grafo.n;
    if (de < 0 || para < 0 || de >= n || para >= n) return null;

    final adj = List<Set<int>>.generate(n, (_) => <int>{});
    for (final a in grafo.arestas) {
      adj[a.de].add(a.para);
      adj[a.para].add(a.de);
    }

    final anterior = List<int?>.filled(n, null);
    final visitado = List<bool>.filled(n, false);
    final fila = <int>[de];
    final profundidade = List<int>.filled(n, 0);
    visitado[de] = true;

    var i = 0;
    while (i < fila.length) {
      final atual = fila[i++];
      if (profundidade[atual] >= maxSaltos) continue;
      for (final v in adj[atual]) {
        if (visitado[v]) continue;
        visitado[v] = true;
        anterior[v] = atual;
        profundidade[v] = profundidade[atual] + 1;
        if (v == para) {
          final caminho = <int>[para];
          int? c = anterior[para];
          while (c != null) {
            caminho.add(c);
            c = anterior[c];
          }
          return caminho.reversed.toList();
        }
        fila.add(v);
      }
    }
    return null;
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  static ({Int32List entrada, Int32List saida}) _graus(Grafo grafo) {
    final entrada = Int32List(grafo.n);
    final saida = Int32List(grafo.n);
    for (final a in grafo.arestas) {
      saida[a.de]++;
      entrada[a.para]++;
    }
    return (entrada: entrada, saida: saida);
  }

  /// Renumera comunidades para 0..k-1, mantendo a ordem de primeira aparição
  /// (estabilidade visual entre execuções).
  static Int32List _compactar(Int32List rotulos) {
    final mapa = <int, int>{};
    final out = Int32List(rotulos.length);
    for (var i = 0; i < rotulos.length; i++) {
      out[i] = mapa.putIfAbsent(rotulos[i], () => mapa.length);
    }
    return out;
  }
}

class ResultadoMetricas {
  const ResultadoMetricas({
    required this.pagerank,
    required this.clusters,
    required this.componentes,
    required this.nComponentes,
    required this.densidade,
  });

  final Float64List pagerank;
  final Int32List clusters;
  final Int32List componentes;
  final int nComponentes;
  final double densidade;

  int get nClusters {
    var maior = -1;
    for (final c in clusters) {
      if (c > maior) maior = c;
    }
    return maior + 1;
  }
}
