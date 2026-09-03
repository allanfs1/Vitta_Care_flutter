import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/idioma.dart';
import '../../core/services/app_providers.dart';
import '../configuracoes/providers/configuracoes_provider.dart';
import '../ia/agent/agent_models.dart';
import '../ia/agent/ai_agent_service.dart';
import 'citacao_validator.dart';
import 'filtros_busca.dart';
import 'ia/agente_evidencias.dart';
import 'ia/chat_pesquisa.dart';
import 'ia/pico.dart';
import 'ia/tradutor.dart';
import 'sessoes/sessao_models.dart';
import 'sessoes/sessao_store.dart';
import 'pubmed_models.dart';
import 'pubmed_service.dart';

/// Estado e serviços do módulo de Evidências — `.specify/EVIDENCIAS.md`.

final pubmedServiceProvider = Provider<PubmedService>((ref) {
  final s = PubmedService(auth: ref.watch(authServiceProvider));
  ref.onDispose(s.dispose);
  return s;
});

final citacaoValidatorProvider =
    Provider<CitacaoValidator>((ref) => const CitacaoValidator());

final agenteEvidenciasProvider = Provider<AgenteEvidencias>((ref) {
  return AgenteEvidencias(
    pubmed: ref.watch(pubmedServiceProvider),
    ia: AiAgentService(),
  );
});

/// Como o usuário está pesquisando.
enum ModoPesquisa {
  /// Consulta Entrez escrita à mão, com filtros. Rápido e previsível.
  busca,

  /// Pergunta em português; o agente decompõe, calibra, lê e sintetiza.
  /// Uma revisão estruturada, cara e completa.
  agente,

  /// Conversa com seguimento. O modelo escolhe as buscas, o acervo acumula, e
  /// cada resposta é conferida contra ele. Leve por turno.
  chat,
}

/// Uma mensagem do chat de pesquisa, já com o que a tela precisa mostrar.
class MensagemChat {
  MensagemChat({
    required this.papel,
    this.texto = '',
    this.streaming = false,
    this.ferramentas = const [],
    this.validacao,
    this.fontes = const [],
    this.erro = false,
  });

  final ChatRole papel;
  String texto;
  bool streaming;

  /// Buscas e leituras que o modelo fez para responder — visíveis de propósito:
  /// sem isso o médico não sabe se a resposta veio de busca ou de memória.
  List<String> ferramentas;

  /// `null` enquanto a resposta ainda está sendo escrita.
  ResultadoValidacao? validacao;
  List<ArtigoPubmed> fontes;
  final bool erro;

  bool get doUsuario => papel == ChatRole.user;
}

/// Idioma ativo, vindo das preferências.
final idiomaProvider = Provider<Idioma>(
  (ref) => Idioma.daChave(ref.watch(settingsProvider).locale),
);

final tradutorProvider = Provider<Tradutor>(
  (ref) => Tradutor(ia: AiAgentService()),
);

final sessaoStoreProvider = Provider<SessaoStore>(
  (ref) => SessaoStore(ref.watch(sharedPrefsProvider)),
);

/// Sessões salvas, do mais recente para o mais antigo.
final sessoesProvider =
    StateNotifierProvider<SessoesNotifier, List<SessaoPesquisa>>((ref) {
  return SessoesNotifier(ref.watch(sessaoStoreProvider));
});

class SessoesNotifier extends StateNotifier<List<SessaoPesquisa>> {
  SessoesNotifier(this._store) : super(_store.listar());

  final SessaoStore _store;

  Future<void> salvar(SessaoPesquisa s) async {
    await _store.salvar(s);
    state = _store.listar();
  }

  Future<void> excluir(String id) async {
    await _store.excluir(id);
    state = _store.listar();
  }

  Future<void> renomear(String id, String titulo) async {
    await _store.renomear(id, titulo);
    state = _store.listar();
  }
}

/// Traduções pedidas nesta sessão, por PMID.
///
/// Vive fora do `EvidenciasState` de propósito: tradução é uma camada sobre o
/// artigo, não parte do resultado da busca. Assim trocar de busca não descarta
/// o que já foi traduzido, e o cache do [Tradutor] segue valendo.
final traducoesProvider =
    StateNotifierProvider<TraducoesNotifier, Map<String, ArtigoTraduzido>>(
        (ref) {
  return TraducoesNotifier(
    ref.watch(tradutorProvider),
    ref.watch(idiomaProvider),
  );
});

class TraducoesNotifier extends StateNotifier<Map<String, ArtigoTraduzido>> {
  TraducoesNotifier(this._tradutor, this._idioma) : super(const {});

  final Tradutor _tradutor;
  final Idioma _idioma;

  final Set<String> _emAndamento = {};

  bool traduzindo(String pmid) => _emAndamento.contains(pmid);

  /// `true` quando faz sentido oferecer tradução: o conteúdo do PubMed é
  /// inglês, então em inglês não há o que traduzir.
  bool get disponivel => _idioma != Idioma.en;

  Future<void> traduzir(ArtigoPubmed artigo) async {
    if (state.containsKey(artigo.pmid) || _emAndamento.contains(artigo.pmid)) {
      return;
    }
    _emAndamento.add(artigo.pmid);
    state = {...state};
    try {
      final r = await _tradutor.traduzir(artigo, _idioma);
      if (mounted) state = {...state, artigo.pmid: r};
    } finally {
      _emAndamento.remove(artigo.pmid);
      if (mounted) state = {...state};
    }
  }

  void remover(String pmid) => state = {...state}..remove(pmid);
}

final chatPesquisaProvider = Provider<ChatPesquisa>((ref) {
  return ChatPesquisa(
    pubmed: ref.watch(pubmedServiceProvider),
    ia: AiAgentService(),
  );
});

/// Converte o modo em texto para guardar, e de volta.
///
/// O histórico persiste em disco: guardar o índice do enum quebraria a leitura
/// no dia em que um modo novo entrar no meio da lista.
ModoPesquisa modoDaChave(String? c) => switch (c) {
      'agente' => ModoPesquisa.agente,
      'chat' => ModoPesquisa.chat,
      _ => ModoPesquisa.busca,
    };

String chaveDoModo(ModoPesquisa m) => switch (m) {
      ModoPesquisa.agente => 'agente',
      ModoPesquisa.chat => 'chat',
      ModoPesquisa.busca => 'busca',
    };

class EvidenciasState {
  const EvidenciasState({
    this.termo = '',
    this.modo = ModoPesquisa.busca,
    this.carregando = false,
    this.resultado,
    this.erro,
    this.sugestaoTermo,
    this.ordem = OrdemBusca.relevancia,
    this.filtros = const FiltrosBusca(),
    this.secoes = const {},
    this.carregandoAbstract = const {},
    this.historico = const [],
    this.passos = const [],
    this.picoEditavel,
    this.consultaEfetiva = '',
    this.viaProxy = true,
    this.motivoFallback,
    this.mensagens = const [],
  });

  final String termo;
  final ModoPesquisa modo;
  final bool carregando;
  final ResultadoBusca? resultado;
  final EvidenciaErro? erro;

  /// Correção sugerida pelo ESpell quando a busca veio vazia.
  final String? sugestaoTermo;
  final OrdemBusca ordem;
  final FiltrosBusca filtros;

  /// Resumos carregados sob demanda, por PMID.
  final Map<String, List<SecaoResumo>> secoes;
  final Map<String, bool> carregandoAbstract;

  final List<ItemHistorico> historico;

  /// Passos do agente na sessão atual (modo [ModoPesquisa.agente]).
  final List<PassoAgente> passos;

  /// PICO que o médico pode corrigir antes de refazer a pesquisa.
  final Pico? picoEditavel;

  /// A consulta realmente enviada, já com os filtros aplicados. Diferente do
  /// que o usuário digitou — e é essa que explica o resultado.
  final String consultaEfetiva;

  /// `false` quando a consulta saiu pelo caminho direto ao NCBI.
  final bool viaProxy;
  final String? motivoFallback;

  /// Conversa do modo [ModoPesquisa.chat].
  final List<MensagemChat> mensagens;

  bool get temResultado => resultado != null && !resultado!.vazio;
  bool get buscaVazia => resultado != null && resultado!.vazio;

  /// A síntese final do agente, quando já veio.
  PassoAgente? get respostaAgente {
    for (final p in passos.reversed) {
      if (p.tipo == TipoPasso.resposta) return p;
    }
    return null;
  }

  EvidenciasState copyWith({
    String? termo,
    ModoPesquisa? modo,
    bool? carregando,
    ResultadoBusca? resultado,
    bool limparResultado = false,
    EvidenciaErro? erro,
    bool limparErro = false,
    String? sugestaoTermo,
    bool limparSugestao = false,
    OrdemBusca? ordem,
    FiltrosBusca? filtros,
    Map<String, List<SecaoResumo>>? secoes,
    Map<String, bool>? carregandoAbstract,
    List<ItemHistorico>? historico,
    List<PassoAgente>? passos,
    Pico? picoEditavel,
    String? consultaEfetiva,
    bool? viaProxy,
    String? motivoFallback,
    List<MensagemChat>? mensagens,
  }) {
    return EvidenciasState(
      termo: termo ?? this.termo,
      modo: modo ?? this.modo,
      carregando: carregando ?? this.carregando,
      resultado: limparResultado ? null : (resultado ?? this.resultado),
      erro: limparErro ? null : (erro ?? this.erro),
      sugestaoTermo:
          limparSugestao ? null : (sugestaoTermo ?? this.sugestaoTermo),
      ordem: ordem ?? this.ordem,
      filtros: filtros ?? this.filtros,
      secoes: secoes ?? this.secoes,
      carregandoAbstract: carregandoAbstract ?? this.carregandoAbstract,
      historico: historico ?? this.historico,
      passos: passos ?? this.passos,
      picoEditavel: picoEditavel ?? this.picoEditavel,
      consultaEfetiva: consultaEfetiva ?? this.consultaEfetiva,
      viaProxy: viaProxy ?? this.viaProxy,
      motivoFallback: motivoFallback ?? this.motivoFallback,
      mensagens: mensagens ?? this.mensagens,
    );
  }
}

class EvidenciasController extends StateNotifier<EvidenciasState> {
  EvidenciasController(this._service, this._agente, this._chat, this._store)
      : super(EvidenciasState(historico: _store.historico()));

  final PubmedService _service;
  final AgenteEvidencias _agente;
  final ChatPesquisa _chat;
  final SessaoStore _store;

  static const int _porPagina = 20;

  StreamSubscription<PassoAgente>? _assinatura;
  StreamSubscription<AgentEvent>? _assinaturaChat;

  @override
  void dispose() {
    _assinatura?.cancel();
    _assinaturaChat?.cancel();
    super.dispose();
  }

  // ── Modo e filtros ──────────────────────────────────────────────────

  void trocarModo(ModoPesquisa m) => state = state.copyWith(modo: m);

  /// Trocar filtro refaz a busca imediatamente quando já há resultado — sem
  /// isso o usuário mexe nos filtros e a tela não reage, o que faz parecer que
  /// o filtro não funcionou.
  void aplicarFiltros(FiltrosBusca f) {
    state = state.copyWith(filtros: f);
    if (state.termo.isNotEmpty && state.modo == ModoPesquisa.busca) {
      buscar(state.termo);
    }
  }

  void limparFiltros() => aplicarFiltros(const FiltrosBusca());

  void ordenarPor(OrdemBusca o) {
    state = state.copyWith(ordem: o);
    if (state.termo.isNotEmpty) buscar(state.termo);
  }

  // ── Busca direta ────────────────────────────────────────────────────

  Future<void> buscar(String termo, {OrdemBusca? ordem}) async {
    final consulta = termo.trim();
    if (consulta.isEmpty) return;

    _assinatura?.cancel();
    state = state.copyWith(
      termo: consulta,
      modo: ModoPesquisa.busca,
      carregando: true,
      ordem: ordem ?? state.ordem,
      limparErro: true,
      limparSugestao: true,
      limparResultado: true,
      secoes: const {},
      passos: const [],
    );

    final efetiva = state.filtros.aplicar(consulta, anoAtual: _anoAtual);
    state = state.copyWith(consultaEfetiva: efetiva);

    try {
      final r = await _service.buscarComMetadados(
        efetiva,
        limite: _porPagina,
        ordem: state.ordem,
      );
      state = state.copyWith(
        carregando: false,
        resultado: r,
        viaProxy: _service.ultimoCaminho == CaminhoEvidencia.proxy,
        motivoFallback: _service.motivoFallback,
      );
      unawaited(_registrar(consulta, r.total, ModoPesquisa.busca));

      // Zero resultado costuma ser grafia, não ausência de literatura.
      // Perguntar ao ESpell custa uma chamada e evita o médico concluir que
      // "não existe estudo sobre isso".
      if (r.vazio) await _sugerirCorrecao(consulta);
    } on EvidenciaErro catch (e) {
      state = state.copyWith(carregando: false, erro: e);
    } catch (e) {
      state = state.copyWith(
        carregando: false,
        erro: EvidenciaErro('Falha inesperada: $e'),
      );
    }
  }

  Future<void> _sugerirCorrecao(String consulta) async {
    try {
      final sugestao = await _service.corrigirTermo(consulta);
      if (sugestao.isNotEmpty && sugestao != consulta) {
        state = state.copyWith(sugestaoTermo: sugestao);
      }
    } catch (_) {
      // Sugestão é conveniência: falhar nela não deve virar erro de tela.
    }
  }

  Future<void> carregarMais() async {
    final atual = state.resultado;
    if (atual == null || state.carregando || !atual.temMais) return;

    state = state.copyWith(carregando: true);
    try {
      final proxima = await _service.buscarComMetadados(
        state.consultaEfetiva.isEmpty ? state.termo : state.consultaEfetiva,
        limite: _porPagina,
        offset: atual.retstart + atual.pmids.length,
        ordem: state.ordem,
      );
      state = state.copyWith(
        carregando: false,
        resultado: ResultadoBusca(
          total: proxima.total,
          pmids: [...atual.pmids, ...proxima.pmids],
          queryEnviada: atual.queryEnviada,
          queryTraduzida: atual.queryTraduzida,
          artigos: [...atual.artigos, ...proxima.artigos],
          retstart: atual.retstart,
          doCache: proxima.doCache,
          buscadoEm: atual.buscadoEm,
          viaProxy: atual.viaProxy,
        ),
      );
    } on EvidenciaErro catch (e) {
      state = state.copyWith(carregando: false, erro: e);
    }
  }

  /// Carrega o resumo de um artigo sob demanda (ao expandir o card).
  ///
  /// Sob demanda porque o EFetch de 20 artigos traz centenas de KB que o médico
  /// raramente lê inteiros — e cada chamada consome cota do NCBI.
  Future<void> carregarAbstract(String pmid) async {
    if (state.secoes.containsKey(pmid)) return;
    if (state.carregandoAbstract[pmid] == true) return;

    state = state.copyWith(
      carregandoAbstract: {...state.carregandoAbstract, pmid: true},
    );
    try {
      final mapa = await _service.abstracts([pmid]);
      state = state.copyWith(
        secoes: {...state.secoes, pmid: mapa[pmid] ?? const []},
        carregandoAbstract: {...state.carregandoAbstract, pmid: false},
      );
    } catch (_) {
      state = state.copyWith(
        secoes: {...state.secoes, pmid: const []},
        carregandoAbstract: {...state.carregandoAbstract, pmid: false},
      );
    }
  }

  // ── Modo agente ─────────────────────────────────────────────────────

  /// Roda o agente sobre uma pergunta em português.
  ///
  /// Os passos chegam por `Stream` e vão para o estado um a um: o usuário vê a
  /// pesquisa acontecendo — inclusive a consulta sendo reescrita — em vez de
  /// encarar um spinner por meio minuto.
  Future<void> perguntar(String pergunta, {Pico? pico}) async {
    final p = pergunta.trim();
    if (p.isEmpty) return;

    await _assinatura?.cancel();
    state = state.copyWith(
      termo: p,
      modo: ModoPesquisa.agente,
      carregando: true,
      limparErro: true,
      limparResultado: true,
      passos: const [],
      secoes: const {},
    );

    final completo = Completer<void>();
    _assinatura = _agente
        .pesquisar(p, picoInicial: pico, anoAtual: _anoAtual)
        .listen(
      (passo) {
        final lista = [...state.passos];
        // Um passo em andamento é substituído pelo definitivo do mesmo tipo,
        // em vez de empilhar dois cartões dizendo quase a mesma coisa.
        if (lista.isNotEmpty &&
            lista.last.emAndamento &&
            lista.last.tipo == passo.tipo) {
          lista.removeLast();
        }
        lista.add(passo);

        state = state.copyWith(
          passos: lista,
          picoEditavel: passo.tipo == TipoPasso.pico
              ? Pico.doJson(passo.dados)
              : state.picoEditavel,
          erro: passo.eErro
              ? EvidenciaErro(passo.detalhe ?? passo.titulo, codigo: 'AGENTE')
              : null,
        );
      },
      onError: (Object e) {
        state = state.copyWith(
          carregando: false,
          erro: EvidenciaErro('O agente falhou: $e', codigo: 'AGENTE'),
        );
        if (!completo.isCompleted) completo.complete();
      },
      onDone: () {
        state = state.copyWith(
          carregando: false,
          viaProxy: _service.ultimoCaminho == CaminhoEvidencia.proxy,
          motivoFallback: _service.motivoFallback,
        );
        unawaited(_registrar(p, _totalDoAgente(), ModoPesquisa.agente));
        if (!completo.isCompleted) completo.complete();
      },
      cancelOnError: true,
    );
    return completo.future;
  }

  /// Refaz a pesquisa com o PICO corrigido pelo médico.
  Future<void> refazerComPico(Pico pico) =>
      perguntar(state.termo, pico: pico);

  void cancelar() {
    _assinatura?.cancel();
    _assinaturaChat?.cancel();
    state = state.copyWith(carregando: false);
  }

  // ── Chat de pesquisa ────────────────────────────────────────────────

  /// Envia um turno do chat.
  ///
  /// A resposta chega token a token e a mensagem é atualizada no lugar — o
  /// médico vê o texto nascendo em vez de encarar um spinner. A **validação
  /// das citações só roda no fim**, quando há texto completo para conferir;
  /// validar parcial marcaria como inventado um PMID que ainda está sendo
  /// escrito.
  Future<void> conversar(String pergunta) async {
    final p = pergunta.trim();
    if (p.isEmpty || state.carregando) return;

    await _assinaturaChat?.cancel();

    final usuario = MensagemChat(papel: ChatRole.user, texto: p);
    final resposta = MensagemChat(papel: ChatRole.assistant, streaming: true);
    state = state.copyWith(
      modo: ModoPesquisa.chat,
      carregando: true,
      limparErro: true,
      mensagens: [...state.mensagens, usuario, resposta],
    );

    // O histórico enviado ao modelo é só o que já está fechado: a mensagem em
    // construção não pode voltar como contexto dela mesma.
    final historico = state.mensagens
        .where((m) => !m.streaming)
        .map((m) => ChatMessage(role: m.papel, content: m.texto))
        .toList();

    final completo = Completer<void>();

    void atualizar(void Function(MensagemChat m) mudar) {
      final lista = [...state.mensagens];
      final i = lista.lastIndexWhere((m) => m.papel == ChatRole.assistant);
      if (i < 0) return;
      mudar(lista[i]);
      state = state.copyWith(mensagens: lista);
    }

    _assinaturaChat = _chat.enviar(historico).listen(
      (ev) {
        switch (ev) {
          case AgentThinking(:final toolName):
            atualizar((m) => m.ferramentas = [...m.ferramentas, toolName]);
          case AgentToken(:final text):
            atualizar((m) => m.texto += text);
          case AgentDone(:final text):
            atualizar((m) {
              if (text.isNotEmpty) m.texto = text;
              m.streaming = false;
              // A trava: nenhuma resposta vira mensagem sem passar por aqui.
              final v = _chat.validarResposta(m.texto);
              m.validacao = v;
              m.texto = _chat.validador.anotarInvalidas(m.texto, v);
              m.fontes = _chat.fontesDe(m.texto);
            });
          case AgentError(:final message):
            atualizar((m) {
              m.streaming = false;
              if (m.texto.isEmpty) m.texto = 'Não consegui responder: $message';
            });
          case AgentToolDone():
            break;
        }
      },
      onError: (Object e) {
        atualizar((m) {
          m.streaming = false;
          if (m.texto.isEmpty) m.texto = 'Falha na conversa: $e';
        });
        state = state.copyWith(carregando: false);
        if (!completo.isCompleted) completo.complete();
      },
      onDone: () {
        atualizar((m) => m.streaming = false);
        state = state.copyWith(
          carregando: false,
          viaProxy: _service.ultimoCaminho == CaminhoEvidencia.proxy,
          motivoFallback: _service.motivoFallback,
        );
        if (!completo.isCompleted) completo.complete();
      },
      cancelOnError: true,
    );
    return completo.future;
  }

  /// Limpa a conversa **e o acervo**. Os dois andam juntos: sem o acervo as
  /// citações antigas deixariam de conferir; sem limpar a conversa o modelo
  /// citaria artigos que a tela não mostra mais.
  void limparConversa() {
    _assinaturaChat?.cancel();
    _chat.acervo.clear();
    state = state.copyWith(mensagens: const [], carregando: false);
  }

  /// Quantos artigos distintos a conversa já recuperou.
  int get artigosNoAcervo => _chat.acervo.length;

  List<ArtigoPubmed> get acervo => _chat.acervo.values.toList();

  // ── Sessões ─────────────────────────────────────────────────────────

  /// Monta uma sessão a partir do estado atual.
  ///
  /// `null` quando não há o que salvar — botão de salvar sem pesquisa feita
  /// gravaria uma sessão vazia que só confunde a lista depois.
  SessaoPesquisa? montarSessao({String? titulo}) {
    final r = state.resultado;
    final resposta = state.respostaAgente;
    final temAlgo = (r != null && !r.vazio) ||
        resposta != null ||
        state.mensagens.isNotEmpty;
    if (!temAlgo) return null;

    // Os artigos vêm da fonte certa para cada modo: no chat é o acervo da
    // conversa inteira; no agente, o que ele leu; na busca, o resultado.
    final artigos = switch (state.modo) {
      ModoPesquisa.chat => _chat.acervo.values.toList(),
      ModoPesquisa.agente => _artigosDoAgente(resposta),
      ModoPesquisa.busca => r?.artigos ?? const [],
    };

    final sintese = resposta?.detalhe;
    final citados = sintese == null
        ? <String>[]
        : const CitacaoValidator().extrair(sintese).map((c) => c.pmid).toList();

    return SessaoPesquisa(
      id: 'ses_${DateTime.now().microsecondsSinceEpoch}',
      titulo: titulo?.trim().isNotEmpty == true
          ? titulo!.trim()
          : SessaoPesquisa.tituloDe(state.termo),
      pergunta: state.termo,
      consultaEnviada: state.consultaEfetiva.isEmpty
          ? (r?.queryEnviada ?? state.termo)
          : state.consultaEfetiva,
      queryTraduzida: r?.queryTraduzida ?? '',
      artigos: artigos,
      salvaEm: DateTime.now(),
      modo: chaveDoModo(state.modo),
      sintese: sintese,
      conversa: state.mensagens
          .map((m) => {
                'papel': m.doUsuario ? 'user' : 'assistant',
                'texto': m.texto,
              })
          .toList(),
      filtros: state.filtros,
      totalNoPubmed: r?.total ?? 0,
      viaProxy: state.viaProxy,
      pmidsCitados: citados,
    );
  }

  List<ArtigoPubmed> _artigosDoAgente(PassoAgente? resposta) {
    final bruto = (resposta?.dados['artigos'] as List?) ?? const [];
    return bruto
        .whereType<Map>()
        .map((e) => ArtigoPubmed.doJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Recoloca a tela no estado de uma sessão salva.
  ///
  /// **Não refaz a busca.** Reexecutar devolveria outro conjunto (o PubMed
  /// indexa todo dia) e a síntese passaria a citar artigos que não estão mais
  /// na lista — quebrando exatamente a reprodutibilidade que a sessão existe
  /// para garantir. O que se lê é o que foi salvo.
  void restaurarSessao(SessaoPesquisa s) {
    _assinatura?.cancel();
    _assinaturaChat?.cancel();

    final modo = modoDaChave(s.modo);
    final resultado = ResultadoBusca(
      total: s.totalNoPubmed,
      pmids: s.artigos.map((a) => a.pmid).toList(),
      queryEnviada: s.consultaEnviada,
      queryTraduzida: s.queryTraduzida,
      artigos: s.artigos,
      buscadoEm: s.salvaEm,
      viaProxy: s.viaProxy,
    );

    // Os resumos salvos voltam para o mapa de seções: sem isso o card pediria
    // o resumo à rede de novo, e uma sessão antiga poderia nem carregar.
    final secoes = <String, List<SecaoResumo>>{};
    for (final a in s.artigos) {
      if (a.abstractSecoes != null) secoes[a.pmid] = a.abstractSecoes!;
    }

    state = state.copyWith(
      termo: s.pergunta,
      modo: modo,
      carregando: false,
      resultado: resultado,
      consultaEfetiva: s.consultaEnviada,
      filtros: s.filtros ?? const FiltrosBusca(),
      secoes: secoes,
      viaProxy: s.viaProxy,
      limparErro: true,
      limparSugestao: true,
      passos: s.temSintese
          ? [
              PassoAgente(
                tipo: TipoPasso.resposta,
                titulo: 'Resposta',
                detalhe: s.sintese,
                dados: {
                  'artigos': s.artigos.map((a) => a.paraJson()).toList(),
                  'validacao': {
                    'ok': true,
                    'naoCitados': s.artigos
                        .map((a) => a.pmid)
                        .where((p) => !s.pmidsCitados.contains(p))
                        .toList(),
                  },
                },
              ),
            ]
          : const [],
      mensagens: modo == ModoPesquisa.chat
          ? s.conversa
              .map((m) => MensagemChat(
                    papel: m['papel'] == 'user'
                        ? ChatRole.user
                        : ChatRole.assistant,
                    texto: m['texto'] ?? '',
                  ))
              .toList()
          : const [],
    );

    // O acervo do chat volta junto, senão as citações da conversa restaurada
    // apareceriam como não verificadas.
    if (modo == ModoPesquisa.chat) {
      _chat.acervo
        ..clear()
        ..addEntries(s.artigos.map((a) => MapEntry(a.pmid, a)));
    }
  }

  // ── Utilidades ──────────────────────────────────────────────────────

  /// Faz a próxima consulta tentar o proxy de novo (o usuário pode ter
  /// publicado a function no meio da sessão).
  void reavaliarConexao() {
    _service.reavaliarProxy();
    state = state.copyWith(viaProxy: true, motivoFallback: null);
  }

  /// Registra a busca no histórico persistente.
  ///
  /// Não bloqueia o resultado: a gravação acontece depois de a tela já ter
  /// mostrado os artigos. Histórico é conveniência — atrasar o que a pessoa
  /// pediu para gravar um rastro seria a troca errada.
  Future<void> _registrar(String termo, int total, ModoPesquisa modo) async {
    final lista = await _store.registrar(ItemHistorico(
      termo: termo,
      total: total,
      quando: DateTime.now(),
      modo: chaveDoModo(modo),
    ));
    if (mounted) state = state.copyWith(historico: lista);
  }

  Future<void> limparHistorico() async {
    await _store.limparHistorico();
    state = state.copyWith(historico: const []);
  }

  /// Total que a estratégia final do agente encontrou, para o histórico.
  int _totalDoAgente() {
    for (final passo in state.passos.reversed) {
      final t = passo.dados['total'];
      if (t is int) return t;
    }
    return 0;
  }

  void limpar() => state = EvidenciasState(historico: state.historico);

  int get _anoAtual => DateTime.now().year;
}

final evidenciasControllerProvider =
    StateNotifierProvider<EvidenciasController, EvidenciasState>((ref) {
  return EvidenciasController(
    ref.watch(pubmedServiceProvider),
    ref.watch(agenteEvidenciasProvider),
    ref.watch(chatPesquisaProvider),
    ref.watch(sessaoStoreProvider),
  );
});
