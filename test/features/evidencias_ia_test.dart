import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vitta_app/core/services/auth_service.dart';
import 'package:vitta_app/features/evidencias/efetch_xml.dart';
import 'package:vitta_app/features/evidencias/filtros_busca.dart';
import 'package:vitta_app/features/evidencias/ia/pico.dart';
import 'package:vitta_app/features/evidencias/phi_guard.dart';
import 'package:vitta_app/features/evidencias/pubmed_direct.dart';
import 'package:vitta_app/features/evidencias/pubmed_models.dart';
import 'package:vitta_app/features/evidencias/pubmed_service.dart';
import 'package:vitta_app/features/evidencias/widgets/formatos_citacao.dart';

/// Testes das peças acrescentadas ao módulo de Evidências: fallback direto,
/// guarda de PHI no cliente, leitor de XML, filtros, PICO e citação.

class _FakeAuth implements AuthService {
  @override
  Future<String?> idToken() async => 'tok';
  @override
  bool get isFirebaseEnabled => true;
  @override
  String? get currentEmail => 'medico@clinica.com';
  @override
  String? get currentUid => 'uid';
  @override
  Stream<String?> authStateChanges() => const Stream.empty();
  @override
  Future<AuthResult> signIn({required String email, required String password}) async =>
      const AuthResult.success('x');
  @override
  Future<AuthResult> register({required String email, required String password}) async =>
      const AuthResult.success('x');
  @override
  Future<AuthResult> signInWithGoogle() async => const AuthResult.success('x');
  @override
  Future<AuthResult> sendPasswordReset(String email) async =>
      const AuthResult.success('x');
  @override
  Future<void> signOut() async {}
}

/// Cliente que roteia por host: o proxy responde uma coisa, o NCBI outra.
/// É assim que se prova o fallback sem depender de rede.
http.Client _roteador({
  required int statusProxy,
  Object corpoProxy = const {},
  Object? corpoNcbi,
  List<Uri>? registro,
}) {
  return MockClient((req) async {
    registro?.add(req.url);
    if (req.url.host.contains('eutils')) {
      return http.Response(
        corpoNcbi is String ? corpoNcbi : jsonEncode(corpoNcbi ?? {}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      corpoProxy is String ? corpoProxy : jsonEncode(corpoProxy),
      statusProxy,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

const _respostaNcbi = {
  'esearchresult': {
    'count': '42',
    'retstart': '0',
    'idlist': ['31452104', '31556701'],
    'querytranslation': '"asthma"[MeSH Terms]',
  },
};

void main() {
  group('guarda de PHI no cliente', () {
    // Espelha `functions/lib/pubmed.js`. Os dois lados são travados contra os
    // mesmos casos de propósito: se um mudar, o outro tem que mudar junto.
    test('bloqueia CPF, CNS, e-mail e telefone', () {
      expect(detectarPhi('paciente 123.456.789-01'), contains('CPF'));
      expect(detectarPhi('diabetes 12345678901'), contains('CPF'));
      expect(detectarPhi('cns 123456789012345'),
          contains('Cartão Nacional de Saúde'));
      expect(detectarPhi('maria@clinica.com'), contains('e-mail'));
      expect(detectarPhi('ligar (11) 98765-4321'), contains('telefone'));
    });

    test('NÃO bloqueia consulta clínica legítima', () {
      // O teste que impede a guarda de virar estorvo.
      expect(detectarPhi('diabetes type 2[tiab] AND 2022:2026[pdat]'), isEmpty);
      expect(detectarPhi('metformin 850 mg AND adults 40-65'), isEmpty);
      expect(detectarPhi('31452104'), isEmpty);
      expect(detectarPhi('SGLT2 inhibitor[tiab] NOT animals[mesh]'), isEmpty);
    });

    test('caminho direto recusa antes de qualquer rede', () async {
      final chamadas = <Uri>[];
      final pm = PubmedDirect(
        client: _roteador(statusProxy: 200, registro: chamadas),
      );
      await expectLater(
        pm.buscar('paciente CPF 123.456.789-01'),
        throwsA(isA<EvidenciaErro>().having(
            (e) => e.bloqueadoPorDadoPessoal, 'PHI', isTrue)),
      );
      expect(chamadas, isEmpty);
    });
  });

  group('fallback proxy → direto', () {
    test('proxy 404 cai para o NCBI e a busca funciona', () async {
      final chamadas = <Uri>[];
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _roteador(
          statusProxy: 404,
          corpoProxy: 'não encontrado',
          corpoNcbi: _respostaNcbi,
          registro: chamadas,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
        direto: PubmedDirect(
          client: _roteador(statusProxy: 404, corpoNcbi: _respostaNcbi),
        ),
      );

      final r = await svc.buscar('asthma');
      expect(r.total, 42);
      expect(r.pmids, ['31452104', '31556701']);
      expect(r.viaProxy, isFalse, reason: 'a tela precisa saber a origem');
      expect(svc.usandoFallback, isTrue);
      expect(svc.ultimoCaminho, CaminhoEvidencia.direto);
      expect(svc.motivoFallback, contains('não está publicada'));
    });

    test('depois de cair, não tenta o proxy de novo na mesma sessão', () async {
      final chamadas = <Uri>[];
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _roteador(
          statusProxy: 404,
          corpoNcbi: _respostaNcbi,
          registro: chamadas,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
        direto: PubmedDirect(
          client: _roteador(
            statusProxy: 404,
            corpoNcbi: _respostaNcbi,
            registro: chamadas,
          ),
        ),
      );

      await svc.buscar('asthma');
      await svc.buscar('diabetes');

      // Sem esta memória, CADA busca pagaria o timeout do proxy antes de
      // funcionar — e a tela pareceria travada a cada pesquisa.
      final aoProxy = chamadas.where((u) => u.host == 'exemplo').length;
      expect(aoProxy, 1);
    });

    test('reavaliarProxy faz tentar de novo', () async {
      final chamadas = <Uri>[];
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _roteador(
          statusProxy: 404,
          corpoNcbi: _respostaNcbi,
          registro: chamadas,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
        direto: PubmedDirect(
            client: _roteador(statusProxy: 404, corpoNcbi: _respostaNcbi)),
      );

      await svc.buscar('asthma');
      svc.reavaliarProxy();
      await svc.buscar('asthma');

      expect(chamadas.where((u) => u.host == 'exemplo').length, 2);
    });

    test('proxy publicado SEM configuração (503) também cai para o direto',
        () async {
      // Sem isto, publicar a function sem NCBI_TOOL/NCBI_EMAIL deixava a tela
      // PIOR do que antes do deploy: morria num 503 em vez de degradar.
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _roteador(
          statusProxy: 503,
          corpoProxy: {
            'error': 'Conector NCBI não configurado',
            'codigo': 'NOT_CONFIGURED',
          },
          corpoNcbi: _respostaNcbi,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
        direto: PubmedDirect(
            client: _roteador(statusProxy: 503, corpoNcbi: _respostaNcbi)),
      );

      final r = await svc.buscar('asthma');
      expect(r.total, 42, reason: 'a busca precisa funcionar mesmo assim');
      expect(svc.usandoFallback, isTrue);
      expect(svc.motivoFallback, contains('NCBI_TOOL'));
    });

    test('o motivo do fallback identifica a causa', () async {
      for (final (status, codigo, esperado) in [
        (404, 'NOT_DEPLOYED', 'não está publicada'),
        (503, 'NOT_CONFIGURED', 'NCBI_TOOL'),
      ]) {
        final svc = PubmedService(
          auth: _FakeAuth(),
          client: _roteador(
            statusProxy: status,
            corpoProxy: {'error': 'x', 'codigo': codigo},
            corpoNcbi: _respostaNcbi,
          ),
          proxyUrl: 'https://exemplo/pubmedProxy',
          direto: PubmedDirect(
              client: _roteador(statusProxy: status, corpoNcbi: _respostaNcbi)),
        );
        await svc.buscar('asthma');
        expect(svc.motivoFallback, contains(esperado));
      }
    });

    test('PHI bloqueado pelo servidor NÃO cai para o direto', () async {
      // O ponto de segurança do fallback: se o servidor recusou por dado
      // pessoal, repetir pelo caminho direto contornaria a guarda.
      final chamadas = <Uri>[];
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _roteador(
          statusProxy: 400,
          corpoProxy: {'error': 'contém CPF', 'codigo': 'PHI_BLOCKED'},
          corpoNcbi: _respostaNcbi,
          registro: chamadas,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
      );

      await expectLater(
        svc.buscar('asthma'),
        throwsA(isA<EvidenciaErro>()
            .having((e) => e.bloqueadoPorDadoPessoal, 'PHI', isTrue)),
      );
      expect(chamadas.any((u) => u.host.contains('eutils')), isFalse);
      expect(svc.usandoFallback, isFalse);
    });

    test('consulta inválida também não cai para o direto', () async {
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _roteador(
          statusProxy: 400,
          corpoProxy: {'error': 'campo inválido', 'codigo': 'INVALID_QUERY'},
          corpoNcbi: _respostaNcbi,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
      );
      await expectLater(
        svc.buscar('x[campoinexistente]'),
        throwsA(isA<EvidenciaErro>()
            .having((e) => e.consultaInvalida, 'INVALID_QUERY', isTrue)),
      );
    });
  });

  group('leitor de EFetch XML', () {
    test('separa por artigo e preserva rótulos', () {
      const xml = '''
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation><PMID Version="1">111</PMID></MedlineCitation>
    <Abstract>
      <AbstractText Label="METHODS">Metodologia A.</AbstractText>
      <AbstractText Label="RESULTS">Resultado A.</AbstractText>
    </Abstract>
  </PubmedArticle>
  <PubmedArticle>
    <MedlineCitation><PMID Version="1">222</PMID></MedlineCitation>
    <Abstract><AbstractText>Resumo B.</AbstractText></Abstract>
  </PubmedArticle>
</PubmedArticleSet>''';
      final r = lerAbstractsXml(xml);
      expect(r.keys, ['111', '222']);
      expect(r['111']!.map((s) => s.rotulo), ['METHODS', 'RESULTS']);
      expect(r['222']!.single.rotulo, '');
      expect(r['111']!.map((s) => s.texto).join(), isNot(contains('Resumo B')));
    });

    test('usa o PRIMEIRO PMID do bloco, não o das referências', () {
      // Um bloco traz PMIDs de referências e de correções; pegar o errado
      // trocaria o dono do resumo.
      const xml = '''
<PubmedArticleSet><PubmedArticle>
  <MedlineCitation><PMID Version="1">111</PMID></MedlineCitation>
  <Abstract><AbstractText>Texto certo.</AbstractText></Abstract>
  <ReferenceList><Reference><PMID Version="1">999</PMID></Reference></ReferenceList>
</PubmedArticle></PubmedArticleSet>''';
      final r = lerAbstractsXml(xml);
      expect(r.keys, ['111']);
      expect(r.containsKey('999'), isFalse);
    });

    test('artigo sem Abstract vira lista vazia, não ausência', () {
      // "não tem resumo" é diferente de "não veio na resposta": a tela mostra
      // mensagens diferentes.
      const xml = '<PubmedArticleSet><PubmedArticle>'
          '<MedlineCitation><PMID Version="1">111</PMID></MedlineCitation>'
          '</PubmedArticle></PubmedArticleSet>';
      final r = lerAbstractsXml(xml);
      expect(r['111'], isEmpty);
      expect(r.containsKey('111'), isTrue);
    });

    test('remove marcação inline e decodifica entidades', () {
      const xml = '<PubmedArticleSet><PubmedArticle>'
          '<MedlineCitation><PMID Version="1">111</PMID></MedlineCitation>'
          '<Abstract><AbstractText>SGLT<sub>2</sub> &amp; risco &lt; 5%'
          '</AbstractText></Abstract>'
          '</PubmedArticle></PubmedArticleSet>';
      expect(lerAbstractsXml(xml)['111']!.single.texto, 'SGLT2 & risco < 5%');
    });

    test('XML vazio não quebra', () {
      expect(lerAbstractsXml(''), isEmpty);
      expect(lerAbstractsXml('<PubmedArticleSet/>'), isEmpty);
    });

    test('traduz os rótulos conhecidos e preserva os desconhecidos', () {
      expect(const SecaoResumo(rotulo: 'CONCLUSIONS', texto: 'x').rotuloPt,
          'Conclusões');
      expect(const SecaoResumo(rotulo: 'BACKGROUND', texto: 'x').rotuloPt,
          'Contexto');
      // Inventar tradução para rótulo desconhecido seria pior que mostrar o
      // original.
      expect(const SecaoResumo(rotulo: 'TRIAL REGISTRATION', texto: 'x').rotuloPt,
          'TRIAL REGISTRATION');
    });
  });

  group('filtros', () {
    test('sem filtro, o termo passa intacto', () {
      expect(const FiltrosBusca().aplicar('asthma'), 'asthma');
    });

    test('desenhos somam com OR, não com AND', () {
      // Com AND o resultado seria sempre vazio: um artigo não é metanálise e
      // ensaio randomizado ao mesmo tempo.
      final f = FiltrosBusca(desenhos: {
        DesenhoFiltro.metanalise,
        DesenhoFiltro.ensaioRandomizado,
      });
      final q = f.aplicar('asthma');
      expect(q, contains('OR'));
      expect(q, contains('"Meta-Analysis"[ptyp]'));
      expect(q, contains('"Randomized Controlled Trial"[ptyp]'));
    });

    test('parenteseia o termo quando ele tem operador', () {
      // Sem isso, o OR do usuário se combinaria errado com os AND dos filtros.
      final f = FiltrosBusca(desenhos: {DesenhoFiltro.metanalise});
      expect(f.aplicar('a OR b'), startsWith('(a OR b) AND'));
      expect(f.aplicar('asthma'), startsWith('asthma AND'));
    });

    test('janela de datas usa o ano corrente', () {
      const f = FiltrosBusca(anosRecentes: 5);
      expect(f.aplicar('asthma', anoAtual: 2026), contains('2021:2026[pdat]'));
    });

    test('conta e resume os filtros ativos', () {
      const f = FiltrosBusca(
        anosRecentes: 5,
        somenteHumanos: true,
        faixaEtaria: FaixaEtaria.idoso,
      );
      expect(f.quantidadeAtiva, 3);
      expect(f.resumo, containsAll(['Últimos 5 anos', 'Humanos', 'Idoso (65+)']));
      expect(f.vazio, isFalse);
    });

    test('termo vazio devolve consulta vazia', () {
      const f = FiltrosBusca(somenteHumanos: true);
      expect(f.aplicar('   '), '');
    });
  });

  group('PICO → Entrez', () {
    const pico = Pico(
      populacao: 'elderly OR aged',
      intervencao: 'metformin',
      comparador: 'insulin',
      desfecho: 'cardiovascular events',
    );

    test('monta blocos OR combinados por AND', () {
      final q = pico.paraEntrez(anoAtual: 2026);
      expect(q, contains('(elderly[tiab] OR aged[tiab])'));
      expect(q, contains('AND'));
      expect(q, contains('"cardiovascular events"[tiab]'));
    });

    test('o comparador AMPLIA, não restringe', () {
      // Exigir o comparador com AND joga fora justamente as metanálises.
      final q = pico.paraEntrez();
      final blocoIntervencao =
          RegExp(r'\(metformin\[tiab\] OR insulin\[tiab\]\)').hasMatch(q);
      expect(blocoIntervencao, isTrue);
      expect(q, isNot(contains('AND insulin')));
    });

    test('frase com espaço vira busca exata', () {
      expect(const Pico(populacao: 'heart failure').paraEntrez(),
          contains('"heart failure"[tiab]'));
    });

    test('respeita qualificador que o modelo já escreveu', () {
      expect(const Pico(populacao: 'asthma[mesh]').paraEntrez(),
          contains('asthma[mesh]'));
    });

    test('desfecho pode ser removido para ampliar', () {
      final com = pico.paraEntrez();
      final sem = pico.paraEntrez(incluirDesfecho: false);
      expect(sem.length, lessThan(com.length));
      expect(sem, isNot(contains('cardiovascular')));
    });

    test('desenho e janela entram como filtro final', () {
      final q = pico
          .copyWith(desenhosPreferidos: ['Meta-Analysis'], janelaAnos: 5)
          .paraEntrez(anoAtual: 2026);
      expect(q, contains('"Meta-Analysis"[ptyp]'));
      expect(q, contains('2021:2026[pdat]'));
    });

    test('doJson tolera o que o modelo costuma errar', () {
      // String onde devia haver lista, número como texto, campo ausente.
      final p = Pico.doJson({
        'populacao': 'elderly',
        'termosMesh': 'Aged, Metformin',
        'janelaAnos': '5',
      });
      expect(p.termosMesh, ['Aged', 'Metformin']);
      expect(p.janelaAnos, 5);
      expect(p.comparador, '');
      expect(p.vazio, isFalse);
    });

    test('PICO vazio não gera consulta', () {
      expect(const Pico().paraEntrez(), '');
      expect(const Pico().vazio, isTrue);
    });
  });

  group('formatos de citação', () {
    const artigo = ArtigoPubmed(
      pmid: '31535829',
      titulo: 'Dapagliflozin in Patients with Heart Failure.',
      autores: ['McMurray JJV', 'Solomon SD', 'Inzucchi SE', 'Køber L'],
      periodico: 'N Engl J Med',
      dataPublicacao: '2019 Nov 21',
      ano: 2019,
      doi: '10.1056/NEJMoa1911303',
      volume: '381',
      paginas: '1995-2008',
      url: 'https://pubmed.ncbi.nlm.nih.gov/31535829/',
    );

    test('Vancouver traz identificadores verificáveis', () {
      final c = formatarCitacao(artigo, FormatoCitacao.vancouver);
      expect(c, contains('McMurray JJV'));
      expect(c, contains('PMID: 31535829'));
      expect(c, contains('doi:10.1056/NEJMoa1911303'));
    });

    test('ABNT põe o sobrenome em versal', () {
      final c = formatarCitacao(artigo, FormatoCitacao.abnt);
      expect(c, contains('MCMURRAY'));
      expect(c, contains('v. 381'));
    });

    test('BibTeX gera chave única com o PMID', () {
      final c = formatarCitacao(artigo, FormatoCitacao.bibtex);
      // Dois artigos do mesmo autor no mesmo ano colidiriam sem o PMID, e um
      // gerenciador de referências rejeita chave repetida.
      expect(c, contains('@article{mcmurray2019_31535829'));
      expect(c, contains('author = {McMurray JJV and Solomon SD'));
    });

    test('RIS sai no formato que os gerenciadores importam', () {
      final c = formatarCitacao(artigo, FormatoCitacao.ris);
      expect(c, startsWith('TY  - JOUR'));
      expect(c, endsWith('ER  - '));
      expect(c, contains('AN  - 31535829'));
    });

    test('artigo sem autor não quebra nenhum formato', () {
      const anon = ArtigoPubmed(pmid: '1', titulo: 'Sem autoria');
      for (final f in FormatoCitacao.values) {
        expect(() => formatarCitacao(anon, f), returnsNormally);
        expect(formatarCitacao(anon, f), contains('1'));
      }
    });
  });
}
