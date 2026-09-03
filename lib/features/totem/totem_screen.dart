import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/app_user.dart';
import '../../core/models/appointment.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../overbooking/occupancy.dart';
import 'models/totem_config.dart';
import 'providers/totem_config_provider.dart';
import 'totem_booking.dart';
import 'widgets/totem_config_panel.dart';

const _kBrand = Color(0xFFFF3B30);
const _kAccent = Color(0xFF23BAD4);
const _kInk = Color(0xFF11151C);

enum _Step { welcome, searchCpf, chooseAppt, schedule, confirm, success }

enum _Mode { agendar, remarcar }

enum _ConfirmStep { cpf, form, confirm }

/// Horário com ocupação dinâmica (overbooking inteligente, §1).
class _Slot {
  const _Slot({
    required this.time,
    required this.doctor,
    required this.booked,
    required this.capacity,
  });
  final String time;
  final Doctor doctor;
  final int booked;
  final int capacity;

  /// Capacidade normalizada (>= 1): evita divisão por zero e o falso "LOTADO"
  /// quando a config zera a capacidade (ver OVERBOOKING.md §B3).
  int get _cap => capacity < 1 ? 1 : capacity;
  double get ratio => OccupancyLevel.ratio(booked: booked, capacity: _cap);
  OccupancyLevel get level =>
      OccupancyLevel.from(booked: booked, capacity: _cap);
  bool get full => level.isFull;
  int get remaining => (_cap - booked) < 0 ? 0 : _cap - booked;
}

/// Totem de autoatendimento — agendamento/remarcação de consultas (porte do
/// fluxo Next.js de referência: welcome → schedule → confirm (CPF/cadastro) →
/// success com senha e comprovante). Sessão expira por inatividade (2 min).
class TotemScreen extends ConsumerStatefulWidget {
  const TotemScreen({super.key});

  @override
  ConsumerState<TotemScreen> createState() => _TotemScreenState();
}

class _TotemScreenState extends ConsumerState<TotemScreen> {
  final _rng = Random();

  /// Lógica de agendamento isolada (ids únicos, senha sem colisão, recheck de
  /// capacidade) — ver `totem_booking.dart` e `TESTE-SISTER/`.
  final _booking = TotemBooking();

  /// Senhas de fila já emitidas nesta sessão do totem — evita duas iguais.
  final Set<String> _emittedSenhas = {};

  Timer? _clock;
  DateTime _now = DateTime.now();

  // --- session (inatividade)
  TotemConfig get _tc => ref.read(totemConfigProvider);
  int get _sessionMax => _tc.sessionTimeout;
  int get _warnAt => _tc.warningSeconds;
  int _session = 120;
  bool _warning = false;

  // --- flow
  _Step _step = _Step.welcome;
  _Mode _mode = _Mode.agendar;

  // schedule
  String _specialty = 'Todos';
  late DateTime _date;
  String? _doctorFilter;
  String? _selTime;
  Doctor? _selDoctor;

  // searchCpf / remarcar
  String _searchCpfVal = '';
  Appointment? _reschedAppt; // agendamento existente a ser remarcado
  List<Appointment> _reschedOptions = []; // consultas ativas do paciente (remarcar)

  // confirm
  _ConfirmStep _cStep = _ConfirmStep.cpf;
  final _cpfCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  AppUser? _found;
  bool _busy = false;

  // success
  String? _senha;
  Appointment? _appt;
  bool _testMode = false;
  // `true` só quando um agendamento existente foi de fato movido — o modo
  // Remarcar pode terminar criando uma consulta NOVA (paciente sem consulta
  // ativa), e a tela de sucesso precisa refletir o que aconteceu.
  bool _wasReschedule = false;

  static const _weekdaysShort = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  static const _weekdaysLong = [
    'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira',
    'sexta-feira', 'sábado', 'domingo'
  ];
  static const _months = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
    'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
  ];

  @override
  void initState() {
    super.initState();
    _date = _startOfDay(DateTime.now());
    _specialty = _tc.defaultSpecialty;
    _session = _tc.sessionTimeout;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      var expired = false;
      setState(() {
        _now = DateTime.now();
        if (_step == _Step.welcome) {
          _session = _sessionMax;
          _warning = false;
          return;
        }
        // Na tela de sucesso, retorna automaticamente em successAutoReturn.
        if (_step == _Step.success && _session > _tc.successAutoReturn) {
          _session = _tc.successAutoReturn;
        }
        _session--;
        if (_session <= 0) {
          expired = true;
        } else {
          _warning = _step != _Step.success && _session <= _warnAt;
        }
      });
      if (expired) _reset();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    for (final c in [_cpfCtrl, _nameCtrl, _emailCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- helpers
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _bump() {
    _session = _sessionMax;
    if (_warning) setState(() => _warning = false);
  }

  void _reset() {
    // Fecha diálogos/pickers abertos (limite, tutorial, calendário) para não
    // ficarem órfãos sobre a tela de boas-vindas quando a sessão expira.
    Navigator.of(context).popUntil((r) => r is! RawDialogRoute);
    setState(() {
      _step = _Step.welcome;
      _specialty = _tc.defaultSpecialty;
      _date = _startOfDay(DateTime.now());
      _doctorFilter = null;
      _selTime = null;
      _selDoctor = null;
      _cStep = _ConfirmStep.cpf;
      _found = null;
      _busy = false;
      _senha = null;
      _appt = null;
      _testMode = false;
      _wasReschedule = false;
      _searchCpfVal = '';
      _reschedAppt = null;
      _reschedOptions = [];
      _session = _sessionMax;
      _warning = false;
      for (final c in [_cpfCtrl, _nameCtrl, _emailCtrl, _phoneCtrl]) {
        c.clear();
      }
    });
  }

  List<String> _specialties() {
    final set = <String>{};
    for (final d in ref.read(clinicDoctorsProvider).where((d) => d.active)) {
      set.addAll(d.specialties);
    }
    return ['Todos', ...set.toList()..sort()];
  }

  /// Especialidades **mais procuradas** (sugestões rápidas): conta os
  /// agendamentos ativos por especialidade e devolve as mais frequentes que
  /// ainda existem no corpo clínico (filtro válido), da maior para a menor.
  List<String> _topSpecialties({int max = 4}) {
    final counts = <String, int>{};
    for (final a in ref.read(appointmentsProvider)) {
      if (a.status == AppointmentStatus.cancelled) continue;
      final s = a.specialty.trim();
      if (s.isEmpty) continue;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final valid = <String>{};
    for (final d in ref.read(clinicDoctorsProvider).where((d) => d.active)) {
      valid.addAll(d.specialties);
    }
    final ranked = counts.keys.where(valid.contains).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return ranked.take(max).toList();
  }

  /// Gera os horários com **ocupação dinâmica** (overbooking §1): conta os
  /// agendamentos ativos por slot e calcula a capacidade do médico no horário.
  List<_Slot> _buildSlots() {
    final wd = _date.weekday; // 1 Mon .. 7 Sun
    if (wd == DateTime.sunday && !_tc.openSunday) return [];
    if (wd == DateTime.saturday && !_tc.openSaturday) return [];
    final endHour =
        wd == DateTime.saturday ? _tc.saturdayCloseHour : _tc.closeHour;
    // Grade no passo da duração da consulta (antes era fixa de hora em hora,
    // o que desperdiçava metade da agenda com consultas de 30 min). O slot só
    // entra se a consulta inteira couber antes do fechamento.
    final step = _tc.appointmentDuration < 5 ? 5 : _tc.appointmentDuration;
    final openMin = _tc.openHour * 60;
    String hhmm(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    final times = [
      for (var m = openMin; m + step <= endHour * 60; m += step)
        // Pula o intervalo de almoço quando configurado.
        if (!(_tc.lunchBreakEnabled &&
            (m ~/ 60) >= _tc.lunchStartHour &&
            (m ~/ 60) < _tc.lunchEndHour))
          hhmm(m)
    ];

    final doctors = ref.read(clinicDoctorsProvider).where((d) {
      if (!d.active) return false;
      return _specialty == 'Todos' || d.specialties.contains(_specialty);
    }).toList();

    // Conta agendamentos ATIVOS (não cancelados) por "HH:mm-doctorId" na data,
    // ancorando cada consulta no slot da grade que a contém — uma consulta às
    // 09:15 numa grade de 30 min ocupa o slot 09:00 (antes, horários fora de
    // HH:00 não contavam na ocupação de slot nenhum).
    final bookedCount = <String, int>{};
    for (final a in ref.read(appointmentsProvider)) {
      if (!_sameDay(a.start, _date)) continue;
      if (a.status == AppointmentStatus.cancelled) continue;
      // A consulta sendo remarcada vai liberar o horário atual — não deve
      // contar na ocupação (senão o próprio slot aparece mais cheio/LOTADO).
      if (_reschedAppt != null && a.id == _reschedAppt!.id) continue;
      final startMin = a.start.hour * 60 + a.start.minute;
      if (startMin < openMin) continue;
      final t = hhmm(openMin + ((startMin - openMin) ~/ step) * step);
      final key = '$t-${a.doctorId}';
      bookedCount[key] = (bookedCount[key] ?? 0) + 1;
    }

    final isToday = _sameDay(_date, DateTime.now());
    final nowMin = _now.hour * 60 + _now.minute;
    final slots = <_Slot>[];
    for (final doc in doctors) {
      for (final t in times) {
        if (isToday) {
          final m =
              int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));
          if (m <= nowMin) continue; // não mostra horários passados hoje
        }
        final booked = bookedCount['$t-${doc.id}'] ?? 0;
        final capacity = doc.capacityAt(wd, t);
        slots.add(_Slot(
            time: t, doctor: doc, booked: booked, capacity: capacity));
      }
    }
    slots.sort((a, b) => a.time.compareTo(b.time));
    return slots;
  }

  /// Valida o CPF pelos dígitos verificadores (rejeita sequências repetidas).
  static bool _isValidCpf(String digits) {
    if (digits.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
    int dv(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += int.parse(digits[i]) * (len + 1 - i);
      }
      final mod = (sum * 10) % 11;
      return mod == 10 ? 0 : mod;
    }

    return dv(9) == int.parse(digits[9]) && dv(10) == int.parse(digits[10]);
  }

  String _genSenha(String specialty) {
    final s = _booking.senha(specialty, taken: _emittedSenhas);
    _emittedSenhas.add(s);
    return s;
  }

  // ------------------------------------------------------------- actions
  void _start(_Mode mode) {
    setState(() {
      _mode = mode;
      _step = mode == _Mode.remarcar ? _Step.searchCpf : _Step.schedule;
      _searchCpfVal = '';
      _session = _sessionMax;
    });
    _bump();
  }

  void _pickSpecialty(String s) {
    setState(() {
      _specialty = s;
      _selTime = null;
      _selDoctor = null;
      _doctorFilter = null;
    });
    _bump();
  }

  void _selectSlot(_Slot slot) {
    if (slot.full) return; // horário lotado (capacidade + overbook atingida)
    setState(() {
      _selTime = slot.time;
      _selDoctor = slot.doctor;
      _doctorFilter = slot.doctor.id;
    });
    _bump();
  }

  void _goConfirm() {
    if (_selTime == null || _selDoctor == null) return;
    setState(() {
      _step = _Step.confirm;
      // No Remarcar o paciente já foi identificado pelo CPF — pula a etapa.
      _cStep = (_mode == _Mode.remarcar && _found != null)
          ? _ConfirmStep.confirm
          : _ConfirmStep.cpf;
    });
    _bump();
  }

  /// Remarcar: busca o paciente pelo CPF e localiza o agendamento ativo dele.
  Future<void> _searchByCpf() async {
    if (_searchCpfVal.length != 11) return;
    if (!_isValidCpf(_searchCpfVal)) {
      _snack('CPF inválido. Confira os dígitos informados.');
      return;
    }
    setState(() => _busy = true);
    AppUser? user;
    try {
      user = await ref.read(userServiceProvider).fetchByCpf(_searchCpfVal);
    } catch (_) {
      user = null;
    }
    if (!mounted) return;
    if (user == null) {
      setState(() => _busy = false);
      _snack('Nenhum cadastro encontrado para este CPF.');
      return;
    }
    final u = user;
    // Busca TODAS as consultas do paciente, independente da data (sem filtro de
    // tempo). Exclui apenas as canceladas/concluídas (não fazem sentido para
    // remarcar). Ordena pelas mais próximas/futuras primeiro.
    final actives = ref
        .read(appointmentsProvider)
        .where((a) =>
            a.status != AppointmentStatus.cancelled &&
            a.status != AppointmentStatus.completed &&
            (a.patientId == u.id ||
                a.patientName.toLowerCase() == u.fullName.toLowerCase()))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    setState(() {
      _busy = false;
      _found = u;
      _reschedOptions = actives;
      if (actives.isEmpty) {
        // Sem consultas ativas: segue para criar uma nova.
        _reschedAppt = null;
        _step = _Step.schedule;
      } else if (actives.length == 1) {
        // Uma só consulta: já segue direto para escolher o novo horário.
        _reschedAppt = actives.first;
        _step = _Step.schedule;
      } else {
        // Várias consultas: o paciente escolhe qual remarcar.
        _reschedAppt = null;
        _step = _Step.chooseAppt;
      }
    });
    if (actives.isEmpty) {
      _snack('Nenhum agendamento ativo encontrado — você pode criar um novo.');
    }
    _bump();
  }

  /// Seleciona qual consulta o paciente quer remarcar (quando há mais de uma).
  void _pickReschedule(Appointment appt) {
    setState(() {
      _reschedAppt = appt;
      _specialty = 'Todos';
      _selTime = null;
      _selDoctor = null;
      _doctorFilter = null;
      _step = _Step.schedule;
    });
    _bump();
  }

  Future<void> _checkCpf() async {
    final digits = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      _snack('Informe um CPF válido (11 dígitos).');
      return;
    }
    if (!_isValidCpf(digits)) {
      _snack('CPF inválido. Confira os dígitos informados.');
      return;
    }
    setState(() => _busy = true);
    AppUser? user;
    try {
      user = await ref.read(userServiceProvider).fetchByCpf(digits);
    } catch (_) {
      user = null;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (user != null) {
        _found = user;
        _cStep = _ConfirmStep.confirm;
      } else if (_tc.allowGuestScheduling) {
        _found = null;
        _cStep = _ConfirmStep.form;
        _snack('CPF não encontrado. Complete o cadastro.');
      } else {
        _found = null;
        _snack('CPF não encontrado. Procure a recepção para se cadastrar.');
      }
    });
    _bump();
  }

  Future<void> _confirmExisting() async {
    final p = _found!;
    if (_mode == _Mode.remarcar && _reschedAppt != null) {
      await _doReschedule();
      return;
    }
    await _createAppointment(
      patientId: p.id,
      name: p.fullName,
      phone: p.phone ?? '',
      email: p.email,
    );
  }

  /// Move o agendamento existente para o novo horário/médico (remarcação).
  Future<void> _doReschedule() async {
    final appt = _reschedAppt!;
    final doctor = _selDoctor!;
    final parts = _selTime!.split(':');
    final start = DateTime(_date.year, _date.month, _date.day,
        int.parse(parts[0]), int.parse(parts[1]));
    final specialty =
        _specialty != 'Todos' ? _specialty : doctor.primarySpecialty;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    ref.read(appointmentsProvider.notifier).move(
          appt.id,
          start: start,
          doctorId: doctor.id,
          doctorName: doctor.name,
          specialty: specialty,
          crm: doctor.crm,
        );

    if (!mounted) return;
    final senha = _genSenha(specialty);
    final updated = appt.copyWith(
      start: start,
      doctorId: doctor.id,
      doctorName: doctor.name,
      specialty: specialty,
      crm: doctor.crm,
    );
    _sendConfirmations(
        email: _found?.email, appt: updated, senha: senha, isReschedule: true);
    setState(() {
      _busy = false;
      _senha = senha;
      _appt = updated;
      _testMode = false;
      _wasReschedule = true;
      _step = _Step.success;
    });
  }

  Future<void> _submitNew() async {
    if (_nameCtrl.text.trim().length < 3) {
      _snack('Informe o nome completo.');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('E-mail inválido. Corrija ou deixe em branco.');
      return;
    }
    if (_tc.requirePhone && _phoneCtrl.text.trim().length < 8) {
      _snack('Informe um telefone para contato.');
      return;
    }
    await _createAppointment(
      patientId: _booking.newGuestPatientId(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
  }

  /// Consultas ativas (não canceladas/concluídas) do paciente, casadas por id
  /// OU por nome (cobre também cadastros novos feitos pelo totem).
  List<Appointment> _activeAppointmentsOf(String patientId, String name) {
    final n = name.trim().toLowerCase();
    return ref
        .read(appointmentsProvider)
        .where((a) =>
            a.status != AppointmentStatus.cancelled &&
            a.status != AppointmentStatus.completed &&
            (a.patientId == patientId ||
                (n.isNotEmpty && a.patientName.trim().toLowerCase() == n)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Regras anti-abuso: limita quantas consultas o mesmo paciente pode marcar.
  /// Retorna a mensagem de bloqueio, ou `null` se o agendamento é permitido.
  String? _bookingLimitMessage({
    required String patientId,
    required String name,
    required DateTime day,
  }) {
    final mine = _activeAppointmentsOf(patientId, name);

    if (_tc.maxPerDay > 0) {
      final sameDay = mine.where((a) => _sameDay(a.start, day)).length;
      if (sameDay >= _tc.maxPerDay) {
        return _tc.maxPerDay == 1
            ? 'Você já tem uma consulta marcada para este dia. Não é possível '
                'agendar outra na mesma data.'
            : 'Limite de ${_tc.maxPerDay} consultas por dia atingido para este '
                'paciente.';
      }
    }
    if (_tc.maxActivePerPatient > 0) {
      final now = DateTime.now();
      final active = mine.where((a) => a.start.isAfter(now)).length;
      if (active >= _tc.maxActivePerPatient) {
        return 'Você já tem ${_tc.maxActivePerPatient} consultas ativas. '
            'Compareça ou cancele uma antes de agendar outra.';
      }
    }
    return null;
  }

  /// Quando um limite é atingido, mostra um diálogo. Se o paciente já tem
  /// consultas ativas, oferece **remarcar** a existente (evita duplicar e
  /// bagunçar a agenda) em vez de só bloquear.
  void _showLimitDialog(String message,
      {required String patientId, required String name}) {
    final mine = _activeAppointmentsOf(patientId, name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limite de agendamentos'),
        content: Text(message),
        actions: [
          if (mine.isNotEmpty)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _startRescheduleFor(mine);
              },
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text('Remarcar existente'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    _bump();
  }

  /// Redireciona o fluxo para a remarcação das consultas informadas.
  void _startRescheduleFor(List<Appointment> appts) {
    setState(() {
      _mode = _Mode.remarcar;
      _reschedOptions = appts;
      _specialty = 'Todos';
      _selTime = null;
      _selDoctor = null;
      _doctorFilter = null;
      if (appts.length == 1) {
        _reschedAppt = appts.first;
        _step = _Step.schedule;
      } else {
        _reschedAppt = null;
        _step = _Step.chooseAppt;
      }
    });
    _bump();
  }

  Future<void> _createAppointment({
    required String patientId,
    required String name,
    required String phone,
    String? email,
  }) async {
    // Remarcação em andamento: move a consulta existente em vez de criar uma
    // nova (cobre também o caminho do formulário de convidado, que antes
    // duplicava o agendamento e esbarrava de novo no limite anti-abuso).
    if (_mode == _Mode.remarcar && _reschedAppt != null) {
      await _doReschedule();
      return;
    }
    final doctor = _selDoctor!;
    final parts = _selTime!.split(':');
    final start = DateTime(_date.year, _date.month, _date.day,
        int.parse(parts[0]), int.parse(parts[1]));

    // Regras anti-abuso (limites configuráveis por paciente).
    final block =
        _bookingLimitMessage(patientId: patientId, name: name, day: start);
    if (block != null) {
      _showLimitDialog(block, patientId: patientId, name: name);
      return;
    }

    final specialty =
        _specialty != 'Todos' ? _specialty : doctor.primarySpecialty;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Revalida a capacidade do slot AGORA (F3): entre a seleção do horário e
    // esta confirmação, outras pessoas (outros totens/abas) podem ter ocupado
    // as últimas vagas. Sem transação no servidor, esta é a última barreira.
    final bookedNow = TotemBooking.bookedInSlot(
      appointments: ref.read(appointmentsProvider),
      date: _date,
      doctorId: doctor.id,
      slotTime: _selTime!,
      appointmentDuration: _tc.appointmentDuration,
      openHour: _tc.openHour,
    );
    final capacityNow = doctor.capacityAt(_date.weekday, _selTime!);
    if (!TotemBooking.hasRoom(booked: bookedNow, capacity: capacityNow)) {
      setState(() {
        _busy = false;
        _selTime = null;
        _selDoctor = null;
        _step = _Step.schedule;
      });
      _snack('Este horário acabou de lotar. Escolha outro, por favor.');
      _bump();
      return;
    }

    final senha = _genSenha(specialty);
    final appt = Appointment(
      id: _booking.newAppointmentId(),
      clinicId: ref.read(clinicaResolvidaProvider),
      patientId: patientId,
      patientName: name,
      doctorId: doctor.id,
      doctorName: doctor.name,
      specialty: specialty,
      start: start,
      durationMinutes: _tc.appointmentDuration,
      status: AppointmentStatus.pending,
      tipoConsulta: 'Consulta',
      modalidade: 'Presencial',
      patientPhone: phone,
      crm: doctor.crm,
      motivo: 'Agendado via totem',
    );
    // `create()` (não `add()`): reage na hora E persiste em `tb_agendamentos`,
    // então o agendamento chega à recepção/agenda e sobrevive ao reload (F2).
    ref.read(appointmentsProvider.notifier).create(appt);
    _sendConfirmations(email: email, appt: appt, senha: senha, isReschedule: false);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _senha = senha;
      _appt = appt;
      _testMode = false;
      _wasReschedule = false;
      _step = _Step.success;
    });
  }

  /// Dispara (sem bloquear o fluxo) as confirmações de consulta: e-mail
  /// (`sendConfirmationEmail`) e, se ativado, WhatsApp via Z-API (`whatsappProxy`)
  /// com o link de confirmação.
  void _sendConfirmations({
    required String? email,
    required Appointment appt,
    required String senha,
    required bool isReschedule,
  }) {
    final svc = ref.read(emailServiceProvider);
    final footer = _tc.ticketFooter.trim();
    final to = (email ?? '').trim();
    if (to.contains('@')) {
      svc.sendConfirmation(
        to: to,
        appointment: appt,
        isReschedule: isReschedule,
        clinicName: _tc.clinicName,
        senha: senha,
        footer: footer.isEmpty ? null : footer,
      );
    }
    if (_tc.confirmViaWhatsapp && appt.patientPhone.trim().isNotEmpty) {
      svc.sendWhatsappConfirmation(
        clinicaId: appt.clinicId,
        phone: appt.patientPhone,
        appointment: appt,
        isReschedule: isReschedule,
        clinicName: _tc.clinicName,
        senha: senha,
        link: _tc.confirmationLink,
      );
    }
  }

  void _testPrint() {
    setState(() {
      _testMode = true;
      _senha = 'T${100 + _rng.nextInt(900)}';
      _appt = null;
      _step = _Step.success;
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  // ------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(totemConfigProvider);
    return Scaffold(
      body: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(cfg.scale)),
        child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _bump(),
        child: Container(
          decoration: BoxDecoration(
            gradient: cfg.gradientBackground
                ? const RadialGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFEEF3F7)],
                    center: Alignment.topLeft,
                    radius: 1.5,
                  )
                : null,
            color: cfg.gradientBackground ? null : const Color(0xFFF6F8FB),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      _topBar(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(
                                      begin: const Offset(0, 0.03),
                                      end: Offset.zero)
                                  .animate(anim),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey('${_step}_$_cStep'),
                            child: _body(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_warning) _warningOverlay(),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _body() => switch (_step) {
        _Step.welcome => _welcome(),
        _Step.searchCpf => _searchCpfScreen(),
        _Step.chooseAppt => _chooseApptScreen(),
        _Step.schedule => _schedule(),
        _Step.confirm => _confirm(),
        _Step.success => _success(),
      };

  // ------------------------------------------------------------- top bar
  Widget _topBar() {
    final showSession = _step != _Step.welcome;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onLongPress: _openConfig, // acesso oculto à configuração (3s)
          child: _card(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.health_and_safety, color: _tc.accentColor, size: 26),
              const SizedBox(width: 10),
              Text(_tc.clinicName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: _kInk)),
            ]),
          ),
        ),
        Row(children: [
          if (showSession)
            _card(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined,
                    size: 18,
                    color:
                        _session <= _warnAt ? _tc.accentColor : Colors.grey[500]),
                const SizedBox(width: 8),
                Text(_mmss(_session),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _session <= _warnAt ? _tc.accentColor : _kInk,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          if (_tc.showClock) ...[
            const SizedBox(width: 12),
            _card(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule, color: _tc.accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                    '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
          ],
        ]),
      ],
    );
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  /// Abre o painel de configuração do totem (acesso oculto por toque longo).
  /// Com [TotemConfig.adminPin] definido, exige o PIN — o totem é uma tela
  /// pública e qualquer paciente poderia abrir o painel sem essa trava.
  Future<void> _openConfig() async {
    final pin = _tc.adminPin.trim();
    if (pin.isNotEmpty) {
      final ok = await _askPin(pin);
      if (!ok || !mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TotemConfigPanel()),
    );
  }

  /// Pede o PIN de administrador. Retorna `true` se o código conferir.
  Future<bool> _askPin(String expected) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN de administrador'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'Digite o PIN',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim() == expected),
        ),
        actions: [
          TextButton(
            // `null` = cancelado (não mostra "PIN incorreto").
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(ctrl.text.trim() == expected),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == false && mounted) _snack('PIN incorreto.');
    return ok == true;
  }

  // ------------------------------------------------------------- welcome
  Widget _welcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _brandLogo(280),
            const SizedBox(height: 24),
            Text(_tc.welcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 60, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 8),
            Text(_tc.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
            const SizedBox(height: 48),
            Wrap(
              spacing: 40,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_tc.allowAgendar)
                  _bigButton(
                    title: 'AGENDAR\nCONSULTA',
                    subtitle: 'NOVO AGENDAMENTO',
                    icon: Icons.calendar_month,
                    gradient: LinearGradient(
                        colors: [
                          _tc.accentColor,
                          Color.lerp(_tc.accentColor, Colors.black, 0.18)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    onTap: () => _start(_Mode.agendar),
                  ),
                if (_tc.allowRemarcar)
                  _bigButton(
                    title: 'REMARCAR\nCONSULTA',
                    subtitle: 'ALTERAR HORÁRIO',
                    icon: Icons.edit_calendar,
                    onTap: () => _start(_Mode.remarcar),
                  ),
                if (!_tc.allowAgendar && !_tc.allowRemarcar)
                  Text('Atendimento indisponível no momento.\nProcure a recepção.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_tc.showTutorial)
                  TextButton.icon(
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            _TotemTutorialModal(accent: _tc.accentColor)),
                    icon: Icon(Icons.help_outline,
                        color: _tc.accentColor, size: 18),
                    label: Text('COMO USAR O TOTEM',
                        style: TextStyle(
                            color: _tc.accentColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 12)),
                  ),
                if (_tc.showTutorial && _tc.showTestPrint)
                  const SizedBox(width: 24),
                if (_tc.showTestPrint)
                  TextButton.icon(
                    onPressed: _testPrint,
                    icon: Icon(Icons.print_outlined,
                        color: Colors.grey[500], size: 18),
                    label: Text('TESTAR IMPRESSÃO',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- search cpf
  Widget _searchCpfScreen() {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 40,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Escuro
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                decoration: const BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(Icons.history, size: 140, color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _tc.accentColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('AJUSTE DE AGENDA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 16),
                        const Text('REMARCAR CONSULTA', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        const Text('IDENTIFIQUE-SE PARA GERENCIAR SEUS AGENDAMENTOS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ],
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _tc.accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.security, color: _tc.accentColor, size: 28),
                    ),
                    const SizedBox(height: 24),
                    const Text('SEGURANÇA DO PACIENTE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kInk)),
                    const SizedBox(height: 8),
                    Text('Digite seu CPF no teclado abaixo para localizarmos seu registro.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 32),
                    // Campo de texto simulado
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _searchCpfVal.isEmpty
                            ? '000.000.000-00'
                            : _maskCpf(_searchCpfVal),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2, color: _searchCpfVal.isEmpty ? _tc.accentColor.withValues(alpha: 0.5) : _tc.accentColor),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Teclado (compartilhado com o passo de confirmação)
                    _CpfKeypad(
                      digits: _searchCpfVal,
                      accent: _tc.accentColor,
                      onChanged: (d) {
                        setState(() => _searchCpfVal = d);
                        _bump();
                      },
                    ),
                    const SizedBox(height: 40),
                    // Confirmar
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_busy || _searchCpfVal.length != 11)
                            ? null
                            : _searchByCpf,
                        style: FilledButton.styleFrom(
                          backgroundColor: _tc.accentColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(_busy ? Icons.hourglass_bottom : Icons.search, size: 20),
                        label: Text(_busy ? 'BUSCANDO...' : 'CONFIRMAR E BUSCAR', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('CANCELAR E VOLTAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ------------------------------------------------- escolher consulta (remarcar)
  Widget _chooseApptScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _card(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tc.showStepper)
                  _TotemStepper(currentStep: 1, accent: _tc.accentColor),
                Text('Qual consulta deseja remarcar?',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _tc.accentColor)),
                const SizedBox(height: 6),
                Text(
                    'Encontramos ${_reschedOptions.length} agendamentos ativos '
                    'no seu CPF. Toque no que deseja alterar.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 20),
                for (final a in _reschedOptions) _apptOptionCard(a),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _apptOptionCard(Appointment a) {
    final d = a.start;
    final dateStr =
        '${_weekdaysLong[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]}';
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Tappable(
        onTap: () => _pickReschedule(a),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: _tc.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(Icons.event_note, color: _tc.accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.doctorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _kInk,
                            fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(a.specialty,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.schedule, size: 14, color: _tc.accentColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('$dateStr • $timeStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: _kInk)),
                      ),
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- schedule

  Widget _schedule() {
    final slots = _buildSlots();
    final doctorsForDate = {
      for (final s in slots) s.doctor.id: s.doctor
    }.values.toList();
    // Quando um médico é filtrado, mostramos os horários dele em destaque e
    // levamos para o topo; os demais ficam esmaecidos (em vez de sumir).
    final hasFilter = _doctorFilter != null;
    final ordered = hasFilter
        ? [
            ...slots.where((s) => s.doctor.id == _doctorFilter),
            ...slots.where((s) => s.doctor.id != _doctorFilter),
          ]
        : slots;
    final showDoctorName = doctorsForDate.length > 1;
    final suggestions = _tc.showSuggestions
        ? _topSpecialties(max: _tc.maxSuggestions)
        : const <String>[];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _card(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tc.showStepper)
                  _TotemStepper(currentStep: 2, accent: _tc.accentColor),
                Text(
                    _mode == _Mode.agendar
                        ? _tc.agendarTitle
                        : _tc.remarcarTitle,
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: _tc.accentColor)),
                if (_mode == _Mode.remarcar && _reschedAppt != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _tc.accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _tc.accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.event_repeat, color: _tc.accentColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REMARCANDO',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color: _tc.accentColor)),
                            Text(
                              '${_reschedAppt!.doctorName} • ${_reschedAppt!.start.day.toString().padLeft(2, '0')}/${_reschedAppt!.start.month.toString().padLeft(2, '0')} às ${_reschedAppt!.start.hour.toString().padLeft(2, '0')}:${_reschedAppt!.start.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: _kInk),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),

                if (suggestions.isNotEmpty) ...[
                  _label('MAIS PROCURADAS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in suggestions)
                        ChoiceChip(
                          avatar: Icon(Icons.trending_up,
                              size: 16,
                              color: _specialty == s
                                  ? _tc.accentColor
                                  : _tc.accentColor.withValues(alpha: 0.7)),
                          label: Text(s),
                          labelStyle: TextStyle(
                            color: _specialty == s ? _tc.accentColor : _kInk,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: Colors.white,
                          selected: _specialty == s,
                          selectedColor: Color.lerp(Colors.white, _tc.accentColor, 0.15)!,
                          showCheckmark: false,
                          side: _specialty == s
                              ? BorderSide(color: _tc.accentColor, width: 1.5)
                              : BorderSide(
                                  color:
                                      _tc.accentColor.withValues(alpha: 0.4)),
                          onSelected: (_) => _pickSpecialty(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                _label('ESPECIALIDADE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _specialties())
                      ChoiceChip(
                        label: Text(s),
                        labelStyle: TextStyle(
                          color: _specialty == s ? _tc.accentColor : _kInk,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white,
                        selected: _specialty == s,
                        selectedColor: Color.lerp(Colors.white, _tc.accentColor, 0.15)!,
                        showCheckmark: false,
                        side: _specialty == s
                            ? BorderSide(color: _tc.accentColor, width: 1.5)
                            : BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        onSelected: (_) => _pickSpecialty(s),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('DATA'),
                    if (_tc.showCalendarButton)
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: const Text('ABRIR CALENDÁRIO',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5)),
                        onPressed: _openCalendar,
                        style: TextButton.styleFrom(
                          foregroundColor: _tc.accentColor,
                          backgroundColor:
                              _tc.accentColor.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_tc.showWeekStrip) _weekStrip(),
                const SizedBox(height: 24),

                if (_tc.showDoctorFilter && doctorsForDate.length > 1) ...[
                  _label('FILTRAR POR MÉDICO'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      labelStyle: TextStyle(
                        color: _doctorFilter == null ? _tc.accentColor : _kInk,
                        fontWeight: FontWeight.w700,
                      ),
                      backgroundColor: Colors.white,
                      selected: _doctorFilter == null,
                      selectedColor:
                          Color.lerp(Colors.white, _tc.accentColor, 0.15)!,
                      showCheckmark: false,
                      side: _doctorFilter == null
                          ? BorderSide(color: _tc.accentColor, width: 1.5)
                          : BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      onSelected: (_) =>
                          setState(() => _doctorFilter = null),
                    ),
                    for (final d in doctorsForDate)
                      ChoiceChip(
                        avatar: Icon(Icons.person,
                            size: 16,
                            color: _doctorFilter == d.id
                                ? _tc.accentColor
                                : _kInk.withValues(alpha: 0.5)),
                        label: Text(d.name.split(' ').take(2).join(' ')),
                        labelStyle: TextStyle(
                          color:
                              _doctorFilter == d.id ? _tc.accentColor : _kInk,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white,
                        selected: _doctorFilter == d.id,
                        selectedColor:
                            Color.lerp(Colors.white, _tc.accentColor, 0.15)!,
                        showCheckmark: false,
                        side: _doctorFilter == d.id
                            ? BorderSide(color: _tc.accentColor, width: 1.5)
                            : BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        onSelected: (_) => setState(() => _doctorFilter =
                            _doctorFilter == d.id ? null : d.id),
                      ),
                  ]),
                  const SizedBox(height: 24),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('HORÁRIO'),
                    if (slots.isNotEmpty && _tc.showOccupancy) _occLegend(),
                  ],
                ),
                const SizedBox(height: 8),
                if (slots.isEmpty)
                  _emptyBox('Nenhum horário disponível para esta data e especialidade.')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final slot in ordered)
                        _slotChip(slot, showDoctor: showDoctorName),
                    ],
                  ),

                if (_selDoctor != null && _tc.showDoctorCard) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  _doctorCard(_selDoctor!),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selTime == null ? null : _goConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: _tc.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    child: Text(_mode == _Mode.agendar
                        ? _tc.agendarButtonLabel
                        : _tc.remarcarButtonLabel),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Voltar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCalendar() async {
    final start = _startOfDay(DateTime.now());
    final last = start.add(Duration(days: _tc.maxDaysAhead));
    // initialDate precisa ficar entre firstDate e lastDate (senão estoura).
    final initial = _date.isBefore(start)
        ? start
        : (_date.isAfter(last) ? last : _date);
    final accent = _tc.accentColor;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: last,
      helpText: 'ESCOLHA A DATA',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accent,
              onPrimary: Colors.white,
              onSurface: _kInk,
              secondary: accent,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: accent),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _date = _startOfDay(picked);
        _selTime = null;
        _selDoctor = null;
        _doctorFilter = null;
      });
      _bump();
    }
  }

  Widget _weekStrip() {
    final today = _startOfDay(DateTime.now());
    final last = today.add(Duration(days: _tc.maxDaysAhead));
    final diff = _date.difference(today).inDays;

    DateTime startDay;
    if (diff >= 0 && diff < 7) {
      startDay = today;
    } else {
      startDay = _date;
    }

    final days = [for (var i = 0; i < 7; i++) startDay.add(Duration(days: i))];
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Opacity(
              opacity: d.isAfter(last) ? 0.35 : 1,
              child: GestureDetector(
              onTap: d.isAfter(last)
                  ? null
                  : () => setState(() {
                        _date = d;
                        _selTime = null;
                        _selDoctor = null;
                        _doctorFilter = null;
                      }),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _sameDay(d, _date) ? _tc.accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _sameDay(d, _date)
                          ? _tc.accentColor
                          : Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(_weekdaysShort[d.weekday - 1],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _sameDay(d, _date)
                                ? Colors.white70
                                : Colors.grey[500])),
                    const SizedBox(height: 2),
                    Text('${d.day}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color:
                                _sameDay(d, _date) ? Colors.white : _kInk)),
                  ],
                ),
              ),
            ),
            ),
          ),
      ],
    );
  }

  // Intensidade de ocupação (overbooking §1) — regra/cores unificadas em
  // [OccupancyLevel] (ver OVERBOOKING.md §M2/§B6).
  Color _occColor(_Slot s) {
    if (s.full) return OccupancyLevel.lotado.color;
    if (!_tc.showOccupancy) return _tc.accentColor; // sem indicador de ocupação
    return s.level.color;
  }

  String? _occBadge(_Slot s) {
    if (s.full) return OccupancyLevel.lotado.label;
    if (_tc.showOccupancy && s.level == OccupancyLevel.ultimas) {
      return OccupancyLevel.ultimas.label;
    }
    return null;
  }

  Widget _occLegend() {
    Widget dot(OccupancyLevel l) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: l.color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(l.label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[500])),
        ]);
    return Wrap(spacing: 10, children: [
      for (final l in OccupancyLevel.values) dot(l),
    ]);
  }

  Widget _slotChip(_Slot slot, {bool showDoctor = false}) {
    final full = slot.full;
    final occ = _occColor(slot);
    final badge = _occBadge(slot);
    final selected =
        _selTime == slot.time && _selDoctor?.id == slot.doctor.id;
    final highlighted = _doctorFilter == slot.doctor.id;
    final dimmed = _doctorFilter != null && !highlighted;
    final firstName = slot.doctor.name
        .replaceAll('Dr. ', '')
        .replaceAll('Dra. ', '')
        .split(' ')
        .first;

    return Opacity(
      opacity: full ? 0.5 : (dimmed ? 0.35 : 1),
      child: GestureDetector(
        onTap: full ? null : () => _selectSlot(slot),
        child: Container(
          width: showDoctor ? 112 : 96,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? _tc.accentColor
                : highlighted
                    ? _tc.accentColor.withValues(alpha: 0.06)
                    : full
                        ? Colors.grey.withValues(alpha: 0.08)
                        : occ.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: selected || highlighted ? 2 : 1,
              color: selected
                  ? Colors.transparent
                  : highlighted
                      ? _tc.accentColor
                      : occ.withValues(alpha: full ? 0.5 : 0.9),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(slot.time,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : _kInk)),
              if (showDoctor)
                Text(firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.grey[600])),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : occ.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: selected ? Colors.white : occ)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doctorCard(Doctor d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: _tc.accentColor.withValues(alpha: 0.1),
            backgroundImage: d.photoUrl != null ? NetworkImage(d.photoUrl!) : null,
            child: d.photoUrl == null
                ? Text(d.initials,
                    style: TextStyle(
                        color: _tc.accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _tc.accentColor)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final s in d.specialties)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 6),
                Text('CRM ${d.crm}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- confirm
  Widget _confirm() {
    final d = _selDoctor!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _card(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tc.showStepper)
                  _TotemStepper(currentStep: 3, accent: _tc.accentColor),
                Text(
                    _cStep == _ConfirmStep.form
                        ? 'Complete seu Cadastro'
                        : 'Confirme seu Agendamento',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _tc.accentColor)),
                const SizedBox(height: 20),
                // resumo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.15))),
                  child: Column(children: [
                    _summaryRow(Icons.medical_services_outlined, 'Médico(a)', d.name),
                    const SizedBox(height: 8),
                    _summaryRow(Icons.event, 'Data',
                        '${_weekdaysLong[_date.weekday - 1]}, ${_date.day} de ${_months[_date.month - 1]}'),
                    const SizedBox(height: 8),
                    _summaryRow(Icons.schedule, 'Horário', _selTime!),
                  ]),
                ),
                const SizedBox(height: 20),
                if (_cStep == _ConfirmStep.cpf) _cpfStep(),
                if (_cStep == _ConfirmStep.confirm) _confirmStep(),
                if (_cStep == _ConfirmStep.form) _formStep(),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _step = _Step.schedule),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Voltar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cpfStep() {
    final masked = _cpfCtrl.text;
    final digits = masked.replaceAll(RegExp(r'\D'), '');
    final complete = digits.length == 11;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('DIGITE SEU CPF'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: digits.isEmpty
                  ? Colors.grey.withValues(alpha: 0.25)
                  : _tc.accentColor,
              width: digits.isEmpty ? 1 : 2),
        ),
        child: Text(
          masked.isEmpty ? '000.000.000-00' : masked,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: masked.isEmpty ? Colors.grey[400] : _kInk,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _CpfKeypad(
        digits: digits,
        accent: _tc.accentColor,
        onChanged: (d) {
          setState(() => _cpfCtrl.text = _maskCpf(d));
          _bump();
        },
      ),
      const SizedBox(height: 16),
      _primary(_busy ? 'VERIFICANDO...' : 'VERIFICAR',
          (_busy || !complete) ? null : _checkCpf),
      if (_tc.allowGuestScheduling)
        Center(
          child: TextButton(
            onPressed:
                _busy ? null : () => setState(() => _cStep = _ConfirmStep.form),
            child: const Text('Não tem cadastro? Agendar mesmo assim'),
          ),
        ),
    ]);
  }

  String _maskCpf(String digits) {
    final d = digits.length > 11 ? digits.substring(0, 11) : digits;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 6) b.write('.');
      if (i == 9) b.write('-');
      b.write(d[i]);
    }
    return b.toString();
  }

  Widget _confirmStep() {
    final p = _found!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('SEUS DADOS'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (p.email != null) Text(p.email!, style: TextStyle(color: Colors.grey[600])),
          Text(p.phone ?? 'Telefone não informado',
              style: TextStyle(color: Colors.grey[600])),
        ]),
      ),
      const SizedBox(height: 16),
      _primary(
          _busy
              ? 'CONFIRMANDO...'
              : (_mode == _Mode.remarcar && _reschedAppt != null
                  ? 'CONFIRMAR REMARCAÇÃO'
                  : 'CONFIRMAR AGENDAMENTO'),
          _busy ? null : _confirmExisting),
      Center(
        child: TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _cStep = _ConfirmStep.cpf;
                    _found = null;
                    _cpfCtrl.clear();
                  }),
          child: const Text('Não é você? Tentar outro CPF'),
        ),
      ),
    ]);
  }

  Widget _formStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('NOME COMPLETO'),
      const SizedBox(height: 6),
      TextField(controller: _nameCtrl, decoration: _input('Seu nome')),
      const SizedBox(height: 14),
      _label('E-MAIL'),
      const SizedBox(height: 6),
      TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _input('seu@email.com')),
      const SizedBox(height: 14),
      _label('TELEFONE'),
      const SizedBox(height: 6),
      TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [_PhoneFormatter()],
          decoration: _input('(00) 00000-0000')),
      const SizedBox(height: 16),
      _primary(_busy ? 'AGENDANDO...' : 'CADASTRAR E AGENDAR',
          _busy ? null : _submitNew),
    ]);
  }

  // ------------------------------------------------------------- success
  Widget _success() {
    final apt = _appt;
    final patientName = _testMode ? 'Paciente de Teste' : (apt?.patientName ?? '—');
    final doctorName = _testMode ? 'Dr(a). Teste' : (apt?.doctorName ?? '—');
    final specialty = _testMode ? 'Clínica Geral' : (apt?.specialty ?? '—');
    final when = apt?.start ?? DateTime.now();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _card(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tc.showStepper)
                  _TotemStepper(currentStep: 4, accent: _tc.accentColor),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  child: Icon(Icons.check_circle, color: Colors.green[600], size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                    _testMode
                        ? 'Comprovante de Teste'
                        : _wasReschedule
                            ? 'Consulta Remarcada!'
                            : 'Agendamento Confirmado!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _tc.accentColor)),
                const SizedBox(height: 20),
                // comprovante
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
                  child: Column(children: [
                    _brandLogo(32),
                    Text(_tc.clinicName,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                        '${_now.day.toString().padLeft(2, '0')}/${_now.month.toString().padLeft(2, '0')}/${_now.year} ${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    _dashed(),
                    const Text('SENHA',
                        style:
                            TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                    Text(_senha ?? '—',
                        style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: 2)),
                    _dashed(),
                    _receiptRow('Paciente', patientName),
                    _receiptRow('Médico', doctorName),
                    _receiptRow('Especialidade', specialty),
                    _receiptRow('Data',
                        '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year} às ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'),
                    _receiptRow('Sala', 'A definir'),
                    _dashed(),
                    if (_tc.arrivalMinutes > 0)
                      Text(
                          'Chegue com ${_tc.arrivalMinutes} minutos de antecedência.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (_tc.ticketFooter.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_tc.ticketFooter,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                    ],
                    const SizedBox(height: 16),
                    QrImageView(
                      data: apt?.id ?? 'agendamento-teste',
                      version: QrVersions.auto,
                      size: 100.0,
                      gapless: false,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                if (_tc.printEnabled)
                  _primary('IMPRIMIR COMPROVANTE', _printReceipt),
                Center(
                  child: TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Voltar ao Início'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Impressão **real** do comprovante: gera um PDF em formato de bobina
  /// (80 mm) e abre o diálogo de impressão do sistema/navegador. Em falha,
  /// avisa sem travar o fluxo.
  Future<void> _printReceipt() async {
    final apt = _appt;
    final patientName =
        _testMode ? 'Paciente de Teste' : (apt?.patientName ?? '—');
    final doctorName = _testMode ? 'Dr(a). Teste' : (apt?.doctorName ?? '—');
    final specialty = _testMode ? 'Clínica Geral' : (apt?.specialty ?? '—');
    final when = apt?.start ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');

    pw.Widget row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                  width: 70,
                  child: pw.Text('$label:',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(
                  child: pw.Text(value, style: const pw.TextStyle(fontSize: 8))),
            ],
          ),
        );
    pw.Widget dashed() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text('- ' * 24, style: const pw.TextStyle(fontSize: 8)),
        );

    try {
      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (_) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(_tc.clinicName,
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                '${two(_now.day)}/${two(_now.month)}/${_now.year} ${two(_now.hour)}:${two(_now.minute)}',
                style: const pw.TextStyle(fontSize: 7)),
            dashed(),
            pw.Text('SENHA',
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(_senha ?? '—',
                style:
                    pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
            dashed(),
            row('Paciente', patientName),
            row('Médico', doctorName),
            row('Especialidade', specialty),
            row('Data',
                '${two(when.day)}/${two(when.month)}/${when.year} às ${two(when.hour)}:${two(when.minute)}'),
            row('Sala', 'A definir'),
            dashed(),
            if (_tc.arrivalMinutes > 0)
              pw.Text(
                  'Chegue com ${_tc.arrivalMinutes} minutos de antecedência.',
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center),
            if (_tc.ticketFooter.trim().isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(_tc.ticketFooter.trim(),
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ),
          ],
        ),
      ));
      await Printing.layoutPdf(
        name: 'comprovante-${_senha ?? 'totem'}',
        onLayout: (_) => doc.save(),
      );
    } catch (e) {
      if (mounted) _snack('Não foi possível imprimir o comprovante.');
    }
  }

  // ------------------------------------------------------------- warning
  Widget _warningOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: _card(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Sessão Expirando!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Você está inativo. A sessão será encerrada em',
                style: TextStyle(color: Colors.grey[600])),
            Text('$_session',
                style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: _tc.accentColor)),
            Text('segundos', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            _primary('CONTINUAR', _bump),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- pieces
  /// Logo da marca (tela inicial/comprovante): usa [TotemConfig.logoUrl]
  /// quando definido, com fallback no coração se vazio ou se a imagem falhar.
  Widget _brandLogo(double size) {
    final url = _tc.logoUrl.trim();
    if (!url.startsWith('http') && !url.startsWith('data:')) {
      return _HeartLogo(size: size);
    }
    return Image.network(
      url,
      height: size,
      width: size,
      fit: BoxFit.contain,
      loadingBuilder: (c, child, progress) => progress == null
          ? child
          : SizedBox(
              width: size,
              height: size,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))),
      errorBuilder: (_, _, _) => _HeartLogo(size: size),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: Colors.grey[500]));

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      );

  Widget _primary(String text, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: _tc.accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          child: Text(text),
        ),
      );

  Widget _summaryRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 18, color: _tc.accentColor),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
              child: Text(value,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      );

  Widget _receiptRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text('$label:',
                  style:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            Expanded(
                child: Text(value, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Widget _dashed() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: List.generate(
              40,
              (i) => Expanded(
                    child: Container(
                      height: 1,
                      color: i.isEven
                          ? Colors.grey.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  )),
        ),
      );

  Widget _emptyBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600])),
      );

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        child: child,
      );

  Widget _bigButton({
    required String title,
    required String subtitle,
    required IconData icon,
    LinearGradient? gradient,
    required VoidCallback onTap,
  }) {
    final solid = gradient == null;
    return _Tappable(
      onTap: onTap,
      child: Container(
        width: 360,
        height: 300,
        decoration: BoxDecoration(
          gradient: gradient,
          color: solid ? Colors.white : null,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: solid
                    ? Colors.black.withValues(alpha: 0.05)
                    : _tc.accentColor.withValues(alpha: 0.3),
                blurRadius: 36,
                offset: const Offset(0, 18)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: solid ? Colors.grey.withValues(alpha: 0.05) : null,
                  border: Border.all(
                      color: solid
                          ? Colors.grey.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.4),
                      width: 2)),
              child: Icon(icon,
                  color: solid ? Colors.grey[600] : Colors.white, size: 32),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: solid ? _kInk : Colors.white)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: solid
                        ? Colors.grey[400]
                        : Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }
}

class _HeartLogo extends StatelessWidget {
  const _HeartLogo({this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [_kAccent, _kBrand],
      ).createShader(rect),
      child: Icon(Icons.favorite, size: size, color: Colors.white),
    );
  }
}

class _Tappable extends StatefulWidget {
  const _Tappable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_Tappable> createState() => _TappableState();
}

class _TappableState extends State<_Tappable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Teclado numérico de CPF **compartilhado** (busca do Remarcar e passo de
/// confirmação): grade 3×4 (1–9, LIMPAR, 0, ⌫) com dígitos desabilitados ao
/// atingir 11 e LIMPAR/⌫ desabilitados quando vazio. Emite só dígitos.
class _CpfKeypad extends StatelessWidget {
  const _CpfKeypad({
    required this.digits,
    required this.onChanged,
    required this.accent,
  });

  /// Valor atual (somente dígitos, 0–11).
  final String digits;

  /// Novo valor após o toque (somente dígitos).
  final ValueChanged<String> onChanged;

  /// Cor de destaque configurada no totem (tecla ⌫).
  final Color accent;

  static const _keys = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', 'clear', '0', 'back',
  ];

  void _press(String k) {
    if (k == 'back') {
      if (digits.isNotEmpty) onChanged(digits.substring(0, digits.length - 1));
    } else if (k == 'clear') {
      onChanged('');
    } else if (digits.length < 11) {
      onChanged(digits + k);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [for (final k in _keys) _key(k)],
    );
  }

  Widget _key(String k) {
    final isBack = k == 'back';
    final isClear = k == 'clear';
    final disabled =
        (isBack || isClear) ? digits.isEmpty : digits.length >= 11;
    Color bg;
    Color fg;
    if (isBack) {
      bg = accent.withValues(alpha: 0.1);
      fg = accent;
    } else if (isClear) {
      bg = Colors.grey.withValues(alpha: 0.08);
      fg = Colors.grey[700]!;
    } else {
      bg = Colors.white;
      fg = _kInk;
    }
    return _Tappable(
      onTap: disabled ? () {} : () => _press(k),
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
          ),
          alignment: Alignment.center,
          child: isBack
              ? Icon(Icons.backspace_outlined, color: fg, size: 24)
              : isClear
                  ? Text('LIMPAR',
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1))
                  : Text(k,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 28)),
        ),
      ),
    );
  }
}

/// Máscara de telefone: (00) 00000-0000.
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 11) d = d.substring(0, 11);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (i == 7) b.write('-');
      b.write(d[i]);
    }
    final t = b.toString();
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

class _TotemStepper extends StatelessWidget {
  const _TotemStepper({required this.currentStep, this.accent = _kBrand});

  final int currentStep; // 1 to 4
  final Color accent; // cor de destaque configurada no totem

  Widget _buildStep(int stepIndex, String title, bool isLast) {
    final isCompleted = currentStep > stepIndex;
    final isActive = currentStep == stepIndex;

    Widget iconNode;
    if (isCompleted) {
      iconNode = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981), // Green
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      );
    } else if (isActive) {
      iconNode = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text('$stepIndex', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
      );
    } else {
      iconNode = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 2),
        ),
        alignment: Alignment.center,
        child: Text('$stepIndex', style: TextStyle(color: Colors.grey[400], fontSize: 20, fontWeight: FontWeight.w900)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconNode,
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: isCompleted ? const Color(0xFF10B981) : isActive ? accent : Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStep(1, 'SERVIÇO', false),
          _buildLine(currentStep > 1),
          _buildStep(2, 'ESPECIALISTA', false),
          _buildLine(currentStep > 2),
          _buildStep(3, 'CONFIRMAÇÃO', false),
          _buildLine(currentStep > 3),
          _buildStep(4, 'FINALIZADO', true),
        ],
      ),
    );
  }
}

class _TotemTutorialModal extends StatefulWidget {
  const _TotemTutorialModal({this.accent = _kBrand});

  final Color accent; // cor de destaque configurada no totem

  @override
  State<_TotemTutorialModal> createState() => _TotemTutorialModalState();
}

class _TotemTutorialModalState extends State<_TotemTutorialModal> {
  int _i = 0;

  Color get _a => widget.accent;

  static const _titles = [
    'ESCOLHA O SERVIÇO',
    'IDENTIFIQUE-SE',
    'ESCOLHA O ESPECIALISTA',
    'RETIRE SEU COMPROVANTE',
  ];
  static const _descs = [
    'Toque em "Agendar consulta" para uma nova marcação ou em "Remarcar" para ajustar uma já existente.',
    'Digite seu CPF no teclado da tela para carregarmos seus dados com segurança. Sem cadastro? É rápido fazer na hora.',
    'Escolha a especialidade, o dia e o médico. Os horários livres aparecem para você tocar e selecionar.',
    'Confira o resumo, confirme e pegue sua senha de atendimento. Aguarde ser chamado no painel.',
  ];
  Widget _illu(int i) => switch (i) {
        0 => _illuStep1(),
        1 => _illuStep2(),
        2 => _illuStep3(),
        _ => _illuStep4(),
      };

  bool get _isLast => _i == _titles.length - 1;

  // Ilustrações procedimentais:
  Widget _illuStep1() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _miniCard(false, Icons.calendar_today),
        const SizedBox(width: 16),
        _miniCard(true, Icons.edit_calendar),
      ],
    );
  }

  Widget _miniCard(bool active, IconData icon) {
    return Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        color: active ? _a.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? _a.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: active ? _a : Colors.grey.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(icon, color: active ? Colors.white : Colors.grey[300], size: 20),
          ),
          const SizedBox(height: 16),
          Container(width: 32, height: 4, decoration: BoxDecoration(color: active ? _a.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _illuStep2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(Icons.security, size: 12, color: _a),
              const SizedBox(width: 8),
              Row(children: List.generate(6, (i) => Container(margin: const EdgeInsets.only(right: 4), width: 6, height: 6, decoration: const BoxDecoration(color: _kInk, shape: BoxShape.circle)))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4, runSpacing: 4,
          children: [
            for (var i=1; i<=9; i++)
              Container(
                width: 32, height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: i == 5 ? _a : Colors.grey.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text('$i', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: i == 5 ? _a : _kInk)),
              )
          ],
        )
      ],
    );
  }

  Widget _illuStep3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 24),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 6),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2))),
              ],
            )
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _timePill(false, '08:00'),
            const SizedBox(width: 8),
            _timePill(true, '09:00'),
            const SizedBox(width: 8),
            _timePill(false, '10:00'),
          ],
        )
      ],
    );
  }

  Widget _timePill(bool active, String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _a : Colors.white,
        border: Border.all(color: active ? _a : Colors.grey.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: active ? Colors.white : Colors.grey[400])),
    );
  }

  Widget _illuStep4() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 30,
          child: Container(
            width: 80, height: 100,
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 20, height: 20, decoration: BoxDecoration(color: _a.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.check, size: 12, color: _a)),
                const SizedBox(height: 12),
                Container(width: 40, height: 4, color: Colors.grey.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                Container(width: 20, height: 20, decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ),
        Positioned(
          top: 30,
          child: Container(
            width: 100, height: 16,
            decoration: BoxDecoration(color: _kInk, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: Container(width: 60, height: 2, color: Colors.black),
          ),
        ),
        Positioned(
          right: 40, top: 20,
          child: Icon(Icons.auto_awesome, color: _a.withValues(alpha: 0.5), size: 24),
        )
      ],
    );
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      setState(() => _i++);
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final width = screenW < 720 ? screenW * 0.94 : 680.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 20))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 20, 24),
              decoration: const BoxDecoration(
                color: _kInk,
                borderRadius:
                    BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _a, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.menu_book, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Como usar o totem',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                        Text('Guia rápido em 4 passos',
                            style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            // Passo atual
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                              begin: const Offset(0.04, 0), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_i),
                    children: [
                      // Ilustração grande
                      Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FB),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.12)),
                        ),
                        child: _illu(_i),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: _a,
                                borderRadius: BorderRadius.circular(14)),
                            alignment: Alignment.center,
                            child: Text('${_i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Text(_titles[_i],
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: _kInk)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(_descs[_i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            ),
            // Progresso
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var s = 0; s < _titles.length; s++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: s == _i ? 28 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s == _i
                            ? _a
                            : s < _i
                                ? _a.withValues(alpha: 0.4)
                                : Colors.grey.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                ],
              ),
            ),
            // Rodapé
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (_i > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _prev,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('ANTERIOR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kInk,
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('PULAR',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: _a,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      child: Text(_isLast ? 'ENTENDI, VAMOS LÁ!' : 'PRÓXIMO'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

