import 'dart:math';

import '../../core/models/appointment.dart';
import '../../core/models/enums.dart';

/// Lógica de agendamento do totem **isolada da UI** — permite testar a
/// integridade do fluxo (concorrência, unicidade de id/senha, respeito à
/// capacidade) sem subir a árvore de widgets de `TotemScreen`.
///
/// Motivação (auditoria 2026-09-01, `TESTE-SISTER/`):
/// - ids baseados só em `millisecondsSinceEpoch` colidiam sob criação
///   concorrente (F1/F5);
/// - a senha de fila (3 dígitos aleatórios) colidia ~4% a cada 10 emissões (F6);
/// - a checagem de lotação usava um snapshot antigo, sem revalidar na hora (F3).
class TotemBooking {
  TotemBooking({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  /// Contador monotônico do isolate — todas as reservas de um mesmo dispositivo
  /// passam por aqui, então ele **garante** unicidade local mesmo que o relógio
  /// e o aleatório coincidam. Micros + aleatório cobrem a unicidade entre
  /// dispositivos.
  static int _seq = 0;

  /// Id de agendamento **único mesmo sob concorrência** (vários agendamentos no
  /// mesmo milissegundo, abas paralelas): microssegundos + contador do isolate
  /// + 31 bits aleatórios.
  String newAppointmentId() =>
      'apt-${DateTime.now().microsecondsSinceEpoch}-${_seq++}-${_rng.nextInt(0x7fffffff)}';

  /// Id de paciente-convidado (cadastro rápido no totem). Mesma garantia de
  /// unicidade — dois cadastros simultâneos não podem colidir e fundir pessoas.
  String newGuestPatientId() =>
      'totem-${DateTime.now().microsecondsSinceEpoch}-${_seq++}-${_rng.nextInt(0x7fffffff)}';

  /// Senha de fila: inicial da especialidade + número. Evita colisão com
  /// [taken] (senhas já emitidas na fila/sessão) — tenta várias vezes com 3
  /// dígitos e, no limite, cai para 4 dígitos (colisão praticamente nula).
  String senha(String specialty, {Set<String> taken = const {}}) {
    final initial = specialty.trim().isNotEmpty
        ? specialty.trim()[0].toUpperCase()
        : 'G';
    for (var i = 0; i < 40; i++) {
      final candidate = '$initial${100 + _rng.nextInt(900)}';
      if (!taken.contains(candidate)) return candidate;
    }
    for (var i = 0; i < 40; i++) {
      final candidate = '$initial${1000 + _rng.nextInt(9000)}';
      if (!taken.contains(candidate)) return candidate;
    }
    return '$initial${DateTime.now().microsecondsSinceEpoch % 100000}';
  }

  /// Passo da grade de horários (nunca menor que 5 min) — espelha `_buildSlots`.
  static int gridStep(int appointmentDuration) =>
      appointmentDuration < 5 ? 5 : appointmentDuration;

  /// Âncora de um horário `HH:mm` no slot da grade que o contém
  /// (ex.: 09:15 numa grade de 30 min → slot 09:00).
  static int _anchorMinutes(int startMin, int openMin, int step) =>
      openMin + ((startMin - openMin) ~/ step) * step;

  /// Quantos agendamentos **ativos** ocupam o slot `slotTime` × `doctorId` em
  /// [date]. Função pura: recalcula a partir da lista atual de [appointments],
  /// então serve para **revalidar a capacidade no instante da confirmação**.
  static int bookedInSlot({
    required Iterable<Appointment> appointments,
    required DateTime date,
    required String doctorId,
    required String slotTime,
    required int appointmentDuration,
    required int openHour,
    String? ignoreApptId,
  }) {
    final step = gridStep(appointmentDuration);
    final openMin = openHour * 60;
    final targetMin = int.parse(slotTime.substring(0, 2)) * 60 +
        int.parse(slotTime.substring(3, 5));
    final target = _anchorMinutes(targetMin, openMin, step);

    var count = 0;
    for (final a in appointments) {
      if (a.doctorId != doctorId) continue;
      if (a.status == AppointmentStatus.cancelled) continue;
      if (ignoreApptId != null && a.id == ignoreApptId) continue;
      final sameDay = a.start.year == date.year &&
          a.start.month == date.month &&
          a.start.day == date.day;
      if (!sameDay) continue;
      final startMin = a.start.hour * 60 + a.start.minute;
      if (startMin < openMin) continue;
      if (_anchorMinutes(startMin, openMin, step) == target) {
        count++;
      }
    }
    return count;
  }

  /// `true` enquanto ainda cabe uma marca no slot. [capacity] já inclui o
  /// overbook (ver `Doctor.capacityAt`). Normaliza capacidade para `>= 1`.
  static bool hasRoom({required int booked, required int capacity}) {
    final cap = capacity < 1 ? 1 : capacity;
    return booked < cap;
  }
}
