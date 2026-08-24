import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/relatorios/providers/relatorios_provider.dart';
import 'package:vitta_app/features/relatorios/relatorios_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('RelatoriosScreen lista os relatórios gerados', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: RelatoriosScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Relatórios'), findsOneWidget);
    expect(find.text('Desempenho operacional — Junho'), findsOneWidget);
  });

  test('Relatorio.toCsv inclui título e métricas', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    // A lista agora vem do repositório: o boot é assíncrono.
    container.read(relatoriosProvider);
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final reports = container.read(relatoriosProvider);
    final csv = reports.first.toCsv();
    expect(csv, contains('titulo'));
    expect(csv, contains('Taxa de ocupação'));
  });
}
