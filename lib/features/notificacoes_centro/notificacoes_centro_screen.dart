import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import 'notificacoes_provider.dart';

/// Central de Notificações (NOT-01..NOT-04).
class NotificacoesCentroScreen extends ConsumerWidget {
  const NotificacoesCentroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(notificacoesProvider);
    final unread = ref.watch(unreadCountProvider);
    final filter = ref.watch(notifFilterProvider);

    final filtered = all.where((n) {
      if (filter == 'all') return true;
      if (filter == 'unread') return !n.read;
      return n.type.name == filter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            onPressed: unread == 0
                ? null
                : () => ref.read(notificacoesProvider.notifier).markAllRead(),
            child: const Text('Marcar todas'),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(selected: filter, unread: unread),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyView(
                    icon: Icons.notifications_off_outlined,
                    message: 'Nenhuma notificação por aqui.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) =>
                        _NotificationTile(item: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected, required this.unread});
  final String selected;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <(String, String)>[
      ('all', 'Todas'),
      ('unread', 'Não lidas${unread > 0 ? ' ($unread)' : ''}'),
      for (final t in NotificationType.values) (t.name, t.label),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final (value, label) = chips[i];
          return Align(
            alignment: Alignment.center,
            child: FilterChip(
              label: Text(label),
              selected: selected == value,
              onSelected: (_) =>
                  ref.read(notifFilterProvider.notifier).state = value,
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: const Icon(Icons.done_all, color: AppColors.success),
      ),
      onDismissed: (_) =>
          ref.read(notificacoesProvider.notifier).remove(item.id),
      child: AppCard(
        color: item.read ? null : AppColors.infoLight,
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => ref
            .read(notificacoesProvider.notifier)
            .markRead(item.id, read: !item.read),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: item.type.background,
              child: Icon(item.type.icon, color: item.type.color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(item.message, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_relative(item.time), style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                if (!item.read)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} d';
  }
}
