import 'dart:async';

import 'package:flutter/material.dart';

import '../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/modules/module_registry.dart';
import '../core/services/app_providers.dart';
import '../features/assistente/assistant_anchors.dart';
import '../features/assistente/assistant_tours.dart';
import 'app_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/command_palette.dart';
import '../features/configuracoes/providers/configuracoes_provider.dart';
import '../features/ia/vigia/vigia_providers.dart';
import 'drawer/app_drawer.dart';
import 'nav_destinations.dart';

/// Casca de navegação responsiva (NAV-02/03).
///
/// - **Mobile** (visual de aplicativo): NavigationBar inferior + Drawer.
/// - **Desktop / Web PWA** (visual de aplicação): NavigationRail lateral.
///
/// Destinos de módulos desabilitados na tela de Arquitetura são ocultados.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Barra lateral recolhida (somente ícones), alternada pelo botão de menu.
  bool _collapsed = false;

  /// Agenda o ciclo diário do Vigia. Vive aqui, e não no provider, porque um
  /// `State` tem `dispose` garantido pelo Flutter — um Timer criado dentro de
  /// um provider sobrevive ao fim da árvore de widgets.
  Timer? _vigia;

  @override
  void initState() {
    super.initState();
    _vigia = Timer(VigiaController.atrasoBoot, () {
      if (!mounted) return;
      final c = ref.read(vigiaControllerProvider.notifier);
      if (c.podeRodar) c.rodar();
    });
  }

  @override
  void dispose() {
    _vigia?.cancel();
    super.dispose();
  }

  bool _matches(NavItem d) =>
      widget.location == d.route ||
      (d.route != '/home' && widget.location.startsWith(d.route));

  /// Envolve o ícone de um item de menu com uma âncora de spotlight, para o
  /// assistente de ajuda poder destacá-lo.
  Widget _anchoredIcon(String route, Widget icon) {
    final id = _anchorForRoute(route);
    return id == null ? icon : AssistantTarget(anchorId: id, child: icon);
  }

  String? _anchorForRoute(String route) {
    switch (route) {
      case AppRoutes.home:
        return HelpAnchors.navHome;
      case AppRoutes.agendamentos:
        return HelpAnchors.navAgenda;
      case AppRoutes.totem:
        return HelpAnchors.navTotem;
      case AppRoutes.configuracoes:
        return HelpAnchors.navConfig;
      case AppRoutes.arquitetura:
        return HelpAnchors.navArquitetura;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = ref.watch(disabledModulesProvider);
    bool enabled(NavItem d) {
      final id = ModuleRegistry.idForRoute(d.route);
      return id == null || !disabled.contains(id);
    }

    final primary = primaryDestinations.where(enabled).toList();
    final secondary = secondaryDestinations.where(enabled).toList();
    final isPrimaryRoute = primary.any(_matches);

    if (Responsive.isMobile(context)) {
      final index = primary.indexWhere(_matches);
      return CommandPaletteShortcut(
        child: Scaffold(
          drawer: AppDrawer(location: widget.location),
          body: SafeArea(bottom: false, child: widget.child),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (i) => context.go(primary[i].route),
            destinations: [
              for (final d in primary)
                NavigationDestination(
                  icon: _anchoredIcon(d.route, Icon(d.icon)),
                  selectedIcon: _anchoredIcon(d.route, Icon(d.selectedIcon)),
                  label: d.texto(context.txt),
                ),
            ],
          ),
        ),
      );
    }

    // Desktop / Web — NavigationRail com os destinos habilitados.
    final allDestinations = [...primary, ...secondary];
    final railIndex = allDestinations.indexWhere(_matches);
    // Recolhível: no desktop segue a preferência do botão de menu; em telas
    // menores permanece sempre recolhido (só ícones).
    final extended = Responsive.isDesktop(context) && !_collapsed;

    return CommandPaletteShortcut(
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height - 24,
                  ),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      extended: extended,
                      minExtendedWidth: 280,
                      selectedIndex: railIndex < 0 ? 0 : railIndex,
                      onDestinationSelected: (i) =>
                          context.go(allDestinations[i].route),
                      leading: SizedBox(
                        width: extended ? 280 : 72,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (Responsive.isDesktop(context))
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: extended ? 16 : 8,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: extended
                                      ? MainAxisAlignment.spaceBetween
                                      : MainAxisAlignment.center,
                                  children: [
                                    if (extended)
                                      Expanded(
                                        child: Builder(builder: (context) {
                                          final logo = ref.watch(settingsProvider).logoBytes;
                                          if (logo != null) {
                                            return Image.memory(
                                              logo,
                                              height: 52,
                                              fit: BoxFit.contain,
                                              alignment: Alignment.centerLeft,
                                            );
                                          }
                                          return Image.asset(
                                            'assets/images/logo.png',
                                            height: 52,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.centerLeft,
                                            errorBuilder: (context, error, stack) => Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                                  ),
                                                  child: const Icon(Icons.favorite, color: Colors.white, size: 22),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Vitta Care',
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAltOf(context).withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        iconSize: 20,
                                        tooltip: _collapsed ? 'Expandir menu' : 'Recolher menu',
                                        icon: Icon(_collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
                                        onPressed: () => setState(() => _collapsed = !_collapsed),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!extended)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 12),
                                child: Center(
                                  child: Builder(builder: (context) {
                                    final logo = ref.watch(settingsProvider).logoBytes;
                                    if (logo != null) {
                                      return Image.memory(logo, height: 38, width: 38, fit: BoxFit.contain);
                                    }
                                    return Image.asset(
                                      'assets/images/logo.png',
                                      height: 38,
                                      width: 38,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stack) => Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                        ),
                                        child: const Icon(Icons.favorite, color: Colors.white, size: 18),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                      destinations: [
                        for (final d in allDestinations)
                          NavigationRailDestination(
                            icon: _anchoredIcon(d.route, Icon(d.icon)),
                            selectedIcon: _anchoredIcon(d.route, Icon(d.selectedIcon)),
                            label: Text(d.texto(context.txt)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ContentContainer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(isPrimaryRoute ? widget.location : 'sub'),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
