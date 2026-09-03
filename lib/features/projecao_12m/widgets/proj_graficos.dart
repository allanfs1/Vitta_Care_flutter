import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/num_ptbr.dart';
import '../projecao_amostradores.dart';
import '../projecao_models.dart';
import 'proj_comuns.dart';

/// Aba de gráficos avançados da projeção de 12 meses.
///
/// Nove blocos visuais que traduzem a massa numérica da projeção em leitura
/// imediata: resumo em linguagem natural, KPIs com sparklines, gauges,
/// evolução mensal com bandas de confiança, funil de desfechos, decomposição
/// financeira, heatmap de capacidade, distribuição de desfechos e insights.
class ProjGraficos extends StatelessWidget {
  const ProjGraficos({super.key, required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    return ListView(
      padding: AppSpacing.pageInsets,
      children: [
        _ResumoNatural(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _KpiRow(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _GaugesComparecimento(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _GraficoMensal(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _FunilDesfechos(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _DecomposicaoFinanceira(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _HeatmapCapacidade(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _DestinoAgendamento(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _RadarClinica(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _PainelInsights(resultado: r),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 0. Resumo em linguagem natural
// ═══════════════════════════════════════════════════════════════════════════

class _ResumoNatural extends StatelessWidget {
  const _ResumoNatural({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = resultado;
    final deltaComp = r.agendaClinica.comparecimentos.p50.toDouble() -
        r.baseline.comparecimentos.p50.toDouble();

    String texto;
    IconData icone;
    Color cor;

    if (r.impacto.houvePerda) {
      texto = 'Com as hipóteses atuais, a intervenção reduz '
          '${NumPtBr.inteiro(deltaComp.abs())} comparecimentos em 12 meses. '
          'Revise os parâmetros antes de apresentar este cenário.';
      icone = Icons.warning_amber_rounded;
      cor = AppColors.danger;
    } else {
      final partes = <String>[];
      if (r.faltasEvitadas.p50 > 0) {
        partes.add('evita ~${NumPtBr.inteiro(r.faltasEvitadas.p50)} faltas');
      }
      if (r.impacto.receitaDefensavel > 0) {
        partes.add(
            'gerando ${NumPtBr.reais(r.impacto.receitaDefensavel)} de receita defensável');
      }
      if (r.temDemandaReprimida) {
        partes.add(
            'porém a capacidade estoura em parte dos meses — considerar ampliar agenda');
      }
      final largura = r.larguraRelativa;
      if (largura > 0.25) {
        partes.add(
            'a incerteza é de ${NumPtBr.pct(largura, casas: 0)} da mediana');
      }
      texto = 'A intervenção ${partes.join(', ')}. '
          'Resultados são projeções probabilísticas — o piloto mede o efeito real.';
      icone = Icons.auto_awesome;
      cor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cor.withValues(alpha: 0.08),
            cor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: cor, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo da projeção',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: cor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. KPIs de impacto com sparklines
// ═══════════════════════════════════════════════════════════════════════════

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final deltaComp = r.agendaClinica.comparecimentos.p50.toDouble() -
        r.baseline.comparecimentos.p50.toDouble();
    final pctDelta = r.baseline.comparecimentos.p50 > 0
        ? deltaComp / r.baseline.comparecimentos.p50.toDouble()
        : 0.0;

    final cards = [
      _KpiCard(
        icone: Icons.event_available,
        rotulo: 'Faltas Evitadas',
        valor: NumPtBr.inteiro(r.faltasEvitadas.p50),
        sub: 'P05–P95: ${NumPtBr.inteiro(r.faltasEvitadas.p05)}–'
            '${NumPtBr.inteiro(r.faltasEvitadas.p95)}',
        cor: AppColors.success,
        sparkData: r.agendaClinica.porMes,
      ),
      _KpiCard(
        icone: Icons.attach_money,
        rotulo: 'Receita Defensável',
        valor: NumPtBr.reais(r.impacto.receitaDefensavel),
        sub: r.impacto.houvePerda
            ? 'Cenário com perda — rever hipóteses'
            : 'Ganho atribuível à intervenção',
        cor: r.impacto.houvePerda ? AppColors.danger : AppColors.primary,
        sparkData: null,
      ),
      _KpiCard(
        icone: Icons.trending_up,
        rotulo: 'Δ Comparecimento',
        valor: '${deltaComp > 0 ? '+' : ''}${NumPtBr.inteiro(deltaComp)}',
        sub: '${NumPtBr.pct(pctDelta.abs())} ${deltaComp >= 0 ? 'a mais' : 'a menos'}',
        cor: deltaComp >= 0 ? AppColors.success : AppColors.danger,
        sparkData: r.baseline.porMes,
      ),
      _KpiCard(
        icone: Icons.hourglass_bottom,
        rotulo: 'Demanda Reprimida',
        valor: NumPtBr.inteiro(r.agendaClinica.demandaReprimida.p50),
        sub: r.agendaClinica.demandaReprimida.p50 > 0
            ? 'Consultas que não couberam no teto'
            : 'Sem estouro de capacidade',
        cor: r.agendaClinica.demandaReprimida.p50 > 0
            ? AppColors.warning
            : AppColors.secondary,
        sparkData: null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: AppSpacing.md),
              ],
            ],
          );
        }
        return Column(
          children: [
            Row(children: [
              Expanded(child: cards[0]),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: cards[1]),
            ]),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: cards[2]),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: cards[3]),
            ]),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.sub,
    required this.cor,
    required this.sparkData,
  });

  final IconData icone;
  final String rotulo;
  final String valor;
  final String sub;
  final Color cor;
  final List<int>? sparkData;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: cor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icone, color: cor, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: cor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          // Sparkline
          if (sparkData != null && sparkData!.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 28,
              child: CustomPaint(
                size: const Size(double.infinity, 28),
                painter: _SparklinePainter(
                  data: sparkData!,
                  cor: cor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data, required this.cor});
  final List<int> data;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minV = data.reduce(math.min).toDouble();
    final maxV = data.reduce(math.max).toDouble();
    final range = maxV - minV;
    if (range == 0) return;

    final linePaint = Paint()
      ..color = cor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [cor.withValues(alpha: 0.20), cor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - ((data[i] - minV) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      data != old.data || cor != old.cor;
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. Gauge / Velocímetro da taxa de comparecimento
// ═══════════════════════════════════════════════════════════════════════════

class _GaugesComparecimento extends StatelessWidget {
  const _GaugesComparecimento({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final base = resultado.absorcaoBaseline;
    final interv = resultado.absorcaoIntervencao;
    final taxaBase = base['compareceu'] ?? 0.0;
    final taxaInterv = interv['compareceu'] ?? 0.0;

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Taxa de comparecimento',
            sub: 'Probabilidade de absorção da cadeia de Markov — '
                'quanto a agulha se moveu com a intervenção',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Gauge(
                  titulo: 'Continuidade',
                  taxa: taxaBase,
                  cor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: _Gauge(
                  titulo: 'Com Agenda Clínica',
                  taxa: taxaInterv,
                  cor: AppColors.primary,
                ),
              ),
            ],
          ),
          if ((taxaInterv - taxaBase).abs() > 0.001) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (taxaInterv > taxaBase
                          ? AppColors.success
                          : AppColors.danger)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  '${taxaInterv > taxaBase ? '▲' : '▼'} '
                  '${NumPtBr.pct((taxaInterv - taxaBase).abs())} de diferença',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: taxaInterv > taxaBase
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.titulo,
    required this.taxa,
    required this.cor,
  });

  final String titulo;
  final double taxa;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: dark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: 130,
          height: 75,
          child: CustomPaint(
            painter: _GaugePainter(taxa: taxa, cor: cor, dark: dark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          NumPtBr.pct(taxa, casas: 1),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: cor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.taxa, required this.cor, required this.dark});
  final double taxa;
  final Color cor;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - 4;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background arc
    final bgPaint = Paint()
      ..color = (dark ? AppColors.borderDark : AppColors.border)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = cor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * taxa.clamp(0.0, 1.0),
      false,
      valuePaint,
    );

    // Needle
    final angle = startAngle + sweepAngle * taxa.clamp(0.0, 1.0);
    final needleLength = radius - 16;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );
    final needlePaint = Paint()
      ..color = dark ? AppColors.textPrimaryDark : AppColors.textPrimary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(
        center, 4, Paint()..color = (dark ? AppColors.textPrimaryDark : AppColors.textPrimary));
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      taxa != old.taxa || cor != old.cor || dark != old.dark;
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. Gráfico de linha com bandas de confiança P05–P95
// ═══════════════════════════════════════════════════════════════════════════

class _GraficoMensal extends StatelessWidget {
  const _GraficoMensal({required this.resultado});
  final ProjecaoResultado resultado;

  static const _meses = [
    'M1', 'M2', 'M3', 'M4', 'M5', 'M6',
    'M7', 'M8', 'M9', 'M10', 'M11', 'M12',
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = resultado.baseline;
    final agenda = resultado.agendaClinica;
    final n = math.min(base.porMes.length, agenda.porMes.length);

    if (n == 0) return const SizedBox.shrink();

    // Determinar limites do eixo Y considerando bandas
    var minY = double.infinity;
    var maxY = 0.0;
    for (var i = 0; i < n; i++) {
      final values = <double>[
        base.porMes[i].toDouble(),
        agenda.porMes[i].toDouble(),
      ];
      if (i < base.porMesPercentis.length) {
        values.add(base.porMesPercentis[i].p05.toDouble());
        values.add(base.porMesPercentis[i].p95.toDouble());
      }
      if (i < agenda.porMesPercentis.length) {
        values.add(agenda.porMesPercentis[i].p05.toDouble());
        values.add(agenda.porMesPercentis[i].p95.toDouble());
      }
      for (final v in values) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    final margem = (maxY - minY) * 0.10;
    final yMin = math.max(0, (minY - margem)).toDouble();
    final yMax = maxY + margem;

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Comparecimentos mês a mês',
            sub: 'Mediana com banda P05–P95 — a faixa mostra o quão incerto '
                'é cada mês, não só o total',
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _Legenda(
                cor: dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                rotulo: 'Continuidade',
                tracejada: true,
              ),
              const SizedBox(width: AppSpacing.lg),
              _Legenda(
                cor: AppColors.primary,
                rotulo: 'Com Agenda Clínica',
                tracejada: false,
              ),
              const SizedBox(width: AppSpacing.lg),
              _Legenda(
                cor: AppColors.primary.withValues(alpha: 0.30),
                rotulo: 'Banda P05–P95',
                tracejada: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 260,
            child: CustomPaint(
              foregroundPainter: _BandPainter(
                basePercentis: base.porMesPercentis,
                agendaPercentis: agenda.porMesPercentis,
                yMin: yMin,
                yMax: yMax,
                dark: dark,
              ),
              child: LineChart(
                LineChartData(
                  minY: yMin,
                  maxY: yMax,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        ((yMax - yMin) / 4).ceilToDouble().clamp(1, double.infinity),
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: dark ? AppColors.borderDark : AppColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, _) => Text(
                          NumPtBr.inteiro(v),
                          style: TextStyle(
                            fontSize: 10,
                            color: dark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= n) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              i < _meses.length ? _meses[i] : 'M${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: dark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final isBase = s.barIndex == 0;
                        return LineTooltipItem(
                          '${isBase ? 'Base' : 'Agenda'}: ${NumPtBr.inteiro(s.y)}',
                          TextStyle(
                            color: isBase
                                ? (dark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary)
                                : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    // Baseline — tracejado
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < n; i++)
                          FlSpot(i.toDouble(), base.porMes[i].toDouble()),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                      barWidth: 2,
                      dashArray: [6, 4],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, xPercentage, bar, index) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: dark
                              ? AppColors.surfaceDark
                              : AppColors.surface,
                          strokeWidth: 1.5,
                          strokeColor: dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // Agenda Clínica — sólida
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < n; i++)
                          FlSpot(i.toDouble(), agenda.porMes[i].toDouble()),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, xPercentage, bar, index) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: dark
                              ? AppColors.surfaceDark
                              : AppColors.surface,
                          strokeWidth: 2,
                          strokeColor: AppColors.primary,
                        ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
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

/// Pinta as bandas de confiança P05–P95 como fundo atrás do gráfico de linha.
class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.basePercentis,
    required this.agendaPercentis,
    required this.yMin,
    required this.yMax,
    required this.dark,
  });

  final List<Percentis> basePercentis;
  final List<Percentis> agendaPercentis;
  final double yMin;
  final double yMax;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // fl_chart has paddings for titles. We estimate chart area:
    // left reserved=44, bottom reserved=28
    const leftPad = 44.0;
    const bottomPad = 28.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad;

    void drawBand(List<Percentis> percentis, Color bandColor) {
      if (percentis.isEmpty) return;
      final n = percentis.length;
      final paint = Paint()..color = bandColor;

      final path = Path();
      // P95 line (top of band)
      for (var i = 0; i < n; i++) {
        final x = leftPad + (i / (n - 1)) * chartWidth;
        final y = chartHeight -
            ((percentis[i].p95.toDouble() - yMin) / (yMax - yMin) * chartHeight);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      // P05 line (bottom of band, reversed)
      for (var i = n - 1; i >= 0; i--) {
        final x = leftPad + (i / (n - 1)) * chartWidth;
        final y = chartHeight -
            ((percentis[i].p05.toDouble() - yMin) / (yMax - yMin) * chartHeight);
        path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    drawBand(
      basePercentis,
      (dark ? AppColors.textSecondaryDark : AppColors.textSecondary)
          .withValues(alpha: 0.08),
    );
    drawBand(
      agendaPercentis,
      AppColors.primary.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(_BandPainter old) => true;
}

class _Legenda extends StatelessWidget {
  const _Legenda({
    required this.cor,
    required this.rotulo,
    required this.tracejada,
  });

  final Color cor;
  final String rotulo;
  final bool tracejada;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 3,
            child: CustomPaint(
              painter: _LinhaPainter(cor: cor, tracejada: tracejada),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            rotulo,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: cor),
          ),
        ],
      );
}

class _LinhaPainter extends CustomPainter {
  _LinhaPainter({required this.cor, required this.tracejada});
  final Color cor;
  final bool tracejada;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    if (tracejada) {
      const dashWidth = 4.0;
      const dashGap = 3.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(math.min(x + dashWidth, size.width), size.height / 2),
          paint,
        );
        x += dashWidth + dashGap;
      }
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinhaPainter old) =>
      cor != old.cor || tracejada != old.tracejada;
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. Funil (Waterfall) de desfechos
// ═══════════════════════════════════════════════════════════════════════════

class _FunilDesfechos extends StatelessWidget {
  const _FunilDesfechos({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    _FunilItem item(String rotulo, Percentis base, Percentis agenda,
        Color cor, bool maiorMelhor) {
      return _FunilItem(
        rotulo: rotulo,
        base: base.p50.toDouble(),
        agenda: agenda.p50.toDouble(),
        cor: cor,
        maiorMelhor: maiorMelhor,
      );
    }

    final itens = [
      item('Agendamentos', resultado.baseline.agendamentos,
          resultado.agendaClinica.agendamentos, AppColors.info, true),
      item('Compareceu', resultado.baseline.comparecimentos,
          resultado.agendaClinica.comparecimentos, AppColors.success, true),
      item('Faltou', resultado.baseline.faltas,
          resultado.agendaClinica.faltas, AppColors.danger, false),
      item('Cancelou', resultado.baseline.cancelamentos,
          resultado.agendaClinica.cancelamentos, AppColors.warning, false),
    ];

    final maxVal = itens.fold<double>(
        0, (m, i) => math.max(m, math.max(i.base, i.agenda)));

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Funil de desfechos',
            sub: 'Onde a clínica perde pacientes — antes e depois da '
                'intervenção. A largura da barra é proporcional ao volume',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _LegendaDot(
                cor: dark
                    ? AppColors.textSecondaryDark.withValues(alpha: 0.50)
                    : AppColors.textSecondary.withValues(alpha: 0.35),
                rotulo: 'Continuidade',
              ),
              const SizedBox(width: AppSpacing.lg),
              const _LegendaDot(
                  cor: AppColors.primary, rotulo: 'Com Agenda Clínica'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final i in itens) ...[
            _FunilBarra(item: i, maxVal: maxVal),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _FunilItem {
  const _FunilItem({
    required this.rotulo,
    required this.base,
    required this.agenda,
    required this.cor,
    required this.maiorMelhor,
  });
  final String rotulo;
  final double base;
  final double agenda;
  final Color cor;
  final bool maiorMelhor;
}

class _FunilBarra extends StatelessWidget {
  const _FunilBarra({required this.item, required this.maxVal});
  final _FunilItem item;
  final double maxVal;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final delta = item.agenda - item.base;
    final melhorou = item.maiorMelhor ? delta > 0 : delta < 0;
    final fracBase = maxVal > 0 ? item.base / maxVal : 0.0;
    final fracAgenda = maxVal > 0 ? item.agenda / maxVal : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                item.rotulo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  // Baseline bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fracBase.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                        dark
                            ? AppColors.textSecondaryDark.withValues(alpha: 0.30)
                            : AppColors.textSecondary.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Agenda bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fracAgenda.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(item.cor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumPtBr.inteiro(item.base),
                    style: TextStyle(
                      fontSize: 11,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        NumPtBr.inteiro(item.agenda),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: item.cor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (delta.abs() > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${delta > 0 ? '+' : ''}${NumPtBr.inteiro(delta)}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color:
                                melhorou ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. Gráfico de barras — decomposição financeira
// ═══════════════════════════════════════════════════════════════════════════

class _DecomposicaoFinanceira extends StatelessWidget {
  const _DecomposicaoFinanceira({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final i = resultado.impacto;

    if (i.receitaTotalBruta == 0 && !i.houvePerda) {
      return const SizedBox.shrink();
    }

    final itens = <_BarItem>[
      _BarItem(
        rotulo: 'Falta\nEvitada',
        valor: i.consultasFaltaEvitada * resultado.config.valorConsulta,
        cor: AppColors.success,
      ),
      _BarItem(
        rotulo: 'Demanda\nNova',
        valor: i.consultasDemandaNova * resultado.config.valorConsulta,
        cor: AppColors.primary,
      ),
      _BarItem(
        rotulo: 'Anteci-\npação',
        valor: i.receitaAntecipacao,
        cor: dark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
    ];

    final maxVal =
        itens.fold<double>(0, (m, b) => b.valor.abs() > m ? b.valor.abs() : m);
    final topY = maxVal <= 0 ? 1.0 : (maxVal * 1.20);

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Decomposição financeira',
            sub: 'Receita defensável (verde + azul) versus antecipação '
                '(cinza) — a segunda não é receita nova',
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: topY,
                minY: i.houvePerda ? -topY * 0.3 : 0,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: dark ? AppColors.borderDark : AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIdx, rod, rIdx) =>
                        BarTooltipItem(
                      NumPtBr.reais(rod.toY),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) => Text(
                        NumPtBr.reais(v),
                        style: TextStyle(
                          fontSize: 9,
                          color: dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= itens.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            itens[idx].rotulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: dark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var j = 0; j < itens.length; j++)
                    BarChartGroupData(
                      x: j,
                      barRods: [
                        BarChartRodData(
                          toY: itens[j].valor,
                          width: 36,
                          color: itens[j].cor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var j = 0; j < itens.length; j++) ...[
                _LegendaDot(
                    cor: itens[j].cor,
                    rotulo: itens[j].rotulo.replaceAll('\n', ' ')),
                if (j < itens.length - 1)
                  const SizedBox(width: AppSpacing.lg),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BarItem {
  const _BarItem(
      {required this.rotulo, required this.valor, required this.cor});
  final String rotulo;
  final double valor;
  final Color cor;
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. Heatmap de risco de capacidade
// ═══════════════════════════════════════════════════════════════════════════

class _HeatmapCapacidade extends StatelessWidget {
  const _HeatmapCapacidade({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseDemanda = resultado.baseline.demandaPorMes;
    final agendaDemanda = resultado.agendaClinica.demandaPorMes;
    final n = math.min(baseDemanda.length, agendaDemanda.length);

    if (n == 0) return const SizedBox.shrink();

    // Only show if there's any overflow risk
    final hasRisk = baseDemanda.any((v) => v > 0) ||
        agendaDemanda.any((v) => v > 0);
    if (!hasRisk) return const SizedBox.shrink();

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Risco de capacidade por mês',
            sub: 'Fração das replicações que estouram o teto em cada mês — '
                'vermelho = gargalo frequente',
          ),
          const SizedBox(height: AppSpacing.md),
          _HeatRow(
            rotulo: 'Continuidade',
            dados: baseDemanda.take(n).toList(),
            dark: dark,
          ),
          const SizedBox(height: AppSpacing.sm),
          _HeatRow(
            rotulo: 'Com intervenção',
            dados: agendaDemanda.take(n).toList(),
            dark: dark,
          ),
          const SizedBox(height: AppSpacing.md),
          // Color scale
          Row(
            children: [
              Text('0%',
                  style: TextStyle(
                      fontSize: 9,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary)),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.warning,
                        AppColors.danger,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('100%',
                  style: TextStyle(
                      fontSize: 9,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatRow extends StatelessWidget {
  const _HeatRow({
    required this.rotulo,
    required this.dados,
    required this.dark,
  });

  final String rotulo;
  final List<double> dados;
  final bool dark;

  Color _corDeFracao(double f) {
    if (f < 0.05) return AppColors.success;
    if (f < 0.25) return Color.lerp(AppColors.success, AppColors.warning, (f - 0.05) / 0.20)!;
    if (f < 0.60) return Color.lerp(AppColors.warning, AppColors.danger, (f - 0.25) / 0.35)!;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: dark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < dados.length; i++) ...[
              Expanded(
                child: Tooltip(
                  message: 'M${i + 1}: ${NumPtBr.pct(dados[i], casas: 0)} das '
                      'replicações estouram',
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: _corDeFracao(dados[i]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'M${i + 1}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              if (i < dados.length - 1) const SizedBox(width: 2),
            ],
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 7. Donut Chart — destino do agendamento antes × depois
// ═══════════════════════════════════════════════════════════════════════════

class _DestinoAgendamento extends StatelessWidget {
  const _DestinoAgendamento({required this.resultado});
  final ProjecaoResultado resultado;

  static const _categorias = [
    'compareceu',
    'faltou',
    'cancelado',
    'reagendado'
  ];
  static const _rotulos = ['Compareceu', 'Faltou', 'Cancelado', 'Reagendado'];
  static const _cores = [
    AppColors.success,
    AppColors.danger,
    AppColors.warning,
    AppColors.secondary,
  ];

  @override
  Widget build(BuildContext context) {
    final base = resultado.absorcaoBaseline;
    final interv = resultado.absorcaoIntervencao;

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Destino do agendamento — visual',
            sub: 'Distribuição de desfechos da cadeia de Markov. '
                'Antes e depois da intervenção',
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartSize =
                  math.min(160.0, constraints.maxWidth * 0.3);
              return Row(
                children: [
                  Expanded(
                    child: _DonutCenario(
                      titulo: 'Continuidade',
                      dados: base,
                      tamanho: chartSize,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DonutCenario(
                      titulo: 'Com Agenda Clínica',
                      dados: interv,
                      tamanho: chartSize,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _categorias.length; i++)
            Builder(
              builder: (context) {
                final k = _categorias[i];
                final antes = base[k] ?? 0.0;
                final depois = interv[k] ?? 0.0;
                final delta = depois - antes;
                if (antes < 0.0001 && depois < 0.0001) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _cores[i],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _rotulos[i],
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${NumPtBr.pct(antes)} → ${NumPtBr.pct(depois)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (delta.abs() > 0.0005) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                _corDelta(k, delta).withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            '${delta > 0 ? '+' : '−'}${NumPtBr.pct(delta.abs())}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _corDelta(k, delta),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _corDelta(String k, double delta) {
    final melhorou =
        k == 'compareceu' || k == 'reagendado' ? delta > 0 : delta < 0;
    return melhorou ? AppColors.success : AppColors.danger;
  }
}

class _DonutCenario extends StatelessWidget {
  const _DonutCenario({
    required this.titulo,
    required this.dados,
    required this.tamanho,
  });

  final String titulo;
  final Map<String, double> dados;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final categorias = _DestinoAgendamento._categorias;
    final cores = _DestinoAgendamento._cores;

    final secoes = <PieChartSectionData>[];
    for (var i = 0; i < categorias.length; i++) {
      final v = dados[categorias[i]] ?? 0.0;
      if (v < 0.0001) continue;
      secoes.add(PieChartSectionData(
        value: v * 100,
        color: cores[i],
        radius: tamanho * 0.18,
        showTitle: false,
      ));
    }

    if (secoes.isEmpty) {
      return Column(
        children: [
          Text(titulo,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          const Text('Sem dados', style: TextStyle(fontSize: 11)),
        ],
      );
    }

    final pComp = dados['compareceu'] ?? 0.0;

    return Column(
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: dark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: tamanho,
          height: tamanho,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: tamanho * 0.30,
                  sections: secoes,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    NumPtBr.pct(pComp, casas: 0),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'compareceu',
                    style: TextStyle(
                      fontSize: 9,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 8. Radar Chart multidimensional
// ═══════════════════════════════════════════════════════════════════════════

class _RadarClinica extends StatelessWidget {
  const _RadarClinica({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = resultado;

    // Normalize all metrics to 0-1 scale
    final taxaComp = r.absorcaoIntervencao['compareceu'] ?? 0.0;
    final taxaCompBase = r.absorcaoBaseline['compareceu'] ?? 0.0;

    // Efficiency: defensive revenue / total gross (0-1)
    final eficiencia = r.impacto.receitaTotalBruta > 0
        ? (r.impacto.receitaDefensavel / r.impacto.receitaTotalBruta)
            .clamp(0.0, 1.0)
        : 0.0;

    // Capacity utilization (inverse of repression)
    final capacidade = 1.0 -
        (r.agendaClinica.probabilidadeEstouro).clamp(0.0, 1.0);

    // Certainty (inverse of relative width)
    final certeza = (1.0 - r.larguraRelativa).clamp(0.0, 1.0);

    // Improvement delta (normalized to 0-1)
    final melhoria = taxaComp > 0 && taxaCompBase > 0
        ? ((taxaComp - taxaCompBase) / taxaCompBase * 5 + 0.5).clamp(0.0, 1.0)
        : 0.5;

    final axes = <_RadarAxis>[
      _RadarAxis('Comparecimento', taxaComp),
      _RadarAxis('Eficiência', eficiencia),
      _RadarAxis('Capacidade', capacidade),
      _RadarAxis('Certeza', certeza),
      _RadarAxis('Melhoria', melhoria),
    ];

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Radar da projeção',
            sub: 'Visão multidimensional — cinco eixos normalizados para '
                'leitura rápida da saúde do cenário',
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _RadarPainter(
                  axes: axes,
                  cor: AppColors.primary,
                  dark: dark,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final a in axes)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${a.rotulo}: ${NumPtBr.pct(a.valor, casas: 0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadarAxis {
  const _RadarAxis(this.rotulo, this.valor);
  final String rotulo;
  final double valor;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.cor,
    required this.dark,
  });

  final List<_RadarAxis> axes;
  final Color cor;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 24;
    final n = axes.length;
    if (n < 3) return;

    // Draw grid
    final gridPaint = Paint()
      ..color = (dark ? AppColors.borderDark : AppColors.border)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / n);
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw spokes and labels
    final textColor = dark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);

      // Label
      final labelX = center.dx + (radius + 16) * math.cos(angle);
      final labelY = center.dy + (radius + 16) * math.sin(angle);
      final tp = TextPainter(
        text: TextSpan(
          text: axes[i].rotulo,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelX - tp.width / 2, labelY - tp.height / 2));
    }

    // Draw value polygon
    final valuePath = Path();
    final fillPaint = Paint()..color = cor.withValues(alpha: 0.15);
    final strokePaint = Paint()
      ..color = cor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = cor;

    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final v = axes[i].valor.clamp(0.0, 1.0);
      final r = radius * v;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        valuePath.moveTo(x, y);
      } else {
        valuePath.lineTo(x, y);
      }
    }
    valuePath.close();
    canvas.drawPath(valuePath, fillPaint);
    canvas.drawPath(valuePath, strokePaint);

    // Draw dots
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final v = axes[i].valor.clamp(0.0, 1.0);
      final r = radius * v;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..color = dark ? AppColors.surfaceDark : AppColors.surface
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
// 9. Painel de insights e feedbacks contextuais
// ═══════════════════════════════════════════════════════════════════════════

class _PainelInsights extends StatelessWidget {
  const _PainelInsights({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final insights = _gerarInsights();
    if (insights.isEmpty) return const SizedBox.shrink();

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Insights e feedbacks',
            sub: 'Alertas contextuais derivados automaticamente da projeção '
                'ativa — ajudam a priorizar o que discutir',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final ins in insights) ...[
            _InsightCard(insight: ins),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  List<_Insight> _gerarInsights() {
    final r = resultado;
    final ins = <_Insight>[];

    // 1. Sobreposição dos intervalos
    final baseP05 = r.baseline.comparecimentos.p05.toDouble();
    final baseP95 = r.baseline.comparecimentos.p95.toDouble();
    final agP05 = r.agendaClinica.comparecimentos.p05.toDouble();
    final agP95 = r.agendaClinica.comparecimentos.p95.toDouble();
    final overlap = math.max(
        0.0, math.min(baseP95, agP95) - math.max(baseP05, agP05));
    final larguraBase = baseP95 - baseP05;
    if (larguraBase > 0) {
      final pctOverlap = overlap / larguraBase;
      if (pctOverlap > 0.6) {
        ins.add(_Insight(
          icone: Icons.compare_arrows,
          cor: AppColors.warning,
          titulo: 'Alta sobreposição de cenários',
          detalhe: 'Os intervalos P05–P95 se sobrepõem em '
              '${NumPtBr.pct(pctOverlap, casas: 0)} da faixa. A diferença '
              'mediana é real, mas muitos futuros plausíveis do cenário com '
              'intervenção são indistinguíveis do baseline.',
        ));
      }
    }

    // 2. Capacidade
    if (r.temDemandaReprimida) {
      final meses = r.agendaClinica.mesesComDemandaReprimida;
      ins.add(_Insight(
        icone: Icons.event_busy,
        cor: AppColors.pinkAccent,
        titulo: 'Gargalo de capacidade detectado',
        detalhe: 'A projeção estoura o teto de '
            '${NumPtBr.inteiro(r.config.capacidadeMensal)}/mês '
            'em ${meses >= 1 ? '${meses.toStringAsFixed(0)} mês(es)' : 'parte das replicações'}. '
            'A intervenção não cria capacidade.',
      ));
    }

    // 3. Superestimativa ingênua
    if (r.impacto.receitaDefensavel > 0 &&
        r.impacto.superestimativaIngenua > 0.50) {
      ins.add(_Insight(
        icone: Icons.warning_amber,
        cor: AppColors.danger,
        titulo: 'Conta ingênua superestima em '
            '${NumPtBr.pct(r.impacto.superestimativaIngenua, casas: 0)}',
        detalhe: 'Somar tudo como receita nova daria '
            '${NumPtBr.reais(r.impacto.receitaTotalBruta)}, mas '
            '${NumPtBr.reais(r.impacto.receitaAntecipacao)} é antecipação.',
      ));
    }

    // 4. Eficiência da intervenção
    if (r.faltasEvitadas.p50 > 0 && r.impacto.receitaDefensavel > 0) {
      final porFalta =
          r.impacto.receitaDefensavel / r.faltasEvitadas.p50.toDouble();
      ins.add(_Insight(
        icone: Icons.speed,
        cor: AppColors.secondary,
        titulo: '${NumPtBr.reaisExato(porFalta)} por falta evitada',
        detalhe: 'Compare com o custo operacional de cada contato para '
            'avaliar o ROI da intervenção.',
      ));
    }

    // 5. Intervenção piora resultado
    if (r.impacto.houvePerda) {
      ins.add(_Insight(
        icone: Icons.trending_down,
        cor: AppColors.danger,
        titulo: 'A intervenção reduz comparecimentos',
        detalhe: 'A mediana com intervenção é pior que o baseline. Revise '
            'os parâmetros antes de apresentar.',
      ));
    }

    // 6. Risco de não-diferença
    if (!r.impacto.houvePerda && r.baseline.comparecimentos.p50 > 0) {
      final ganhoRel =
          (r.agendaClinica.comparecimentos.p50 -
                      r.baseline.comparecimentos.p50)
                  .toDouble() /
              r.baseline.comparecimentos.p50.toDouble();
      if (ganhoRel > 0 && ganhoRel < 0.05) {
        ins.add(_Insight(
          icone: Icons.remove_circle_outline,
          cor: AppColors.warning,
          titulo: 'Ganho menor que 5%',
          detalhe: 'Diferença de apenas ${NumPtBr.pct(ganhoRel, casas: 1)}. '
              'Pode ser estatisticamente indistinguível de zero no piloto.',
        ));
      }
    }

    // 7. Faixa muito larga
    if (r.larguraRelativa > 0.30) {
      ins.add(_Insight(
        icone: Icons.unfold_more,
        cor: AppColors.info,
        titulo:
            'Incerteza elevada (${NumPtBr.pct(r.larguraRelativa, casas: 0)})',
        detalhe: 'Aumentar o histórico ou estreitar o WAPE do forecast '
            'reduz a faixa.',
      ));
    }

    return ins;
  }
}

class _Insight {
  const _Insight({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.detalhe,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String detalhe;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final _Insight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: insight.cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: insight.cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: insight.cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(insight.icone, color: insight.cor, size: 17),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: insight.cor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.detalhe,
                  style: const TextStyle(fontSize: 11.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendaDot extends StatelessWidget {
  const _LegendaDot({required this.cor, required this.rotulo});
  final Color cor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            rotulo,
            style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      );
}
