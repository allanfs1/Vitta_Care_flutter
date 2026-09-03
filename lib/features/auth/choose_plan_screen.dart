import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/plan.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../navigation/app_router.dart';

/// Tela de ESCOLHER PLANO (módulo auth). Mapeia `tb_plans`.
class ChoosePlanScreen extends ConsumerStatefulWidget {
  const ChoosePlanScreen({super.key});

  @override
  ConsumerState<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends ConsumerState<ChoosePlanScreen> {
  bool _yearly = false;
  String? _selectedId;
  String? _saving;

  static final _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$ ', decimalDigits: 0);

  bool get _isChange =>
      GoRouterState.of(context).uri.queryParameters['change'] == 'true';

  Future<void> _confirm(Plan plan) async {
    final isChange = _isChange;
    setState(() => _saving = plan.id);
    await ref.read(authProvider.notifier).choosePlan(plan.id);
    if (!mounted) return;
    if (isChange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plano atualizado para ${plan.name}.')),
      );
    }
    context.go(isChange ? AppRoutes.plano : AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plans = ref.watch(plansProvider);
    final wide = !Responsive.isMobile(context);
    final isChange = _isChange;
    final active = ref.watch(activePlanProvider);

    // No modo "trocar", parte do plano atual; senão, do popular.
    final defaultPlan = (isChange && active != null)
        ? active
        : plans.firstWhere(
            (p) => p.isPopular,
            orElse: () => plans.isNotEmpty ? plans.first : _placeholder,
          );
    final selectedId = _selectedId ?? defaultPlan.id;
    final selected = plans.firstWhere(
      (p) => p.id == selectedId,
      orElse: () => defaultPlan,
    );

    final maxDiscount = plans
        .map((p) => p.yearlyDiscountPercent)
        .fold<int>(0, (m, d) => d > m ? d : m);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _ConfirmBar(
        plan: selected,
        yearly: _yearly,
        saving: _saving == selected.id,
        priceLabel: _priceLabel(selected),
        confirmLabel: isChange ? 'Atualizar plano' : 'Continuar',
        onConfirm: plans.isEmpty ? null : () => _confirm(selected),
      ),
      body: SafeArea(
        bottom: false,
        child: plans.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      isChange: isChange,
                      onSkip: () => context.go(
                          isChange ? AppRoutes.plano : AppRoutes.home),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                          child: Column(
                            children: [
                              Text(
                                  isChange
                                      ? 'Escolha o novo plano da sua clínica'
                                      : 'Escolha o plano ideal para sua clínica',
                                  style: theme.textTheme.headlineMedium,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Comece agora. Troque ou cancele quando quiser.',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _BillingToggle(
                                yearly: _yearly,
                                savingsPercent: maxDiscount,
                                onChanged: (v) => setState(() => _yearly = v),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              if (wide)
                                Wrap(
                                  spacing: AppSpacing.md,
                                  runSpacing: AppSpacing.md,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (final p in plans)
                                      SizedBox(
                                        width: 320,
                                        child: _PlanCard(
                                          plan: p,
                                          yearly: _yearly,
                                          selected: p.id == selectedId,
                                          priceLabel: _priceLabel(p),
                                          billingNote: _billingNote(p),
                                          onTap: () => setState(() => _selectedId = p.id),
                                        ),
                                      ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    for (final p in plans)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: AppSpacing.md),
                                        child: _PlanCard(
                                          plan: p,
                                          yearly: _yearly,
                                          selected: p.id == selectedId,
                                          priceLabel: _priceLabel(p),
                                          billingNote: _billingNote(p),
                                          onTap: () =>
                                              setState(() => _selectedId = p.id),
                                        ),
                                      ),
                                  ],
                                ),
                              const SizedBox(height: AppSpacing.lg),
                              const _TrustRow(),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _priceLabel(Plan p) {
    if (p.monthlyPrice <= 0) return 'Gratuito';
    final perMonth = _yearly ? p.yearlyPrice / 12 : p.monthlyPrice;
    return _currency.format(perMonth);
  }

  String _billingNote(Plan p) {
    if (p.monthlyPrice <= 0) return 'Sem custo';
    if (_yearly) return 'cobrado ${_currency.format(p.yearlyPrice)}/ano';
    return 'por mês';
  }

  static const _placeholder = Plan(
    id: '_',
    name: '-',
    description: '',
    monthlyPrice: 0,
    yearlyPrice: 0,
    features: [],
  );
}

// ───────────────────────────── Header ─────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onSkip, this.isChange = false});
  final VoidCallback onSkip;
  final bool isChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(context.txt.t('auth.vitta'), style: theme.textTheme.titleLarge),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                child: Text(isChange ? 'Cancelar' : 'Pular por enquanto'),
              ),
            ],
          ),
          // Indicador de etapas só no onboarding (não ao trocar de plano).
          if (!isChange) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Step(label: 'Conta', done: true),
                _StepConnector(active: true),
                _Step(label: 'Plano', active: true),
                _StepConnector(active: false),
                _Step(label: 'Pronto'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, this.active = false, this.done = false});
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = (active || done) ? AppColors.primary : AppColors.textTertiary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: done ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Center(
                  child: Text(active ? '2' : '3',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            )),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
      color: active ? AppColors.primary : AppColors.border,
    );
  }
}

// ───────────────────────── Billing toggle ─────────────────────────

class _BillingToggle extends StatelessWidget {
  const _BillingToggle({
    required this.yearly,
    required this.onChanged,
    required this.savingsPercent,
  });

  final bool yearly;
  final ValueChanged<bool> onChanged;
  final int savingsPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(context, 'Mensal', !yearly, () => onChanged(false)),
          _seg(context, 'Anual', yearly, () => onChanged(true),
              badge: savingsPercent > 0 ? '-$savingsPercent%' : null),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String label, bool active, VoidCallback onTap,
      {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                )),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────  Plan card ──────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.yearly,
    required this.selected,
    required this.priceLabel,
    required this.billingNote,
    required this.onTap,
  });

  final Plan plan;
  final bool yearly;
  final bool selected;
  final String priceLabel;
  final String billingNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final popular = plan.isPopular;
    final free = plan.monthlyPrice <= 0;
    final borderColor = selected
        ? AppColors.primary
        : popular
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.border;
    final bgColor = selected 
        ? AppColors.primary.withValues(alpha: 0.03) 
        : AppColors.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        // ignore: deprecated_member_use
        ..scale(selected ? 1.02 : 1.0)
        // ignore: deprecated_member_use
        ..translate(0.0, selected ? -4.0 : 0.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: borderColor, width: selected ? 2.5 : 1),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(plan.description,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (popular)
                      _Pill(
                        text: 'MAIS POPULAR',
                        bg: AppColors.primary,
                        fg: Colors.white,
                        icon: Icons.star,
                      )
                    else if (free)
                      _Pill(
                        text: 'GRATUITO',
                        bg: AppColors.secondaryLight,
                        fg: AppColors.secondary,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // Preço
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(priceLabel,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        )),
                    if (!free) ...[
                      const SizedBox(width: 4),
                      Text('/mês', 
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                    ],
                  ],
                ),
                Text(billingNote, 
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  )),
                const Divider(height: AppSpacing.xxl),
                // Limites principais
                _MetaRow(
                  icon: Icons.group_outlined,
                  label: plan.userLimit == null
                      ? 'Usuários ilimitados'
                      : 'Até ${plan.userLimit} usuários',
                ),
                _MetaRow(
                  icon: Icons.event_available_outlined,
                  label: plan.appointmentLimit == null
                      ? 'Agendamentos ilimitados'
                      : '${plan.appointmentLimit} / mês',
                ),
                _MetaRow(
                  icon: Icons.support_agent_outlined,
                  label: 'Suporte ${plan.supportLevel}',
                ),
                const SizedBox(height: AppSpacing.md),
                // Recursos
                for (final f in plan.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 18, color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                            child:
                                Text(f, style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.3,
                                ))),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                // Radio button substituto
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg, this.icon});
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ─────────────────────── Confirm bar / trust ──────────────────────

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.plan,
    required this.yearly,
    required this.saving,
    required this.priceLabel,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final Plan plan;
  final bool yearly;
  final bool saving;
  final String priceLabel;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final free = plan.monthlyPrice <= 0;
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plano ${plan.name}',
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          free
                              ? 'Sem custo'
                              : '$priceLabel/mês • ${yearly ? 'cobrança anual' : 'cobrança mensal'}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : onConfirm,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.arrow_forward),
                      label: Text(saving ? 'Salvando...' : confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const items = [
      (Icons.credit_card_off, 'Sem cartão para começar'),
      (Icons.lock_outline, 'Dados seguros'),
      (Icons.autorenew, 'Cancele quando quiser'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (icon, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
