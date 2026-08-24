import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../models/agent_model.dart';
import '../services/admin_agentes_repository.dart';
import 'queue_provider.dart';

/// Repositório de agentes/filas: Firestore quando há Firebase, memória quando
/// não há — semeada com o elenco de demonstração para a tela não abrir vazia.
final adminAgentesRepositoryProvider = Provider<AdminAgentesRepository>((ref) {
  if (ref.watch(firebaseEnabledProvider)) {
    return FirestoreAdminAgentesRepository();
  }
  return MemoriaAdminAgentesRepository(
    agentes: AgentsNotifier.demonstracao,
    filas: QueuesNotifier.demonstracao,
  );
});

final agentsProvider = StateNotifierProvider<AgentsNotifier, List<AgentModel>>((ref) {
  return AgentsNotifier(
    ref.watch(adminAgentesRepositoryProvider),
    ref.watch(clinicaResolvidaProvider),
  );
});

class AgentsNotifier extends StateNotifier<List<AgentModel>> {
  AgentsNotifier(this._repo, this._clinicaId) : super(const []) {
    if (_clinicaId.isNotEmpty) carregar();
  }

  final AdminAgentesRepository _repo;
  final String _clinicaId;

  /// Elenco de demonstração — só semeia o repositório em memória, nunca é
  /// gravado no Firestore por conta própria (o Cérebro já ensinou o preço de
  /// auto-popular banco de produção).
  static List<AgentModel> get demonstracao => _initialData;

  Future<void> carregar() async {
    try {
      state = await _repo.carregarAgentes(_clinicaId);
    } catch (_) {
      // Sem cadastro acessível a tela mostra vazio em vez de dados fantasma.
      state = const [];
    }
  }

  static final List<AgentModel> _initialData = [
    const AgentModel(
      id: '1',
      nomeOperacional: 'Vitório Amigos',
      email: 'vitorio@marktech.com',
      pin: '4321',
      disponibilidade: AgentAvailability.online,
      setores: ['FINANCEIRO'],
      cargaAtivos: 0,
      cargaMaxima: 5,
    ),
    const AgentModel(
      id: '2',
      nomeOperacional: 'Alex Mendez',
      email: 'alex@gmail.com',
      pin: '591890',
      disponibilidade: AgentAvailability.offline,
      setores: ['TRIAGEM GERAL', 'SUPORTE GERAL'],
      cargaAtivos: 0,
      cargaMaxima: 5,
    ),
    const AgentModel(
      id: '3',
      nomeOperacional: 'Gean Oliveira',
      email: 'gean@marktech.com',
      pin: '1234',
      disponibilidade: AgentAvailability.online,
      setores: ['IMIGRAÇÃO', 'SUPORTE GERAL'],
      cargaAtivos: 0,
      cargaMaxima: 5,
    ),
    const AgentModel(
      id: '4',
      nomeOperacional: 'Maria Silva',
      email: 'maria@clinica.com',
      pin: '5555',
      disponibilidade: AgentAvailability.offline,
      setores: ['SUPORTE GERAL'],
      cargaAtivos: 0,
      cargaMaxima: 5,
    ),
  ];

  /// Aplica a mudança na tela e só a mantém se o banco aceitar.
  ///
  /// Sem o rollback, uma gravação recusada (regra de segurança, rede) deixava
  /// a tela mostrando um agente que não existe no banco — e ele sumia no
  /// próximo boot, sem ninguém entender por quê.
  Future<void> _otimista(
      List<AgentModel> novoEstado, Future<void> Function() gravar) async {
    final anterior = state;
    state = novoEstado;
    try {
      await gravar();
    } catch (_) {
      state = anterior;
      rethrow;
    }
  }

  Future<void> addAgent(AgentModel agent) {
    return _otimista(
      [...state, agent],
      () => _repo.salvarAgente(_clinicaId, agent),
    );
  }

  Future<void> updateAvailability(String id, AgentAvailability availability) {
    final atual = state.where((a) => a.id == id).firstOrNull;
    if (atual == null) return Future.value();
    final novo = atual.copyWith(disponibilidade: availability);
    return _otimista(
      [for (final a in state) a.id == id ? novo : a],
      () => _repo.salvarAgente(_clinicaId, novo),
    );
  }

  Future<void> removeAgent(String id) {
    return _otimista(
      state.where((a) => a.id != id).toList(),
      () => _repo.excluirAgente(id),
    );
  }

  /// Incrementa a carga de atendimentos do agente (§1.1 `metrics.activeChats`),
  /// respeitando o teto [AgentModel.cargaMaxima].
  ///
  /// **Não persiste**, de propósito: carga ativa é estado de sessão e muda a
  /// cada mensagem — gravar cada passo custaria uma escrita por evento de chat.
  /// O que precisa sobreviver ao restart é o cadastro e a disponibilidade.
  void incrementLoad(String id) {
    state = [
      for (final a in state)
        if (a.id == id && a.cargaAtivos < a.cargaMaxima)
          a.copyWith(cargaAtivos: a.cargaAtivos + 1)
        else
          a,
    ];
  }

  /// Decrementa a carga (nunca abaixo de zero) — usado na transferência (§3.2).
  void decrementLoad(String id) {
    state = [
      for (final a in state)
        if (a.id == id && a.cargaAtivos > 0)
          a.copyWith(cargaAtivos: a.cargaAtivos - 1)
        else
          a,
    ];
  }

  /// Agente mais livre apto a receber um ticket da fila [queueName] (§3.1):
  /// online, vinculado à fila e abaixo do teto, ordenado por menor carga.
  AgentModel? leastOccupiedFor(String queueName) {
    final candidates = state
        .where((a) =>
            a.disponibilidade == AgentAvailability.online &&
            a.setores.contains(queueName) &&
            a.cargaAtivos < a.cargaMaxima)
        .toList()
      ..sort((a, b) => a.cargaAtivos.compareTo(b.cargaAtivos));
    return candidates.isEmpty ? null : candidates.first;
  }
}
