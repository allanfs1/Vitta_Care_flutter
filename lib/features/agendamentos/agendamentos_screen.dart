import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assistente/assistant_anchors.dart';
import '../assistente/assistant_tours.dart';
import '../../core/models/appointment.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_header.dart';
import 'widgets/appointment_list_item.dart';
import 'widgets/appointment_timeline.dart';
import 'widgets/new_appointment_dialog.dart';

/// Agente 2 — Agendamentos (`features/agendamentos`). Cobre A-01 e A-04.
class AgendamentosScreen extends ConsumerStatefulWidget {
  const AgendamentosScreen({super.key});

  @override
  ConsumerState<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

class _AgendamentosScreenState extends ConsumerState<AgendamentosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  String _specialty = 'Todas';
  String _doctor = 'Todos';
  AppointmentStatus? _status;
  String _query = '';
  _AgendaPeriod _period = _AgendaPeriod.all;
  DateTime _refDate = DateTime.now();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// `true` se a data cai no período selecionado (relativo a [_refDate]).
  bool _inPeriod(DateTime d) {
    switch (_period) {
      case _AgendaPeriod.all:
        return true;
      case _AgendaPeriod.day:
        return d.year == _refDate.year &&
            d.month == _refDate.month &&
            d.day == _refDate.day;
      case _AgendaPeriod.week:
        final monday = _refDate.subtract(Duration(days: _refDate.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = start.add(const Duration(days: 7));
        return !d.isBefore(start) && d.isBefore(end);
      case _AgendaPeriod.month:
        return d.year == _refDate.year && d.month == _refDate.month;
    }
  }

  /// Avança/retrocede o período de referência (dia, semana ou mês).
  void _shiftPeriod(int dir) {
    setState(() {
      switch (_period) {
        case _AgendaPeriod.day:
          _refDate = _refDate.add(Duration(days: dir));
        case _AgendaPeriod.week:
          _refDate = _refDate.add(Duration(days: 7 * dir));
        case _AgendaPeriod.month:
          _refDate = DateTime(_refDate.year, _refDate.month + dir, _refDate.day);
        case _AgendaPeriod.all:
          break;
      }
    });
  }

  String _periodLabel() {
    switch (_period) {
      case _AgendaPeriod.all:
        return '';
      case _AgendaPeriod.day:
        return '${Fmt.weekdayShort(_refDate)}, ${Fmt.shortDate(_refDate)}';
      case _AgendaPeriod.week:
        final monday = _refDate.subtract(Duration(days: _refDate.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${Fmt.shortDate(monday)} – ${Fmt.shortDate(sunday)}';
      case _AgendaPeriod.month:
        return Fmt.monthYear(_refDate);
    }
  }

  Future<void> _pickRefDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _refDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) setState(() => _refDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(appointmentsProvider);

    final specialties = ['Todas', ...{for (final a in all) a.specialty}];
    final doctors = ['Todos', ...{for (final a in all) a.doctorName}];

    // Sugestões do autocomplete: nomes de pacientes, médicos e especialidades
    // presentes na agenda (sem duplicar, ignorando vazios).
    final suggestions = <String>{
      for (final a in all) a.patientName,
      for (final a in all) a.doctorName,
      for (final a in all) a.specialty,
    }.where((s) => s.trim().isNotEmpty).toList()
      ..sort();

    final q = _query.trim().toLowerCase();
    final filtered = all.where((a) {
      if (!_inPeriod(a.start)) return false;
      if (_specialty != 'Todas' && a.specialty != _specialty) return false;
      if (_doctor != 'Todos' && a.doctorName != _doctor) return false;
      if (_status != null && a.status != _status) return false;
      if (q.isNotEmpty) {
        final hay =
            '${a.patientName} ${a.doctorName} ${a.specialty} ${a.local} ${a.motivo}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      floatingActionButton: AssistantTarget(
        anchorId: HelpAnchors.agendaNew,
        child: FloatingActionButton(
          onPressed: () => _showNewAppointmentSheet(context),
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          const AppHeader(title: 'Agenda'),
          // A-01 — pesquisa avançada com autocomplete
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: _SearchField(
              suggestions: suggestions,
              query: _query,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // A-01 — filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _FilterDropdown(
                    value: _specialty,
                    items: specialties,
                    icon: Icons.medical_services_outlined,
                    onChanged: (v) => setState(() => _specialty = v!),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _FilterDropdown(
                    value: _doctor,
                    items: doctors,
                    icon: Icons.person_outline,
                    onChanged: (v) => setState(() => _doctor = v!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusFilterChips(
            selected: _status,
            onSelected: (s) => setState(() => _status = s),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PeriodFilter(
            period: _period,
            label: _periodLabel(),
            count: filtered.length,
            onPeriodChanged: (p) => setState(() {
              _period = p;
              _refDate = DateTime.now();
            }),
            onPrev: () => _shiftPeriod(-1),
            onNext: () => _shiftPeriod(1),
            onPickDate: _pickRefDate,
          ),
          TabBar(
            controller: _tab,
            labelColor: theme.colorScheme.primary,
            tabs: const [Tab(text: 'Lista'), Tab(text: 'Timeline')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ListView(appointments: filtered),
                AppointmentTimeline(
                  appointments: filtered
                      .where((a) => a.start.day == DateTime.now().day)
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewAppointmentSheet(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const NewAppointmentDialog(),
    );
  }
}

/// Lista com **scroll infinito**: renderiza uma página por vez e carrega mais
/// itens conforme o usuário se aproxima do fim. Reinicia a paginação quando o
/// conjunto filtrado muda.
class _ListView extends StatefulWidget {
  const _ListView({required this.appointments});
  final List<Appointment> appointments;

  @override
  State<_ListView> createState() => _ListViewState();
}

class _ListViewState extends State<_ListView> {
  static const int _pageSize = 15;

  final ScrollController _scroll = ScrollController();
  int _visible = _pageSize;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Filtros mudaram → recomeça do topo. Caso contrário, apenas garante que
    // a janela visível não exceda a nova quantidade de itens.
    if (!_sameList(oldWidget.appointments, widget.appointments)) {
      _visible = _pageSize;
      _loading = false;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if (_visible > widget.appointments.length) {
      _visible = widget.appointments.length;
    }
  }

  bool _sameList(List<Appointment> a, List<Appointment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].status != b[i].status ||
          a[i].start != b[i].start) {
        return false;
      }
    }
    return true;
  }

  void _onScroll() {
    if (_loading || _visible >= widget.appointments.length) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    // Pequena espera para o indicador aparecer (simula carregamento de página).
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      final next = _visible + _pageSize;
      _visible = next < widget.appointments.length
          ? next
          : widget.appointments.length;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.appointments;
    if (items.isEmpty) {
      return const Center(child: Text('Nenhum agendamento para os filtros.'));
    }
    final count = _visible < items.length ? _visible : items.length;
    final hasMore = count < items.length;

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: count + (hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) {
        if (i >= count) {
          // Sentinela de carregamento no fim da lista.
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return AppointmentListItem(appointment: items[i]);
      },
    );
  }
}

/// Campo de pesquisa avançada com autocomplete: filtra a agenda por paciente,
/// médico, especialidade, local ou motivo, sugerindo termos da própria agenda.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.suggestions,
    required this.query,
    required this.onChanged,
  });

  final List<String> suggestions;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: query),
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return suggestions
            .where((s) => s.toLowerCase().contains(q))
            .take(8);
      },
      onSelected: onChanged,
      fieldViewBuilder:
          (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            hintText: 'Pesquisar paciente, médico, especialidade…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 520),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.search, size: 18),
                    title: Text(option, overflow: TextOverflow.ellipsis),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      items: [
        for (final i in items)
          DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Período de agrupamento da agenda (filtro por dia, semana ou mês).
enum _AgendaPeriod {
  all('Todos'),
  day('Dia'),
  week('Semana'),
  month('Mês');

  const _AgendaPeriod(this.label);
  final String label;
}

/// Filtro de período: escolhe Dia/Semana/Mês/Todos, navega entre os períodos
/// e permite escolher uma data de referência. Mostra a contagem de resultados.
class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter({
    required this.period,
    required this.label,
    required this.count,
    required this.onPeriodChanged,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
  });

  final _AgendaPeriod period;
  final String label;
  final int count;
  final ValueChanged<_AgendaPeriod> onPeriodChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              for (final p in _AgendaPeriod.values) ...[
                ChoiceChip(
                  label: Text(p.label),
                  selected: period == p,
                  onSelected: (_) => onPeriodChanged(p),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        if (period != _AgendaPeriod.all)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Anterior',
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: onPickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(label,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Próximo',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 0),
          child: Text(
            count == 1 ? '1 agendamento' : '$count agendamentos',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.selected, required this.onSelected});

  final AppointmentStatus? selected;
  final ValueChanged<AppointmentStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Todos'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final s in AppointmentStatus.values) ...[
            FilterChip(
              label: Text(s.label),
              selected: selected == s,
              onSelected: (_) => onSelected(selected == s ? null : s),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
