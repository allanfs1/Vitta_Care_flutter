import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/doctor.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import 'medico_detalhe_screen.dart';
import 'medico_form_screen.dart';

/// Ordenação da lista da equipe médica (EM-01).
enum _DoctorSort { name, consultations }

/// Módulo Equipe Médica — lista com busca, filtros e cadastro (EM-01, EM-02).
/// Mapeia `tb_medicos` filtrado pela clínica selecionada.
class EquipeMedicaScreen extends ConsumerStatefulWidget {
  const EquipeMedicaScreen({super.key});

  @override
  ConsumerState<EquipeMedicaScreen> createState() => _EquipeMedicaScreenState();
}

class _EquipeMedicaScreenState extends ConsumerState<EquipeMedicaScreen> {
  final _search = TextEditingController();
  String? _specialty;
  bool? _active = true; // true=ativos, false=inativos, null=todos
  _DoctorSort _sort = _DoctorSort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // EM-01 — apenas os médicos da clínica selecionada (`idclinica`).
    final all = ref.watch(clinicDoctorsProvider);
    final clinic = ref.watch(selectedClinicProvider);

    // Especialidades existentes na equipe (para os chips de filtro).
    final specialties = <String>{
      for (final d in all) ...d.specialties,
    }.toList()
      ..sort();

    final query = _search.text.trim().toLowerCase();
    final doctors = all.where((d) {
      if (_active != null && d.active != _active) return false;
      if (_specialty != null && !d.specialties.contains(_specialty)) return false;
      if (query.isNotEmpty &&
          !d.name.toLowerCase().contains(query) &&
          !d.crm.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => switch (_sort) {
            _DoctorSort.name => a.name.compareTo(b.name),
            _DoctorSort.consultations =>
              b.monthlyConsultations.compareTo(a.monthlyConsultations),
          });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Equipe Médica'),
            Text('${clinic.name} • ${all.length} profissionais',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          PopupMenuButton<_DoctorSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _DoctorSort.name, child: Text('Nome (A-Z)')),
              PopupMenuItem(
                  value: _DoctorSort.consultations,
                  child: Text('Consultas no mês')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const MedicoFormScreen(),
        )),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo médico'),
      ),
      body: Column(
        children: [
          _TeamStats(doctors: all),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou CRM',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          // Filtro por status (ativo / inativo / todos).
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _statusChip('Ativos', true),
                const SizedBox(width: AppSpacing.sm),
                _statusChip('Inativos', false),
                const SizedBox(width: AppSpacing.sm),
                _statusChip('Todos', null),
              ],
            ),
          ),
          // Filtro por especialidade (EM-02).
          if (specialties.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  FilterChip(
                    label: const Text('Todas'),
                    selected: _specialty == null,
                    onSelected: (_) => setState(() => _specialty = null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  for (final s in specialties) ...[
                    FilterChip(
                      label: Text(s),
                      selected: _specialty == s,
                      onSelected: (_) =>
                          setState(() => _specialty = _specialty == s ? null : s),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: doctors.isEmpty
                ? EmptyView(
                    icon: Icons.badge_outlined,
                    message: 'Nenhum médico para os filtros.',
                    actionLabel: 'Cadastrar médico',
                    onAction: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MedicoFormScreen(),
                    )),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: doctors.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => _DoctorTile(doctor: doctors[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _active == value,
      onSelected: (_) => setState(() => _active = value),
    );
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({required this.doctor});
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MedicoDetalheScreen(doctorId: doctor.id),
      )),
      child: Row(
        children: [
          AppAvatar(
            initials: doctor.initials,
            imageUrl: doctor.photoUrl,
            imageBytes: doctor.photoBytes,
            radius: 24,
            color: doctor.active ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.name, style: theme.textTheme.titleMedium),
                Text(
                  'CRM ${doctor.crm} • ${doctor.monthlyConsultations} consultas/mês',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final s in doctor.specialties.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text(s,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.primaryDark)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusBadge(active: doctor.active),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// Cabeçalho com KPIs do corpo clínico da clínica (visão rápida da equipe).
class _TeamStats extends StatelessWidget {
  const _TeamStats({required this.doctors});
  final List<Doctor> doctors;

  @override
  Widget build(BuildContext context) {
    final active = doctors.where((d) => d.active).toList();
    final n = active.length;
    final avgOcc = n == 0
        ? 0.0
        : active.map((d) => d.occupancyRate).reduce((a, b) => a + b) / n;
    final avgAbs = n == 0
        ? 0.0
        : active.map((d) => d.absenceRate).reduce((a, b) => a + b) / n;
    final totalMonth =
        active.fold<int>(0, (s, d) => s + d.monthlyConsultations);

    final tiles = <Widget>[
      _MetricTile(
        icon: Icons.groups_2_outlined,
        value: '$n',
        label: 'Médicos ativos',
        color: AppColors.primary,
      ),
      _MetricTile(
        icon: Icons.event_available_outlined,
        value: '$totalMonth',
        label: 'Consultas/mês',
        color: AppColors.secondary,
      ),
      _MetricTile(
        icon: Icons.donut_large_outlined,
        value: '${(avgOcc * 100).round()}%',
        label: 'Ocupação média',
        color: AppColors.info,
      ),
      _MetricTile(
        icon: Icons.person_off_outlined,
        value: '${(avgAbs * 100).round()}%',
        label: 'Faltas médias',
        color: AppColors.danger,
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        itemCount: tiles.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => tiles[i],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 132,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const Spacer(),
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(color: color)),
          Text(label, style: theme.textTheme.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}

/// Badge ativo/inativo do médico (reaproveita as cores de status do tema).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textSecondary;
    final bg = active ? AppColors.successLight : AppColors.surfaceAlt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        active ? 'Ativo' : 'Inativo',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
