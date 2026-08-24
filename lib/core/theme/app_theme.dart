import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/configuracoes/models/app_settings.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Tema global do Vitta App (claro e escuro), seguindo o Design System.
/// Pode ser construído estaticamente ([light]/[dark]) ou a partir das
/// preferências do usuário ([fromSettings]) — Módulo 9.
class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(
    TextTheme base,
    Color primary,
    Color secondary, {
    String fontFamily = 'Inter',
    double lineHeight = 1.5,
    bool bodyBold = false,
  }) {
    TextTheme themed;
    try {
      themed = GoogleFonts.getTextTheme(fontFamily, base);
    } catch (_) {
      themed = GoogleFonts.interTextTheme(base);
    }
    final bodyWeight = bodyBold ? FontWeight.w600 : FontWeight.w400;
    TextStyle? h(double size) => themed.titleLarge?.copyWith(
        fontSize: size, fontWeight: FontWeight.w700, color: primary, height: 1.2);
    return themed.copyWith(
      displaySmall: h(28)?.copyWith(letterSpacing: -0.5),
      headlineMedium: h(24)?.copyWith(letterSpacing: -0.5),
      headlineSmall: h(20),
      titleLarge: h(18),
      titleMedium: themed.titleMedium
          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: themed.bodyLarge
          ?.copyWith(fontSize: 15, color: primary, height: lineHeight, fontWeight: bodyWeight),
      bodyMedium: themed.bodyMedium?.copyWith(
          fontSize: 14, color: secondary, height: lineHeight, fontWeight: bodyWeight),
      bodySmall: themed.bodySmall?.copyWith(fontSize: 12, color: secondary, height: lineHeight),
      labelLarge: themed.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get light => fromSettings(const AppSettings(), Brightness.light);
  static ThemeData get dark => fromSettings(const AppSettings(), Brightness.dark);

  /// Constrói o tema aplicando as preferências do usuário (cor, fonte, cantos,
  /// contraste). [brightness] define claro/escuro.
  static ThemeData fromSettings(AppSettings s, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = s.primary;
    final accent = s.accent;

    final scaffold = isDark
        ? AppColors.backgroundDark
        : (s.backgroundColor == const AppSettings().backgroundColor
            ? AppColors.background
            : s.background);
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final surfaceAlt = isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt;

    // Contraste alto → bordas mais fortes e escuras.
    final baseBorder = isDark ? AppColors.borderDark : AppColors.border;
    final contrast = (s.contrastLevel.clamp(0, 1)) +
        (s.highContrast ? 0.6 : 0.0);
    final border = Color.lerp(baseBorder, textPrimary, contrast.clamp(0, 0.7)) ??
        baseBorder;
    final borderWidth = s.highContrast ? 1.6 : 1.0;

    final radius = s.borderRadius;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final textTheme = _textTheme(
      isDark ? Typography.whiteMountainView : Typography.blackMountainView,
      textPrimary,
      textSecondary,
      fontFamily: s.fontFamily,
      lineHeight: s.lineHeight,
      bodyBold: s.bodyBold,
    );

    OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius * 0.75),
          borderSide: BorderSide(color: c, width: w),
        );

    RoundedRectangleBorder rr([double? r]) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r ?? radius * 0.75));

    final pageTransitions = s.effectiveAnimations
        ? const PageTransitionsTheme()
        : const PageTransitionsTheme(builders: {
            TargetPlatform.android: _NoTransitionsBuilder(),
            TargetPlatform.iOS: _NoTransitionsBuilder(),
            TargetPlatform.windows: _NoTransitionsBuilder(),
            TargetPlatform.macOS: _NoTransitionsBuilder(),
            TargetPlatform.linux: _NoTransitionsBuilder(),
          });

    final visualDensity =
        s.largerTouchTargets ? VisualDensity.comfortable : VisualDensity.standard;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      dividerColor: border,
      visualDensity: visualDensity,
      pageTransitionsTheme: pageTransitions,
      dividerTheme: DividerThemeData(color: border, thickness: borderWidth, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: border, width: borderWidth),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        side: BorderSide.none,
        labelStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: ob(border, borderWidth),
        enabledBorder: ob(border, borderWidth),
        focusedBorder: ob(primary, 1.6),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
          shape: rr(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: rr(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: borderWidth),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          textStyle: textTheme.labelLarge,
          shape: rr(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: primary, textStyle: textTheme.labelLarge),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? primary : null),
        trackColor: WidgetStateProperty.resolveWith((st) =>
            st.contains(WidgetState.selected) ? primary.withValues(alpha: 0.4) : null),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
            textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : textSecondary)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle:
            textTheme.bodySmall?.copyWith(color: primary, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: textTheme.bodySmall,
        indicatorColor: primary.withValues(alpha: 0.14),
      ),
    );
  }
}

/// Transição de página "nenhuma" (para reduzir movimento — CFG-04d).
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
