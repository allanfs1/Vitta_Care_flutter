import 'package:flutter/material.dart';

/// Estado vivo de disponibilidade do atendente (coleção `agents.status`).
/// Reflete a presença imediata controlada em tempo real.
enum AgentAvailability {
  online,
  busy,
  away,
  offline,
}

/// Rótulos e cores de cada estado, reutilizados na tabela e nos modais.
extension AgentAvailabilityX on AgentAvailability {
  String get label => switch (this) {
        AgentAvailability.online => 'ONLINE',
        AgentAvailability.busy => 'OCUPADO',
        AgentAvailability.away => 'AUSENTE',
        AgentAvailability.offline => 'OFFLINE',
      };

  Color get color => switch (this) {
        AgentAvailability.online => const Color(0xFF1FAA59),
        AgentAvailability.busy => const Color(0xFFFF3B30),
        AgentAvailability.away => const Color(0xFFF5A623),
        AgentAvailability.offline => const Color(0xFF9AA1AD),
      };
}

class AgentModel {
  const AgentModel({
    required this.id,
    required this.nomeOperacional,
    required this.email,
    required this.pin,
    this.disponibilidade = AgentAvailability.offline,
    this.setores = const [],
    this.cargaAtivos = 0,
    this.cargaMaxima = 5,
  });

  final String id;
  final String nomeOperacional;
  final String email;

  /// `accessPin`: chave de 6 dígitos (também senha inicial do Auth).
  final String pin;
  final AgentAvailability disponibilidade;

  /// `assignedQueues`: nomes das filas/departamentos a que o agente pertence.
  final List<String> setores;

  /// `metrics.activeChats`: carga de trabalho atual (nunca excede [cargaMaxima]).
  final int cargaAtivos;

  /// `maxConcurrentChats`: teto de atendimentos simultâneos.
  final int cargaMaxima;

  /// `true` quando o agente ainda pode receber novos tickets.
  bool get podeReceber =>
      disponibilidade == AgentAvailability.online && cargaAtivos < cargaMaxima;

  /// Lê um doc de `tb_agentes`. Tolerante a campos ausentes: a coleção é nova
  /// e docs antigos podem não ter tudo.
  factory AgentModel.fromFirestore(String id, Map<String, dynamic> d) {
    return AgentModel(
      id: id,
      nomeOperacional: (d['nomeOperacional'] ?? d['displayName'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      pin: (d['accessPin'] ?? d['pin'] ?? '').toString(),
      disponibilidade: AgentAvailability.values.firstWhere(
        (v) => v.name == d['disponibilidade'],
        orElse: () => AgentAvailability.offline,
      ),
      setores: ((d['assignedQueues'] ?? d['setores']) as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      cargaAtivos: (d['activeChats'] as num?)?.toInt() ?? 0,
      cargaMaxima: (d['maxConcurrentChats'] as num?)?.toInt() ?? 5,
    );
  }

  /// Nomes de campo espelham o contrato de §1.1 (`accessPin`,
  /// `assignedQueues`, `maxConcurrentChats`).
  Map<String, dynamic> toFirestore(String clinicaId) => {
        'clinicaId': clinicaId,
        'nomeOperacional': nomeOperacional,
        'email': email,
        'accessPin': pin,
        'disponibilidade': disponibilidade.name,
        'assignedQueues': setores,
        'activeChats': cargaAtivos,
        'maxConcurrentChats': cargaMaxima,
      };

  AgentModel copyWith({
    String? id,
    String? nomeOperacional,
    String? email,
    String? pin,
    AgentAvailability? disponibilidade,
    List<String>? setores,
    int? cargaAtivos,
    int? cargaMaxima,
  }) {
    return AgentModel(
      id: id ?? this.id,
      nomeOperacional: nomeOperacional ?? this.nomeOperacional,
      email: email ?? this.email,
      pin: pin ?? this.pin,
      disponibilidade: disponibilidade ?? this.disponibilidade,
      setores: setores ?? this.setores,
      cargaAtivos: cargaAtivos ?? this.cargaAtivos,
      cargaMaxima: cargaMaxima ?? this.cargaMaxima,
    );
  }
}
