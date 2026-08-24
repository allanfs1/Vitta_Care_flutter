import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/cerebro/data/vault_demo.dart';
import 'package:vitta_app/features/cerebro/data/models/nota_enums.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_builder.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_engine.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_modelo.dart';
import 'package:vitta_app/features/cerebro/index/busca_service.dart';
import 'package:vitta_app/features/cerebro/index/parser/parser_vfm.dart';
import 'package:vitta_app/features/cerebro/index/vault_index.dart';

/// Carga sintética sob os orçamentos de performance de `obsidian.md` §13.1.
///
/// Não é só "não explodiu": cada tamanho de vault é medido nas quatro etapas
/// do caminho crítico (parse → índice → grafo → busca) e verificado nas
/// propriedades estruturais que a interface depende para ficar legível.
void main() {
  const parser = ParserVFM();

  /// Roda o pipeline completo e devolve as medições.
  _Medicao medir(int alvo) {
    final notas = VaultDemo.gerar('cl_bench', alvo: alvo, seed: 7);

    final tParse = Stopwatch()..start();
    final asts = [for (final n in notas) parser.parse(n.conteudo)];
    tParse.stop();

    final index = VaultIndex();
    final tIndice = Stopwatch()..start();
    for (var i = 0; i < notas.length; i++) {
      index.indexar(notas[i], asts[i]);
    }
    // 2ª passada: resolve links cujos alvos só existiam depois (igual ao boot).
    for (final n in index.notas.values.toList()) {
      index.indexar(n, parser.parse(n.conteudo));
    }
    index.atualizarGraus();
    tIndice.stop();

    final busca = BuscaService(index);

    final tGrafo = Stopwatch()..start();
    final resultado = GrafoBuilder(index, busca).construir(
      config: const ConfigGrafo(),
      escopo: const GrafoEscopo.global(),
    );
    tGrafo.stop();

    final tBusca = Stopwatch()..start();
    final achados = busca.buscar('absenteismo confirmacao');
    tBusca.stop();

    final tBacklinks = Stopwatch()..start();
    var totalBacklinks = 0;
    for (final n in index.notas.values) {
      totalBacklinks += index.backlinks(n.id).length;
    }
    tBacklinks.stop();

    return _Medicao(
      alvo: alvo,
      notas: index.totalNotas,
      arestas: index.totalArestas,
      grafo: resultado,
      orfas: index.orfas.length,
      quebrados: index.linksQuebrados.length,
      tags: index.tags.length,
      resultadosBusca: achados.length,
      totalBacklinks: totalBacklinks,
      msParse: tParse.elapsedMilliseconds,
      msIndice: tIndice.elapsedMilliseconds,
      msGrafo: tGrafo.elapsedMilliseconds,
      msBusca: tBusca.elapsedMilliseconds,
      msBacklinks: tBacklinks.elapsedMilliseconds,
    );
  }

  group('carga sintética · §13.1', () {
    for (final alvo in [300, 1200, 3000]) {
      test('vault de ~$alvo notas', () {
        final m = medir(alvo);
        // ignore: avoid_print
        print(m);

        // ── Volume ──────────────────────────────────────────────────────────
        expect(m.notas, greaterThan((alvo * 0.85).round()));
        expect(m.arestas, greaterThan(m.notas)); // densidade > 1

        // ── Orçamentos (§13.1, com folga de CI) ─────────────────────────────
        expect(m.msIndice, lessThan(alvo * 6),
            reason: 'indexação ${m.msIndice} ms para ${m.notas} notas');
        expect(m.msGrafo, lessThan(6000),
            reason: 'montagem do grafo ${m.msGrafo} ms');
        expect(m.msBusca, lessThan(1500),
            reason: 'busca textual ${m.msBusca} ms');
        expect(m.msBacklinks, lessThan(1000),
            reason: 'varredura de backlinks ${m.msBacklinks} ms');

        // ── Propriedades estruturais que a UI depende ───────────────────────
        expect(m.densidade, greaterThan(2.0),
            reason: 'vault sem densidade vira depósito, não cérebro (R4)');
        expect(m.orfas, greaterThan(0), reason: 'órfãs propositais para a UI');
        expect(m.quebrados, greaterThan(0),
            reason: 'links quebrados propositais para a UI');
        expect(m.tags, greaterThan(10));
        expect(m.resultadosBusca, greaterThan(0));

        // ── O grafo precisa ter forma, não ser uma malha uniforme ───────────
        final g = m.grafo.grafo;
        final maiorGrau =
            g.nos.map((n) => n.grau).reduce((a, b) => a > b ? a : b);
        final grauMedio =
            g.nos.fold<int>(0, (s, n) => s + n.grau) / g.n;
        expect(maiorGrau, greaterThan(grauMedio * 8),
            reason: 'sem hubs o grafo não exercita LOD nem PageRank');
        expect(m.grafo.metricas.nClusters, greaterThan(1),
            reason: 'Louvain precisa encontrar comunidades');

        // ── Entidades operacionais entraram no grafo ────────────────────────
        final entidades =
            g.nos.where((n) => n.noTipo == NoTipo.entidade).length;
        expect(entidades, greaterThan(0));
      });
    }

    test('simulação estabiliza no vault de 1.200 notas', () {
      final m = medir(1200);
      final engine = GrafoEngine(m.grafo.grafo);

      final relogio = Stopwatch()..start();
      var passos = 0;
      while (engine.tick() && passos < 3000) {
        passos++;
      }
      relogio.stop();
      // ignore: avoid_print
      print('  simulação: $passos ticks em ${relogio.elapsedMilliseconds} ms '
          '(${(relogio.elapsedMilliseconds / passos).toStringAsFixed(2)} ms/tick) '
          'para ${m.grafo.grafo.n} nós');

      expect(engine.congelado, isTrue, reason: 'não convergiu em 3000 ticks');
      for (var i = 0; i < engine.n; i++) {
        expect(engine.px[i].isFinite, isTrue);
        expect(engine.py[i].isFinite, isTrue);
      }
      engine.dispose();
    });

    test('geração é determinística com a mesma seed', () {
      final a = VaultDemo.gerar('cl_x', alvo: 300, seed: 7);
      final b = VaultDemo.gerar('cl_x', alvo: 300, seed: 7);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].path, b[i].path);
        expect(a[i].conteudo, b[i].conteudo);
      }
    });

    test('vault de demo respeita a regra de PII (§14.2)', () {
      // Nenhuma nota gerada pode carregar CPF, telefone ou e-mail no corpo —
      // pacientes só aparecem como entity-link.
      final notas = VaultDemo.gerar('cl_x', alvo: 1200, seed: 7);
      final cpf = RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b');
      final tel = RegExp(r'\(\d{2}\)\s?9?\d{4}-?\d{4}');
      final email = RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]{2,}\b');
      for (final n in notas) {
        expect(cpf.hasMatch(n.conteudo), isFalse, reason: n.path);
        expect(tel.hasMatch(n.conteudo), isFalse, reason: n.path);
        expect(email.hasMatch(n.conteudo), isFalse, reason: n.path);
      }
    });

    test('filtro do grafo recorta o vault', () {
      final notas = VaultDemo.gerar('cl_f', alvo: 600, seed: 7);
      final index = VaultIndex();
      for (final n in notas) {
        index.indexar(n, parser.parse(n.conteudo));
      }
      for (final n in index.notas.values.toList()) {
        index.indexar(n, parser.parse(n.conteudo));
      }
      index.atualizarGraus();

      final busca = BuscaService(index);
      final builder = GrafoBuilder(index, busca);

      final total = builder.construir(config: const ConfigGrafo()).grafo.n;
      final soDiario = builder
          .construir(config: const ConfigGrafo(filtro: 'tipo:diario'))
          .grafo
          .nos
          .where((n) => n.noTipo == NoTipo.nota)
          .length;

      expect(soDiario, greaterThan(0));
      expect(soDiario, lessThan(total));

      final soAgente = busca.buscar('origem:agente', limite: 100000);
      expect(soAgente, isNotEmpty);
      expect(soAgente.every((r) => r.nota.origem == NotaOrigem.agente), isTrue);
    });
  });
}

class _Medicao {
  const _Medicao({
    required this.alvo,
    required this.notas,
    required this.arestas,
    required this.grafo,
    required this.orfas,
    required this.quebrados,
    required this.tags,
    required this.resultadosBusca,
    required this.totalBacklinks,
    required this.msParse,
    required this.msIndice,
    required this.msGrafo,
    required this.msBusca,
    required this.msBacklinks,
  });

  final int alvo;
  final int notas;
  final int arestas;
  final ResultadoGrafo grafo;
  final int orfas;
  final int quebrados;
  final int tags;
  final int resultadosBusca;
  final int totalBacklinks;
  final int msParse;
  final int msIndice;
  final int msGrafo;
  final int msBusca;
  final int msBacklinks;

  double get densidade => notas == 0 ? 0 : arestas / notas;

  @override
  String toString() => '''
  ┌─ vault ~$alvo ────────────────────────────────────────────
  │ notas             $notas
  │ arestas           $arestas   (densidade ${densidade.toStringAsFixed(2)})
  │ nós no grafo      ${grafo.grafo.n}   (arestas ${grafo.grafo.arestas.length})
  │ componentes       ${grafo.metricas.nComponentes}   clusters ${grafo.metricas.nClusters}
  │ órfãs             $orfas    quebrados $quebrados    tags $tags
  │ backlinks totais  $totalBacklinks
  ├─ tempos ─────────────────────────────────────────────────
  │ parse             $msParse ms
  │ índice (2 passes) $msIndice ms
  │ montagem grafo    $msGrafo ms   (PageRank + Louvain inclusos)
  │ busca textual     $msBusca ms   ($resultadosBusca resultados)
  │ backlinks (todos) $msBacklinks ms
  └───────────────────────────────────────────────────────────''';
}
