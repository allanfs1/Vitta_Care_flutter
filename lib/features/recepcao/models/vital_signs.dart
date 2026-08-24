import 'manchester_priority.dart';

/// Sinais vitais aferidos no acolhimento (embasam a classificação de risco).
/// Todos opcionais — nem toda procura exige aferição completa.
class VitalSigns {
  const VitalSigns({
    this.paSistolica,
    this.paDiastolica,
    this.fc,
    this.temperatura,
    this.satO2,
    this.glicemia,
    this.dor,
  });

  final int? paSistolica; // mmHg
  final int? paDiastolica; // mmHg
  final int? fc; // bpm
  final double? temperatura; // °C
  final int? satO2; // %
  final int? glicemia; // mg/dL
  final int? dor; // escala 0–10

  bool get isEmpty =>
      paSistolica == null &&
      paDiastolica == null &&
      fc == null &&
      temperatura == null &&
      satO2 == null &&
      glicemia == null &&
      dor == null;

  String? get paLabel =>
      (paSistolica != null && paDiastolica != null)
          ? '$paSistolica/$paDiastolica'
          : null;

  /// Sugestão de classificação Manchester a partir dos vitais (apoio à decisão;
  /// o profissional pode sobrepor). Regras simplificadas para fins de demo.
  ManchesterPriority get suggestedPriority {
    if ((satO2 != null && satO2! < 90) ||
        (dor != null && dor! >= 9) ||
        (paSistolica != null && paSistolica! >= 220)) {
      return ManchesterPriority.red;
    }
    if ((satO2 != null && satO2! < 94) ||
        (dor != null && dor! >= 7) ||
        (temperatura != null && temperatura! >= 39.5) ||
        (paSistolica != null && paSistolica! >= 180) ||
        (glicemia != null && (glicemia! >= 300 || glicemia! < 60))) {
      return ManchesterPriority.orange;
    }
    if ((dor != null && dor! >= 4) ||
        (temperatura != null && temperatura! >= 37.8) ||
        (fc != null && (fc! > 110 || fc! < 50))) {
      return ManchesterPriority.yellow;
    }
    return ManchesterPriority.green;
  }
}
