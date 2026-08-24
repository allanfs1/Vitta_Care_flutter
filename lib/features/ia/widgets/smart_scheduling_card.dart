import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

/// IA-01 — Agendamento inteligente. Recurso **B2B** disponível apenas para
/// clínicas privadas; demais tipos veem o recurso bloqueado.
class SmartSchedulingCard extends ConsumerStatefulWidget {
  const SmartSchedulingCard({super.key, required this.isB2B});

  final bool isB2B;

  @override
  ConsumerState<SmartSchedulingCard> createState() =>
      _SmartSchedulingCardState();
}

class _SmartSchedulingCardState extends ConsumerState<SmartSchedulingCard> {
  bool _loading = false;
  List<String>? _slots;

  Future<void> _suggest() async {
    setState(() => _loading = true);
    final slots =
        await ref.read(aiServiceProvider).suggestSlots(specialty: 'Cardiologia');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _slots = slots;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.privada.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.privada),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agendamento inteligente',
                        style: theme.textTheme.titleMedium),
                    Text('Sugere horários otimizados (B2B)',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isB2B
                      ? AppColors.successLight
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  widget.isB2B ? 'Ativo' : 'Premium',
                  style: TextStyle(
                    color: widget.isB2B
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!widget.isB2B)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline, color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recurso exclusivo para Clínicas Privadas. '
                      'Selecione uma unidade privada para habilitar.',
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_slots != null)
              for (final s in _slots!)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _suggest,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Sugerir horários'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
