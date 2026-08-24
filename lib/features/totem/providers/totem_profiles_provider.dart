import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_providers.dart';
import '../models/totem_config.dart';
import '../models/totem_profile.dart';

/// Overrides de perfil salvos pelo usuário (id do perfil -> config).
/// Quando um perfil não tem override, vale o preset embutido [kTotemProfiles].
/// Persistência local em SharedPreferences; com Firebase disponível, o campo
/// `profiles` de `tb_totem_config/{clinicaId}` sincroniza entre dispositivos.
class TotemProfilesNotifier extends StateNotifier<Map<String, TotemConfig>> {
  TotemProfilesNotifier(
    this._prefs, {
    FirebaseFirestore? db,
    String clinicId = '',
  })  : _db = db,
        _clinicId = clinicId.trim(),
        super(_load(_prefs)) {
    _subscribe();
  }

  static const _key = 'totem_profiles';
  final SharedPreferences _prefs;
  final FirebaseFirestore? _db;
  final String _clinicId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  DocumentReference<Map<String, dynamic>>? get _doc =>
      (_db == null || _clinicId.isEmpty)
          ? null
          : _db.collection('tb_totem_config').doc(_clinicId);

  static Map<String, TotemConfig> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _decode(map);
    } catch (_) {
      return {};
    }
  }

  static Map<String, TotemConfig> _decode(Map<String, dynamic> map) => {
        for (final e in map.entries)
          if (e.value is Map)
            e.key: TotemConfig.fromJson(
                Map<String, dynamic>.from(e.value as Map)),
      };

  Map<String, dynamic> _encoded() =>
      {for (final e in state.entries) e.key: e.value.toJson()};

  /// Espelha os overrides remotos (outros dispositivos da clínica).
  void _subscribe() {
    final doc = _doc;
    if (doc == null) return;
    _sub = doc.snapshots().listen((snap) {
      final raw = snap.data()?['profiles'];
      if (raw is! Map) return;
      try {
        final remote = _decode(Map<String, dynamic>.from(raw));
        if (!mounted) return;
        final encoded =
            jsonEncode({for (final e in remote.entries) e.key: e.value.toJson()});
        if (encoded == jsonEncode(_encoded())) return; // eco da escrita
        state = remote;
        _prefs.setString(_key, encoded);
      } catch (_) {
        // Campo malformado: mantém os overrides locais.
      }
    }, onError: (_) {
      // Sem permissão/offline: segue local.
    });
  }

  void _persist() {
    final encoded = _encoded();
    _prefs.setString(_key, jsonEncode(encoded));
    // `mergeFields` substitui o campo inteiro (necessário para o `restore`
    // remover um override também no servidor), preservando o campo `config`.
    _doc?.set({
      'profiles': encoded,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(mergeFields: ['profiles', 'updatedAt'])).catchError((_) {
      // Offline/sem permissão: fica só no cache local.
    });
  }

  /// Config efetiva do perfil: override salvo, senão o preset embutido.
  TotemConfig configFor(String id) {
    final saved = state[id];
    if (saved != null) return saved;
    return kTotemProfiles
        .firstWhere((p) => p.id == id, orElse: () => kTotemProfiles.first)
        .config;
  }

  /// `true` se o perfil tem uma versão salva (diferente do preset original).
  bool hasOverride(String id) => state.containsKey(id);

  /// Salva a configuração informada como o conteúdo do perfil.
  void save(String id, TotemConfig cfg) {
    state = {...state, id: cfg};
    _persist();
  }

  /// Remove o override e volta o perfil ao preset embutido.
  void restore(String id) {
    if (!state.containsKey(id)) return;
    state = {...state}..remove(id);
    _persist();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final totemProfilesProvider =
    StateNotifierProvider<TotemProfilesNotifier, Map<String, TotemConfig>>(
        (ref) {
  final firebaseOn = ref.watch(firebaseEnabledProvider);
  return TotemProfilesNotifier(
    ref.watch(sharedPrefsProvider),
    db: firebaseOn ? FirebaseFirestore.instance : null,
    clinicId: ref.watch(selectedClinicIdProvider),
  );
});

/// Perfil atualmente selecionado no painel (para salvar/restaurar). `null` =
/// nenhum perfil escolhido (configuração avulsa).
final activeTotemProfileProvider = StateProvider<String?>((ref) => null);
