import 'enums.dart';

/// Agendamento / consulta. Mapeia `tb_agendamentos`.
class Appointment {
  const Appointment({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.start,
    required this.durationMinutes,
    required this.status,
    this.tipoConsulta = 'Consulta',
    this.modalidade = 'Presencial',
    this.local = '',
    this.motivo = '',
    this.observacoes = '',
    this.crm = '',
    this.patientPhone = '',
    this.patientRisk = RiskLevel.low,
    this.preparo = const [],
    this.firstVisit = false,
    this.lateMinutes,
  });

  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final DateTime start;
  final int durationMinutes;
  final AppointmentStatus status;
  final String tipoConsulta;
  final String modalidade;
  final String local;
  final String motivo;
  final String observacoes;
  final String crm;
  final String patientPhone;
  final RiskLevel patientRisk;
  final List<String> preparo;
  final bool firstVisit;
  final int? lateMinutes;

  DateTime get end => start.add(Duration(minutes: durationMinutes));

  Appointment copyWith({
    AppointmentStatus? status,
    DateTime? start,
    String? doctorId,
    String? doctorName,
    String? specialty,
    String? crm,
  }) {
    return Appointment(
      id: id,
      clinicId: clinicId,
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      start: start ?? this.start,
      durationMinutes: durationMinutes,
      status: status ?? this.status,
      tipoConsulta: tipoConsulta,
      modalidade: modalidade,
      local: local,
      motivo: motivo,
      observacoes: observacoes,
      crm: crm ?? this.crm,
      patientPhone: patientPhone,
      patientRisk: patientRisk,
      preparo: preparo,
      firstVisit: firstVisit,
      lateMinutes: lateMinutes,
    );
  }
}

/// KPI exibido em cards (H-05). Genérico para reuso entre módulos.
class Kpi {
  const Kpi({
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive = true,
    this.suffix = '',
  });

  final String label;
  final String value;
  final double? delta;
  final bool deltaPositive;
  final String suffix;
}

/// Ponto de série temporal para gráficos.
class TimeSeriesPoint {
  const TimeSeriesPoint(this.label, this.value);
  final String label;
  final double value;
}
