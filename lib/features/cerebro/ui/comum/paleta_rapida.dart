import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/aresta.dart' show removerAcentos;
import '../../data/models/nota.dart';
import '../../providers/cerebro_providers.dart';
import 'acoes_cerebro.dart';
import 'cerebro_ui.dart';

/// Ação escolhida na paleta. É executada **depois** do `pop`, com o contexto
/// da tela (e não o do diálogo, que já não existe mais).
typedef AcaoPaleta = void Function(BuildContext contexto, WidgetRef ref);

/// Paleta rápida (Ctrl+P) — abre qualquer nota ou dispara qualquer comando
/// sem tirar as mãos do teclado.
///
/// É a resposta de UX para navegar um vault de milhares de notas: o
/// explorador serve para *passear*, a paleta serve para *chegar*.
Future<void> mostrarPaletaRapida(
  BuildContext context,
  WidgetRef ref, {
  String prefixo = '',
}) async {
  final acao = await showDialog<AcaoPaleta>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _PaletaRapida(ref: ref, prefixo: prefixo),
  );
  if (acao == null || !context.mounted) return;
  acao(context, ref);
}

class _Entrada {
  const _Entrada({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.acao,
    this.subtitulo = '',
    this.atalho,
    this.grupo = 'NOTAS',
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final String? atalho;
  final String grupo;
  final AcaoPaleta acao;
}

class _PaletaRapida extends StatefulWidget {
  const _PaletaRapida({required this.ref, required this.prefixo});

  final WidgetRef ref;
  final String prefixo;

  @override
  State<_PaletaRapida> createState() => _PaletaRapidaState();
}

class _PaletaRapidaState extends State<_PaletaRapida> {
  static const double _alturaLinha = 44;

  late final TextEditingController _ctrl =
      TextEditingController(text: widget.prefixo);
  final _scroll = ScrollController();
  int _ativa = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Fonte de dados ────────────────────────────────────────────────────────

  List<_Entrada> _comandos() {
    final neutra = AppColors.textSecondaryOf(context);
    return [
      _Entrada(
        titulo: 'Nova nota',
        subtitulo: 'Cria uma nota e abre no editor',
        icone: Icons.note_add_outlined,
        cor: AppColors.pinkAccent,
        atalho: 'Ctrl+N',
        grupo: 'COMANDOS',
        acao: (c, r) => AcoesCerebro.novaNota(c, r),
      ),
      _Entrada(
        titulo: 'Nota de hoje',
        subtitulo: 'Abre (ou cria) o diário do dia',
        icone: Icons.today_outlined,
        cor: AppColors.primary,
        atalho: 'Ctrl+D',
        grupo: 'COMANDOS',
        acao: (c, r) => AcoesCerebro.abrirDiario(r),
      ),
      _Entrada(
        titulo: 'Grafo global',
        subtitulo: 'Visualiza o vault inteiro como rede',
        icone: Icons.hub_outlined,
        cor: AppColors.secondary,
        atalho: 'Ctrl+G',
        grupo: 'COMANDOS',
        acao: (c, r) =>
            r.read(layoutProvider.notifier).irPara(VistaCentral.grafo),
      ),
      _Entrada(
        titulo: 'Modo analítico',
        subtitulo: 'Facetas, métricas e tabela de notas',
        icone: Icons.analytics_outlined,
        cor: AppColors.primary,
        atalho: 'Ctrl+Shift+A',
        grupo: 'COMANDOS',
        acao: (c, r) =>
            r.read(layoutProvider.notifier).irPara(VistaCentral.analitico),
      ),
      _Entrada(
        titulo: 'Buscar no acervo',
        subtitulo: 'Operadores: tag:  tipo:  path:  orfa:true',
        icone: Icons.search,
        cor: neutra,
        atalho: 'Ctrl+Shift+F',
        grupo: 'COMANDOS',
        acao: (c, r) =>
            r.read(layoutProvider.notifier).abrirPainel(PainelEsquerdo.busca),
      ),
      _Entrada(
        titulo: 'Sugestões de higiene',
        subtitulo: 'Notas órfãs e links quebrados',
        icone: Icons.bolt_outlined,
        cor: AppColors.warning,
        atalho: 'Ctrl+Shift+S',
        grupo: 'COMANDOS',
        acao: (c, r) => r
            .read(layoutProvider.notifier)
            .abrirPainel(PainelEsquerdo.sugestoes),
      ),
      _Entrada(
        titulo: 'Alternar leitura / edição',
        subtitulo: 'Renderiza o VFM da nota ativa',
        icone: Icons.menu_book_outlined,
        cor: neutra,
        atalho: 'Ctrl+E',
        grupo: 'COMANDOS',
        acao: (c, r) => r.read(layoutProvider.notifier).alternarModoLeitura(),
      ),
      _Entrada(
        titulo: 'Carregar 1.200 notas de demonstração',
        subtitulo: 'Popula o vault com dados sintéticos',
        icone: Icons.science_outlined,
        cor: AppColors.secondary,
        grupo: 'COMANDOS',
        acao: (c, r) => AcoesCerebro.popularDemo(c, r, 1200),
      ),
    ];
  }

  List<_Entrada> _resultados() {
    final consulta = _ctrl.text.trim();
    final soComandos = consulta.startsWith('>');
    final termo = removerAcentos(
            (soComandos ? consulta.substring(1) : consulta).toLowerCase())
        .trim();

    final comandos = _comandos()
        .where((c) =>
            termo.isEmpty ||
            removerAcentos(c.titulo.toLowerCase()).contains(termo))
        .toList();
    if (soComandos) return comandos;

    final index = widget.ref.read(vaultProvider.notifier).index;
    final abertas = widget.ref.read(abasProvider).abertas.toSet();

    final ranqueadas = <(int, Nota)>[];
    for (final n in index.notas.values) {
      if (n.excluida) continue;
      final titulo = removerAcentos(n.titulo.toLowerCase());
      final path = removerAcentos(n.path.toLowerCase());
      final int rank;
      if (termo.isEmpty) {
        rank = abertas.contains(n.id) ? 0 : 1;
      } else if (titulo.startsWith(termo)) {
        rank = 0;
      } else if (titulo.contains(termo)) {
        rank = 1;
      } else if (path.contains(termo)) {
        rank = 2;
      } else {
        continue;
      }
      ranqueadas.add((rank, n));
    }
    ranqueadas.sort((a, b) {
      final r = a.$1.compareTo(b.$1);
      return r != 0 ? r : b.$2.updatedAt.compareTo(a.$2.updatedAt);
    });

    final notas = <_Entrada>[
      for (final (_, n) in ranqueadas.take(termo.isEmpty ? 8 : 24))
        _Entrada(
          titulo: n.titulo.isEmpty ? n.nomeArquivo : n.titulo,
          subtitulo: n.path,
          icone: n.tipo.icon,
          cor: n.tipo.cor,
          grupo: termo.isEmpty ? 'RECENTES' : 'NOTAS',
          acao: (c, r) => AcoesCerebro.abrirNota(r, n.id),
        ),
    ];

    return [...notas, ...(termo.isEmpty ? comandos : comandos.take(4))];
  }

  // ── Teclado ───────────────────────────────────────────────────────────────

  void _mover(int delta, int total) {
    if (total == 0) return;
    setState(() => _ativa = (_ativa + delta + total) % total);
    if (!_scroll.hasClients) return;
    final alvo = _ativa * _alturaLinha;
    final viewport = _scroll.position.viewportDimension;
    final de = _scroll.offset;
    if (alvo < de) {
      _scroll.animateTo(alvo,
          duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    } else if (alvo + _alturaLinha > de + viewport) {
      _scroll.animateTo(
        (alvo - viewport + _alturaLinha)
            .clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  void _ativar(List<_Entrada> lista) {
    if (lista.isEmpty) return;
    Navigator.of(context).pop(lista[_ativa.clamp(0, lista.length - 1)].acao);
  }

  KeyEventResult _aoTeclar(KeyEvent evento, List<_Entrada> lista) {
    if (evento is! KeyDownEvent) return KeyEventResult.ignored;
    switch (evento.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _mover(1, lista.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _mover(-1, lista.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _resultados();
    if (_ativa >= lista.length) _ativa = 0;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 88, left: 16, right: 16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Focus(
        onKeyEvent: (_, evento) => _aoTeclar(evento, lista),
        child: Container(
          width: 620,
          constraints: const BoxConstraints(maxHeight: 460),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: CerebroTokens.flutuante(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo(),
              Divider(height: 1, color: AppColors.borderOf(context)),
              Flexible(
                child: lista.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'Nada encontrado. Comece com “>” para ver apenas comandos.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemExtent: _alturaLinha,
                        itemCount: lista.length,
                        itemBuilder: (context, i) => _Linha(
                          entrada: lista[i],
                          ativa: i == _ativa,
                          mostrarGrupo:
                              i == 0 || lista[i].grupo != lista[i - 1].grupo,
                          aoTocar: () {
                            setState(() => _ativa = i);
                            _ativar(lista);
                          },
                        ),
                      ),
              ),
              _rodape(lista.length),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.search,
              size: 18, color: AppColors.textSecondaryOf(context)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: TextStyle(
                  fontSize: 15, color: AppColors.textPrimaryOf(context)),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Buscar notas…  ou “>” para comandos',
                hintStyle:
                    TextStyle(fontSize: 15, color: AppColors.textTertiary),
              ),
              onChanged: (_) => setState(() => _ativa = 0),
              onSubmitted: (_) => _ativar(_resultados()),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            BotaoIcone(
              icone: Icons.close,
              tooltip: 'Limpar',
              tamanho: 14,
              onTap: () => setState(() {
                _ctrl.clear();
                _ativa = 0;
              }),
            ),
        ],
      ),
    );
  }

  Widget _rodape(int total) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        border: Border(top: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          const Teclas(atalho: '↑ ↓'),
          const SizedBox(width: 5),
          _dica('navegar'),
          const SizedBox(width: AppSpacing.md),
          const Teclas(atalho: '⏎'),
          const SizedBox(width: 5),
          _dica('abrir'),
          const SizedBox(width: AppSpacing.md),
          const Teclas(atalho: 'Esc'),
          const SizedBox(width: 5),
          _dica('fechar'),
          const Spacer(),
          _dica('$total ${total == 1 ? "resultado" : "resultados"}'),
        ],
      ),
    );
  }

  Widget _dica(String texto) => Text(
        texto,
        style:
            TextStyle(fontSize: 10, color: AppColors.textSecondaryOf(context)),
      );
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.entrada,
    required this.ativa,
    required this.mostrarGrupo,
    required this.aoTocar,
  });

  final _Entrada entrada;
  final bool ativa;
  final bool mostrarGrupo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoTocar,
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 2, 6, 2),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: ativa ? CerebroTokens.selecao(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(CerebroTokens.raio),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entrada.cor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(entrada.icone, size: 14, color: entrada.cor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entrada.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: ativa ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  if (entrada.subtitulo.isNotEmpty)
                    Text(
                      entrada.subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                ],
              ),
            ),
            if (mostrarGrupo)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  entrada.grupo,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            if (entrada.atalho != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Teclas(atalho: entrada.atalho!),
            ],
          ],
        ),
      ),
    );
  }
}
