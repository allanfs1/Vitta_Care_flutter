import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Estado vazio padrão do Cérebro (`obsidian.md` §10.5.5 e §10.15).
///
/// Nunca uma tela em branco: todo vazio explica o que aconteceu e oferece a
/// próxima ação.
class CerebroVazio extends StatelessWidget {
  const CerebroVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.acoes = const [],
    this.dica,
    this.cor,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final List<Widget> acoes;

  /// Linha final opcional — normalmente um atalho ou uma sintaxe a lembrar.
  final String? dica;

  /// Cor do halo do ícone; por padrão o accent do módulo.
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final destaque = cor ?? AppColors.pinkAccent;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Halo suave em vez de um ícone cinza solto: dá foco ao vazio
                // sem transformá-lo em alerta.
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        destaque.withValues(alpha: 0.18),
                        destaque.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: Icon(icone,
                      size: 27, color: destaque.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  descricao,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                if (acoes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: acoes,
                  ),
                ],
                if (dica != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAltOf(context),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      dica!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Esqueleto de carregamento do grafo — 40 círculos em posições fixas com
/// shimmer, em vez de um spinner genérico (§10.5.5).
class EsqueletoGrafo extends StatefulWidget {
  const EsqueletoGrafo({super.key});

  @override
  State<EsqueletoGrafo> createState() => _EsqueletoGrafoState();
}

class _EsqueletoGrafoState extends State<EsqueletoGrafo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        painter: _EsqueletoPainter(
          fase: _ctrl.value,
          cor: AppColors.textSecondaryOf(context),
          fundo: AppColors.backgroundOf(context),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _EsqueletoPainter extends CustomPainter {
  _EsqueletoPainter({required this.fase, required this.cor, required this.fundo});

  final double fase;
  final Color cor;
  final Color fundo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fundo);
    final centro = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    // Espiral determinística — mesma semente do layout real (§7.2 › semear).
    const phi = 2.399963229728653;
    for (var i = 0; i < 40; i++) {
      final r = size.shortestSide * 0.045 * (i + 1) / 6;
      final a = i * phi;
      final p = centro + Offset(r * 1.6 * _cos(a), r * 1.6 * _sen(a));
      final opacidade = 0.05 + 0.09 * ((fase + i / 40) % 1.0);
      paint.color = cor.withValues(alpha: opacidade);
      canvas.drawCircle(p, 3.0 + (i % 5), paint);
    }
  }

  static double _cos(double x) {
    // Aproximação suficiente para o esqueleto (evita import de dart:math).
    var t = x % 6.283185307179586;
    if (t > 3.141592653589793) t -= 6.283185307179586;
    final t2 = t * t;
    return 1 - t2 / 2 + t2 * t2 / 24 - t2 * t2 * t2 / 720;
  }

  static double _sen(double x) => _cos(x - 1.5707963267948966);

  @override
  bool shouldRepaint(covariant _EsqueletoPainter old) => old.fase != fase;
}
