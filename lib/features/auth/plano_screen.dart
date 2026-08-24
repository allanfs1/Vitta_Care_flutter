import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/plan.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../navigation/app_router.dart';

/// Tela de Assinatura: mostra o plano ativo e permite **mudar/atualizar** o plano.
class PlanoScreen extends ConsumerWidget {
  const PlanoScreen({super.key});

  static final _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$ ', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(activePlanProvider);
    final allPlans = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu plano')),
      body: ContentContainer(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SectionHeader(
              title: 'Plano atual',
              subtitle: 'Gerencie sua assinatura',
              icon: Icons.workspace_premium_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            if (plan == null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nenhum plano ativo', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Escolha um plano para liberar todos os recursos.',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () => context.go('${AppRoutes.choosePlan}?change=true'),
                      icon: const Icon(Icons.add),
                      label: const Text('Escolher plano'),
                    ),
                  ],
                ),
              )
            else
              _CurrentPlanCard(plan: plan, currency: _currency),
            const SizedBox(height: AppSpacing.md),

            // Botão de atualizar/mudar de plano (sempre disponível).
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.go('${AppRoutes.choosePlan}?change=true'),
                icon: const Icon(Icons.swap_horiz),
                label: Text(plan == null ? 'Escolher plano' : 'Atualizar plano'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Todos os planos disponíveis (o atual fica marcado).
            SectionHeader(
              title: 'Todos os planos',
              subtitle: '${allPlans.length} planos disponíveis',
            ),
            const SizedBox(height: AppSpacing.md),
            if (allPlans.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final p in allPlans)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PlanRow(
                    plan: p,
                    currency: _currency,
                    isCurrent: plan != null && p.id == plan.id,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.plan, required this.currency});
  final Plan plan;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final free = plan.monthlyPrice <= 0;
    return AppCard(
      color: AppColors.primaryLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Plano ${plan.name}',
                    style: theme.textTheme.titleLarge),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: const Text('Ativo',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(plan.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            free ? 'Gratuito' : '${currency.format(plan.monthlyPrice)}/mês',
            style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primary),
          ),
          const Divider(height: AppSpacing.xl),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.currency,
    this.isCurrent = false,
  });
  final Plan plan;
  final NumberFormat currency;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final free = plan.monthlyPrice <= 0;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: isCurrent ? AppColors.primaryLight : null,
      onTap: () => context.go('${AppRoutes.choosePlan}?change=true'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(plan.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (plan.isPopular && !isCurrent) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, size: 14, color: AppColors.warning),
                    ],
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: const Text('Atual',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                Text(plan.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(free ? 'Grátis' : '${currency.format(plan.monthlyPrice)}/mês',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.primary)),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
