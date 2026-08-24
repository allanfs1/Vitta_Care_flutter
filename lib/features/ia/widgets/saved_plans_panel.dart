import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../agent/agent_plans_service.dart';

/// Painel lateral que lista os planos multi-agente salvos e os relatórios de
/// IA da clínica ativa. Segue o tema escuro do dashboard de IA.
class SavedPlansPanel extends ConsumerWidget {
  const SavedPlansPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(savedPlansProvider);
    final reportsAsync = ref.watch(savedReportsProvider);

    return Container(
      color: AppColors.backgroundOf(context),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SectionHeader(title: 'Planos salvos', icon: Icons.account_tree_outlined),
          const SizedBox(height: AppSpacing.sm),
          plansAsync.when(
            data: (plans) => plans.isEmpty
                ? _EmptyState(label: 'Nenhum plano salvo ainda.')
                : Column(
                    children: [
                      for (final plan in plans) _PlanCard(item: plan),
                    ],
                  ),
            loading: () => const _LoadingState(),
            error: (e, _) => _ErrorState(message: e.toString()),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(title: 'Relatórios', icon: Icons.summarize_outlined),
          const SizedBox(height: AppSpacing.sm),
          reportsAsync.when(
            data: (reports) => reports.isEmpty
                ? _EmptyState(label: 'Nenhum relatório salvo ainda.')
                : Column(
                    children: [
                      for (final report in reports) _ReportCard(item: report),
                    ],
                  ),
            loading: () => const _LoadingState(),
            error: (e, _) => _ErrorState(message: e.toString()),
          ),
        ],
      ),
    );
  }
}

// ── Widgets internos ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimaryOf(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondaryOf(context),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        'Erro: $message',
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Card expansível para um plano salvo.
class _PlanCard extends StatefulWidget {
  const _PlanCard({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final objetivo = widget.item['objetivo'] as String? ?? '(sem objetivo)';
    final sintese = widget.item['sintese'] as String? ?? '';
    final createdAt = widget.item['createdAt'] as String? ?? '';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree, size: 14, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      objetivo,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ],
              ),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 10,
                  ),
                ),
              ],
              if (_expanded && sintese.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(color: AppColors.borderOf(context), height: 1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  sintese,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card expansível para um relatório de IA.
class _ReportCard extends StatefulWidget {
  const _ReportCard({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final titulo = widget.item['titulo'] as String? ?? '(sem titulo)';
    final markdown = widget.item['markdown'] as String? ?? '';
    final createdAt = widget.item['createdAt'] as String? ?? '';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.summarize, size: 14, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: _expanded ? null : 1,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ],
              ),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 10,
                  ),
                ),
              ],
              if (_expanded && markdown.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(color: AppColors.borderOf(context), height: 1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  markdown,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}
