import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/cerebro/data/models/aresta.dart';
import 'package:vitta_app/features/cerebro/data/models/nota.dart';
import 'package:vitta_app/features/cerebro/data/models/nota_enums.dart';
import 'package:vitta_app/features/cerebro/index/parser/parser_vfm.dart';
import 'package:vitta_app/features/cerebro/index/vault_index.dart';

/// Os 20 casos-limite normativos do parser VFM
/// (`.specify/obsidian/obsidian.md` §6.3).
///
/// A integridade de todo o grafo depende deste arquivo: um erro aqui vira
/// aresta fantasma ou aresta perdida em milhares de notas.
void main() {
  const parser = ParserVFM();

  List<Aresta> wikilinks(String texto) => parser
      .parse(texto)
      .arestas
      .where((a) => a.tipo == LinkTipo.wiki || a.tipo == LinkTipo.embed)
      .toList();

  group('§6.3 · casos-limite do tokenizer', () {
    test('1 · duas ocorrências do mesmo link viram uma aresta com peso 2', () {
      final links = wikilinks('[[a]] e de novo [[a]]');
      expect(links, hasLength(1));
      expect(links.first.peso, 2.0);
    });

    test('2 · só o primeiro pipe separa o alias', () {
      final links = wikilinks('[[a|b|c]]');
      expect(links.first.para, 'a');
      expect(links.first.alias, 'b|c');
    });

    test('3 · [[]] não gera aresta', () {
      expect(wikilinks('texto [[]] fim'), isEmpty);
    });

    test('4 · espaços em volta do alvo são removidos', () {
      expect(wikilinks('[[  a  ]]').first.para, 'a');
    });

    test('5 · link dentro de código inline é literal', () {
      expect(wikilinks('use `[[a]]` assim'), isEmpty);
    });

    test('6 · link dentro de bloco cercado é literal', () {
      expect(wikilinks('```\n[[a]]\n```'), isEmpty);
    });

    test('7 · fragmento de URL não vira tag', () {
      expect(parser.parse('veja https://x.com/p#frag aqui').tags, isEmpty);
    });

    test('8 · # seguido de dígito não vira tag', () {
      expect(parser.parse('item #1 e #123').tags, isEmpty);
    });

    test('9 · tag hierárquica gera o prefixo e a tag completa', () {
      final tags = parser.parse('#pai/filho').tags;
      expect(tags, containsAll(['pai', 'pai/filho']));
    });

    test('10 · alvo, âncora e alias são separados corretamente', () {
      final l = wikilinks('[[nota#sec|texto]]').first;
      expect(l.para, 'nota');
      expect(l.ancora, 'sec');
      expect(l.alias, 'texto');
    });

    test('11 · embed de bloco é reconhecido como embed', () {
      final l = wikilinks('![[nota#^bloco]]').first;
      expect(l.tipo, LinkTipo.embed);
      expect(l.para, 'nota');
      expect(l.bloco, 'bloco');
    });

    test('12 · entity-link não é wikilink', () {
      final ast = parser.parse('paciente [[@paciente:pac_1]]');
      expect(wikilinks('paciente [[@paciente:pac_1]]'), isEmpty);
      expect(ast.entidades, hasLength(1));
      expect(ast.entidades.first.tipo, EntidadeTipo.paciente);
      expect(ast.entidades.first.id, 'pac_1');
    });

    test('13 · tipo de entidade desconhecido cai para wikilink comum', () {
      final l = wikilinks('[[@invalido:x]]');
      expect(l, hasLength(1));
      expect(l.first.para, '@invalido:x');
    });

    test('14 · link dentro de callout é contado normalmente', () {
      expect(wikilinks('> [!risco] Aviso\n> impacto em [[a]]'), hasLength(1));
    });

    test('15 · aliases do frontmatter entram no AST', () {
      final ast = parser.parse('---\naliases: [x, y]\n---\n\n# T');
      expect(ast.aliases, ['x', 'y']);
      expect(ast.titulo, 'T');
    });

    test('16 · self-link não entra no grafo', () {
      final index = VaultIndex();
      final nota = _nota('nt_1', 'a.md', '# A\n\nvolta para [[A]]');
      index.indexar(nota, parser.parse(nota.conteudo));
      // Reindexa: agora o alias "A" já existe e resolveria para ela mesma.
      index.indexar(index.porId('nt_1')!, parser.parse(nota.conteudo));
      expect(index.linksDe('nt_1').where((a) => a.para == 'nt_1'), isEmpty);
    });

    test('17 · alvo com dois donos é ambíguo', () {
      final index = VaultIndex();
      final a = _nota('nt_1', 'p1/a.md', '# Alvo');
      final b = _nota('nt_2', 'p2/b.md', '---\naliases: [Alvo]\n---\n\n# B');
      index.indexar(a, parser.parse(a.conteudo));
      index.indexar(b, parser.parse(b.conteudo));
      expect(index.resolver('Alvo').estado, LinkEstado.ambiguo);
      expect(index.resolver('Alvo').candidatos, hasLength(2));
    });

    test('18 · texto grande sem links é parseado sem estourar', () {
      final grande = List.filled(20000, 'palavra').join(' ');
      final ast = parser.parse(grande);
      expect(ast.arestas, isEmpty);
      expect(ast.wordCount, 20000);
    });

    test('19 · âncora de bloco é registrada e some do texto plano', () {
      final ast = parser.parse('uma frase importante ^resumo-q1\n');
      expect(ast.blocos.containsKey('^resumo-q1'), isTrue);
      expect(ast.textoPlano, isNot(contains('^resumo-q1')));
    });

    test('20 · acento e caixa não impedem a resolução', () {
      final index = VaultIndex();
      final alvo = _nota('nt_1', 'mocs/absenteismo.md', '# Absenteísmo — MOC');
      index.indexar(alvo, parser.parse(alvo.conteudo));
      expect(index.resolver('ABSENTEISMO — MOC').estado, LinkEstado.resolvido);
      expect(index.resolver('absenteismo').notaId, 'nt_1');
    });
  });

  group('índice · backlinks e reconciliação', () {
    test('link quebrado é religado quando a nota alvo passa a existir', () {
      final index = VaultIndex();
      final origem = _nota('nt_1', 'a.md', '# A\n\nvê [[Protocolo X]]');
      index.indexar(origem, parser.parse(origem.conteudo));

      expect(index.linksDe('nt_1').first.ehNaoResolvido, isTrue);
      expect(index.linksQuebrados, hasLength(1));

      final alvo = _nota('nt_2', 'protocolos/x.md', '# Protocolo X');
      index.indexar(alvo, parser.parse(alvo.conteudo));

      expect(index.linksQuebrados, isEmpty);
      expect(index.backlinks('nt_2').map((a) => a.de), contains('nt_1'));
    });

    test('backlink carrega o trecho de contexto para preview', () {
      final index = VaultIndex();
      final alvo = _nota('nt_2', 'b.md', '# Alvo');
      final origem = _nota(
          'nt_1', 'a.md', '# A\n\nimpacto direto sobre [[Alvo]] em março.');
      index.indexar(alvo, parser.parse(alvo.conteudo));
      index.indexar(origem, parser.parse(origem.conteudo));

      final back = index.backlinks('nt_2');
      expect(back, hasLength(1));
      expect(back.first.contexto, contains('impacto direto'));
    });

    test('remover a nota devolve os links dela ao estado quebrado', () {
      final index = VaultIndex();
      final alvo = _nota('nt_2', 'b.md', '# Alvo');
      final origem = _nota('nt_1', 'a.md', '# A\n\n[[Alvo]]');
      index.indexar(alvo, parser.parse(alvo.conteudo));
      index.indexar(origem, parser.parse(origem.conteudo));
      expect(index.backlinks('nt_2'), hasLength(1));

      index.remover('nt_2');
      expect(index.porId('nt_2'), isNull);
      expect(index.linksDe('nt_1').first.ehNaoResolvido, isTrue);
    });

    test('órfã é detectada e deixa de ser órfã ao ganhar link', () {
      final index = VaultIndex();
      final sozinha = _nota('nt_1', 'sozinha.md', '# Sozinha');
      index.indexar(sozinha, parser.parse(sozinha.conteudo));
      index.atualizarGraus();
      expect(index.orfas.map((n) => n.id), ['nt_1']);

      final outra = _nota('nt_2', 'outra.md', '# Outra\n\n[[Sozinha]]');
      index.indexar(outra, parser.parse(outra.conteudo));
      index.atualizarGraus();
      expect(index.orfas, isEmpty);
    });
  });

  group('§14.2 · o parser não materializa PII', () {
    test('entity-link de paciente não expõe nome no texto plano', () {
      final ast = parser.parse('faltou [[@paciente:pac_812]] de novo');
      expect(ast.textoPlano, contains('Paciente'));
      expect(ast.textoPlano, isNot(contains('pac_812')));
    });
  });
}

Nota _nota(String id, String path, String conteudo) => Nota(
      id: id,
      clinicaId: 'cl_test',
      path: path,
      titulo: '',
      conteudo: conteudo,
    );
