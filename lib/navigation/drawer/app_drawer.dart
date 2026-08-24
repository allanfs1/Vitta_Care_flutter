import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/module_registry.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_avatar.dart';
import '../../features/configuracoes/providers/configuracoes_provider.dart';
import '../nav_destinations.dart';

/// Drawer lateral global com atalhos para todos os módulos (NAV-02).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final clinic = ref.watch(selectedClinicProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Builder(builder: (context) {
                final logo = ref.watch(settingsProvider).logoBytes;
                if (logo != null) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Image.memory(logo, height: 160, fit: BoxFit.contain),
                  );
                }
                return Image.asset(
                  'assets/images/logo.png',
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: const Icon(Icons.favorite, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text('Vitta', style: theme.textTheme.headlineSmall),
                    ],
                  ),
                );
              }),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  AppAvatar(initials: user.initials, imageUrl: user.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: theme.textTheme.titleMedium),
                        Text(clinic.name, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(builder: (context) {
                final disabled = ref.watch(disabledModulesProvider);
                bool enabled(NavItem d) {
                  final id = ModuleRegistry.idForRoute(d.route);
                  return id == null || !disabled.contains(id);
                }

                final items = [...primaryDestinations, ...secondaryDestinations]
                    .where(enabled)
                    .toList();
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: [
                    for (final item in items)
                      _DrawerTile(item: item, location: location),
                  ],
                );
              }),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Sair'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.item, required this.location});

  final NavItem item;
  final String location;

  @override
  Widget build(BuildContext context) {
    final selected = location == item.route ||
        (item.route != '/home' && location.startsWith(item.route));
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.primaryLight,
      leading: Icon(selected ? item.selectedIcon : item.icon),
      title: Text(item.label),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      onTap: () {
        Navigator.of(context).pop();
        context.go(item.route);
      },
    );
  }
}
