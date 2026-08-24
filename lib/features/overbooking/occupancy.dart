import 'package:flutter/material.dart';

/// Nível de ocupação de um horário (overbooking §1) — **fonte única** da regra
/// de classificação usada pelo Totem, pela Agenda do Médico e pelo Painel de
/// Overbooking. Antes cada tela tinha seus próprios limiares/cores (ver
/// OVERBOOKING.md §B6); aqui elas ficam unificadas.
enum OccupancyLevel {
  /// Sem lotação: bastante folga.
  livre,

  /// Meia lotação.
  media,

  /// Quase cheio (últimas vagas).
  ultimas,

  /// Sem vagas (capacidade + overbook atingidos).
  lotado;

  /// Classifica um horário a partir de agendados x capacidade. A capacidade é
  /// normalizada para `>= 1` para evitar divisão por zero e o falso "LOTADO"
  /// quando a config zera a capacidade (ver OVERBOOKING.md §B2/§B3).
  factory OccupancyLevel.from({required int booked, required int capacity}) {
    final cap = capacity < 1 ? 1 : capacity;
    if (booked >= cap) return OccupancyLevel.lotado;
    final ratio = booked / cap;
    if (ratio >= 0.8) return OccupancyLevel.ultimas;
    if (ratio >= 0.5) return OccupancyLevel.media;
    return OccupancyLevel.livre;
  }

  /// Proporção ocupada (0..1), com capacidade normalizada.
  static double ratio({required int booked, required int capacity}) {
    final cap = capacity < 1 ? 1 : capacity;
    final r = booked / cap;
    return r < 0 ? 0 : (r > 1 ? 1 : r);
  }

  /// Cor canônica do nível (mesma paleta do totem, neutra ao tema).
  Color get color => switch (this) {
        OccupancyLevel.livre => const Color(0xFF2E9E5B),
        OccupancyLevel.media => const Color(0xFFF5A623),
        OccupancyLevel.ultimas => const Color(0xFFE53935),
        OccupancyLevel.lotado => const Color(0xFF9E9E9E),
      };

  /// Rótulo curto exibido em legendas/badges.
  String get label => switch (this) {
        OccupancyLevel.livre => 'LIVRE',
        OccupancyLevel.media => 'MÉDIA',
        OccupancyLevel.ultimas => 'ÚLTIMAS',
        OccupancyLevel.lotado => 'LOTADO',
      };

  bool get isFull => this == OccupancyLevel.lotado;
}
