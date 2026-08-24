import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Helpers de responsividade para o app multiplataforma (mobile + desktop/web PWA).
class Responsive {
  Responsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppSpacing.mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= AppSpacing.mobileBreakpoint && w < AppSpacing.desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppSpacing.desktopBreakpoint;

  /// Número de colunas sugerido para grids responsivos.
  static int gridColumns(BuildContext context, {int max = 4}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) return max;
    if (w >= 800) return (max - 1).clamp(2, max);
    if (w >= 560) return 2;
    return 1;
  }

  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}

/// Centraliza e limita a largura do conteúdo em telas largas.
class ContentContainer extends StatelessWidget {
  const ContentContainer({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppSpacing.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
