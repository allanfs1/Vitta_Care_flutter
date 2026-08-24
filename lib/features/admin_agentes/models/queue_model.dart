/// Estratégia de distribuição de tickets dentro de uma fila (`distributionStrategy`).
enum DistributionStrategy {
  /// O ticket vai para o agente com o menor número absoluto de `activeChats`.
  leastOccupied,

  /// Distribuição cíclica entre os agentes da fila.
  roundRobin,
}

extension DistributionStrategyX on DistributionStrategy {
  String get label => switch (this) {
        DistributionStrategy.leastOccupied => 'Menos ocupado',
        DistributionStrategy.roundRobin => 'Rodízio (round-robin)',
      };

  String get id => switch (this) {
        DistributionStrategy.leastOccupied => 'least_occupied',
        DistributionStrategy.roundRobin => 'round_robin',
      };
}

/// Acordo de nível de serviço da fila (`sla`).
class QueueSla {
  const QueueSla({
    required this.firstResponse,
    required this.resolution,
  });

  /// Tempo-alvo para o primeiro "Oi" de um humano.
  final Duration firstResponse;

  /// Tempo-alvo para fechar o caso.
  final Duration resolution;

  QueueSla copyWith({Duration? firstResponse, Duration? resolution}) {
    return QueueSla(
      firstResponse: firstResponse ?? this.firstResponse,
      resolution: resolution ?? this.resolution,
    );
  }
}

/// Departamento / fila de atendimento (coleção `queues`).
class QueueModel {
  const QueueModel({
    required this.id,
    required this.name,
    this.distributionStrategy = DistributionStrategy.leastOccupied,
    this.sla = const QueueSla(
      firstResponse: Duration(minutes: 5),
      resolution: Duration(minutes: 30),
    ),
    this.agentIds = const [],
  });

  final String id;
  final String name;
  final DistributionStrategy distributionStrategy;
  final QueueSla sla;

  /// Agentes vinculados à fila (`assignedQueues` no lado do agente).
  final List<String> agentIds;

  factory QueueModel.fromFirestore(String id, Map<String, dynamic> d) {
    final sla = (d['sla'] as Map?)?.cast<String, dynamic>();
    int seg(String k, int padrao) => (sla?[k] as num?)?.toInt() ?? padrao;
    return QueueModel(
      id: id,
      name: (d['name'] ?? d['nome'] ?? '').toString(),
      distributionStrategy: DistributionStrategy.values.firstWhere(
        (v) => v.id == d['distributionStrategy'],
        orElse: () => DistributionStrategy.leastOccupied,
      ),
      sla: QueueSla(
        firstResponse: Duration(seconds: seg('firstResponseSeconds', 300)),
        resolution: Duration(seconds: seg('resolutionSeconds', 1800)),
      ),
      agentIds: (d['agentIds'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore(String clinicaId) => {
        'clinicaId': clinicaId,
        'name': name,
        'distributionStrategy': distributionStrategy.id,
        'sla': {
          'firstResponseSeconds': sla.firstResponse.inSeconds,
          'resolutionSeconds': sla.resolution.inSeconds,
        },
        'agentIds': agentIds,
      };

  QueueModel copyWith({
    String? id,
    String? name,
    DistributionStrategy? distributionStrategy,
    QueueSla? sla,
    List<String>? agentIds,
  }) {
    return QueueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      distributionStrategy: distributionStrategy ?? this.distributionStrategy,
      sla: sla ?? this.sla,
      agentIds: agentIds ?? this.agentIds,
    );
  }
}
