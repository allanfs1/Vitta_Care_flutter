import 'package:flutter/material.dart';

import '../../core/models/appointment.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_colors.dart';

/// Estado operacional de um paciente no painel de overbooking (AGENTS.md
/// OVB-04). Deriva do `status` do agendamento + sobreposição da realocação.
enum PacienteEstado {
  agendado('Agendado', AppColors.warning),
  confirmado('Confirmado', AppColors.success),
  aguardando('Aguardando', AppColors.primary),
  emAtendimento('Em atendimento', AppColors.privada),
  realizado('Realizado', AppColors.textTertiary),
  faltou('Faltou', AppColors.textPrimary),
  realocavel('Realocável', Color(0xFFE8590C)),
  sugerida('Sugerida', AppColors.primary),
  aguardandoConfirmacao('Aguard. confirmação', AppColors.primary),
  realocado('Realocado', AppColors.success),
  recusada('Recusada', AppColors.danger);

  const PacienteEstado(this.label, this.color);
  final String label;
  final Color color;
}

/// Ciclo de vida de uma proposta de realocação (OVB-05.5).
enum RealocacaoStatus {
  sugerida('Sugerida'),
  aguardandoConfirmacao('Aguardando confirmação'),
  concluida('Concluída'),
  recusada('Recusada'),
  expirada('Expirada');

  const RealocacaoStatus(this.label);
  final String label;
}

/// Status do e-mail de overbooking (OVB-05.7).
enum RealoEmailStatus {
  naoEnviado('Não enviado', AppColors.textTertiary),
  enviado('Enviado', AppColors.primary),
  entregue('Entregue', AppColors.info),
  confirmado('Confirmado', AppColors.success),
  recusado('Recusado', AppColors.danger);

  const RealoEmailStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// Canal de notificação da realocação.
enum RealoCanal {
  email('E-mail', Icons.email_outlined),
  whatsapp('WhatsApp', Icons.chat_outlined),
  push('Push', Icons.notifications_outlined);

  const RealoCanal(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Candidato a realocação de um slot sobrecarregado: o agendamento a mover, o
/// **novo horário destino** escolhido pelo motor e a justificativa (OVB-05.2/5.3).
class CandidatoRealoc {
  const CandidatoRealoc({
    required this.appointment,
    required this.destino,
    required this.motivo,
  });

  final Appointment appointment;

  /// Novo dia/horário sugerido. `null` quando não há vaga próxima.
  final DateTime? destino;
  final String motivo;
}

/// Slot (médico × hora) em sobrecarga, com os candidatos a realocar (OVB-05.1).
class SlotSobrecarga {
  const SlotSobrecarga({
    required this.doctorId,
    required this.doctorName,
    required this.doctorCrm,
    required this.specialty,
    required this.hour,
    required this.booked,
    required this.capacity,
    required this.slotBase,
    required this.candidatos,
  });

  final String doctorId;
  final String doctorName;
  final String doctorCrm;
  final String specialty;
  final int hour;
  final int booked;
  final int capacity;
  final int slotBase;
  final List<CandidatoRealoc> candidatos;

  /// Acima do teto real de capacidade (realocação obrigatória).
  int get estouro => (booked - capacity).clamp(0, booked);

  /// Acima do limite base (uso de overbooking).
  int get excedente => (booked - slotBase).clamp(0, booked);
}

/// Proposta de realocação aceita/enfileirada, com o estado do e-mail (OVB-05).
class RealocacaoProposta {
  const RealocacaoProposta({
    required this.appointmentId,
    required this.patientName,
    required this.patientRisk,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.crm,
    required this.slotOrigem,
    required this.slotDestino,
    required this.motivoDestino,
    required this.canal,
    required this.status,
    required this.emailStatus,
    required this.criadaEm,
    this.emailEnviadoEm,
  });

  final String appointmentId;
  final String patientName;
  final RiskLevel patientRisk;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final String crm;
  final DateTime slotOrigem;
  final DateTime slotDestino;
  final String motivoDestino;
  final RealoCanal canal;
  final RealocacaoStatus status;
  final RealoEmailStatus emailStatus;
  final DateTime criadaEm;
  final DateTime? emailEnviadoEm;

  RealocacaoProposta copyWith({
    DateTime? slotDestino,
    String? motivoDestino,
    RealoCanal? canal,
    RealocacaoStatus? status,
    RealoEmailStatus? emailStatus,
    DateTime? emailEnviadoEm,
  }) {
    return RealocacaoProposta(
      appointmentId: appointmentId,
      patientName: patientName,
      patientRisk: patientRisk,
      doctorId: doctorId,
      doctorName: doctorName,
      specialty: specialty,
      crm: crm,
      slotOrigem: slotOrigem,
      slotDestino: slotDestino ?? this.slotDestino,
      motivoDestino: motivoDestino ?? this.motivoDestino,
      canal: canal ?? this.canal,
      status: status ?? this.status,
      emailStatus: emailStatus ?? this.emailStatus,
      criadaEm: criadaEm,
      emailEnviadoEm: emailEnviadoEm ?? this.emailEnviadoEm,
    );
  }
}

/// Entrada da timeline de decisões / auditoria (OVB-06).
class DecisaoOverbooking {
  const DecisaoOverbooking({
    required this.at,
    required this.ator,
    required this.texto,
    required this.icon,
    required this.cor,
  });

  final DateTime at;
  final String ator;
  final String texto;
  final IconData icon;
  final Color cor;
}
