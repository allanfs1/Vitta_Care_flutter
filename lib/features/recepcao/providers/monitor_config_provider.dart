import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_providers.dart';
import '../models/monitor_config.dart';

/// Configuração do Monitor da Recepção, persistida em SharedPreferences.
final monitorConfigProvider =
    StateNotifierProvider<MonitorConfigNotifier, MonitorConfig>((ref) {
  return MonitorConfigNotifier(ref.watch(sharedPrefsProvider));
});

class MonitorConfigNotifier extends StateNotifier<MonitorConfig> {
  MonitorConfigNotifier(this._prefs) : super(_load(_prefs));

  static const _key = 'recepcao_monitor_config';
  final SharedPreferences _prefs;

  static MonitorConfig _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const MonitorConfig();
    try {
      return MonitorConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const MonitorConfig();
    }
  }

  void update(MonitorConfig config) {
    state = config;
    _prefs.setString(_key, jsonEncode(config.toJson()));
  }

  void reset() => update(const MonitorConfig());
}
