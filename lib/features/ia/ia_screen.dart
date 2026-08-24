import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/configuracoes/providers/configuracoes_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/ai_dashboard_left_sidebar.dart';
import 'widgets/ai_dashboard_right_sidebar.dart';
import 'widgets/ai_dashboard_main_area.dart';
import 'agent/ia_session.dart';

class IaScreen extends ConsumerWidget {
  const IaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine if we should show the sidebars based on screen width
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 768 && !isDesktop;
    
    final settings = ref.watch(settingsProvider);

    // Build a proper dark theme that overrides input decoration to avoid
    // theme InputDecorationTheme (filled:true, OutlineInputBorder) leaking
    // into the custom-styled TextFields of the IA dashboard.
    final effectiveBrightness = settings.themeMode == ThemeMode.light 
        ? Brightness.light 
        : Brightness.dark;

    final baseTheme = AppTheme.fromSettings(settings, effectiveBrightness);
    
    final iaTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: baseTheme.scaffoldBackgroundColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseTheme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.pinkAccent, width: 1.5),
        ),
        hintStyle: TextStyle(color: baseTheme.colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: baseTheme.colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    final showLeftSidebar = ref.watch(iaLeftSidebarExpandedProvider);

    return Theme(
      data: iaTheme,
      child: Scaffold(
        backgroundColor: iaTheme.scaffoldBackgroundColor,
        drawer: !isDesktop ? const Drawer(child: AiDashboardLeftSidebar()) : null,
        endDrawer: (!isDesktop && !isTablet) ? const Drawer(child: AiDashboardRightSidebar()) : null,
        body: SafeArea(
          child: Row(
            children: [
              if (isDesktop && showLeftSidebar) const AiDashboardLeftSidebar(),
              if (isDesktop && showLeftSidebar) VerticalDivider(width: 1, thickness: 1, color: iaTheme.dividerColor),
              
              const AiDashboardMainArea(),
              
              if (isDesktop || isTablet) VerticalDivider(width: 1, thickness: 1, color: iaTheme.dividerColor),
              if (isDesktop || isTablet) const AiDashboardRightSidebar(),
            ],
          ),
        ),
      ),
    );
  }
}
