import 'package:vitta_app/features/cerebro/data/models/nota.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_builder.dart';
import 'package:vitta_app/features/cerebro/index/busca_service.dart';
import 'package:vitta_app/features/cerebro/index/parser/parser_vfm.dart';
import 'package:vitta_app/features/cerebro/index/vault_index.dart';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/cerebro/agent/politica_escrita.dart';
import 'package:vitta_app/features/cerebro/data/models/nota_enums.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_engine.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_metricas.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_modelo.dart';
import 'package:vitta_app/features/cerebro/graph/grafo_painter.dart';
import 'package:vitta_app/features/cerebro/graph/quadtree.dart';

void main() {
  group('§7.2 · Barnes-Hut', () {
    test('aproximação bate com a força bruta dentro da tolerância', () {
      // 200 corpos determinísticos.
      final n = 200;
      final px = Float32List(n);
      final py = Float32List(n);
      for (var i = 0; i < n; i++) {
        final a = i * 2.399963229728653;
        final r = 12.0 * math.sqrt(i + 0.5);
        px[i] = r * math.cos(a);
        py[i] = r * math.sin(a);
      }

      const k = -280.0;
      final arvore = Quadtree.construir(px, py, n);

      var erroRelativoMax = 0.0;
      for (var i = 0; i < n; i += 17) {
        // Força exata.
        var exFx = 0.0, exFy = 0.0;
        for (var j = 0; j < n; j++) {
          if (i == j) continue;
          final dx = px[i] - px[j];
          final dy = py[i] - py[j];
          final d2 = dx * dx + dy * dy;
          if (d2 < 1e-9) continue;
          final d = math.sqrt(d2);
          final f = k / d2;
          exFx += f * dx / d;
          exFy += f * dy / d;
        }

        var apFx = 0.0, apFy = 0.0;
        arvore.repulsao(i, px[i], py[i], k, 0.5, (fx, fy) {
          apFx += fx;
          apFy += fy;
        });

        final magEx = math.sqrt(exFx * exFx + exFy * exFy);
        if (magEx < 1e-6) continue;
        final erro = math.sqrt(
                (apFx - exFx) * (apFx - exFx) + (apFy - exFy) * (apFy - exFy)) /
            magEx;
        if (erro > erroRelativoMax) erroRelativoMax = erro;
      }

      expect(erroRelativoMax, lessThan(0.20));
    });

    test('consulta por região devolve só os corpos dentro do retângulo', () {
      final px = Float32List.fromList([0, 100, -100, 5]);
      final py = Float32List.fromList([0, 100, -100, 5]);
      final arvore = Quadtree.construir(px, py, 4);
      final dentro = <int>[];
      arvore.consultar(-10, -10, 10, 10, dentro.add);
      expect(dentro..sort(), [0, 3]);
    });
  });

  group('§7.6 · métricas do grafo', () {
    test('PageRank soma ~1 e o hub tem o maior valor', () {
      // Estrela: 1..4 apontam para 0.
      final grafo = _grafo(5, [(1, 0), (2, 0), (3, 0), (4, 0)]);
      final pr = GrafoMetricas.pagerank(grafo);
      final soma = pr.reduce((a, b) => a + b);
      expect(soma, closeTo(1.0, 1e-6));
      for (var i = 1; i < 5; i++) {
        expect(pr[0], greaterThan(pr[i]));
      }
    });

    test('Louvain separa dois blocos densos', () {
      // Dois triângulos ligados por uma única ponte.
      final grafo = _grafo(6, [
        (0, 1), (1, 2), (2, 0),
        (3, 4), (4, 5), (5, 3),
        (2, 3),
      ]);
      final c = GrafoMetricas.louvain(grafo);
      expect(c[0], equals(c[1]));
      expect(c[1], equals(c[2]));
      expect(c[3], equals(c[4]));
      expect(c[4], equals(c[5]));
      expect(c[0], isNot(equals(c[3])));
    });

    test('Louvain é determinístico entre execuções', () {
      final arestas = [(0, 1), (1, 2), (2, 0), (3, 4), (4, 5), (5, 3), (2, 3)];
      final a = GrafoMetricas.louvain(_grafo(6, arestas));
      final b = GrafoMetricas.louvain(_grafo(6, arestas));
      expect(a, equals(b));
    });

    test('componentes: o maior recebe o rótulo 0', () {
      final grafo = _grafo(5, [(0, 1), (1, 2), (3, 4)]);
      final comps = GrafoMetricas.componentes(grafo);
      expect(comps[0], 0);
      expect(comps[1], 0);
      expect(comps[2], 0);
      expect(comps[3], 1);
      expect(comps[4], 1);
    });

    test('caminho mínimo atravessa a ponte', () {
      final grafo = _grafo(5, [(0, 1), (1, 2), (2, 3), (3, 4)]);
      expect(GrafoMetricas.caminhoMinimo(grafo, 0, 4), [0, 1, 2, 3, 4]);
      expect(GrafoMetricas.caminhoMinimo(grafo, 0, 0), [0]);
    });

    test('caminho mínimo devolve null quando não há conexão', () {
      final grafo = _grafo(4, [(0, 1), (2, 3)]);
      expect(GrafoMetricas.caminhoMinimo(grafo, 0, 3), isNull);
    });

    test('grafo sem arestas não quebra as métricas', () {
      final grafo = _grafo(3, const []);
      final r = GrafoMetricas.calcular(grafo);
      expect(r.densidade, 0);
      expect(r.nComponentes, 3);
    });
  });

  group('§7.2 · simulação', () {
    test('converge e congela', () {
      final grafo = _grafo(40, [
        for (var i = 1; i < 40; i++) (i, i ~/ 2),
      ]);
      final engine = GrafoEngine(grafo);
      var passos = 0;
      while (engine.tick() && passos < 4000) {
        passos++;
      }
      expect(engine.congelado, isTrue);
      expect(passos, lessThan(4000));
      // Nenhuma posição virou NaN/infinita.
      for (var i = 0; i < engine.n; i++) {
        expect(engine.px[i].isFinite, isTrue);
        expect(engine.py[i].isFinite, isTrue);
      }
      engine.dispose();
    });

    test('nó travado não se move', () {
      final grafo = _grafo(10, [for (var i = 1; i < 10; i++) (i, 0)]);
      final engine = GrafoEngine(grafo);
      engine.travar(0, 42, -17);
      for (var i = 0; i < 60; i++) {
        engine.tick();
      }
      expect(engine.px[0], 42);
      expect(engine.py[0], -17);
      engine.dispose();
    });

    test('semeadura é determinística', () {
      final a = GrafoEngine(_grafo(20, const []));
      final b = GrafoEngine(_grafo(20, const []));
      for (var i = 0; i < 20; i++) {
        expect(a.px[i], b.px[i]);
        expect(a.py[i], b.py[i]);
      }
      a.dispose();
      b.dispose();
    });
  });

  group('§9.3 · política de escrita do agente', () {
    const politica = PoliticaEscrita();

    VeredictoEscrita avaliar({
      String path = 'agente/analises/x.md',
      String conteudo = 'Análise ligando [[mocs/absenteismo]].',
      double confianca = 0.9,
      String motivo = 'Registrar o padrão detectado hoje.',
      List<String> nomes = const [],
    }) =>
        politica.avaliar(
          path: path,
          conteudo: conteudo,
          confianca: confianca,
          motivo: motivo,
          nomesDePacientes: nomes,
        );

    test('guarda 1 · bloqueia escrita fora do namespace do agente', () {
      final v = avaliar(path: 'protocolos/confirmacao-48h.md');
      expect(v.permitido, isFalse);
      expect(v.motivo, contains('agente/'));
    });

    test('guarda 1 · permite agente/, padroes/ e diario/', () {
      for (final p in ['agente/x.md', 'padroes/y.md', 'diario/2026-08-19.md']) {
        expect(avaliar(path: p).permitido, isTrue, reason: p);
      }
    });

    test('guarda 2 · confiança < 0.60 é recusada', () {
      expect(avaliar(confianca: 0.4).permitido, isFalse);
    });

    test('guarda 2 · 0.60 ≤ confiança < 0.85 entra como rascunho', () {
      final v = avaliar(confianca: 0.71);
      expect(v.permitido, isTrue);
      expect(v.estado, NotaEstado.rascunho);
    });

    test('guarda 2 · confiança ≥ 0.85 publica', () {
      expect(avaliar(confianca: 0.9).estado, NotaEstado.publicada);
    });

    test('guarda 3 · CPF no corpo bloqueia a escrita', () {
      final v = avaliar(conteudo: 'O paciente 123.456.789-00 faltou.');
      expect(v.permitido, isFalse);
      expect(v.padraoDetectado, 'CPF');
      // O valor detectado nunca aparece na mensagem (§15.1).
      expect(v.motivo, isNot(contains('123.456.789')));
    });

    test('guarda 3 · telefone e e-mail também bloqueiam', () {
      expect(avaliar(conteudo: 'ligar (11) 98888-7777').permitido, isFalse);
      expect(avaliar(conteudo: 'ana@exemplo.com.br faltou').permitido, isFalse);
    });

    test('guarda 3 · nome completo de paciente conhecido bloqueia', () {
      final v = avaliar(
        conteudo: 'Maria Aparecida Silva faltou três vezes.',
        nomes: ['Maria Aparecida Silva'],
      );
      expect(v.permitido, isFalse);
      expect(v.padraoDetectado, 'nome de paciente');
    });

    test('guarda 3 · entity-link é a forma aceita de citar paciente', () {
      final v = avaliar(
        conteudo: '[[@paciente:pac_812]] faltou três vezes.',
        nomes: ['Maria Aparecida Silva'],
      );
      expect(v.permitido, isTrue);
    });

    test('guarda 5 · motivo vazio é recusado (auditoria)', () {
      expect(avaliar(motivo: 'ok').permitido, isFalse);
    });
  });

  group('§14.2 · RedatorPii.sanitizar', () {
    test('remove PII antes de gerar embeddings', () {
      final limpo = RedatorPii.sanitizar(
        'Maria Aparecida Silva (CPF 123.456.789-00), tel (11) 98888-7777, '
        'ver [[@paciente:pac_1]].',
        nomesDePacientes: ['Maria Aparecida Silva'],
      );
      expect(limpo, isNot(contains('123.456.789')));
      expect(limpo, isNot(contains('Maria Aparecida Silva')));
      expect(limpo, isNot(contains('pac_1')));
      expect(limpo, contains('(paciente)'));
    });

    test('mantém nome de médico (não é PII de paciente)', () {
      final limpo = RedatorPii.sanitizar('[[@medico:med_44|Dra. Helena]] atendeu.');
      expect(limpo, contains('Dra. Helena'));
    });
  });

  group('§7.4 · Rótulos e Configuração do Grafo', () {
    test('ConfigGrafo padrão inicia com mostrarRotulos e mostrarRotulosClusters desativados', () {
      const config = ConfigGrafo();
      expect(config.mostrarRotulos, isFalse);
      expect(config.mostrarRotulosClusters, isFalse);
    });

    test('ConfigGrafo serializa e desserializa mostrarRotulos e tamanhoRotulo', () {
      const config = ConfigGrafo(
        mostrarRotulos: true,
        mostrarRotulosClusters: true,
        rotulosAuto: false,
        tamanhoRotulo: 1.5,
      );
      final map = config.toMap();
      expect(map['mostrarRotulos'], isTrue);
      expect(map['mostrarRotulosClusters'], isTrue);
      expect(map['rotulosAuto'], isFalse);
      expect(map['tamanhoRotulo'], 1.5);

      final recuperado = ConfigGrafo.fromMap(map);
      expect(recuperado.mostrarRotulos, isTrue);
      expect(recuperado.mostrarRotulosClusters, isTrue);
      expect(recuperado.rotulosAuto, isFalse);
      expect(recuperado.tamanhoRotulo, 1.5);
    });

    test('LabelCache constrói e reutiliza parágrafos de texto', () {
      final cache = LabelCache(capacidade: 10);
      final p1 = cache.obter('Nota Principal', 11.0, const Color(0xFFFFFFFF));
      expect(p1.width, greaterThan(0));

      // Mesma chave deve retornar o parágrafo cacheado
      final p2 = cache.obter('Nota Principal', 11.0, const Color(0xFFFFFFFF));
      expect(identical(p1, p2), isTrue);

      // Chave diferente cria novo parágrafo
      final p3 = cache.obter('Outra Nota', 11.0, const Color(0xFFFFFFFF));
      expect(identical(p1, p3), isFalse);

      cache.limpar();
    });
  });


  group('§10.5.2 · Legenda Interativa e Filtros do Grafo', () {
    test('ConfigGrafo serializa e desserializa conjuntos de desativação e calcula getters', () {
      const config = ConfigGrafo(
        tiposDesativados: {'diario', 'protocolo'},
        entidadesDesativadas: {'paciente'},
        clustersDesativados: {1, 3},
        mostrarTags: false,
      );
      expect(config.temFiltrosLegendaAtivos, isTrue);
      expect(config.totalFiltrosLegendaAtivos, 6);

      final map = config.toMap();
      expect(map['tiposDesativados'], containsAll(['diario', 'protocolo']));
      expect(map['entidadesDesativadas'], contains('paciente'));
      expect(map['clustersDesativados'], containsAll([1, 3]));

      final recuperado = ConfigGrafo.fromMap(map);
      expect(recuperado.tiposDesativados, equals({'diario', 'protocolo'}));
      expect(recuperado.entidadesDesativadas, equals({'paciente'}));
      expect(recuperado.clustersDesativados, equals({1, 3}));
      expect(recuperado.temFiltrosLegendaAtivos, isTrue);
    });

    test('GrafoBuilder filtra notas por tiposDesativados', () {
      const parser = ParserVFM();
      final index = VaultIndex();
      final n1 = Nota(
        id: 'n1',
        clinicaId: 'c1',
        path: 'n1.md',
        titulo: 'Nota 1',
        tipo: NotaTipo.protocolo,
        conteudo: 'corpo',
      );
      final n2 = Nota(
        id: 'n2',
        clinicaId: 'c1',
        path: 'n2.md',
        titulo: 'Nota 2',
        tipo: NotaTipo.diario,
        conteudo: 'corpo',
      );
      index.indexar(n1, parser.parse(n1.conteudo));
      index.indexar(n2, parser.parse(n2.conteudo));

      final builder = GrafoBuilder(index, BuscaService(index));

      // Sem filtro: ambas aparecem
      final r1 = builder.construir(config: const ConfigGrafo());
      expect(r1.grafo.n, 2);

      // Com filtro para desativar protocolo
      final r2 = builder.construir(
        config: const ConfigGrafo(tiposDesativados: {'protocolo'}),
      );
      expect(r2.grafo.n, 1);
      expect(r2.grafo.nos.first.id, 'n2');
    });

    test('GrafoBuilder filtra entidades operacionais por entidadesDesativadas', () {
      const parser = ParserVFM();
      final index = VaultIndex();
      final n1 = Nota(
        id: 'n1',
        clinicaId: 'c1',
        path: 'n1.md',
        titulo: 'Nota 1',
        conteudo: 'Tratando [[@paciente:pac_1]] e [[@medico:med_1]]',
      );
      index.indexar(n1, parser.parse(n1.conteudo));

      final builder = GrafoBuilder(index, BuscaService(index));

      // Sem filtro: 1 nota + 2 entidades = 3 nós
      final r1 = builder.construir(config: const ConfigGrafo(mostrarEntidades: true));
      expect(r1.grafo.n, 3);

      // Desativando entidades paciente
      final r2 = builder.construir(
        config: const ConfigGrafo(
          mostrarEntidades: true,
          entidadesDesativadas: {'paciente'},
        ),
      );
      expect(r2.grafo.n, 2);
      expect(r2.grafo.nos.any((n) => n.id == '@paciente:pac_1'), isFalse);
      expect(r2.grafo.nos.any((n) => n.id == '@medico:med_1'), isTrue);
    });
  });
}

/// Monta um grafo sintético com [n] nós e as arestas informadas.
Grafo _grafo(int n, List<(int, int)> arestas) {
  final nos = [
    for (var i = 0; i < n; i++)
      GrafoNo(id: 'n', rotulo: 'Nó ', noTipo: NoTipo.nota),
  ];
  final es = [
    for (final (de, para) in arestas)
      GrafoAresta(de: de, para: para, tipo: LinkTipo.wiki),
  ];
  final g = Grafo(nos, es);
  // Preenche graus para o raio/rigidez.
  for (final a in es) {
    nos[a.de].outDegree++;
    nos[a.para].inDegree++;
  }
  return g;
}
