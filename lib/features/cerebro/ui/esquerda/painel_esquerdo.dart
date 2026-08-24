import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/nota.dart';
import '../../providers/cerebro_providers.dart';
import '../comum/acoes_cerebro.dart';
import '../comum/badge_origem.dart';
import '../comum/cerebro_ui.dart';
import '../comum/estados_vazios.dart';
import '../comum/tutorial_cerebro.dart';

/// Painel esquerdo com seus 5 modos (`obsidian.md` §10.3).
class PainelEsquerdoView extends ConsumerWidget {
  const PainelEsquerdoView({super.key, this.emGaveta = false});

  /// Dentro de uma gaveta o painel ocupa a largura disponível e não oferece
  /// o botão de recolher (a gaveta já fecha sozinha).
  final bool emGaveta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);

    return Container(
      width: emGaveta ? null : layout.larguraEsquerda,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: emGaveta
            ? null
            : Border(right: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Cabecalho(painel: layout.painelEsquerdo, emGaveta: emGaveta),
          Expanded(
            child: switch (layout.painelEsquerdo) {
              PainelEsquerdo.explorer => const _Explorer(),
              PainelEsquerdo.busca => const _Busca(),
              PainelEsquerdo.tags => const _Tags(),
              PainelEsquerdo.sugestoes => const _Sugestoes(),
              PainelEsquerdo.recentes => const _Recentes(),
            },
          ),
        ],
      ),
    );
  }
}

class _Cabecalho extends ConsumerWidget {
  const _Cabecalho({required this.painel, required this.emGaveta});

  final PainelEsquerdo painel;
  final bool emGaveta;

  static const _titulos = {
    PainelEsquerdo.explorer: 'EXPLORADOR',
    PainelEsquerdo.busca: 'BUSCA',
    PainelEsquerdo.tags: 'TAGS',
    PainelEsquerdo.sugestoes: 'SUGESTÕES',
    PainelEsquerdo.recentes: 'RECENTES',
  };

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
          Expanded(
            child: Text(
              _titulos[painel]!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          if (painel == PainelEsquerdo.explorer) ...[
            BotaoIcone(
              icone: Icons.add,
              tooltip: 'Nova nota',
              atalho: 'Ctrl+N',
              tamanho: 15,
              onTap: () => AcoesCerebro.novaNota(context, ref),
            ),
            PopupMenuButton<int>(
              tooltip: 'Popular com dados de demonstração',
              position: PopupMenuPosition.under,
              padding: EdgeInsets.zero,
              iconSize: 15,
              icon: Icon(Icons.science_outlined,
                  size: 15, color: AppColors.textSecondaryOf(context)),
              onSelected: (n) => AcoesCerebro.popularDemo(context, ref, n),
              itemBuilder: (context) => const [
                PopupMenuItem<int>(
                  enabled: false,
                  height: 30,
                  child: Text('CARGA DE DEMONSTRAÇÃO',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7)),
                ),
                PopupMenuItem<int>(
                  value: 300,
                  height: 36,
                  child: Text('300 notas  ·  vault pequeno',
                      style: TextStyle(fontSize: 12)),
                ),
                PopupMenuItem<int>(
                  value: 1200,
                  height: 36,
                  child: Text('1.200 notas  ·  1 ano de uso',
                      style: TextStyle(fontSize: 12)),
                ),
                PopupMenuItem<int>(
                  value: 3000,
                  height: 36,
                  child: Text('3.000 notas  ·  carga pesada',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          if (painel == PainelEsquerdo.busca)
            BotaoIcone(
              icone: Icons.filter_alt_off_outlined,
              tooltip: 'Limpar busca',
              tamanho: 15,
              onTap: () => ref.read(termoBuscaProvider.notifier).state = '',
            ),
          if (!emGaveta)
            BotaoIcone(
              icone: Icons.keyboard_double_arrow_left,
              tooltip: 'Recolher painel',
              atalho: 'Ctrl+B',
              tamanho: 15,
              onTap: ref.read(layoutProvider.notifier).alternarEsquerdo,
            ),
        ],
      ),
    );
  }
}

// ── Explorer ────────────────────────────────────────────────────────────────

class _Explorer extends ConsumerStatefulWidget {
  const _Explorer();

  @override
  ConsumerState<_Explorer> createState() => _ExplorerState();
}

class _ExplorerState extends ConsumerState<_Explorer> {
  /// Pastas recolhidas — um vault de mil notas precisa poder ser dobrado.
  final Set<String> _fechadas = {};

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    if (vault.carregando) return EsqueletoLista(progresso: vault.progresso);

    // Um vault sem clínica resolvida não é um vault vazio — oferecer "criar
    // nota" aqui levaria a uma escrita órfã. Diz o que está acontecendo.
    if (vault.aguardandoClinica) {
      return const CerebroVazio(
        icone: Icons.business_outlined,
        titulo: 'Aguardando a clínica',
        descricao: 'O Cérebro guarda as notas por clínica. Assim que a clínica '
            'ativa carregar, o vault dela aparece aqui.',
        dica: 'Se isto persistir, selecione uma clínica no topo do app.',
      );
    }

    // A falha de leitura era só um ícone na status bar: a tela parecia vazia e
    // convidava a popular o vault, escondendo o erro real.
    if (vault.erro != null) {
      return CerebroVazio(
        icone: Icons.cloud_off_outlined,
        cor: AppColors.danger,
        titulo: 'Não foi possível carregar o vault',
        descricao: vault.erro!,
        acoes: [
          FilledButton.icon(
            onPressed: () => ref.read(vaultProvider.notifier).carregar(),
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Tentar de novo'),
          ),
        ],
      );
    }

    final index = ref.read(vaultProvider.notifier).index;
    final filtroTag = ref.watch(filtroTagProvider);

    var notas = index.notas.values.where((n) => !n.excluida).toList();
    if (filtroTag != null) {
      notas = notas
          .where((n) =>
              n.tags.any((t) => t == filtroTag || t.startsWith('$filtroTag/')))
          .toList();
    }

    if (notas.isEmpty) {
      return CerebroVazio(
        icone: Icons.hub_outlined,
        titulo:
            filtroTag != null ? 'Nenhuma nota com #$filtroTag' : 'Cérebro vazio',
        descricao: filtroTag != null
            ? 'Nenhuma nota carrega esta tag.'
            : 'Popule com dados sintéticos ou crie a primeira nota — o grafo '
                'começa a existir no segundo link.',
        acoes: [
          if (filtroTag != null)
            TextButton(
              onPressed: () => ref.read(filtroTagProvider.notifier).state = null,
              child: const Text('Limpar filtro'),
            )
          else ...[
            FilledButton.icon(
              onPressed: () => AcoesCerebro.popularDemo(context, ref, 1200),
              icon: const Icon(Icons.science_outlined, size: 15),
              label: const Text('Carregar 1.200 notas'),
            ),
            OutlinedButton.icon(
              onPressed: () => AcoesCerebro.novaNota(context, ref),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Nova nota'),
            ),
            OutlinedButton.icon(
              onPressed: () => mostrarTutorialCerebro(context),
              icon: const Icon(Icons.school_outlined, size: 15),
              label: const Text('Guia & Tutorial'),
            ),
          ],
        ],
      );
    }

    _reagruparSePreciso(vault.revisao, filtroTag, notas);

    // Achata a arvore numa lista de linhas e deixa o `ListView.builder`
    // construir so o que aparece. Antes o explorer instanciava um widget por
    // nota do vault a cada rebuild - com 3.000 notas isso e o primeiro frame
    // inteiro gasto montando itens que ninguem ve.
    final linhas = <_Linha>[
      if (notas.length < 50 && filtroTag == null) const _Linha.demo(),
      if (filtroTag != null) _Linha.filtro(filtroTag),
      if (_fixadas.isNotEmpty) ...[
        _Linha.grupo(
            '@fixadas', 'FIXADAS', Icons.push_pin_outlined, _fixadas.length),
        if (!_fechadas.contains('@fixadas'))
          for (final n in _fixadas) _Linha.nota(n, 0),
      ],
      for (final pasta in _pastas) ...[
        _Linha.grupo(pasta, pasta.isEmpty ? 'RAIZ' : pasta.toUpperCase(),
            Icons.folder_outlined, _porPasta[pasta]!.length),
        if (!_fechadas.contains(pasta))
          for (final n in _porPasta[pasta]!) _Linha.nota(n, 1),
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      itemCount: linhas.length,
      // Linhas tem altura conhecida; informa-la evita o ListView medir filho a
      // filho para saber onde cada um cai.
      itemExtentBuilder: (i, _) => linhas[i].alturaFixa,
      itemBuilder: (context, i) {
        final l = linhas[i];
        switch (l.tipo) {
          case _TipoLinha.demo:
            return const _CartaoDemo();
          case _TipoLinha.filtro:
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PilulaTexto(
                  texto: '#${l.texto}',
                  icone: Icons.filter_alt_outlined,
                  cor: AppColors.pinkAccent,
                  onRemover: () =>
                      ref.read(filtroTagProvider.notifier).state = null,
                ),
              ),
            );
          case _TipoLinha.grupo:
            return _CabecalhoGrupo(
              texto: l.texto,
              icone: l.icone,
              contador: l.contador,
              aberta: !_fechadas.contains(l.chave),
              aoAlternar: () => _alternar(l.chave),
            );
          case _TipoLinha.nota:
            return _ItemNota(
                key: ValueKey(l.nota!.id), nota: l.nota!, nivel: l.nivel);
        }
      },
    );
  }

  // -- Agrupamento memoizado ------------------------------------------------
  //
  // Agrupar por pasta e ordenar e O(N log N); refazer isso a cada build (hover,
  // troca de aba, abrir/fechar pasta) e desperdicio puro. So recalcula quando o
  // vault muda de revisao ou o filtro de tag muda.
  int _revisaoAgrupada = -1;
  String? _filtroAgrupado;
  List<Nota> _fixadas = const [];
  List<String> _pastas = const [];
  Map<String, List<Nota>> _porPasta = const {};

  void _reagruparSePreciso(int revisao, String? filtroTag, List<Nota> notas) {
    if (revisao == _revisaoAgrupada && filtroTag == _filtroAgrupado) return;
    _revisaoAgrupada = revisao;
    _filtroAgrupado = filtroTag;

    _fixadas = notas.where((n) => n.fixada).toList()
      ..sort((a, b) => a.titulo.compareTo(b.titulo));

    final porPasta = <String, List<Nota>>{};
    for (final n in notas) {
      porPasta.putIfAbsent(n.pasta, () => []).add(n);
    }
    for (final lista in porPasta.values) {
      lista.sort((a, b) => a.titulo.compareTo(b.titulo));
    }
    _porPasta = porPasta;
    _pastas = porPasta.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return -1;
        if (b.isEmpty) return 1;
        return a.compareTo(b);
      });
  }

  void _alternar(String chave) => setState(() {
        if (!_fechadas.remove(chave)) _fechadas.add(chave);
      });
}

enum _TipoLinha { demo, filtro, grupo, nota }

/// Uma linha achatada do explorer - o que o `ListView.builder` consome.
class _Linha {
  const _Linha.demo()
      : tipo = _TipoLinha.demo,
        chave = '',
        texto = '',
        icone = null,
        contador = 0,
        nota = null,
        nivel = 0;

  const _Linha.filtro(this.texto)
      : tipo = _TipoLinha.filtro,
        chave = '',
        icone = null,
        contador = 0,
        nota = null,
        nivel = 0;

  const _Linha.grupo(this.chave, this.texto, this.icone, this.contador)
      : tipo = _TipoLinha.grupo,
        nota = null,
        nivel = 0;

  const _Linha.nota(this.nota, this.nivel)
      : tipo = _TipoLinha.nota,
        chave = '',
        texto = '',
        icone = null,
        contador = 0;

  final _TipoLinha tipo;
  final String chave;
  final String texto;
  final IconData? icone;
  final int contador;
  final Nota? nota;
  final int nivel;

  /// Altura de cada tipo de linha, para o `ListView` nao precisar medir.
  double get alturaFixa => switch (tipo) {
        _TipoLinha.demo => 108,
        _TipoLinha.filtro => 36,
        _TipoLinha.grupo => 28,
        _TipoLinha.nota => 34,
      };
}

class _CartaoDemo extends ConsumerWidget {
  const _CartaoDemo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.pinkAccent.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border:
            Border.all(color: AppColors.pinkAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 13, color: AppColors.pinkAccent),
              const SizedBox(width: 5),
              Text(
                'DADOS DE DEMONSTRAÇÃO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.pinkAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Gere 1.200 notas interligadas para exercitar grafo, clusters e busca.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 7),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              textStyle: const TextStyle(fontSize: 11),
            ),
            onPressed: () => AcoesCerebro.popularDemo(context, ref, 1200),
            icon: const Icon(Icons.auto_awesome, size: 13),
            label: const Text('Carregar 1.200 notas'),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoGrupo extends StatelessWidget {
  const _CabecalhoGrupo({
    required this.texto,
    required this.contador,
    required this.aberta,
    required this.aoAlternar,
    this.icone,
  });

  final String texto;
  final int contador;
  final bool aberta;
  final IconData? icone;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoAlternar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, AppSpacing.md, AppSpacing.md, 4),
        child: Row(
          children: [
            AnimatedRotation(
              turns: aberta ? 0 : -0.25,
              duration: const Duration(milliseconds: 130),
              child: Icon(Icons.expand_more,
                  size: 14, color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(width: 2),
            if (icone != null) ...[
              Icon(icone, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                texto,
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
            PilulaContagem(valor: contador),
          ],
        ),
      ),
    );
  }
}

class _ItemNota extends ConsumerStatefulWidget {
  const _ItemNota(
      {super.key, required this.nota, this.nivel = 0, this.subtitulo});

  final Nota nota;
  final int nivel;
  final String? subtitulo;

  @override
  ConsumerState<_ItemNota> createState() => _ItemNotaState();
}

class _ItemNotaState extends ConsumerState<_ItemNota> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final nota = widget.nota;
    final ativa = ref.watch(abasProvider).notaAtiva == nota.id;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => AcoesCerebro.abrirNota(ref, nota.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: EdgeInsets.fromLTRB(4 + widget.nivel * 10.0, 1, 4, 1),
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 5, 6, 5),
          decoration: BoxDecoration(
            color: ativa
                ? CerebroTokens.selecao(context)
                : (_hover ? CerebroTokens.hover(context) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              NotaIcone(tipo: nota.tipo, tamanho: 14),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nota.titulo.isEmpty ? nota.nomeArquivo : nota.titulo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        fontStyle:
                            nota.ehRascunho ? FontStyle.italic : FontStyle.normal,
                        fontWeight: ativa ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.textPrimaryOf(context)
                            .withValues(alpha: nota.ehRascunho ? 0.72 : 1),
                      ),
                    ),
                    if (widget.subtitulo != null)
                      Text(
                        widget.subtitulo!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.3,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (nota.fixada)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(Icons.push_pin,
                      size: 10, color: AppColors.pinkAccent),
                ),
              if (nota.ehDeAgente)
                const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Icon(Icons.auto_awesome,
                      size: 10, color: Color(0xFF7C3AED)),
                ),
              if (nota.metrics.inDegree > 0) ...[
                const SizedBox(width: 5),
                Tooltip(
                  message:
                      '${nota.metrics.inDegree} nota(s) apontam para esta',
                  child: Text('${nota.metrics.inDegree}',
                      style: TextStyle(
                          fontSize: 9.5, color: AppColors.textTertiary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Busca ───────────────────────────────────────────────────────────────────

class _Busca extends ConsumerStatefulWidget {
  const _Busca();

  @override
  ConsumerState<_Busca> createState() => _BuscaState();
}

class _BuscaState extends ConsumerState<_Busca> {
  late final TextEditingController _ctrl =
      TextEditingController(text: ref.read(termoBuscaProvider));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultados = ref.watch(resultadosBuscaProvider);
    final termo = ref.watch(termoBuscaProvider);

    // Mantém o campo em sincronia quando a busca é disparada de fora
    // (ex.: clique em "órfãs" na status bar).
    if (_ctrl.text != termo) {
      _ctrl.value = TextEditingValue(
        text: termo,
        selection: TextSelection.collapsed(offset: termo.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: CerebroTokens.trilho(context),
              hintText: 'tag:#operacao  tipo:moc  -rascunho',
              hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search, size: 16),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
              suffixIcon: termo.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () =>
                          ref.read(termoBuscaProvider.notifier).state = '',
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
            onChanged: (v) => ref.read(termoBuscaProvider.notifier).state = v,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (op, dica) in const [
                ('tag:', 'filtra por tag'),
                ('tipo:', 'filtra por tipo de nota'),
                ('path:', 'filtra por caminho'),
                ('origem:agente', 'só notas escritas pela IA'),
                ('orfa:true', 'só notas sem conexão'),
              ])
                Tooltip(
                  message: dica,
                  child: InkWell(
                    onTap: () {
                      final novo = '${_ctrl.text} $op'.trim();
                      _ctrl.text = novo;
                      ref.read(termoBuscaProvider.notifier).state = novo;
                    },
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: CerebroTokens.trilho(context),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text(op,
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppColors.textSecondaryOf(context))),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (termo.trim().isNotEmpty)
          RotuloSecao(
            texto:
                '${resultados.length} ${resultados.length == 1 ? "RESULTADO" : "RESULTADOS"}',
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 4),
          ),
        Expanded(
          child: resultados.isEmpty
              ? (termo.trim().isEmpty
                  ? const CerebroVazio(
                      icone: Icons.search,
                      titulo: 'Busque no acervo inteiro',
                      descricao:
                          'Combine texto livre com operadores para chegar '
                          'rápido ao que importa.',
                      dica: 'Ex.: absenteísmo tag:#operacao -tipo:diario',
                    )
                  : const CerebroVazio(
                      icone: Icons.search_off,
                      titulo: 'Nada encontrado',
                      descricao:
                          'Tente outros termos ou remova filtros da consulta.',
                    ))
              : ListView.builder(
                  itemCount: resultados.length,
                  itemBuilder: (context, i) {
                    final r = resultados[i];
                    return _ResultadoBusca(
                      nota: r.nota,
                      trechos: [for (final t in r.trechos) t.texto],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ResultadoBusca extends ConsumerStatefulWidget {
  const _ResultadoBusca({required this.nota, required this.trechos});

  final Nota nota;
  final List<String> trechos;

  @override
  ConsumerState<_ResultadoBusca> createState() => _ResultadoBuscaState();
}

class _ResultadoBuscaState extends ConsumerState<_ResultadoBusca> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => AcoesCerebro.abrirNota(ref, widget.nota.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.fromLTRB(4, 1, 4, 1),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? CerebroTokens.hover(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  NotaIcone(tipo: widget.nota.tipo, tamanho: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.nota.titulo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              for (final t in widget.trechos)
                Padding(
                  padding: const EdgeInsets.only(left: 19, top: 2),
                  child: Text(
                    t,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tags ────────────────────────────────────────────────────────────────────

class _Tags extends ConsumerWidget {
  const _Tags();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(vaultProvider);
    final index = ref.read(vaultProvider.notifier).index;
    final contagem = index.contagemTags;
    if (contagem.isEmpty) {
      return const CerebroVazio(
        icone: Icons.tag,
        titulo: 'Nenhuma tag ainda',
        descricao:
            'Adicione #tags às notas para agrupar temas sem criar pastas.',
        dica: 'No editor, digite # para autocompletar',
      );
    }

    final tags = contagem.keys.toList()..sort();
    final maximo = contagem.values.reduce((a, b) => a > b ? a : b);
    final filtro = ref.watch(filtroTagProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: tags.length,
      itemBuilder: (context, i) {
        final tag = tags[i];
        return _ItemTag(
          tag: tag,
          contagem: contagem[tag]!,
          proporcao: contagem[tag]! / maximo,
          ativa: filtro == tag,
          aoTocar: () {
            ref.read(filtroTagProvider.notifier).state =
                filtro == tag ? null : tag;
            ref
                .read(layoutProvider.notifier)
                .abrirPainel(PainelEsquerdo.explorer);
          },
        );
      },
    );
  }
}

class _ItemTag extends StatefulWidget {
  const _ItemTag({
    required this.tag,
    required this.contagem,
    required this.proporcao,
    required this.ativa,
    required this.aoTocar,
  });

  final String tag;
  final int contagem;
  final double proporcao;
  final bool ativa;
  final VoidCallback aoTocar;

  @override
  State<_ItemTag> createState() => _ItemTagState();
}

class _ItemTagState extends State<_ItemTag> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final nivel = '/'.allMatches(widget.tag).length;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.aoTocar,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: EdgeInsets.fromLTRB(4 + nivel * 10.0, 1, 4, 1),
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 4, AppSpacing.sm, 5),
          decoration: BoxDecoration(
            color: widget.ativa
                ? CerebroTokens.selecao(context)
                : (_hover ? CerebroTokens.hover(context) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.tag, size: 12, color: AppColors.warning),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.tag.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            widget.ativa ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Text('${widget.contagem}',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
                ],
              ),
              const SizedBox(height: 3),
              // Barra proporcional: a distribuição de temas vira visível.
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: CerebroTokens.trilho(context),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.proporcao.clamp(0.02, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.warning
                          .withValues(alpha: widget.ativa ? 0.9 : 0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sugestões (curadoria de higiene do grafo) ───────────────────────────────

class _Sugestoes extends ConsumerWidget {
  const _Sugestoes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(vaultProvider);
    final index = ref.read(vaultProvider.notifier).index;
    final orfas = index.orfas;
    final quebrados = index.linksQuebrados;

    // Um vault grande chega a ter milhares de links quebrados. Renderizar um
    // cartao para cada um travava o painel e nao ajudava ninguem: a lista e
    // para agir, e ninguem age em 1.800 itens. Mostra um lote e diz o resto.
    const teto = 50;
    final entradasQuebradas = quebrados.entries.take(teto).toList();
    final orfasVisiveis = orfas.take(teto).toList();
    final ocultosQuebrados = quebrados.length - entradasQuebradas.length;
    final ocultasOrfas = orfas.length - orfasVisiveis.length;

    if (orfas.isEmpty && quebrados.isEmpty) {
      return CerebroVazio(
        icone: Icons.check_circle_outline,
        cor: AppColors.success,
        titulo: 'Nada pendente',
        descricao:
            'Nenhuma órfã e nenhum link quebrado. O grafo está saudável.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        if (quebrados.isNotEmpty) ...[
          RotuloSecao(
              texto: 'LINKS QUEBRADOS', contador: quebrados.length),
          for (final e in entradasQuebradas)
            _CardSugestao(
              icone: Icons.link_off,
              cor: AppColors.danger,
              titulo: e.key,
              descricao:
                  '${e.value.length} ${e.value.length == 1 ? "nota aponta" : "notas apontam"} '
                  'para algo que não existe.',
              acao: 'Criar nota',
              aoAgir: () async {
                final id =
                    await ref.read(vaultProvider.notifier).criar(path: e.key);
                AcoesCerebro.abrirNota(ref, id);
              },
            ),
          if (ocultosQuebrados > 0)
            _MaisPendencias(quantidade: ocultosQuebrados),
        ],
        if (orfas.isNotEmpty) ...[
          RotuloSecao(texto: 'NOTAS ÓRFÃS', contador: orfas.length),
          for (final n in orfasVisiveis)
            _CardSugestao(
              icone: Icons.link_outlined,
              cor: AppColors.warning,
              titulo: n.titulo.isEmpty ? n.nomeArquivo : n.titulo,
              descricao:
                  'Sem nenhuma conexão. Uma nota que ninguém alcança é uma '
                  'nota que o Cérebro não lembra.',
              acao: 'Abrir',
              aoAgir: () => AcoesCerebro.abrirNota(ref, n.id),
            ),
          if (ocultasOrfas > 0) _MaisPendencias(quantidade: ocultasOrfas),
        ],
      ],
    );
  }
}

/// Rodape de secao truncada - deixa explicito que a lista foi cortada, em vez
/// de dar a impressao de que aquilo e tudo que existe.
class _MaisPendencias extends StatelessWidget {
  const _MaisPendencias({required this.quantidade});

  final int quantidade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Text(
        'e mais $quantidade - resolva estes primeiro',
        style: TextStyle(
          fontSize: 10.5,
          fontStyle: FontStyle.italic,
          color: AppColors.textSecondaryOf(context),
        ),
      ),
    );
  }
}

class _CardSugestao extends StatefulWidget {
  const _CardSugestao({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.descricao,
    required this.acao,
    required this.aoAgir,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String descricao;
  final String acao;
  final VoidCallback aoAgir;

  @override
  State<_CardSugestao> createState() => _CardSugestaoState();
}

class _CardSugestaoState extends State<_CardSugestao> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, 6, 2),
        decoration: BoxDecoration(
          color: _hover
              ? widget.cor.withValues(alpha: 0.07)
              : AppColors.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border(left: BorderSide(color: widget.cor, width: 2.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icone, size: 13, color: widget.cor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.titulo,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              widget.descricao,
              style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: AppColors.textSecondaryOf(context)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.aoAgir,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: widget.cor,
                ),
                child: Text(widget.acao, style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recentes ────────────────────────────────────────────────────────────────

class _Recentes extends ConsumerWidget {
  const _Recentes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(vaultProvider);
    final index = ref.read(vaultProvider.notifier).index;
    final notas = index.notas.values.where((n) => !n.excluida).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (notas.isEmpty) {
      return const CerebroVazio(
        icone: Icons.history,
        titulo: 'Sem histórico',
        descricao: 'As notas que você abrir ou editar aparecem aqui.',
      );
    }

    final agora = DateTime.now();
    final hoje = <Nota>[];
    final semana = <Nota>[];
    final antes = <Nota>[];
    for (final n in notas.take(40)) {
      final dias = agora.difference(n.updatedAt).inDays;
      if (dias < 1) {
        hoje.add(n);
      } else if (dias < 7) {
        semana.add(n);
      } else {
        antes.add(n);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        for (final (titulo, lista) in [
          ('HOJE', hoje),
          ('ESTA SEMANA', semana),
          ('ANTES', antes),
        ])
          if (lista.isNotEmpty) ...[
            RotuloSecao(texto: titulo, contador: lista.length),
            for (final n in lista)
              _ItemNota(nota: n, subtitulo: _relativo(agora, n.updatedAt)),
          ],
      ],
    );
  }

  static String _relativo(DateTime agora, DateTime d) {
    final delta = agora.difference(d);
    if (delta.inMinutes < 1) return 'agora mesmo';
    if (delta.inMinutes < 60) return 'há ${delta.inMinutes} min';
    if (delta.inHours < 24) return 'há ${delta.inHours} h';
    if (delta.inDays < 30) return 'há ${delta.inDays} d';
    return 'há ${(delta.inDays / 30).floor()} mês(es)';
  }
}
