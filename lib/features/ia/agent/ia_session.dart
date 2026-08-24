import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de sessão compartilhado da página /ia (coordena topo, sidebars e área
/// principal). Mantém pequeno e sem dependências para evitar acoplamento.

/// Modo da área principal: chat conversacional ou orquestrador multi-agente.
enum IaView { chat, agentes }

/// Modo atual (toggle no topo + atalhos da sidebar esquerda).
final iaViewProvider = StateProvider<IaView>((_) => IaView.chat);

/// Texto de busca da sidebar esquerda (filtra conversas e planos salvos).
final iaSearchProvider = StateProvider<String>((_) => '');

/// Controle de visibilidade da sidebar esquerda (conversas) em telas grandes.
final iaLeftSidebarExpandedProvider = StateProvider<bool>((_) => true);

/// Timeout por agente (segundos) do modo Agentes — controlado pelo slider da
/// sidebar direita e aplicado pelo orquestrador.
final agentTimeoutProvider = StateProvider<int>((_) => 90);

/// Tarefas executadas em paralelo por lote no modo Agentes. Baixo por padrão
/// para não saturar a cota de requisições/minuto da IA (Azure → 429 sob rajada).
final agentBatchSizeProvider = StateProvider<int>((_) => 2);

/// Tentativas extras em respostas 429/503 da IA antes de desistir (backoff).
final agentMaxRetriesProvider = StateProvider<int>((_) => 3);

/// Anexos pendentes do chat (nome → texto extraído). Compartilhado entre o
/// input do chat e o painel "ANEXOS" da sidebar direita.
final pendingAttachmentsProvider =
    StateNotifierProvider<PendingAttachmentsNotifier, Map<String, String>>(
        (ref) => PendingAttachmentsNotifier());

class PendingAttachmentsNotifier extends StateNotifier<Map<String, String>> {
  PendingAttachmentsNotifier() : super(const {});

  void add(String name, String text) => state = {...state, name: text};

  void remove(String name) {
    final next = {...state}..remove(name);
    state = next;
  }

  void clear() => state = const {};
}
