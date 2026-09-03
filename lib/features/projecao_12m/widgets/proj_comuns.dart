import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/num_ptbr.dart';

/// Componentes visuais do módulo de projeção.

class ProjCartao extends StatelessWidget {
  const ProjCartao({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardInsets,
    this.cor,
    this.borda,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? cor;
  final Color? borda;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cor ?? (dark ? AppColors.surfaceDark : AppColors.surface),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
            color: borda ?? (dark ? AppColors.borderDark : AppColors.border)),
      ),
      child: child,
    );
  }
}

class ProjTitulo extends StatelessWidget {
  const ProjTitulo({super.key, required this.titulo, required this.sub});
  final String titulo;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.25,
              letterSpacing: -0.2,
              color: dark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            )),
        const SizedBox(height: 3),
        Text(sub,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color:
                  dark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            )),
      ],
    );
  }
}

class ProjFaixa extends StatelessWidget {
  const ProjFaixa({
    super.key,
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.detalhe,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String detalhe;

  @override
  Widget build(BuildContext context) => ProjCartao(
        cor: cor.withValues(alpha: 0.055),
        borda: cor.withValues(alpha: 0.38),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icone, color: cor, size: 19),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        height: 1.25,
                        color: cor,
                      )),
                  const SizedBox(height: 3),
                  Text(detalhe,
                      style: const TextStyle(fontSize: 12, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
}

class ProjCarregando extends StatelessWidget {
  const ProjCarregando({super.key, required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(texto,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class ProjAviso extends StatelessWidget {
  const ProjAviso({
    super.key,
    required this.texto,
    this.icone = Icons.info_outline,
    this.cor = AppColors.textSecondary,
  });

  final String texto;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icone, size: 15, color: cor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(texto,
                  style: TextStyle(fontSize: 11.5, height: 1.45, color: cor)),
            ),
          ],
        ),
      );
}

/// Lista rótulo → valor, alinhada à direita com dígitos tabulares.
class ProjLinhas extends StatelessWidget {
  const ProjLinhas({super.key, required this.itens});
  final List<(String, String)> itens;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final i in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // O rótulo cede espaço primeiro, mas o valor também precisa
                  // poder quebrar: em tela estreita, um valor longo colado num
                  // rótulo longo estourava a linha.
                  Flexible(
                      flex: 3,
                      child: Text(i.$1,
                          style: const TextStyle(fontSize: 12, height: 1.35))),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    flex: 2,
                    child: Text(i.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ],
              ),
            ),
        ],
      );
}

class ProjDeslizante extends StatelessWidget {
  const ProjDeslizante({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.texto,
    required this.ajuda,
    required this.onChanged,
  });

  final String rotulo;
  final double valor;
  final double min;
  final double max;
  final String texto;
  final String ajuda;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(rotulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(texto,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: AppColors.primary)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: valor.clamp(min, max),
              min: min,
              max: max,
              label: texto,
              onChanged: onChanged,
            ),
          ),
          Text(ajuda,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

/// Barra dupla antes/depois — mostra a direção da mudança, não só o valor.
class ProjBarraDupla extends StatelessWidget {
  const ProjBarraDupla({
    super.key,
    required this.rotulo,
    required this.antes,
    required this.depois,
    required this.cor,
  });

  final String rotulo;
  final double antes;
  final double depois;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final delta = depois - antes;
    final melhorou = rotulo == 'Compareceu' ? delta > 0 : delta < 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(rotulo,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Text(
                '${NumPtBr.pct(antes)} → ${NumPtBr.pct(depois)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
              if (delta.abs() > 0.0005) ...[
                const SizedBox(width: 6),
                Text(
                  '${delta > 0 ? '+' : '−'}${NumPtBr.pct(delta.abs())}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: melhorou ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          _barra(antes, cor.withValues(alpha: 0.35)),
          const SizedBox(height: 3),
          _barra(depois, cor),
        ],
      ),
    );
  }

  Widget _barra(double v, Color c) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: v.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: c.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(c),
        ),
      );
}
