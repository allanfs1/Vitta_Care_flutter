/// Evento da jornada do paciente (§1.3 — `tickets.timeline`).
///
/// Cada passo no sistema gera um registro `{action, timestamp, details,
/// agentId}` que permite reconstruir o caminho do ticket.
class TimelineEvent {
  const TimelineEvent({
    required this.action,
    required this.timestamp,
    this.details = '',
    this.agentId,
  });

  final String action;
  final DateTime timestamp;
  final String details;
  final String? agentId;
}
