import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../models/queue_model.dart';
import '../services/admin_agentes_repository.dart';
import 'agent_provider.dart';

final queuesProvider =
    StateNotifierProvider<QueuesNotifier, List<QueueModel>>((ref) {
  return QueuesNotifier(
    ref.watch(adminAgentesRepositoryProvider),
    ref.watch(clinicaResolvidaProvider),
  );
});

class QueuesNotifier extends StateNotifier<List<QueueModel>> {
  QueuesNotifier(this._repo, this._clinicaId) : super(const []) {
    if (_clinicaId.isNotEmpty) carregar();
  }

  final AdminAgentesRepository _repo;
  final String _clinicaId;

  /// Filas de demonstração — semeiam apenas o repositório em memória.
  static List<QueueModel> get demonstracao => _initialData;

  Future<void> carregar() async {
    try {
      state = await _repo.carregarFilas(_clinicaId);
    } catch (_) {
      state = const [];
    }
  }

  static final List<QueueModel> _initialData = [
    const QueueModel(
      id: 'q-financeiro',
      name: 'FINANCEIRO',
      distributionStrategy: DistributionStrategy.leastOccupied,
      sla: QueueSla(
        firstResponse: Duration(minutes: 3),
        resolution: Duration(minutes: 20),
      ),
      agentIds: ['1'],
    ),
    const QueueModel(
      id: 'q-triagem',
      name: 'TRIAGEM GERAL',
      distributionStrategy: DistributionStrategy.roundRobin,
      sla: QueueSla(
        firstResponse: Duration(minutes: 2),
        resolution: Duration(minutes: 15),
      ),
      agentIds: ['2'],
    ),
    const QueueModel(
      id: 'q-suporte',
      name: 'SUPORTE GERAL',
      distributionStrategy: DistributionStrategy.leastOccupied,
      sla: QueueSla(
        firstResponse: Duration(minutes: 5),
        resolution: Duration(minutes: 30),
      ),
      agentIds: ['2', '3', '4'],
    ),
    const QueueModel(
      id: 'q-imigracao',
      name: 'IMIGRAÇÃO',
      distributionStrategy: DistributionStrategy.leastOccupied,
      sla: QueueSla(
        firstResponse: Duration(minutes: 10),
        resolution: Duration(minutes: 60),
      ),
      agentIds: ['3'],
    ),
  ];

  /// Mesma regra dos agentes: a tela só mantém a mudança se o banco aceitar.
  Future<void> _otimista(
      List<QueueModel> novoEstado, Future<void> Function() gravar) async {
    final anterior = state;
    state = novoEstado;
    try {
      await gravar();
    } catch (_) {
      state = anterior;
      rethrow;
    }
  }

  Future<void> addQueue(QueueModel queue) {
    return _otimista(
      [...state, queue],
      () => _repo.salvarFila(_clinicaId, queue),
    );
  }

  Future<void> updateQueue(QueueModel queue) {
    return _otimista(
      [for (final q in state) q.id == queue.id ? queue : q],
      () => _repo.salvarFila(_clinicaId, queue),
    );
  }

  Future<void> removeQueue(String id) {
    return _otimista(
      state.where((q) => q.id != id).toList(),
      () => _repo.excluirFila(id),
    );
  }
}
