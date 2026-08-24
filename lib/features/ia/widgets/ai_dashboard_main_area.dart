import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../agent/agent_controller.dart';
import '../agent/chat_interface.dart';
import '../agent/ia_alerts_provider.dart';
import '../agent/ia_session.dart';
import 'ai_agents_panel.dart';
import 'ai_chat_panel.dart';

/// Área principal da /ia — barra superior (modo, clínica, sessão), barra de
/// alertas em tempo real e o conteúdo (Chat ou Agentes).
class AiDashboardMainArea extends ConsumerWidget {
  const AiDashboardMainArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(iaViewProvider);
    return Expanded(
      child: Container(
        color: AppColors.backgroundOf(context).withValues(alpha: 0.9),
        child: Column(
          children: [
            _TopBar(view: view),
            Divider(height: 1, color: AppColors.borderOf(context)),
            const _AlertasBar(),
            Divider(height: 1, color: AppColors.borderOf(context)),
            Expanded(
              child: view == IaView.chat
                  ? const AiChatPanel()
                  : const AiAgentsPanel(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.view});
  final IaView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinic = ref.watch(selectedClinicProvider);
    final user = ref.watch(currentUserProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (ctx) => IconButton(
                icon:
                    Icon(Icons.menu, color: AppColors.textSecondaryOf(context)),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            onTap: () {
              if (isDesktop) {
                ref.read(iaLeftSidebarExpandedProvider.notifier).update((s) => !s);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dashboard, color: AppColors.pinkAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          clinic.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        Text(
                          user.email ?? '${user.firstName} ${user.lastName}'.trim(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                _toggle(context, ref, 'CHAT', IaView.chat, view),
                _toggle(context, ref, 'AGENTES', IaView.agentes, view),
              ],
            ),
          ),
          if (view == IaView.chat) ...[
            const SizedBox(width: AppSpacing.sm),
            const _InterfacePicker(),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Colors.tealAccent, size: 16),
                const SizedBox(width: 4),
                Text('PROTEGIDA',
                    style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Configurações',
            icon: Icon(Icons.settings_outlined,
                color: AppColors.textSecondaryOf(context)),
            onPressed: () => context.go('/configuracoes'),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: Icon(Icons.logout, color: AppColors.textSecondaryOf(context)),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: Text('Sair da conta',
            style: TextStyle(color: AppColors.textPrimaryOf(context))),
        content: Text('Deseja encerrar a sessão?',
            style: TextStyle(color: AppColors.textSecondaryOf(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.pinkAccent),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Limpa a conversa atual e encerra a sessão; o router redireciona p/ login.
      ref.read(agentChatProvider.notifier).newConversation();
      await ref.read(authProvider.notifier).logout();
    }
  }

  Widget _toggle(BuildContext context, WidgetRef ref, String text,
      IaView target, IaView current) {
    final isSelected = current == target;
    final isChat = target == IaView.chat;
    final activeColor = isChat ? AppColors.pinkAccent : const Color(0xFFC084FC);
    return GestureDetector(
      onTap: () => ref.read(iaViewProvider.notifier).state = target,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            if (!isChat) ...[
              Icon(Icons.smart_toy_outlined,
                  color:
                      isSelected ? Colors.white : AppColors.textSecondaryOf(context),
                  size: 16),
              const SizedBox(width: 4),
            ],
            Text(text,
                style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Seletor da interface gráfica do chat (por perfil). "Automático" usa a
/// interface padrão da role do usuário; uma escolha manual sobrepõe e persiste.
class _InterfacePicker extends ConsumerWidget {
  const _InterfacePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(effectiveChatInterfaceProvider);
    final isAuto = ref.watch(chatInterfaceIsAutoProvider);
    final style = chatStyleOf(current);
    final notifier = ref.read(chatInterfaceProvider.notifier);

    return PopupMenuButton<ChatInterface?>(
      tooltip: 'Interface do chat',
      position: PopupMenuPosition.under,
      color: AppColors.surfaceOf(context),
      onSelected: (v) =>
          v == null ? notifier.setAuto() : notifier.select(v),
      itemBuilder: (context) => [
        CheckedPopupMenuItem<ChatInterface?>(
          value: null,
          checked: isAuto,
          child: Text('Automático (perfil)',
              style: TextStyle(color: AppColors.textPrimaryOf(context))),
        ),
        const PopupMenuDivider(),
        for (final s in chatInterfaceStyles.values)
          CheckedPopupMenuItem<ChatInterface?>(
            value: s.id,
            checked: !isAuto && s.id == current,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(s.icon, size: 16, color: s.accent),
                    const SizedBox(width: 6),
                    Text(s.label,
                        style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 22, top: 2),
                  child: SizedBox(
                    width: 230,
                    child: Text(s.description,
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 16, color: style.accent),
            const SizedBox(width: 6),
            Text(style.label,
                style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            if (isAuto) ...[
              const SizedBox(width: 4),
              Text('• auto',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(context), fontSize: 11)),
            ],
            Icon(Icons.arrow_drop_down,
                size: 18, color: AppColors.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }
}

class _AlertasBar extends ConsumerWidget {
  const _AlertasBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(iaAlertsProvider);
    final alerts = alertsAsync.value ?? const [];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined,
                color: Colors.orangeAccent, size: 18),
            const SizedBox(width: AppSpacing.sm),
            const Text('ALERTAS',
                style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(width: AppSpacing.lg),
            if (alerts.isEmpty)
              Text(
                alertsAsync.isLoading ? 'Verificando…' : 'Sem alertas',
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 12),
              ),
            for (final a in alerts) ...[
              _AlertChip(alert: a),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends ConsumerWidget {
  const _AlertChip({required this.alert});
  final IaAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = alert.severity == AlertSeverity.critical
        ? AppColors.pinkAccent
        : Colors.orangeAccent;
    final icon =
        alert.icon == 'mail' ? Icons.mail_outline : Icons.calendar_today;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: () {
        ref.read(iaViewProvider.notifier).state = IaView.chat;
        ref.read(agentChatProvider.notifier).send(alert.prompt);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(alert.label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
