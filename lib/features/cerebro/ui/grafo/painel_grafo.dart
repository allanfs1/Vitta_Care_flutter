import 'dart:ui' show ImageFilter;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../graph/grafo_builder.dart';
import '../../graph/grafo_engine.dart';
import '../../graph/grafo_modelo.dart';
import '../../graph/grafo_painter.dart';
import '../../providers/cerebro_providers.dart';
import '../../providers/grafo_busca_provider.dart';
import '../../data/models/nota.dart';
import '../../data/models/nota_enums.dart';
import '../comum/acoes_cerebro.dart';
import '../comum/cerebro_ui.dart';
import 'package:flutter/services.dart';
import '../comum/estados_vazios.dart';
import '../comum/tutorial_cerebro.dart';
import '../comum/card_rotina_preventiva.dart';
import '../editor/renderizador_vfm.dart';
import '../../services/rotina_preventiva_service.dart';
import '../../index/vault_index.dart';

/// Painel de grafo — cabeçalho Obsidian + tela interativa (`obsidian.md` §10.5).
class PainelGrafo extends ConsumerWidget {
  const PainelGrafo({
    super.key,
    this.escopo = const GrafoEscopo.global(),
    this.compacto = false,
  });

  final GrafoEscopo escopo;

  /// Modo grafo local (embutido abaixo do editor).
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultado = ref.watch(grafoProvider(escopo));

    return Column(
      children: [
        _Cabecalho(escopo: escopo, resultado: resultado, compacto: compacto),
        Expanded(
          child: resultado.grafo.vazio
              ? CerebroVazio(
                  icone: Icons.hub_outlined,
                  titulo: compacto
                      ? 'Esta nota ainda não se conectou a nada'
                      : 'Nenhum nó neste filtro',
                  descricao: compacto
                      ? 'Use [[links]] no texto para ligá-la ao resto do Cérebro.'
                      : 'Limpe os filtros do grafo ou popule com dados de teste.',
                  dica: compacto
                      ? 'Digite [[ no editor para ligar esta nota a outra'
                      : null,
                  acoes: [
                    if (!compacto)
                      FilledButton.icon(
                        onPressed: () =>
                            AcoesCerebro.popularDemo(context, ref, 1200),
                        icon: const Icon(Icons.science_outlined, size: 15),
                        label: const Text('Carregar 1.200 notas de teste'),
                      ),
                  ],
                )
              : GrafoView(
                  key: ValueKey('${escopo.notaFocal}-${escopo.profundidade}'),
                  resultado: resultado,
                  escopo: escopo,
                  compacto: compacto,
                ),
        ),
      ],
    );
  }
}

class _Cabecalho extends ConsumerWidget {
  const _Cabecalho({
    required this.escopo,
    required this.resultado,
    required this.compacto,
  });

  final GrafoEscopo escopo;
  final ResultadoGrafo resultado;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = resultado.grafo;
    final filtro = ref.watch(configGrafoProvider).filtro;
    final layout = ref.watch(layoutProvider);
    final layoutNotifier = ref.read(layoutProvider.notifier);
    final abasNotifier = ref.read(abasProvider.notifier);
    final abasEstado = ref.watch(abasProvider);
    final podeVoltar = abasEstado.historico.length > 1;

    return Container(
      height: compacto ? 32 : CerebroTokens.barra,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          if (!compacto) ...[
            BotaoIcone(
              icone: Icons.arrow_back,
              tooltip: 'Voltar nota anterior',
              atalho: 'Alt+←',
              tamanho: 16,
              onTap: podeVoltar ? abasNotifier.voltar : () {},
            ),
            const SizedBox(width: 2),
            BotaoIcone(
              icone: Icons.arrow_forward,
              tooltip: 'Avançar',
              tamanho: 16,
              onTap: () {},
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Icon(
            escopo.ehLocal ? Icons.polyline_outlined : Icons.hub_outlined,
            size: 15,
            color: AppColors.pinkAccent,
          ),
          const SizedBox(width: 8),
          Text(
            escopo.ehLocal ? 'Local Graph' : 'Graph view',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '${g.n} nós · ${g.arestas.length} arestas'
              '${resultado.truncado ? " (de ${resultado.totalOriginal})" : ""}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          if (filtro.isNotEmpty && !compacto) ...[
            const SizedBox(width: AppSpacing.sm),
            PilulaTexto(
              texto: filtro,
              icone: Icons.filter_alt_outlined,
              cor: AppColors.pinkAccent,
              onRemover: () => ref
                  .read(configGrafoProvider.notifier)
                  .atualizar((c) => c.copyWith(filtro: '')),
            ),
          ],
          if (!compacto) ...[
            const SizedBox(width: AppSpacing.md),
            _PilulaFiltroRapido(
              rotulo: 'Clusters',
              icone: Icons.bubble_chart_outlined,
              ativo: ref.watch(configGrafoProvider).colorirPorCluster,
              aoAlternar: () => ref.read(configGrafoProvider.notifier).atualizar(
                    (c) => c.copyWith(colorirPorCluster: !c.colorirPorCluster),
                  ),
            ),
            const SizedBox(width: 4),
            _PilulaFiltroRapido(
              rotulo: 'Tags',
              icone: Icons.tag,
              ativo: ref.watch(configGrafoProvider).mostrarTags,
              aoAlternar: () => ref.read(configGrafoProvider.notifier).atualizar(
                    (c) => c.copyWith(mostrarTags: !c.mostrarTags),
                  ),
            ),
            const SizedBox(width: 4),
            _PilulaFiltroRapido(
              rotulo: 'Entidades',
              icone: Icons.local_hospital_outlined,
              ativo: ref.watch(configGrafoProvider).mostrarEntidades,
              aoAlternar: () => ref.read(configGrafoProvider.notifier).atualizar(
                    (c) => c.copyWith(mostrarEntidades: !c.mostrarEntidades),
                  ),
            ),
            const SizedBox(width: 4),
            _PilulaFiltroRapido(
              rotulo: 'Rótulos',
              icone: Icons.subtitles_outlined,
              ativo: ref.watch(configGrafoProvider).mostrarRotulos,
              aoAlternar: () => ref.read(configGrafoProvider.notifier).atualizar(
                    (c) => c.copyWith(mostrarRotulos: !c.mostrarRotulos),
                  ),
            ),
          ],
          const Spacer(),
          if (escopo.ehLocal) const _SliderProfundidade(),
          if (compacto)
            BotaoIcone(
              icone: Icons.open_in_full,
              tooltip: 'Abrir visão completa do grafo',
              atalho: 'Ctrl+2',
              tamanho: 15,
              onTap: () => layoutNotifier.irPara(VistaCentral.grafo),
            )
          else ...[
            BotaoIcone(
              icone: layout.grafoTelaCheia
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              tooltip: layout.grafoTelaCheia
                  ? 'Sair da tela cheia (Esc / F11)'
                  : 'Maximizar em tela cheia (F11)',
              tamanho: 18,
              ativo: layout.grafoTelaCheia,
              onTap: layoutNotifier.alternarGrafoTelaCheia,
            ),
            const _BotaoConfig(),
            const _MenuMaisGrafo(),
          ],
        ],
      ),
    );
  }
}

class _PilulaFiltroRapido extends StatelessWidget {
  const _PilulaFiltroRapido({
    required this.rotulo,
    required this.icone,
    required this.ativo,
    required this.aoAlternar,
  });

  final String rotulo;
  final IconData icone;
  final bool ativo;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: aoAlternar,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ativo
              ? (themeDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativo
                ? AppColors.pinkAccent.withValues(alpha: 0.6)
                : AppColors.borderOf(context).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icone,
              size: 11,
              color: ativo
                  ? AppColors.pinkAccent
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 4),
            Text(
              rotulo,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: ativo ? FontWeight.w600 : FontWeight.normal,
                color: ativo
                    ? AppColors.textPrimaryOf(context)
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderProfundidade extends ConsumerWidget {
  const _SliderProfundidade();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configGrafoProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('profundidade',
            style: TextStyle(
                fontSize: 10, color: AppColors.textSecondaryOf(context))),
        SizedBox(
          width: 80,
          child: Slider(
            value: config.profundidadeLocal.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '${config.profundidadeLocal}',
            onChanged: (v) {
              ref
                  .read(configGrafoProvider.notifier)
                  .atualizar((c) => c.copyWith(profundidadeLocal: v.round()));
              final escopoAtual = ref.read(escopoGrafoProvider);
              if (escopoAtual.ehLocal) {
                ref.read(escopoGrafoProvider.notifier).state =
                    GrafoEscopo.local(escopoAtual.notaFocal!, v.round());
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Popover de configuração com os 4 grupos de §10.5.2.
class _BotaoConfig extends StatelessWidget {
  const _BotaoConfig();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Configurações do grafo',
      position: PopupMenuPosition.under,
      icon: Icon(Icons.settings_outlined,
          size: 16, color: AppColors.textSecondaryOf(context)),
      itemBuilder: (context) => [
        const PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(width: 310, child: _PainelConfig()),
        ),
      ],
    );
  }
}

class _MenuMaisGrafo extends ConsumerWidget {
  const _MenuMaisGrafo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configGrafoProvider);
    final notifier = ref.read(configGrafoProvider.notifier);
    final layoutNotifier = ref.read(layoutProvider.notifier);

    return PopupMenuButton<String>(
      tooltip: 'Mais opções do grafo',
      position: PopupMenuPosition.under,
      icon: Icon(Icons.more_vert,
          size: 16, color: AppColors.textSecondaryOf(context)),
      onSelected: (opcao) {
        switch (opcao) {
          case 'setas':
            notifier.atualizar(
                (c) => c.copyWith(mostrarSetas: !c.mostrarSetas));
          case 'cluster':
            notifier.atualizar(
                (c) => c.copyWith(colorirPorCluster: !c.colorirPorCluster));
          case 'foco':
            notifier.atualizar((c) => c.copyWith(modoFoco: !c.modoFoco));
          case 'rotulos':
            notifier.atualizar(
                (c) => c.copyWith(mostrarRotulos: !c.mostrarRotulos));
          case 'telaCheia':
            layoutNotifier.alternarGrafoTelaCheia();
          case 'demo':
            AcoesCerebro.popularDemo(context, ref, 1200);
          case 'resetar':
            notifier.restaurar();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'setas',
          child: Row(
            children: [
              Icon(
                config.mostrarSetas
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 16,
                color: AppColors.pinkAccent,
              ),
              const SizedBox(width: 8),
              const Text('Setas direcionais', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'cluster',
          child: Row(
            children: [
              Icon(
                config.colorirPorCluster
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 16,
                color: AppColors.pinkAccent,
              ),
              const SizedBox(width: 8),
              const Text('Colorir por cluster (Louvain)',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'foco',
          child: Row(
            children: [
              Icon(
                config.modoFoco
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 16,
                color: AppColors.pinkAccent,
              ),
              const SizedBox(width: 8),
              const Text('Modo foco ao selecionar',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rotulos',
          child: Row(
            children: [
              Icon(
                config.mostrarRotulos
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 16,
                color: AppColors.pinkAccent,
              ),
              const SizedBox(width: 8),
              const Text('Exibir rótulos dos nós',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'telaCheia',
          child: Row(
            children: [
              Icon(Icons.fullscreen, size: 16),
              SizedBox(width: 8),
              Text('Alternar tela cheia (F11)', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'demo',
          child: Row(
            children: [
              Icon(Icons.science_outlined, size: 16),
              SizedBox(width: 8),
              Text('Carregar 1.200 notas de teste',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'resetar',
          child: Row(
            children: [
              Icon(Icons.restart_alt, size: 16),
              SizedBox(width: 8),
              Text('Restaurar padrões', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PainelConfig extends ConsumerWidget {
  const _PainelConfig();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configGrafoProvider);
    final notifier = ref.read(configGrafoProvider.notifier);

    Widget slider(String rotulo, double valor, double min, double max,
        ConfigGrafo Function(ConfigGrafo, double) aplicar) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(rotulo,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondaryOf(context))),
            ),
            Expanded(
              child: Slider(
                value: valor.clamp(min, max),
                min: min,
                max: max,
                onChanged: (v) => notifier.atualizar((c) => aplicar(c, v)),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(valor.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
            ),
          ],
        ),
      );
    }

    Widget toggle(String rotulo, bool valor,
        ConfigGrafo Function(ConfigGrafo, bool) aplicar) {
      return SwitchListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        title: Text(rotulo, style: const TextStyle(fontSize: 12)),
        value: valor,
        onChanged: (v) => notifier.atualizar((c) => aplicar(c, v)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _tituloGrupo(context, 'FILTROS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextFormField(
                initialValue: config.filtro,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'tag:#operacao -tipo:diario',
                ),
                onFieldSubmitted: (v) =>
                    notifier.atualizar((c) => c.copyWith(filtro: v)),
              ),
            ),
            toggle('Tags', config.mostrarTags,
                (c, v) => c.copyWith(mostrarTags: v)),
            toggle('Entidades operacionais', config.mostrarEntidades,
                (c, v) => c.copyWith(mostrarEntidades: v)),
            toggle('Links não resolvidos', config.mostrarNaoResolvidos,
                (c, v) => c.copyWith(mostrarNaoResolvidos: v)),
            toggle('Notas arquivadas', config.mostrarArquivadas,
                (c, v) => c.copyWith(mostrarArquivadas: v)),
            _tituloGrupo(context, 'EXIBIÇÃO'),
            toggle('Setas direcionais (Obsidian)', config.mostrarSetas,
                (c, v) => c.copyWith(mostrarSetas: v)),
            toggle('Colorir por cluster (Louvain)', config.colorirPorCluster,
                (c, v) => c.copyWith(colorirPorCluster: v)),
            toggle('Exibir rótulos dos nós', config.mostrarRotulos,
                (c, v) => c.copyWith(mostrarRotulos: v)),
            toggle('Exibir rótulos de clusters', config.mostrarRotulosClusters,
                (c, v) => c.copyWith(mostrarRotulosClusters: v)),
            toggle('Rótulos inteligentes (LOD)', config.rotulosAuto,
                (c, v) => c.copyWith(rotulosAuto: v)),
            toggle('Modo foco ao selecionar', config.modoFoco,
                (c, v) => c.copyWith(modoFoco: v)),
            slider('Tamanho nós', config.multiplicadorTamanho, 0.5, 5,
                (c, v) => c.copyWith(multiplicadorTamanho: v)),
            slider('Tamanho rótulos', config.tamanhoRotulo, 0.6, 2.0,
                (c, v) => c.copyWith(tamanhoRotulo: v)),
            slider('Espessura', config.espessuraLinha, 0.3, 3,
                (c, v) => c.copyWith(espessuraLinha: v)),
            _tituloGrupo(context, 'FORÇAS'),
            slider('Central', config.forcaCentro, 0, 1,
                (c, v) => c.copyWith(forcaCentro: v)),
            slider('Repulsão', config.forcaRepulsao, 0, 20,
                (c, v) => c.copyWith(forcaRepulsao: v)),
            slider('Dist. links', config.distanciaLinks, 10, 140,
                (c, v) => c.copyWith(distanciaLinks: v)),
            slider('Atrito', config.atrito, 0.1, 0.95,
                (c, v) => c.copyWith(atrito: v)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: TextButton.icon(
                onPressed: notifier.restaurar,
                icon: const Icon(Icons.restart_alt, size: 14),
                label: const Text('Restaurar padrões',
                    style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tituloGrupo(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      );
}

/// A tela do grafo: física, câmera, gestos e pintura (§7.3, §7.4, §7.8).
class GrafoView extends ConsumerStatefulWidget {
  const GrafoView({
    super.key,
    required this.resultado,
    required this.escopo,
    this.compacto = false,
  });

  final ResultadoGrafo resultado;
  final GrafoEscopo escopo;
  final bool compacto;

  @override
  ConsumerState<GrafoView> createState() => _GrafoViewState();
}

class _GrafoViewState extends ConsumerState<GrafoView>
    with SingleTickerProviderStateMixin {
  late GrafoEngine _engine;
  late Ticker _ticker;
  final _cache = LabelCache();

  Offset _offset = Offset.zero;
  double _escala = 1.0;
  Offset? _panInicio;
  Offset _offsetInicio = Offset.zero;
  double _escalaInicio = 1.0;

  int? _selecionado;
  int? _hover;
  int? _arrastando;

  int _framesLentos = 0;
  int _framesWarmup = 0;
  bool _modoPerformance = false;
  bool _legenda = false;
  bool _menuFiltrosAberto = false;
  bool _modoRadarRisco = false;
  bool _exibirMiniMapa = true;
  Set<String> _causas = {};
  Set<String> _efeitos = {};
  Duration _ultimoFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _engine = GrafoEngine(widget.resultado.grafo,
        config: ref.read(configGrafoProvider));
    // O ticker vem antes do listener: `_ancorarSeLocal` reaquece o engine, e
    // um `notifyListeners` disparado com `_ticker` ainda não atribuído estoura
    // um LateInitializationError no primeiro frame do grafo local.
    _ticker = createTicker(_aoTick)..start();
    _engine.addListener(_retomarSePreciso);
    _ancorarSeLocal();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enquadrar());
  }

  @override
  void didUpdateWidget(covariant GrafoView old) {
    super.didUpdateWidget(old);
    if (!identical(old.resultado.grafo, widget.resultado.grafo)) {
      final posicoesAnteriores = _engine.exportarPosicoes();
      _engine.removeListener(_retomarSePreciso);
      _engine.dispose();
      _engine = GrafoEngine(widget.resultado.grafo,
          config: ref.read(configGrafoProvider))
        ..addListener(_retomarSePreciso);
      _engine.carregarPosicoes(posicoesAnteriores);
      _ancorarSeLocal();
      _selecionado = null;
      _retomarSePreciso();
    }
  }

  void _ancorarSeLocal() {
    if (!widget.escopo.ehLocal) return;
    final focal = widget.resultado.grafo.indiceDe(widget.escopo.notaFocal!);
    if (focal == null) return;
    final saltos = <int, int>{focal: 0};
    var fronteira = {focal};
    for (var d = 1; d <= widget.escopo.profundidade; d++) {
      final proxima = <int>{};
      for (final i in fronteira) {
        for (final v in widget.resultado.grafo.vizinhos(i)) {
          if (saltos.containsKey(v)) continue;
          saltos[v] = d;
          proxima.add(v);
        }
      }
      if (proxima.isEmpty) break;
      fronteira = proxima;
    }
    _engine.ancorarRadial(focal, saltos);
  }

  void _aoTick(Duration elapsed) {
    if (_ultimoFrame == Duration.zero) {
      _ultimoFrame = elapsed;
      return;
    }
    final delta = elapsed - _ultimoFrame;
    _ultimoFrame = elapsed;

    // Ignora os primeiros 60 frames (aquecimento do browser e compilação de shaders)
    if (_framesWarmup < 60) {
      _framesWarmup++;
      _framesLentos = 0;
    } else if (delta.inMilliseconds > 45) {
      _framesLentos++;
      if (_framesLentos >= 8 && !_modoPerformance) {
        setState(() => _modoPerformance = true);
      }
    } else if (delta.inMilliseconds <= 25) {
      _framesLentos = 0;
    }

    _engine.atualizarConfig(ref.read(configGrafoProvider));
    if (!_engine.tick()) {
      // A simulação congelou: pausar o Ticker para poupar CPU
      _pausar();
    }
  }

  void _pausar() {
    if (!_ticker.isActive) return;
    _ticker.stop();
    _ultimoFrame = Duration.zero;
    _framesLentos = 0;
  }

  void _retomarSePreciso() {
    if (!mounted || _engine.congelado || _ticker.isActive) return;
    _ultimoFrame = Duration.zero;
    _ticker.start();
  }

  @override
  void dispose() {
    _engine.removeListener(_retomarSePreciso);
    _ticker.dispose();
    _engine.dispose();
    _cache.limpar();
    super.dispose();
  }

  // ── Câmera ────────────────────────────────────────────────────────────────

  Offset _paraGrafo(Offset tela) => (tela - _offset) / _escala;

  void _enquadrar() {
    if (!mounted) return;
    final size = context.size;
    if (size == null || _engine.n == 0) return;
    final l = _engine.limites;
    final larguraG = (l.x1 - l.x0).abs().clamp(1.0, double.infinity);
    final alturaG = (l.y1 - l.y0).abs().clamp(1.0, double.infinity);
    final escala =
        (size.width / larguraG).clamp(0.05, 3.0) < (size.height / alturaG)
            ? size.width / larguraG
            : size.height / alturaG;
    setState(() {
      _escala = (escala * 0.82).clamp(0.06, 4.0);
      final cx = (l.x0 + l.x1) / 2;
      final cy = (l.y0 + l.y1) / 2;
      _offset = Offset(size.width / 2 - cx * _escala,
          size.height / 2 - cy * _escala);
    });
  }

  void _zoom(double fator, Offset foco) {
    final antes = _paraGrafo(foco);
    setState(() {
      _escala = (_escala * fator).clamp(0.05, 8.0);
      _offset = foco - antes * _escala;
    });
  }

  void _zoomCentro(double fator) {
    final size = context.size;
    if (size == null) return;
    _zoom(fator, Offset(size.width / 2, size.height / 2));
  }

  Widget _separador(BuildContext context) => Container(
        height: 1,
        width: 20,
        margin: const EdgeInsets.symmetric(vertical: 3),
        color: AppColors.borderOf(context),
      );

  // ── Interação ─────────────────────────────────────────────────────────────

  void _selecionar(int? i) {
    setState(() {
      _selecionado = i;
      if (i == null) {
        _causas = {};
        _efeitos = {};
      }
    });
    if (i == null) {
      ref.read(noSelecionadoProvider.notifier).state = null;
      return;
    }
    final no = widget.resultado.grafo.nos[i];
    ref.read(noSelecionadoProvider.notifier).state = no.id;
  }

  void _focarNo(String notaId) {
    final idx = widget.resultado.grafo.indiceDe(notaId);
    if (idx == null) return;
    final x = _engine.px[idx];
    final y = _engine.py[idx];
    final size = context.size;
    if (size == null) return;
    setState(() {
      _escala = 1.35;
      _offset = Offset(size.width / 2 - x * _escala, size.height / 2 - y * _escala);
      _selecionar(idx);
    });
  }

  void _abrirNo(int i) {
    final no = widget.resultado.grafo.nos[i];
    if (no.noTipo != NoTipo.nota) return;
    _abrirNotaPorId(no.id);
  }

  void _abrirNotaPorId(String notaId) {
    ref.read(abasProvider.notifier).abrir(notaId);
    ref.read(layoutProvider.notifier).irPara(VistaCentral.editor);
  }

  void _rastrearCausaEEfeito(String notaId) {
    final index = ref.read(vaultProvider.notifier).index;
    final (c, e) =
        const RotinaPreventivaService().rastrearCausaEEfeito(notaId, index);
    setState(() {
      _causas = c;
      _efeitos = e;
    });
  }

  void _abrirDossieExecutivo() {
    final index = ref.read(vaultProvider.notifier).index;
    showDialog<void>(
      context: context,
      builder: (context) => _ModalDossieExecutivo(index: index),
    );
  }

  void _mostrarModalLeitura(String notaId) {
    showDialog<void>(
      context: context,
      builder: (context) => _ModalLeituraRapidaNota(
        notaId: notaId,
        aoAbrirNoEditor: () {
          Navigator.pop(context);
          _abrirNotaPorId(notaId);
        },
      ),
    );
  }

  EstadoInteracao _estadoInteracao() {
    final config = ref.watch(configGrafoProvider);
    if (_selecionado == null || !config.modoFoco) {
      return EstadoInteracao(selecionado: _selecionado, hover: _hover);
    }
    final grafo = widget.resultado.grafo;
    final foco = grafo.alcance(_selecionado!, config.profundidadeLocal);
    final arestas = <int>{};
    for (var e = 0; e < grafo.arestas.length; e++) {
      final a = grafo.arestas[e];
      if (foco.contains(a.de) && foco.contains(a.para)) arestas.add(e);
    }
    return EstadoInteracao(
      selecionado: _selecionado,
      hover: _hover,
      emFoco: foco,
      arestasDestacadas: arestas,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A config chegava ao engine dentro do `_aoTick`. Com o ticker pausavel,
    // mexer num slider de fisica com o grafo congelado nao teria efeito nenhum
    // - a config precisa ser empurrada aqui e a simulacao, reaquecida.
    ref.listen(configGrafoProvider, (_, nova) {
      _engine.atualizarConfig(nova);
      _retomarSePreciso();
    });

    final config = ref.watch(configGrafoProvider);
    final paleta = PaletaGrafo.de(context);
    final layout = ref.watch(layoutProvider);
    final layoutNotifier = ref.read(layoutProvider.notifier);
    final busca = ref.watch(grafoBuscaProvider);
    final index = ref.watch(vaultProvider.notifier).index;
    final nosCriticos =
        const RotinaPreventivaService().identificarNosCriticos(index);

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerSignal: (evento) {
              if (evento is PointerScrollEvent) {
                _zoom(evento.scrollDelta.dy > 0 ? 0.9 : 1.1,
                    evento.localPosition);
              }
            },
            child: MouseRegion(
              onHover: (e) {
                final g = _paraGrafo(e.localPosition);
                final i = _engine.noEm(g.dx, g.dy);
                if (i != _hover) setState(() => _hover = i);
              },
              onExit: (_) => setState(() => _hover = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final g = _paraGrafo(d.localPosition);
                  _selecionar(_engine.noEm(g.dx, g.dy));
                },
                onDoubleTapDown: (d) {
                  final g = _paraGrafo(d.localPosition);
                  final i = _engine.noEm(g.dx, g.dy);
                  if (i != null) _abrirNo(i);
                },
                onScaleStart: (d) {
                  final g = _paraGrafo(d.localFocalPoint);
                  _arrastando = _engine.noEm(g.dx, g.dy);
                  _panInicio = d.localFocalPoint;
                  _offsetInicio = _offset;
                  _escalaInicio = _escala;
                },
                onScaleUpdate: (d) {
                  if (_arrastando != null) {
                    final g = _paraGrafo(d.localFocalPoint);
                    _engine.travar(_arrastando!, g.dx, g.dy);
                    _engine.reaquecer(0.25);
                    return;
                  }
                  setState(() {
                    if (d.scale != 1.0) {
                      _escala = (_escalaInicio * d.scale).clamp(0.05, 8.0);
                    }
                    _offset =
                        _offsetInicio + (d.localFocalPoint - _panInicio!);
                  });
                },
                onScaleEnd: (_) => _arrastando = null,
                child: CustomPaint(
                  painter: GrafoPainter(
                    engine: _engine,
                    config: config,
                    paleta: paleta,
                    cache: _cache,
                    offset: _offset,
                    escala: _escala,
                    interacao: _estadoInteracao(),
                    modoPerformance: _modoPerformance,
                    buscaAtiva: busca.idsEncontrados,
                    nosCriticos: nosCriticos,
                    modoRadarRisco: _modoRadarRisco,
                    exibirRotulosClusters: config.mostrarRotulosClusters,
                    causas: _causas,
                    efeitos: _efeitos,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        // Barra de busca do Grafo (Normal + Agente IA)
        if (!widget.compacto)
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: _BarraBuscaGrafoOverlay(
              aoFocarNo: _focarNo,
              aoAbrirNoEditor: _abrirNotaPorId,
              aoVerLeituraRapida: _mostrarModalLeitura,
            ),
          ),
        // Painel de raciocínio da IA
        if (!widget.compacto &&
            busca.modo == ModoBuscaGrafo.agente &&
            (busca.carregando ||
                busca.raciocinio.isNotEmpty ||
                busca.erro != null))
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm + 115,
            child: _CardRaciocinioIA(
              busca: busca,
              aoFocarNo: _focarNo,
              aoAbrirNoEditor: _abrirNotaPorId,
              aoVerLeituraRapida: _mostrarModalLeitura,
              aoFechar: () => ref.read(grafoBuscaProvider.notifier).limpar(),
            ),
          ),
        // Card de Preview da Nota Selecionada no Grafo
        if (!widget.compacto &&
            _selecionado != null &&
            _selecionado! >= 0 &&
            _selecionado! < widget.resultado.grafo.nos.length &&
            widget.resultado.grafo.nos[_selecionado!].noTipo == NoTipo.nota)
          Positioned(
            right: AppSpacing.sm + 48,
            bottom: AppSpacing.sm,
            child: _CardPreviewNotaFlutuante(
              notaId: widget.resultado.grafo.nos[_selecionado!].id,
              aoAbrirNoEditor: () =>
                  _abrirNotaPorId(widget.resultado.grafo.nos[_selecionado!].id),
              aoVerLeituraRapida: () =>
                  _mostrarModalLeitura(widget.resultado.grafo.nos[_selecionado!].id),
              aoRastrearCausaEEfeito: () =>
                  _rastrearCausaEEfeito(widget.resultado.grafo.nos[_selecionado!].id),
              aoFechar: () => _selecionar(null),
            ),
          ),
        // Mini-Mapa de Navegação 2D
        if (!widget.compacto && _exibirMiniMapa && _selecionado == null)
          Positioned(
            right: AppSpacing.sm + 48,
            bottom: AppSpacing.sm,
            child: _MiniMapaGrafo(
              engine: _engine,
              offset: _offset,
              escala: _escala,
              nosCriticos: nosCriticos,
              aoMoverCamera: (novoOffset) {
                setState(() => _offset = novoOffset);
              },
            ),
          ),
        // Barra de ferramentas flutuante lateral (Obsidian Overlay Toolbar)
        Positioned(
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: CerebroTokens.flutuante(context),
            ),
            padding: const EdgeInsets.all(3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Configurações (Engrenagem)
                _BotaoFlutuante(
                  icone: Icons.settings_outlined,
                  tooltip: 'Configurações e forças',
                  ativo: _menuFiltrosAberto,
                  onTap: () =>
                      setState(() => _menuFiltrosAberto = !_menuFiltrosAberto),
                ),
                // Varinha mágica (Filtros & Grupos)
                _BotaoFlutuante(
                  icone: Icons.auto_awesome_outlined,
                  tooltip: config.colorirPorCluster
                      ? 'Desativar cores de cluster'
                      : 'Colorir por cluster (Louvain)',
                  ativo: config.colorirPorCluster,
                  onTap: () {
                    ref.read(configGrafoProvider.notifier).atualizar((c) => c.copyWith(
                          colorirPorCluster: !c.colorirPorCluster,
                        ));
                  },
                ),
                // Radar de Risco
                _BotaoFlutuante(
                  icone: Icons.radar,
                  tooltip: _modoRadarRisco
                      ? 'Desativar Radar de Risco'
                      : 'Radar de Risco (${nosCriticos.length} alertas detectados)',
                  ativo: _modoRadarRisco,
                  onTap: () =>
                      setState(() => _modoRadarRisco = !_modoRadarRisco),
                ),
                // Dossiê Executivo
                _BotaoFlutuante(
                  icone: Icons.description_outlined,
                  tooltip: 'Dossiê Executivo da Rede de Conhecimento',
                  onTap: _abrirDossieExecutivo,
                ),
                // Mini-Mapa
                _BotaoFlutuante(
                  icone: Icons.map_outlined,
                  tooltip: _exibirMiniMapa ? 'Ocultar Mini-Mapa' : 'Exibir Mini-Mapa',
                  ativo: _exibirMiniMapa,
                  onTap: () => setState(() => _exibirMiniMapa = !_exibirMiniMapa),
                ),
                // Legenda de cores e filtros
                _BotaoFlutuante(
                  icone: Icons.palette_outlined,
                  tooltip: _legenda
                      ? 'Ocultar legenda'
                      : (config.temFiltrosLegendaAtivos
                          ? 'Legenda (${config.totalFiltrosLegendaAtivos} categorias desativadas)'
                          : 'Mostrar legenda e filtros'),
                  ativo: _legenda || config.temFiltrosLegendaAtivos,
                  onTap: () => setState(() => _legenda = !_legenda),
                ),
                // Rótulos / legendas de texto dos nós
                _BotaoFlutuante(
                  icone: config.mostrarRotulos
                      ? Icons.subtitles
                      : Icons.subtitles_off_outlined,
                  tooltip: config.mostrarRotulos
                      ? 'Ocultar rótulos/legendas dos nós'
                      : 'Exibir rótulos/legendas dos nós (alto consumo)',
                  ativo: config.mostrarRotulos,
                  onTap: () {
                    ref.read(configGrafoProvider.notifier).atualizar(
                          (c) => c.copyWith(mostrarRotulos: !c.mostrarRotulos),
                        );
                  },
                ),
                // Maximizar tela cheia
                _BotaoFlutuante(
                  icone: layout.grafoTelaCheia
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  tooltip: layout.grafoTelaCheia
                      ? 'Sair da tela cheia (Esc / F11)'
                      : 'Maximizar em tela cheia (F11)',
                  ativo: layout.grafoTelaCheia,
                  onTap: layoutNotifier.alternarGrafoTelaCheia,
                ),
                _separador(context),
                _BotaoFlutuante(
                  icone: Icons.add,
                  tooltip: 'Aproximar (+)',
                  onTap: () => _zoomCentro(1.25),
                ),
                _BotaoFlutuante(
                  icone: Icons.remove,
                  tooltip: 'Afastar (-)',
                  onTap: () => _zoomCentro(0.8),
                ),
                _separador(context),
                _BotaoFlutuante(
                  icone: Icons.center_focus_strong,
                  tooltip: 'Enquadrar tudo',
                  onTap: _enquadrar,
                ),
                _BotaoFlutuante(
                  icone: Icons.local_fire_department_outlined,
                  tooltip: 'Reaquecer simulação de forças',
                  onTap: () => _engine.reaquecer(0.6),
                ),
              ],
            ),
          ),
        ),
        // Painel flutuante de configurações e forças quando ativado pelo botão lateral
        if (_menuFiltrosAberto)
          Positioned(
            right: AppSpacing.sm + 44,
            top: AppSpacing.sm,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              color: AppColors.surfaceOf(context),
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom:
                              BorderSide(color: AppColors.borderOf(context)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.settings_outlined, size: 14),
                          const SizedBox(width: 6),
                          const Text(
                            'Configurações do Grafo',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () =>
                                setState(() => _menuFiltrosAberto = false),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _PainelConfig(),
                  ],
                ),
              ),
            ),
          ),
        if (_legenda)
          Positioned(
            right: AppSpacing.sm + 44,
            top: AppSpacing.sm + 100,
            child: _Legenda(
              nos: widget.resultado.grafo.nos,
              colorirPorCluster: config.colorirPorCluster,
              aoFechar: () => setState(() => _legenda = false),
            ),
          ),
        if (_modoPerformance)
          Positioned(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: ActionChip(
              avatar: const Icon(Icons.speed, size: 13),
              label: const Text('modo performance',
                  style: TextStyle(fontSize: 10)),
              onPressed: () => setState(() {
                _modoPerformance = false;
                _framesLentos = 0;
              }),
            ),
          ),
        if (widget.resultado.truncado)
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                '${widget.resultado.totalOriginal} nós — mostrando os '
                '${widget.resultado.grafo.n} de maior PageRank',
                style: TextStyle(fontSize: 10, color: AppColors.warning),
              ),
            ),
          ),
      ],
    );
  }
}

class _BotaoFlutuante extends StatelessWidget {
  const _BotaoFlutuante({
    required this.icone,
    required this.tooltip,
    required this.onTap,
    this.ativo = false,
  });

  final IconData icone;
  final String tooltip;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BotaoIcone(
        icone: icone,
        tooltip: tooltip,
        ativo: ativo,
        tamanho: 16,
        onTap: onTap,
      );
}

/// Legenda interativa das cores e filtros de nós do grafo.
class _Legenda extends ConsumerWidget {
  const _Legenda({
    required this.nos,
    this.colorirPorCluster = false,
    this.aoFechar,
  });

  final List<GrafoNo> nos;
  final bool colorirPorCluster;
  final VoidCallback? aoFechar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configGrafoProvider);
    final notifier = ref.read(configGrafoProvider.notifier);

    // Contagens de nós presentes
    final contagemTipos = <NotaTipo, int>{};
    final contagemEntidades = <EntidadeTipo, int>{};
    final clusters = <int, (String, Color, int)>{};
    var tags = 0;
    var naoResolvidos = 0;

    for (final no in nos) {
      if (colorirPorCluster && no.cluster > 0) {
        final atual = clusters[no.cluster];
        if (atual == null) {
          clusters[no.cluster] = (no.rotulo, no.cor, 1);
        } else {
          clusters[no.cluster] = (atual.$1, atual.$2, atual.$3 + 1);
        }
      }

      switch (no.noTipo) {
        case NoTipo.nota:
          if (no.notaTipo != null) {
            contagemTipos.update(no.notaTipo!, (v) => v + 1, ifAbsent: () => 1);
          }
        case NoTipo.entidade:
          if (no.entidadeTipo != null) {
            contagemEntidades.update(no.entidadeTipo!, (v) => v + 1, ifAbsent: () => 1);
          }
        case NoTipo.tag:
          tags++;
        case NoTipo.naoResolvido:
          naoResolvidos++;
      }
    }

    // Garante que tipos presentes ou desativados apareçam na legenda
    for (final tipoId in config.tiposDesativados) {
      final tipo = NotaTipo.fromId(tipoId);
      contagemTipos.putIfAbsent(tipo, () => 0);
    }
    for (final entId in config.entidadesDesativadas) {
      final ent = EntidadeTipo.fromId(entId);
      if (ent != null) contagemEntidades.putIfAbsent(ent, () => 0);
    }

    final tipos = contagemTipos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final entidades = contagemEntidades.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final listaClusters = clusters.entries.toList()
      ..sort((a, b) => b.value.$3.compareTo(a.value.$3));

    final temFiltros = config.temFiltrosLegendaAtivos;

    return Container(
      width: 232,
      constraints: const BoxConstraints(maxHeight: 390),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: temFiltros
              ? AppColors.pinkAccent.withValues(alpha: 0.45)
              : AppColors.borderOf(context),
        ),
        boxShadow: CerebroTokens.flutuante(context),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 8, AppSpacing.sm, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da legenda com ações
          Row(
            children: [
              Expanded(
                child: Text(
                  colorirPorCluster ? 'CLUSTERS (LOUVAIN)' : 'LEGENDA & FILTROS',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              if (temFiltros)
                Tooltip(
                  message: 'Reativar todas as opções',
                  child: InkWell(
                    onTap: () => notifier.atualizar((c) => c.copyWith(
                          tiposDesativados: const {},
                          entidadesDesativadas: const {},
                          clustersDesativados: const {},
                          mostrarTags: true,
                          mostrarEntidades: true,
                          mostrarNaoResolvidos: false,
                        )),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restore, size: 12, color: AppColors.pinkAccent),
                          const SizedBox(width: 2),
                          Text(
                            'Ativar todos',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: AppColors.pinkAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              if (aoFechar != null)
                InkWell(
                  onTap: aoFechar,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 8),
          // Lista de opções rolável com toggles
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (colorirPorCluster) ...[
                    for (final c in listaClusters)
                      _linhaInterativa(
                        context: context,
                        cor: c.value.$2,
                        rotulo: '✦ ${c.value.$1}',
                        valor: c.value.$3,
                        ativo: !config.clustersDesativados.contains(c.key),
                        aoAlternar: () {
                          final novo = Set<int>.from(config.clustersDesativados);
                          if (novo.contains(c.key)) {
                            novo.remove(c.key);
                          } else {
                            novo.add(c.key);
                          }
                          notifier.atualizar((cfg) => cfg.copyWith(clustersDesativados: novo));
                        },
                      ),
                  ] else ...[
                    // Seção de Tipos de Notas
                    if (tipos.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 3),
                        child: Text(
                          'NOTAS',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      for (final e in tipos)
                        _linhaInterativa(
                          context: context,
                          cor: e.key.cor,
                          rotulo: e.key.label,
                          valor: e.value,
                          icone: e.key.icon,
                          ativo: !config.tiposDesativados.contains(e.key.id),
                          aoAlternar: () {
                            final novo = Set<String>.from(config.tiposDesativados);
                            if (novo.contains(e.key.id)) {
                              novo.remove(e.key.id);
                            } else {
                              novo.add(e.key.id);
                            }
                            notifier.atualizar((cfg) => cfg.copyWith(tiposDesativados: novo));
                          },
                        ),
                    ],

                    // Seção de Entidades Operacionais
                    if (entidades.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 3),
                        child: Text(
                          'ENTIDADES OPERACIONAIS',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      for (final e in entidades)
                        _linhaInterativa(
                          context: context,
                          cor: e.key.cor,
                          rotulo: e.key.label,
                          valor: e.value,
                          icone: e.key.icon,
                          ativo: config.mostrarEntidades && !config.entidadesDesativadas.contains(e.key.id),
                          aoAlternar: () {
                            final novo = Set<String>.from(config.entidadesDesativadas);
                            if (novo.contains(e.key.id)) {
                              novo.remove(e.key.id);
                            } else {
                              novo.add(e.key.id);
                            }
                            notifier.atualizar((cfg) => cfg.copyWith(
                                  mostrarEntidades: true,
                                  entidadesDesativadas: novo,
                                ));
                          },
                        ),
                    ],

                    // Seção de Tags e Auxiliares
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 3),
                      child: Text(
                        'ELEMENTOS AUXILIARES',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _linhaInterativa(
                      context: context,
                      cor: const Color(0xFFFACC15),
                      rotulo: 'Tags',
                      valor: tags,
                      icone: Icons.tag,
                      ativo: config.mostrarTags,
                      aoAlternar: () => notifier.atualizar(
                          (cfg) => cfg.copyWith(mostrarTags: !cfg.mostrarTags)),
                    ),
                    _linhaInterativa(
                      context: context,
                      cor: const Color(0xFF475569),
                      rotulo: 'Não resolvidos',
                      valor: naoResolvidos,
                      icone: Icons.link_off,
                      ativo: config.mostrarNaoResolvidos,
                      aoAlternar: () => notifier.atualizar((cfg) =>
                          cfg.copyWith(mostrarNaoResolvidos: !cfg.mostrarNaoResolvidos)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 8),
          Text(
            'Clique no item para desativar/ativar no grafo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaInterativa({
    required BuildContext context,
    required Color cor,
    required String rotulo,
    required int valor,
    required bool ativo,
    required VoidCallback aoAlternar,
    IconData? icone,
  }) {
    return InkWell(
      onTap: aoAlternar,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
        decoration: BoxDecoration(
          color: ativo ? Colors.transparent : CerebroTokens.trilho(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // Ícone de visibilidade / toggle
            Icon(
              ativo ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 12,
              color: ativo ? cor : AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 5),
            // Ponto indicador com a cor do tipo
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: ativo ? cor : cor.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ativo ? Colors.transparent : AppColors.textTertiary.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Rótulo do tipo
            Expanded(
              child: Text(
                rotulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: ativo ? FontWeight.w500 : FontWeight.normal,
                  color: ativo
                      ? AppColors.textPrimaryOf(context)
                      : AppColors.textTertiary.withValues(alpha: 0.6),
                  decoration: ativo ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            // Contagem de nós
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: ativo
                    ? CerebroTokens.trilho(context)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$valor',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: ativo ? AppColors.textSecondaryOf(context) : AppColors.textTertiary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de busca flutuante no topo do grafo (Busca Normal + Agente IA).
class _BarraBuscaGrafoOverlay extends ConsumerStatefulWidget {
  const _BarraBuscaGrafoOverlay({
    required this.aoFocarNo,
    this.aoAbrirNoEditor,
    this.aoVerLeituraRapida,
  });

  final void Function(String notaId) aoFocarNo;
  final void Function(String notaId)? aoAbrirNoEditor;
  final void Function(String notaId)? aoVerLeituraRapida;

  @override
  ConsumerState<_BarraBuscaGrafoOverlay> createState() =>
      _BarraBuscaGrafoOverlayState();
}

class _BarraBuscaGrafoOverlayState
    extends ConsumerState<_BarraBuscaGrafoOverlay> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  bool _expandido = true;
  bool _temFoco = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _temFoco = _focusNode.hasFocus);
    });
    _ctrl = TextEditingController(text: ref.read(grafoBuscaProvider).query);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _alternarFiltro(String termo) {
    final textoAtual = _ctrl.text.trim();
    String novoTexto;
    if (textoAtual.toLowerCase().contains(termo.toLowerCase())) {
      novoTexto = textoAtual
          .replaceAll(RegExp(RegExp.escape(termo), caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    } else {
      novoTexto = textoAtual.isEmpty ? termo : '$textoAtual $termo';
    }
    _ctrl.value = TextEditingValue(
      text: novoTexto,
      selection: TextSelection.collapsed(offset: novoTexto.length),
    );
    ref.read(grafoBuscaProvider.notifier).buscar(novoTexto);
  }

  void _aplicarIdeiaPrompt(String prompt) {
    _ctrl.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    ref.read(grafoBuscaProvider.notifier).buscar(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final busca = ref.watch(grafoBuscaProvider);
    final buscaNotifier = ref.read(grafoBuscaProvider.notifier);
    final ehAgente = busca.modo == ModoBuscaGrafo.agente;
    final index = ref.watch(vaultProvider.notifier).index;

    if (_ctrl.text != busca.query) {
      _ctrl.value = TextEditingValue(
        text: busca.query,
        selection: TextSelection.collapsed(offset: busca.query.length),
      );
    }

    if (!_expandido) {
      return Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surfaceOf(context),
        child: InkWell(
          onTap: () => setState(() => _expandido = true),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ehAgente ? Icons.auto_awesome : Icons.search,
                  size: 14,
                  color:
                      ehAgente ? const Color(0xFF8B5CF6) : AppColors.pinkAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  ehAgente ? 'Busca IA' : 'Buscar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                if (busca.idsEncontrados.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: (ehAgente
                              ? const Color(0xFF8B5CF6)
                              : AppColors.pinkAccent)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${busca.idsEncontrados.length}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: ehAgente
                            ? const Color(0xFF8B5CF6)
                            : AppColors.pinkAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final corAtiva = ehAgente ? const Color(0xFF8B5CF6) : AppColors.pinkAccent;

    // Resultados correspondentes no modo Normal
    final notasEncontradas = (!ehAgente && busca.query.trim().isNotEmpty)
        ? busca.idsEncontrados
            .map((id) => index.porId(id))
            .whereType<Nota>()
            .take(5)
            .toList()
        : const <Nota>[];

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (_ctrl.text.isNotEmpty) {
            _ctrl.clear();
            buscaNotifier.limpar();
            return KeyEventResult.handled;
          } else if (_temFoco) {
            _focusNode.unfocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            color: AppColors.surfaceOf(context).withValues(alpha: 0.94),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 390,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: _temFoco
                      ? corAtiva.withValues(alpha: 0.8)
                      : (ehAgente
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                          : AppColors.borderOf(context)),
                  width: _temFoco ? 1.4 : 1.0,
                ),
                boxShadow: CerebroTokens.flutuante(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha de cabeçalho: Modos + Badge + Ações
                  Row(
                    children: [
                      // Toggle Modo Normal
                      _SegmentoModo(
                        rotulo: 'Normal',
                        icone: Icons.search,
                        ativo: !ehAgente,
                        cor: AppColors.pinkAccent,
                        aoClicar: () =>
                            buscaNotifier.alternarModo(ModoBuscaGrafo.normal),
                      ),
                      const SizedBox(width: 4),
                      // Toggle Modo Agente IA
                      _SegmentoModo(
                        rotulo: 'Agente IA',
                        icone: Icons.auto_awesome,
                        ativo: ehAgente,
                        cor: const Color(0xFF8B5CF6),
                        aoClicar: () =>
                            buscaNotifier.alternarModo(ModoBuscaGrafo.agente),
                      ),
                      const Spacer(),
                      if (busca.idsEncontrados.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: corAtiva.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${busca.idsEncontrados.length} ${busca.idsEncontrados.length == 1 ? 'nota' : 'notas'}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: corAtiva,
                            ),
                          ),
                        ),
                      Tooltip(
                        message: 'Guia & Tutorial do Cérebro (F1)',
                        child: InkWell(
                          onTap: () => mostrarTutorialCerebro(context),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 13, color: AppColors.pinkAccent),
                                const SizedBox(width: 3),
                                Text(
                                  'Tutorial',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.pinkAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Tooltip(
                        message: 'Minimizar barra',
                        child: InkWell(
                          onTap: () => setState(() => _expandido = false),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(Icons.unfold_less,
                                size: 14, color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Campo de Input de Texto
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: CerebroTokens.trilho(context),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: _temFoco
                            ? corAtiva.withValues(alpha: 0.4)
                            : (ehAgente
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                                : Colors.transparent),
                      ),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      autofocus: false,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: ehAgente
                            ? 'Ex: "Quais protocolos reduzem no-show?"...'
                            : 'Buscar por título, tag (#moc), tipo...',
                        hintStyle: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                        prefixIcon: Icon(
                          ehAgente ? Icons.psychology : Icons.search,
                          size: 15,
                          color: ehAgente
                              ? const Color(0xFF8B5CF6)
                              : AppColors.textSecondaryOf(context),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (busca.carregando)
                              const Padding(
                                padding: EdgeInsets.all(7),
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                              )
                            else if (busca.query.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 13),
                                padding: EdgeInsets.zero,
                                splashRadius: 12,
                                constraints: const BoxConstraints(
                                    minWidth: 24, minHeight: 24),
                                onPressed: () {
                                  _ctrl.clear();
                                  buscaNotifier.limpar();
                                },
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CerebroTokens.hover(context),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: AppColors.borderOf(context)),
                                  ),
                                  child: Text(
                                    'Ctrl+K',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (v) => buscaNotifier.buscar(v),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Chips Rápidos de Filtro (Modo Normal) ou Ideias de Busca (Modo Agente)
                  if (!ehAgente) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ChipFiltroRapido(
                            rotulo: '#moc',
                            termo: '#moc',
                            icone: Icons.hub_outlined,
                            cor: const Color(0xFFF43F5E),
                            ativo: _ctrl.text.toLowerCase().contains('#moc'),
                            aoAlternar: () => _alternarFiltro('#moc'),
                          ),
                          const SizedBox(width: 4),
                          _ChipFiltroRapido(
                            rotulo: 'Protocolo',
                            termo: 'tipo:protocolo',
                            icone: Icons.rule_folder_outlined,
                            cor: const Color(0xFF2E9E8F),
                            ativo: _ctrl.text
                                .toLowerCase()
                                .contains('tipo:protocolo'),
                            aoAlternar: () => _alternarFiltro('tipo:protocolo'),
                          ),
                          const SizedBox(width: 4),
                          _ChipFiltroRapido(
                            rotulo: 'Decisão',
                            termo: 'tipo:decisao',
                            icone: Icons.gavel_outlined,
                            cor: const Color(0xFFC77700),
                            ativo: _ctrl.text
                                .toLowerCase()
                                .contains('tipo:decisao'),
                            aoAlternar: () => _alternarFiltro('tipo:decisao'),
                          ),
                          const SizedBox(width: 4),
                          _ChipFiltroRapido(
                            rotulo: 'Conceito',
                            termo: 'tipo:conceito',
                            icone: Icons.lightbulb_outline,
                            cor: const Color(0xFF7C3AED),
                            ativo: _ctrl.text
                                .toLowerCase()
                                .contains('tipo:conceito'),
                            aoAlternar: () => _alternarFiltro('tipo:conceito'),
                          ),
                          const SizedBox(width: 4),
                          _ChipFiltroRapido(
                            rotulo: 'Órfãs',
                            termo: 'somenteOrfas',
                            icone: Icons.link_off_outlined,
                            cor: const Color(0xFF94A3B8),
                            ativo: _ctrl.text
                                .toLowerCase()
                                .contains('somenteorfas'),
                            aoAlternar: () => _alternarFiltro('somenteOrfas'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ChipIdeiaPrompt(
                            rotulo: '🌟 Hubs & MOCs',
                            aoClicar: () => _aplicarIdeiaPrompt(
                                'Quais são os principais centros de conhecimento e MOCs do vault?'),
                          ),
                          const SizedBox(width: 4),
                          _ChipIdeiaPrompt(
                            rotulo: '📋 Protocolos',
                            aoClicar: () => _aplicarIdeiaPrompt(
                                'Listar todos os protocolos operacionais e clínicos'),
                          ),
                          const SizedBox(width: 4),
                          _ChipIdeiaPrompt(
                            rotulo: '📉 Absenteísmo / No-Show',
                            aoClicar: () => _aplicarIdeiaPrompt(
                                'Como mitigar no-show e faltas em consultas?'),
                          ),
                          const SizedBox(width: 4),
                          _ChipIdeiaPrompt(
                            rotulo: '⚖️ Decisões',
                            aoClicar: () => _aplicarIdeiaPrompt(
                                'Quais foram as principais decisões de governança clínica?'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Lista de Resultados Imediatos (Modo Normal)
                  if (!ehAgente && busca.query.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    if (notasEncontradas.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'RESULTADOS (${busca.idsEncontrados.length})',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'clique para focar',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      for (final nota in notasEncontradas)
                        _ItemResultadoBuscaRapida(
                          nota: nota,
                          aoFocar: () => widget.aoFocarNo(nota.id),
                          aoVerLeitura: widget.aoVerLeituraRapida != null
                              ? () => widget.aoVerLeituraRapida!(nota.id)
                              : null,
                          aoAbrir: widget.aoAbrirNoEditor != null
                              ? () => widget.aoAbrirNoEditor!(nota.id)
                              : null,
                        ),
                      if (busca.idsEncontrados.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 3, bottom: 1),
                          child: Center(
                            child: Text(
                              '+ ${busca.idsEncontrados.length - 5} outras notas destacadas no grafo',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pinkAccent,
                              ),
                            ),
                          ),
                        ),
                    ] else if (!busca.carregando) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              'Nenhuma nota correspondente no grafo.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de resultado rápido renderizado dentro do dropdown da barra de busca.
class _ItemResultadoBuscaRapida extends StatefulWidget {
  const _ItemResultadoBuscaRapida({
    required this.nota,
    required this.aoFocar,
    this.aoVerLeitura,
    this.aoAbrir,
  });

  final Nota nota;
  final VoidCallback aoFocar;
  final VoidCallback? aoVerLeitura;
  final VoidCallback? aoAbrir;

  @override
  State<_ItemResultadoBuscaRapida> createState() =>
      _ItemResultadoBuscaRapidaState();
}

class _ItemResultadoBuscaRapidaState extends State<_ItemResultadoBuscaRapida> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tipo = widget.nota.tipo;
    final tagsStr = widget.nota.tags.take(3).map((t) => '#$t').join(' ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.aoFocar,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: _hover ? CerebroTokens.hover(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: tipo.cor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(tipo.icon, size: 10.5, color: tipo.cor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.nota.titulo.isEmpty ? 'Sem título' : widget.nota.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    if (tagsStr.isNotEmpty)
                      Text(
                        tagsStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (_hover) ...[
                if (widget.aoVerLeitura != null)
                  Tooltip(
                    message: 'Leitura rápida',
                    child: InkWell(
                      onTap: widget.aoVerLeitura,
                      borderRadius: BorderRadius.circular(3),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.visibility_outlined, size: 12),
                      ),
                    ),
                  ),
                if (widget.aoAbrir != null)
                  Tooltip(
                    message: 'Abrir no editor',
                    child: InkWell(
                      onTap: widget.aoAbrir,
                      borderRadius: BorderRadius.circular(3),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.open_in_new, size: 12),
                      ),
                    ),
                  ),
              ] else
                Icon(Icons.gps_fixed, size: 11, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de filtro rápido (1-toque) no modo normal.
class _ChipFiltroRapido extends StatelessWidget {
  const _ChipFiltroRapido({
    required this.rotulo,
    required this.termo,
    required this.icone,
    required this.cor,
    required this.ativo,
    required this.aoAlternar,
  });

  final String rotulo;
  final String termo;
  final IconData icone;
  final Color cor;
  final bool ativo;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoAlternar,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.2) : CerebroTokens.trilho(context),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: ativo ? cor.withValues(alpha: 0.6) : AppColors.borderOf(context),
            width: ativo ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 10, color: ativo ? cor : AppColors.textTertiary),
            const SizedBox(width: 3.5),
            Text(
              rotulo,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                color: ativo ? cor : AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de ideia de consulta pronta no modo Agente IA.
class _ChipIdeiaPrompt extends StatelessWidget {
  const _ChipIdeiaPrompt({
    required this.rotulo,
    required this.aoClicar,
  });

  final String rotulo;
  final VoidCallback aoClicar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoClicar,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Text(
          rotulo,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B5CF6),
          ),
        ),
      ),
    );
  }
}

class _SegmentoModo extends StatelessWidget {
  const _SegmentoModo({
    required this.rotulo,
    required this.icone,
    required this.ativo,
    required this.cor,
    required this.aoClicar,
  });

  final String rotulo;
  final IconData icone;
  final bool ativo;
  final Color cor;
  final VoidCallback aoClicar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoClicar,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ativo ? cor.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 12, color: ativo ? cor : AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              rotulo,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: ativo ? FontWeight.w700 : FontWeight.normal,
                color: ativo ? cor : AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardRaciocinioIA extends StatelessWidget {
  const _CardRaciocinioIA({
    required this.busca,
    required this.aoFocarNo,
    required this.aoAbrirNoEditor,
    required this.aoVerLeituraRapida,
    required this.aoFechar,
  });

  final GrafoBuscaEstado busca;
  final void Function(String notaId) aoFocarNo;
  final void Function(String notaId) aoAbrirNoEditor;
  final void Function(String notaId) aoVerLeituraRapida;
  final VoidCallback aoFechar;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      color: AppColors.surfaceOf(context).withValues(alpha: 0.96),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 320),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          ),
          boxShadow: CerebroTokens.flutuante(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology,
                    size: 15, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                const Text(
                  'Raciocínio do Agente IA',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: aoFechar,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (busca.carregando) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analisando rede de conhecimento...',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryOf(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else if (busca.erro != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  busca.erro!,
                  style: TextStyle(fontSize: 11, color: AppColors.danger),
                ),
              ),
            ] else ...[
              if (busca.raciocinio.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    busca.raciocinio,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              if (busca.titulosEncontrados.isNotEmpty) ...[
                Text(
                  'NOTAS DESTACADAS NO GRAFO (clique para focar • 👁 ver • ↗ abrir)',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final id in busca.idsEncontrados)
                          _ChipNotaEncontrada(
                            notaId: id,
                            aoFocarNo: () => aoFocarNo(id),
                            aoAbrirNoEditor: () => aoAbrirNoEditor(id),
                            aoVerLeituraRapida: () => aoVerLeituraRapida(id),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipNotaEncontrada extends ConsumerWidget {
  const _ChipNotaEncontrada({
    required this.notaId,
    required this.aoFocarNo,
    required this.aoAbrirNoEditor,
    required this.aoVerLeituraRapida,
  });

  final String notaId;
  final VoidCallback aoFocarNo;
  final VoidCallback aoAbrirNoEditor;
  final VoidCallback aoVerLeituraRapida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nota = ref.watch(notaProvider(notaId));
    final titulo = nota?.titulo ?? notaId;

    return InkWell(
      onTap: aoFocarNo,
      onDoubleTap: aoAbrirNoEditor,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 2, 4, 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 6, color: Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                titulo,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Ver conteúdo da nota',
              child: InkWell(
                onTap: aoVerLeituraRapida,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 12,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Abrir no editor',
              child: InkWell(
                onTap: aoAbrirNoEditor,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.open_in_new,
                    size: 11,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card flutuante de preview rápido exibido quando um nó é selecionado no Grafo.
class _CardPreviewNotaFlutuante extends ConsumerWidget {
  const _CardPreviewNotaFlutuante({
    required this.notaId,
    required this.aoAbrirNoEditor,
    required this.aoVerLeituraRapida,
    required this.aoFechar,
    this.aoRastrearCausaEEfeito,
  });

  final String notaId;
  final VoidCallback aoAbrirNoEditor;
  final VoidCallback aoVerLeituraRapida;
  final VoidCallback aoFechar;
  final VoidCallback? aoRastrearCausaEEfeito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nota = ref.watch(notaProvider(notaId));
    if (nota == null) return const SizedBox.shrink();

    final previewTexto = nota.conteudo.trim().isNotEmpty
        ? nota.conteudo.trim().split('\n').take(4).join('\n')
        : 'Nota sem conteúdo textual.';

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      color: AppColors.surfaceOf(context).withValues(alpha: 0.98),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: CerebroTokens.flutuante(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  nota.tipo == NotaTipo.protocolo
                      ? Icons.assignment_outlined
                      : (nota.tipo == NotaTipo.moc
                          ? Icons.hub_outlined
                          : Icons.description_outlined),
                  size: 15,
                  color: AppColors.pinkAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nota.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                InkWell(
                  onTap: aoFechar,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14),
                  ),
                ),
              ],
            ),
            if (nota.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 3,
                runSpacing: 2,
                children: [
                  for (final t in nota.tags.take(4))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 65),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CerebroTokens.trilho(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                previewTexto,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.3,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (aoRastrearCausaEEfeito != null)
                  OutlinedButton.icon(
                    onPressed: aoRastrearCausaEEfeito,
                    icon: const Icon(Icons.account_tree_outlined,
                        size: 12, color: Color(0xFFF43F5E)),
                    label: const Text('Causa & Efeito',
                        style:
                            TextStyle(fontSize: 10.5, color: Color(0xFFF43F5E))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      side: const BorderSide(color: Color(0xFFF43F5E)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: aoVerLeituraRapida,
                  icon: const Icon(Icons.visibility_outlined, size: 12),
                  label: const Text('Ver Conteúdo',
                      style: TextStyle(fontSize: 10.5)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: aoAbrirNoEditor,
                  icon: const Icon(Icons.edit_outlined, size: 12),
                  label: const Text('Editar', style: TextStyle(fontSize: 10.5)),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal de leitura rápida com renderização VFM / Markdown completa.
class _ModalLeituraRapidaNota extends ConsumerWidget {
  const _ModalLeituraRapidaNota({
    required this.notaId,
    required this.aoAbrirNoEditor,
  });

  final String notaId;
  final VoidCallback aoAbrirNoEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nota = ref.watch(notaProvider(notaId));
    final index = ref.watch(vaultProvider.notifier).index;

    if (nota == null) {
      return AlertDialog(
        title: const Text('Nota não encontrada'),
        content: Text('ID: $notaId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho da Nota
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.pinkAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    nota.tipo == NotaTipo.protocolo
                        ? Icons.assignment_outlined
                        : (nota.tipo == NotaTipo.moc
                            ? Icons.hub_outlined
                            : Icons.description_outlined),
                    size: 20,
                    color: AppColors.pinkAccent,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nota.titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      if (nota.tags.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final t in nota.tags)
                              Text(
                                '#$t',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: aoAbrirNoEditor,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Abrir no Editor',
                      style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Fechar',
                ),
              ],
            ),
            const Divider(height: 24),

            // Conteúdo formatado em Markdown com Sugestão Preventiva IA
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sugestão de Medida / Rotina Preventiva Agendada
                    CardRotinaPreventiva(nota: nota),

                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: CerebroTokens.trilho(context),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: AppColors.borderOf(context)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: nota.conteudo.trim().isNotEmpty
                          ? VfmView(
                              conteudo: nota.conteudo,
                              index: index,
                              aoTocar: (alvo) {
                                if (alvo.tipo == TipoAlvo.nota &&
                                    alvo.notaId != null) {
                                  Navigator.pop(context);
                                  ref
                                      .read(abasProvider.notifier)
                                      .abrir(alvo.notaId!);
                                  ref
                                      .read(layoutProvider.notifier)
                                      .irPara(VistaCentral.editor);
                                }
                              },
                            )
                          : Text(
                              'Nota sem conteúdo textual.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Rodapé
            Row(
              children: [
                Text(
                  '${nota.wordCount} palavras · ${nota.outLinks.length} links de saída · ${nota.metrics.inDegree} referências',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-Mapa de Navegação 2D (Radar / Minimap do Grafo).
class _MiniMapaGrafo extends StatelessWidget {
  const _MiniMapaGrafo({
    required this.engine,
    required this.offset,
    required this.escala,
    required this.nosCriticos,
    required this.aoMoverCamera,
  });

  final GrafoEngine engine;
  final Offset offset;
  final double escala;
  final Set<String> nosCriticos;
  final void Function(Offset novoOffset) aoMoverCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 95,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: CerebroTokens.flutuante(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final novoDx = offset.dx - d.delta.dx * 12.0;
            final novoDy = offset.dy - d.delta.dy * 12.0;
            aoMoverCamera(Offset(novoDx, novoDy));
          },
          child: CustomPaint(
            painter: _MiniMapaPainter(
              engine: engine,
              offset: offset,
              escala: escala,
              nosCriticos: nosCriticos,
            ),
            size: const Size(140, 95),
          ),
        ),
      ),
    );
  }
}

class _MiniMapaPainter extends CustomPainter {
  _MiniMapaPainter({
    required this.engine,
    required this.offset,
    required this.escala,
    required this.nosCriticos,
  });

  final GrafoEngine engine;
  final Offset offset;
  final double escala;
  final Set<String> nosCriticos;

  @override
  void paint(Canvas canvas, Size size) {
    final grafo = engine.grafo;
    if (grafo.vazio) return;

    final px = engine.px;
    final py = engine.py;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const miniEscala = 0.045;

    final paintNormal = Paint()..color = const Color(0x6694A3B8);
    final paintCritico = Paint()..color = const Color(0xFFEF4444);

    for (var i = 0; i < grafo.n; i += (grafo.n > 800 ? 3 : 1)) {
      final x = cx + px[i] * miniEscala;
      final y = cy + py[i] * miniEscala;
      if (x < 0 || x > size.width || y < 0 || y > size.height) continue;
      final ehCritico = nosCriticos.contains(grafo.nos[i].id);
      canvas.drawCircle(
          Offset(x, y), ehCritico ? 1.8 : 0.9, ehCritico ? paintCritico : paintNormal);
    }

    // Retângulo da Câmera (Viewport)
    final vpW = (size.width / escala) * miniEscala * 1.5;
    final vpH = (size.height / escala) * miniEscala * 1.5;
    final vpX = cx - (offset.dx / escala) * miniEscala - vpW / 2;
    final vpY = cy - (offset.dy / escala) * miniEscala - vpH / 2;

    final paintVp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF8B5CF6);

    canvas.drawRect(
      Rect.fromLTWH(
        vpX.clamp(2.0, size.width - 20),
        vpY.clamp(2.0, size.height - 20),
        vpW.clamp(15.0, size.width - 4),
        vpH.clamp(15.0, size.height - 4),
      ),
      paintVp,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapaPainter old) => true;
}

/// Modal de visualização e exportação do Dossiê Executivo da Rede de Conhecimento.
class _ModalDossieExecutivo extends StatelessWidget {
  const _ModalDossieExecutivo({required this.index});

  final VaultIndex index;

  @override
  Widget build(BuildContext context) {
    final relatorio =
        const RotinaPreventivaService().gerarDossieExecutivo(index);

    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 20, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                Text(
                  'Dossiê Executivo da Rede de Conhecimento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: CerebroTokens.trilho(context),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: VfmView(
                    conteudo: relatorio,
                    index: index,
                    aoTocar: (_) {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: relatorio));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Dossiê copiado para a área de transferência!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copiar Dossiê'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Concluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
