import 'dart:ui' show lerpDouble;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../assistente/assistant_anchors.dart';
import '../assistente/assistant_tours.dart';
import '../../core/models/appointment.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/services/mock_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../configuracoes/providers/configuracoes_provider.dart';
import '../../core/widgets/ai_insight_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/density_heatmap.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/next_appointments_carousel.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_badge.dart';
import '../../navigation/app_router.dart';
import 'home_layout_provider.dart';

import 'widgets/shortcut_bar.dart';
import 'widgets/unit_profile_banner.dart';
import 'widgets/week_selector.dart';

/// Agente 1 — Dashboard Home (`features/home`).
/// Cobre H-01..H-06 + drag & drop personalizado.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final clinic = ref.watch(selectedClinicProvider);
    final appointments = ref.watch(appointmentsProvider);
    final next = appointments
        .where((a) => a.status != AppointmentStatus.cancelled)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final kpis = MockData.homeKpis();
    final columns = Responsive.gridColumns(context, max: 3);

    final blockOrder = ref.watch(homeLayoutProvider).where((id) {
      if (id == 'carousel_appointments' && !ref.watch(settingsProvider).showNextAppointmentsCarousel) return false;
      return true;
    }).toList();
    final isFinanceiroEnabled = !ref.watch(disabledModulesProvider).contains('financeiro');
    final isCarrosselEnabled = !ref.watch(disabledModulesProvider).contains('carrossel_agendamentos');

    // Mapa de blockId → widget builder.
    Widget buildBlock(String id) {
      return switch (id) {
        'unit_profile' => UnitProfileBanner(clinic: clinic),
        'week_selector' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Esta semana',
                actionLabel: 'Ver tudo',
                onAction: () => context.go(AppRoutes.agendamentos),
              ),
              const SizedBox(height: AppSpacing.md),
              const WeekSelector(),
            ],
          ),
        'shortcuts' => const ShortcutBar(),
        'kpis' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Indicadores', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              AssistantTarget(
                anchorId: HelpAnchors.homeKpis,
                child: _KpiGrid(kpis: kpis, columns: columns),
              ),
            ],
          ),
        'faturamento' => isFinanceiroEnabled ? const _FaturamentoCard() : const SizedBox.shrink(),
        'charts' => _ChartsSection(),
        'density' => _DensityCard(),
        'reallocation' => const _ReallocationCard(),
        'carousel_appointments' => isCarrosselEnabled 
          ? NextAppointmentsCarousel(
              appointments: next,
              onTapAppointment: (id) => context.go(AppRoutes.appointmentDetail(id)),
            ) 
          : const SizedBox.shrink(),
        'next_appointments' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Próximos agendamentos',
                actionLabel: 'Ver todos',
                onAction: () => context.go(AppRoutes.agendamentos),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final a in next.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _NextAppointmentTile(appointment: a),
                ),
            ],
          ),
        _ => const SizedBox.shrink(),
      };
    }

    return Column(
      children: [
        AppHeader(
          trailing: _EditLayoutButton(
            editing: _editing,
            onToggle: () => setState(() => _editing = !_editing),
            onReset: () => ref.read(homeLayoutProvider.notifier).resetOrder(),
          ),
        ),
        if (_editing)
          _EditModeBanner(
            onDone: () => setState(() => _editing = false),
          ),
        Expanded(
          child: _editing
              ? _buildReorderable(blockOrder, buildBlock)
              : _buildNormal(blockOrder, buildBlock),
        ),
      ],
    );
  }

  Widget _buildNormal(List<String> order, Widget Function(String) buildBlock) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        for (final id in order) ...[
          if (id == 'carousel_appointments') ...[
            const SizedBox(height: AppSpacing.lg),
            buildBlock(id),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: buildBlock(id),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ],
    );
  }

  Widget _buildReorderable(
      List<String> order, Widget Function(String) buildBlock) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      itemCount: order.length,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = lerpDouble(0, 8, animation.value) ?? 0;
            return Material(
              color: Colors.transparent,
              elevation: elevation,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 4),
              child: child,
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        ref.read(homeLayoutProvider.notifier).reorder(order, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final id = order[index];
        return _DraggableItem(
          key: ValueKey(id),
          index: index,
          label: kBlockLabels[id] ?? id,
          child: buildBlock(id),
        );
      },
    );
  }
}

/// Item individual do ReorderableListView com drag handle integrado.
class _DraggableItem extends StatefulWidget {
  const _DraggableItem({
    super.key,
    required this.index,
    required this.label,
    required this.child,
  });

  final int index;
  final String label;
  final Widget child;

  @override
  State<_DraggableItem> createState() => _DraggableItemState();
}

class _DraggableItemState extends State<_DraggableItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final handleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final borderColor = _hovering
        ? AppColors.primary.withValues(alpha: 0.5)
        : AppColors.primary.withValues(alpha: 0.2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 4),
            border: Border.all(
              color: borderColor,
              width: _hovering ? 2 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ─────────────────────────────
              ReorderableDragStartListener(
                index: widget.index,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceAlt)
                        .withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusLg + 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator,
                          size: 20, color: handleColor),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: handleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.open_with,
                          size: 16,
                          color: handleColor.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),

              // ── Conteúdo ──────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão no header para entrar/sair do modo de edição de layout.
class _EditLayoutButton extends StatelessWidget {
  const _EditLayoutButton({
    required this.editing,
    required this.onToggle,
    required this.onReset,
  });

  final bool editing;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Restaurar ordem padrão',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt, size: 20),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onToggle,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Concluir'),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      );
    }
    return IconButton(
      tooltip: 'Personalizar layout',
      onPressed: onToggle,
      icon: const Icon(Icons.dashboard_customize_outlined, size: 22),
    );
  }
}

/// Banner que aparece no topo quando o modo edição está ativo.
class _EditModeBanner extends StatelessWidget {
  const _EditModeBanner({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Arraste os blocos pelo ícone ≡ para reorganizar o dashboard.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onDone,
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de bloco (mantidos do original)
// ─────────────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.columns});

  final List<Kpi> kpis;
  final int columns;

  static const _icons = [
    Icons.event_available,
    Icons.how_to_reg,
    Icons.cancel_schedule_send,
    Icons.timer_outlined,
    Icons.medical_services_outlined,
    Icons.sentiment_satisfied_alt,
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: 120,
      ),
      itemBuilder: (context, i) =>
          KpiCard(kpi: kpis[i], icon: _icons[i % _icons.length]),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trend = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Tendência de agendamentos',
            trailing: AiInsightButton(
              chartTitle: 'Tendência de agendamentos',
              summary:
                  'O volume semanal oscila entre 30 e 63 agendamentos, com pico nas quintas e queda no sábado.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SimpleLineChart(data: MockData.appointmentTrend()),
        ],
      ),
    );

    final absent = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Taxa global de absenteísmo',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const AiInsightButton(
                chartTitle: 'Taxa global de absenteísmo',
                summary:
                    'A taxa global está em 18%, com alta de 2 p.p. frente à semana anterior.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: DonutChart(percent: 18, color: AppColors.primary, centerLabel: ''),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.trending_up, size: 16, color: AppColors.danger),
                SizedBox(width: 4),
                Text('+2% vs semana passada',
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );

    if (Responsive.isMobile(context)) {
      return Column(children: [absent, const SizedBox(height: AppSpacing.lg), trend]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: absent),
          const SizedBox(width: AppSpacing.lg),
          Expanded(flex: 2, child: trend),
        ],
      ),
    );
  }
}

class _ReallocationCard extends StatelessWidget {
  const _ReallocationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Eficiência de realocação',
                    style: theme.textTheme.titleLarge),
              ),
              const AiInsightButton(
                chartTitle: 'Eficiência de realocação',
                summary:
                    'A taxa de sucesso ao preencher horários cancelados está em 72%, em tendência de alta.',
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Taxa de sucesso ao preencher horários cancelados',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(0.45, AppColors.surfaceAlt),
              const SizedBox(width: 12),
              _bar(0.6, AppColors.border),
              const SizedBox(width: 12),
              _bar(0.85, AppColors.primary),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Atual', style: theme.textTheme.bodyMedium),
              Text('72%',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(double factor, Color color) {
    return Expanded(
      child: Container(
        height: 90 * factor + 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
  }
}

class _NextAppointmentTile extends StatelessWidget {
  const _NextAppointmentTile({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go(AppRoutes.appointmentDetail(appointment.id)),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: appointment.status.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(Fmt.time(appointment.start),
                        style: theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    StatusBadge.appointment(appointment.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(appointment.patientName, style: theme.textTheme.bodyLarge),
                Text('${appointment.specialty} • ${appointment.tipoConsulta}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _DensityCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Densidade de Agendamento',
            trailing: AiInsightButton(
              chartTitle: 'Densidade de Agendamento',
              summary:
                  'Os horários de pico ocorrem na terça à tarde (14h-16h) e quinta pela manhã (9h-11h).',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DensityHeatmap(
            data: MockData.heatmap(),
            onCellTapped: (dayIndex, hourIndex) => _showAppointmentsBottomSheet(
              context,
              dayIndex,
              hourIndex,
              appointments,
            ),
          ),
        ],
      ),
    );
  }

  void _showAppointmentsBottomSheet(
    BuildContext context,
    int dayIndex,
    int hourIndex,
    List<Appointment> appointments,
  ) {
    final theme = Theme.of(context);
    final days = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira'
    ];
    final hourLabel = '${8 + hourIndex}h';
    final dayLabel = days[dayIndex];

    final mockList = appointments.take(3).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Agendamentos - $dayLabel às $hourLabel',
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (mockList.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                      child:
                          Text('Nenhum agendamento para este horário.')),
                )
              else
                ...mockList.map((app) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _NextAppointmentTile(appointment: app),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _FaturamentoCard extends StatelessWidget {
  const _FaturamentoCard();

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
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.attach_money, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EVOLUÇÃO DO FATURAMENTO',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    Text('RECEITA CONFIRMADA NOS ÚLTIMOS 6 MESES',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl * 2),
          SizedBox(
            height: 240,
            child: _FaturamentoChart(),
          ),
        ],
      ),
    );
  }
}

class _FaturamentoChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value == 0) return _label('R\$0k');
                if (value == 0.15) return _label('R\$0.15k');
                if (value == 0.3) return _label('R\$0.3k');
                if (value == 0.45) return _label('R\$0.45k');
                if (value == 0.6) return _label('R\$0.6k');
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun'];
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(months[i], style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                );
              },
            ),
          ),
        ),
        minY: 0,
        maxY: 0.6,
        minX: 0,
        maxX: 5,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 0.5),
              FlSpot(1, 0.0),
              FlSpot(2, 0.5),
              FlSpot(3, 0.25),
              FlSpot(4, 0.0),
              FlSpot(5, 0.0),
            ],
            isCurved: true,
            color: const Color(0xFF00C853),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00C853).withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
