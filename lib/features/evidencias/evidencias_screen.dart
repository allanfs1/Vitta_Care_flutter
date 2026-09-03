import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/textos.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/platform_share.dart';
import '../../core/widgets/async_states.dart';
import 'evidencias_providers.dart';
import 'widgets/artigo_card.dart';
import 'widgets/barra_pesquisa.dart';
import 'widgets/estados_vazios.dart';
import 'widgets/painel_agente.dart';
import 'widgets/painel_chat.dart';
import 'widgets/painel_filtros.dart';
import 'widgets/painel_sessoes.dart';

/// Módulo Evidências — pesquisa de literatura científica no PubMed.
///
/// ## Dois modos, um propósito
///
/// **Busca** é a consulta Entrez com filtros: rápida, previsível, para quem já
/// sabe o que procura. **Pergunta (IA)** recebe português corrente e conduz uma
/// revisão rápida — decompõe em PICO, calibra a estratégia, lê os resumos e
/// sintetiza citando.
///
/// Os dois existem porque servem a momentos diferentes: triar literatura de um
/// tema conhecido não é a mesma tarefa que responder a uma dúvida clínica na
/// frente do paciente.
///
/// A tela é organizada para **verificar**, não só ler: cada resultado mostra
/// desenho do estudo e ano em destaque, e a consulta realmente enviada ao
/// PubMed fica visível. Ver `.specify/EVIDENCIAS.md` §8.
class EvidenciasScreen extends ConsumerStatefulWidget {
  const EvidenciasScreen({super.key});

  @override
  ConsumerState<EvidenciasScreen> createState() => _EvidenciasScreenState();
}

class _EvidenciasScreenState extends ConsumerState<EvidenciasScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _filtrosAbertos = false;

  /// O aviso de caminho direto já foi dispensado nesta sessão.
  ///
  /// Ele informa uma vez e sai. Mantê-lo fixo custava uma faixa da tela em
  /// **toda** busca para repetir algo que não muda e que o médico não pode
  /// resolver — o lugar dessa informação, depois de lida, é o painel
  /// "Como pesquisamos", que já registra a origem de cada consulta.
  bool _avisoDispensado = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_aoRolar);
  }

  @override
  void dispose() {
    _scroll.removeListener(_aoRolar);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _aoRolar() {
    if (!_scroll.hasClients) return;
    // Paginação só existe na busca. No chat e no agente a lista é a conversa,
    // e chamar carregarMais ali dispararia uma busca do nada ao rolar.
    if (ref.read(evidenciasControllerProvider).modo != ModoPesquisa.busca) {
      return;
    }
    final perto =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400;
    if (perto) ref.read(evidenciasControllerProvider.notifier).carregarMais();
  }

  void _enviar([String? texto]) {
    final t = (texto ?? _controller.text).trim();
    if (t.isEmpty) return;
    if (texto != null) _controller.text = texto;
    FocusScope.of(context).unfocus();

    final ctrl = ref.read(evidenciasControllerProvider.notifier);
    switch (ref.read(evidenciasControllerProvider).modo) {
      case ModoPesquisa.agente:
        ctrl.perguntar(t);
      case ModoPesquisa.chat:
        // O campo esvazia: num chat, o texto enviado já está na conversa, e
        // deixá-lo no campo faz o usuário apagar antes de cada pergunta.
        _controller.clear();
        ctrl.conversar(t).then((_) => _irParaOFim());
      case ModoPesquisa.busca:
        ctrl.buscar(t);
    }
  }

  /// Rola para a resposta mais recente do chat.
  void _irParaOFim() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(evidenciasControllerProvider);
    final ctrl = ref.read(evidenciasControllerProvider.notifier);
    final t = context.txt;
    final largura = MediaQuery.sizeOf(context).width;
    final amplo = largura >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('evid.titulo')),
        actions: [
          // Salvar só aparece quando há o que salvar — botão morto ensina o
          // usuário a ignorar a barra.
          if (estado.temResultado ||
              estado.respostaAgente != null ||
              estado.mensagens.isNotEmpty)
            IconButton(
              tooltip: t.t('evid.sessao.salvar'),
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: () => salvarSessaoDialogo(context, ref),
            ),
          IconButton(
            tooltip: t.t('evid.sessao.salvas'),
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => PainelSessoes.abrir(context, (sessao) {
              ctrl.restaurarSessao(sessao);
              _controller.text = sessao.pergunta;
              setState(() => _filtrosAbertos = false);
            }),
          ),
          if (estado.modo == ModoPesquisa.chat && estado.mensagens.isNotEmpty)
            IconButton(
              tooltip: 'Nova conversa',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () {
                ctrl.limparConversa();
                _controller.clear();
              },
            ),
          if (estado.historico.isNotEmpty)
            IconButton(
              tooltip: 'Buscas recentes',
              icon: const Icon(Icons.history),
              onPressed: () => _abrirHistorico(context),
            ),
          IconButton(
            tooltip: 'Como escrever a busca',
            icon: const Icon(Icons.help_outline),
            onPressed: () => mostrarAjudaBusca(context),
          ),
        ],
      ),
      body: Column(
        children: [
          BarraPesquisa(
            controller: _controller,
            estado: estado,
            filtrosAbertos: _filtrosAbertos,
            onEnviar: _enviar,
            onModo: ctrl.trocarModo,
            onOrdem: ctrl.ordenarPor,
            onAlternarFiltros: () =>
                setState(() => _filtrosAbertos = !_filtrosAbertos),
          ),
          // Flexible: o painel cede espaço quando a tela é baixa, em vez de
          // empurrar o resultado para fora da Column. A rolagem interna dele
          // cuida do que não couber.
          if (_filtrosAbertos && estado.modo == ModoPesquisa.busca)
            Flexible(
              child: PainelFiltros(
                filtros: estado.filtros,
                onMudar: ctrl.aplicarFiltros,
                onLimpar: ctrl.limparFiltros,
              ),
            ),
          if (!estado.viaProxy && !_avisoDispensado)
            _AvisoCaminhoDireto(
              motivo: estado.motivoFallback,
              onDispensar: () => setState(() => _avisoDispensado = true),
              onTentarProxy: () {
                setState(() => _avisoDispensado = true);
                ctrl.reavaliarConexao();
                if (estado.termo.isNotEmpty) _enviar(estado.termo);
              },
            ),
          Expanded(child: _corpo(estado, amplo)),
        ],
      ),
    );
  }

  Widget _corpo(EvidenciasState e, bool amplo) {
    if (e.modo == ModoPesquisa.chat) {
      return PainelChat(
        estado: e,
        scroll: _scroll,
        onSugestao: _enviar,
        onExpandirArtigo: (pmid) => ref
            .read(evidenciasControllerProvider.notifier)
            .carregarAbstract(pmid),
      );
    }

    if (e.modo == ModoPesquisa.agente && e.passos.isNotEmpty) {
      return PainelAgente(
        estado: e,
        scroll: _scroll,
        onRefazerPico: (p) =>
            ref.read(evidenciasControllerProvider.notifier).refazerComPico(p),
        onExpandirArtigo: (pmid) => ref
            .read(evidenciasControllerProvider.notifier)
            .carregarAbstract(pmid),
      );
    }

    if (e.erro != null) {
      return ErroEvidencias(
        erro: e.erro!,
        onTentarNovamente:
            e.erro!.bloqueadoPorDadoPessoal ? null : () => _enviar(e.termo),
      );
    }

    if (e.carregando && e.resultado == null) {
      return e.modo == ModoPesquisa.agente
          ? const LoadingView()
          : const EsqueletoResultados();
    }

    if (e.resultado == null) {
      return IntroEvidencias(
        modo: e.modo,
        onExemplo: _enviar,
        historico: e.historico,
      );
    }

    if (e.buscaVazia) {
      return SemResultado(
        termo: e.termo,
        sugestao: e.sugestaoTermo,
        queryTraduzida: e.resultado!.queryTraduzida,
        filtrosAtivos: e.filtros.quantidadeAtiva,
        onUsarSugestao: _enviar,
        onLimparFiltros:
            ref.read(evidenciasControllerProvider.notifier).limparFiltros,
      );
    }

    final r = e.resultado!;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.symmetric(
        horizontal: amplo ? AppSpacing.xxl : AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      // +2: cabeçalho de resumo e rodapé de paginação.
      itemCount: r.artigos.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return ResumoBusca(resultado: r, filtros: e.filtros);
        if (i == r.artigos.length + 1) {
          return RodapeResultados(resultado: r, carregando: e.carregando);
        }
        final artigo = r.artigos[i - 1];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ArtigoCard(
              artigo: artigo,
              indice: i,
              secoes: e.secoes[artigo.pmid],
              carregandoAbstract: e.carregandoAbstract[artigo.pmid] == true,
              onExpandir: () => ref
                  .read(evidenciasControllerProvider.notifier)
                  .carregarAbstract(artigo.pmid),
            ),
          ),
        );
      },
    );
  }

  void _abrirHistorico(BuildContext context) {
    final estado = ref.read(evidenciasControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.txt.t('evid.hist.titulo'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref
                          .read(evidenciasControllerProvider.notifier)
                          .limparHistorico();
                    },
                    child: Text(context.txt.t('evid.hist.limpar')),
                  ),
                ],
              ),
            ),
            for (final h in estado.historico)
              ListTile(
                leading: Icon(
                  switch (h.modo) {
                    'agente' => Icons.auto_awesome,
                    'chat' => Icons.forum_outlined,
                    _ => Icons.search,
                  },
                  size: 20,
                ),
                title: Text(h.termo, maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    context.txt.t2('evid.hist.resultados', {'n': '${h.total}'})),
                onTap: () {
                  Navigator.of(context).pop();
                  ref
                      .read(evidenciasControllerProvider.notifier)
                      .trocarModo(modoDaChave(h.modo));
                  _enviar(h.termo);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de que a consulta saiu pelo caminho direto ao NCBI.
///
/// ## Três decisões sobre este aviso
///
/// **Sem jargão.** A versão anterior dizia "o proxy de evidências não respondeu
/// (rede ou CORS)". "CORS" não significa nada para um médico, e "proxy" não é
/// problema dele. O detalhe técnico continua existindo — em
/// `motivoFallback`, que vai para o log e para o painel de diagnóstico — mas
/// não na faixa que ocupa a tela de quem está atendendo.
///
/// **Dispensável.** Informa uma vez e sai. Fixo, custava uma faixa em toda
/// busca para repetir algo que não muda e que o médico não pode resolver.
///
/// **Discreto.** Fundo neutro e ícone pequeno, não a cor de destaque do tema.
/// A busca **está funcionando**; um alerta forte diria o contrário.
///
/// A informação não se perde ao ser dispensada: "Como pesquisamos" registra a
/// origem de cada consulta.
class _AvisoCaminhoDireto extends StatelessWidget {
  const _AvisoCaminhoDireto({
    this.motivo,
    required this.onTentarProxy,
    required this.onDispensar,
  });

  /// Causa técnica — só para o tooltip de diagnóstico.
  final String? motivo;
  final VoidCallback onTentarProxy;
  final VoidCallback onDispensar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
            child: Row(
              children: [
                Tooltip(
                  message: motivo ?? 'Serviço interno indisponível.',
                  child: Icon(Icons.info_outline,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.txt.t('evid.direto.aviso'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onTentarProxy,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(context.txt.t('evid.direto.reconectar')),
                ),
                IconButton(
                  tooltip: context.txt.t('evid.direto.dispensar'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                  onPressed: onDispensar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Utilidades compartilhadas ───────────────────────

/// Abre uma URL externa.
///
/// **Limitação conhecida.** `openExternalUrl` só tem implementação em web
/// (`platform_share_web.dart`); no stub das demais plataformas é no-op — o
/// projeto não usa `url_launcher` (ver `clinic_map_stub.dart`, que registra a
/// mesma escolha). Em vez de o toque não fazer nada, aqui fora da web o link
/// vai para a área de transferência e o usuário é avisado. Adicionar
/// `url_launcher` resolveria de vez; ver `.specify/EVIDENCIAS.md` §9.
Future<void> abrirUrl(BuildContext context, String url) async {
  if (url.isEmpty) return;
  if (kIsWeb) {
    openExternalUrl(url);
    return;
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
        content: Text('Link copiado — cole no navegador para abrir.')),
  );
}

/// Copia [texto] e avisa via SnackBar.
Future<void> copiar(BuildContext context, String texto, String rotulo) async {
  await Clipboard.setData(ClipboardData(text: texto));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$rotulo copiado.')),
  );
}
