import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/overbooking/overbooking_engine.dart';

Doctor _doc({int slotLimit = 1, int maxOverbook = 1}) => Doctor(
      id: 'd1',
      name: 'Dr. Teste',
      crm: 'CRM/SP 111',
      specialties: const ['Clínico Geral'],
      slotLimit: slotLimit,
      maxOverbook: maxOverbook,
    );

Appointment _appt(
  String id,
  DateTime start, {
  AppointmentStatus status = AppointmentStatus.confirmed,
  RiskLevel risk = RiskLevel.low,
  String phone = '11999999999',
}) =>
    Appointment(
      id: id,
      clinicId: 'c1',
      patientId: 'p$id',
      patientName: 'Paciente $id',
      doctorId: 'd1',
      doctorName: 'Dr. Teste',
      specialty: 'Clínico Geral',
      start: start,
      durationMinutes: 30,
      status: status,
      patientRisk: risk,
      patientPhone: phone,
    );

void main() {
  // Uma quarta-feira qualquer (weekday = 3), horário comercial.
  final dia = DateTime(2026, 7, 8, 9);

  test('detecta estouro quando agendados excedem a capacidade', () {
    final doc = _doc(slotLimit: 1, maxOverbook: 1); // capacidade = 2
    final appts = [
      _appt('a', dia),
      _appt('b', dia),
      _appt('c', dia), // 3 no slot 09h → estouro de 1
    ];
    final snap = OverbookingEngine.build(
      date: dia,
      doctors: [doc],
      allAppointments: appts,
      now: dia,
    );
    expect(snap.estouroTotal, 1);
    expect(snap.slotsSobrecarga.length, 1);
    expect(snap.slotsSobrecarga.first.candidatos.length, 1);
  });

  test('escolhe o candidato mais tolerante (pendente + baixo risco)', () {
    final doc = _doc(slotLimit: 1, maxOverbook: 1); // capacidade = 2
    final appts = [
      _appt('conf-alto', dia,
          status: AppointmentStatus.confirmed, risk: RiskLevel.high),
      _appt('conf-baixo', dia,
          status: AppointmentStatus.confirmed, risk: RiskLevel.low),
      _appt('pend-baixo', dia,
          status: AppointmentStatus.pending, risk: RiskLevel.low),
    ];
    final snap = OverbookingEngine.build(
      date: dia,
      doctors: [doc],
      allAppointments: appts,
      now: dia,
    );
    // 3 agendados, capacidade 2 → 1 candidato: o pendente de baixo risco.
    final cand = snap.slotsSobrecarga.first.candidatos.single;
    expect(cand.appointment.id, 'pend-baixo');
  });

  test('sugere um novo horário futuro com vaga livre para o mesmo médico', () {
    final doc = _doc(slotLimit: 1, maxOverbook: 1);
    final appts = [
      _appt('a', dia),
      _appt('b', dia),
      _appt('c', dia),
    ];
    final snap = OverbookingEngine.build(
      date: dia,
      doctors: [doc],
      allAppointments: appts,
      now: dia,
    );
    final destino = snap.slotsSobrecarga.first.candidatos.single.destino;
    expect(destino, isNotNull);
    expect(destino!.isAfter(dia), isTrue);
  });

  test('não realoca pacientes realizados ou faltantes', () {
    final doc = _doc(slotLimit: 1, maxOverbook: 0); // capacidade = 1
    final appts = [
      _appt('feito', dia, status: AppointmentStatus.completed),
      _appt('faltou', dia, status: AppointmentStatus.noShow),
      _appt('ativo', dia, status: AppointmentStatus.confirmed),
    ];
    // completed/noShow não contam como sobrecarga elegível; só 'ativo' é elegível.
    final snap = OverbookingEngine.build(
      date: dia,
      doctors: [doc],
      allAppointments: appts,
      now: dia,
    );
    for (final s in snap.slotsSobrecarga) {
      for (final c in s.candidatos) {
        expect(
          c.appointment.status == AppointmentStatus.completed ||
              c.appointment.status == AppointmentStatus.noShow,
          isFalse,
        );
      }
    }
  });
}
