import '../../core/models/appointment.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import 'overbooking_models.dart';

/// Resultado agregado do dia para o painel de overbooking (OVB-02/03).
class OverbookingSnapshot {
  const OverbookingSnapshot({
    required this.date,
    required this.hours,
    required this.doctors,
    required this.dayAppointments,
    required this.totalBooked,
    required this.totalCapacity,
    required this.fullSlots,
    required this.excedenteTotal,
    required this.estouroTotal,
    required this.esperando,
    required this.slotsSobrecarga,
    required this.bookedByDoctorHour,
    required this.bookedByHour,
    required this.capacityByHour,
  });

  final DateTime date;
  final List<int> hours;
  final List<Doctor> doctors;
  final List<Appointment> dayAppointments;

  final int totalBooked;
  final int totalCapacity;
  final int fullSlots;
  final int excedenteTotal;
  final int estouroTotal;
  final int esperando;

  /// Slots (médico × hora) em estouro, com candidatos + destino sugerido.
  final List<SlotSobrecarga> slotsSobrecarga;

  final Map<String, Map<int, int>> bookedByDoctorHour;
  final Map<int, int> bookedByHour;
  final Map<int, int> capacityByHour;

  int get occPct =>
      totalCapacity == 0 ? 0 : (totalBooked / totalCapacity * 100).round();

  /// Pacientes elegíveis a realocação hoje (candidatos dos slots em estouro).
  int get realocaveis =>
      slotsSobrecarga.fold(0, (s, sl) => s + sl.candidatos.length);

  /// Ids dos agendamentos que estão marcados como realocáveis.
  Set<String> get realocavelIds => {
        for (final s in slotsSobrecarga)
          for (final c in s.candidatos) c.appointment.id,
      };
}

/// Motor de detecção e escolha de realocação (lógica pura, testável).
class OverbookingEngine {
  const OverbookingEngine._();

  static const _businessStart = 7;
  static const _businessEnd = 18;

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _pad(int h) => h.toString().padLeft(2, '0');

  static String periodOf(int hour) =>
      hour < 12 ? 'manha' : (hour < 18 ? 'tarde' : 'noite');

  /// Elegível a ser movido: ainda pendente ou confirmado (não realizado, não
  /// falta, não cancelado) — OVB-05.2 (hard constraints).
  static bool _eligible(Appointment a) =>
      a.status == AppointmentStatus.pending ||
      a.status == AppointmentStatus.confirmed;

  /// Prioridade para SAIR do slot (maior = melhor candidato): não confirmados
  /// e de baixo risco toleram melhor a mudança (OVB-05.2).
  static int _priority(Appointment a) {
    var score = a.status == AppointmentStatus.pending ? 2 : 0;
    score += switch (a.patientRisk) {
      RiskLevel.low => 2,
      RiskLevel.medium => 1,
      RiskLevel.high => 0,
    };
    return score;
  }

  /// Ordem de horas preferida para o destino: mesmo turno primeiro (OVB-05.3).
  static List<int> _preferredHours(String period) {
    final all = [for (var h = _businessStart; h <= _businessEnd; h++) h];
    all.sort((a, b) {
      final sa = periodOf(a) == period ? 0 : 1;
      final sb = periodOf(b) == period ? 0 : 1;
      return sa != sb ? sa - sb : a - b;
    });
    return all;
  }

  static int _bookedAt(
      List<Appointment> all, String doctorId, DateTime day, int hour) {
    return all
        .where((a) =>
            a.doctorId == doctorId &&
            a.status != AppointmentStatus.cancelled &&
            sameDay(a.start, day) &&
            a.start.hour == hour)
        .length;
  }

  /// Melhor janela de destino com folga real para o mesmo médico nos próximos
  /// 1..7 dias (OVB-05.3). `used` evita propor o mesmo destino a dois pacientes.
  static DateTime? findDestino(
    Doctor doc,
    DateTime fromDate,
    List<Appointment> all,
    String period,
    Set<String> used,
  ) {
    for (var d = 1; d <= 7; d++) {
      final day = DateTime(fromDate.year, fromDate.month, fromDate.day + d);
      final wd = day.weekday;
      for (final h in _preferredHours(period)) {
        final slot = DateTime(day.year, day.month, day.day, h);
        final key = '${doc.id}|${slot.toIso8601String()}';
        if (used.contains(key)) continue;
        final cap = doc.capacityAt(wd, '${_pad(h)}:00');
        if (_bookedAt(all, doc.id, day, h) < cap) return slot;
      }
    }
    return null;
  }

  static String _motivo(Doctor doc, DateTime dest, String origPeriod) {
    final samePeriod = periodOf(dest.hour) == origPeriod;
    return 'Mesmo médico${samePeriod ? ', mesmo turno' : ''} • vaga livre '
        'com menor pressão de agenda';
  }

  /// Constrói o snapshot do dia a partir dos médicos ativos e de TODOS os
  /// agendamentos (a janela do dia alimenta a detecção; o histórico completo
  /// alimenta a busca de destino).
  static OverbookingSnapshot build({
    required DateTime date,
    required List<Doctor> doctors,
    required List<Appointment> allAppointments,
    DateTime? now,
  }) {
    final agora = now ?? DateTime.now();
    final wd = date.weekday;
    final dayAppts = allAppointments
        .where((a) =>
            sameDay(a.start, date) && a.status != AppointmentStatus.cancelled)
        .toList();

    var startH = _businessStart;
    var endH = _businessEnd;
    for (final a in dayAppts) {
      if (a.start.hour < startH) startH = a.start.hour;
      if (a.start.hour > endH) endH = a.start.hour;
    }
    final hours = [for (var h = startH; h <= endH; h++) h];

    final bookedByDoctorHour = <String, Map<int, int>>{};
    for (final a in dayAppts) {
      final m = bookedByDoctorHour.putIfAbsent(a.doctorId, () => {});
      m[a.start.hour] = (m[a.start.hour] ?? 0) + 1;
    }

    final bookedByHour = <int, int>{for (final h in hours) h: 0};
    final capacityByHour = <int, int>{for (final h in hours) h: 0};

    final used = <String>{};
    final slots = <SlotSobrecarga>[];
    var totalBooked = 0, totalCap = 0, fullSlots = 0, excedente = 0, estouro = 0;

    for (final doc in doctors) {
      final byHour = bookedByDoctorHour[doc.id] ?? const {};
      for (final h in hours) {
        final cap = doc.capacityAt(wd, '${_pad(h)}:00');
        final booked = byHour[h] ?? 0;
        totalBooked += booked;
        totalCap += cap;
        bookedByHour[h] = (bookedByHour[h] ?? 0) + booked;
        capacityByHour[h] = (capacityByHour[h] ?? 0) + cap;
        if (booked >= cap) fullSlots++;

        final base = doc.slotLimit < 1 ? 1 : doc.slotLimit;
        final exc = booked - base;
        if (exc > 0) excedente += exc;
        final est = booked - cap;
        if (est <= 0) continue;
        estouro += est;

        final inSlot = dayAppts
            .where((a) => a.doctorId == doc.id && a.start.hour == h)
            .where(_eligible)
            .toList()
          ..sort((a, b) => _priority(b) - _priority(a));
        final moveCount = est.clamp(0, inSlot.length);
        final period = periodOf(h);
        final cands = <CandidatoRealoc>[];
        for (final a in inSlot.take(moveCount)) {
          final dest = findDestino(doc, date, allAppointments, period, used);
          if (dest != null) used.add('${doc.id}|${dest.toIso8601String()}');
          cands.add(CandidatoRealoc(
            appointment: a,
            destino: dest,
            motivo: dest != null
                ? _motivo(doc, dest, period)
                : 'Sem vaga próxima — tratar manualmente',
          ));
        }
        slots.add(SlotSobrecarga(
          doctorId: doc.id,
          doctorName: doc.name,
          doctorCrm: doc.crm,
          specialty: doc.primarySpecialty,
          hour: h,
          booked: booked,
          capacity: cap,
          slotBase: base,
          candidatos: cands,
        ));
      }
    }

    // "Esperando": confirmados de hoje cujo horário já passou e ainda não foram
    // atendidos (proxy de check-in em espera).
    final esperando = dayAppts
        .where((a) =>
            a.status == AppointmentStatus.confirmed &&
            a.start.isBefore(agora))
        .length;

    return OverbookingSnapshot(
      date: date,
      hours: hours,
      doctors: doctors,
      dayAppointments: dayAppts,
      totalBooked: totalBooked,
      totalCapacity: totalCap,
      fullSlots: fullSlots,
      excedenteTotal: excedente,
      estouroTotal: estouro,
      esperando: esperando,
      slotsSobrecarga: slots,
      bookedByDoctorHour: bookedByDoctorHour,
      bookedByHour: bookedByHour,
      capacityByHour: capacityByHour,
    );
  }

  /// Deriva o estado operacional de um paciente (OVB-04) combinando o status do
  /// agendamento, se está num slot em estouro e a sobreposição da realocação.
  static PacienteEstado estadoDe(
    Appointment a, {
    required bool realocavel,
    RealocacaoStatus? proposta,
  }) {
    if (proposta != null) {
      switch (proposta) {
        case RealocacaoStatus.concluida:
          return PacienteEstado.realocado;
        case RealocacaoStatus.recusada:
        case RealocacaoStatus.expirada:
          return PacienteEstado.recusada;
        case RealocacaoStatus.aguardandoConfirmacao:
          return PacienteEstado.aguardandoConfirmacao;
        case RealocacaoStatus.sugerida:
          return PacienteEstado.sugerida;
      }
    }
    switch (a.status) {
      case AppointmentStatus.completed:
        return PacienteEstado.realizado;
      case AppointmentStatus.noShow:
        return PacienteEstado.faltou;
      case AppointmentStatus.cancelled:
        return PacienteEstado.recusada;
      case AppointmentStatus.confirmed:
        return realocavel ? PacienteEstado.realocavel : PacienteEstado.confirmado;
      case AppointmentStatus.pending:
        return realocavel ? PacienteEstado.realocavel : PacienteEstado.agendado;
    }
  }
}
