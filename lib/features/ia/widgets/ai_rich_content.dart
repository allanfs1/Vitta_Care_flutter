import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/app_colors.dart';
import 'ai_chart_view.dart';

/// Renderiza um conteúdo de IA: markdown + blocos ```json-chart``` (fl_chart).
/// Compartilhado pelo chat e pelo modo Agentes.
class AiRichContent extends StatelessWidget {
  const AiRichContent({super.key, required this.content, this.textColor});

  final String content;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textPrimaryOf(context);
    final segments = splitAiCharts(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments)
          seg.chart != null
              ? AiChartView(spec: seg.chart!)
              : MarkdownBody(
                  data: seg.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: color, height: 1.4),
                    listBullet: TextStyle(color: color),
                    strong:
                        TextStyle(color: color, fontWeight: FontWeight.bold),
                    h1: TextStyle(color: color, fontWeight: FontWeight.bold),
                    h2: TextStyle(color: color, fontWeight: FontWeight.bold),
                    h3: TextStyle(color: color, fontWeight: FontWeight.bold),
                    code: TextStyle(
                        color: color,
                        backgroundColor: AppColors.surfaceAltOf(context)),
                    tableBorder: TableBorder.all(color: AppColors.borderOf(context)),
                    tableHead:
                        TextStyle(color: color, fontWeight: FontWeight.bold),
                    tableBody: TextStyle(color: color),
                  ),
                ),
      ],
    );
  }
}

/// Segmento: texto markdown OU um gráfico.
class AiSegment {
  AiSegment.text(this.text) : chart = null;
  AiSegment.chart(this.chart) : text = '';
  final String text;
  final ChartSpec? chart;
}

/// Separa blocos ```json-chart``` do restante do markdown.
List<AiSegment> splitAiCharts(String content) {
  final regex = RegExp(r'```json-chart\s*([\s\S]*?)```', multiLine: true);
  final segments = <AiSegment>[];
  var last = 0;
  for (final match in regex.allMatches(content)) {
    if (match.start > last) {
      final t = content.substring(last, match.start).trim();
      if (t.isNotEmpty) segments.add(AiSegment.text(t));
    }
    final spec = ChartSpec.tryParse(match.group(1)?.trim() ?? '');
    segments.add(spec != null
        ? AiSegment.chart(spec)
        : AiSegment.text('_Gerando gráfico…_'));
    last = match.end;
  }
  if (last < content.length) {
    final t = content.substring(last).trim();
    if (t.isNotEmpty) segments.add(AiSegment.text(t));
  }
  if (segments.isEmpty) segments.add(AiSegment.text(content));
  return segments;
}
