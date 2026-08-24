import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/services/appointment_service.dart';
import 'package:vitta_app/core/services/doctor_service.dart';
import 'package:vitta_app/features/equipe_medica/medico_agenda_screen.dart';

import '../helpers.dart';

/// Testes do módulo Equipe Médica: serviço `tb_medicos`, filtro por clínica,
/// CRUD, e a agenda pública do médico em tempo real (PM-09).
void main() {
  // A agenda formata datas em pt_BR (intl) — inicializa como o app faz no main.
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('MockDoctorService', () {
    const service = MockDoctorService();

    test('seed filtra pela clínica quando há vínculo (c1)', () {
      final ids = service.seed('c1').map((d) => d.id).toSet();
      expect(ids, containsAll(['d1', 'd2', 'd4']));
      expect(ids.contains('d3'), isFalse);
    });

    test('seed cai para toda a equipe quando a clínica não tem médicos', () {
      // c3 não tem médico vinculado → devolve todos (fallback anti-lista-vazia).
      expect(service.seed('c3').length, service.seed('nao-existe').length);
      expect(service.seed('c3'), isNotEmpty);
    });

    test('fetchById encontra o médico e devolve null quando não existe', () async {
      expect((await service.fetchById('d1'))?.id, 'd1');
      expect(await service.fetchById('zzz'), isNull);
    });

    test('watchAll devolve o catálogo global de médicos', () async {
      final all = await service.watchAll().first;
      expect(all.map((d) => d.id), containsAll(['d1', 'd2', 'd3', 'd4']));
    });
  });

  group('MockAppointmentService.watchForDoctor', () {
    test('retorna somente as consultas do médico informado', () async {
      const service = MockAppointmentService();
      final list = await service.watchForDoctor('d1').first;
      expect(list, isNotEmpty);
      expect(list.every((a) => a.doctorId == 'd1'), isTrue);
    });
  });

  group('clinicDoctorsProvider + CRUD', () {
    test('lista os médicos da clínica selecionada (c1) e exclui d3', () async {
      final c = await makeContainer();
      final ids = c.read(clinicDoctorsProvider).map((d) => d.id).toSet();
      expect(ids, containsAll(['d1', 'd2', 'd4']));
      expect(ids.contains('d3'), isFalse);
    });

    test('add insere e setActive/softDelete desativam', () async {
      final c = await makeContainer();
      final notifier = c.read(clinicDoctorsProvider.notifier);
      final before = c.read(clinicDoctorsProvider).length;

      notifier.add(const Doctor(
        id: 'dX',
        name: 'Dr. Teste',
        crm: '999-SP',
        specialties: ['Clínica Geral'],
        clinicId: 'c1',
      ));
      expect(c.read(clinicDoctorsProvider).length, before + 1);

      notifier.softDelete('dX');
      final dx = c.read(clinicDoctorsProvider).firstWhere((d) => d.id == 'dX');
      expect(dx.active, isFalse);
    });
  });

  group('providers da agenda pública', () {
    test('doctorByIdProvider resolve o médico por id', () async {
      final c = await makeContainer();
      final d = await c.read(doctorByIdProvider('d1').future);
      expect(d?.id, 'd1');
    });

    test('doctorAgendaProvider traz só as consultas do médico', () async {
      final c = await makeContainer();
      final list = await c.read(doctorAgendaProvider('d1').future);
      expect(list.every((a) => a.doctorId == 'd1'), isTrue);
    });
  });

  testWidgets('agenda pública do médico renderiza em tempo real', (tester) async {
    await tester.pumpWidget(await wrap(const MedicoAgendaScreen(doctorId: 'd1')));
    await settle(tester);

    expect(find.text('Agenda em tempo real'), findsOneWidget);
    // Após resolver o FutureProvider, o nome do médico aparece no título.
    expect(find.textContaining('Roberto'), findsWidgets);
  });
}
