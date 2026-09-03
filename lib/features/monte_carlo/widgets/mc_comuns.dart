import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Formatação numérica pt-BR.
///
/// `toStringAsFixed` devolve `0.90` — separador decimal de outra língua no meio
/// de uma tela em português. Aqui é `0,90`, e milhar com ponto.
class McNum {
  const McNum._();

  static String dec(num v, {int casas = 2}) {
    if (v.isNaN) return '—';
    if (v.isInfinite) return v.isNegative ? '−∞' : '∞';
    return v.toStringAsFixed(casas).replaceAll('.', ',');
  }

  static String pct(num fracao, {int casas = 1}) {
    if (fracao.isNaN) return '—';
    return '${dec(fracao * 100, casas: casas)}%';
  }

  /// Percentual já em escala 0–100.
  static String pctDireto(num v, {int casas = 1}) =>
      v.isNaN ? '—' : '${dec(v, casas: casas)}%';

  static String inteiro(num v) {
    if (v.isNaN) return '—';
    final s = v.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${v < 0 ? '−' : ''}$buf';
  }

  static String reais(num v) => 'R\$ ${inteiro(v)}';

  /// Multiplicador: `1,25x`.
  static String vezes(num v, {int casas = 2}) => '${dec(v, casas: casas)}x';
}

/// Cartão base. `destaque` sobe a elevação visual sem mudar o esquema de cor.
class McCartao extends StatelessWidget {
  const McCartao({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardInsets,
    this.cor,
    this.borda,
    this.destaque = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? cor;
  final Color? borda;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cor ?? (dark ? AppColors.surfaceDark : AppColors.surface),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: borda ?? (dark ? AppColors.borderDark : AppColors.border),
          width: destaque ? 1.5 : 1,
        ),
        boxShadow: destaque && !dark
            ? [
                BoxShadow(
                  color: (borda ?? AppColors.primary).withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Título de seção com subtítulo e ação opcional à direita.
class McTitulo extends StatelessWidget {
  const McTitulo({
    super.key,
    required this.titulo,
    required this.sub,
    this.acao,
  });

  final String titulo;
  final String sub;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                    letterSpacing: -0.2,
                    color: dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  )),
              const SizedBox(height: 3),
              Text(sub,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  )),
            ],
          ),
        ),
        if (acao != null) ...[const SizedBox(width: AppSpacing.sm), acao!],
      ],
    );
  }
}

class McSelo extends StatelessWidget {
  const McSelo({
    super.key,
    required this.texto,
    required this.cor,
    this.icone,
  });

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(
            left: icone == null ? 8 : 6, right: 8, top: 3, bottom: 3),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: cor.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 11, color: cor),
              const SizedBox(width: 3),
            ],
            // Flexible + ellipsis: sem isto, um selo com texto longo estoura
            // o Row que o contém em vez de encolher. Não muda nada para os
            // selos curtos, que são todos os usos existentes.
            Flexible(
              child: Text(texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: cor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1.2)),
            ),
          ],
        ),
      );
}

/// KPI. Sabe representar ausência de dado — `—` cinza em vez de zero colorido,
/// porque "não medido" e "medido como zero" são coisas diferentes.
class McKpi extends StatelessWidget {
  const McKpi({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.icone,
    required this.cor,
    this.dica,
    this.indisponivel = false,
    this.sufixo,
  });

  final String rotulo;
  final String valor;
  final IconData icone;
  final Color cor;

  /// Explicação em tooltip — o que o número quer dizer.
  final String? dica;

  final bool indisponivel;

  /// Texto pequeno após o valor (unidade, comparação).
  final String? sufixo;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final corEfetiva = indisponivel ? AppColors.textTertiary : cor;

    final card = McCartao(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: corEfetiva.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: corEfetiva, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        indisponivel ? '—' : valor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                          height: 1.1,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: indisponivel
                              ? AppColors.textTertiary
                              : (dark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ),
                    if (sufixo != null && !indisponivel) ...[
                      const SizedBox(width: 3),
                      Text(sufixo!,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary)),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(rotulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );

    final rotulado = Semantics(
      label: '$rotulo: ${indisponivel ? "sem dado" : valor}',
      child: ExcludeSemantics(child: card),
    );

    return dica == null
        ? rotulado
        : Tooltip(
            message: dica!,
            waitDuration: const Duration(milliseconds: 400),
            child: rotulado,
          );
  }
}

/// Grade responsiva de KPIs.
class McGradeKpis extends StatelessWidget {
  const McGradeKpis({super.key, required this.cartoes});

  final List<McKpi> cartoes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = cartoes.length;
      var colunas = c.maxWidth > 1000
          ? 5
          : (c.maxWidth > 760 ? 4 : (c.maxWidth > 520 ? 3 : 2));
      if (colunas > n) colunas = n;
      if (colunas < 1) colunas = 1;
      final largura = (c.maxWidth - (colunas - 1) * AppSpacing.md) / colunas;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final k in cartoes) SizedBox(width: largura, child: k),
        ],
      );
    });
  }
}

/// Slider com rótulo, valor e ajuda. Sem marcas de divisão: com dezenas de
/// passos elas viram ruído visual e não ajudam a mirar.
class McDeslizante extends StatelessWidget {
  const McDeslizante({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.texto,
    required this.ajuda,
    required this.onChanged,
    this.divisoes,
  });

  final String rotulo;
  final double valor;
  final double min;
  final double max;
  final String texto;
  final String ajuda;
  final ValueChanged<double> onChanged;
  final int? divisoes;

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
              divisions: divisoes,
              label: texto,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(ajuda,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                )),
          ),
        ],
      ),
    );
  }
}

/// Aviso em linha — limitação que precisa ser lida antes de confiar no número.
class McAviso extends StatelessWidget {
  const McAviso({
    super.key,
    required this.texto,
    this.icone = Icons.info_outline,
    this.cor = AppColors.warning,
  });

  final String texto;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                  style: const TextStyle(fontSize: 12, height: 1.45)),
            ),
          ],
        ),
      );
}

/// Faixa de estado no topo de uma seção: ícone, título, detalhe e ação.
///
/// Um só componente para veredito, recomendação e bloqueio — assim os três
/// falam com a mesma voz e a pessoa aprende a lê-los uma vez só.
class McFaixaEstado extends StatelessWidget {
  const McFaixaEstado({
    super.key,
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.detalhe,
    this.acao,
    this.rodape,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String detalhe;
  final Widget? acao;
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    return McCartao(
      destaque: true,
      cor: cor.withValues(alpha: 0.055),
      borda: cor.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          fontSize: 15,
                          height: 1.25,
                          letterSpacing: -0.2,
                          color: cor,
                        )),
                    const SizedBox(height: 3),
                    Text(detalhe,
                        style: const TextStyle(fontSize: 12, height: 1.45)),
                  ],
                ),
              ),
              if (acao != null) ...[
                const SizedBox(width: AppSpacing.sm),
                acao!,
              ],
            ],
          ),
          if (rodape != null) ...[
            const SizedBox(height: AppSpacing.md),
            rodape!,
          ],
        ],
      ),
    );
  }
}

/// Tabela que rola na horizontal sem deixar a página rolar junto.
class McTabela extends StatelessWidget {
  const McTabela({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      );
}
