import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistente/assistant_anchors.dart';
import '../../features/assistente/assistant_tours.dart';
import '../../features/configuracoes/providers/configuracoes_provider.dart';
import '../../features/notificacoes_centro/notificacoes_provider.dart';
import '../../navigation/app_router.dart';
import '../models/clinic.dart';
import '../services/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive.dart';
import 'app_avatar.dart';
import 'command_palette.dart';

/// Cabeçalho de tela no estilo dos mockups: avatar + nome da clínica + busca.
/// No mobile, o avatar abre o Drawer (NAV-02). H-01: toque na clínica troca a unidade.
class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, this.showClinicSwitcher = true, this.title, this.trailing});

  final bool showClinicSwitcher;
  final String? title;
  /// Widget opcional exibido após o botão de busca (ex: botão de editar layout).
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final clinic = ref.watch(selectedClinicProvider);
    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (isMobile)
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: AppAvatar(initials: user.initials, imageUrl: user.photoUrl),
            )
          else
            _AccountMenu(
              child: AppAvatar(initials: user.initials, imageUrl: user.photoUrl),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: AssistantTarget(
              anchorId: HelpAnchors.clinicSwitcher,
              child: InkWell(
              onTap: showClinicSwitcher
                  ? () => showClinicSelector(context, ref)
                  : null,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Row(
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? clinic.name,
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (title == null)
                          Text(user.fullName, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (showClinicSwitcher)
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
            ),
          ),
          const _NotificationBell(),
          const _ThemeModeToggle(),
          _SearchButton(
            onTap: () => showCommandPalette(context),
            isMobile: isMobile,
          ),
          ?trailing,
          const _LogoutButton(),
        ],
      ),
    );
  }
}

/// Botão de logout sempre visível no cabeçalho (em toda a aplicação).
class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sair',
      icon: const Icon(Icons.logout, color: AppColors.danger),
      onPressed: () => confirmLogout(context, ref),
    );
  }
}

/// Diálogo de confirmação + logout. O router redireciona para o login.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sair da conta'),
      content: const Text('Deseja encerrar a sessão?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(authProvider.notifier).logout();
  }
}

/// Menu de conta (desktop): nome/e-mail + Configurações + **Sair**.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final email = ref.watch(authProvider).email ?? user.email ?? '';
    return PopupMenuButton<String>(
      tooltip: 'Conta',
      offset: const Offset(0, 52),
      onSelected: (v) {
        switch (v) {
          case 'config':
            context.go(AppRoutes.configuracoes);
          case 'plano':
            context.go(AppRoutes.plano);
          case 'logout':
            ref.read(authProvider.notifier).logout();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.fullName,
                  style: Theme.of(ctx).textTheme.titleMedium),
              if (email.isNotEmpty)
                Text(email, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'plano',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.workspace_premium_outlined),
            title: Text('Meu plano'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'config',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Configurações'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, color: AppColors.danger),
            title: Text('Sair', style: TextStyle(color: AppColors.danger)),
          ),
        ),
      ],
      child: child,
    );
  }
}

/// Sino de notificações com badge de não lidas (Central de Notificações).
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: 'Notificações',
      onPressed: () => context.go(AppRoutes.notificacoes),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

/// Toggle rápido de tema claro/escuro no cabeçalho.
class _ThemeModeToggle extends ConsumerWidget {
  const _ThemeModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Modo claro' : 'Modo escuro',
      onPressed: () {
        final ctrl = ref.read(settingsProvider.notifier);
        ctrl.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween(begin: 0.75, end: 1.0).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(isDark),
        ),
      ),
    );
  }
}

/// Modal de seleção de clínica (H-01) com persistência via provider.
Future<void> showClinicSelector(BuildContext context, WidgetRef ref) {
  final allClinics = ref.read(clinicsProvider);
  final selectedId = ref.read(selectedClinicIdProvider);
  final user = ref.read(currentUserProvider);
  
  // Filtra as clínicas que pertencem ao usuário atual
  final clinics = user.clinicIds.isNotEmpty 
      ? allClinics.where((c) => user.clinicIds.contains(c.id)).toList()
      : allClinics;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.6,
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                'Selecionar unidade',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                children: [
                  for (final Clinic c in clinics)
                    ListTile(
                leading: CircleAvatar(
                  backgroundColor: c.type.color.withValues(alpha: 0.15),
                  child: Text(
                    c.type.label,
                    style: TextStyle(
                      color: c.type.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                title: Text(c.name),
                subtitle: Text(c.type.description),
                trailing: c.id == selectedId
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  ref.read(selectedClinicIdProvider.notifier).select(c.id);
                  Navigator.of(context).pop();
                },
              ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Botão de busca com indicador de atalho (Ctrl+K).
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap, required this.isMobile});
  final VoidCallback onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceAlt = isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final textColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;

    if (isMobile) {
      return IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.search),
        tooltip: 'Buscar (Ctrl+K)',
      );
    }
    return Tooltip(
      message: 'Busca avançada (Ctrl+K)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceAlt,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Buscar…',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '⌘K',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
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
