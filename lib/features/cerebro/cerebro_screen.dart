import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'graph/grafo_modelo.dart';
import 'providers/cerebro_providers.dart';
import 'ui/analitico/analitico_view.dart';
import 'ui/comum/acoes_cerebro.dart';
import 'ui/comum/barra_superior.dart';
import 'ui/comum/paleta_rapida.dart';
import 'ui/comum/status_bar.dart';
import 'ui/comum/tutorial_cerebro.dart';
import 'ui/direita/painel_direito.dart';
import 'ui/editor/area_editor.dart';
import 'ui/esquerda/painel_esquerdo.dart';
import 'ui/grafo/painel_grafo.dart';
import 'ui/rail/cerebro_rail.dart';

/// Densidade de layout do Cérebro, derivada da largura **disponível** para a
/// tela — e não da largura da janela.
///
/// A distinção importa: a casca do app já consome até 280 px com a
/// `NavigationRail`, então medir a janela fazia a tela se declarar "desktop"
/// e espremer o editor em uma faixa estreita entre quatro painéis.
enum _Densidade {
  /// Rail + painel esquerdo + centro + painel direito.
  ampla,

  /// Rail + painel esquerdo + centro; detalhes viram gaveta.
  media,

  /// Só o centro; navegação e detalhes viram gavetas.
  compacta;

  static _Densidade de(double largura) => largura >= 1180
      ? _Densidade.ampla
      : (largura >= 880 ? _Densidade.media : _Densidade.compacta);

  bool get temRail => this != _Densidade.compacta;
  bool get temEsquerdoFixo => this != _Densidade.compacta;
  bool get temDireitoFixo => this == _Densidade.ampla;
}

/// Tela do **Cérebro Vitta** — o segundo cérebro da clínica.
///
/// Anatomia de 4 zonas (`obsidian.md` §10.1): rail · painel esquerdo · área
/// central (editor + grafo local) · painel direito, com barra superior de
/// comando e status bar no rodapé.
class CerebroScreen extends ConsumerWidget {
  const CerebroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final densidade = _Densidade.de(constraints.maxWidth);
        final layout = ref.watch(layoutProvider);
        final layoutNotifier = ref.read(layoutProvider.notifier);

        if (layout.grafoTelaCheia) {
          return CallbackShortcuts(
            bindings: _atalhos(context, ref),
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: AppColors.backgroundOf(context),
                body: const SafeArea(
                  child: PainelGrafo(escopo: GrafoEscopo.global()),
                ),
              ),
            ),
          );
        }

        return CallbackShortcuts(
          bindings: _atalhos(context, ref),
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: AppColors.backgroundOf(context),
              drawer: densidade.temEsquerdoFixo
                  ? null
                  : Drawer(
                      width: 332,
                      child: SafeArea(
                        child: Row(
                          children: [
                            const CerebroRail(),
                            const Expanded(
                                child: PainelEsquerdoView(emGaveta: true)),
                          ],
                        ),
                      ),
                    ),
              endDrawer: densidade.temDireitoFixo
                  ? null
                  : const Drawer(
                      width: 340,
                      child: SafeArea(child: PainelDireito(emGaveta: true)),
                    ),
              body: SafeArea(
                child: Column(
                  children: [
                    Builder(
                      builder: (context) => CerebroBarraSuperior(
                        largura: constraints.maxWidth,
                        aoAbrirMenu: densidade.temEsquerdoFixo
                            ? null
                            : () => Scaffold.of(context).openDrawer(),
                        aoAbrirDetalhes: densidade.temDireitoFixo
                            ? null
                            : () => Scaffold.of(context).openEndDrawer(),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          if (densidade.temRail) const CerebroRail(),
                          if (densidade.temEsquerdoFixo &&
                              layout.esquerdoVisivel) ...[
                            const PainelEsquerdoView(),
                            _Divisoria(
                              aoArrastar: (dx) =>
                                  layoutNotifier.redimensionarEsquerda(
                                      layout.larguraEsquerda + dx),
                              aoResetar: () =>
                                  layoutNotifier.redimensionarEsquerda(280),
                            ),
                          ],
                          Expanded(
                            child: _AreaCentral(densidade: densidade),
                          ),
                          if (densidade.temDireitoFixo &&
                              layout.direitoVisivel) ...[
                            _Divisoria(
                              aoArrastar: (dx) =>
                                  layoutNotifier.redimensionarDireita(
                                      layout.larguraDireita - dx),
                              aoResetar: () =>
                                  layoutNotifier.redimensionarDireita(320),
                            ),
                            const PainelDireito(),
                          ],
                        ],
                      ),
                    ),
                    CerebroStatusBar(compacta: !densidade.temDireitoFixo),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Atalhos de §10.14 — o conjunto completo aparece em "Atalhos do teclado"
  /// no menu da barra superior (Ctrl+/).
  Map<ShortcutActivator, VoidCallback> _atalhos(
      BuildContext context, WidgetRef ref) {
    final layout = ref.read(layoutProvider.notifier);

    void alternarVista(VistaCentral alvo) {
      final atual = ref.read(layoutProvider).vista;
      layout.irPara(atual == alvo ? VistaCentral.editor : alvo);
    }

    return {
      // Painéis
      const SingleActivator(LogicalKeyboardKey.keyB, control: true):
          layout.alternarEsquerdo,
      const SingleActivator(LogicalKeyboardKey.keyB, control: true, shift: true):
          layout.alternarDireito,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
          () => layout.abrirPainel(PainelEsquerdo.busca),
      const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
          () => layout.abrirPainel(PainelEsquerdo.explorer),
      const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true):
          () => layout.abrirPainel(PainelEsquerdo.tags),
      const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
          () => layout.abrirPainel(PainelEsquerdo.sugestoes),

      // Vistas & Tela Cheia
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          layout.irPara(VistaCentral.editor),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
          layout.irPara(VistaCentral.grafo),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
          layout.irPara(VistaCentral.analitico),
      const SingleActivator(LogicalKeyboardKey.keyG, control: true): () =>
          alternarVista(VistaCentral.grafo),
      const SingleActivator(LogicalKeyboardKey.keyA, control: true, shift: true):
          () => alternarVista(VistaCentral.analitico),
      const SingleActivator(LogicalKeyboardKey.f11):
          layout.alternarGrafoTelaCheia,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (ref.read(layoutProvider).grafoTelaCheia) {
          layout.setGrafoTelaCheia(false);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true, alt: true):
          layout.alternarGrafoTelaCheia,

      // Escrita e navegação
      const SingleActivator(LogicalKeyboardKey.keyE, control: true):
          layout.alternarModoLeitura,
      const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
          mostrarPaletaRapida(context, ref),
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
          mostrarPaletaRapida(context, ref),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
          AcoesCerebro.novaNota(context, ref),
      const SingleActivator(LogicalKeyboardKey.keyD, control: true): () =>
          AcoesCerebro.abrirDiario(ref),
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
        final ativa = ref.read(abasProvider).notaAtiva;
        if (ativa != null) ref.read(abasProvider.notifier).fechar(ativa);
      },
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
          ref.read(abasProvider.notifier).voltar(),
      const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
          mostrarAtalhos(context),
      const SingleActivator(LogicalKeyboardKey.f1): () =>
          mostrarTutorialCerebro(context),
      const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
          mostrarTutorialCerebro(context),
    };
  }
}

class _AreaCentral extends ConsumerWidget {
  const _AreaCentral({required this.densidade});

  final _Densidade densidade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);
    final notaAtiva = ref.watch(notaAtivaProvider);

    final Widget conteudo;
    switch (layout.vista) {
      case VistaCentral.grafo:
        conteudo = const PainelGrafo(escopo: GrafoEscopo.global());
      case VistaCentral.analitico:
        conteudo = AnaliticoView(compacto: densidade != _Densidade.ampla);
      case VistaCentral.editor:
        final mostrarLocal = densidade.temRail &&
            layout.grafoLocalVisivel &&
            notaAtiva != null;
        conteudo = Column(
          children: [
            const Expanded(flex: 2, child: AreaEditor()),
            if (mostrarLocal) ...[
              Container(height: 1, color: AppColors.borderOf(context)),
              Expanded(
                child: PainelGrafo(
                  compacto: true,
                  escopo: GrafoEscopo.local(
                    notaAtiva.id,
                    ref.watch(configGrafoProvider).profundidadeLocal,
                  ),
                ),
              ),
            ],
          ],
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (atual, anteriores) => Stack(
        alignment: Alignment.topLeft,
        children: [...anteriores, ?atual],
      ),
      child: KeyedSubtree(key: ValueKey(layout.vista), child: conteudo),
    );
  }
}

/// Divisória arrastável entre painéis (§10.1).
///
/// Alvo de 8 px com feedback: a linha ganha o accent do módulo ao passar o
/// mouse ou durante o arrasto, e o duplo clique restaura a largura padrão.
class _Divisoria extends StatefulWidget {
  const _Divisoria({required this.aoArrastar, required this.aoResetar});

  final void Function(double dx) aoArrastar;
  final VoidCallback aoResetar;

  @override
  State<_Divisoria> createState() => _DivisoriaState();
}

class _DivisoriaState extends State<_Divisoria> {
  bool _hover = false;
  bool _arrastando = false;

  @override
  Widget build(BuildContext context) {
    final ativo = _hover || _arrastando;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: 'Arraste para redimensionar · duplo clique restaura',
        waitDuration: const Duration(milliseconds: 900),
        child: GestureDetector(
          onHorizontalDragStart: (_) => setState(() => _arrastando = true),
          onHorizontalDragUpdate: (d) => widget.aoArrastar(d.delta.dx),
          onHorizontalDragEnd: (_) => setState(() => _arrastando = false),
          onHorizontalDragCancel: () => setState(() => _arrastando = false),
          onDoubleTap: widget.aoResetar,
          child: Container(
            width: 8,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: ativo ? 2 : 1,
              decoration: BoxDecoration(
                color: ativo
                    ? AppColors.pinkAccent
                    : AppColors.borderOf(context),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
