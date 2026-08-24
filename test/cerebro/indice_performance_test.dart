import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/cerebro/data/models/nota.dart';
import 'package:vitta_app/features/cerebro/data/vault_demo.dart';
import 'package:vitta_app/features/cerebro/index/busca_service.dart';
import 'package:vitta_app/features/cerebro/index/parser/parser_vfm.dart';
import 'package:vitta_app/features/cerebro/index/vault_index.dart';

// Abrir o Cérebro com um vault grande levava ~75 s de indexação. Três causas,
// todas O(N²) ou pior:
//
//  1. `resolver()` varria `notas.values` para achar um path — O(notas) por
//     link, ~68 milhões de comparações num vault de 3.000 notas.
//  2. desindexar uma nota varria `alias`/`tags`/`pastas` inteiros atrás do id.
//  3. o boot fazia duas passadas completas, reparseando tudo na segunda.
//
// E a busca renormalizava (lowercase + sem acento) o corpo de TODAS as notas a
// cada tecla digitada.
//
// Estes testes prendem as estruturas que sustentam as correções. Os limites de
// tempo são folgados de propósito: servem para pegar volta ao comportamento
// quadrático, não para medir a máquina.
void main() {
  const parser = ParserVFM();

  VaultIndex indexar(List<Nota> notas) {
    final index = VaultIndex();
    index.indexarLote(notas, [for (final n in notas) parser.parse(n.conteudo)]);
    return index;
  }

  group('correção do índice', () {
    test('lote produz o mesmo grafo que indexar uma a uma', () {
      final notas = VaultDemo.gerar('c', alvo: 300);
      final asts = [for (final n in notas) parser.parse(n.conteudo)];

      final umAUm = VaultIndex();
      for (var i = 0; i < notas.length; i++) {
        umAUm.indexar(notas[i], asts[i]);
      }
      for (final n in notas) {
        final atual = umAUm.porId(n.id);
        if (atual != null) umAUm.indexar(atual, parser.parse(atual.conteudo));
      }
      umAUm.atualizarGraus();

      final lote = indexar(notas);

      expect(lote.totalNotas, umAUm.totalNotas);
      expect(lote.totalArestas, umAUm.totalArestas);
      expect(lote.linksQuebrados.length, umAUm.linksQuebrados.length);
      expect(lote.orfas.length, umAUm.orfas.length);
      expect(lote.tags.length, umAUm.tags.length);
    });

    test('índice de path resolve e acompanha renomeação', () {
      final index = VaultIndex();
      final a = Nota(
        id: 'nt_a',
        clinicaId: 'c',
        path: 'protocolos/confirmacao.md',
        titulo: 'Confirmação',
        conteudo: '# Confirmação',
      );
      index.indexar(a, parser.parse(a.conteudo));

      expect(index.porPath('protocolos/confirmacao.md')?.id, 'nt_a');
      expect(
        index.resolver('protocolos/confirmacao').notaId,
        'nt_a',
        reason: 'link por path exato precisa resolver pelo índice',
      );

      // Move a nota: o path antigo não pode continuar respondendo.
      final movida = a.copyWith(path: 'arquivo/confirmacao.md');
      index.indexar(movida, parser.parse(movida.conteudo));

      expect(index.porPath('arquivo/confirmacao.md')?.id, 'nt_a');
      expect(index.porPath('protocolos/confirmacao.md'), isNull);
    });

    test('desindexar limpa alias, tags e pasta da nota', () {
      final index = VaultIndex();
      final n = Nota(
        id: 'nt_a',
        clinicaId: 'c',
        path: 'conceitos/risco.md',
        titulo: 'Risco',
        conteudo: '---\ntags: [clinica/risco]\n---\n# Risco',
      );
      index.indexar(n, parser.parse(n.conteudo));
      expect(index.tags.keys, contains('clinica/risco'));

      index.remover('nt_a');

      expect(index.totalNotas, 0);
      expect(index.tags.values.any((ids) => ids.contains('nt_a')), isFalse);
      expect(index.alias.values.any((ids) => ids.contains('nt_a')), isFalse);
      expect(index.pastas.values.any((ids) => ids.contains('nt_a')), isFalse);
      expect(index.porPath('conceitos/risco.md'), isNull);
    });
  });

  group('cache de derivados', () {
    // orfas/linksQuebrados/totalArestas passaram a ser memoizados. Cache velho
    // seria pior que lentidão: a status bar mentiria sobre o vault.
    test('invalida ao indexar, ao remover e ao limpar', () {
      final index = VaultIndex();
      expect(index.totalArestas, 0);
      expect(index.orfas, isEmpty);

      final solta = Nota(
        id: 'nt_a',
        clinicaId: 'c',
        path: 'a.md',
        titulo: 'A',
        conteudo: '# A\n\nsem links',
      );
      index.indexar(solta, parser.parse(solta.conteudo));
      expect(index.orfas.map((n) => n.id), ['nt_a'],
          reason: 'nota sem entrada nem saída é órfã');

      // Uma segunda nota apontando para a primeira desfaz as duas orfandades.
      final liga = Nota(
        id: 'nt_b',
        clinicaId: 'c',
        path: 'b.md',
        titulo: 'B',
        conteudo: '# B\n\nver [[A]]',
      );
      index.indexar(liga, parser.parse(liga.conteudo));
      expect(index.totalArestas, 1, reason: 'cache de arestas ficou velho');
      expect(index.orfas, isEmpty, reason: 'cache de órfãs ficou velho');

      index.remover('nt_b');
      expect(index.orfas.map((n) => n.id), ['nt_a'],
          reason: 'remover precisa invalidar o cache');

      index.limpar();
      expect(index.totalArestas, 0);
      expect(index.orfas, isEmpty);
      expect(index.linksQuebrados, isEmpty);
    });

    test('link quebrado aparece e some conforme o alvo existe', () {
      final index = VaultIndex();
      final orfaDeLink = Nota(
        id: 'nt_a',
        clinicaId: 'c',
        path: 'a.md',
        titulo: 'A',
        conteudo: '# A\n\nver [[Inexistente]]',
      );
      index.indexar(orfaDeLink, parser.parse(orfaDeLink.conteudo));
      expect(index.linksQuebrados.keys, contains('inexistente'));

      final alvo = Nota(
        id: 'nt_b',
        clinicaId: 'c',
        path: 'inexistente.md',
        titulo: 'Inexistente',
        conteudo: '# Inexistente',
      );
      index.indexar(alvo, parser.parse(alvo.conteudo));
      expect(index.linksQuebrados, isEmpty,
          reason: 'reconciliação precisa invalidar o cache');
    });
  });

  group('escala', () {
    test('indexação cresce perto do linear, não do quadrático', () {
      // 4× as notas não pode custar muito mais que ~4× o tempo. Na versão
      // quadrática esta razão passava de 20.
      final pequeno = VaultDemo.gerar('c', alvo: 300);
      final grande = VaultDemo.gerar('c', alvo: 1200);

      final tP = Stopwatch()..start();
      indexar(pequeno);
      tP.stop();

      final tG = Stopwatch()..start();
      indexar(grande);
      tG.stop();

      final razaoNotas = grande.length / pequeno.length;
      final razaoTempo = (tG.elapsedMicroseconds + 1) / (tP.elapsedMicroseconds + 1);

      expect(razaoTempo, lessThan(razaoNotas * 3),
          reason: 'tempo cresceu ${razaoTempo.toStringAsFixed(1)}× para '
              '${razaoNotas.toStringAsFixed(1)}× notas — cheira a O(N²)');
    });

    test('buscar não renormaliza o vault a cada consulta', () {
      final index = indexar(VaultDemo.gerar('c', alvo: 1200));
      final busca = BuscaService(index);

      // A primeira consulta paga o mesmo que as seguintes: o texto normalizado
      // já foi calculado na indexação, não é lazy por consulta.
      final t = Stopwatch()..start();
      for (final q in ['risco', 'protocolo', 'confirmacao', 'falta', 'agenda']) {
        busca.buscar(q);
      }
      t.stop();

      expect(t.elapsedMilliseconds, lessThan(1500),
          reason: '5 consultas levaram ${t.elapsedMilliseconds} ms');
    });

    test('texto normalizado some junto com a nota', () {
      final index = VaultIndex();
      final n = Nota(
        id: 'nt_a',
        clinicaId: 'c',
        path: 'a.md',
        titulo: 'Ação Clínica',
        conteudo: '# Ação Clínica',
      );
      index.indexar(n, parser.parse(n.conteudo));
      expect(index.textoBusca('nt_a').titulo, 'acao clinica',
          reason: 'deve estar minúsculo e sem acento');

      index.remover('nt_a');
      expect(index.textoBusca('nt_a').titulo, '');
    });
  });
}
