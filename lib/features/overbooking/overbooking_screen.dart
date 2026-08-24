import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import 'overbooking_providers.dart';
import 'overbooking_tabs.dart';

/// Painel de **gestão inteligente de overbooking** da clínica
/// (ver `.specify/AGENTS.md` → Módulo Overbooking, OVB-01..OVB-07).
///
/// Centro de comando operacional em 4 abas: Visão Geral (KPIs + gráficos em
/// tempo real), Pacientes do Dia (estados), Realocação (motor que remaneja o
/// excedente e envia o e-mail de overbooking com o novo horário) e Decisões
/// (auditoria). Reaproveita `Doctor.capacityAt`, `OccupancyLevel` e o mesmo
/// conjunto de agendamentos do Totem/Agenda.
class OverbookingScreen extends ConsumerWidget {
  const OverbookingScreen({super.key});

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(overbookingDateProvider);
    final isToday = _sameDay(date, DateTime.now());

    void shift(int days) => ref.read(overbookingDateProvider.notifier).state =
        DateTime(date.year, date.month, date.day + days);

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 180)),
      );
      if (picked != null) {
        ref.read(overbookingDateProvider.notifier).state =
            DateTime(picked.year, picked.month, picked.day);
      }
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Overbooking'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => shift(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: pickDate,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          child: Column(
                            children: [
                              Text(isToday ? 'Hoje' : Fmt.weekdayShort(date),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                              Text(Fmt.fullDate(date),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => shift(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: 'Visão Geral'),
                    Tab(text: 'Pacientes do Dia'),
                    Tab(text: 'Realocação'),
                    Tab(text: 'Decisões'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            OverviewTab(),
            PatientsTab(),
            ReallocationTab(),
            DecisionsTab(),
          ],
        ),
      ),
    );
  }
}
