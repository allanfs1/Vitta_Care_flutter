import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Primitivas visuais compartilhadas pelo Cérebro (`obsidian.md` §10).
///
/// Centralizam densidade, hover, raio e hierarquia tipográfica que antes
/// estavam repetidas painel a painel. Com elas o módulo inteiro passa a ter o
/// mesmo peso visual e o mesmo feedback de interação.
class CerebroTokens {
  CerebroTokens._();

  /// Altura das barras de cromo (topo, abas, contexto).
  static const double barra = 42;
  static const double barraStatus = 28;
  static const double rail = 52;
  static const double raio = 8;

  static bool escuro(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// Realce de hover — sutil o bastante para não competir com a seleção.
  static Color hover(BuildContext c) => escuro(c)
      ? Colors.white.withValues(alpha: 0.055)
      : const Color(0xFF1A1D29).withValues(alpha: 0.045);

  /// Realce de item selecionado (mesma família do accent do módulo).
  static Color selecao(BuildContext c) =>
      AppColors.pinkAccent.withValues(alpha: escuro(c) ? 0.20 : 0.11);

  /// Fundo de "trilho" — segmentos, campos embutidos, chips neutros.
  static Color trilho(BuildContext c) => escuro(c)
      ? Colors.white.withValues(alpha: 0.055)
      : const Color(0xFF1A1D29).withValues(alpha: 0.045);

  static List<BoxShadow> flutuante(BuildContext c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: escuro(c) ? 0.45 : 0.14),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Rótulo de seção — o `EXPLORADOR`, `SUMÁRIO`, `TAGS` de todos os painéis.
class RotuloSecao extends StatelessWidget {
  const RotuloSecao({
    super.key,
    required this.texto,
    this.contador,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.xs),
  });

  final String texto;
  final int? contador;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          if (contador != null) ...[
            const SizedBox(width: 6),
            PilulaContagem(valor: contador!),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Contador discreto usado ao lado dos rótulos de seção.
class PilulaContagem extends StatelessWidget {
  const PilulaContagem({super.key, required this.valor, this.cor});

  final int valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? AppColors.textSecondaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: cor == null ? 0.0 : 0.14),
        border: Border.all(color: c.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        valor > 999 ? '999+' : '$valor',
        style: TextStyle(
          fontSize: 9,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}

/// Botão de ícone compacto com hover explícito e tooltip com atalho.
///
/// Substitui os `InkWell(child: Icon(...))` soltos: alvo de toque de 28 px,
/// hover visível e estado ativo consistente em todo o módulo.
class BotaoIcone extends StatefulWidget {
  const BotaoIcone({
    super.key,
    required this.icone,
    required this.tooltip,
    required this.onTap,
    this.atalho,
    this.ativo = false,
    this.tamanho = 16,
    this.corAtiva,
    this.badge = 0,
  });

  final IconData icone;
  final String tooltip;
  final String? atalho;
  final bool ativo;
  final double tamanho;
  final Color? corAtiva;
  final int badge;
  final VoidCallback onTap;

  @override
  State<BotaoIcone> createState() => _BotaoIconeState();
}

class _BotaoIconeState extends State<BotaoIcone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final corAtiva = widget.corAtiva ?? AppColors.pinkAccent;
    final cor = widget.ativo ? corAtiva : AppColors.textSecondaryOf(context);

    return Tooltip(
      message: widget.atalho == null
          ? widget.tooltip
          : '${widget.tooltip}  ·  ${widget.atalho}',
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.ativo
                  ? CerebroTokens.selecao(context)
                  : (_hover ? CerebroTokens.hover(context) : Colors.transparent),
              borderRadius: BorderRadius.circular(CerebroTokens.raio),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(widget.icone, size: widget.tamanho, color: cor),
                if (widget.badge > 0)
                  Positioned(
                    top: -1,
                    right: -3,
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

/// Bolha de contagem sobreposta a um ícone (pendências no rail).
class BadgeContagem extends StatelessWidget {
  const BadgeContagem({super.key, required this.valor, this.cor});

  final int valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      constraints: const BoxConstraints(minWidth: 14),
      decoration: BoxDecoration(
        color: cor ?? AppColors.warning,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.surfaceAltOf(context), width: 1.4),
      ),
      child: Text(
        valor > 99 ? '99+' : '$valor',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 8,
          height: 1.25,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Pílula de rótulo (tipo, filtro, estado) com cor semântica.
class PilulaTexto extends StatelessWidget {
  const PilulaTexto({
    super.key,
    required this.texto,
    this.icone,
    this.cor,
    this.onTap,
    this.onRemover,
  });

  final String texto;
  final IconData? icone;
  final Color? cor;
  final VoidCallback? onTap;
  final VoidCallback? onRemover;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? AppColors.textSecondaryOf(context);
    final conteudo = Container(
      padding: EdgeInsets.fromLTRB(
          icone == null ? 8 : 6, 3, onRemover == null ? 8 : 4, 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 11, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
          if (onRemover != null) ...[
            const SizedBox(width: 2),
            InkWell(
              onTap: onRemover,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: Icon(Icons.close, size: 12, color: c),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return conteudo;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: conteudo,
    );
  }
}

/// Atalho de teclado desenhado como teclas — usado na paleta rápida e na
/// folha de atalhos.
class Teclas extends StatelessWidget {
  const Teclas({super.key, required this.atalho});

  final String atalho;

  @override
  Widget build(BuildContext context) {
    final teclas = atalho.split('+').map((t) => t.trim()).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < teclas.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text('+',
                  style:
                      TextStyle(fontSize: 9, color: AppColors.textTertiary)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: CerebroTokens.trilho(context),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Text(
              teclas[i],
              style: TextStyle(
                fontSize: 9.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Esqueleto de carregamento em linhas — substitui o spinner genérico dos
/// painéis laterais (§10.5.5: todo vazio explica o que está acontecendo).
class EsqueletoLista extends StatefulWidget {
  const EsqueletoLista(
      {super.key, this.linhas = 9, this.comSecoes = true, this.progresso});

  final int linhas;
  final bool comSecoes;

  /// Fracao ja indexada (0..1). Um vault grande leva mais de um frame; sem
  /// este sinal o esqueleto pulsa indefinidamente e a tela parece travada.
  final double? progresso;

  @override
  State<EsqueletoLista> createState() => _EsqueletoListaState();
}

class _EsqueletoListaState extends State<EsqueletoLista>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.textSecondaryOf(context);
    final progresso = widget.progresso;
    return Column(
      children: [
        if (progresso != null) _BarraProgresso(valor: progresso),
        Expanded(child: _esqueleto(context, base)),
      ],
    );
  }

  Widget _esqueleto(BuildContext context, Color base) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: widget.linhas,
        itemBuilder: (context, i) {
          final secao = widget.comSecoes && i % 4 == 0;
          final alpha = 0.06 + 0.06 * ((_ctrl.value + i / widget.linhas) % 1.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.md, secao ? AppSpacing.md : 5, AppSpacing.md, 0),
            child: Row(
              children: [
                if (!secao) ...[
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: base.withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  flex: secao ? 4 : (6 + i % 4),
                  child: Container(
                    height: secao ? 7 : 10,
                    decoration: BoxDecoration(
                      color:
                          base.withValues(alpha: secao ? alpha * 0.8 : alpha),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Spacer(flex: 3 + (i % 3)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Barra de progresso da indexacao, com a contagem em texto.
class _BarraProgresso extends StatelessWidget {
  const _BarraProgresso({required this.valor});

  final double valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Indexando o vault… ${(valor * 100).round()}%',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: valor.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: CerebroTokens.trilho(context),
              valueColor: AlwaysStoppedAnimation(AppColors.pinkAccent),
            ),
          ),
        ],
      ),
    );
  }
}
