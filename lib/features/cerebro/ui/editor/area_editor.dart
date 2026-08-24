import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/nota.dart';
import '../../providers/cerebro_providers.dart';
import '../comum/acoes_cerebro.dart';
import '../comum/badge_origem.dart';
import '../comum/cerebro_ui.dart';
import '../comum/estados_vazios.dart';
import 'renderizador_vfm.dart';

/// Área central: abas, barra de contexto e editor/preview (`obsidian.md` §10.4).
class AreaEditor extends ConsumerWidget {
  const AreaEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abas = ref.watch(abasProvider);
    final nota = ref.watch(notaAtivaProvider);

    return Container(
      color: AppColors.surfaceOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (abas.abertas.isNotEmpty) const _BarraAbas(),
          if (nota != null) _BarraContexto(nota: nota),
          Expanded(
            child: nota == null
                ? CerebroVazio(
                    icone: Icons.description_outlined,
                    titulo: 'Nenhuma nota aberta',
                    descricao:
                        'Escolha uma nota no explorador, salte direto com a '
                        'paleta rápida ou carregue dados de demonstração para '
                        'ver o Cérebro cheio.',
                    dica: 'Ctrl+P abre a paleta · Ctrl+N cria uma nota',
                    acoes: [
                      FilledButton.icon(
                        onPressed: () =>
                            AcoesCerebro.popularDemo(context, ref, 1200),
                        icon: const Icon(Icons.science_outlined, size: 15),
                        label: const Text('Carregar 1.200 notas de teste'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => AcoesCerebro.novaNota(context, ref),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Nova nota'),
                      ),
                    ],
                  )
                : _EditorNota(key: ValueKey(nota.id), nota: nota),
          ),
        ],
      ),
    );
  }
}

// ── Abas ────────────────────────────────────────────────────────────────────

class _BarraAbas extends ConsumerWidget {
  const _BarraAbas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abas = ref.watch(abasProvider);
    final notifier = ref.read(abasProvider.notifier);

    return Container(
      height: CerebroTokens.barra,
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false, dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              }),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < abas.abertas.length; i++)
                      _Aba(
                        id: abas.abertas[i],
                        ativa: i == abas.ativa,
                        aoSelecionar: () => notifier.selecionar(i),
                        aoFechar: () => notifier.fechar(abas.abertas[i]),
                      ),
                  ],
                ),
              ),
            ),
          ),
          BotaoIcone(
            icone: Icons.add,
            tooltip: 'Nova nota',
            atalho: 'Ctrl+N',
            tamanho: 15,
            onTap: () => AcoesCerebro.novaNota(context, ref),
          ),
          PopupMenuButton<String>(
            tooltip: 'Ações das abas',
            position: PopupMenuPosition.under,
            icon: Icon(Icons.more_vert,
                size: 15, color: AppColors.textSecondaryOf(context)),
            iconSize: 15,
            padding: EdgeInsets.zero,
            onSelected: (v) {
              switch (v) {
                case 'todas':
                  notifier.fecharTodas();
                case 'outras':
                  final ativa = ref.read(abasProvider).notaAtiva;
                  notifier.fecharTodas();
                  if (ativa != null) notifier.abrir(ativa);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'outras',
                height: 36,
                child: Text('Fechar as outras abas',
                    style: TextStyle(fontSize: 12.5)),
              ),
              PopupMenuItem(
                value: 'todas',
                height: 36,
                child:
                    Text('Fechar todas as abas', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Aba extends ConsumerStatefulWidget {
  const _Aba({
    required this.id,
    required this.ativa,
    required this.aoSelecionar,
    required this.aoFechar,
  });

  final String id;
  final bool ativa;
  final VoidCallback aoSelecionar;
  final VoidCallback aoFechar;

  @override
  ConsumerState<_Aba> createState() => _AbaState();
}

class _AbaState extends ConsumerState<_Aba> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final nota = ref.watch(notaProvider(widget.id));
    final titulo = nota?.titulo.isNotEmpty == true
        ? nota!.titulo
        : (nota?.nomeArquivo ?? widget.id);

    return Tooltip(
      message: nota?.path ?? widget.id,
      waitDuration: const Duration(milliseconds: 700),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          // Fechar com o botão do meio — convenção de todo editor com abas.
          onPointerDown: (e) {
            if (e.buttons == kMiddleMouseButton) widget.aoFechar();
          },
          child: GestureDetector(
            onTap: widget.aoSelecionar,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              constraints: const BoxConstraints(maxWidth: 220, minWidth: 118),
              padding: const EdgeInsets.only(left: AppSpacing.md, right: 6),
              decoration: BoxDecoration(
                color: widget.ativa
                    ? AppColors.surfaceOf(context)
                    : (_hover
                        ? CerebroTokens.hover(context)
                        : Colors.transparent),
                border: Border(
                  top: BorderSide(
                    color: widget.ativa
                        ? AppColors.pinkAccent
                        : Colors.transparent,
                    width: 2,
                  ),
                  right: BorderSide(color: AppColors.borderOf(context)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    nota?.tipo.icon ?? Icons.description_outlined,
                    size: 13,
                    color: nota?.tipo.cor ?? AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      titulo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: nota?.ehRascunho == true
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontWeight:
                            widget.ativa ? FontWeight.w600 : FontWeight.w400,
                        color: widget.ativa
                            ? AppColors.textPrimaryOf(context)
                            : AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // O "x" só aparece na aba ativa ou sob o mouse — abas
                  // inativas ficam menos ruidosas.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: (_hover || widget.ativa) ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !(_hover || widget.ativa),
                      child: InkWell(
                        onTap: widget.aoFechar,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.close,
                              size: 13,
                              color: AppColors.textSecondaryOf(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barra de contexto ───────────────────────────────────────────────────────

class _BarraContexto extends ConsumerWidget {
  const _BarraContexto({required this.nota});

  final Nota nota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);
    final vault = ref.watch(vaultProvider);
    final segmentos = nota.path.split('/');

    return Container(
      height: CerebroTokens.barra,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          BotaoIcone(
            icone: Icons.arrow_back,
            tooltip: 'Voltar',
            atalho: 'Alt+←',
            onTap: () => ref.read(abasProvider.notifier).voltar(),
          ),
          const SizedBox(width: 2),
          // Caminho como trilha — as pastas ficam clicáveis e o arquivo ganha
          // destaque, em vez de uma string cinza única.
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (var i = 0; i < segmentos.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(Icons.chevron_right,
                            size: 12, color: AppColors.textTertiary),
                      ),
                    Text(
                      segmentos[i],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: i == segmentos.length - 1
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: i == segmentos.length - 1
                            ? AppColors.textPrimaryOf(context)
                            : AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          BadgeOrigem(nota: nota),
          const Spacer(),
          if (vault.salvando)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          BotaoIcone(
            icone: layout.modoLeitura
                ? Icons.edit_outlined
                : Icons.menu_book_outlined,
            tooltip: layout.modoLeitura ? 'Editar' : 'Ler',
            atalho: 'Ctrl+E',
            ativo: layout.modoLeitura,
            onTap: () => ref.read(layoutProvider.notifier).alternarModoLeitura(),
          ),
          BotaoIcone(
            icone: nota.fixada ? Icons.push_pin : Icons.push_pin_outlined,
            tooltip: nota.fixada ? 'Desafixar' : 'Fixar no topo do explorador',
            ativo: nota.fixada,
            onTap: () =>
                ref.read(vaultProvider.notifier).alternarFixada(nota.id),
          ),
          BotaoIcone(
            icone: Icons.polyline_outlined,
            tooltip: 'Focar esta nota no grafo',
            onTap: () => AcoesCerebro.abrirGrafoLocal(ref, nota.id),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais ações da nota',
            position: PopupMenuPosition.under,
            icon: Icon(Icons.more_horiz,
                size: 17, color: AppColors.textSecondaryOf(context)),
            iconSize: 17,
            padding: EdgeInsets.zero,
            onSelected: (v) => _executar(context, ref, v),
            itemBuilder: (context) => [
              _item('link', Icons.link, 'Copiar wikilink'),
              _item('caminho', Icons.content_copy_outlined, 'Copiar caminho'),
              const PopupMenuDivider(),
              _item(
                'favorita',
                nota.favorita ? Icons.star : Icons.star_border,
                nota.favorita ? 'Remover dos favoritos' : 'Favoritar',
              ),
              _item(
                'arquivar',
                Icons.inventory_2_outlined,
                nota.arquivada ? 'Desarquivar' : 'Arquivar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _item(String valor, IconData icone, String texto) =>
      PopupMenuItem<String>(
        value: valor,
        height: 38,
        child: Row(
          children: [
            Icon(icone, size: 15),
            const SizedBox(width: AppSpacing.sm),
            Text(texto, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      );

  void _executar(BuildContext context, WidgetRef ref, String valor) {
    final messenger = ScaffoldMessenger.of(context);
    void avisar(String texto) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 300,
        duration: const Duration(seconds: 2),
        content: Text(texto, style: const TextStyle(fontSize: 12.5)),
      ));
    }

    switch (valor) {
      case 'link':
        Clipboard.setData(ClipboardData(text: '[[${nota.titulo}]]'));
        avisar('Wikilink copiado');
      case 'caminho':
        Clipboard.setData(ClipboardData(text: nota.path));
        avisar('Caminho copiado');
      case 'favorita':
        ref.read(vaultProvider.notifier).alternarFavorita(nota.id);
      case 'arquivar':
        ref.read(vaultProvider.notifier).arquivar(nota.id);
    }
  }
}

/// Editor de uma nota: `TextField` com autocomplete de `[[` e `#`, autosave
/// com debounce de 2 s e alternância para leitura (§10.4).
class _EditorNota extends ConsumerStatefulWidget {
  const _EditorNota({super.key, required this.nota});

  final Nota nota;

  @override
  ConsumerState<_EditorNota> createState() => _EditorNotaState();
}

class _EditorNotaState extends ConsumerState<_EditorNota> {
  /// Medida confortável de leitura/escrita — evita linhas de 200 caracteres
  /// em monitores largos.
  static const double _medida = 900;

  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  Timer? _debounce;

  // Estado do autocomplete.
  List<_Sugestao> _sugestoes = const [];
  int _sugestaoAtiva = 0;
  int _inicioGatilho = -1;
  String _gatilho = '';

  bool get _popupAberto => _sugestoes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.nota.conteudo);
    _ctrl.addListener(_aoMudar);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _salvarAgora();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _aoMudar() {
    _atualizarSugestoes();
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _salvarAgora);
  }

  void _salvarAgora() {
    final texto = _ctrl.text;
    if (texto == widget.nota.conteudo) return;
    ref.read(vaultProvider.notifier).salvarConteudo(widget.nota.id, texto);
  }

  // ── Autocomplete ──────────────────────────────────────────────────────────

  void _atualizarSugestoes() {
    final sel = _ctrl.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      _fecharPopup();
      return;
    }
    final texto = _ctrl.text;
    final cursor = sel.baseOffset;
    if (cursor <= 0 || cursor > texto.length) {
      _fecharPopup();
      return;
    }

    // Procura o gatilho mais próximo à esquerda, na mesma linha.
    final inicioLinha = texto.lastIndexOf('\n', cursor - 1) + 1;
    final antes = texto.substring(inicioLinha, cursor);

    final idxLink = antes.lastIndexOf('[[');
    final idxTag = antes.lastIndexOf('#');

    if (idxLink >= 0 && !antes.substring(idxLink).contains(']]')) {
      final consulta = antes.substring(idxLink + 2);
      if (consulta.contains('\n')) return _fecharPopup();
      _gatilho = '[[';
      _inicioGatilho = inicioLinha + idxLink;
      _buscarNotas(consulta);
      return;
    }

    if (idxTag >= 0) {
      final consulta = antes.substring(idxTag + 1);
      final validoAntes = idxTag == 0 || antes[idxTag - 1] == ' ';
      if (validoAntes && !consulta.contains(RegExp(r'[\s\[\]]'))) {
        _gatilho = '#';
        _inicioGatilho = inicioLinha + idxTag;
        _buscarTags(consulta);
        return;
      }
    }

    _fecharPopup();
  }

  void _buscarNotas(String consulta) {
    final index = ref.read(vaultProvider.notifier).index;
    final q = chaveNormalizadaSegura(consulta);
    final out = <_Sugestao>[];

    for (final n in index.notas.values) {
      if (n.id == widget.nota.id || n.excluida) continue;
      final titulo = chaveNormalizadaSegura(n.titulo);
      final arquivo = chaveNormalizadaSegura(n.nomeArquivo);
      if (q.isEmpty || titulo.startsWith(q) || arquivo.startsWith(q)) {
        out.add(_Sugestao(n.titulo, n.pasta, n.tipo.icon, n.tipo.cor, 0));
      } else if (titulo.contains(q) || arquivo.contains(q)) {
        out.add(_Sugestao(n.titulo, n.pasta, n.tipo.icon, n.tipo.cor, 1));
      }
      if (out.length >= 40) break;
    }
    out.sort((a, b) => a.rank.compareTo(b.rank));

    setState(() {
      _sugestoes = out.take(8).toList();
      if (consulta.trim().isNotEmpty) {
        _sugestoes = [
          ..._sugestoes,
          _Sugestao('Criar "$consulta"', '', Icons.add, AppColors.pinkAccent, 9,
              criar: consulta),
        ];
      }
      _sugestaoAtiva = 0;
    });
  }

  void _buscarTags(String consulta) {
    final index = ref.read(vaultProvider.notifier).index;
    final q = consulta.toLowerCase();
    final out = <_Sugestao>[];
    for (final e in index.contagemTags.entries) {
      if (q.isEmpty || e.key.startsWith(q)) {
        out.add(_Sugestao('#${e.key}', '${e.value} notas', Icons.tag,
            const Color(0xFFC77700), e.key.length));
      }
      if (out.length >= 8) break;
    }
    out.sort((a, b) => a.rank.compareTo(b.rank));
    setState(() {
      _sugestoes = out;
      _sugestaoAtiva = 0;
    });
  }

  void _fecharPopup() {
    if (_sugestoes.isEmpty) return;
    setState(() {
      _sugestoes = const [];
      _inicioGatilho = -1;
    });
  }

  Future<void> _aceitarSugestao(_Sugestao s) async {
    if (_inicioGatilho < 0) return;
    final texto = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;

    String insercao;
    if (_gatilho == '[[') {
      final alvo = s.criar ?? s.titulo;
      if (s.criar != null) {
        await ref.read(vaultProvider.notifier).criar(path: s.criar!);
      }
      insercao = '[[$alvo]]';
    } else {
      insercao = s.titulo; // já vem com '#'
    }

    final novo = texto.replaceRange(_inicioGatilho, cursor, insercao);
    _ctrl.value = TextEditingValue(
      text: novo,
      selection:
          TextSelection.collapsed(offset: _inicioGatilho + insercao.length),
    );
    _fecharPopup();
  }

  KeyEventResult _aoTeclar(FocusNode node, KeyEvent evento) {
    if (!_popupAberto || evento is! KeyDownEvent) return KeyEventResult.ignored;
    switch (evento.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(
            () => _sugestaoAtiva = (_sugestaoAtiva + 1) % _sugestoes.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _sugestaoAtiva =
            (_sugestaoAtiva - 1 + _sugestoes.length) % _sugestoes.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.tab:
        _aceitarSugestao(_sugestoes[_sugestaoAtiva]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _fecharPopup();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  // ── Navegação a partir do preview ─────────────────────────────────────────

  Future<void> _navegar(AlvoLink alvo) async {
    switch (alvo.tipo) {
      case TipoAlvo.nota:
        ref.read(abasProvider.notifier).abrir(alvo.notaId!);
      case TipoAlvo.criar:
        final id =
            await ref.read(vaultProvider.notifier).criar(path: alvo.valor);
        ref.read(abasProvider.notifier).abrir(id);
      case TipoAlvo.tag:
        ref.read(filtroTagProvider.notifier).state = alvo.valor;
        ref.read(layoutProvider.notifier).abrirPainel(PainelEsquerdo.tags);
      case TipoAlvo.entidade:
        final e = alvo.entidade!;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${e.tipo.label} ${e.id} — abertura da entidade '
              'chega com a ponte operacional (§bridge).'),
        ));
      case TipoAlvo.externo:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(layoutProvider);
    final index = ref.read(vaultProvider.notifier).index;

    if (layout.modoLeitura) {
      return Container(
        color: AppColors.surfaceOf(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: VfmView(
                conteudo: _ctrl.text,
                index: index,
                aoTocar: _navegar,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: AppColors.surfaceOf(context),
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: c.maxWidth > _medida + 80 ? _medida : c.maxWidth,
                  height: c.maxHeight,
                  child: Focus(
                    onKeyEvent: _aoTeclar,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      cursorColor: AppColors.pinkAccent,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.65,
                        color: AppColors.textPrimaryOf(context),
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        contentPadding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 80),
                        hintText: 'Escreva ligando: [[outra nota]], #tag, '
                            '[[@medico:id]]…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_popupAberto)
          Positioned(
            left: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: _PopupAutocomplete(
              gatilho: _gatilho,
              sugestoes: _sugestoes,
              ativa: _sugestaoAtiva,
              aoEscolher: _aceitarSugestao,
            ),
          ),
      ],
    );
  }
}

class _Sugestao {
  const _Sugestao(this.titulo, this.subtitulo, this.icone, this.cor, this.rank,
      {this.criar});

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final int rank;

  /// Quando preenchido, aceitar a sugestão cria a nota com este caminho.
  final String? criar;
}

class _PopupAutocomplete extends StatelessWidget {
  const _PopupAutocomplete({
    required this.gatilho,
    required this.sugestoes,
    required this.ativa,
    required this.aoEscolher,
  });

  final String gatilho;
  final List<_Sugestao> sugestoes;
  final int ativa;
  final Future<void> Function(_Sugestao) aoEscolher;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: CerebroTokens.flutuante(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 5, AppSpacing.md, 5),
            color: AppColors.surfaceAltOf(context),
            child: Row(
              children: [
                Icon(gatilho == '[[' ? Icons.link : Icons.tag,
                    size: 12, color: AppColors.pinkAccent),
                const SizedBox(width: 5),
                Text(
                  gatilho == '[[' ? 'LIGAR A UMA NOTA' : 'ADICIONAR TAG',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < sugestoes.length; i++)
            InkWell(
              onTap: () => aoEscolher(sugestoes[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 7),
                color: i == ativa
                    ? CerebroTokens.selecao(context)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Icon(sugestoes[i].icone, size: 15, color: sugestoes[i].cor),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        sugestoes[i].titulo,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == ativa ? FontWeight.w600 : FontWeight.w400,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    if (sugestoes[i].subtitulo.isNotEmpty)
                      Text(
                        sugestoes[i].subtitulo,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
            color: AppColors.surfaceAltOf(context),
            child: Row(
              children: [
                const Teclas(atalho: '↑ ↓'),
                const SizedBox(width: 4),
                _dica(context, 'navegar'),
                const SizedBox(width: AppSpacing.sm),
                const Teclas(atalho: '⏎'),
                const SizedBox(width: 4),
                _dica(context, 'inserir'),
                const SizedBox(width: AppSpacing.sm),
                const Teclas(atalho: 'Esc'),
                const SizedBox(width: 4),
                _dica(context, 'fechar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dica(BuildContext context, String texto) => Text(
        texto,
        style:
            TextStyle(fontSize: 10, color: AppColors.textSecondaryOf(context)),
      );
}

/// Normalização defensiva usada pelo autocomplete (o índice já expõe a sua,
/// esta apenas evita import circular em widgets).
String chaveNormalizadaSegura(String s) =>
    removerAcentosLocal(s.trim().toLowerCase());

String removerAcentosLocal(String s) {
  const com = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const sem = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = com.indexOf(ch);
    b.write(i >= 0 ? sem[i] : ch);
  }
  return b.toString();
}
