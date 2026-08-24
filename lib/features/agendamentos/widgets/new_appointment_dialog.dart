import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/doctor.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/patient.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';

/// A-02 — Agendamento manual (botão "+" da agenda). Formulário que cria um
/// [Appointment] real a partir dos pacientes/médicos da clínica ativa e o
/// adiciona à agenda via [appointmentsProvider].
class NewAppointmentDialog extends ConsumerStatefulWidget {
  const NewAppointmentDialog({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<NewAppointmentDialog> createState() =>
      _NewAppointmentDialogState();
}

class _NewAppointmentDialogState extends ConsumerState<NewAppointmentDialog> {
  // Seleções do formulário.
  Patient? _patient;
  Doctor? _doctor;
  String? _specialty;
  DateTime? _date;
  TimeOfDay? _time;
  String _tipo = 'Primeira Consulta';
  String _modalidade = 'Presencial';

  // Campos de texto controlados (auto-preenchidos ao escolher o paciente/médico).
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _value = TextEditingController();
  final _obs = TextEditingController();

  static const _defaultDuration = 30;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _cpf.dispose();
    _phone.dispose();
    _email.dispose();
    _value.dispose();
    _obs.dispose();
    super.dispose();
  }

  /// Data + hora combinadas (quando ambas foram escolhidas).
  DateTime? get _start {
    final d = _date;
    final t = _time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  bool get _isValid => _patient != null && _doctor != null && _start != null;

  void _onPatientChanged(Patient? p) {
    setState(() {
      _patient = p;
      _cpf.text = p?.cpf ?? '';
      _phone.text = p?.phone ?? '';
      _email.text = p?.email ?? '';
    });
  }

  void _onDoctorChanged(Doctor? d) {
    setState(() {
      _doctor = d;
      // Especialidade padrão = primeira do médico (ajustável se ele tiver várias).
      _specialty = d?.primarySpecialty;
      if (d != null && d.ticket > 0) {
        _value.text = _money(d.ticket);
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _finalize() {
    final patient = _patient;
    final doctor = _doctor;
    final start = _start;
    if (patient == null || doctor == null || start == null) return;

    final clinic = ref.read(selectedClinicProvider);
    final senha = _genSenha(_specialty ?? doctor.primarySpecialty);

    final appointment = Appointment(
      id: 'apt-${DateTime.now().millisecondsSinceEpoch}',
      clinicId: ref.read(selectedClinicIdProvider),
      patientId: patient.id,
      patientName: patient.name,
      doctorId: doctor.id,
      doctorName: doctor.name,
      specialty: _specialty ?? doctor.primarySpecialty,
      start: start,
      durationMinutes: _defaultDuration,
      status: AppointmentStatus.pending,
      tipoConsulta: _tipo,
      modalidade: _modalidade,
      motivo: _obs.text.trim(),
      observacoes: _obs.text.trim(),
      crm: doctor.crm,
      patientPhone: _phone.text.trim(),
      patientRisk: patient.riskLevel,
      firstVisit: _tipo == 'Primeira Consulta',
    );

    ref.read(appointmentsProvider.notifier).create(appointment);
    // Logística automática (mesma do totem): dispara e-mail (SendGrid) e
    // WhatsApp (Z-API) de confirmação. Não bloqueia o fechamento do diálogo.
    _sendConfirmations(
        appointment: appointment, clinicName: clinic.name, senha: senha);

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Consulta de ${patient.name} agendada para '
          '${Fmt.shortDate(start)} às ${Fmt.time(start)}. Senha: $senha.',
        ),
      ),
    );
  }

  /// Envia as confirmações transacionais via [EmailService] (e-mail SendGrid +
  /// WhatsApp Z-API), espelhando `_sendConfirmations` do totem. Fire-and-forget:
  /// os serviços nunca lançam e validam o destino (e-mail com `@`, telefone com
  /// DDI+DDD), então destinos vazios são simplesmente ignorados.
  void _sendConfirmations({
    required Appointment appointment,
    required String clinicName,
    required String senha,
  }) {
    final svc = ref.read(emailServiceProvider);
    final email = _email.text.trim();
    if (email.contains('@')) {
      svc.sendConfirmation(
        to: email,
        appointment: appointment,
        isReschedule: false,
        clinicName: clinicName,
        senha: senha,
      );
    }
    if (appointment.patientPhone.trim().isNotEmpty) {
      svc.sendWhatsappConfirmation(
        clinicaId: appointment.clinicId,
        phone: appointment.patientPhone,
        appointment: appointment,
        isReschedule: false,
        clinicName: clinicName,
        senha: senha,
        link: '',
      );
    }
  }

  /// Senha do totem: inicial da especialidade + 3 dígitos (ex.: "C123").
  String _genSenha(String specialty) {
    final s = specialty.trim();
    final letter = s.isNotEmpty ? s[0].toUpperCase() : 'A';
    return '$letter${100 + _rng.nextInt(900)}';
  }

  String _money(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isDark = theme.brightness == Brightness.dark;

    final patients = ref.watch(patientsProvider);
    // Médicos ativos da clínica selecionada; recai no catálogo global se a
    // clínica ainda não tem equipe cadastrada (offline/seed).
    var doctors =
        ref.watch(clinicDoctorsProvider).where((d) => d.active).toList();
    if (doctors.isEmpty) doctors = ref.watch(activeDoctorsProvider);

    final specialties = _doctor?.specialties ?? const <String>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        width: size.width > 1200 ? 1100 : size.width * 0.9,
        height: size.height * 0.9,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LADO ESQUERDO: Formulário
            Expanded(
              flex: 5,
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho / Identificação
                      _SectionContainer(
                        title: 'IDENTIFICAÇÃO DO PACIENTE',
                        subtitle: 'BUSCA NA BASE OU NOVO REGISTRO RÁPIDO',
                        icon: Icons.person_outline,
                        iconColor: Colors.pinkAccent,
                        isDarkHeader: true,
                        child: Column(
                          children: [
                            _LabeledDropdown<Patient>(
                              label: 'PACIENTE',
                              hint: 'Selecione o paciente...',
                              value: _patient,
                              items: [
                                for (final p in patients)
                                  DropdownMenuItem(value: p, child: Text(p.name)),
                              ],
                              onChanged: _onPatientChanged,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                    child: _TextField(
                                        label: 'DOCUMENTO CPF',
                                        hint: '000.000.000-00',
                                        icon: Icons.badge_outlined,
                                        controller: _cpf)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                    child: _TextField(
                                        label: 'WHATSAPP',
                                        hint: '(00) 00000-0000',
                                        icon: Icons.phone_outlined,
                                        controller: _phone,
                                        keyboardType: TextInputType.phone)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                    child: _TextField(
                                        label: 'E-MAIL',
                                        hint: 'paciente@exemplo.com',
                                        icon: Icons.email_outlined,
                                        controller: _email,
                                        keyboardType:
                                            TextInputType.emailAddress)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Especialista e Serviço
                      _SectionContainer(
                        title: 'ESPECIALISTA E SERVIÇO',
                        subtitle: 'DEFINA O PROFISSIONAL E A MODALIDADE',
                        icon: Icons.medical_services_outlined,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledDropdown<Doctor>(
                                    label: 'MÉDICO RESPONSÁVEL',
                                    hint: 'Selecionar Profissional...',
                                    value: _doctor,
                                    items: [
                                      for (final d in doctors)
                                        DropdownMenuItem(
                                            value: d, child: Text(d.name)),
                                    ],
                                    onChanged: _onDoctorChanged,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _TextField(
                                    label: 'VALOR DA CONSULTA',
                                    hint: 'R\$ 0,00',
                                    icon: Icons.attach_money,
                                    iconColor: Colors.pinkAccent,
                                    controller: _value,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledDropdown<String>(
                                    label: 'ESPECIALIDADE',
                                    hint: 'Selecione o médico...',
                                    value: specialties.contains(_specialty)
                                        ? _specialty
                                        : null,
                                    items: [
                                      for (final s in specialties)
                                        DropdownMenuItem(
                                            value: s, child: Text(s)),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _specialty = v),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _LabeledDropdown<String>(
                                    label: 'TIPO DE ATENDIMENTO',
                                    hint: 'Selecione...',
                                    value: _tipo,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Primeira Consulta',
                                          child: Text('Primeira Consulta')),
                                      DropdownMenuItem(
                                          value: 'Retorno',
                                          child: Text('Retorno')),
                                      DropdownMenuItem(
                                          value: 'Exame', child: Text('Exame')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _tipo = v ?? _tipo),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _LabeledDropdown<String>(
                                    label: 'MODALIDADE',
                                    hint: 'Selecione...',
                                    value: _modalidade,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Presencial',
                                          child: Text('Presencial')),
                                      DropdownMenuItem(
                                          value: 'Telemedicina',
                                          child: Text('Telemedicina')),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _modalidade = v ?? _modalidade),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Agenda e Horário
                      _SectionContainer(
                        title: 'AGENDA E HORÁRIO',
                        subtitle: 'MOMENTO DA CONSULTA E NOTAS',
                        icon: Icons.access_time,
                        iconColor: Colors.white,
                        headerColor: Colors.pinkAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickDate,
                                    child: _TextField(
                                      label: 'DATA',
                                      hint: 'Escolha a data',
                                      icon: Icons.calendar_today_outlined,
                                      iconColor: Colors.pinkAccent,
                                      enabled: false,
                                      valueText: _date != null
                                          ? Fmt.shortDate(_date!)
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickTime,
                                    child: _TextField(
                                      label: 'HORÁRIO',
                                      hint: 'Escolha a hora',
                                      icon: Icons.schedule,
                                      iconColor: Colors.pinkAccent,
                                      enabled: false,
                                      valueText: _time?.format(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Text('OBSERVAÇÕES DO AGENDAMENTO',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textTertiary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _obs,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText:
                                    'Descreva brevemente o motivo da consulta ou notas importantes...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.borderDark
                                          : AppColors.border),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // LADO DIREITO: Resumo
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF1E1E24)),
                child: Stack(
                  children: [
                    Positioned(
                      top: 40,
                      right: -20,
                      child: Icon(Icons.check_circle,
                          size: 200,
                          color: Colors.white.withValues(alpha: 0.03)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RESUMO DO AGENDAMENTO',
                              style: TextStyle(
                                  color: Colors.pinkAccent,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  fontSize: 12)),
                          const SizedBox(height: AppSpacing.xl),
                          _SummaryItem(
                              icon: Icons.person_outline,
                              title: 'PACIENTE',
                              value: _patient?.name ?? 'Aguardando seleção...'),
                          _SummaryItem(
                              icon: Icons.medical_services_outlined,
                              title: 'PROFISSIONAL',
                              value: _doctor != null
                                  ? '${_doctor!.name}  •  ${_specialty ?? _doctor!.primarySpecialty}'
                                  : 'Aguardando seleção...'),
                          _SummaryItem(
                              icon: Icons.calendar_today_outlined,
                              title: 'DATA E HORA',
                              value: _start != null
                                  ? '${Fmt.shortDate(_start!)} às ${Fmt.time(_start!)}'
                                  : 'Não definido'),
                          _SummaryItem(
                              icon: Icons.attach_money,
                              title: 'VALOR PREVISTO',
                              value: _value.text.trim().isEmpty
                                  ? 'R\$ 0,00'
                                  : _value.text.trim(),
                              isHighlighted: true),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14,
                                        color:
                                            Colors.white.withValues(alpha: 0.5)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text('LOGÍSTICA AUTOMÁTICA',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.5),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _LogisticBullet('Envio de E-mail Transacional'),
                                _LogisticBullet(
                                    'Geração de Senha de Totem (pass)'),
                                _LogisticBullet('Bloqueio de Agenda do Médico'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25)),
                              ),
                              onPressed: _isValid ? _finalize : null,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_outline, size: 18),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text('FINALIZAR AGENDAMENTO',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                  foregroundColor:
                                      Colors.white.withValues(alpha: 0.6)),
                              child: const Text('DESCARTAR E VOLTAR',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// COMPONENTES AUXILIARES

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.isDarkHeader = false,
    this.iconColor,
    this.headerColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final bool isDarkHeader;
  final Color? iconColor;
  final Color? headerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headerColor ?? (isDarkHeader ? const Color(0xFF1E1E24) : null),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDarkHeader ? Colors.pinkAccent.withValues(alpha: 0.2) : theme.scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: headerColor != null || isDarkHeader ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: headerColor != null || isDarkHeader ? Colors.white.withValues(alpha: 0.6) : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (headerColor == null && !isDarkHeader)
            Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.hint,
    this.icon,
    this.iconColor,
    this.enabled = true,
    this.controller,
    this.valueText,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final IconData? icon;
  final Color? iconColor;
  final bool enabled;
  final TextEditingController? controller;

  /// Texto exibido quando o campo é somente-leitura (ex.: data/hora escolhida).
  final String? valueText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
        const SizedBox(height: 8),
        // Campos somente-leitura (data/hora) usam um TextField com `controller`
        // baseado em texto para refletir a seleção sem manter foco/edição.
        TextField(
          controller: controller ??
              (valueText != null ? TextEditingController(text: valueText) : null),
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, color: iconColor ?? AppColors.border, size: 18) : null,
            filled: true,
            fillColor: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          ),
        ),
      ],
    );
  }
}

/// Dropdown rotulado genérico (paciente, médico, especialidade, etc.) no mesmo
/// estilo visual dos campos de texto do formulário.
class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.value,
  });

  final String label;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.icon, required this.title, required this.value, this.isHighlighted = false});
  final IconData icon;
  final String title;
  final String value;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isHighlighted ? Colors.white : Colors.white.withValues(alpha: 0.8),
                    fontSize: isHighlighted ? 16 : 14,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogisticBullet extends StatelessWidget {
  const _LogisticBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.success),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
