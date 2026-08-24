import 'package:flutter/widgets.dart';

/// Espaçamentos e raios padronizados do Design System.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Raios de borda — cards usam 16px (mockups).
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  static const EdgeInsets pageInsets = EdgeInsets.all(lg);
  static const EdgeInsets cardInsets = EdgeInsets.all(lg);

  /// Largura de breakpoint para alternar entre layout mobile e desktop/web.
  static const double mobileBreakpoint = 720;
  static const double desktopBreakpoint = 1100;

  /// Largura máxima do conteúdo central em telas largas.
  static const double maxContentWidth = 1180;
}
