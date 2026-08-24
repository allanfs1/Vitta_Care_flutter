import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/core/services/app_providers.dart';

import '../helpers.dart';

/// Testes de unidade do estado compartilhado (Riverpod): seleção de clínica
/// (H-01) e mutações de agendamentos (A-03).
void main() {
  test('clínica padrão é a primeira quando não há preferência', () async {
    final c = await makeContainer();
    final clinics = c.read(clinicsProvider);
    expect(c.read(selectedClinicIdProvider), clinics.first.id);
  });

  test('seleção de clínica persiste e atualiza selectedClinicProvider', () async {
    final c = await makeContainer();
    // O usuário mock está vinculado a c1/c2 — seleciona c2 (uma das suas).
    c.read(selectedClinicIdProvider.notifier).select('c2');
    expect(c.read(selectedClinicIdProvider), 'c2');
    expect(c.read(selectedClinicProvider).id, 'c2');
  });

  test('selecionar clínica fora do usuário cai para a 1ª clínica dele', () async {
    final c = await makeContainer();
    // c4 (privada) não pertence ao usuário mock (c1/c2) → resolve para c1.
    c.read(selectedClinicIdProvider.notifier).select('c4');
    expect(c.read(selectedClinicProvider).id, 'c1');
  });

  test('clínica selecionada é restaurada das preferências', () async {
    final c = await makeContainer(prefs: {'selected_clinic_id': 'c2'});
    expect(c.read(selectedClinicIdProvider), 'c2');
  });

  test('AppointmentsNotifier.setStatus altera apenas o alvo', () async {
    final c = await makeContainer();
    final before = c.read(appointmentsProvider);
    final id = before.first.id;
    c.read(appointmentsProvider.notifier).setStatus(id, AppointmentStatus.cancelled);
    final after = c.read(appointmentsProvider);
    expect(after.firstWhere((a) => a.id == id).status, AppointmentStatus.cancelled);
    expect(after.length, before.length);
  });

  test('AppointmentsNotifier.reschedule muda data e volta a pendente', () async {
    final c = await makeContainer();
    final id = c.read(appointmentsProvider).first.id;
    final newStart = DateTime(2026, 7, 1, 15, 30);
    c.read(appointmentsProvider.notifier).reschedule(id, newStart);
    final a = c.read(appointmentsProvider).firstWhere((x) => x.id == id);
    expect(a.start, newStart);
    expect(a.status, AppointmentStatus.pending);
  });

  test('AppointmentsNotifier.create adiciona o agendamento manual (A-02)', () async {
    final c = await makeContainer();
    final before = c.read(appointmentsProvider);
    final start = DateTime(2026, 7, 10, 9, 30);
    final novo = Appointment(
      id: 'apt-manual-1',
      clinicId: c.read(selectedClinicIdProvider),
      patientId: 'p1',
      patientName: 'Maria Santos',
      doctorId: 'd1',
      doctorName: 'Dr. Roberto Santos',
      specialty: 'Cardiologia',
      start: start,
      durationMinutes: 30,
      status: AppointmentStatus.pending,
    );

    c.read(appointmentsProvider.notifier).create(novo);

    final after = c.read(appointmentsProvider);
    expect(after.length, before.length + 1);
    final criado = after.firstWhere((a) => a.id == 'apt-manual-1');
    expect(criado.patientName, 'Maria Santos');
    expect(criado.start, start);
    expect(criado.status, AppointmentStatus.pending);
  });
}
