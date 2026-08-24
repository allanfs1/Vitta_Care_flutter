import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../models/care_line.dart';
import '../../models/manchester_priority.dart';
import '../../models/queue_entry.dart';
import '../../recepcao_provider.dart';
import '../fullscreen_helper.dart';

class IndicadoresTab extends StatelessWidget {
  const IndicadoresTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpandTabBar(
          onExpand: () => showRecepcaoFullscreen(
              context, 'Indicadores', const IndicadoresBoard()),
        ),
        const Expanded(child: IndicadoresBoard()),
      ],
    );
  }
}

/// Painel de indicadores operacionais da recepção (UBS/UPA/APS).
class IndicadoresBoard extends ConsumerWidget {
  const IndicadoresBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recepcaoProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final waiting = state.waiting;
    final inService = state.inService;
    final breaches = waiting.where((e) => e.slaBreached(now)).length;
    final avgWait = waiting.isEmpty
        ? 0
        : (waiting
                    .map((e) => e.waitedFrom(now).inMinutes)
                    .reduce((a, b) => a + b) /
                waiting.length)
            .round();
    final breachPct =
        waiting.isEmpty ? 0 : (breaches * 100 / waiting.length).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cards-resumo
          LayoutBuilder(
            builder: (context, c) {
              const spacing = AppSpacing.md;
              final cols = c.maxWidth >= 900
                  ? 4
                  : c.maxWidth >= 480
                      ? 2
                      : 1;
              final w = (c.maxWidth - spacing * (cols - 1)) / cols;
              final cards = [
                _kpi(theme, 'EM ESPERA', '${waiting.length}',
                    Icons.hourglass_bottom, theme.colorScheme.primary),
                _kpi(theme, 'EM ATENDIMENTO', '${inService.length}',
                    Icons.medical_services_outlined, const Color(0xFFFB8C00)),
                _kpi(theme, 'ATENDIDOS HOJE', '${state.servedToday}',
                    Icons.task_alt, const Color(0xFF43A047)),
                _kpi(theme, 'TEMPO MÉDIO', '$avgWait min',
                    Icons.timer_outlined, const Color(0xFF1C1C1E)),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final card in cards) SizedBox(width: w, child: card),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // SLA + distribuições
          LayoutBuilder(
            builder: (context, c) {
              final twoCols = c.maxWidth >= 760;
              final w = twoCols
                  ? (c.maxWidth - AppSpacing.md) / 2
                  : c.maxWidth;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: w,
                    child: _slaCard(theme, breachPct, breaches, waiting.length),
                  ),
                  SizedBox(
                    width: w,
                    child: _distRiscoCard(theme, state.riskCounts),
                  ),
                  SizedBox(
                    width: w,
                    child: _distCareLineCard(theme, [...waiting, ...inService]),
                  ),
                  SizedBox(
                    width: w,
                    child: _demandaCard(theme, [...waiting, ...inService]),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kpi(ThemeData theme, String label, String value, IconData icon,
      Color color) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _slaCard(ThemeData theme, int pct, int breaches, int total) {
    final ok = pct == 0;
    final color = ok ? const Color(0xFF43A047) : const Color(0xFFFF3B30);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(theme, 'ADERÊNCIA AO SLA (CLASSIFICAÇÃO)'),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$pct%',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w900, color: color)),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('da fila com SLA estourado',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : breaches / total,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('$breaches de $total pacientes acima do tempo-alvo',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _distRiscoCard(ThemeData theme, Map<ManchesterPriority, int> counts) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(theme, 'DISTRIBUIÇÃO POR RISCO (EM ESPERA)'),
          const SizedBox(height: AppSpacing.md),
          for (final p in ManchesterPriority.values)
            _bar(theme, p.label, counts[p] ?? 0, total, p.color),
        ],
      ),
    );
  }

  Widget _distCareLineCard(ThemeData theme, List<QueueEntry> entries) {
    final counts = {for (final l in CareLine.values) l: 0};
    for (final e in entries) {
      counts[e.careLine] = (counts[e.careLine] ?? 0) + 1;
    }
    final total = entries.length;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(theme, 'POR LINHA DE CUIDADO'),
          const SizedBox(height: AppSpacing.md),
          for (final l in CareLine.values)
            _bar(theme, l.label, counts[l] ?? 0, total,
                theme.colorScheme.primary),
        ],
      ),
    );
  }

  Widget _demandaCard(ThemeData theme, List<QueueEntry> entries) {
    final espontanea =
        entries.where((e) => e.attendanceType == AttendanceType.espontanea).length;
    final agendada = entries.length - espontanea;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(theme, 'TIPO DE DEMANDA'),
          const SizedBox(height: AppSpacing.md),
          _bar(theme, 'Demanda espontânea', espontanea, entries.length,
              const Color(0xFFFB8C00)),
          _bar(theme, 'Agendada', agendada, entries.length,
              const Color(0xFF1FAA59)),
        ],
      ),
    );
  }

  Widget _cardTitle(ThemeData theme, String text) => Text(text,
      style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5));

  Widget _bar(ThemeData theme, String label, int value, int total, Color color) {
    final frac = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text('$value',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
