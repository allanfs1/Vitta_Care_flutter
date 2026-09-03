import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../monte_carlo_models.dart';

/// Histograma da distribuição de faltas com as faixas P05 / P50 / P95.
///
/// A leitura que importa não é a barra mais alta e sim a **largura da cauda**:
/// é ela que decide overbooking. Por isso os quantis são desenhados como
/// marcas verticais sobre as barras, e não apenas listados em texto.
class DistribuicaoChart extends StatelessWidget {
  const DistribuicaoChart({
    super.key,
    required this.distribuicao,
    this.altura = 190,
    this.corBarra = AppColors.primary,
    this.rotulo = 'faltas',
  });

  final Distribuicao distribuicao;
  final double altura;
  final Color corBarra;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final texto = dark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    if (distribuicao.total == 0) {
      return SizedBox(
        height: altura,
        child: Center(
          child: Text('Sem dados para exibir',
              style: TextStyle(color: texto, fontSize: 12)),
        ),
      );
    }

    // Recorta a faixa útil: fora dela as barras são invisíveis e só espremem
    // o gráfico. Mantém uma folga para a cauda não parecer cortada.
    final p05 = distribuicao.p05;
    final p95 = distribuicao.p95;
    final margem = math.max(3, ((p95 - p05) * 0.6).round());
    final ini = math.max(0, p05 - margem);
    final fim = math.min(distribuicao.contagens.length - 1, p95 + margem);

    final fatias = <int>[
      for (var k = ini; k <= fim; k++) distribuicao.contagens[k],
    ];
    final maxC = fatias.fold(0, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: altura,
          child: LayoutBuilder(
            builder: (context, c) {
              final n = fatias.length;
              final larguraBarra = n == 0 ? 0.0 : c.maxWidth / n;
              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0.5),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: maxC == 0
                                    ? 0
                                    : (fatias[i] / maxC) * (altura - 22),
                                decoration: BoxDecoration(
                                  color: _corDe(ini + i, p05, p95),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(2)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final marca in [
                    (p05, 'P05', AppColors.warning),
                    (distribuicao.p50, 'P50', AppColors.textSecondary),
                    (p95, 'P95', AppColors.danger),
                  ])
                    if (marca.$1 >= ini && marca.$1 <= fim)
                      Positioned(
                        left: (marca.$1 - ini + 0.5) * larguraBarra - 14,
                        top: 0,
                        bottom: 18,
                        child: _Marca(
                            rotulo: marca.$2, valor: marca.$1, cor: marca.$3),
                      ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$ini', style: TextStyle(color: texto, fontSize: 10)),
            Text('número de $rotulo',
                style: TextStyle(color: texto, fontSize: 10)),
            Text('$fim', style: TextStyle(color: texto, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Color _corDe(int k, int p05, int p95) {
    if (k < p05) return AppColors.warning.withValues(alpha: 0.55);
    if (k > p95) return AppColors.danger.withValues(alpha: 0.55);
    return corBarra.withValues(alpha: 0.85);
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.rotulo, required this.valor, required this.cor});

  final String rotulo;
  final int valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text('$rotulo $valor',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800)),
        ),
        Expanded(child: Container(width: 1.5, color: cor.withValues(alpha: 0.6))),
      ],
    );
  }
}
