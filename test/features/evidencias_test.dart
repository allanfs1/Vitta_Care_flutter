import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vitta_app/core/modules/mcp/mcp_server.dart';
import 'package:vitta_app/core/services/auth_service.dart';
import 'package:vitta_app/features/evidencias/citacao_validator.dart';
import 'package:vitta_app/features/evidencias/pubmed_models.dart';
import 'package:vitta_app/features/evidencias/pubmed_service.dart';

/// Testes do módulo de Evidências (`.specify/EVIDENCIAS.md`).
///
/// A guarda de PHI e o limitador de taxa são testados do lado do servidor
/// (`functions/test/pubmed.test.js`) — é lá que eles rodam. Aqui cobre-se o
/// que é responsabilidade do cliente: validação de citação, parsing de
/// abstract, modelos e o comportamento das tools MCP sem serviço.

/// AuthService de teste — devolve o token que lhe for dado.
class _FakeAuth implements AuthService {
  _FakeAuth([this._token = 'token-de-teste']);
  final String? _token;

  @override
  Future<String?> idToken() async => _token;

  @override
  bool get isFirebaseEnabled => true;
  @override
  String? get currentEmail => 'medico@clinica.com';
  @override
  String? get currentUid => 'uid-teste';
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

/// Cliente HTTP falso que devolve um corpo fixo e guarda a requisição.
http.Client _clienteFake(
  Object corpo, {
  int status = 200,
  List<http.Request>? registro,
}) {
  return MockClient((req) async {
    registro?.add(req);
    return http.Response(
      corpo is String ? corpo : jsonEncode(corpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

void main() {
  group('CitacaoValidator', () {
    const v = CitacaoValidator();

    test('extrai PMIDs nos formatos usuais', () {
      final r = v.extrair(
        'Reduz internação (PMID: 31452104). Outro achado [PMID 31556701] '
        'e um terceiro [12345678].',
      );
      expect(r.map((c) => c.pmid), ['31452104', '31556701', '12345678']);
    });

    test('NÃO confunde ano, dose ou amostra com citação', () {
      // Este é o teste que impede a validação de acusar erro onde não há: um
      // número solto no texto clínico não é PMID.
      final r = v.extrair(
        'Em 2024, 850 mg ao dia em 12345 pacientes reduziu o desfecho em 30%.',
      );
      expect(r, isEmpty);
    });

    test('não duplica o mesmo PMID', () {
      final r = v.extrair('PMID: 31452104 e de novo PMID: 31452104');
      expect(r.length, 1);
    });

    test('separa citação válida de inventada', () {
      final r = v.validar(
        'A reduziu mortalidade (PMID: 31452104), e B também (PMID: 99999999).',
        ['31452104', '31556701'],
      );
      expect(r.validos, ['31452104']);
      expect(r.invalidos, ['99999999']);
      expect(r.naoCitados, ['31556701']);
      expect(r.ok, isFalse);
      expect(r.cobertura, 0.5);
    });

    test('texto só com citações recuperadas passa', () {
      final r = v.validar('Conforme PMID: 31452104.', ['31452104']);
      expect(r.ok, isTrue);
      expect(r.cobertura, 1.0);
      expect(v.aviso(r), isNull);
    });

    test('resposta sem citação alguma é sinalizada, não reprovada', () {
      final r = v.validar('O tratamento costuma ser eficaz.', ['31452104']);
      expect(r.ok, isTrue, reason: 'não há citação errada');
      expect(r.semCitacao, isTrue);
      expect(v.aviso(r), contains('não cita nenhuma fonte'));
    });

    test('marca a citação inválida no texto em vez de apagá-la', () {
      const texto = 'Achado forte (PMID: 99999999).';
      final r = v.validar(texto, ['31452104']);
      final anotado = v.anotarInvalidas(texto, r);
      // Apagar esconderia o problema: a afirmação continuaria lá, sem fonte.
      expect(anotado, contains('99999999'));
      expect(anotado, contains('não verificada'));
    });

    test('valida contra a lista de artigos', () {
      const artigo = ArtigoPubmed(pmid: '31452104', titulo: 'X');
      final r = v.validarContra('Ver PMID: 31452104', const [artigo]);
      expect(r.ok, isTrue);
    });
  });

  group('ArtigoPubmed', () {
    const artigo = ArtigoPubmed(
      pmid: '31452104',
      titulo: 'Dapagliflozin in Heart Failure',
      autores: ['McMurray JJV', 'Solomon SD', 'Inzucchi SE'],
      periodico: 'N Engl J Med',
      dataPublicacao: '2019 Nov 21',
      ano: 2019,
      doi: '10.1056/NEJMoa1911303',
      pmcid: 'PMC123456',
      tiposPublicacao: ['Randomized Controlled Trial', 'Journal Article'],
      url: 'https://pubmed.ncbi.nlm.nih.gov/31452104/',
    );

    test('autoria abreviada segue o padrão bibliográfico', () {
      expect(artigo.autoresCurto, 'McMurray JJV, et al.');
      expect(
        const ArtigoPubmed(pmid: '1', titulo: 't', autores: ['Só A'])
            .autoresCurto,
        'Só A',
      );
      expect(
        const ArtigoPubmed(pmid: '1', titulo: 't').autoresCurto,
        'Autoria não informada',
      );
    });

    test('desenho do estudo prioriza a evidência mais forte', () {
      expect(artigo.desenhoEstudo, 'Randomized Controlled Trial');
      expect(
        const ArtigoPubmed(
          pmid: '1',
          titulo: 't',
          tiposPublicacao: ['Journal Article', 'Meta-Analysis'],
        ).desenhoEstudo,
        'Meta-Analysis',
      );
    });

    test('citação traz os elementos verificáveis', () {
      expect(artigo.citacao, contains('PMID: 31452104'));
      expect(artigo.citacao, contains('DOI: 10.1056/NEJMoa1911303'));
      expect(artigo.citacao, contains('N Engl J Med'));
    });

    test('URLs derivadas só existem quando há identificador', () {
      expect(artigo.urlPmc, contains('PMC123456'));
      expect(artigo.urlDoi, 'https://doi.org/10.1056/NEJMoa1911303');
      const semIds = ArtigoPubmed(pmid: '1', titulo: 't');
      expect(semIds.urlPmc, isNull);
      expect(semIds.urlDoi, isNull);
    });

    test('doJson tolera registro incompleto', () {
      final a = ArtigoPubmed.doJson({'pmid': '9', 'titulo': 'T'});
      expect(a.pmid, '9');
      expect(a.doi, isNull);
      expect(a.ano, isNull);
      expect(a.autores, isEmpty);
    });
  });

  group('PubmedService', () {
    test('envia o token no header e a ação no corpo', () async {
      final reqs = <http.Request>[];
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _clienteFake(
          {'ok': true, 'total': 0, 'pmids': [], 'queryEnviada': 'x', 'queryTraduzida': ''},
          registro: reqs,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
        permitirFallback: false,
      );
      await svc.buscar('asthma');

      expect(reqs.single.headers['Authorization'], 'Bearer token-de-teste');
      final corpo = jsonDecode(reqs.single.body) as Map<String, dynamic>;
      expect(corpo['acao'], 'buscar');
      expect(corpo['termo'], 'asthma');
    });

    test('recusa sem sessão, sem ir à rede', () async {
      final reqs = <http.Request>[];
      final svc = PubmedService(
        auth: _FakeAuth(null),
        client: _clienteFake({}, registro: reqs),
        proxyUrl: 'https://exemplo/pubmedProxy',
        permitirFallback: false,
      );
      await expectLater(
        svc.buscar('asthma'),
        throwsA(isA<EvidenciaErro>()
            .having((e) => e.precisaLogin, 'precisaLogin', isTrue)),
      );
      expect(reqs, isEmpty);
    });

    test('propaga o código de erro do servidor (PHI bloqueado)', () async {
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _clienteFake(
          {'error': 'contém CPF', 'codigo': 'PHI_BLOCKED'},
          status: 400,
        ),
        proxyUrl: 'https://exemplo/pubmedProxy',
        permitirFallback: false,
      );
      await expectLater(
        svc.buscar('paciente 123.456.789-01'),
        throwsA(isA<EvidenciaErro>().having(
            (e) => e.bloqueadoPorDadoPessoal, 'bloqueadoPorDadoPessoal', isTrue)),
      );
    });

    test('404 vira instrução de deploy, não erro genérico', () async {
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _clienteFake('não encontrado', status: 404),
        proxyUrl: 'https://exemplo/pubmedProxy',
        permitirFallback: false,
      );
      await expectLater(
        svc.buscar('asthma'),
        throwsA(isA<EvidenciaErro>()
            .having((e) => e.codigo, 'codigo', 'NOT_DEPLOYED')),
      );
    });

    test('lê resumos em seções rotuladas do XML', () async {
      const xml = '''
<PubmedArticleSet>
  <PubmedArticle>
    <MedlineCitation><PMID Version="1">31452104</PMID></MedlineCitation>
    <Abstract>
      <AbstractText Label="BACKGROUND">Contexto do estudo A.</AbstractText>
      <AbstractText Label="CONCLUSIONS">Conclusão do estudo A.</AbstractText>
    </Abstract>
  </PubmedArticle>
  <PubmedArticle>
    <MedlineCitation><PMID Version="1">31556701</PMID></MedlineCitation>
    <Abstract><AbstractText>Resumo corrido do estudo B.</AbstractText></Abstract>
  </PubmedArticle>
</PubmedArticleSet>''';

      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _clienteFake({'ok': true, 'xml': xml}),
        proxyUrl: 'https://exemplo/pubmedProxy',
        permitirFallback: false,
      );
      final mapa = await svc.abstracts(['31452104', '31556701']);

      expect(mapa.keys, containsAll(['31452104', '31556701']));
      // Estruturado: rótulos preservados, porque em leitura clínica uma frase
      // em CONCLUSIONS pesa diferente da mesma frase em METHODS.
      expect(mapa['31452104']!.length, 2);
      expect(mapa['31452104']!.first.rotulo, 'BACKGROUND');
      expect(mapa['31452104']!.first.rotuloPt, 'Contexto');
      expect(mapa['31452104']!.last.texto, contains('Conclusão do estudo A'));
      // Corrido: uma seção sem rótulo.
      expect(mapa['31556701']!.single.temRotulo, isFalse);
      // Sem vazamento entre artigos.
      expect(mapa['31452104']!.map((s) => s.texto).join(),
          isNot(contains('estudo B')));
    });

    test('lista vazia não chama a rede', () async {
      final reqs = <http.Request>[];
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: _clienteFake({}, registro: reqs),
        proxyUrl: 'https://exemplo/pubmedProxy',
        permitirFallback: false,
      );
      expect(await svc.resumos([]), isEmpty);
      expect(await svc.abstracts([]), isEmpty);
      expect(reqs, isEmpty);
    });
  });

  group('ResultadoBusca', () {
    test('temMais compara o total com o que já veio', () {
      const r = ResultadoBusca(
        total: 100,
        pmids: ['1', '2'],
        queryEnviada: 'x',
        queryTraduzida: 'y',
      );
      expect(r.temMais, isTrue);
      expect(r.vazio, isFalse);

      const fim = ResultadoBusca(
        total: 2,
        pmids: ['1', '2'],
        queryEnviada: 'x',
        queryTraduzida: 'y',
      );
      expect(fim.temMais, isFalse);
    });

    test('preserva a consulta traduzida — base da auditoria', () {
      final r = ResultadoBusca.doJson({
        'total': 5,
        'pmids': ['1'],
        'queryEnviada': 'asthma[tiab]',
        'queryTraduzida': '"asthma"[MeSH Terms] OR "asthma"[All Fields]',
      });
      expect(r.queryTraduzida, contains('MeSH Terms'));
      expect(r.queryEnviada, 'asthma[tiab]');
    });
  });

  group('ferramentas MCP de PubMed', () {
    test('estão registradas no catálogo', () {
      final servidor = createMcpServer(defaultClinicaId: 'clinica-x');
      expect(servidor.hasTool('pubmed_buscar'), isTrue);
      expect(servidor.hasTool('pubmed_artigo'), isTrue);
      expect(servidor.hasTool('pubmed_relacionados'), isTrue);
      expect(servidor.hasTool('pubmed_corrigir_termo'), isTrue);
    });

    test('sem serviço, recusam com orientação em vez de falhar de forma opaca',
        () async {
      // Modo demonstração: o servidor existe, as tools estão registradas (o
      // modelo precisa saber que a capacidade existe), mas não há cliente.
      final servidor = createMcpServer(defaultClinicaId: 'clinica-x');
      final r = await servidor.callTool('pubmed_buscar', {'termo': 'asthma'});
      expect(r.isError, isTrue);
      expect(r.text, contains('indisponível'));
    });

    test('continuam sujeitas à guarda de clínica não resolvida', () async {
      // Literatura é pública, mas a guarda de tenant vale para toda tool: sem
      // clínica resolvida nada é despachado. Ver MCP.md §3.1.
      final servidor = createMcpServer(defaultClinicaId: '');
      final r = await servidor.callTool('pubmed_buscar', {'termo': 'asthma'});
      expect(r.isError, isTrue);
    });

    test('o catálogo exposto ao LLM descreve o contrato de citação', () {
      final servidor = createMcpServer(defaultClinicaId: 'c');
      final spec = servidor
          .listToolSpecs()
          .firstWhere((s) => s['name'] == 'pubmed_buscar');
      final descricao = spec['description'].toString();
      // As duas regras que impedem o pior erro do produto.
      expect(descricao, contains('NUNCA invente PMID'));
      expect(descricao, contains('CPF'));
    });
  });
}
