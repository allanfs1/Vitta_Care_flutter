import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../data/models/aresta.dart';
import '../data/models/nota.dart';
import '../data/models/nota_enums.dart';
import '../data/nota_repository.dart';
import '../graph/grafo_builder.dart';
import '../graph/grafo_modelo.dart';
import '../index/busca_service.dart';
import '../index/parser/parser_vfm.dart';
import '../index/vault_index.dart';

/// Mapa de estado do Cérebro (`obsidian.md` §12).
///
/// Regras que o módulo respeita:
///  - `vaultIndexProvider` é caro de reconstruir → vive dentro do notifier.
///  - Toda escrita passa pelo [VaultNotifier], nunca direto do widget.
///  - O grafo NÃO guarda posições em provider: elas ficam no `GrafoEngine`,
///    que notifica o painter via `repaint:` (regra 3 de §12).

// ── Repositório ─────────────────────────────────────────────────────────────

final notaRepositoryProvider = Provider<NotaRepository>((ref) {
  // Sem Firebase (modo demonstração) o vault vive em memória — o módulo
  // funciona igual, com o mesmo contrato de versão (§8 P8: degradação graciosa).
  final comFirebase = ref.watch(firebaseEnabledProvider);
  return comFirebase ? FirestoreNotaRepository() : MemoriaNotaRepository();
});

// ── Vault ───────────────────────────────────────────────────────────────────

class VaultEstado {
  const VaultEstado({
    required this.index,
    this.carregando = true,
    this.erro,
    this.revisao = 0,
    this.salvando = false,
    this.aguardandoClinica = false,
    this.progresso,
  });

  final VaultIndex index;
  final bool carregando;
  final String? erro;

  /// Incrementado a cada mutação — é o sinal de invalidação para os widgets
  /// (o índice em si é mutável por performance).
  final int revisao;
  final bool salvando;

  /// A clínica ativa ainda não foi resolvida (ver [clinicaVaultProvider]).
  /// Um vault sem clínica não é um vault vazio: é um vault que ainda não sabe
  /// de quem é — e a UI precisa dizer isso, não oferecer "criar nota".
  final bool aguardandoClinica;

  /// Fração indexada (0..1) durante o boot, ou nulo fora dele. Alimenta o
  /// esqueleto de carregamento — um vault grande leva mais de um frame e a
  /// tela deve mostrar avanço em vez de parecer travada.
  final double? progresso;

  bool get vazio =>
      !carregando && !aguardandoClinica && index.totalNotas == 0;

  VaultEstado copyWith({
    bool? carregando,
    String? erro,
    int? revisao,
    bool? salvando,
    bool? aguardandoClinica,
    double? progresso,
    bool limparProgresso = false,
    bool limparErro = false,
  }) =>
      VaultEstado(
        index: index,
        carregando: carregando ?? this.carregando,
        erro: limparErro ? null : (erro ?? this.erro),
        revisao: revisao ?? this.revisao,
        salvando: salvando ?? this.salvando,
        aguardandoClinica: aguardandoClinica ?? this.aguardandoClinica,
        progresso: limparProgresso ? null : (progresso ?? this.progresso),
      );
}

class VaultNotifier extends StateNotifier<VaultEstado> {
  VaultNotifier(this._ref, this._repo, this.clinicaId)
      : super(VaultEstado(
          index: VaultIndex(),
          carregando: clinicaId.isNotEmpty,
          aguardandoClinica: clinicaId.isEmpty,
        )) {
    if (clinicaId.isNotEmpty) carregar();
  }

  final Ref _ref;
  final NotaRepository _repo;
  final String clinicaId;

  static const _parser = ParserVFM();

  String get _autor => _ref.read(authProvider).email ?? 'usuario';

  VaultIndex get index => state.index;

  Future<void> carregar() async {
    state = state.copyWith(carregando: true, limparErro: true);
    try {
      // Sem auto-seed. Antes, um vault com ≤1 nota disparava `popularDemo(1200)`
      // — que no Firestore é escrita de verdade. Bastava uma leitura falhar
      // (índice ausente) ou o boot pegar a clínica placeholder para o banco da
      // clínica ganhar 1.200 notas sintéticas. Carga de demonstração agora só
      // acontece por ação explícita do usuário (§18.3).
      final notas = await _repo.carregarTodas(clinicaId);
      index.limpar();
      await _indexarCedendo(notas);
      state = state.copyWith(
        carregando: false,
        revisao: state.revisao + 1,
        limparErro: true,
        limparProgresso: true,
      );
    } catch (e) {
      state = state.copyWith(carregando: false, erro: e.toString());
    }
  }

  /// Popula o vault com um volume sintético realista (§18.3) e reindexa.
  /// Devolve quantas notas o vault passou a ter.
  Future<int> popularDemo({int alvo = 1200}) async {
    state = state.copyWith(carregando: true, limparErro: true);
    try {
      final notas = await _repo.popularDemo(clinicaId, alvo);
      await _indexarCedendo(notas);
      state = state.copyWith(
        carregando: false,
        revisao: state.revisao + 1,
        limparErro: true,
        limparProgresso: true,
      );
      return index.totalNotas;
    } catch (e) {
      state = state.copyWith(carregando: false, erro: e.toString());
      rethrow;
    }
  }

  /// Parseia e indexa cedendo a thread entre os lotes.
  ///
  /// O trabalho total é o mesmo — o que muda é que a UI consegue desenhar entre
  /// um lote e outro. Sem isso um vault grande congela a tela por todo o boot,
  /// que é exatamente a sensação de "a página está pesada" mesmo depois de a
  /// indexação em si ter ficado ~75× mais rápida.
  ///
  /// O lote é grande o bastante para o overhead de ceder ser irrelevante e
  /// pequeno o bastante para caber com folga num frame.
  static const int _loteIndexacao = 200;

  Future<void> _indexarCedendo(List<Nota> notas) async {
    if (notas.isEmpty) {
      index.atualizarGraus();
      return;
    }

    Future<void> ceder(double fracao) {
      if (mounted) state = state.copyWith(progresso: fracao);
      return Future<void>.delayed(Duration.zero);
    }

    // Fase A — parse.
    final asts = <NotaAst>[];
    for (var i = 0; i < notas.length; i += _loteIndexacao) {
      final fim = (i + _loteIndexacao).clamp(0, notas.length);
      for (var j = i; j < fim; j++) {
        asts.add(_parser.parse(notas[j].conteudo));
      }
      if (fim < notas.length) await ceder(0.5 * fim / notas.length);
    }

    // Fase B — registro das chaves (nenhum link resolvido ainda).
    final registradas = <Nota>[];
    for (var i = 0; i < notas.length; i += _loteIndexacao) {
      final fim = (i + _loteIndexacao).clamp(0, notas.length);
      registradas.addAll(index.registrarFaixa(notas, asts, i, fim));
      if (fim < notas.length) await ceder(0.5 + 0.25 * fim / notas.length);
    }

    // Fase C — resolução das arestas, agora que todas as chaves existem.
    for (var i = 0; i < registradas.length; i += _loteIndexacao) {
      final fim = (i + _loteIndexacao).clamp(0, registradas.length);
      index.resolverFaixa(registradas, asts, i, fim);
      if (fim < registradas.length) {
        await ceder(0.75 + 0.25 * fim / registradas.length);
      }
    }

    index.atualizarGraus();
  }

  /// Quantas notas do vault vieram da carga de demonstração.
  int get totalDemo => index.notas.values
      .where((n) => !n.excluida && n.id.startsWith(prefixoDemo))
      .length;

  /// Remove fisicamente a carga de demonstração e reindexa o que sobrou.
  /// Devolve quantas notas foram apagadas.
  Future<int> limparDemo() async {
    state = state.copyWith(carregando: true, limparErro: true);
    try {
      final removidas = await _repo.limparDemo(clinicaId);
      await carregar();
      return removidas;
    } catch (e) {
      state = state.copyWith(carregando: false, erro: e.toString());
      rethrow;
    }
  }

  /// Cria uma nota nova e devolve seu id.
  Future<String> criar({
    required String path,
    String conteudo = '',
    NotaTipo tipo = NotaTipo.nota,
    NotaOrigem origem = NotaOrigem.humano,
  }) async {
    final caminho = _normalizarPath(path);
    final existente = index.porPath(caminho);
    if (existente != null) return existente.id;

    final id = 'nt_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final titulo = caminho.split('/').last.replaceAll('.md', '');
    final corpo = conteudo.isEmpty ? '# $titulo\n\n' : conteudo;

    final nota = Nota(
      id: id,
      clinicaId: clinicaId,
      path: caminho,
      titulo: titulo,
      tipo: tipo,
      conteudo: corpo,
      origem: origem,
      createdBy: _autor,
      updatedBy: _autor,
      versao: 0,
    );
    await _persistir(nota);
    return id;
  }

  /// Atualiza o corpo de uma nota (chamada pelo editor, com debounce).
  Future<void> salvarConteudo(String notaId, String conteudo) async {
    final atual = index.porId(notaId);
    if (atual == null) return;
    if (atual.conteudo == conteudo) return;
    await _persistir(atual.copyWith(conteudo: conteudo));
  }

  Future<void> alternarFixada(String notaId) async {
    final n = index.porId(notaId);
    if (n == null) return;
    await _persistir(n.copyWith(fixada: !n.fixada));
  }

  Future<void> alternarFavorita(String notaId) async {
    final n = index.porId(notaId);
    if (n == null) return;
    await _persistir(n.copyWith(favorita: !n.favorita));
  }

  Future<void> arquivar(String notaId) async {
    final n = index.porId(notaId);
    if (n == null) return;
    await _persistir(n.copyWith(
      estado: n.arquivada ? NotaEstado.publicada : NotaEstado.arquivada,
    ));
  }

  Future<void> excluir(String notaId) async {
    await _repo.excluir(notaId);
    index.remover(notaId);
    index.atualizarGraus();
    state = state.copyWith(revisao: state.revisao + 1);
  }

  /// Renomeia/move uma nota **reescrevendo em cascata** todos os wikilinks que
  /// apontavam para ela (§6.4). Devolve quantas notas foram alteradas.
  Future<int> renomear(String notaId, String novoPath) async {
    final nota = index.porId(notaId);
    if (nota == null) return 0;
    final destino = _normalizarPath(novoPath);
    if (destino == nota.path) return 0;
    if (index.porPath(destino) != null) {
      throw const CerebroException('Já existe uma nota nesse caminho.');
    }

    final tituloAntigo = nota.titulo;
    final novoTitulo = destino.split('/').last.replaceAll('.md', '');

    // Notas que referenciam esta.
    final entrantes = index.backlinks(notaId);
    final origens = entrantes.map((a) => a.de).toSet();

    var alteradas = 0;
    for (final origemId in origens) {
      final origem = index.porId(origemId);
      if (origem == null || !origem.corpoCarregado) continue;
      final novoCorpo = _reescreverLinks(
        origem.conteudo,
        alvosAntigos: {
          nota.path,
          nota.path.replaceAll('.md', ''),
          nota.nomeArquivo,
          tituloAntigo,
          ...nota.aliases,
        },
        novoAlvo: destino.replaceAll('.md', ''),
      );
      if (novoCorpo == origem.conteudo) continue;
      await _persistir(origem.copyWith(conteudo: novoCorpo), notificar: false);
      alteradas++;
    }

    await _persistir(nota.copyWith(path: destino, titulo: novoTitulo));
    return alteradas;
  }

  /// Insere um wikilink para [destino] no fim da nota [origemId] — usado por
  /// "Vincular" nas menções não-vinculadas e nas sugestões semânticas.
  Future<void> vincular(String origemId, String destino) async {
    final origem = index.porId(origemId);
    if (origem == null) return;
    final corpo = origem.conteudo.trimRight();
    final novo = '$corpo\n\n[[$destino]]\n';
    await _persistir(origem.copyWith(conteudo: novo));
  }

  Future<void> _persistir(Nota nota, {bool notificar = true}) async {
    // Escrever sem clínica resolvida é o que espalhava notas por uma clínica
    // fantasma e as fazia sumir no boot seguinte. Melhor falhar visível.
    if (clinicaId.isEmpty) {
      const erro = CerebroException(
        'A clínica ativa ainda não carregou — aguarde para salvar.',
      );
      state = state.copyWith(salvando: false, erro: erro.mensagem);
      throw erro;
    }
    if (notificar) state = state.copyWith(salvando: true, limparErro: true);
    try {
      final salva = await _repo.salvar(nota, autor: _autor);
      index.indexar(salva, _parser.parse(salva.conteudo));
      index.atualizarGraus();
      if (notificar) {
        state = state.copyWith(
          salvando: false,
          revisao: state.revisao + 1,
          limparErro: true,
        );
      }
    } on CerebroException catch (e) {
      state = state.copyWith(salvando: false, erro: e.mensagem);
      rethrow;
    } catch (e) {
      state = state.copyWith(salvando: false, erro: 'Falha ao salvar: $e');
      rethrow;
    }
  }

  static String _normalizarPath(String bruto) {
    var p = bruto.trim().replaceAll('\\', '/');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    if (!p.toLowerCase().endsWith('.md')) p = '$p.md';
    return p;
  }

  /// Reescreve `[[alvo]]`, `[[alvo|alias]]`, `[[alvo#sec]]` preservando alias,
  /// âncora e bloco.
  static String _reescreverLinks(
    String corpo, {
    required Set<String> alvosAntigos,
    required String novoAlvo,
  }) {
    final normalizados = {
      for (final a in alvosAntigos)
        if (a.trim().isNotEmpty) chaveNormalizada(a),
    };
    return corpo.replaceAllMapped(
      RegExp(r'(!?)\[\[([^\[\]]+?)\]\]'),
      (m) {
        final bang = m.group(1) ?? '';
        final interno = m.group(2)!;
        final pipe = interno.indexOf('|');
        final alvoParte = (pipe >= 0 ? interno.substring(0, pipe) : interno).trim();
        final sufixo = pipe >= 0 ? interno.substring(pipe) : '';

        var alvo = alvoParte;
        var extra = '';
        final hash = alvo.indexOf('#');
        if (hash >= 0) {
          extra = alvo.substring(hash);
          alvo = alvo.substring(0, hash);
        }
        if (!normalizados.contains(chaveNormalizada(alvo.trim()))) {
          return m.group(0)!;
        }
        return '$bang[[$novoAlvo$extra$sufixo]]';
      },
    );
  }
}

/// Clínica que serve de chave do vault — e só ela.
///
/// Delega a [clinicaResolvidaProvider]: enquanto a clínica do boot for o
/// placeholder de `MockData`, o vault espera em vez de ler e gravar em uma
/// clínica que não existe no Firestore. Era isso que deixava notas órfãs em
/// `'c1'` e abria o Cérebro vazio na sessão seguinte.
final clinicaVaultProvider = Provider<String>(
    (ref) => ref.watch(clinicaResolvidaProvider));

final vaultProvider =
    StateNotifierProvider<VaultNotifier, VaultEstado>((ref) {
  final clinicaId = ref.watch(clinicaVaultProvider);
  final repo = ref.watch(notaRepositoryProvider);
  return VaultNotifier(ref, repo, clinicaId);
});

/// Serviço de busca — reconstruído a cada revisão do vault.
final buscaServiceProvider = Provider<BuscaService>((ref) {
  final estado = ref.watch(vaultProvider);
  return BuscaService(estado.index);
});

/// Nota por id (reativa às revisões do vault).
final notaProvider = Provider.family<Nota?, String>((ref, id) {
  ref.watch(vaultProvider);
  return ref.read(vaultProvider.notifier).index.porId(id);
});

// ── Abas / navegação interna ────────────────────────────────────────────────

class AbasEstado {
  const AbasEstado({this.abertas = const [], this.ativa = 0, this.historico = const []});

  final List<String> abertas;
  final int ativa;
  final List<String> historico;

  String? get notaAtiva =>
      abertas.isEmpty || ativa >= abertas.length ? null : abertas[ativa];
}

class AbasNotifier extends StateNotifier<AbasEstado> {
  AbasNotifier() : super(const AbasEstado());

  void abrir(String notaId) {
    final i = state.abertas.indexOf(notaId);
    if (i >= 0) {
      state = AbasEstado(
        abertas: state.abertas,
        ativa: i,
        historico: [...state.historico, notaId],
      );
      return;
    }
    state = AbasEstado(
      abertas: [...state.abertas, notaId],
      ativa: state.abertas.length,
      historico: [...state.historico, notaId],
    );
  }

  void fechar(String notaId) {
    final abertas = [...state.abertas]..remove(notaId);
    final ativa = state.ativa >= abertas.length ? abertas.length - 1 : state.ativa;
    state = AbasEstado(
      abertas: abertas,
      ativa: ativa < 0 ? 0 : ativa,
      historico: state.historico,
    );
  }

  void selecionar(int i) {
    if (i < 0 || i >= state.abertas.length) return;
    state = AbasEstado(
      abertas: state.abertas,
      ativa: i,
      historico: [...state.historico, state.abertas[i]],
    );
  }

  void voltar() {
    if (state.historico.length < 2) return;
    final h = [...state.historico]..removeLast();
    final anterior = h.last;
    final i = state.abertas.indexOf(anterior);
    state = AbasEstado(
      abertas: state.abertas,
      ativa: i >= 0 ? i : state.ativa,
      historico: h,
    );
  }

  void fecharTodas() => state = const AbasEstado();
}

final abasProvider =
    StateNotifierProvider<AbasNotifier, AbasEstado>((ref) => AbasNotifier());

final notaAtivaProvider = Provider<Nota?>((ref) {
  final id = ref.watch(abasProvider).notaAtiva;
  if (id == null) return null;
  return ref.watch(notaProvider(id));
});

// ── Layout ──────────────────────────────────────────────────────────────────

enum PainelEsquerdo { explorer, busca, tags, sugestoes, recentes }

enum VistaCentral { editor, grafo, analitico }

class LayoutEstado {
  const LayoutEstado({
    this.painelEsquerdo = PainelEsquerdo.explorer,
    this.esquerdoVisivel = true,
    this.direitoVisivel = true,
    this.grafoLocalVisivel = true,
    this.vista = VistaCentral.editor,
    this.larguraEsquerda = 280,
    this.larguraDireita = 320,
    this.modoLeitura = false,
    this.grafoTelaCheia = false,
  });

  final PainelEsquerdo painelEsquerdo;
  final bool esquerdoVisivel;
  final bool direitoVisivel;
  final bool grafoLocalVisivel;
  final VistaCentral vista;
  final double larguraEsquerda;
  final double larguraDireita;
  final bool modoLeitura;
  final bool grafoTelaCheia;

  LayoutEstado copyWith({
    PainelEsquerdo? painelEsquerdo,
    bool? esquerdoVisivel,
    bool? direitoVisivel,
    bool? grafoLocalVisivel,
    VistaCentral? vista,
    double? larguraEsquerda,
    double? larguraDireita,
    bool? modoLeitura,
    bool? grafoTelaCheia,
  }) =>
      LayoutEstado(
        painelEsquerdo: painelEsquerdo ?? this.painelEsquerdo,
        esquerdoVisivel: esquerdoVisivel ?? this.esquerdoVisivel,
        direitoVisivel: direitoVisivel ?? this.direitoVisivel,
        grafoLocalVisivel: grafoLocalVisivel ?? this.grafoLocalVisivel,
        vista: vista ?? this.vista,
        larguraEsquerda: larguraEsquerda ?? this.larguraEsquerda,
        larguraDireita: larguraDireita ?? this.larguraDireita,
        modoLeitura: modoLeitura ?? this.modoLeitura,
        grafoTelaCheia: grafoTelaCheia ?? this.grafoTelaCheia,
      );
}

class LayoutNotifier extends StateNotifier<LayoutEstado> {
  LayoutNotifier() : super(const LayoutEstado());

  void abrirPainel(PainelEsquerdo p) {
    if (state.painelEsquerdo == p && state.esquerdoVisivel) {
      state = state.copyWith(esquerdoVisivel: false);
    } else {
      state = state.copyWith(painelEsquerdo: p, esquerdoVisivel: true);
    }
  }

  void alternarEsquerdo() =>
      state = state.copyWith(esquerdoVisivel: !state.esquerdoVisivel);
  void alternarDireito() =>
      state = state.copyWith(direitoVisivel: !state.direitoVisivel);
  void alternarGrafoLocal() =>
      state = state.copyWith(grafoLocalVisivel: !state.grafoLocalVisivel);
  void alternarModoLeitura() =>
      state = state.copyWith(modoLeitura: !state.modoLeitura);
  void alternarGrafoTelaCheia() {
    final novo = !state.grafoTelaCheia;
    state = state.copyWith(
      grafoTelaCheia: novo,
      vista: novo ? VistaCentral.grafo : state.vista,
    );
  }
  void setGrafoTelaCheia(bool val) {
    state = state.copyWith(
      grafoTelaCheia: val,
      vista: val ? VistaCentral.grafo : state.vista,
    );
  }
  void irPara(VistaCentral v) =>
      state = state.copyWith(vista: v, grafoTelaCheia: false);
  void redimensionarEsquerda(double l) =>
      state = state.copyWith(larguraEsquerda: l.clamp(200, 420));
  void redimensionarDireita(double l) =>
      state = state.copyWith(larguraDireita: l.clamp(260, 460));
}

final layoutProvider =
    StateNotifierProvider<LayoutNotifier, LayoutEstado>((ref) => LayoutNotifier());

// ── Busca ───────────────────────────────────────────────────────────────────

final termoBuscaProvider = StateProvider<String>((_) => '');

final resultadosBuscaProvider = Provider<List<ResultadoBusca>>((ref) {
  final termo = ref.watch(termoBuscaProvider);
  if (termo.trim().isEmpty) return const [];
  return ref.watch(buscaServiceProvider).buscar(termo);
});

/// Filtro de tag aplicado ao Explorer (clique no painel de tags).
final filtroTagProvider = StateProvider<String?>((_) => null);

// ── Grafo ───────────────────────────────────────────────────────────────────

final configGrafoProvider =
    StateNotifierProvider<ConfigGrafoNotifier, ConfigGrafo>(
        (ref) => ConfigGrafoNotifier());

class ConfigGrafoNotifier extends StateNotifier<ConfigGrafo> {
  ConfigGrafoNotifier()
      : super(const ConfigGrafo(grupos: GrupoGrafo.padrao));

  void atualizar(ConfigGrafo Function(ConfigGrafo) f) => state = f(state);
  void restaurar() => state = const ConfigGrafo(grupos: GrupoGrafo.padrao);
}

final escopoGrafoProvider =
    StateProvider<GrafoEscopo>((_) => const GrafoEscopo.global());

/// Grafo montado para um escopo. Recalcula quando o vault ou a config mudam.
final grafoProvider =
    Provider.family<ResultadoGrafo, GrafoEscopo>((ref, escopo) {
  ref.watch(vaultProvider);
  final config = ref.watch(configGrafoProvider);
  final index = ref.read(vaultProvider.notifier).index;
  final busca = ref.watch(buscaServiceProvider);
  return GrafoBuilder(index, busca).construir(config: config, escopo: escopo);
});

/// Nó selecionado no grafo — dirige o inspector do modo analítico.
final noSelecionadoProvider = StateProvider<String?>((_) => null);

// ── Painel direito ──────────────────────────────────────────────────────────

class MencaoNaoVinculada {
  const MencaoNaoVinculada(this.nota, this.trecho, this.termo);

  final Nota nota;
  final String trecho;
  final String termo;
}

/// Menções textuais ao título/aliases de uma nota que ainda **não** são links
/// (§8.2). Implementação direta: varre o corpo das notas carregadas.
final mencoesNaoVinculadasProvider =
    Provider.family<List<MencaoNaoVinculada>, String>((ref, notaId) {
  ref.watch(vaultProvider);
  final index = ref.read(vaultProvider.notifier).index;
  final alvo = index.porId(notaId);
  if (alvo == null) return const [];

  final termos = <String>{
    alvo.titulo,
    ...alvo.aliases,
  }.where((t) => t.trim().length >= 4).map((t) => t.toLowerCase()).toSet();
  if (termos.isEmpty) return const [];

  final jaLinkam = index.backlinks(notaId).map((a) => a.de).toSet();
  final out = <MencaoNaoVinculada>[];

  for (final nota in index.notas.values) {
    if (nota.id == notaId || jaLinkam.contains(nota.id)) continue;
    if (!nota.corpoCarregado || nota.conteudo.isEmpty) continue;
    final corpoNormal = removerAcentos(nota.conteudo.toLowerCase());
    for (final termo in termos) {
      final t = removerAcentos(termo);
      final pos = corpoNormal.indexOf(t);
      if (pos < 0) continue;
      // Ignora ocorrências que já estão dentro de um [[...]].
      final antes = nota.conteudo.substring(
          (pos - 2).clamp(0, nota.conteudo.length), pos.clamp(0, nota.conteudo.length));
      if (antes.contains('[[')) continue;
      final de = (pos - 60).clamp(0, nota.conteudo.length);
      final ate = (pos + termo.length + 80).clamp(0, nota.conteudo.length);
      out.add(MencaoNaoVinculada(
        nota,
        '…${nota.conteudo.substring(de, ate).replaceAll(RegExp(r'\s+'), ' ').trim()}…',
        termo,
      ));
      break;
    }
    if (out.length >= 20) break;
  }
  return out;
});

/// Estatísticas exibidas na status bar (§10.10).
class EstatisticasVault {
  const EstatisticasVault({
    required this.notas,
    required this.links,
    required this.orfas,
    required this.quebrados,
    required this.tags,
  });

  final int notas;
  final int links;
  final int orfas;
  final int quebrados;
  final int tags;
}

final estatisticasProvider = Provider<EstatisticasVault>((ref) {
  ref.watch(vaultProvider);
  final index = ref.read(vaultProvider.notifier).index;
  return EstatisticasVault(
    notas: index.totalNotas,
    links: index.totalArestas,
    orfas: index.orfas.length,
    quebrados: index.linksQuebrados.length,
    tags: index.tags.length,
  );
});
