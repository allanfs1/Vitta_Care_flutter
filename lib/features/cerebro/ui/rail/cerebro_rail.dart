import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../navigation/app_router.dart';
import '../../providers/cerebro_providers.dart';
import '../comum/acoes_cerebro.dart';
import '../comum/cerebro_ui.dart';

/// Rail do Cérebro (`obsidian.md` §10.2).
///
/// Ordem e atalhos são normativos — a especificação define a memória muscular
/// do usuário. O que mudou foi só a leitura: indicador ativo em pílula,
/// hover explícito e agrupamento visual entre painéis, vistas e atalhos.
class CerebroRail extends ConsumerWidget {
  const CerebroRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);
    final stats = ref.watch(estatisticasProvider);
    final notifier = ref.read(layoutProvider.notifier);

    bool painelAtivo(PainelEsquerdo p) =>
        layout.esquerdoVisivel && layout.painelEsquerdo == p;

    return Container(
      width: CerebroTokens.rail,
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        border: Border(right: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _Botao(
            icone: Icons.folder_outlined,
            iconeAtivo: Icons.folder,
            rotulo: 'Explorador',
            atalho: 'Ctrl+Shift+E',
            ativo: painelAtivo(PainelEsquerdo.explorer),
            onTap: () => notifier.abrirPainel(PainelEsquerdo.explorer),
          ),
          _Botao(
            icone: Icons.search,
            rotulo: 'Busca',
            atalho: 'Ctrl+Shift+F',
            ativo: painelAtivo(PainelEsquerdo.busca),
            onTap: () => notifier.abrirPainel(PainelEsquerdo.busca),
          ),
          _Botao(
            icone: Icons.tag_outlined,
            iconeAtivo: Icons.tag,
            rotulo: 'Tags',
            atalho: 'Ctrl+Shift+T',
            ativo: painelAtivo(PainelEsquerdo.tags),
            onTap: () => notifier.abrirPainel(PainelEsquerdo.tags),
          ),
          _Botao(
            icone: Icons.bolt_outlined,
            iconeAtivo: Icons.bolt,
            rotulo: 'Sugestões',
            atalho: 'Ctrl+Shift+S',
            badge: stats.orfas + stats.quebrados,
            ativo: painelAtivo(PainelEsquerdo.sugestoes),
            onTap: () => notifier.abrirPainel(PainelEsquerdo.sugestoes),
          ),
          _Botao(
            icone: Icons.history,
            rotulo: 'Recentes',
            ativo: painelAtivo(PainelEsquerdo.recentes),
            onTap: () => notifier.abrirPainel(PainelEsquerdo.recentes),
          ),
          const _Separador(),
          _Botao(
            icone: Icons.hub_outlined,
            iconeAtivo: Icons.hub,
            rotulo: 'Grafo global',
            atalho: 'Ctrl+G',
            ativo: layout.vista == VistaCentral.grafo,
            onTap: () => notifier.irPara(
              layout.vista == VistaCentral.grafo
                  ? VistaCentral.editor
                  : VistaCentral.grafo,
            ),
          ),
          _Botao(
            icone: Icons.analytics_outlined,
            iconeAtivo: Icons.analytics,
            rotulo: 'Modo analítico',
            atalho: 'Ctrl+Shift+A',
            ativo: layout.vista == VistaCentral.analitico,
            onTap: () => notifier.irPara(
              layout.vista == VistaCentral.analitico
                  ? VistaCentral.editor
                  : VistaCentral.analitico,
            ),
          ),
          const _Separador(),
          _Botao(
            icone: Icons.note_add_outlined,
            rotulo: 'Nova nota',
            atalho: 'Ctrl+N',
            onTap: () => AcoesCerebro.novaNota(context, ref),
          ),
          _Botao(
            icone: Icons.today_outlined,
            rotulo: 'Nota de hoje',
            atalho: 'Ctrl+D',
            onTap: () => AcoesCerebro.abrirDiario(ref),
          ),
          const Spacer(),
          _Botao(
            icone: Icons.psychology_outlined,
            rotulo: 'Voltar ao chat da IA',
            onTap: () => context.go(AppRoutes.ia),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: AppColors.borderOf(context),
      );
}

class _Botao extends StatefulWidget {
  const _Botao({
    required this.icone,
    required this.rotulo,
    required this.onTap,
    this.iconeAtivo,
    this.atalho,
    this.ativo = false,
    this.badge = 0,
  });

  final IconData icone;
  final IconData? iconeAtivo;
  final String rotulo;
  final String? atalho;
  final bool ativo;
  final int badge;
  final VoidCallback onTap;

  @override
  State<_Botao> createState() => _BotaoState();
}

class _BotaoState extends State<_Botao> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = widget.ativo
        ? AppColors.pinkAccent
        : (_hover
            ? AppColors.textPrimaryOf(context)
            : AppColors.textSecondaryOf(context));

    return Tooltip(
      message: widget.atalho == null
          ? widget.rotulo
          : '${widget.rotulo}  ·  ${widget.atalho}',
      waitDuration: const Duration(milliseconds: 450),
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 42,
            width: CerebroTokens.rail,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Indicador de painel ativo — barra arredondada à esquerda.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  left: 0,
                  top: widget.ativo ? 9 : 21,
                  bottom: widget.ativo ? 9 : 21,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: widget.ativo
                          ? AppColors.pinkAccent
                          : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(3)),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 34,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.ativo
                        ? CerebroTokens.selecao(context)
                        : (_hover
                            ? CerebroTokens.hover(context)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                Icon(
                  widget.ativo ? (widget.iconeAtivo ?? widget.icone) : widget.icone,
                  size: 19,
                  color: cor,
                ),
                if (widget.badge > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: BadgeContagem(valor: widget.badge),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
