import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/status_badge.dart';
import 'providers/relatorios_provider.dart';

/// Detalhe do relatório (REL-02) com exportação (REL-03).
class RelatorioDetalheScreen extends ConsumerWidget {
  const RelatorioDetalheScreen({super.key, required this.relatorioId});

  final String relatorioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final match = ref.watch(relatoriosProvider).where((r) => r.id == relatorioId);

    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relatório')),
        body: const EmptyView(message: 'Relatório não encontrado.'),
      );
    }
    final r = match.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório'),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: r.toPlainText()));
              _snack(context, 'Relatório copiado.');
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _snack(
                      context, 'CSV gerado (${r.toCsv().length} bytes) — download (demo).'),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Baixar CSV'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _snack(context, 'Enviado para impressão (demo).'),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              StatusBadge(
                label: r.type.label,
                color: r.type.color,
                background: r.type.background,
                icon: r.type.icon,
              ),
              const Spacer(),
              Text('${r.period} • ${Fmt.dayMonth(r.createdAt)}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(r.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          if (r.metrics.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final m in r.metrics) _MetricChip(label: m.label, value: m.value),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppCard(
            child: Text(r.body, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
