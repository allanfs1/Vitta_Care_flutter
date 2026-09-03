import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/services/appointment_service.dart';
import 'package:vitta_app/features/totem/totem_booking.dart';

/// Testes de **integridade do totem** sob uso concorrente — simula várias
/// pessoas agendando ao mesmo tempo e comprova as correções dos achados
/// F1–F8 (ver `TESTE-SISTER/`). Requisitos em `TESTE-SISTER/REQUISITOS_DE_TESTE.md`.

/// `AppointmentService` in-memory: guarda o que é criado/remarcado e re-emite
/// para quem observa `watchForClinic` — permite abrir uma "nova sessão"
/// (outro `AppointmentsNotifier`) sobre o mesmo repositório.
class FakeAppointmentService implements AppointmentService {
  final List<Appointment> _store = [];
  final StreamController<List<Appointment>> _ctrl =
      StreamController<List<Appointment>>.broadcast();

  /// Snapshot atual (para a revalidação de capacidade feita "na hora").
  List<Appointment> get snapshot => List.of(_store);
  int get length => _store.length;

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(List.of(_store));
  }

  @override
  Stream<List<Appointment>> watchForClinic(String clinicId) async* {
    yield _store.where((a) => a.clinicId == clinicId).toList();
    yield* _ctrl.stream
        .map((all) => all.where((a) => a.clinicId == clinicId).toList());
  }

  @override
  Stream<List<Appointment>> watchForDoctor(String doctorId) async* {
    yield _store.where((a) => a.doctorId == doctorId).toList();
    yield* _ctrl.stream
        .map((all) => all.where((a) => a.doctorId == doctorId).toList());
  }

  @override
  Future<void> create(Appointment appointment) async {
    _store.add(appointment);
    _emit();
  }

  @override
  Future<void> updateStatus(String appointmentId, AppointmentStatus status) async {
    for (var i = 0; i < _store.length; i++) {
      if (_store[i].id == appointmentId) {
        _store[i] = _store[i].copyWith(status: status);
      }
    }
    _emit();
  }

  @override
  Future<void> reschedule(String appointmentId, DateTime newStart) async {
    for (var i = 0; i < _store.length; i++) {
      if (_store[i].id == appointmentId) {
        _store[i] = _store[i].copyWith(
          start: newStart,
          status: AppointmentStatus.pending,
        );
      }
    }
    _emit();
  }

  /// A calibração não faz parte deste teste — devolve o que está em memória
  /// para satisfazer o contrato sem inventar histórico.
  @override
  Future<List<Appointment>> carregarHistoricoCalibracao(
    String clinicId, {
    int dias = 180,
  }) async =>
      List.of(_store);

  void dispose() => _ctrl.close();
}

/// Deixa o event-loop girar para os streams/persistências assíncronas
/// terminarem antes das asserções.
Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final hoje = DateTime.now();
  final dia = DateTime(hoje.year, hoje.month, hoje.day);
  const clinica = 'clinica-teste';

  Appointment agendamento({
    required String id,
    required String patientId,
    required String patientName,
    String doctorId = 'd1',
    int hora = 9,
    int minuto = 0,
    AppointmentStatus status = AppointmentStatus.pending,
  }) {
    return Appointment(
      id: id,
      clinicId: clinica,
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      doctorName: 'Dr. Teste',
      specialty: 'Cardiologia',
      start: DateTime(dia.year, dia.month, dia.day, hora, minuto),
      durationMinutes: 30,
      status: status,
      motivo: 'Agendado via totem',
    );
  }

  group('RT-01/RT-02 — unicidade de id sob concorrência (F1/F5)', () {
    test('10.000 ids de agendamento em laço apertado são todos distintos', () {
      final b = TotemBooking(rng: Random(42));
      final ids = [for (var i = 0; i < 10000; i++) b.newAppointmentId()];
      expect(ids.toSet().length, ids.length,
          reason: 'houve colisão de id de agendamento');
      expect(ids.every((s) => RegExp(r'^apt-\d+-\d+-\d+$').hasMatch(s)), isTrue);
    });

    test('10 ids de agendamento criados "ao mesmo tempo" (Future.wait) são distintos',
        () async {
      final b = TotemBooking(); // Random real
      final ids = await Future.wait([
        for (var i = 0; i < 10; i++)
          Future(() async {
            await Future<void>.delayed(Duration.zero);
            return b.newAppointmentId();
          }),
      ]);
      expect(ids.toSet().length, 10, reason: '2 pessoas pegaram o mesmo id');
    });

    test('ids de paciente-convidado simultâneos não colidem (não fundem pessoas)',
        () async {
      final b = TotemBooking();
      final loop = [for (var i = 0; i < 10000; i++) b.newGuestPatientId()];
      expect(loop.toSet().length, loop.length);
      final par = await Future.wait([
        for (var i = 0; i < 10; i++)
          Future(() async {
            await Future<void>.delayed(Duration.zero);
            return b.newGuestPatientId();
          }),
      ]);
      expect(par.toSet().length, 10);
      expect(loop.every((s) => RegExp(r'^totem-\d+-\d+-\d+$').hasMatch(s)), isTrue);
    });
  });

  group('RT-03/RT-04 — persistência entre sessões (F2)', () {
    test('um agendamento feito via create() reaparece numa sessão nova', () async {
      final svc = FakeAppointmentService();
      addTearDown(svc.dispose);

      final sessao1 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao1.dispose);
      await _flush();

      final appt = agendamento(
          id: 'apt-x', patientId: 'cpf-1', patientName: 'Ana');
      sessao1.create(appt);
      await _flush();

      final sessao2 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao2.dispose);
      await _flush();

      expect(sessao2.state.any((a) => a.id == 'apt-x'), isTrue,
          reason: 'agendamento do totem não persistiu (agendamento-fantasma)');
    });

    test('espelho negativo: add() (método antigo) NÃO sobrevive à sessão', () async {
      final svc = FakeAppointmentService();
      addTearDown(svc.dispose);

      final sessao1 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao1.dispose);
      await _flush();
      // ignore: deprecated_member_use_from_same_package
      sessao1.add(agendamento(
          id: 'apt-volatil', patientId: 'cpf-9', patientName: 'Fantasma'));
      await _flush();

      final sessao2 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao2.dispose);
      await _flush();

      expect(sessao2.state.any((a) => a.id == 'apt-volatil'), isFalse,
          reason: 'add() não deveria persistir — é o bug F2');
    });

    test('10 agendamentos SIMULTÂNEOS de 10 pacientes distintos sobrevivem todos',
        () async {
      final svc = FakeAppointmentService();
      addTearDown(svc.dispose);
      final booking = TotemBooking();

      final sessao1 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao1.dispose);
      await _flush();

      // Cada "pessoa no totem" agenda em paralelo, com CPF/paciente próprios.
      await Future.wait([
        for (var i = 0; i < 10; i++)
          Future(() async {
            await Future<void>.delayed(Duration.zero);
            sessao1.create(agendamento(
              id: booking.newAppointmentId(),
              patientId: booking.newGuestPatientId(),
              patientName: 'Paciente $i',
              hora: 8 + i, // horários distintos: ninguém disputa o mesmo slot
            ));
          }),
      ]);
      await _flush();

      final sessao2 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao2.dispose);
      await _flush();

      final novos = sessao2.state
          .where((a) => a.motivo == 'Agendado via totem')
          .toList();
      expect(novos.length, 10, reason: 'nem todos os 10 persistiram');
      expect(novos.map((a) => a.id).toSet().length, 10,
          reason: 'ids colidiram sob concorrência');
      expect(novos.map((a) => a.patientId).toSet().length, 10,
          reason: 'patientIds colidiram — pacientes fundidos');
    });
  });

  group('RT-05/RT-08 — capacidade do slot sob concorrência (F3)', () {
    test('hasRoom respeita capacidade e normaliza capacidade zero', () {
      expect(TotemBooking.hasRoom(booked: 2, capacity: 3), isTrue);
      expect(TotemBooking.hasRoom(booked: 3, capacity: 3), isFalse);
      expect(TotemBooking.hasRoom(booked: 0, capacity: 0), isTrue); // cap→1
      expect(TotemBooking.hasRoom(booked: 1, capacity: 0), isFalse);
    });

    test('bookedInSlot conta só ativos do médico/dia/slot e ancora na grade', () {
      final appts = [
        agendamento(id: 'a', patientId: 'p1', patientName: 'A', hora: 9, minuto: 0),
        agendamento(id: 'b', patientId: 'p2', patientName: 'B', hora: 9, minuto: 15),
        agendamento(
            id: 'c',
            patientId: 'p3',
            patientName: 'C',
            hora: 9,
            minuto: 0,
            status: AppointmentStatus.cancelled),
        agendamento(
            id: 'd', patientId: 'p4', patientName: 'D', hora: 9, doctorId: 'd2'),
        agendamento(id: 'e', patientId: 'p5', patientName: 'E', hora: 10),
      ];
      final n = TotemBooking.bookedInSlot(
        appointments: appts,
        date: dia,
        doctorId: 'd1',
        slotTime: '09:00',
        appointmentDuration: 30,
        openHour: 7,
      );
      expect(n, 2, reason: '09:00 e 09:15 do d1 contam; cancelado/d2/10:00 não');

      final ignorando = TotemBooking.bookedInSlot(
        appointments: appts,
        date: dia,
        doctorId: 'd1',
        slotTime: '09:00',
        appointmentDuration: 30,
        openHour: 7,
        ignoreApptId: 'a',
      );
      expect(ignorando, 1);
    });

    test('10 reservas concorrentes no MESMO slot: só a capacidade (3) confirma',
        () async {
      final svc = FakeAppointmentService();
      addTearDown(svc.dispose);
      final booking = TotemBooking();
      const capacidadeEfetiva = 3; // base + overbook (Doctor.capacityAt)

      Future<bool> tentarAgendar(int i) async {
        await Future<void>.delayed(Duration.zero); // ponto de entrelaçamento
        final ocupados = TotemBooking.bookedInSlot(
          appointments: svc.snapshot,
          date: dia,
          doctorId: 'd1',
          slotTime: '09:00',
          appointmentDuration: 30,
          openHour: 7,
        );
        if (!TotemBooking.hasRoom(
            booked: ocupados, capacity: capacidadeEfetiva)) {
          return false;
        }
        await svc.create(agendamento(
          id: booking.newAppointmentId(),
          patientId: 'cpf-$i',
          patientName: 'Paciente $i',
          hora: 9,
          minuto: 0,
        ));
        return true;
      }

      final resultados =
          await Future.wait([for (var i = 0; i < 10; i++) tentarAgendar(i)]);
      final confirmadas = resultados.where((ok) => ok).length;

      expect(confirmadas, capacidadeEfetiva,
          reason: 'capacidade do slot foi estourada por concorrência');
      expect(resultados.where((ok) => !ok).length, 10 - capacidadeEfetiva);
      expect(svc.length, capacidadeEfetiva);
    });
  });

  group('RT-06 — senha de fila sem colisão (F6)', () {
    test('200 senhas da mesma especialidade, com dedupe, são todas distintas', () {
      final b = TotemBooking(rng: Random(7));
      final taken = <String>{};
      for (var i = 0; i < 200; i++) {
        final s = b.senha('Cardiologia', taken: taken);
        expect(taken.contains(s), isFalse, reason: 'senha repetida: $s');
        expect(RegExp(r'^C\d{3,}$').hasMatch(s), isTrue);
        taken.add(s);
      }
      expect(taken.length, 200);
    });

    test('contraste: o esquema antigo (3 dígitos, sem dedupe) colide em 200 emissões',
        () {
      final rng = Random(7);
      String senhaAntiga(String esp) =>
          '${esp[0].toUpperCase()}${100 + rng.nextInt(900)}';
      final emitidas = [for (var i = 0; i < 200; i++) senhaAntiga('Cardiologia')];
      expect(emitidas.toSet().length, lessThan(emitidas.length),
          reason: 'o esquema antigo deveria colidir — é o bug F6');
    });
  });

  group('RT-07 — remarcação pelo totem persiste (F8)', () {
    test('move() grava o novo horário; sessão nova vê a mudança', () async {
      final svc = FakeAppointmentService();
      addTearDown(svc.dispose);

      final sessao1 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao1.dispose);
      await _flush();

      final original = agendamento(
          id: 'apt-rm', patientId: 'cpf-7', patientName: 'Rita', hora: 9);
      sessao1.create(original);
      await _flush();

      final novoHorario = DateTime(dia.year, dia.month, dia.day, 15, 30);
      sessao1.move('apt-rm', start: novoHorario);
      await _flush();

      final sessao2 = AppointmentsNotifier(svc, clinica);
      addTearDown(sessao2.dispose);
      await _flush();

      final rm = sessao2.state.firstWhere((a) => a.id == 'apt-rm');
      expect(rm.start, novoHorario,
          reason: 'remarcação não persistiu — some no reload');
      expect(rm.status, AppointmentStatus.pending);
    });
  });
}
