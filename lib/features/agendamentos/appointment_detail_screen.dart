import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/appointment.dart';
import '../../core/models/clinic.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/clinic_map.dart';
import '../../core/widgets/status_badge.dart';

/// A-02 / A-03 — Detalhe da consulta e ações (confirmar/cancelar/reagendar).
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appointments = ref.watch(appointmentsProvider);
    final match = appointments.where((a) => a.id == appointmentId);

    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes da Consulta')),
        body: const Center(child: Text('Consulta não encontrada.')),
      );
    }
    final a = match.first;

    // Dados completos da clínica e do profissional vinculados à consulta.
    final clinicMatch = ref.watch(clinicsProvider).where((c) => c.id == a.clinicId);
    final Clinic? clinic = clinicMatch.isEmpty ? null : clinicMatch.first;
    final doctorMatch = ref.watch(doctorsProvider).where((d) => d.id == a.doctorId);
    final Doctor? doctor = doctorMatch.isEmpty ? null : doctorMatch.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Consulta'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      bottomNavigationBar: _ActionBar(appointment: a),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge.appointment(a.status),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.dayMonth(a.start), style: theme.textTheme.bodyMedium),
                  Text(Fmt.time(a.start), style: theme.textTheme.headlineSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Paciente
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PACIENTE',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    AppAvatar(initials: _initials(a.patientName), radius: 26),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.patientName, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          StatusBadge.risk(a.patientRisk, prefix: 'Risco de faltas: '),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366)),
                        onPressed: () => _snack(context, 'Abrindo WhatsApp…'),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _snack(context, 'Ligando…'),
                        icon: const Icon(Icons.call),
                        label: const Text('Ligar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Profissional
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PROFISSIONAL',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    AppAvatar(
                      initials: _initials(a.doctorName),
                      imageUrl: doctor?.photoUrl,
                      radius: 24,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.doctorName, style: theme.textTheme.titleMedium),
                          Text(
                              doctor != null && doctor.specialties.isNotEmpty
                                  ? doctor.specialties.join(' • ')
                                  : a.specialty,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                _infoRow(context, Icons.badge_outlined, 'CRM',
                    (doctor?.crm.isNotEmpty ?? false) ? doctor!.crm : (a.crm.isEmpty ? '—' : a.crm)),
                if (doctor?.phone != null && doctor!.phone!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _infoRow(context, Icons.phone_outlined, 'Telefone', doctor.phone!),
                ],
                if (doctor?.email != null && doctor!.email!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _infoRow(context, Icons.email_outlined, 'E-mail', doctor.email!),
                ],
                const SizedBox(height: AppSpacing.sm),
                _infoRow(context, Icons.location_on_outlined, 'Unidade',
                    a.local.isEmpty ? (clinic?.name ?? '—') : a.local),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Clínica — dados completos + mapa de localização
          if (clinic != null) ...[
            _ClinicCard(clinic: clinic),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Informações da consulta
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INFORMAÇÕES DA CONSULTA',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                _labelValue(context, 'Tipo de atendimento', a.tipoConsulta),
                const SizedBox(height: AppSpacing.md),
                _labelValue(context, 'Modalidade', a.modalidade),
                const SizedBox(height: AppSpacing.md),
                _labelValue(
                    context, 'Duração estimada', Fmt.duration(a.durationMinutes)),
                if (a.motivo.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _labelValue(context, 'Motivo', a.motivo),
                ],
              ],
            ),
          ),

          // Preparo e instruções
          if (a.preparo.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: AppColors.infoLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.assignment_outlined,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('PREPARO E INSTRUÇÕES',
                          style: TextStyle(
                              letterSpacing: 1,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final p in a.preparo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(p, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext c, IconData icon, String label, String value) {
    final t = Theme.of(c).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: t.bodyMedium),
        ]),
        Text(value, style: t.titleMedium),
      ],
    );
  }

  Widget _labelValue(BuildContext c, String label, String value) {
    final t = Theme.of(c).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: t.titleMedium),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name.substring(0, name.length >= 2 ? 2 : 1);
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static void _snack(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}

/// Cartão com os dados completos da clínica vinculada à consulta e o mapa de
/// localização (Google Maps) quando há coordenadas cadastradas.
class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.clinic});
  final Clinic clinic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addr = clinic.address.formatted;
    final hours = clinic.businessHours;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CLÍNICA',
              style: theme.textTheme.bodySmall
                  ?.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppAvatar(
                initials: _clinicInitials(clinic.name),
                imageUrl: clinic.photoUrl,
                radius: 24,
                color: clinic.type.color,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clinic.name, style: theme.textTheme.titleMedium),
                    Text(clinic.type.description,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: clinic.type.color)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          if (clinic.razaoSocial != null && clinic.razaoSocial!.isNotEmpty) ...[
            _infoRow(context, Icons.business_outlined, 'Razão social',
                clinic.razaoSocial!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (clinic.cnpj != null && clinic.cnpj!.isNotEmpty) ...[
            _infoRow(context, Icons.assignment_ind_outlined, 'CNPJ',
                clinic.cnpj!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (addr.isNotEmpty) ...[
            _infoRow(context, Icons.location_on_outlined, 'Endereço', addr),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (clinic.phone != null && clinic.phone!.isNotEmpty) ...[
            _infoRow(context, Icons.phone_outlined, 'Telefone', clinic.phone!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (clinic.email != null && clinic.email!.isNotEmpty) ...[
            _infoRow(context, Icons.email_outlined, 'E-mail', clinic.email!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (clinic.website != null && clinic.website!.isNotEmpty) ...[
            _infoRow(context, Icons.language_outlined, 'Site', clinic.website!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (hours.isNotEmpty) ...[
            _infoRow(context, Icons.schedule_outlined, 'Horário',
                _hoursSummary(hours)),
          ],
          if (clinic.specialties.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Especialidades',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in clinic.specialties) Chip(label: Text(s)),
              ],
            ),
          ],
          if (clinic.hasLocation) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Localização', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            ClinicMap(
              latitude: clinic.latitude!,
              longitude: clinic.longitude!,
              label: clinic.name,
            ),
          ],
        ],
      ),
    );
  }

  static String _clinicInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _hoursSummary(List<BusinessHour> hours) {
    final open = hours.where((h) => !h.closed).toList();
    if (open.isEmpty) return 'Fechado';
    final first = open.first;
    final allSame = open.every((h) => h.open == first.open && h.close == first.close);
    if (allSame) {
      return '${first.weekdayLabel}–${open.last.weekdayLabel}, ${first.open}–${first.close}';
    }
    return '${first.weekdayLabel} ${first.open}–${first.close} …';
  }

  Widget _infoRow(BuildContext c, IconData icon, String label, String value) {
    final t = Theme.of(c).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: t.bodyMedium),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(value,
              style: t.titleMedium, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

/// Tipo de notificação ao paciente disparada pela barra de ações.
enum _NotifyKind { schedule, reschedule, cancel }

/// A-03 — barra de ações com confirmação via modal.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appointmentsProvider.notifier);
    final a = appointment;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a.status != AppointmentStatus.cancelled)
              TextButton.icon(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Cancelar consulta',
                  message: 'Deseja realmente cancelar a consulta de ${a.patientName}?',
                  confirmLabel: 'Cancelar consulta',
                  danger: true,
                  onConfirm: () {
                    notifier.setStatus(a.id, AppointmentStatus.cancelled);
                    _notify(ref, a, _NotifyKind.cancel);
                    _snack(context,
                        'Consulta cancelada. Paciente notificado por e-mail e WhatsApp.');
                  },
                ),
                icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                label: const Text('Cancelar',
                    style: TextStyle(color: AppColors.danger)),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reschedule(context, ref),
                    child: const Text('Reagendar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmAction(
                      context,
                      title: a.status == AppointmentStatus.confirmed
                          ? 'Fazer check-in'
                          : 'Confirmar consulta',
                      message: 'Confirmar presença de ${a.patientName}?',
                      confirmLabel: 'Confirmar',
                      onConfirm: () {
                        final isCheckIn =
                            a.status == AppointmentStatus.confirmed;
                        notifier.setStatus(
                          a.id,
                          isCheckIn
                              ? AppointmentStatus.completed
                              : AppointmentStatus.confirmed,
                        );
                        // Confirmar a consulta (marcar) notifica o paciente; o
                        // check-in (presença) apenas atualiza o status.
                        if (!isCheckIn) {
                          _notify(ref, a, _NotifyKind.schedule);
                          _snack(context,
                              'Consulta confirmada. Paciente notificado por e-mail e WhatsApp.');
                        } else {
                          _snack(context, 'Check-in realizado.');
                        }
                      },
                    ),
                    child: Text(a.status == AppointmentStatus.confirmed
                        ? 'Fazer Check-in'
                        : 'Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _reschedule(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: appointment.start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appointment.start),
    );
    if (time == null || !context.mounted) return;
    final newStart =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    ref.read(appointmentsProvider.notifier).reschedule(appointment.id, newStart);
    // Notifica com o novo horário (status passa a pré-agendado).
    final updated = appointment.copyWith(
        start: newStart, status: AppointmentStatus.pending);
    _notify(ref, updated, _NotifyKind.reschedule);
    _snack(context,
        'Consulta reagendada para ${Fmt.dayMonth(newStart)} ${Fmt.time(newStart)}. Paciente notificado.');
  }

  /// Dispara (sem bloquear a UI) as notificações ao paciente conforme a ação:
  /// confirmação/remarcação enviam e-mail + WhatsApp de confirmação; o
  /// cancelamento envia e-mail + WhatsApp de cancelamento. O e-mail usa a Cloud
  /// Function `sendConfirmationEmail`; o WhatsApp usa o proxy Z-API.
  void _notify(WidgetRef ref, Appointment appt, _NotifyKind kind) {
    final svc = ref.read(emailServiceProvider);

    // E-mail/telefone do paciente (resolve pelo cadastro; cai no telefone do
    // próprio agendamento quando o paciente não tem telefone no perfil).
    final pMatch =
        ref.read(patientsProvider).where((p) => p.id == appt.patientId);
    final patient = pMatch.isEmpty ? null : pMatch.first;
    final email = (patient?.email ?? '').trim();
    final phone = appt.patientPhone.trim().isNotEmpty
        ? appt.patientPhone
        : (patient?.phone ?? '');

    // Nome da clínica vinculada à consulta.
    final cMatch = ref.read(clinicsProvider).where((c) => c.id == appt.clinicId);
    final clinicName =
        cMatch.isEmpty ? ref.read(selectedClinicProvider).name : cMatch.first.name;

    switch (kind) {
      case _NotifyKind.cancel:
        if (email.contains('@')) {
          svc.sendCancellation(
              to: email, appointment: appt, clinicName: clinicName);
        }
        if (phone.trim().isNotEmpty) {
          svc.sendWhatsappCancellation(
              clinicaId: appt.clinicId,
              phone: phone,
              appointment: appt,
              clinicName: clinicName);
        }
      case _NotifyKind.schedule:
      case _NotifyKind.reschedule:
        final isReschedule = kind == _NotifyKind.reschedule;
        if (email.contains('@')) {
          svc.sendConfirmation(
              to: email,
              appointment: appt,
              isReschedule: isReschedule,
              clinicName: clinicName);
        }
        if (phone.trim().isNotEmpty) {
          svc.sendWhatsappConfirmation(
              clinicaId: appt.clinicId,
              phone: phone,
              appointment: appt,
              isReschedule: isReschedule,
              clinicName: clinicName,
              link: '');
        }
    }
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    bool danger = false,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
          ElevatedButton(
            style: danger
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}
