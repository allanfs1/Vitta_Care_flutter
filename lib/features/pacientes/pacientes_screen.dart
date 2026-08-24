import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assistente/assistant_anchors.dart';
import '../assistente/assistant_tours.dart';
import '../../core/models/enums.dart';
import '../../core/models/patient.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/status_badge.dart';
import 'paciente_detalhe_screen.dart';

/// Módulo Pacientes — lista com busca e filtro por risco (PAC-01, PAC-02).
class PacientesScreen extends ConsumerStatefulWidget {
  const PacientesScreen({super.key});

  @override
  ConsumerState<PacientesScreen> createState() => _PacientesScreenState();
}

class _PacientesScreenState extends ConsumerState<PacientesScreen> {
  final _search = TextEditingController();
  RiskLevel? _risk;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final patients = ref.watch(patientsProvider).where((p) {
      if (_risk != null && p.riskLevel != _risk) return false;
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: AssistantTarget(
              anchorId: HelpAnchors.pacientesSearch,
              child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar paciente',
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
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _risk == null,
                  onSelected: (_) => setState(() => _risk = null),
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final r in RiskLevel.values) ...[
                  FilterChip(
                    label: Text('Risco ${r.label}'),
                    selected: _risk == r,
                    onSelected: (_) => setState(() => _risk = _risk == r ? null : r),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: patients.isEmpty
                ? const EmptyView(
                    icon: Icons.people_outline,
                    message: 'Nenhum paciente para os filtros.')
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: patients.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => _PatientTile(patient: patients[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PacienteDetalheScreen(patientId: patient.id),
      )),
      child: Row(
        children: [
          AppAvatar(
              initials: patient.initials,
              radius: 22,
              color: patient.riskLevel.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name, style: theme.textTheme.titleMedium),
                Text(
                  '${patient.age ?? '—'} anos • ${patient.gender ?? ''} • '
                  '${patient.attendedYtd} atend. / ${patient.absencesYtd} faltas',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge.risk(patient.riskLevel),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
