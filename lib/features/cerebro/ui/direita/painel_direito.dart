import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/aresta.dart';
import '../../data/models/nota.dart';
import '../../providers/cerebro_providers.dart';
import '../comum/badge_origem.dart';
import '../comum/cerebro_ui.dart';
import '../comum/estados_vazios.dart';

/// Painel direito em acordeão (`obsidian.md` §10.7).
///
/// Ordem normativa: Propriedades → Sumário → Menções vinculadas →
/// Menções não-vinculadas → Métricas.
class PainelDireito extends ConsumerWidget {
  const PainelDireito({super.key, this.emGaveta = false});

  /// Dentro de uma gaveta o painel ocupa a largura disponível.
  final bool emGaveta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);
    final nota = ref.watch(notaAtivaProvider);

    return Container(
      width: emGaveta ? null : layout.larguraDireita,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: emGaveta
            ? null
            : Border(left: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: nota == null
          ? const CerebroVazio(
              icone: Icons.article_outlined,
              titulo: 'Nenhuma nota em foco',
              descricao:
                  'Abra uma nota para ver propriedades, sumário, backlinks e '
                  'métricas do grafo.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CabecalhoNota(nota: nota, emGaveta: emGaveta),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    children: [
                      _Propriedades(nota: nota),
                      _Sumario(nota: nota),
                      _Vinculadas(nota: nota),
                      _NaoVinculadas(nota: nota),
                      _Metricas(nota: nota),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Cabeçalho fixo do painel — diz de qual nota são os dados abaixo, coisa que
/// antes só dava para inferir olhando a aba ativa.
class _CabecalhoNota extends ConsumerWidget {
  const _CabecalhoNota({required this.nota, required this.emGaveta});

  final Nota nota;
  final bool emGaveta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: CerebroTokens.barra,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          NotaIcone(tipo: nota.tipo, tamanho: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              nota.titulo.isEmpty ? nota.nomeArquivo : nota.titulo,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
          if (!emGaveta)
            BotaoIcone(
              icone: Icons.keyboard_double_arrow_right,
              tooltip: 'Recolher painel',
              atalho: 'Ctrl+Shift+B',
              tamanho: 15,
              onTap: ref.read(layoutProvider.notifier).alternarDireito,
            ),
        ],
      ),
    );
  }
}

class _Secao extends StatefulWidget {
  const _Secao({
    required this.titulo,
    required this.filho,
    this.contador,
    this.iniciaAberta = true,
  });

  final String titulo;
  final Widget filho;
  final int? contador;
  final bool iniciaAberta;

  @override
  State<_Secao> createState() => _SecaoState();
}

class _SecaoState extends State<_Secao> {
  late bool _aberta = widget.iniciaAberta;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: () => setState(() => _aberta = !_aberta),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              color: _hover
                  ? CerebroTokens.hover(context)
                  : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(
                  6, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _aberta ? 0 : -0.25,
                    duration: const Duration(milliseconds: 130),
                    child: Icon(Icons.expand_more,
                        size: 14, color: AppColors.textSecondaryOf(context)),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      widget.titulo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.contador != null)
                    PilulaContagem(valor: widget.contador!),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 150),
          firstChild: widget.filho,
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState:
              _aberta ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          sizeCurve: Curves.easeOut,
        ),
        Divider(height: 1, color: AppColors.borderOf(context)),
      ],
    );
  }
}

// ── Propriedades ────────────────────────────────────────────────────────────

class _Propriedades extends StatelessWidget {
  const _Propriedades({required this.nota});

  final Nota nota;

  @override
  Widget build(BuildContext context) {
    final props = <String, String>{
      'tipo': nota.tipo.label,
      'origem': nota.origem.label,
      'estado': nota.estado.label,
      if (nota.aliases.isNotEmpty) 'aliases': nota.aliases.join(', '),
      if (nota.tags.isNotEmpty) 'tags': nota.tags.map((t) => '#$t').join(' '),
      'versão': '${nota.versao}',
      'atualizada': _relativo(nota.updatedAt),
      for (final e in nota.frontmatter.entries)
        if (!const {'tags', 'aliases', 'tipo', 'titulo', 'title', 'alias', 'type'}
            .contains(e.key))
          e.key: '${e.value}',
    };

    return _Secao(
      titulo: 'PROPRIEDADES',
      iniciaAberta: false,
      filho: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BadgeOrigem(nota: nota),
            const SizedBox(height: 6),
            for (final e in props.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondaryOf(context))),
                    ),
                    Expanded(
                      child: Text(e.value,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimaryOf(context))),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _relativo(DateTime d) {
    final delta = DateTime.now().difference(d);
    if (delta.inMinutes < 1) return 'agora';
    if (delta.inMinutes < 60) return 'há ${delta.inMinutes} min';
    if (delta.inHours < 24) return 'há ${delta.inHours} h';
    return 'há ${delta.inDays} d';
  }
}

// ── Sumário ─────────────────────────────────────────────────────────────────

class _Sumario extends StatelessWidget {
  const _Sumario({required this.nota});

  final Nota nota;

  @override
  Widget build(BuildContext context) {
    if (nota.headings.isEmpty) {
      return const _Secao(
        titulo: 'SUMÁRIO',
        filho: _Nada(texto: 'Sem títulos nesta nota.'),
      );
    }
    return _Secao(
      titulo: 'SUMÁRIO',
      contador: nota.headings.length,
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final h in nota.headings)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md + (h.nivel - 1) * 12, 2, AppSpacing.md, 2),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: h.nivel == 1
                          ? AppColors.pinkAccent
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      h.texto,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            h.nivel == 1 ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Menções vinculadas (backlinks) ──────────────────────────────────────────

class _Vinculadas extends ConsumerWidget {
  const _Vinculadas({required this.nota});

  final Nota nota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(vaultProvider);
    final index = ref.read(vaultProvider.notifier).index;
    final backlinks = index.backlinks(nota.id);

    if (backlinks.isEmpty) {
      return const _Secao(
        titulo: 'MENÇÕES VINCULADAS',
        filho: _Nada(texto: 'Nenhuma nota aponta para esta ainda.'),
      );
    }

    return _Secao(
      titulo: 'MENÇÕES VINCULADAS',
      contador: backlinks.length,
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in backlinks)
            _CardMencao(
              aresta: a,
              origem: index.porId(a.de),
              aoAbrir: () {
                ref.read(abasProvider.notifier).abrir(a.de);
                ref.read(layoutProvider.notifier).irPara(VistaCentral.editor);
              },
            ),
        ],
      ),
    );
  }
}

class _CardMencao extends StatelessWidget {
  const _CardMencao({
    required this.aresta,
    required this.origem,
    required this.aoAbrir,
  });

  final Aresta aresta;
  final Nota? origem;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoAbrir,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (origem != null) NotaIcone(tipo: origem!.tipo, tamanho: 12),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    origem?.titulo ?? aresta.de,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (aresta.tipo.name == 'embed')
                  Icon(Icons.picture_in_picture_alt_outlined,
                      size: 11, color: AppColors.textTertiary),
              ],
            ),
            if (aresta.contexto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 17, top: 2),
                child: Text(
                  aresta.contexto,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Menções não-vinculadas ──────────────────────────────────────────────────

class _NaoVinculadas extends ConsumerWidget {
  const _NaoVinculadas({required this.nota});

  final Nota nota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mencoes = ref.watch(mencoesNaoVinculadasProvider(nota.id));
    if (mencoes.isEmpty) {
      return const _Secao(
        titulo: 'MENÇÕES NÃO-VINCULADAS',
        iniciaAberta: false,
        filho: _Nada(texto: 'Nenhuma menção textual solta encontrada.'),
      );
    }

    return _Secao(
      titulo: 'MENÇÕES NÃO-VINCULADAS',
      contador: mencoes.length,
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in mencoes)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NotaIcone(tipo: m.nota.tipo, tamanho: 12),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          m.nota.titulo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(vaultProvider.notifier)
                            .vincular(m.nota.id, nota.titulo),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Vincular',
                            style: TextStyle(fontSize: 10.5)),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 17, top: 2),
                    child: Text(
                      m.trecho,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Métricas ────────────────────────────────────────────────────────────────

class _Metricas extends StatelessWidget {
  const _Metricas({required this.nota});

  final Nota nota;

  @override
  Widget build(BuildContext context) {
    final m = nota.metrics;
    return _Secao(
      titulo: 'MÉTRICAS',
      iniciaAberta: false,
      filho: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 6),
        child: Column(
          children: [
            _linha(context, 'Entradas', '${m.inDegree}'),
            _linha(context, 'Saídas', '${m.outDegree}'),
            _linha(context, 'PageRank', m.pagerank.toStringAsFixed(4)),
            _linha(context, 'Cluster', '#${m.cluster}'),
            _linha(context, 'Palavras', '${nota.wordCount}'),
            _linha(context, 'Leitura', '${(nota.tempoLeituraSeg / 60).ceil()} min'),
            if (m.orfa)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 12, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Nota órfã — ninguém alcança e ela não alcança ninguém.',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.warning, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linha(BuildContext context, String rotulo, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(rotulo,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondaryOf(context))),
            ),
            Text(valor,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context))),
          ],
        ),
      );
}

class _Nada extends StatelessWidget {
  const _Nada({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 6),
        child: Text(
          texto,
          style: TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: AppColors.textSecondaryOf(context)),
        ),
      );
}
