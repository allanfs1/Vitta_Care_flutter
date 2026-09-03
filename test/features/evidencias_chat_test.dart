import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vitta_app/core/services/auth_service.dart';
import 'package:vitta_app/features/evidencias/ia/chat_pesquisa.dart';
import 'package:vitta_app/features/evidencias/nivel_evidencia.dart';
import 'package:vitta_app/features/evidencias/pubmed_direct.dart';
import 'package:vitta_app/features/evidencias/pubmed_service.dart';
import 'package:vitta_app/features/ia/agent/ai_agent_service.dart';

/// Testes do chat de pesquisa e do nível de evidência.
///
/// O que mais importa aqui é o comportamento das **ferramentas** e da
/// **validação acumulativa**: é onde um chat clínico erra de forma perigosa.

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

Map<String, dynamic> _busca(List<String> pmids, {String count = '12'}) => {
      'esearchresult': {
        'count': count,
        'retstart': '0',
        'idlist': pmids,
        'querytranslation': '"asthma"[MeSH]',
      },
      'result': {
        'uids': pmids,
        for (final p in pmids)
          p: {
            'uid': p,
            'title': 'Artigo $p',
            'authors': [
              {'name': 'Autor A', 'authtype': 'Author'},
            ],
            'fulljournalname': 'Revista X',
            'pubdate': '2023 Jan 5',
            'pubtype': ['Randomized Controlled Trial'],
            'articleids': [
              {'idtype': 'doi', 'value': '10.1000/$p'},
            ],
          },
      },
    };

ChatPesquisa _chat(List<Uri> urls, {Object? resposta}) {
  final cliente = MockClient((req) async {
    urls.add(req.url);
    return http.Response(
      jsonEncode(resposta ?? _busca(['111', '222'])),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return ChatPesquisa(
    pubmed: PubmedService(
      auth: _FakeAuth(),
      client: MockClient((req) async => http.Response('x', 404)),
      proxyUrl: 'https://exemplo/pubmedProxy',
      direto: PubmedDirect(client: cliente),
    ),
    ia: AiAgentService(),
  );
}

void main() {
  group('ferramentas do chat', () {
    test('só oferece ferramentas de literatura', () {
      final nomes =
          _chat([]).toolSpecs.map((t) => t['name'] as String).toList();
      // Nenhuma tool de dados da clínica: o chat fala com um serviço externo,
      // e misturar aqui uma ferramenta que lê pacientes abriria caminho para
      // dado de paciente virar termo de busca.
      expect(nomes, ['buscar_literatura', 'ler_resumos']);
    });

    test('a descrição carrega o contrato de citação e de PHI', () {
      final busca = _chat([])
          .toolSpecs
          .firstWhere((t) => t['name'] == 'buscar_literatura');
      final d = '${busca['description']}';
      expect(d, contains('nunca responda pergunta clínica de memória'));
      expect(d, contains('CPF'));
      expect(d, contains('INGLÊS'));
    });

    test('buscar alimenta o acervo e devolve os artigos', () async {
      final urls = <Uri>[];
      final chat = _chat(urls);

      final bruto = (await chat.executarTool(
              'buscar_literatura', {'termo': 'asthma', 'limite': 2}))
          .text;
      final j = jsonDecode(bruto) as Map<String, dynamic>;

      expect(j['total'], 12);
      expect((j['artigos'] as List).length, 2);
      expect(chat.acervo.keys, containsAll(['111', '222']));
      expect(j['orientacao'], contains('Cite os PMIDs'));
    });

    test('bloqueia PHI no termo, sem ir à rede', () async {
      final urls = <Uri>[];
      final chat = _chat(urls);

      // Num chat o modelo monta o termo sozinho, então um dado do paciente
      // escorregar do histórico para a busca é risco real — daí a guarda local
      // além da do servidor.
      final bruto = (await chat.executarTool(
              'buscar_literatura', {'termo': 'diabetes CPF 123.456.789-01'}))
          .text;
      final j = jsonDecode(bruto) as Map<String, dynamic>;

      expect(j['erro'], contains('CPF'));
      expect(j['erro'], contains('Reescreva'));
      expect(urls, isEmpty);
    });

    test('termo vazio devolve erro, não busca', () async {
      final urls = <Uri>[];
      final j = jsonDecode(
              (await _chat(urls)
                      .executarTool('buscar_literatura', {'termo': ' '}))
                  .text)
          as Map<String, dynamic>;
      expect(j['erro'], isNotNull);
      expect(urls, isEmpty);
    });

    test('busca vazia orienta a NÃO responder de memória', () async {
      final chat = _chat([], resposta: _busca([], count: '0'));
      final j = jsonDecode(
              (await chat.executarTool('buscar_literatura', {'termo': 'xyzabc'}))
                  .text)
          as Map<String, dynamic>;

      expect(j['total'], 0);
      expect(j['orientacao'], contains('em vez de responder de memória'));
    });

    test('ferramenta desconhecida não derruba o turno', () async {
      final j = jsonDecode((await _chat([]).executarTool('inexistente', {})).text)
          as Map<String, dynamic>;
      expect(j['erro'], contains('desconhecida'));
    });

    test('ler_resumos exige PMID', () async {
      final j = jsonDecode((await _chat([]).executarTool('ler_resumos', {})).text)
          as Map<String, dynamic>;
      expect(j['erro'], isNotNull);
    });
  });

  group('validação acumulativa', () {
    test('citação de artigo achado em turno anterior continua válida',
        () async {
      final chat = _chat([]);
      await chat.executarTool('buscar_literatura', {'termo': 'asthma'});

      // O ponto do chat: sem acervo acumulado, citar no turno 5 um artigo do
      // turno 2 seria marcado como invenção — o contrário do desejado.
      final v = chat.validarResposta('Conforme (PMID: 111) e (PMID: 222).');
      expect(v.ok, isTrue);
      expect(v.validos, ['111', '222']);
    });

    test('PMID nunca recuperado é marcado como inválido', () async {
      final chat = _chat([]);
      await chat.executarTool('buscar_literatura', {'termo': 'asthma'});

      final v = chat.validarResposta('Estudo relevante (PMID: 99999999).');
      expect(v.ok, isFalse);
      expect(v.invalidos, ['99999999']);
    });

    test('acervo vazio reprova qualquer citação', () {
      final v = _chat([]).validarResposta('Segundo (PMID: 31452104).');
      expect(v.invalidos, ['31452104']);
    });

    test('fontesDe devolve os artigos citados, na ordem do texto', () async {
      final chat = _chat([]);
      await chat.executarTool('buscar_literatura', {'termo': 'asthma'});

      final fontes = chat.fontesDe('Primeiro (PMID: 222), depois (PMID: 111).');
      expect(fontes.map((a) => a.pmid), ['222', '111']);
    });

    test('fontesDe ignora PMID fora do acervo em vez de quebrar', () async {
      final chat = _chat([]);
      await chat.executarTool('buscar_literatura', {'termo': 'asthma'});
      final fontes = chat.fontesDe('(PMID: 111) e (PMID: 99999999)');
      expect(fontes.map((a) => a.pmid), ['111']);
    });
  });

  group('nível de evidência', () {
    test('classifica pelo desenho, do mais forte ao mais fraco', () {
      expect(NivelEvidencia.de('Meta-Analysis'), NivelEvidencia.sintese);
      expect(NivelEvidencia.de('Systematic Review'), NivelEvidencia.sintese);
      expect(NivelEvidencia.de('Randomized Controlled Trial'),
          NivelEvidencia.experimental);
      expect(NivelEvidencia.de('Observational Study'),
          NivelEvidencia.observacional);
      expect(NivelEvidencia.de('Review'), NivelEvidencia.narrativa);
      expect(NivelEvidencia.de('Case Reports'), NivelEvidencia.relato);
    });

    test('"Journal Article" é indefinido, não observacional', () {
      // É o tipo genérico que quase todo registro carrega; tratá-lo como
      // desenho daria falsa precisão.
      expect(NivelEvidencia.de('Journal Article'), NivelEvidencia.indefinido);
      expect(NivelEvidencia.de(null), NivelEvidencia.indefinido);
      expect(NivelEvidencia.de(''), NivelEvidencia.indefinido);
    });

    test('só síntese e experimental contam como forte', () {
      expect(NivelEvidencia.sintese.forte, isTrue);
      expect(NivelEvidencia.experimental.forte, isTrue);
      expect(NivelEvidencia.observacional.forte, isFalse);
      expect(NivelEvidencia.relato.forte, isFalse);
    });

    test('a ordem cresce descendo a pirâmide', () {
      final ordens =
          NivelEvidencia.values.map((n) => n.ordem).toList();
      final ordenado = [...ordens]..sort();
      expect(ordens, ordenado, reason: 'a enum já está em ordem de força');
    });

    test('desenho desconhecido cai em observacional, não em indefinido', () {
      // Um tipo que o NCBI declarou mas que não mapeamos ainda é informação —
      // tratá-lo como "não informado" descartaria o que o registro afirma.
      expect(NivelEvidencia.de('Adaptive Clinical Trial'),
          NivelEvidencia.observacional);
    });
  });
}
