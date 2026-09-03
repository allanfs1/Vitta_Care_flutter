import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/services/auth_service.dart';
import 'package:vitta_app/features/evidencias/evidencias_providers.dart';
import 'package:vitta_app/features/evidencias/evidencias_screen.dart';
import 'package:vitta_app/features/evidencias/pubmed_direct.dart';
import 'package:vitta_app/features/evidencias/pubmed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/features/evidencias/sessoes/sessao_store.dart';
import 'package:vitta_app/features/evidencias/widgets/artigo_card.dart';

/// Testes de widget da tela `/evidencias`.
///
/// Renderizam a tela de verdade — não um mock dela — e verificam o que o
/// usuário vê em cada estado. Cobrem o que os testes de unidade não alcançam:
/// que a troca de modo muda a instrução ao usuário, que o aviso de caminho
/// direto aparece, e que o estado vazio aponta o filtro como suspeito.

class _FakeAuth implements AuthService {
  @override
  Future<String?> idToken() async => 'tok';
  @override
  bool get isFirebaseEnabled => false;
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

/// Serviço que responde do NCBI com [corpo], sempre pelo caminho direto.
PubmedService _servico(Object corpo) {
  final cliente = MockClient((req) async => http.Response(
        corpo is String ? corpo : jsonEncode(corpo),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));
  return PubmedService(
    auth: _FakeAuth(),
    // Proxy inexistente força o fallback — que é o estado real hoje, com a
    // Cloud Function ainda não publicada.
    client: MockClient((req) async => http.Response('nao encontrado', 404)),
    proxyUrl: 'https://exemplo/pubmedProxy',
    direto: PubmedDirect(client: cliente),
  );
}

late SharedPreferences _prefs;

/// Prepara o armazenamento local antes de montar a tela. Sessões e histórico
/// agora persistem, então sem isto os providers nem constroem.
Future<void> _prepararPrefs() async {
  SharedPreferences.setMockInitialValues({});
  _prefs = await SharedPreferences.getInstance();
}

Widget _app(PubmedService svc) => ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuth()),
        pubmedServiceProvider.overrideWithValue(svc),
        sharedPrefsProvider.overrideWithValue(_prefs),
      ],
      child: const MaterialApp(home: EvidenciasScreen()),
    );

const _buscaComResultado = {
  'esearchresult': {
    'count': '128',
    'retstart': '0',
    'idlist': ['31535829'],
    'querytranslation': '"heart failure"[MeSH Terms]',
  },
  'result': {
    'uids': ['31535829'],
    '31535829': {
      'uid': '31535829',
      'title': 'Dapagliflozin in Patients with Heart Failure.',
      'authors': [
        {'name': 'McMurray JJV', 'authtype': 'Author'},
        {'name': 'DAPA-HF Group', 'authtype': 'CollectiveName'},
      ],
      'fulljournalname': 'The New England journal of medicine',
      'pubdate': '2019 Nov 21',
      'volume': '381',
      'pages': '1995-2008',
      'pubtype': ['Randomized Controlled Trial', 'Journal Article'],
      'articleids': [
        {'idtype': 'doi', 'value': '10.1056/NEJMoa1911303'},
      ],
    },
  },
};

const _buscaVazia = {
  'esearchresult': {
    'count': '0',
    'retstart': '0',
    'idlist': <String>[],
    'querytranslation': '"xyzabc"[All Fields]',
  },
};

void main() {
  setUp(_prepararPrefs);

  group('sessões', () {
    testWidgets('salvar só aparece quando há o que salvar', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      // Botão morto ensina o usuário a ignorar a barra.
      expect(find.byIcon(Icons.bookmark_add_outlined), findsNothing);

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
    });

    testWidgets('salva e a sessão aparece na lista', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Salvar sessão'), findsOneWidget);
      // A prévia diz o que vai ser guardado.
      expect(find.textContaining('artigo(s)'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_outline));
      await tester.pumpAndSettle();
      expect(find.text('Sessões salvas'), findsOneWidget);
      expect(find.textContaining('heart failure'), findsWidgets);
    });

    testWidgets('a lista vazia explica para que serve', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_outline));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma sessão salva ainda.'), findsOneWidget);
      expect(find.textContaining('retomar depois'), findsOneWidget);
    });

    testWidgets('restaurar NÃO refaz a busca na rede', (tester) async {
      final urls = <Uri>[];
      final cliente = MockClient((req) async {
        urls.add(req.url);
        return http.Response(jsonEncode(_buscaComResultado), 200,
            headers: {'content-type': 'application/json'});
      });
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: MockClient((req) async => http.Response('x', 404)),
        proxyUrl: 'https://exemplo/pubmedProxy',
        direto: PubmedDirect(client: cliente),
      );

      await tester.pumpWidget(_app(svc));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      final antes = urls.length;
      await tester.tap(find.byIcon(Icons.bookmark_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('heart failure').last);
      await tester.pumpAndSettle();

      // Reexecutar devolveria outro conjunto (o PubMed indexa todo dia) e a
      // síntese citaria artigos que sumiram — quebrando a reprodutibilidade
      // que a sessão existe para garantir.
      expect(urls.length, antes);
      expect(find.byType(ArtigoCard), findsOneWidget);
    });
  });

  group('estado inicial', () {
    testWidgets('abre em modo Buscar, explicando o que digitar',
        (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      expect(find.text('Evidências'), findsOneWidget);
      expect(find.text('Buscar'), findsOneWidget);
      expect(find.text('Perguntar'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Pesquise literatura científica'), findsOneWidget);
      // A instrução de idioma evita o erro mais caro do módulo: buscar em
      // português e concluir que não há literatura.
      expect(find.textContaining('Termos em inglês'), findsOneWidget);
    });

    testWidgets('o aviso de dado pessoal fica visível antes da primeira busca',
        (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();
      // Depois de bloqueado já é tarde para ensinar.
      expect(find.textContaining('Nunca inclua nome, CPF'), findsOneWidget);
    });

    testWidgets('trocar para IA muda a instrução ao usuário', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perguntar'));
      await tester.pumpAndSettle();

      expect(find.text('Pergunte em português'), findsOneWidget);
      expect(find.textContaining('decompõe em PICO'), findsOneWidget);
      // Filtros e ordenação não fazem sentido no modo agente: quem monta a
      // estratégia é ele.
      expect(find.text('Filtros'), findsNothing);
    });
  });

  group('modo chat', () {
    testWidgets('abre explicando a diferença entre os três modos',
        (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      expect(find.text('Converse sobre a literatura'), findsOneWidget);
      // Sem isto o usuário escolhe pelo nome e descobre a diferença tarde:
      // manda pergunta de revisão para o chat e recebe resposta rasa.
      expect(find.text('Qual modo usar'), findsOneWidget);
      expect(find.textContaining('Dúvida rápida', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('revisão a fundo', findRichText: true),
          findsOneWidget);
    });

    testWidgets('o campo muda de instrução no chat', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a conversa guarda o contexto'.toLowerCase()),
          findsNothing);
      expect(find.textContaining('A conversa guarda o contexto'), findsOneWidget);
      // Filtros e ordenação somem: quem monta a estratégia é o modelo.
      expect(find.text('Filtros'), findsNothing);
    });

    testWidgets('sugestão preenche e dispara a conversa', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Metformina reduz eventos'));
      await tester.pump();

      // A pergunta entra na conversa mesmo que o modelo não responda (sem
      // credencial de IA no teste) — o que se verifica aqui é o fluxo da tela.
      expect(find.textContaining('Metformina reduz eventos'), findsWidgets);
    });

    testWidgets('cabe em tela estreita', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('busca', () {
    testWidgets('mostra total, card do artigo e o desenho do estudo',
        (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.textContaining('128 artigos encontrados'), findsOneWidget);
      expect(find.byType(ArtigoCard), findsOneWidget);
      expect(find.textContaining('Dapagliflozin'), findsOneWidget);
      // Desenho traduzido e em destaque — é o que o médico usa para triar.
      expect(find.text('Ensaio randomizado'), findsOneWidget);
      expect(find.text('2019'), findsOneWidget);
    });

    testWidgets('"Como pesquisamos" revela a consulta que o PubMed executou',
        (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Como pesquisamos'));
      await tester.pumpAndSettle();

      // Sem isto a busca vira caixa-preta: não há como entender por que um
      // artigo esperado não apareceu.
      expect(find.textContaining('MeSH Terms'), findsOneWidget);
      expect(find.text('Direto no NCBI'), findsOneWidget);
    });

    testWidgets('o autor coletivo não entra na autoria', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // "DAPA-HF Group" é o consórcio, não uma pessoa — citá-lo como autor
      // estragaria a referência.
      expect(find.text('McMurray JJV'), findsOneWidget);
      expect(find.textContaining('DAPA-HF Group'), findsNothing);
    });
  });

  group('filtros', () {
    testWidgets('abrem, marcam e mostram o contador', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Desenho do estudo'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Metanálise'));
      await tester.pumpAndSettle();

      // O contador impede o pior estado da tela: filtro ligado, resultado
      // estranho, ninguém lembrando por quê.
      expect(find.text('Filtros (1)'), findsOneWidget);
    });
  });

  group('estados sem resultado', () {
    testWidgets('busca vazia acusa os filtros como suspeito', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaVazia)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Metanálise'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'xyzabc');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Nenhum artigo encontrado'), findsOneWidget);
      // Filtro ativo é a causa mais comum e a mais fácil de esquecer.
      expect(find.textContaining('filtro(s) ativo(s)'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Limpar'), findsOneWidget);
    });
  });

  group('caminho direto', () {
    testWidgets('avisa sem jargão e sem alarme', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.textContaining('Buscando direto no PubMed'), findsOneWidget);
      expect(find.textContaining('proteção de dados continua ativa'),
          findsOneWidget);

      // "CORS" e "proxy" não significam nada para um médico. O detalhe técnico
      // vive no tooltip e no log, não na faixa que ocupa a tela de quem atende.
      expect(find.textContaining('CORS'), findsNothing);
      expect(find.textContaining('proxy'), findsNothing);
    });

    testWidgets('o aviso é dispensável e não volta', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('Buscando direto no PubMed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining('Buscando direto no PubMed'), findsNothing);

      // Fixo, custaria uma faixa da tela em TODA busca para repetir algo que
      // não muda e que o médico não pode resolver.
      await tester.enterText(find.byType(TextField), 'diabetes');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('Buscando direto no PubMed'), findsNothing);
    });

    testWidgets('a origem continua registrada em "Como pesquisamos"',
        (tester) async {
      // A informação não se perde ao dispensar o aviso.
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Como pesquisamos'));
      await tester.pumpAndSettle();

      expect(find.text('Direto no NCBI'), findsOneWidget);
    });
  });

  group('bloqueio de dado pessoal', () {
    testWidgets('mostra escudo e ensina, em vez de erro vermelho',
        (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'diabetes do paciente CPF 123.456.789-01');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Não é falha do sistema — é a guarda funcionando.
      expect(find.text('Busca bloqueada por proteção de dados'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.textContaining('CPF'), findsWidgets);
      // Sem botão de "tentar novamente": repetir a mesma busca daria no mesmo.
      expect(find.widgetWithText(FilledButton, 'Tentar novamente'), findsNothing);
    });
  });

  group('responsividade', () {
    testWidgets('cabe em tela estreita sem estourar o layout', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Evidências'), findsOneWidget);
    });

    testWidgets('e em tela larga também', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ArtigoCard), findsOneWidget);
    });
  });

  group('filtros aplicados de fato', () {
    testWidgets('marcar um filtro refaz a busca com ele na consulta',
        (tester) async {
      final urls = <Uri>[];
      final cliente = MockClient((req) async {
        urls.add(req.url);
        return http.Response(jsonEncode(_buscaComResultado), 200,
            headers: {'content-type': 'application/json'});
      });
      final svc = PubmedService(
        auth: _FakeAuth(),
        client: MockClient((req) async => http.Response('x', 404)),
        proxyUrl: 'https://exemplo/pubmedProxy',
        direto: PubmedDirect(client: cliente),
      );

      await tester.pumpWidget(_app(svc));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Metanálise'));
      await tester.pumpAndSettle();

      // Trocar filtro sem refazer a busca faria parecer que o filtro não
      // funcionou.
      final ultima = urls.lastWhere((u) => u.path.contains('esearch'));
      expect(ultima.queryParameters['term'], contains('"Meta-Analysis"[ptyp]'));
    });
  });

  group('citação', () {
    testWidgets('o menu oferece os quatro formatos', (tester) async {
      await tester.pumpWidget(_app(_servico(_buscaComResultado)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart failure');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ArtigoCard));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Citar'));
      await tester.pumpAndSettle();

      // O formato depende do destino: revista pede Vancouver, trabalho
      // brasileiro pede ABNT, gerenciador pede BibTeX ou RIS.
      expect(find.text('Vancouver'), findsOneWidget);
      expect(find.text('ABNT'), findsOneWidget);
      expect(find.text('BibTeX'), findsOneWidget);
      expect(find.text('RIS'), findsOneWidget);
    });
  });
}
