import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';

/// Cria um [ProviderContainer] com SharedPreferences mockado, para testes de unidade.
Future<ProviderContainer> makeContainer({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(sp)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Envolve um widget com ProviderScope + MaterialApp para testes de widget.
Future<Widget> wrap(Widget child, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(sp)],
    child: MaterialApp(home: child),
  );
}

/// Bombeia frames até estabilizar, ignorando timeouts de animações infinitas.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
