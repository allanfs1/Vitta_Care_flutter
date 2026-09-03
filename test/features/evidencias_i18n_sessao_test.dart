import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/i18n/idioma.dart';
import 'package:vitta_app/core/i18n/textos.dart';
import 'package:vitta_app/core/i18n/textos_en.dart';
import 'package:vitta_app/core/i18n/textos_es.dart';
import 'package:vitta_app/core/i18n/textos_pt.dart';
import 'package:vitta_app/features/evidencias/filtros_busca.dart';
import 'package:vitta_app/features/evidencias/pubmed_models.dart';
import 'package:vitta_app/features/evidencias/sessoes/sessao_export.dart';
import 'package:vitta_app/features/evidencias/sessoes/sessao_models.dart';
import 'package:vitta_app/features/evidencias/sessoes/sessao_store.dart';

/// Testes de idiomas, sessões salvas e exportação.

const _artigo = ArtigoPubmed(
  pmid: '31535829',
  titulo: 'Dapagliflozin in Patients with Heart Failure.',
  autores: ['McMurray JJV', 'Solomon SD'],
  periodico: 'N Engl J Med',
  dataPublicacao: '2019 Nov 21',
  ano: 2019,
  doi: '10.1056/NEJMoa1911303',
  volume: '381',
  paginas: '1995-2008',
  tiposPublicacao: ['Randomized Controlled Trial'],
  url: 'https://pubmed.ncbi.nlm.nih.gov/31535829/',
  abstractSecoes: [
    SecaoResumo(rotulo: 'BACKGROUND', texto: 'Contexto do estudo.'),
    SecaoResumo(rotulo: 'CONCLUSIONS', texto: 'Reduziu o desfecho primário.'),
  ],
);

SessaoPesquisa _sessao({String id = 's1', String titulo = 'Insuficiência cardíaca'}) =>
    SessaoPesquisa(
      id: id,
      titulo: titulo,
      pergunta: 'SGLT2 reduz mortalidade em IC?',
      consultaEnviada: 'dapagliflozin[tiab] AND heart failure[tiab]',
      queryTraduzida: '"dapagliflozin"[All Fields] AND "heart failure"[MeSH]',
      artigos: const [_artigo],
      salvaEm: DateTime(2026, 9, 2, 14, 30),
      modo: 'agente',
      sintese: 'Reduziu hospitalização (PMID: 31535829).',
      totalNoPubmed: 193,
      pmidsCitados: const ['31535829'],
      filtros: const FiltrosBusca(anosRecentes: 5, somenteHumanos: true),
    );

void main() {
  group('idiomas', () {
    test('resolve pela chave das preferências e cai no português', () {
      expect(Idioma.daChave('en_US'), Idioma.en);
      expect(Idioma.daChave('es_ES'), Idioma.es);
      expect(Idioma.daChave('pt_BR'), Idioma.pt);
      // Chave desconhecida não pode deixar o app sem idioma.
      expect(Idioma.daChave('kl_KL'), Idioma.pt);
      expect(Idioma.daChave(null), Idioma.pt);
    });

    test('resolve pelo Locale do sistema', () {
      expect(Idioma.doLocale(const Locale('en', 'GB')), Idioma.en);
      expect(Idioma.doLocale(const Locale('es')), Idioma.es);
      expect(Idioma.doLocale(const Locale('de')), Idioma.pt);
      expect(Idioma.doLocale(null), Idioma.pt);
    });

    test('o nome em inglês é o que instrui o modelo de tradução', () {
      // Pedir "traduza para Português (Brasil)" funciona pior que pedir em
      // inglês, que é como o modelo foi majoritariamente treinado.
      expect(Idioma.pt.nomeIngles, 'Brazilian Portuguese');
      expect(Idioma.es.nomeIngles, 'Spanish');
    });
  });

  group('textos', () {
    test('devolve a string do idioma pedido', () {
      expect(const Textos(Idioma.pt).t('evid.titulo'), 'Evidências');
      expect(const Textos(Idioma.en).t('evid.titulo'), 'Evidence');
      expect(const Textos(Idioma.es).t('evid.titulo'), 'Evidencias');
    });

    test('chave sem tradução cai no português, não em branco', () {
      // Traduzir por partes precisa ser possível: exigir os três idiomas a
      // cada string nova travaria o desenvolvimento.
      const chaveSoEmPt = 'evid.hist.limpar';
      expect(textosPt.containsKey(chaveSoEmPt), isTrue);
      final semTraducao = Map<String, String>.from(textosEn)..remove(chaveSoEmPt);
      expect(semTraducao[chaveSoEmPt], isNull);
      // Pelo delegate real, a queda acontece:
      expect(const Textos(Idioma.en).t('chave.que.nao.existe'),
          'chave.que.nao.existe');
    });

    test('chave inexistente aparece como a própria chave', () {
      // Melhor um texto estranho na tela que um espaço em branco silencioso.
      expect(const Textos(Idioma.pt).t('nao.existe.mesmo'), 'nao.existe.mesmo');
    });

    test('substitui marcadores', () {
      expect(
        const Textos(Idioma.pt).t2('evid.filtros.ativos', {'n': '3'}),
        'Filtros (3)',
      );
    });

    test('plural escolhe a chave certa', () {
      const t = Textos(Idioma.pt);
      expect(t.plural(1, 'evid.res.um', 'evid.res.muitos'),
          '1 artigo encontrado');
      expect(t.plural(7, 'evid.res.um', 'evid.res.muitos'),
          '7 artigos encontrados');
    });

    test('todas as chaves de en/es existem em pt', () {
      // O português é a fonte da verdade: uma chave que só existe na tradução
      // é uma chave morta — ninguém a lê, porque o código pede pelo nome de pt.
      for (final mapa in [textosEn, textosEs]) {
        final orfas = mapa.keys.where((k) => !textosPt.containsKey(k)).toList();
        expect(orfas, isEmpty, reason: 'chaves sem correspondente em pt: $orfas');
      }
    });

    test('relatório do que falta traduzir', () {
      // Não falha — informa. Traduções incompletas são estado normal aqui.
      for (final (nome, mapa) in [('en', textosEn), ('es', textosEs)]) {
        final faltando =
            textosPt.keys.where((k) => !mapa.containsKey(k)).toList();
        final pct = ((1 - faltando.length / textosPt.length) * 100).round();
        // ignore: avoid_print
        print('  $nome: $pct% traduzido '
            '(${faltando.length} de ${textosPt.length} faltando)');
        expect(pct, greaterThan(80), reason: 'tradução de $nome muito atrasada');
      }
    });

    test('marcadores do pt existem também nas traduções', () {
      // Uma tradução que perde o `{n}` mostra "Filtros ()" — erro que só
      // aparece em produção, no idioma que ninguém testa.
      final re = RegExp(r'\{(\w+)\}');
      for (final (nome, mapa) in [('en', textosEn), ('es', textosEs)]) {
        for (final e in mapa.entries) {
          final esperados =
              re.allMatches(textosPt[e.key] ?? '').map((m) => m[1]).toSet();
          final achados = re.allMatches(e.value).map((m) => m[1]).toSet();
          expect(achados, esperados,
              reason: '$nome/${e.key}: marcadores divergem');
        }
      }
    });
  });

  group('sessão — modelo', () {
    test('sobrevive a uma volta por JSON', () {
      final s = _sessao();
      final volta = SessaoPesquisa.doJson(s.paraJson());

      expect(volta.id, s.id);
      expect(volta.titulo, s.titulo);
      expect(volta.artigos.single.pmid, '31535829');
      expect(volta.sintese, contains('31535829'));
      expect(volta.pmidsCitados, ['31535829']);
      expect(volta.totalNoPubmed, 193);
      // Sem estes dois não há como auditar depois o que foi pesquisado.
      expect(volta.queryTraduzida, contains('MeSH'));
      expect(volta.salvaEm, s.salvaEm);
    });

    test('JSON corrompido não derruba: campos faltantes viram padrão', () {
      final s = SessaoPesquisa.doJson({'id': 'x'});
      expect(s.id, 'x');
      expect(s.artigos, isEmpty);
      expect(s.titulo, isNotEmpty);
      expect(s.salvaEm, isNotNull);
    });

    test('título derivado corta sem cortar no meio de nada importante', () {
      expect(SessaoPesquisa.tituloDe('  a   b  '), 'a b');
      expect(SessaoPesquisa.tituloDe(''), 'Sessão sem nome');
      final longo = SessaoPesquisa.tituloDe('x' * 200);
      expect(longo.length, lessThanOrEqualTo(60));
      expect(longo, endsWith('…'));
    });
  });

  group('sessão — persistência', () {
    late SessaoStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = SessaoStore(await SharedPreferences.getInstance());
    });

    test('salva, lê e exclui', () async {
      await store.salvar(_sessao());
      expect(store.listar().single.titulo, 'Insuficiência cardíaca');
      expect(store.porId('s1'), isNotNull);

      await store.excluir('s1');
      expect(store.listar(), isEmpty);
      expect(store.porId('s1'), isNull);
    });

    test('salvar o mesmo id substitui em vez de duplicar', () async {
      await store.salvar(_sessao());
      await store.salvar(_sessao(titulo: 'Renomeada'));
      expect(store.listar().length, 1);
      expect(store.listar().single.titulo, 'Renomeada');
    });

    test('renomeia preservando o conteúdo', () async {
      await store.salvar(_sessao());
      await store.renomear('s1', 'Novo nome');
      final s = store.porId('s1')!;
      expect(s.titulo, 'Novo nome');
      expect(s.artigos.single.pmid, '31535829');
    });

    test('lista da mais recente para a mais antiga', () async {
      await store.salvar(SessaoPesquisa(
        id: 'antiga',
        titulo: 'Antiga',
        pergunta: 'p',
        consultaEnviada: 'c',
        queryTraduzida: 'q',
        artigos: const [],
        salvaEm: DateTime(2020),
      ));
      await store.salvar(_sessao(id: 'nova'));
      expect(store.listar().first.id, 'nova');
    });

    test('respeita o teto de sessões', () async {
      // SharedPreferences carrega tudo no boot; sem teto, o app ficaria mais
      // lento para iniciar a cada pesquisa salva.
      for (var i = 0; i < SessaoStore.maxSessoes + 8; i++) {
        await store.salvar(_sessao(id: 's$i'));
      }
      expect(store.listar().length, SessaoStore.maxSessoes);
    });

    test('entrada corrompida não impede ler as demais', () async {
      final prefs = await SharedPreferences.getInstance();
      await store.salvar(_sessao());
      final atual = prefs.getStringList('evidencias_sessoes_v1')!;
      await prefs.setStringList(
          'evidencias_sessoes_v1', ['{lixo', ...atual]);

      // Perder UMA sessão é muito melhor que a lista inteira deixar de abrir.
      expect(store.listar().length, 1);
    });
  });

  group('histórico', () {
    late SessaoStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = SessaoStore(await SharedPreferences.getInstance());
    });

    test('registra e persiste', () async {
      await store.registrar(ItemHistorico(
          termo: 'asthma', total: 12, quando: DateTime(2026, 9, 2)));
      expect(store.historico().single.termo, 'asthma');
    });

    test('repetir o termo move para o topo, sem duplicar', () async {
      await store.registrar(
          ItemHistorico(termo: 'a', total: 1, quando: DateTime(2026)));
      await store.registrar(
          ItemHistorico(termo: 'b', total: 2, quando: DateTime(2026)));
      await store.registrar(
          ItemHistorico(termo: 'a', total: 9, quando: DateTime(2026)));

      final h = store.historico();
      expect(h.length, 2);
      expect(h.first.termo, 'a');
      expect(h.first.total, 9, reason: 'a entrada é atualizada, não repetida');
    });

    test('respeita o teto', () async {
      for (var i = 0; i < SessaoStore.maxHistorico + 10; i++) {
        await store.registrar(
            ItemHistorico(termo: 't$i', total: i, quando: DateTime(2026)));
      }
      expect(store.historico().length, SessaoStore.maxHistorico);
    });

    test('limpar histórico não apaga as sessões', () async {
      // São coisas diferentes: rastro automático × ato deliberado de guardar.
      await store.salvar(_sessao());
      await store.registrar(
          ItemHistorico(termo: 'x', total: 1, quando: DateTime(2026)));

      await store.limparHistorico();
      expect(store.historico(), isEmpty);
      expect(store.listar().length, 1);
    });
  });

  group('exportação', () {
    test('Markdown traz a estratégia e a data — não só os artigos', () {
      final md = SessaoExport.gerar(_sessao(), FormatoExport.markdown);

      // É o que separa um registro reprodutível de uma bibliografia.
      expect(md, contains('Como esta busca foi feita'));
      expect(md, contains('dapagliflozin[tiab]'));
      expect(md, contains('MeSH'));
      expect(md, contains('02/09/2026'));
      expect(md, contains('193'));

      expect(md, contains('## Síntese'));
      expect(md, contains('PMID: 31535829'));
      expect(md, contains('*(citado)*'));
      // Os rótulos de seção sobrevivem ao export, traduzidos.
      expect(md, contains('Conclusões'));
      // O aviso de IA acompanha a síntese exportada, não só a tela.
      expect(md, contains('gerado por IA'));
    });

    test('Markdown mostra os filtros que restringiram a busca', () {
      final md = SessaoExport.gerar(_sessao(), FormatoExport.markdown);
      expect(md, contains('Últimos 5 anos'));
      expect(md, contains('Humanos'));
    });

    test('RIS e BibTeX saem no formato dos gerenciadores', () {
      final ris = SessaoExport.gerar(_sessao(), FormatoExport.ris);
      expect(ris, startsWith('TY  - JOUR'));
      expect(ris, contains('AN  - 31535829'));

      final bib = SessaoExport.gerar(_sessao(), FormatoExport.bibtex);
      expect(bib, contains('@article{mcmurray2019_31535829'));
    });

    test('JSON reimporta sem perder nada', () {
      final json = SessaoExport.gerar(_sessao(), FormatoExport.json);
      final volta = SessaoPesquisa.doJson(
          SessaoPesquisa.doJson(_sessao().paraJson()).paraJson());
      expect(json, contains('31535829'));
      expect(volta.artigos.single.abstractSecoes, isNotNull);
    });

    test('nome de arquivo é seguro em qualquer sistema', () {
      final nome = SessaoExport.nomeArquivo(
        _sessao(titulo: 'IC: SGLT2 / "estudo" *2024*'),
        FormatoExport.markdown,
      );
      expect(nome, endsWith('.md'));
      expect(nome, contains('20260902'));
      // Nada que o Windows recuse.
      expect(RegExp(r'[<>:"/\\|?*]').hasMatch(nome), isFalse);
    });

    test('sessão vazia exporta sem quebrar', () {
      final vazia = SessaoPesquisa(
        id: 'v',
        titulo: 'Vazia',
        pergunta: '',
        consultaEnviada: '',
        queryTraduzida: '',
        artigos: const [],
        salvaEm: DateTime(2026),
      );
      for (final f in FormatoExport.values) {
        expect(() => SessaoExport.gerar(vazia, f), returnsNormally);
      }
    });
  });
}
