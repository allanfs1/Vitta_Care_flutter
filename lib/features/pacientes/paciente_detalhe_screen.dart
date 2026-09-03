import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/patient.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/section_header.dart';
import 'paciente_data.dart';

/// Detalhe / jornada do paciente (PAC-03..PAC-06).
/// Segue `.specify/Designer/area_e_jornada_do_paciente.png`.
class PacienteDetalheScreen extends ConsumerWidget {
  const PacienteDetalheScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final matches = ref.watch(patientsProvider).where((p) => p.id == patientId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paciente')),
        body: const EmptyView(
            icon: Icons.person_off_outlined, message: 'Paciente não encontrado.'),
      );
    }
    final p = matches.first;
    final notes = ref.watch(clinicalNotesProvider.notifier).notes(p);
    final highRisk = p.riskLevel == RiskLevel.high;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paciente'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      bottomNavigationBar: _ActionBar(patient: p),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Cabeçalho
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    AppAvatar(
                        initials: p.initials,
                        radius: 28,
                        color: p.riskLevel.color),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: theme.textTheme.titleLarge),
                          Text('${p.age ?? '—'} anos • ${p.gender ?? ''}',
                              style: theme.textTheme.bodyMedium),
                          Text('ID #${p.id.toUpperCase()}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                _row(context, 'Próximo atendimento', 'Hoje, 14:30'),
                const SizedBox(height: AppSpacing.sm),
                _row(context, 'Cuidado principal', 'Dr. Roberto Santos'),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: p.riskLevel.background,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(highRisk ? Icons.warning_amber_rounded : Icons.shield_outlined,
                          color: p.riskLevel.color, size: 18),
                      const SizedBox(width: 8),
                      Text(context.txt.t('pacientes.riscoDeFaltas'),
                          style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(p.riskLevel.label,
                          style: TextStyle(
                              color: p.riskLevel.color,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Jornada atual
          const SectionHeader(title: 'Jornada atual', icon: Icons.timeline),
          const SizedBox(height: AppSpacing.md),
          AppCard(child: _Journey(steps: PacienteData.journeyFor(p))),
          const SizedBox(height: AppSpacing.lg),

          // Histórico de presença
          const SectionHeader(title: 'Histórico de presença', icon: Icons.history),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                          value: '${p.attendedYtd}',
                          label: context.txt.t('pacientes.atendidos'),
                          color: AppColors.success,
                          bg: AppColors.successLight),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatBox(
                          value: '${p.absencesYtd}',
                          label: context.txt.t('pacientes.faltas'),
                          color: AppColors.danger,
                          bg: AppColors.dangerLight),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                for (final h in PacienteData.historyFor(p))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 10,
                            color: h.attended ? AppColors.success : AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(h.specialty, style: theme.textTheme.bodyMedium)),
                        Text(h.date, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Notas clínicas
          SectionHeader(
            title: context.txt.t('pacientes.notasClinicas'),
            icon: Icons.edit_note,
            actionLabel: context.txt.t('pacientes.adicionar'),
            onAction: () => _addNote(context, ref, p),
          ),
          const SizedBox(height: AppSpacing.md),
          if (notes.isEmpty)
            const AppCard(child: Text('Sem notas registradas.'))
          else
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.date,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(n.text, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _row(BuildContext c, String label, String value) {
    final t = Theme.of(c).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: t.bodyMedium),
        Text(value, style: t.titleMedium),
      ],
    );
  }

  void _addNote(BuildContext context, WidgetRef ref, Patient p) {
    final controller = TextEditingController();
    var salvando = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nova nota clínica'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            enabled: !salvando,
            decoration: const InputDecoration(hintText: 'Descreva a observação…'),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: salvando
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;

                      setState(() => salvando = true);
                      final autor = ref.read(currentUserProvider).fullName;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        // A tela só mantém a nota depois que o banco confirmou —
                        // antes, "Salvar" fechava o diálogo mesmo sem gravar nada.
                        await ref.read(clinicalNotesProvider.notifier).add(
                              p,
                              ClinicalNote('Hoje — $autor', autor, text),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => salvando = false);
                        messenger.showSnackBar(SnackBar(
                          backgroundColor: AppColors.danger,
                          content: Text('Não foi possível salvar: $e'),
                        ));
                      }
                    },
              child: salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Journey extends StatelessWidget {
  const _Journey({required this.steps});
  final List<JourneyStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: steps[i].state == JourneyState.pending
                            ? AppColors.surfaceAlt
                            : AppColors.primary,
                      ),
                      child: Icon(
                        steps[i].state == JourneyState.done
                            ? Icons.check
                            : steps[i].icon,
                        size: 18,
                        color: steps[i].state == JourneyState.pending
                            ? AppColors.textTertiary
                            : Colors.white,
                      ),
                    ),
                    if (i != steps.length - 1)
                      Expanded(child: Container(width: 2, color: AppColors.border)),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: steps[i].state == JourneyState.current
                                  ? AppColors.primary
                                  : null,
                            )),
                        Text(steps[i].subtitle, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
    required this.bg,
  });

  final String value;
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _snack(context, 'Paciente marcado como falta.'),
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('Marcar falta'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _snack(context, 'Consulta concluída.'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Concluir consulta'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}
