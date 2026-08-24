import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/cerebro_providers.dart';
import 'acoes_cerebro.dart';
import 'cerebro_ui.dart';
import 'paleta_rapida.dart';
import 'tutorial_cerebro.dart';

/// Barra superior do Cérebro.
///
/// Antes o módulo não tinha cabeçalho no desktop: a troca de vista só existia
/// no rail e no teclado, e não havia porta de entrada para busca global. Esta
/// barra dá identidade à tela, torna a vista atual explícita e coloca a
/// paleta rápida a um clique.
class CerebroBarraSuperior extends ConsumerWidget {
  const CerebroBarraSuperior({
    super.key,
    required this.largura,
    this.aoAbrirMenu,
    this.aoAbrirDetalhes,
  });

  /// Largura disponível para a tela (não a da janela) — define o quanto de
  /// rótulo cabe antes de degradar para só ícones.
  final double largura;

  /// Fora do desktop os painéis viram gavetas: quando estes callbacks existem,
  /// a barra troca os alternadores de painel por botões de gaveta.
  final VoidCallback? aoAbrirMenu;
  final VoidCallback? aoAbrirDetalhes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);
    final notifier = ref.read(layoutProvider.notifier);
    final stats = ref.watch(estatisticasProvider);

    final emGaveta = aoAbrirMenu != null || aoAbrirDetalhes != null;
    final compacta = largura < 1100;
    final minima = largura < 880;

    return Container(
      height: CerebroTokens.barra,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          if (aoAbrirMenu != null) ...[
            BotaoIcone(
              icone: Icons.menu,
              tooltip: 'Explorador, busca e tags',
              tamanho: 18,
              onTap: aoAbrirMenu!,
            ),
            const SizedBox(width: 2),
          ],
          _Marca(notas: stats.notas, compacta: minima),
          const SizedBox(width: AppSpacing.md),
          _SeletorVista(
            vista: layout.vista,
            comRotulos: !compacta,
            aoTrocar: notifier.irPara,
          ),
          const Spacer(),
          if (!minima) ...[
            _CampoPaleta(largura: largura < 1280 ? 190 : 260),
            const SizedBox(width: AppSpacing.sm),
          ] else
            BotaoIcone(
              icone: Icons.search,
              tooltip: 'Buscar notas e comandos',
              atalho: 'Ctrl+P',
              onTap: () => mostrarPaletaRapida(context, ref),
            ),
          BotaoIcone(
            icone: Icons.note_add_outlined,
            tooltip: 'Nova nota',
            atalho: 'Ctrl+N',
            onTap: () => AcoesCerebro.novaNota(context, ref),
          ),
          _divisor(context),
          if (!emGaveta) ...[
            BotaoIcone(
              icone: Icons.vertical_split_outlined,
              tooltip: layout.esquerdoVisivel
                  ? 'Ocultar painel esquerdo'
                  : 'Mostrar painel esquerdo',
              atalho: 'Ctrl+B',
              ativo: layout.esquerdoVisivel,
              onTap: notifier.alternarEsquerdo,
            ),
            BotaoIcone(
              icone: Icons.polyline_outlined,
              tooltip: layout.grafoLocalVisivel
                  ? 'Ocultar grafo local'
                  : 'Mostrar grafo local sob o editor',
              ativo: layout.grafoLocalVisivel,
              onTap: notifier.alternarGrafoLocal,
            ),
            BotaoIcone(
              icone: Icons.view_sidebar_outlined,
              tooltip: layout.direitoVisivel
                  ? 'Ocultar painel direito'
                  : 'Mostrar painel direito',
              atalho: 'Ctrl+Shift+B',
              ativo: layout.direitoVisivel,
              onTap: notifier.alternarDireito,
            ),
            _divisor(context),
          ] else if (aoAbrirDetalhes != null) ...[
            BotaoIcone(
              icone: Icons.view_sidebar_outlined,
              tooltip: 'Sumário, backlinks e métricas',
              onTap: aoAbrirDetalhes!,
            ),
            _divisor(context),
          ],
          const _MenuMais(),
        ],
      ),
    );
  }

  Widget _divisor(BuildContext context) => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: AppColors.borderOf(context),
      );
}

class _Marca extends StatelessWidget {
  const _Marca({required this.notas, required this.compacta});

  final int notas;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.pinkAccent.withValues(alpha: 0.22),
                AppColors.primary.withValues(alpha: 0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(Icons.psychology_outlined,
              size: 16, color: AppColors.pinkAccent),
        ),
        if (!compacta) ...[
          const SizedBox(width: AppSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cérebro',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Text(
                '$notas ${notas == 1 ? "nota" : "notas"} no vault',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.2,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Segmentado Editor · Grafo · Analítico — torna a vista atual legível de
/// relance, coisa que o rail sozinho não fazia.
class _SeletorVista extends StatelessWidget {
  const _SeletorVista({
    required this.vista,
    required this.comRotulos,
    required this.aoTrocar,
  });

  final VistaCentral vista;
  final bool comRotulos;
  final ValueChanged<VistaCentral> aoTrocar;

  static const _itens = <(VistaCentral, IconData, String, String)>[
    (VistaCentral.editor, Icons.edit_note_outlined, 'Editor', 'Ctrl+1'),
    (VistaCentral.grafo, Icons.hub_outlined, 'Grafo', 'Ctrl+2'),
    (VistaCentral.analitico, Icons.analytics_outlined, 'Analítico', 'Ctrl+3'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: CerebroTokens.trilho(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, icone, rotulo, atalho) in _itens)
            Tooltip(
              message: '$rotulo  ·  $atalho',
              waitDuration: const Duration(milliseconds: 450),
              child: InkWell(
                onTap: () => aoTrocar(v),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: EdgeInsets.symmetric(
                      horizontal: comRotulos ? 10 : 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: v == vista
                        ? AppColors.surfaceOf(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: v == vista
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: CerebroTokens.escuro(context) ? 0.4 : 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icone,
                        size: 14,
                        color: v == vista
                            ? AppColors.pinkAccent
                            : AppColors.textSecondaryOf(context),
                      ),
                      if (comRotulos) ...[
                        const SizedBox(width: 5),
                        Text(
                          rotulo,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                v == vista ? FontWeight.w600 : FontWeight.w500,
                            color: v == vista
                                ? AppColors.textPrimaryOf(context)
                                : AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Campo falso que abre a paleta rápida — a affordance de busca global que
/// o módulo não tinha.
class _CampoPaleta extends ConsumerWidget {
  const _CampoPaleta({required this.largura});

  final double largura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => mostrarPaletaRapida(context, ref),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        width: largura,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: CerebroTokens.trilho(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.search,
                size: 14, color: AppColors.textSecondaryOf(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ir para…',
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
            ),
            const Teclas(atalho: 'Ctrl+P'),
          ],
        ),
      ),
    );
  }
}

class _MenuMais extends ConsumerWidget {
  const _MenuMais();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      position: PopupMenuPosition.under,
      icon: Icon(Icons.more_horiz,
          size: 18, color: AppColors.textSecondaryOf(context)),
      iconSize: 18,
      padding: EdgeInsets.zero,
      onSelected: (v) => _executar(context, ref, v),
      itemBuilder: (context) => [
        _item('tutorial', Icons.school_outlined, 'Guia & Tutorial do Cérebro', 'F1'),
        _item('hoje', Icons.today_outlined, 'Nota de hoje', 'Ctrl+D'),
        _item('leitura', Icons.menu_book_outlined, 'Alternar leitura', 'Ctrl+E'),
        const PopupMenuDivider(),
        _item('demo300', Icons.science_outlined, '300 notas · vault pequeno'),
        _item('demo1200', Icons.science_outlined, '1.200 notas · 1 ano de uso'),
        _item('demo3000', Icons.science_outlined, '3.000 notas · carga pesada'),
        _item('limpardemo', Icons.delete_sweep_outlined,
            'Limpar dados de demonstração'),
        const PopupMenuDivider(),
        _item('layout', Icons.restart_alt, 'Restaurar larguras dos painéis'),
        _item('atalhos', Icons.keyboard_outlined, 'Atalhos do teclado', 'Ctrl+/'),
      ],
    );
  }

  PopupMenuItem<String> _item(
      String valor, IconData icone, String texto, [String? atalho]) {
    return PopupMenuItem<String>(
      value: valor,
      height: 38,
      child: Row(
        children: [
          Icon(icone, size: 15),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 12.5))),
          if (atalho != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Teclas(atalho: atalho),
          ],
        ],
      ),
    );
  }

  void _executar(BuildContext context, WidgetRef ref, String valor) {
    final layout = ref.read(layoutProvider.notifier);
    switch (valor) {
      case 'tutorial':
        mostrarTutorialCerebro(context);
      case 'hoje':
        AcoesCerebro.abrirDiario(ref);
      case 'leitura':
        layout.alternarModoLeitura();
      case 'demo300':
        AcoesCerebro.popularDemo(context, ref, 300);
      case 'demo1200':
        AcoesCerebro.popularDemo(context, ref, 1200);
      case 'demo3000':
        AcoesCerebro.popularDemo(context, ref, 3000);
      case 'limpardemo':
        AcoesCerebro.limparDemo(context, ref);
      case 'layout':
        layout.redimensionarEsquerda(280);
        layout.redimensionarDireita(320);
      case 'atalhos':
        mostrarAtalhos(context);
    }
  }
}

/// Folha de atalhos (§10.14) — descoberta do teclado sem sair da tela.
Future<void> mostrarAtalhos(BuildContext context) {
  const grupos = <String, List<(String, String)>>{
    'Navegação': [
      ('Ctrl+P', 'Paleta rápida — ir para nota ou comando'),
      ('Ctrl+1 / 2 / 3', 'Editor · Grafo · Analítico'),
      ('Ctrl+G', 'Grafo global'),
      ('Ctrl+Shift+A', 'Modo analítico'),
      ('Alt+←', 'Voltar na navegação de notas'),
    ],
    'Painéis': [
      ('Ctrl+B', 'Painel esquerdo'),
      ('Ctrl+Shift+B', 'Painel direito'),
      ('Ctrl+Shift+E', 'Explorador'),
      ('Ctrl+Shift+F', 'Busca'),
      ('Ctrl+Shift+T', 'Tags'),
      ('Ctrl+Shift+S', 'Sugestões'),
    ],
    'Escrita': [
      ('Ctrl+N', 'Nova nota'),
      ('Ctrl+D', 'Nota de hoje'),
      ('Ctrl+E', 'Alternar leitura / edição'),
      ('Ctrl+W', 'Fechar aba atual'),
      ('[[', 'Autocompletar link para nota'),
      ('#', 'Autocompletar tag'),
    ],
  };

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.keyboard_outlined, color: AppColors.pinkAccent),
      title: const Text('Atalhos do Cérebro', style: TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final grupo in grupos.entries) ...[
                RotuloSecao(
                  texto: grupo.key.toUpperCase(),
                  padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, 6),
                ),
                for (final (tecla, descricao) in grupo.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 132, child: Teclas(atalho: tecla)),
                        Expanded(
                          child: Text(
                            descricao,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
