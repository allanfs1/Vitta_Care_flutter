import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Tipo do relatório (REL-01).
enum RelatorioType {
  ia('IA', AppColors.primary, AppColors.primaryLight, Icons.auto_awesome),
  operacional('Operacional', AppColors.secondary, AppColors.secondaryLight, Icons.insights),
  absenteismo('Absenteísmo', AppColors.danger, AppColors.dangerLight, Icons.person_off_outlined),
  financeiro('Financeiro', AppColors.warning, AppColors.warningLight, Icons.payments_outlined);

  const RelatorioType(this.label, this.color, this.background, this.icon);

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

/// Métrica simples exibida no relatório (rótulo + valor).
class RelatorioMetric {
  const RelatorioMetric(this.label, this.value);
  final String label;
  final String value;
}

/// Relatório gerado (IA ou operacional). Estrutura local do módulo.
class Relatorio {
  const Relatorio({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.period,
    required this.body,
    this.metrics = const [],
  });

  final String id;
  final String title;
  final RelatorioType type;
  final DateTime createdAt;
  final String period;
  final String body;
  final List<RelatorioMetric> metrics;

  /// Serializa o relatório como CSV (REL-03).
  String toCsv() {
    final buffer = StringBuffer()
      ..writeln('campo,valor')
      ..writeln('titulo,"${title.replaceAll('"', '""')}"')
      ..writeln('tipo,${type.label}')
      ..writeln('periodo,$period')
      ..writeln('gerado_em,${createdAt.toIso8601String()}');
    for (final m in metrics) {
      buffer.writeln('${m.label},"${m.value.replaceAll('"', '""')}"');
    }
    return buffer.toString();
  }

  /// Texto completo para copiar (REL-03).
  String toPlainText() {
    final m = metrics.map((e) => '• ${e.label}: ${e.value}').join('\n');
    return '$title ($period)\n\n$body${m.isEmpty ? '' : '\n\nMétricas\n$m'}';
  }
}
