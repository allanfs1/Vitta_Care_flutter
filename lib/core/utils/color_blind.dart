import '../../features/configuracoes/models/app_settings.dart';

/// Matrizes de simulação de daltonismo (CFG-04e) para `ColorFilter.matrix`.
/// Cada matriz tem 20 valores (4×5). Retorna `null` quando não há filtro.
List<double>? colorBlindMatrix(ColorBlindFilter filter) {
  switch (filter) {
    case ColorBlindFilter.protanopia:
      return const [
        0.567, 0.433, 0.000, 0, 0,
        0.558, 0.442, 0.000, 0, 0,
        0.000, 0.242, 0.758, 0, 0,
        0.000, 0.000, 0.000, 1, 0,
      ];
    case ColorBlindFilter.deuteranopia:
      return const [
        0.625, 0.375, 0.000, 0, 0,
        0.700, 0.300, 0.000, 0, 0,
        0.000, 0.300, 0.700, 0, 0,
        0.000, 0.000, 0.000, 1, 0,
      ];
    case ColorBlindFilter.tritanopia:
      return const [
        0.950, 0.050, 0.000, 0, 0,
        0.000, 0.433, 0.567, 0, 0,
        0.000, 0.475, 0.525, 0, 0,
        0.000, 0.000, 0.000, 1, 0,
      ];
    case ColorBlindFilter.none:
      return null;
  }
}
