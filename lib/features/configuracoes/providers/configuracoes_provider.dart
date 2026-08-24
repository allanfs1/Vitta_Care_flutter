import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_providers.dart';
import '../models/app_settings.dart';

/// Controla as preferências do app (Módulo 9), persistindo em SharedPreferences.
/// (A sincronização com Firestore `tb_limit_app`/`users` é um passo futuro.)
class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._prefs) : super(AppSettings.decode(_prefs.getString(_key)));

  static const _key = 'app_settings';
  final SharedPreferences _prefs;

  void _save(AppSettings next) {
    state = next;
    _prefs.setString(_key, next.encode());
  }

  /// Atualiza aplicando uma transformação sobre o estado atual.
  void update(AppSettings Function(AppSettings s) transform) =>
      _save(transform(state));

  void applyPalette(AppPalette p) => _save(state.applyPalette(p));

  void setPrimary(Color c) => _save(state.copyWith(primaryColor: c.toARGB32()));
  void setAccent(Color c) => _save(state.copyWith(accentColor: c.toARGB32()));
  void setBackground(Color c) =>
      _save(state.copyWith(backgroundColor: c.toARGB32()));

  void setThemeMode(ThemeMode m) => _save(state.copyWith(themeMode: m));
  void setFontFamily(String f) => _save(state.copyWith(fontFamily: f));
  void setFontScale(double s) => _save(state.copyWith(fontScale: s));
  void setBorderRadius(double r) => _save(state.copyWith(borderRadius: r));

  void togglePush(String key, bool value) {
    final next = {...state.pushToggles, key: value};
    _save(state.copyWith(pushToggles: next));
  }

  void toggleEmail(String key, bool value) {
    final next = {...state.emailToggles, key: value};
    _save(state.copyWith(emailToggles: next));
  }

  /// Define (ou remove) o logotipo personalizado da marca.
  void setLogo(String? base64) {
    _save(base64 == null
        ? state.copyWith(clearLogo: true)
        : state.copyWith(logoBase64: base64));
  }

  /// Restaura os padrões (CFG-07g) — opcionalmente por tipo de unidade.
  void restoreDefaults({AppSettings? defaults}) =>
      _save(defaults ?? const AppSettings());
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(sharedPrefsProvider));
});
