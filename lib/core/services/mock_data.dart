import '../models/appointment.dart';
import '../models/app_user.dart';
import '../models/clinic.dart';
import '../models/doctor.dart';
import '../models/enums.dart';
import '../models/patient.dart';
import '../models/patient_feedback.dart';
import '../models/patient_health_score.dart';
import '../models/plan.dart';

/// Fonte de dados mock que espelha a estrutura do Firestore (`database.md`).
///
/// Substitua estas funções por chamadas reais ao Firebase quando as credenciais
/// (`.specify/api-key.js`) forem integradas — a forma dos modelos já corresponde
/// às coleções `tb_clinica`, `tb_medicos`, `tb_agendamentos` e `users`.
class MockData {
  MockData._();

  static const usuarioAtual = AppUser(
    id: 'u1',
    firstName: 'Carlos',
    lastName: 'Silva',
    email: 'dr.silva@vitta.app',
    phone: '(11) 98888-0001',
    cpf: '529.982.247-25',
    gender: 'Masculino',
    roleLabel: 'Gestor Clínico',
    address: UserAddress(
      cep: '01310-100',
      street: 'Av. Paulista',
      number: '1000',
      district: 'Bela Vista',
      city: 'São Paulo',
      state: 'SP',
    ),
    clinicIds: ['c1', 'c2'], // Apenas 2 clínicas vinculadas ao mock user
  );

  static final List<Clinic> clinics = [
    Clinic(
      id: 'c1',
      name: 'UBS Centro',
      type: ClinicType.ubs,
      razaoSocial: 'Prefeitura Municipal — UBS Centro',
      cnpj: '12.345.678/0001-90',
      email: 'ubs.centro@saude.gov.br',
      phone: '(11) 3333-1000',
      website: 'www.saude.gov.br',
      address: const ClinicAddress(
        cep: '01001-000',
        street: 'Praça da Sé',
        number: '100',
        district: 'Sé',
        city: 'São Paulo',
        state: 'SP',
      ),
      specialties: const ['Clínica Geral', 'Cardiologia', 'Pediatria', 'Enfermagem'],
      businessHours: _defaultHours(),
      latitude: -23.55052,
      longitude: -46.633308,
    ),
    Clinic(
      id: 'c2',
      name: 'UPA Zona Leste',
      type: ClinicType.upa,
      email: 'upa.leste@saude.gov.br',
      phone: '(11) 3333-2000',
      address: const ClinicAddress(city: 'São Paulo', state: 'SP', district: 'Itaquera'),
      specialties: const ['Emergência', 'Clínica Geral', 'Ortopedia'],
      businessHours: _defaultHours(),
    ),
    Clinic(
      id: 'c3',
      name: 'APS Vila Nova',
      type: ClinicType.aps,
      email: 'aps.vilanova@saude.gov.br',
      phone: '(11) 3333-3000',
      address: const ClinicAddress(city: 'São Paulo', state: 'SP', district: 'Vila Nova'),
      specialties: const ['Clínica Geral', 'Saúde da Família', 'Ginecologia'],
      businessHours: _defaultHours(),
    ),
    Clinic(
      id: 'c4',
      name: 'Clínica Vitta Premium',
      type: ClinicType.privada,
      razaoSocial: 'Vitta Saúde Ltda.',
      cnpj: '98.765.432/0001-10',
      email: 'contato@vittapremium.com.br',
      phone: '(11) 4000-9000',
      website: 'www.vittapremium.com.br',
      address: const ClinicAddress(
        cep: '04538-132',
        street: 'Av. Brigadeiro Faria Lima',
        number: '3500',
        district: 'Itaim Bibi',
        city: 'São Paulo',
        state: 'SP',
      ),
      specialties: const [
        'Cardiologia',
        'Dermatologia',
        'Ortopedia',
        'Endocrinologia',
        'Neurologia',
      ],
      businessHours: _defaultHours(),
      latitude: -23.585883,
      longitude: -46.682246,
    ),
  ];

  /// Planos de assinatura (`tb_plans`).
  static const List<Plan> plans = [
    Plan(
      id: 'plan_basic',
      name: 'Essencial',
      description: 'Para unidades começando a digitalizar a gestão.',
      monthlyPrice: 99,
      yearlyPrice: 990,
      userLimit: 3,
      appointmentLimit: 500,
      supportLevel: 'E-mail',
      features: [
        'Dashboard e agenda',
        'Até 3 usuários',
        '500 agendamentos/mês',
        'Relatórios básicos',
      ],
    ),
    Plan(
      id: 'plan_pro',
      name: 'Profissional',
      description: 'Para clínicas que querem reduzir o absenteísmo com IA.',
      monthlyPrice: 249,
      yearlyPrice: 2390,
      isPopular: true,
      userLimit: 15,
      appointmentLimit: 5000,
      supportLevel: 'Prioritário',
      hasIntegrations: true,
      features: [
        'Tudo do Essencial',
        'Análises e relatórios por IA',
        'Integração WhatsApp (Z-API)',
        'Até 15 usuários',
        'Score de risco de faltas',
      ],
    ),
    Plan(
      id: 'plan_enterprise',
      name: 'Enterprise',
      description: 'Para redes e operações de grande porte.',
      monthlyPrice: 599,
      yearlyPrice: 5750,
      userLimit: null,
      appointmentLimit: null,
      supportLevel: 'Dedicado 24/7',
      hasIntegrations: true,
      features: [
        'Tudo do Profissional',
        'Agendamento inteligente B2B',
        'Usuários ilimitados',
        'Multi-unidades',
        'Suporte dedicado 24/7',
      ],
    ),
    Plan(
      id: 'plan_public_unlimited',
      name: 'Público Ilimitado',
      description: 'Plano ilimitado e exclusivo para unidades UBS, UPA e APS.',
      monthlyPrice: 0,
      yearlyPrice: 0,
      userLimit: null,
      appointmentLimit: null,
      supportLevel: 'Dedicado 24/7',
      hasIntegrations: true,
      features: [
        'Exclusivo para UBS, UPA e APS',
        'Agendamentos ilimitados',
        'Usuários e unidades ilimitadas',
        'Integrações com sistemas públicos',
        'Suporte dedicado 24/7',
      ],
    ),
  ];

  static List<BusinessHour> _defaultHours() => [
        for (var d = 1; d <= 5; d++)
          BusinessHour(weekday: d, open: '07:00', close: '19:00'),
        const BusinessHour(weekday: 6, open: '08:00', close: '12:00'),
        const BusinessHour(weekday: 7, closed: true),
      ];

  static final List<Doctor> doctors = [
    const Doctor(
      id: 'd1',
      name: 'Dr. Roberto Santos',
      crm: '123456-SP',
      specialties: ['Cardiologia'],
      clinicId: 'c1',
      email: 'roberto.santos@vitta.app',
      phone: '(11) 97777-1001',
      bio: 'Cardiologista com foco em prevenção e reabilitação cardíaca.',
      experience: '15 anos de atuação clínica e hospitalar.',
      ticket: 350,
      monthlyConsultations: 128,
      occupancyRate: 0.82,
      absenceRate: 0.14,
      slotLimit: 1,
      maxOverbook: 2,
      maxPerSlot: 3,
    ),
    const Doctor(
      id: 'd2',
      name: 'Dra. Ana Pereira',
      crm: '234567-SP',
      specialties: ['Pediatria'],
      clinicId: 'c1',
      email: 'ana.pereira@vitta.app',
      phone: '(11) 97777-1002',
      ticket: 280,
      monthlyConsultations: 96,
      occupancyRate: 0.74,
      absenceRate: 0.19,
      slotLimit: 1,
      maxOverbook: 1,
    ),
    const Doctor(
      id: 'd3',
      name: 'Dr. Marcos Lima',
      crm: '345678-SP',
      specialties: ['Clínica Geral'],
      clinicId: 'c2',
      email: 'marcos.lima@vitta.app',
      phone: '(11) 97777-1003',
      ticket: 200,
      monthlyConsultations: 142,
      occupancyRate: 0.68,
      absenceRate: 0.22,
      slotLimit: 2,
      maxOverbook: 1,
      periodOverbook: {'manha': 3},
      maxPerSlot: 5,
    ),
    const Doctor(
      id: 'd4',
      name: 'Dra. Juliana Costa',
      crm: '456789-SP',
      specialties: ['Dermatologia'],
      clinicId: 'c1',
      email: 'juliana.costa@vitta.app',
      phone: '(11) 97777-1004',
      ticket: 320,
      monthlyConsultations: 88,
      occupancyRate: 0.79,
      absenceRate: 0.11,
      slotLimit: 1,
      maxOverbook: 0,
    ),
  ];

  static final List<Patient> patients = [
    const Patient(
      id: 'p1',
      name: 'Maria Santos',
      phone: '(11) 98765-4321',
      cpf: '111.444.777-35',
      age: 68,
      gender: 'Feminino',
      riskScore: 0.82,
      absencesYtd: 4,
      attendedYtd: 12,
    ),
    const Patient(
      id: 'p2',
      name: 'João Oliveira',
      phone: '(11) 91234-5678',
      age: 45,
      gender: 'Masculino',
      riskScore: 0.61,
      absencesYtd: 3,
      attendedYtd: 9,
    ),
    const Patient(
      id: 'p3',
      name: 'Ana Lima',
      phone: '(11) 99876-5432',
      age: 33,
      gender: 'Feminino',
      riskScore: 0.58,
      absencesYtd: 3,
      attendedYtd: 15,
    ),
    const Patient(
      id: 'p4',
      name: 'Carlos Souza',
      phone: '(11) 95555-1212',
      age: 52,
      gender: 'Masculino',
      riskScore: 0.21,
      absencesYtd: 1,
      attendedYtd: 20,
    ),
  ];

  /// Agendamentos do dia atual + próximos, para a clínica informada.
  static List<Appointment> appointmentsFor(String clinicId) {
    final today = DateTime.now();
    DateTime at(int dayOffset, int h, int m) =>
        DateTime(today.year, today.month, today.day + dayOffset, h, m);

    return [
      Appointment(
        id: 'a1',
        clinicId: clinicId,
        patientId: 'p1',
        patientName: 'Maria Oliveira',
        doctorId: 'd1',
        doctorName: 'Dr. Roberto Santos',
        specialty: 'Cardiologia',
        start: at(0, 9, 0),
        durationMinutes: 45,
        status: AppointmentStatus.confirmed,
        tipoConsulta: 'Retorno',
        crm: '123456-SP',
        local: 'UBS Centro',
        motivo: 'Acompanhamento de hipertensão',
        patientPhone: '(11) 98765-4321',
        patientRisk: RiskLevel.low,
        preparo: const [
          'Jejum de 8 horas',
          'Trazer exames anteriores (sangue e eletrocardiograma)',
          'Chegar com 15 minutos de antecedência',
        ],
      ),
      Appointment(
        id: 'a2',
        clinicId: clinicId,
        patientId: 'p2',
        patientName: 'João Santos',
        doctorId: 'd3',
        doctorName: 'Dr. Marcos Lima',
        specialty: 'Clínica Geral',
        start: at(0, 9, 30),
        durationMinutes: 30,
        status: AppointmentStatus.pending,
        tipoConsulta: 'Check-up geral',
        crm: '345678-SP',
        local: 'UBS Centro',
        patientPhone: '(11) 91234-5678',
        patientRisk: RiskLevel.medium,
        firstVisit: true,
      ),
      Appointment(
        id: 'a3',
        clinicId: clinicId,
        patientId: 'p3',
        patientName: 'Ana Costa',
        doctorId: 'd3',
        doctorName: 'Dr. Marcos Lima',
        specialty: 'Clínica Geral',
        start: at(0, 10, 30),
        durationMinutes: 30,
        status: AppointmentStatus.pending,
        tipoConsulta: 'Primeira consulta',
        crm: '345678-SP',
        firstVisit: true,
        patientRisk: RiskLevel.medium,
      ),
      Appointment(
        id: 'a4',
        clinicId: clinicId,
        patientId: 'p4',
        patientName: 'João Souza',
        doctorId: 'd1',
        doctorName: 'Dr. Roberto Santos',
        specialty: 'Cardiologia',
        start: at(0, 10, 0),
        durationMinutes: 30,
        status: AppointmentStatus.confirmed,
        tipoConsulta: 'Consulta',
        crm: '123456-SP',
        lateMinutes: 15,
        patientRisk: RiskLevel.high,
      ),
      Appointment(
        id: 'a5',
        clinicId: clinicId,
        patientId: 'p2',
        patientName: 'Pedro Almeida',
        doctorId: 'd4',
        doctorName: 'Dra. Juliana Costa',
        specialty: 'Dermatologia',
        start: at(1, 14, 0),
        durationMinutes: 30,
        status: AppointmentStatus.confirmed,
        tipoConsulta: 'Retorno',
      ),
      Appointment(
        id: 'a6',
        clinicId: clinicId,
        patientId: 'p3',
        patientName: 'Beatriz Rocha',
        doctorId: 'd2',
        doctorName: 'Dra. Ana Pereira',
        specialty: 'Pediatria',
        start: at(2, 11, 0),
        durationMinutes: 30,
        status: AppointmentStatus.cancelled,
        tipoConsulta: 'Consulta',
      ),
    ];
  }

  // ---- Métricas e séries para dashboards (H-04, H-05, AB-*). ----

  static List<Kpi> homeKpis() => const [
        Kpi(label: 'Taxa de Ocupação', value: '78', suffix: '%', delta: 3.2),
        Kpi(label: 'Taxa de Comparecimento', value: '82', suffix: '%', delta: 1.4),
        Kpi(
          label: 'Taxa de Cancelamento',
          value: '12',
          suffix: '%',
          delta: -0.8,
          deltaPositive: false,
        ),
        Kpi(label: 'Tempo Médio de Espera', value: '14', suffix: 'min', delta: -2.0),
        Kpi(label: 'Tempo Médio de Atendimento', value: '23', suffix: 'min'),
        Kpi(label: 'Satisfação do Paciente', value: '4.6', suffix: '/5', delta: 0.2),
      ];

  static List<TimeSeriesPoint> appointmentTrend() => const [
        TimeSeriesPoint('Seg', 42),
        TimeSeriesPoint('Ter', 55),
        TimeSeriesPoint('Qua', 48),
        TimeSeriesPoint('Qui', 63),
        TimeSeriesPoint('Sex', 58),
        TimeSeriesPoint('Sáb', 30),
      ];

  static List<TimeSeriesPoint> absenteeismTrend() => const [
        TimeSeriesPoint('Jan', 22),
        TimeSeriesPoint('Fev', 19),
        TimeSeriesPoint('Mar', 21),
        TimeSeriesPoint('Abr', 17),
        TimeSeriesPoint('Mai', 18),
        TimeSeriesPoint('Jun', 16),
      ];

  static List<TimeSeriesPoint> absenteeismByUnit() => const [
        TimeSeriesPoint('UBS', 21),
        TimeSeriesPoint('UPA', 12),
        TimeSeriesPoint('APS', 15),
      ];

  static List<TimeSeriesPoint> cancellationBreakdown() => const [
        TimeSeriesPoint('Paciente', 48),
        TimeSeriesPoint('Clínica', 22),
        TimeSeriesPoint('Médico', 18),
        TimeSeriesPoint('Sistema', 12),
      ];

  static List<TimeSeriesPoint> absenteeismBySpecialty() => const [
        TimeSeriesPoint('Cardiologia', 14),
        TimeSeriesPoint('Pediatria', 19),
        TimeSeriesPoint('Clínica Geral', 22),
        TimeSeriesPoint('Dermatologia', 11),
      ];

  /// Mapa de calor: linhas = dias úteis, colunas = horas (8h–17h). Valor 0..1.
  static List<List<double>> heatmap() => const [
        [0.2, 0.4, 0.6, 0.8, 0.5, 0.3, 0.7, 0.9, 0.4, 0.2],
        [0.3, 0.5, 0.7, 0.6, 0.4, 0.5, 0.8, 0.7, 0.3, 0.1],
        [0.1, 0.3, 0.5, 0.9, 0.6, 0.4, 0.6, 0.5, 0.2, 0.2],
        [0.4, 0.6, 0.8, 0.7, 0.5, 0.6, 0.9, 0.8, 0.5, 0.3],
        [0.2, 0.3, 0.4, 0.5, 0.7, 0.8, 0.6, 0.4, 0.3, 0.1],
      ];

  static final List<PatientFeedback> patientFeedbacks = [
    PatientFeedback(
      id: 'fb1',
      patientName: 'Roberto Souza Lima',
      patientId: '#89923783',
      patientEmail: 'roberto@email.com',
      patientCpf: '111.222.333-44',
      protocol: '240501',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      systemRating: 4,
      unitRating: 1,
      teamRating: 5,
    ),
    PatientFeedback(
      id: 'fb2',
      patientName: 'Ana Beatriz Oliveira',
      patientId: '#79536283',
      patientEmail: 'ana.beatriz@email.com',
      patientCpf: '555.666.777-88',
      protocol: '240502',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      systemRating: 5,
      unitRating: 5,
      teamRating: 5,
    ),
    PatientFeedback(
      id: 'fb3',
      patientName: 'Carlos Eduardo Ferreira',
      patientId: '#54154875',
      patientEmail: 'carlos.edu@email.com',
      patientCpf: '999.888.777-66',
      protocol: '240503',
      createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      systemRating: 1,
      unitRating: 2,
      teamRating: 2,
    ),
    PatientFeedback(
      id: 'fb4',
      patientName: 'Maria Aparecida Santos',
      patientId: '#43890582',
      patientEmail: 'maria.santos@email.com',
      patientCpf: '123.456.789-00',
      protocol: '240504',
      createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      systemRating: 4,
      unitRating: 5,
      teamRating: 5,
    ),
    PatientFeedback(
      id: 'fb5',
      patientName: 'João Ricardo Silva',
      patientId: '#36718446',
      patientEmail: 'joao.ricardo@email.com',
      patientCpf: '234.567.890-11',
      protocol: '240505',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      systemRating: 5,
      unitRating: 4,
      teamRating: 5,
    ),
  ];

  static final List<PatientHealthScore> healthScores = [
    PatientHealthScore(
      id: 'hs1',
      patientName: 'Bruno Santos',
      patientCpf: '999.888.777-66',
      classification: HealthClassification.diamante,
      healthScore: 100,
      totalAppointments: 3,
      absences: 0,
      trend: null,
      doctorName: 'Dr. Antonio Leandro Marcelo Alves',
      phone: '999.888.777-66',
      events: const [
        PatientEvent(
          description: 'Comparecimento à consulta com Dr. Antonio Leandro Marcelo Alves',
          date: '30/05/2026',
          time: '19:09H',
          scoreImpact: 2,
        ),
        PatientEvent(
          description: 'Comparecimento à consulta com Dr. Antonio Leandro Marcelo Alves',
          date: '22/05/2026',
          time: '19:05H',
          scoreImpact: 2,
        ),
        PatientEvent(
          description: 'Comparecimento à consulta com Dr. Antonio Leandro Marcelo Alves',
          date: '22/05/2026',
          time: '18:44H',
          scoreImpact: 2,
        ),
        PatientEvent(
          description: 'Comparecimento à consulta com Dr. Antonio Leandro Marcelo Alves',
          date: '22/05/2026',
          time: '18:42H',
          scoreImpact: 2,
        ),
      ],
      scoreHistory: const [
        ScorePoint('Início', 100),
        ScorePoint('03/03', 100),
        ScorePoint('03/03', 100),
        ScorePoint('02/04', 100),
        ScorePoint('02/04', 100),
        ScorePoint('02/04', 100),
        ScorePoint('02/05', 100),
        ScorePoint('02/05', 100),
        ScorePoint('02/05', 100),
        ScorePoint('02/05', 100),
        ScorePoint('17/05', 100),
        ScorePoint('21/05', 100),
        ScorePoint('22/05', 100),
        ScorePoint('30/05', 100),
      ],
    ),
    PatientHealthScore(
      id: 'hs2',
      patientName: 'Marina Souza',
      patientCpf: '995.848.757-42',
      classification: HealthClassification.diamante,
      healthScore: 100,
      totalAppointments: 33,
      absences: 0,
      trend: null,
      doctorName: 'Dr. Antonio Leandro Marcelo Alves',
      events: const [
        PatientEvent(
          description: 'Comparecimento à consulta com Dr. Antonio Leandro Marcelo Alves',
          date: '28/05/2026',
          time: '10:30H',
          scoreImpact: 2,
        ),
      ],
      scoreHistory: const [
        ScorePoint('Início', 100),
        ScorePoint('01/03', 100),
        ScorePoint('15/03', 100),
        ScorePoint('01/04', 100),
        ScorePoint('15/04', 100),
        ScorePoint('01/05', 100),
        ScorePoint('28/05', 100),
      ],
    ),
    PatientHealthScore(
      id: 'hs3',
      patientName: 'Rafael Oliveira',
      patientCpf: '994.958.973-96',
      classification: HealthClassification.diamante,
      healthScore: 100,
      totalAppointments: 3,
      absences: 0,
      trend: null,
      doctorName: 'Dr. Antonio Leandro Marcelo Alves',
      events: const [
        PatientEvent(
          description: 'Comparecimento à consulta com Dr. Antonio Leandro Marcelo Alves',
          date: '20/05/2026',
          time: '09:15H',
          scoreImpact: 2,
        ),
      ],
      scoreHistory: const [
        ScorePoint('Início', 100),
        ScorePoint('01/04', 100),
        ScorePoint('01/05', 100),
        ScorePoint('20/05', 100),
      ],
    ),
    PatientHealthScore(
      id: 'hs4',
      patientName: 'Marina Silva',
      patientCpf: '986.408.138-11',
      classification: HealthClassification.diamante,
      healthScore: 100,
      totalAppointments: 34,
      absences: 0,
      trend: null,
      doctorName: 'Dr. Antonio Leandro Marcelo Alves',
      events: const [
        PatientEvent(
          description: 'Comparecimento à consulta com Dr. Antonio Leandro Marcelo Alves',
          date: '25/05/2026',
          time: '14:00H',
          scoreImpact: 2,
        ),
      ],
      scoreHistory: const [
        ScorePoint('Início', 100),
        ScorePoint('01/02', 100),
        ScorePoint('01/03', 100),
        ScorePoint('01/04', 100),
        ScorePoint('01/05', 100),
        ScorePoint('25/05', 100),
      ],
    ),
  ];
}
