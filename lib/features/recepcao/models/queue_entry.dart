import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'care_line.dart';
import 'manchester_priority.dart';
import 'timeline_event.dart';
import 'vital_signs.dart';

/// Situação de uma senha na fila da recepção (REC-01..REC-03).
enum QueueStatus {
  waiting('Aguardando', AppColors.warning, AppColors.warningLight),
  called('Chamado', AppColors.primary, AppColors.primaryLight),
  inService('Em atendimento', AppColors.secondary, AppColors.secondaryLight),
  done('Atendido/Finalizado', AppColors.success, AppColors.successLight);

  const QueueStatus(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;
}

/// Entrada da fila de espera: paciente que fez check-in no balcão.
@immutable
class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.senha,
    required this.patientName,
    required this.specialty,
    required this.doctorName,
    required this.checkInAt,
    this.status = QueueStatus.waiting,
    this.priority = false,
    this.protocol = '#00000000',
    this.origin = 'WEB',
    this.assignedTo,
    this.channelColor = AppColors.primary,
    this.manchester = ManchesterPriority.green,
    this.timeline = const [],
    this.vitals = const VitalSigns(),
    this.careLine = CareLine.geral,
    this.attendanceType = AttendanceType.espontanea,
    this.microarea = '',
    this.acs = '',
    this.referral,
    this.scheduledAt,
    this.photoUrl,
  });

  final String id;
  final String senha; // ex.: A012
  final String patientName;
  final String specialty;
  final String doctorName;
  final DateTime checkInAt;
  final QueueStatus status;
  final bool priority;

  // Novos campos para o monitoramento híbrido
  final String protocol;
  final String origin;
  final String? assignedTo;
  final Color channelColor;

  /// Classificação de risco Manchester (§1.3).
  final ManchesterPriority manchester;

  /// Jornada do paciente (§1.3) — passos de atribuição/transferência/chamada.
  final List<TimelineEvent> timeline;

  /// Sinais vitais aferidos no acolhimento.
  final VitalSigns vitals;

  /// Linha de cuidado / grupo programático (pré-natal, HiperDia, etc.).
  final CareLine careLine;

  /// Demanda espontânea vs. agendada.
  final AttendanceType attendanceType;

  /// Microárea da equipe eSF.
  final String microarea;

  /// Agente Comunitário de Saúde responsável.
  final String acs;

  /// Destino de encaminhamento (referência), quando houver (ex.: "UPA Central").
  final String? referral;

  /// Horário agendado (para demanda agendada) — dispara a chamada automática.
  final DateTime? scheduledAt;

  /// Foto do paciente (URL), exibida no monitor quando habilitada.
  final String? photoUrl;

  /// `true` quando é um agendamento cuja hora já chegou e ainda aguarda chamada.
  bool autoCallDue(DateTime now) =>
      status == QueueStatus.waiting &&
      scheduledAt != null &&
      !now.isBefore(scheduledAt!);

  /// Tempo-alvo de atendimento conforme a cor Manchester.
  Duration get slaTarget => switch (manchester) {
        ManchesterPriority.red => Duration.zero,
        ManchesterPriority.orange => const Duration(minutes: 10),
        ManchesterPriority.yellow => const Duration(minutes: 60),
        ManchesterPriority.green => const Duration(minutes: 120),
      };

  /// `true` quando o tempo de espera já excedeu o alvo da cor (estouro de SLA).
  bool slaBreached(DateTime now) =>
      status == QueueStatus.waiting && waitedFrom(now) > slaTarget;

  /// Tempo de espera desde o check-in.
  Duration waitedFrom(DateTime now) => now.difference(checkInAt);

  String waitLabel(DateTime now) {
    final m = waitedFrom(now).inMinutes;
    if (m < 1) return 'agora';
    if (m < 60) return '$m min';
    return '${m ~/ 60}h ${m % 60}min';
  }

  String get initials {
    final parts =
        patientName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  QueueEntry copyWith({
    QueueStatus? status,
    String? assignedTo,
    ManchesterPriority? manchester,
    List<TimelineEvent>? timeline,
    VitalSigns? vitals,
    String? referral,
    DateTime? scheduledAt,
    String? photoUrl,
  }) => QueueEntry(
        id: id,
        senha: senha,
        patientName: patientName,
        specialty: specialty,
        doctorName: doctorName,
        checkInAt: checkInAt,
        status: status ?? this.status,
        priority: priority,
        protocol: protocol,
        origin: origin,
        assignedTo: assignedTo ?? this.assignedTo,
        channelColor: channelColor,
        manchester: manchester ?? this.manchester,
        timeline: timeline ?? this.timeline,
        vitals: vitals ?? this.vitals,
        careLine: careLine,
        attendanceType: attendanceType,
        microarea: microarea,
        acs: acs,
        referral: referral ?? this.referral,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}
