import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../agent/agent_controller.dart';
import '../agent/agent_plans_service.dart';
import '../agent/ia_chats_service.dart';
import '../agent/ia_session.dart';

/// Sidebar esquerda da /ia: busca, nova conversa, histórico de conversas
/// (tb_ia_chats) e planos salvos (tb_agent_plans) — todos reais e clicáveis.
class AiDashboardLeftSidebar extends ConsumerWidget {
  const AiDashboardLeftSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(iaSearchProvider).toLowerCase();
    final chatsAsync = ref.watch(iaChatsProvider);
    final plansAsync = ref.watch(savedPlansProvider);

    return Container(
      width: 280,
      color: AppColors.backgroundOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              style: TextStyle(color: AppColors.textPrimaryOf(context)),
              onChanged: (v) =>
                  ref.read(iaSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
                prefixIcon: Icon(Icons.search,
                    color: AppColors.textSecondaryOf(context)),
                filled: true,
                fillColor: AppColors.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(agentChatProvider.notifier).newConversation();
                ref.read(iaViewProvider.notifier).state = IaView.chat;
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('NOVA CONVERSA',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pinkAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(context, 'CONVERSAS'),
                ...chatsAsync.when(
                  data: (chats) {
                    final list = chats
                        .where((c) => (c['titulo'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(query))
                        .toList();
                    if (list.isEmpty) {
                      return [_empty('Nenhuma conversa ainda')];
                    }
                    return list
                        .map((c) => _ConversaItem(chat: c))
                        .toList();
                  },
                  loading: () => [_empty('Carregando…')],
                  error: (_, _) =>[_empty('Erro ao carregar conversas')],
                ),
                const SizedBox(height: AppSpacing.lg),
                _header(context, 'PLANOS SALVOS',
                    icon: Icons.smart_toy_outlined),
                ...plansAsync.when(
                  data: (plans) {
                    final list = plans
                        .where((p) => (p['objetivo'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(query))
                        .toList();
                    if (list.isEmpty) {
                      return [_empty('Nenhum plano salvo')];
                    }
                    return list.map((p) => _PlanoItem(plan: p)).toList();
                  },
                  loading: () => [_empty('Carregando…')],
                  error: (_, _) =>[_empty('Erro ao carregar planos')],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title, {IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.textSecondaryOf(context), size: 16),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(title,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ],
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textTertiary, fontSize: 12)),
      );
}

String _fmtDate(Object? iso) {
  if (iso is! String) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

class _ConversaItem extends ConsumerWidget {
  const _ConversaItem({required this.chat});
  final Map<String, dynamic> chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(Icons.chat_bubble_outline,
          color: AppColors.textSecondaryOf(context), size: 20),
      title: Text(
        (chat['titulo'] ?? 'Conversa').toString(),
        style: TextStyle(color: AppColors.textPrimaryOf(context), fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_fmtDate(chat['updatedAt']),
          style: TextStyle(
              color: AppColors.textSecondaryOf(context), fontSize: 12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      onTap: () {
        ref
            .read(agentChatProvider.notifier)
            .loadConversation((chat['id'] ?? '').toString());
        ref.read(iaViewProvider.notifier).state = IaView.chat;
      },
    );
  }
}

class _PlanoItem extends StatelessWidget {
  const _PlanoItem({required this.plan});
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final objetivo = (plan['objetivo'] ?? 'Plano').toString();
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: ListTile(
        leading: const Icon(Icons.account_tree_outlined,
            color: AppColors.pinkAccent, size: 24),
        title: Text(objetivo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Text(_fmtDate(plan['createdAt']),
            style: TextStyle(
                color: AppColors.textSecondaryOf(context), fontSize: 12)),
        onTap: () => _showPlan(context, objetivo, plan),
      ),
    );
  }

  void _showPlan(BuildContext context, String titulo, Map<String, dynamic> p) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: Text(titulo,
            style: TextStyle(color: AppColors.textPrimaryOf(context))),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Text(
              (p['sintese'] ?? 'Sem síntese.').toString(),
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
