import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_providers.dart';
import '../models/totem_config.dart';

/// Configuração do Totem: aplicada na hora e persistida em SharedPreferences
/// (cache local/offline). Com o Firebase disponível, sincroniza com o doc
/// `tb_totem_config/{clinicaId}` (campo `config`) — a personalização passa a
/// valer em **todos os dispositivos** da clínica, em tempo real.
final totemConfigProvider =
    StateNotifierProvider<TotemConfigNotifier, TotemConfig>((ref) {
  final firebaseOn = ref.watch(firebaseEnabledProvider);
  return TotemConfigNotifier(
    ref.watch(sharedPrefsProvider),
    db: firebaseOn ? FirebaseFirestore.instance : null,
    clinicId: ref.watch(selectedClinicIdProvider),
  );
});

class TotemConfigNotifier extends StateNotifier<TotemConfig> {
  TotemConfigNotifier(
    this._prefs, {
    FirebaseFirestore? db,
    String clinicId = '',
  })  : _db = db,
        _clinicId = clinicId.trim(),
        super(_load(_prefs)) {
    _subscribe();
  }

  static const _key = 'totem_config';
  final SharedPreferences _prefs;
  final FirebaseFirestore? _db;
  final String _clinicId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  DocumentReference<Map<String, dynamic>>? get _doc =>
      (_db == null || _clinicId.isEmpty)
          ? null
          : _db.collection('tb_totem_config').doc(_clinicId);

  static TotemConfig _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const TotemConfig();
    try {
      return TotemConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const TotemConfig();
    }
  }

  /// Espelha o doc da clínica no estado local — edições feitas em outro
  /// dispositivo chegam ao vivo. Sem permissão/offline, segue só o local.
  void _subscribe() {
    final doc = _doc;
    if (doc == null) return;
    _sub = doc.snapshots().listen((snap) {
      final raw = snap.data()?['config'];
      if (raw is! Map) return;
      try {
        final remote = TotemConfig.fromJson(Map<String, dynamic>.from(raw));
        if (!mounted) return;
        final encoded = jsonEncode(remote.toJson());
        if (encoded == jsonEncode(state.toJson())) return; // eco da escrita
        state = remote;
        _prefs.setString(_key, encoded);
      } catch (_) {
        // Doc malformado: mantém a config local.
      }
    }, onError: (_) {
      // Regras do Firestore podem bloquear o totem (rota pública, sem
      // login) — a config continua funcionando por dispositivo.
    });
  }

  void update(TotemConfig config) {
    state = config;
    _prefs.setString(_key, jsonEncode(config.toJson()));
    _doc?.set({
      'config': config.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(mergeFields: ['config', 'updatedAt'])).catchError((_) {
      // Offline/sem permissão: fica só no cache local.
    });
  }

  void reset() => update(const TotemConfig());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Config do totem de uma clínica **específica**, para telas públicas (sem
/// login) que não podem depender de [selectedClinicIdProvider] — ele começa num
/// placeholder até o Firestore responder e apontaria para a clínica errada.
///
/// Lê `tb_totem_config/{clinicaId}` uma única vez. Sem Firebase, sem id ou com
/// as regras bloqueando a leitura anônima, devolve a config padrão — o que
/// importa aqui é a grade de horários (abertura/fechamento, duração, almoço).
final publicTotemConfigProvider =
    FutureProvider.family<TotemConfig, String>((ref, clinicId) async {
  final id = clinicId.trim();
  if (id.isEmpty || !ref.watch(firebaseEnabledProvider)) {
    return const TotemConfig();
  }
  try {
    final snap = await FirebaseFirestore.instance
        .collection('tb_totem_config')
        .doc(id)
        .get();
    final raw = snap.data()?['config'];
    if (raw is! Map) return const TotemConfig();
    return TotemConfig.fromJson(Map<String, dynamic>.from(raw));
  } catch (_) {
    return const TotemConfig();
  }
});
