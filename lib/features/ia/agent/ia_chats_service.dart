import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import 'agent_models.dart';

/// Persistência das conversas do chat de IA em `tb_ia_chats` (multi-tenant).
class IaChatsService {
  IaChatsService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tb_ia_chats');

  /// Cria/atualiza uma conversa. Retorna o id do documento.
  Future<String> saveChat({
    String? chatId,
    required String titulo,
    required List<ChatMessage> messages,
    required String clinicaId,
  }) async {
    final data = <String, dynamic>{
      'titulo': titulo,
      'mensagens': messages.map((m) => m.toStore()).toList(),
      'idclinica': clinicaId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (chatId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(data);
      return ref.id;
    }
    await _col.doc(chatId).set(data, SetOptions(merge: true));
    return chatId;
  }

  Future<void> deleteChat(String id) => _col.doc(id).delete();

  /// Lista as conversas da clínica (ordenadas por updatedAt desc em memória).
  Stream<List<Map<String, dynamic>>> watchChats(String clinicaId) {
    return _col.where('idclinica', isEqualTo: clinicaId).snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'titulo': (data['titulo'] ?? 'Conversa').toString(),
          'updatedAt': data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
              : null,
          'n': (data['mensagens'] is List)
              ? (data['mensagens'] as List).length
              : 0,
        };
      }).toList();
      list.sort((a, b) =>
          (b['updatedAt'] ?? '').toString().compareTo((a['updatedAt'] ?? '').toString()));
      return list;
    });
  }

  /// Carrega as mensagens de uma conversa.
  Future<List<ChatMessage>> loadMessages(String id) async {
    final snap = await _col.doc(id).get();
    final raw = snap.data()?['mensagens'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => ChatMessage.fromStore(Map<String, dynamic>.from(m)))
        .toList();
  }
}

final iaChatsServiceProvider = Provider<IaChatsService>(
    (ref) => IaChatsService(FirebaseFirestore.instance));

/// Conversas salvas da clínica ativa (para a sidebar esquerda).
final iaChatsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final clinicaId = ref.watch(selectedClinicIdProvider);
  if (clinicaId.isEmpty) return Stream.value(const []);
  return ref.watch(iaChatsServiceProvider).watchChats(clinicaId);
});
