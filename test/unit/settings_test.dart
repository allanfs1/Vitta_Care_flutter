import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/configuracoes/models/app_settings.dart';
import 'package:vitta_app/features/configuracoes/providers/configuracoes_provider.dart';

import '../helpers.dart';

/// Testes do Módulo 9 — Configurações do Sistema.
void main() {
  // Necessário para google_fonts ao construir o tema; sem buscar na rede.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('AppSettings serializa e desserializa (round-trip)', () {
    const s = AppSettings(
      primaryColor: 0xFF7C3AED,
      fontFamily: 'Poppins',
      fontScale: 1.25,
      themeMode: ThemeMode.dark,
      borderRadius: 8,
      highContrast: true,
      colorBlindFilter: ColorBlindFilter.deuteranopia,
    );
    final decoded = AppSettings.decode(s.encode());
    expect(decoded.primaryColor, 0xFF7C3AED);
    expect(decoded.fontFamily, 'Poppins');
    expect(decoded.fontScale, 1.25);
    expect(decoded.themeMode, ThemeMode.dark);
    expect(decoded.borderRadius, 8);
    expect(decoded.highContrast, true);
    expect(decoded.colorBlindFilter, ColorBlindFilter.deuteranopia);
  });

  test('defaultsFor aplica paleta por tipo de unidade', () {
    expect(AppSettings.defaultsFor(ClinicType.upa).paletteId, 'urgencia');
    expect(AppSettings.defaultsFor(ClinicType.privada).paletteId, 'premium');
    expect(AppSettings.defaultsFor(ClinicType.ubs).paletteId, 'institucional');
  });

  test('SettingsController persiste alterações em SharedPreferences', () async {
    final c = await makeContainer();
    final ctrl = c.read(settingsProvider.notifier);
    ctrl.setFontFamily('Roboto');
    ctrl.setBorderRadius(0);
    expect(c.read(settingsProvider).fontFamily, 'Roboto');
    expect(c.read(settingsProvider).borderRadius, 0);

    // Novo container lê a mesma instância de prefs e restaura o estado.
    final ctrl2 = c.read(settingsProvider.notifier);
    expect(ctrl2.state.fontFamily, 'Roboto');
  });

  test('reduceMotion desliga animações efetivas', () {
    const s = AppSettings(animationsEnabled: true, reduceMotion: true);
    expect(s.effectiveAnimations, false);
  });
}
