import 'package:flutter/material.dart';

/// Classificação de risco pelo Protocolo Manchester (§1.3 — `tickets.priority`).
///
/// A ordem do enum (do mais grave para o menos) define a prioridade de
/// atendimento na fila: menor `index` = maior urgência.
enum ManchesterPriority {
  red('Emergência', Color(0xFFE53935)),
  orange('Muito urgente', Color(0xFFFB8C00)),
  yellow('Urgente', Color(0xFFFDD835)),
  green('Pouco urgente', Color(0xFF43A047));

  const ManchesterPriority(this.label, this.color);

  final String label;
  final Color color;

  /// Cor de texto legível sobre [color] (o amarelo precisa de texto escuro).
  Color get onColor =>
      this == ManchesterPriority.yellow ? Colors.black87 : Colors.white;
}
