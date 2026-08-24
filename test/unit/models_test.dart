import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/app_user.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/clinic.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/core/models/patient.dart';
import 'package:vitta_app/core/models/plan.dart';

/// Testes unitários dos modelos de domínio.
void main() {
  test('Doctor.initials e primarySpecialty', () {
    const d = Doctor(
        id: 'd', name: 'Dr. Roberto Santos', crm: '1', specialties: ['Cardiologia']);
    expect(d.initials, 'RS');
    expect(d.primarySpecialty, 'Cardiologia');
    const semEsp = Doctor(id: 'x', name: 'Ana', crm: '2', specialties: []);
    expect(semEsp.primarySpecialty, 'Clínico Geral');
  });

  test('Patient.riskLevel deriva do score', () {
    const p = Patient(id: 'p', name: 'Maria Santos', riskScore: 0.82);
    expect(p.riskLevel, RiskLevel.high);
    expect(p.initials, 'MS');
  });

  test('AppUser.fullName e initials', () {
    const u = AppUser(id: 'u', firstName: 'Carlos', lastName: 'Silva');
    expect(u.fullName, 'Carlos Silva');
    expect(u.initials, 'CS');
  });

  test('Appointment.end soma a duração e copyWith preserva campos', () {
    final a = Appointment(
      id: 'a',
      clinicId: 'c',
      patientId: 'p',
      patientName: 'Maria',
      doctorId: 'd',
      doctorName: 'Dr. X',
      specialty: 'Cardio',
      start: DateTime(2026, 6, 24, 9, 0),
      durationMinutes: 45,
      status: AppointmentStatus.pending,
    );
    expect(a.end, DateTime(2026, 6, 24, 9, 45));
    final confirmed = a.copyWith(status: AppointmentStatus.confirmed);
    expect(confirmed.status, AppointmentStatus.confirmed);
    expect(confirmed.patientName, 'Maria'); // preservado
  });

  test('ClinicAddress.formatted concatena partes não vazias', () {
    const addr = ClinicAddress(
        street: 'Av. Paulista', number: '1000', city: 'São Paulo', state: 'SP');
    expect(addr.formatted.contains('Av. Paulista, 1000'), true);
    expect(addr.formatted.contains('São Paulo - SP'), true);
  });

  test('Plan.fromFirestore mapeia campos de tb_plans', () {
    final plan = Plan.fromFirestore('plan_x', {
      'nome': 'Profissional',
      'descricao': 'Para clínicas',
      'precoMensal': 249,
      'precoAnual': 2390,
      'isPopular': true,
      'limiteUsuarios': 15,
      'limite_consulta': 5000,
      'nivelSuporte': 'Prioritário',
      'intergracao': true,
      'recursosInclusos': 'Dashboard; Agenda; Relatórios',
      'beneficiosAdicionais': ['Integração WhatsApp'],
      'status': 'active',
    });

    expect(plan.id, 'plan_x');
    expect(plan.name, 'Profissional');
    expect(plan.monthlyPrice, 249);
    expect(plan.yearlyPrice, 2390);
    expect(plan.isPopular, true);
    expect(plan.userLimit, 15);
    expect(plan.hasIntegrations, true);
    // recursosInclusos (split) + beneficiosAdicionais
    expect(plan.features, contains('Dashboard'));
    expect(plan.features, contains('Integração WhatsApp'));
  });

  test('Plan.fromFirestore usa preços inter_* e calcula anual quando ausente', () {
    final plan = Plan.fromFirestore('p2', {
      'nome': 'Essencial',
      'inter_preco_mes': 99,
    });
    expect(plan.monthlyPrice, 99);
    expect(plan.yearlyPrice, 99 * 12); // anual ausente → 12x o mensal
  });

  test('Clinic.copyWith mantém id', () {
    const c = Clinic(id: 'c1', name: 'UBS', type: ClinicType.ubs);
    final updated = c.copyWith(name: 'UBS Centro');
    expect(updated.id, 'c1');
    expect(updated.name, 'UBS Centro');
  });
}
