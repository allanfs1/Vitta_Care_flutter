import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/navigation/app_router.dart';

/// Garante que o redirect do router respeita o vínculo de plano:
/// - com plano: `/choose-plan` é bloqueado (vai para a home);
/// - sem plano: o app força a escolha de plano.
Future<GoRouter> _routerWith(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(sp)],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('com plano vinculado, /choose-plan redireciona para a home',
      (tester) async {
    final router = await _routerWith(tester, {
      'auth_logged_in': true,
      'auth_plan_id': 'plan_pro',
      'auth_email': 'gestor@vitta.app',
    });

    router.go(AppRoutes.choosePlan);
    await tester.pump(const Duration(milliseconds: 300));

    expect(_location(router), AppRoutes.home);
  });

  testWidgets('autenticado sem plano é levado para /choose-plan',
      (tester) async {
    final router = await _routerWith(tester, {
      'auth_logged_in': true,
      'auth_email': 'gestor@vitta.app',
    });

    router.go(AppRoutes.home);
    await tester.pump(const Duration(milliseconds: 300));

    expect(_location(router), AppRoutes.choosePlan);
  });
}
