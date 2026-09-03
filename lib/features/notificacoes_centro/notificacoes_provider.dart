import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import 'notificacoes_repository.dart';

/// Tipos de notificação (NOT-01).
enum NotificationType {
  agendamento('Agendamento', Icons.event_available, AppColors.primary, AppColors.primaryLight),
  cancelamento('Cancelamento', Icons.event_busy, AppColors.danger, AppColors.dangerLight),
  risco('Risco de falta', Icons.warning_amber_rounded, AppColors.warning, AppColors.warningLight),
  relatorio('Relatório', Icons.auto_awesome, AppColors.secondary, AppColors.secondaryLight),
  ticket('Ticket', Icons.confirmation_number_outlined, AppColors.primary, AppColors.infoLight),
  overbooking('Overbooking', Icons.swap_horiz, AppColors.warning, AppColors.warningLight);

  const NotificationType(this.label, this.icon, this.color, this.background);
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

/// Item do feed de notificações.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    this.read = false,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime time;
  final bool read;

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        message: message,
        time: time,
        read: read ?? this.read,
      );
}

/// Estado do feed (NOT-03: marcar como lida / todas).
class NotificacoesNotifier extends StateNotifier<List<NotificationItem>> {
  NotificacoesNotifier(this._repo, this._clinicaId) : super(const []) {
    if (_clinicaId.isNotEmpty) carregar();
  }

  final NotificacoesRepository _repo;
  final String _clinicaId;

  /// Feed de demonstração — semeia apenas o repositório em memória.
  static List<NotificationItem> get demonstracao => _seed();

  Future<void> carregar() async {
    try {
      state = await _repo.carregar(_clinicaId);
    } catch (_) {
      state = const [];
    }
  }

  static List<NotificationItem> _seed() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'n1',
        type: NotificationType.cancelamento,
        title: 'Consulta cancelada',
        message: 'Beatriz Rocha cancelou a consulta de Pediatria.',
        time: now.subtract(const Duration(minutes: 6)),
      ),
      NotificationItem(
        id: 'n2',
        type: NotificationType.risco,
        title: 'Paciente de alto risco',
        message: 'Maria Santos tem 82% de risco de falta amanhã às 09:00.',
        time: now.subtract(const Duration(minutes: 40)),
      ),
      NotificationItem(
        id: 'n3',
        type: NotificationType.agendamento,
        title: 'Novo agendamento',
        message: 'João Souza agendou Cardiologia para hoje às 10:00.',
        time: now.subtract(const Duration(hours: 2)),
      ),
      NotificationItem(
        id: 'n4',
        type: NotificationType.relatorio,
        title: 'Relatório de IA gerado',
        message: 'O relatório semanal de absenteísmo está disponível.',
        time: now.subtract(const Duration(hours: 5)),
        read: true,
      ),
      NotificationItem(
        id: 'n5',
        type: NotificationType.ticket,
        title: 'Ticket atribuído',
        message: 'Ticket #1043 (remarcação) foi atribuído a você.',
        time: now.subtract(const Duration(days: 1)),
        read: true,
      ),
    ];
  }

  /// Insere/atualiza uma notificação no topo do feed (dedupe por id). Ponto de
  /// entrada para eventos reais de outras áreas (ex.: realocação de overbooking).
  /// A tela só mantém a mudança se o banco aceitar (ver agentes/filas).
  Future<void> _otimista(
      List<NotificationItem> novoEstado, Future<void> Function() gravar) async {
    final anterior = state;
    state = novoEstado;
    try {
      await gravar();
    } catch (_) {
      state = anterior;
      rethrow;
    }
  }

  Future<void> add(NotificationItem item) {
    final existe = state.any((n) => n.id == item.id);
    return _otimista(
      existe
          ? [for (final n in state) n.id == item.id ? item : n]
          : [item, ...state],
      () => _repo.salvar(_clinicaId, item),
    );
  }

  /// Emite uma notificação nova com id/hora automáticos (NOT-01).
  Future<void> push({
    required NotificationType type,
    required String title,
    required String message,
  }) {
    return add(NotificationItem(
      id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      time: DateTime.now(),
    ));
  }

  Future<void> markRead(String id, {bool read = true}) {
    final atual = state.where((n) => n.id == id).firstOrNull;
    if (atual == null) return Future.value();
    final novo = atual.copyWith(read: read);
    return _otimista(
      [for (final n in state) n.id == id ? novo : n],
      () => _repo.salvar(_clinicaId, novo),
    );
  }

  Future<void> markAllRead() {
    final naoLidas = [for (final n in state) if (!n.read) n.id];
    if (naoLidas.isEmpty) return Future.value();
    return _otimista(
      [for (final n in state) n.copyWith(read: true)],
      () => _repo.marcarLidas(_clinicaId, naoLidas),
    );
  }

  Future<void> remove(String id) {
    return _otimista(
      [for (final n in state) if (n.id != id) n],
      () => _repo.excluir(id),
    );
  }
}

/// Repositório do feed: Firestore com Firebase, memória em modo demonstração
/// (semeado para a tela não abrir vazia).
final notificacoesRepositoryProvider = Provider<NotificacoesRepository>((ref) {
  if (ref.watch(firebaseEnabledProvider)) {
    return FirestoreNotificacoesRepository();
  }
  return MemoriaNotificacoesRepository(NotificacoesNotifier.demonstracao);
});

final notificacoesProvider =
    StateNotifierProvider<NotificacoesNotifier, List<NotificationItem>>((ref) {
  return NotificacoesNotifier(
    ref.watch(notificacoesRepositoryProvider),
    ref.watch(clinicaResolvidaProvider),
  );
});

/// Contagem de não lidas (NOT-04) — alimenta o badge na navegação/cabeçalho.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificacoesProvider).where((n) => !n.read).length;
});

/// Filtro selecionado: 'all', 'unread' ou o `name` de um [NotificationType].
final notifFilterProvider = StateProvider<String>((ref) => 'all');
