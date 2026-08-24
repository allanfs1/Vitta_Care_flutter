import 'package:cloud_firestore/cloud_firestore.dart';

import 'notificacoes_provider.dart';

/// Persistência do feed de notificações (`tb_notificacoes`).
///
/// O feed era um seed fixo em memória: marcar como lida, remover ou receber um
/// evento real (uma realocação de overbooking, por exemplo) se perdia ao
/// fechar o app — e o badge de não lidas voltava do zero a cada abertura.
abstract class NotificacoesRepository {
  Future<List<NotificationItem>> carregar(String clinicaId);
  Future<void> salvar(String clinicaId, NotificationItem item);
  Future<void> excluir(String id);

  /// Marca várias como lidas de uma vez (NOT-03, "marcar todas").
  Future<void> marcarLidas(String clinicaId, Iterable<String> ids);
}

class FirestoreNotificacoesRepository implements NotificacoesRepository {
  FirestoreNotificacoesRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String colecao = 'tb_notificacoes';

  /// Teto do feed — notificação é fluxo, não arquivo.
  static const int limite = 200;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(colecao);

  @override
  Future<List<NotificationItem>> carregar(String clinicaId) async {
    if (clinicaId.isEmpty) return const [];
    // Sem `orderBy` na query: ordenar aqui exigiria índice composto
    // (clinicaId + time) e o feed é pequeno o bastante para ordenar no cliente.
    final snap =
        await _col.where('clinicaId', isEqualTo: clinicaId).limit(limite).get();
    final out = snap.docs
        .map((d) => _deMapa(d.id, d.data()))
        .whereType<NotificationItem>()
        .toList();
    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }

  @override
  Future<void> salvar(String clinicaId, NotificationItem item) {
    return _col.doc(item.id).set({
      'clinicaId': clinicaId,
      'tipo': item.type.name,
      'titulo': item.title,
      'mensagem': item.message,
      'time': Timestamp.fromDate(item.time),
      'lida': item.read,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> excluir(String id) => _col.doc(id).delete();

  @override
  Future<void> marcarLidas(String clinicaId, Iterable<String> ids) async {
    final lista = ids.toList();
    if (lista.isEmpty) return;
    const tamanhoLote = 450; // Firestore aceita até 500 ops por batch.
    for (var i = 0; i < lista.length; i += tamanhoLote) {
      final fim = (i + tamanhoLote).clamp(0, lista.length);
      final batch = _db.batch();
      for (final id in lista.sublist(i, fim)) {
        batch.set(_col.doc(id), {'lida': true}, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  static NotificationItem? _deMapa(String id, Map<String, dynamic> d) {
    final tipo = NotificationType.values
        .where((t) => t.name == d['tipo'])
        .firstOrNull;
    if (tipo == null) return null;
    final time = d['time'];
    return NotificationItem(
      id: id,
      type: tipo,
      title: (d['titulo'] ?? '').toString(),
      message: (d['mensagem'] ?? '').toString(),
      time: time is Timestamp ? time.toDate() : DateTime.now(),
      read: d['lida'] == true,
    );
  }
}

/// Implementação em memória — modo demonstração e testes.
class MemoriaNotificacoesRepository implements NotificacoesRepository {
  MemoriaNotificacoesRepository([List<NotificationItem> inicial = const []]) {
    for (final n in inicial) {
      _itens[n.id] = n;
    }
  }

  final Map<String, NotificationItem> _itens = {};

  @override
  Future<List<NotificationItem>> carregar(String clinicaId) async {
    final out = _itens.values.toList();
    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }

  @override
  Future<void> salvar(String clinicaId, NotificationItem item) async =>
      _itens[item.id] = item;

  @override
  Future<void> excluir(String id) async => _itens.remove(id);

  @override
  Future<void> marcarLidas(String clinicaId, Iterable<String> ids) async {
    for (final id in ids) {
      final n = _itens[id];
      if (n != null) _itens[id] = n.copyWith(read: true);
    }
  }
}
