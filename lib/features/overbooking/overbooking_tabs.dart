import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/appointment.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import 'overbooking_engine.dart';
import 'overbooking_models.dart';
import 'overbooking_providers.dart';
import 'overbooking_widgets.dart';
import '../monte_carlo/widgets/mc_ponte_overbooking.dart';

// ───────────────────────── Visão Geral (OVB-02/03) ─────────────────────────

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(overbookingSnapshotProvider);
    final realoc = ref.watch(realocacaoProvider);
    final doctors = snap.doctors;
    final wd = snap.date.weekday;
    final cols = Responsive.gridColumns(context, max: 4).clamp(2, 4);

    final kpis = <Widget>[
      OvbKpiTile(
        label: 'Ocupação',
        value: '${snap.occPct}%',
        icon: Icons.donut_large_outlined,
        color: snap.occPct > 90
            ? AppColors.danger
            : (snap.occPct > 70 ? AppColors.warning : AppColors.success),
        hint: 'Ocupação da clínica',
      ),
      OvbKpiTile(
          label: 'Slots lotados',
          value: '${snap.fullSlots}',
          icon: Icons.block,
          color: snap.fullSlots > 0 ? AppColors.danger : AppColors.textSecondary),
      OvbKpiTile(
          label: 'Excedente overbook',
          value: '${snap.excedenteTotal}',
          icon: Icons.trending_up,
          color: AppColors.warning),
      OvbKpiTile(
          label: 'Estouro capacidade',
          value: '${snap.estouroTotal}',
          icon: Icons.priority_high,
          color: snap.estouroTotal > 0 ? AppColors.danger : AppColors.textSecondary),
      OvbKpiTile(
          label: 'Esperando',
          value: '${snap.esperando}',
          icon: Icons.hourglass_bottom,
          color: AppColors.primary),
      OvbKpiTile(
          label: 'Realocáveis',
          value: '${snap.realocaveis}',
          icon: Icons.swap_horiz,
          color: const Color(0xFFE8590C)),
      OvbKpiTile(
          label: 'Realoc. pendentes',
          value: '${realoc.propostas.values.where((p) => p.status == RealocacaoStatus.sugerida || p.status == RealocacaoStatus.aguardandoConfirmacao).length}',
          icon: Icons.pending_actions,
          color: AppColors.warning),
      OvbKpiTile(
          label: 'E-mails enviados',
          value: '${realoc.propostas.values.where((p) => p.emailStatus != RealoEmailStatus.naoEnviado).length}',
          icon: Icons.mark_email_read_outlined,
          color: AppColors.success),
    ];

    final estados = contarEstados(snap, realoc);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Ponte com o Simulador: o painel mostra o que já ocupou a agenda;
        // o cartão traz o que a distribuição diz sobre o que ainda vem.
        const McPonteOverbooking(),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.3,
          children: kpis,
        ),
        const SizedBox(height: AppSpacing.lg),
        OccupancyLineChart(
          hours: snap.hours,
          booked: snap.bookedByHour,
          capacity: snap.capacityByHour,
        ),
        const SizedBox(height: AppSpacing.lg),
        EstadosPieChart(counts: estados),
        const SizedBox(height: AppSpacing.lg),
        Text('OCUPAÇÃO POR MÉDICO',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.sm),
        if (doctors.isEmpty)
          const EmptyView(
            message: 'Nenhum médico ativo nesta clínica.',
            icon: Icons.badge_outlined,
          )
        else
          for (final d in doctors)
            DoctorOverbookCard(
              doctor: d,
              hours: snap.hours,
              bookedByHour: snap.bookedByDoctorHour[d.id] ?? const {},
              weekday: wd,
              onEdit: () => showOverbookingConfigDialog(context, ref, d),
            ),
      ],
    );
  }
}

// ─────────────────────── Pacientes do dia (OVB-04) ───────────────────────

final _pacientesFiltroProvider = StateProvider<String>((ref) => 'todos');

class PatientsTab extends ConsumerWidget {
  const PatientsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(overbookingSnapshotProvider);
    final realoc = ref.watch(realocacaoProvider);
    final filtro = ref.watch(_pacientesFiltroProvider);
    final realocavel = snap.realocavelIds;

    final appts = [...snap.dayAppointments]
      ..sort((a, b) => a.start.compareTo(b.start));

    PacienteEstado estado(Appointment a) => OverbookingEngine.estadoDe(
          a,
          realocavel: realocavel.contains(a.id),
          proposta: realoc.propostas[a.id]?.status,
        );

    final filtrados = appts.where((a) {
      final e = estado(a);
      switch (filtro) {
        case 'realocaveis':
          return e == PacienteEstado.realocavel;
        case 'esperando':
          return e == PacienteEstado.aguardando ||
              (a.status == AppointmentStatus.confirmed &&
                  a.start.isBefore(DateTime.now()));
        case 'realocados':
          return e == PacienteEstado.realocado ||
              e == PacienteEstado.sugerida ||
              e == PacienteEstado.aguardandoConfirmacao;
        default:
          return true;
      }
    }).toList();

    Widget chip(String id, String label, int count) {
      final sel = filtro == id;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          selected: sel,
          label: Text('$label ($count)'),
          onSelected: (_) =>
              ref.read(_pacientesFiltroProvider.notifier).state = id,
        ),
      );
    }

    final total = appts.length;
    final realocaveisN = appts.where((a) => estado(a) == PacienteEstado.realocavel).length;
    final esperandoN = snap.esperando;
    final emProcessoN = appts.where((a) {
      final e = estado(a);
      return e == PacienteEstado.realocado ||
          e == PacienteEstado.sugerida ||
          e == PacienteEstado.aguardandoConfirmacao;
    }).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('todos', 'Todos', total),
                chip('realocaveis', 'Realocáveis', realocaveisN),
                chip('esperando', 'Esperando', esperandoN),
                chip('realocados', 'Em realocação', emProcessoN),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtrados.isEmpty
              ? const EmptyView(
                  message: 'Nenhum paciente neste filtro.',
                  icon: Icons.people_outline)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtrados.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final a = filtrados[i];
                    return _PacienteTile(appointment: a, estado: estado(a));
                  },
                ),
        ),
      ],
    );
  }
}

class _PacienteTile extends StatelessWidget {
  const _PacienteTile({required this.appointment, required this.estado});
  final Appointment appointment;
  final PacienteEstado estado;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(Fmt.time(a.start),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.patientName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${a.specialty} • ${a.doctorName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: a.patientRisk.color),
                    const SizedBox(width: 4),
                    Text('Risco ${a.patientRisk.label.toLowerCase()}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    if (a.patientPhone.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.chat_outlined,
                          size: 12, color: AppColors.textTertiary),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          EstadoBadge(estado),
        ],
      ),
    );
  }
}

// ─────────────────────── Realocação (OVB-05) ───────────────────────

class ReallocationTab extends ConsumerWidget {
  const ReallocationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(overbookingSnapshotProvider);
    final realoc = ref.watch(realocacaoProvider);
    final modo = ref.watch(realocacaoModoProvider);
    final notifier = ref.read(realocacaoProvider.notifier);

    final propostas = realoc.propostas.values.toList()
      ..sort((a, b) => a.slotOrigem.compareTo(b.slotOrigem));
    final semProposta = <_SlotCand>[];
    for (final s in snap.slotsSobrecarga) {
      for (final c in s.candidatos) {
        if (!realoc.propostas.containsKey(c.appointment.id) &&
            c.destino != null) {
          semProposta.add(_SlotCand(s, c));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_suggest_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text('Motor de realocação',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  DropdownButton<RealocacaoModo>(
                    value: modo,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final m in RealocacaoModo.values)
                        DropdownMenuItem(value: m, child: Text(m.label)),
                    ],
                    onChanged: (v) => v == null
                        ? null
                        : ref.read(realocacaoModoProvider.notifier).state = v,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Modo $modo detecta o excedente e ${modo == RealocacaoModo.automatico ? 'efetiva a realocação notificando o paciente' : modo == RealocacaoModo.semiAutomatico ? 'envia o e-mail pedindo confirmação antes de efetivar' : 'apenas propõe para o gestor revisar'}.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: snap.slotsSobrecarga.isEmpty
                          ? null
                          : () => notifier.sugerirTodos(snap.slotsSobrecarga),
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('Gerar sugestões'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (snap.slotsSobrecarga.isEmpty && propostas.isEmpty)
          const EmptyView(
            message: 'Nenhum slot em sobrecarga hoje. 🎉',
            icon: Icons.check_circle_outline,
          ),
        if (propostas.isNotEmpty) ...[
          const Text('PROPOSTAS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          for (final p in propostas)
            _PropostaCard(proposta: p, modo: modo, notifier: notifier),
        ],
        if (semProposta.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const Text('DETECTADOS (sem proposta)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          for (final sc in semProposta)
            _CandidatoCard(
              slot: sc.slot,
              cand: sc.cand,
              onSugerir: () => notifier.sugerir(sc.slot, sc.cand),
            ),
        ],
      ],
    );
  }
}

class _SlotCand {
  const _SlotCand(this.slot, this.cand);
  final SlotSobrecarga slot;
  final CandidatoRealoc cand;
}

class _CandidatoCard extends StatelessWidget {
  const _CandidatoCard(
      {required this.slot, required this.cand, required this.onSugerir});
  final SlotSobrecarga slot;
  final CandidatoRealoc cand;
  final VoidCallback onSugerir;

  @override
  Widget build(BuildContext context) {
    final a = cand.appointment;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.patientName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                      '${slot.doctorName} ${slot.hour.toString().padLeft(2, '0')}:00 '
                      '(${slot.booked}/${slot.capacity}) → ${cand.destino != null ? Fmt.shortDate(cand.destino!) : '—'} '
                      '${cand.destino != null ? Fmt.time(cand.destino!) : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            FilledButton.tonal(
                onPressed: onSugerir, child: const Text('Sugerir')),
          ],
        ),
      ),
    );
  }
}

class _PropostaCard extends StatelessWidget {
  const _PropostaCard(
      {required this.proposta, required this.modo, required this.notifier});
  final RealocacaoProposta proposta;
  final RealocacaoModo modo;
  final RealocacaoNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final p = proposta;
    final concluida = p.status == RealocacaoStatus.concluida;
    final recusada = p.status == RealocacaoStatus.recusada;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: p.patientRisk.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.patientName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                _statusChip(p.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _fromTo(
              context,
              from: '${p.doctorName}\n${Fmt.shortDate(p.slotOrigem)} ${Fmt.time(p.slotOrigem)}',
              to: '${p.doctorName}\n${Fmt.shortDate(p.slotDestino)} ${Fmt.time(p.slotDestino)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(p.canal.icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(p.canal.label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.email_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  p.emailStatus.label +
                      (p.emailEnviadoEm != null
                          ? ' • ${Fmt.time(p.emailEnviadoEm!)}'
                          : ''),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: p.emailStatus.color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(p.motivoDestino,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(height: AppSpacing.sm),
            if (!concluida && !recusada)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (p.status == RealocacaoStatus.sugerida)
                    FilledButton.icon(
                      onPressed: () => notifier.enviarEmail(p.appointmentId),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Enviar e-mail'),
                    ),
                  if (p.status == RealocacaoStatus.aguardandoConfirmacao)
                    FilledButton.icon(
                      onPressed: () => notifier.aplicar(p.appointmentId,
                          confirmadoPeloPaciente: true),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Confirmar'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => notifier.aplicar(p.appointmentId),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Aplicar agora'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _trocarHorario(context),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                    label: const Text('Trocar horário'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        notifier.delegarAoServidor(p.appointmentId),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                    label: const Text('Delegar ao servidor'),
                  ),
                  TextButton(
                    onPressed: () => notifier.recusar(p.appointmentId),
                    child: const Text('Recusar'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(concluida ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: concluida ? AppColors.success : AppColors.danger),
                  const SizedBox(width: 6),
                  Text(concluida ? 'Realocação concluída' : 'Recusada',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              concluida ? AppColors.success : AppColors.danger)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => notifier.descartar(p.appointmentId),
                    child: const Text('Remover'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _trocarHorario(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: proposta.slotDestino,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(proposta.slotDestino),
    );
    if (time == null) return;
    notifier.alterarDestino(proposta.appointmentId,
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Widget _fromTo(BuildContext context,
      {required String from, required String to}) {
    return Row(
      children: [
        Expanded(child: _slotBox('DE', from, AppColors.danger)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(Icons.arrow_forward, size: 18),
        ),
        Expanded(child: _slotBox('PARA', to, AppColors.success)),
      ],
    );
  }

  Widget _slotBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _statusChip(RealocacaoStatus s) {
    final color = switch (s) {
      RealocacaoStatus.concluida => AppColors.success,
      RealocacaoStatus.recusada => AppColors.danger,
      RealocacaoStatus.expirada => AppColors.danger,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(s.label.toUpperCase(),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }
}

// ─────────────────────── Decisões / auditoria (OVB-06) ───────────────────────

class DecisionsTab extends ConsumerWidget {
  const DecisionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisoes = ref.watch(realocacaoProvider).decisoes;
    if (decisoes.isEmpty) {
      return const EmptyView(
        message:
            'Nenhuma decisão registrada ainda.\nGere e aplique realocações na aba anterior.',
        icon: Icons.history,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: decisoes.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final d = decisoes[i];
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: d.cor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(d.icon, size: 16, color: d.cor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(d.ator,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(width: 6),
                        Text('${Fmt.time(d.at)} • ${Fmt.shortDate(d.at)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textTertiary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(d.texto, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
