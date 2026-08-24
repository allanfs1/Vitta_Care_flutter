import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/core/models/patient_health_score.dart';
import 'package:vitta_app/core/models/plan.dart';
import 'package:vitta_app/core/utils/validators.dart';
import 'package:vitta_app/features/overbooking/occupancy.dart';

void main() {
  group('AppointmentStatus.fromString', () {
    test('reconhece "faltou" (rótulo gravado pelo serviço Firestore)', () {
      expect(AppointmentStatus.fromString('faltou'), AppointmentStatus.noShow);
      expect(AppointmentStatus.fromString('falta'), AppointmentStatus.noShow);
      expect(AppointmentStatus.fromString('no-show'), AppointmentStatus.noShow);
    });

    test('reconhece variações de pré-agendado/reagendado como pending', () {
      expect(AppointmentStatus.fromString('pre-agendado'),
          AppointmentStatus.pending);
      expect(AppointmentStatus.fromString('reagendado'),
          AppointmentStatus.pending);
      expect(AppointmentStatus.fromString('pendente'),
          AppointmentStatus.pending);
    });

    test('normaliza espaços e caixa', () {
      expect(AppointmentStatus.fromString('  Confirmado '),
          AppointmentStatus.confirmed);
      expect(AppointmentStatus.fromString('REALIZADO'),
          AppointmentStatus.completed);
    });

    test('valor nulo/desconhecido cai em pending', () {
      expect(AppointmentStatus.fromString(null), AppointmentStatus.pending);
      expect(AppointmentStatus.fromString('xyz'), AppointmentStatus.pending);
    });

    test('round-trip: apiLabel → fromString devolve o mesmo status (R6)', () {
      for (final s in AppointmentStatus.values) {
        expect(AppointmentStatus.fromString(s.apiLabel), s,
            reason: 'apiLabel "${s.apiLabel}" deveria mapear de volta para $s');
      }
    });

    test('apiLabel usa os rótulos canônicos do Firestore', () {
      expect(AppointmentStatus.noShow.apiLabel, 'faltou');
      expect(AppointmentStatus.pending.apiLabel, 'pre-agendado');
      expect(AppointmentStatus.completed.apiLabel, 'realizado');
    });
  });

  group('OccupancyLevel.from', () {
    test('lotado quando agendados atingem a capacidade', () {
      expect(OccupancyLevel.from(booked: 3, capacity: 3), OccupancyLevel.lotado);
      expect(OccupancyLevel.from(booked: 4, capacity: 3), OccupancyLevel.lotado);
    });

    test('faixas média/últimas/livre por proporção', () {
      expect(OccupancyLevel.from(booked: 0, capacity: 4), OccupancyLevel.livre);
      expect(OccupancyLevel.from(booked: 2, capacity: 4), OccupancyLevel.media);
      expect(
          OccupancyLevel.from(booked: 4, capacity: 5), OccupancyLevel.ultimas);
    });

    test('capacidade <= 0 é normalizada para 1 (não vira falso LOTADO vazio)',
        () {
      expect(OccupancyLevel.from(booked: 0, capacity: 0), OccupancyLevel.livre);
      expect(OccupancyLevel.ratio(booked: 0, capacity: 0), 0);
    });
  });

  group('Doctor.capacityAt', () {
    Doctor doc({
      int slotLimit = 2,
      int maxOverbook = 1,
      int? maxPerSlot,
      Map<String, int> periodOverbook = const {},
      Map<int, int> dayOverbook = const {},
    }) =>
        Doctor(
          id: 'd',
          name: 'Dr',
          crm: 'x',
          specialties: const ['x'],
          slotLimit: slotLimit,
          maxOverbook: maxOverbook,
          maxPerSlot: maxPerSlot,
          periodOverbook: periodOverbook,
          dayOverbook: dayOverbook,
        );

    test('período tem precedência sobre dia e global', () {
      final d = doc(periodOverbook: {'manha': 3});
      // manhã: 2 + 3 = 5; tarde usa global: 2 + 1 = 3.
      expect(d.capacityAt(3, '09:00'), 5);
      expect(d.capacityAt(3, '15:00'), 3);
    });

    test('teto rígido só se aplica quando > 0; nunca zera a capacidade', () {
      expect(doc(maxPerSlot: 3).capacityAt(3, '09:00'), 3); // teto corta
      expect(doc(maxPerSlot: 0).capacityAt(3, '09:00'), 3); // 0 = sem teto
      expect(doc(slotLimit: 0, maxOverbook: 0).capacityAt(3, '09:00'), 1);
    });
  });

  group('HealthClassification.fromScore', () {
    test('faixas de score', () {
      expect(HealthClassification.fromScore(95), HealthClassification.diamante);
      expect(HealthClassification.fromScore(70), HealthClassification.ouro);
      expect(HealthClassification.fromScore(40), HealthClassification.prata);
      expect(HealthClassification.fromScore(0), HealthClassification.bronze);
    });
  });

  group('PatientHealthScore.initials', () {
    PatientHealthScore withName(String n) => PatientHealthScore(
          id: '1',
          patientName: n,
          patientCpf: '',
          classification: HealthClassification.ouro,
          healthScore: 70,
          totalAppointments: 0,
          absences: 0,
          trend: 0,
          doctorName: '',
        );

    test('extrai iniciais de nome composto e simples', () {
      expect(withName('Maria Souza').initials, 'MS');
      expect(withName('Ana').initials, 'A');
      expect(withName('   ').initials, '?');
    });
  });

  group('Plan', () {
    test('yearlyDiscountPercent calcula economia do plano anual', () {
      const p = Plan(
        id: '1',
        name: 'X',
        description: '',
        monthlyPrice: 100,
        yearlyPrice: 1080, // vs 1200 cheio → 10%
        features: [],
      );
      expect(p.yearlyDiscountPercent, 10);
    });

    test('fromFirestore: anual ausente cai para mensal×12 e parseia features',
        () {
      final p = Plan.fromFirestore('id1', {
        'nome': 'Profissional',
        'precoMensal': 50,
        'recursosInclusos': 'Agenda\nRelatórios; IA',
      });
      expect(p.name, 'Profissional');
      expect(p.yearlyPrice, 600); // 50 * 12
      expect(p.features, containsAll(['Agenda', 'Relatórios', 'IA']));
    });
  });

  group('Validators', () {
    test('cpf válido/ inválido', () {
      expect(Validators.cpf('529.982.247-25'), isNull);
      expect(Validators.cpf('111.111.111-11'), isNotNull);
      expect(Validators.cpf('123.456.789-00'), isNotNull);
      expect(Validators.cpf('123'), isNotNull);
    });

    test('email', () {
      expect(Validators.email('user@dominio.com'), isNull);
      expect(Validators.email('invalido'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('password forte exige todos os requisitos', () {
      expect(Validators.password('Abcd123!'), isNull);
      expect(Validators.password('abcd123!'), isNotNull); // sem maiúscula
      expect(Validators.password('Abcdefg!'), isNotNull); // sem número
      expect(Validators.password('Ab1!'), isNotNull); // curta
    });

    test('cep e cnpj checam comprimento', () {
      expect(Validators.cep('01001-000'), isNull);
      expect(Validators.cep('123'), isNotNull);
      expect(Validators.cnpj('11.222.333/0001-81'), isNull);
      expect(Validators.cnpj('123'), isNotNull);
    });
  });
}
