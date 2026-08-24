import 'package:flutter/material.dart';

/// Design tokens de cor do Vitta App.
///
/// Paleta extraída dos mockups em `.specify/Designer/`: tema claro,
/// azul médico royal como cor primária, crimson para alertas/absenteísmo,
/// teal/verde para indicadores positivos e âmbar para estados pendentes.
class AppColors {
  AppColors._();

  // Marca
  static const Color primary = Color(0xFF1B53D0);
  static const Color primaryDark = Color(0xFF143FA0);
  static const Color primaryLight = Color(0xFFE7EEFC);

  // Rosa Accent (Dashboard IA)
  static const Color pinkAccent = Color(0xFFF43F5E);
  static const Color pinkAccentLight = Color(0xFFFDE8EC);

  static const Color secondary = Color(0xFF2E9E8F); // teal saúde
  static const Color secondaryLight = Color(0xFFE0F2EF);

  // Superfícies (tema claro)
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEEF1F6);
  static const Color border = Color(0xFFE2E6EE);

  // Texto
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9AA1AD);

  // Superfícies (tema escuro)
  static const Color backgroundDark = Color(0xFF0F1320);
  static const Color surfaceDark = Color(0xFF1A1F2E);
  static const Color surfaceAltDark = Color(0xFF232938);
  static const Color borderDark = Color(0xFF2D3446);
  static const Color textPrimaryDark = Color(0xFFF2F4F8);
  static const Color textSecondaryDark = Color(0xFFA0A8B8);

  // ── Tokens sensíveis ao tema ────────────────────────────────────────────
  // Resolvem para a paleta clara ou escura conforme o brilho do [Theme]
  // ambiente. Usados em telas (como a /ia) que precisam acompanhar a troca
  // claro/escuro em vez de fixar a paleta escura.
  static bool _isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext c) =>
      _isDark(c) ? backgroundDark : background;
  static Color surfaceOf(BuildContext c) => _isDark(c) ? surfaceDark : surface;
  static Color surfaceAltOf(BuildContext c) =>
      _isDark(c) ? surfaceAltDark : surfaceAlt;
  static Color borderOf(BuildContext c) => _isDark(c) ? borderDark : border;
  static Color textPrimaryOf(BuildContext c) =>
      _isDark(c) ? textPrimaryDark : textPrimary;
  static Color textSecondaryOf(BuildContext c) =>
      _isDark(c) ? textSecondaryDark : textSecondary;

  // Estados / status
  static const Color success = Color(0xFF2EA043); // confirmado
  static const Color successLight = Color(0xFFE3F4E7);
  static const Color danger = Color(0xFFC62828); // cancelado / risco alto
  static const Color dangerLight = Color(0xFFFBE6E6);
  static const Color warning = Color(0xFFC77700); // pré-agendado / pendente
  static const Color warningLight = Color(0xFFFBF0DC);
  static const Color info = Color(0xFF1B53D0);
  static const Color infoLight = Color(0xFFE7EEFC);

  // Tipos de unidade de saúde
  static const Color ubs = Color(0xFF1B53D0);
  static const Color upa = Color(0xFFC62828);
  static const Color aps = Color(0xFF2E9E8F);
  static const Color privada = Color(0xFF7C3AED);

  // Gráficos
  static const List<Color> chartPalette = [
    Color(0xFF1B53D0),
    Color(0xFF2E9E8F),
    Color(0xFFC77700),
    Color(0xFFC62828),
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
  ];
}
