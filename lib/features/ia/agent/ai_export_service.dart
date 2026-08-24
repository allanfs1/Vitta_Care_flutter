import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../widgets/ai_chart_view.dart';
import '../widgets/ai_rich_content.dart';

/// Exporta a resposta do agente (texto + gráficos) para PDF/Excel.
///
/// Os gráficos são desenhados **nativamente** pelo pacote `pdf` a partir do
/// [ChartSpec] (sem capturar widgets da tela), então funciona headless,
/// inclusive no Flutter Web. O download é feito via `file_saver`.
class AiExportService {
  const AiExportService();

  /// Paleta para os gráficos no PDF (espelha o tom da UI).
  static const List<PdfColor> _palette = [
    PdfColor.fromInt(0xFFEC4899), // pink
    PdfColor.fromInt(0xFF8B5CF6), // purple
    PdfColor.fromInt(0xFF14B8A6), // teal
    PdfColor.fromInt(0xFFF59E0B), // amber
    PdfColor.fromInt(0xFF3B82F6), // blue
    PdfColor.fromInt(0xFFEF4444), // red
    PdfColor.fromInt(0xFF10B981), // green
  ];

  PdfColor _color(int i) => _palette[i % _palette.length];

  /// Extrai os gráficos (`json-chart`) de um conteúdo de IA.
  static List<ChartSpec> chartsOf(String content) => splitAiCharts(content)
      .where((s) => s.chart != null)
      .map((s) => s.chart!)
      .toList();

  // ---- PDF: resposta completa (texto + gráficos) ----

  Future<void> exportResponsePdf({
    required String title,
    required String content,
    String? subtitle,
  }) async {
    final doc = pw.Document();
    final segments = splitAiCharts(content);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) {
          final widgets = <pw.Widget>[_pdfTitle(title, subtitle)];
          for (final seg in segments) {
            if (seg.chart != null) {
              widgets.add(_pdfChart(seg.chart!));
            } else {
              widgets.addAll(_pdfMarkdown(seg.text));
            }
          }
          return widgets;
        },
      ),
    );
    await _save(await doc.save(), title, 'pdf', MimeType.pdf);
  }

  // ---- PDF: apenas os gráficos ----

  Future<void> exportChartsPdf({
    required String title,
    required List<ChartSpec> charts,
    String? subtitle,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) {
          final widgets = <pw.Widget>[_pdfTitle(title, subtitle)];
          if (charts.isEmpty) {
            widgets.add(pw.Text('Nenhum gráfico nesta resposta.'));
          }
          for (final c in charts) {
            widgets.add(_pdfChart(c));
          }
          return widgets;
        },
      ),
    );
    await _save(await doc.save(), '$title-graficos', 'pdf', MimeType.pdf);
  }

  // ---- Excel: dados dos gráficos (uma planilha por gráfico) ----

  Future<void> exportChartsExcel({
    required String title,
    required List<ChartSpec> charts,
  }) async {
    final book = xls.Excel.createExcel();
    final used = <String>{};

    if (charts.isEmpty) {
      final sheet = book['Dados'];
      sheet.appendRow([xls.TextCellValue('Sem gráficos nesta resposta.')]);
    } else {
      for (var i = 0; i < charts.length; i++) {
        final spec = charts[i];
        final sheet = book[_sheetName(spec, i, used)];
        sheet.appendRow([
          xls.TextCellValue(
              spec.title.isEmpty ? 'Gráfico ${i + 1}' : spec.title),
        ]);
        sheet.appendRow([
          xls.TextCellValue('Rótulo'),
          xls.TextCellValue('Valor'),
        ]);
        for (final p in spec.points) {
          sheet.appendRow([
            xls.TextCellValue(p.label),
            xls.DoubleCellValue(p.value),
          ]);
        }
      }
    }

    // Remove a planilha padrão vazia quando criamos planilhas nomeadas.
    if (book.sheets.keys.contains('Sheet1') &&
        !used.contains('Sheet1') &&
        book.sheets.length > 1) {
      book.delete('Sheet1');
    }

    final bytes = book.save();
    if (bytes != null) {
      await _save(
          Uint8List.fromList(bytes), title, 'xlsx', MimeType.microsoftExcel);
    }
  }

  // ---- PDF helpers ----

  pw.Widget _pdfTitle(String title, String? subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style:
                pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (subtitle != null && subtitle.isNotEmpty)
          pw.Text(subtitle,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromInt(0xFF6B7280))),
        pw.Divider(color: const PdfColor.fromInt(0xFFE5E7EB)),
        pw.SizedBox(height: 6),
      ],
    );
  }

  /// Conversão leve de markdown → widgets PDF (cabeçalhos, listas, parágrafos).
  /// Marcadores inline (`**`, `*`, `` ` ``) são removidos.
  List<pw.Widget> _pdfMarkdown(String text) {
    final widgets = <pw.Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(_pdfHeading(line.substring(4), 12));
      } else if (line.startsWith('## ')) {
        widgets.add(_pdfHeading(line.substring(3), 14));
      } else if (line.startsWith('# ')) {
        widgets.add(_pdfHeading(line.substring(2), 16));
      } else if (line.startsWith('- ') ||
          line.startsWith('* ') ||
          line.startsWith('• ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
          child: pw.Text('•  ${_stripInline(line.substring(2))}',
              style: const pw.TextStyle(fontSize: 11)),
        ));
      } else {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(_stripInline(line),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ));
      }
    }
    return widgets;
  }

  pw.Widget _pdfHeading(String text, double size) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Text(_stripInline(text),
            style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold)),
      );

  String _stripInline(String s) =>
      s.replaceAll('**', '').replaceAll('`', '').replaceAll('__', '').trim();

  pw.Widget _pdfChart(ChartSpec spec) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (spec.title.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(spec.title,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          pw.SizedBox(width: 470, height: 230, child: _pdfChartBody(spec)),
        ],
      ),
    );
  }

  pw.Widget _pdfChartBody(ChartSpec spec) {
    if (spec.points.isEmpty) return pw.Text('(sem dados)');

    if (spec.type == 'pie') {
      return pw.Chart(
        grid: pw.PieGrid(),
        datasets: [
          for (var i = 0; i < spec.points.length; i++)
            pw.PieDataSet(
              value: spec.points[i].value,
              legend: spec.points[i].label,
              color: _color(i),
              legendStyle: const pw.TextStyle(fontSize: 9),
            ),
        ],
      );
    }

    final maxV =
        spec.points.map((p) => p.value).fold<double>(0, (a, b) => b > a ? b : a);
    final top = maxV <= 0 ? 1.0 : maxV * 1.2;
    final yTicks = [for (var i = 0; i <= 4; i++) (top / 4) * i];
    final data = [
      for (var i = 0; i < spec.points.length; i++)
        pw.PointChartValue(i.toDouble(), spec.points[i].value),
    ];

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          [for (final p in spec.points) p.label],
          marginStart: 30,
          textStyle: const pw.TextStyle(fontSize: 8),
        ),
        yAxis: pw.FixedAxis(
          yTicks,
          divisions: true,
          format: (v) => v.toStringAsFixed(0),
          textStyle: const pw.TextStyle(fontSize: 8),
        ),
      ),
      datasets: [
        if (spec.type == 'line')
          pw.LineDataSet(
            data: data,
            color: _color(0),
            isCurved: true,
            drawPoints: true,
            drawSurface: true,
          )
        else
          pw.BarDataSet(data: data, color: _color(0), width: 16),
      ],
    );
  }

  // ---- Excel helpers ----

  /// Nome de planilha válido (≤31 chars, sem caracteres proibidos, único).
  String _sheetName(ChartSpec spec, int index, Set<String> used) {
    var base = (spec.title.isEmpty ? 'Gráfico ${index + 1}' : spec.title)
        .replaceAll(RegExp(r'[\[\]\:\*\?\/\\]'), ' ')
        .trim();
    if (base.isEmpty) base = 'Gráfico ${index + 1}';
    if (base.length > 28) base = base.substring(0, 28);
    var name = base;
    var n = 2;
    while (used.contains(name)) {
      name = '$base $n';
      n++;
    }
    used.add(name);
    return name;
  }

  // ---- Download ----

  Future<void> _save(
      Uint8List bytes, String title, String ext, MimeType mime) async {
    await FileSaver.instance.saveFile(
      name: _fileBase(title),
      bytes: bytes,
      fileExtension: ext,
      mimeType: mime,
    );
  }

  String _fileBase(String title) {
    final base = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return base.isEmpty ? 'relatorio-ia' : base;
  }
}
