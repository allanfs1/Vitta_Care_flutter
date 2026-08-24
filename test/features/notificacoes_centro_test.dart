import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/notificacoes_centro/notificacoes_centro_screen.dart';
import 'package:vitta_app/features/notificacoes_centro/notificacoes_provider.dart';

// O feed agora vem de um repositório (em memória fora do Firebase), então o
// estado inicial chega de forma assíncrona — daí os `pump`/`aguardarBoot`.
void main() {
  // O feed é escopado por clínica, e a clínica vem de SharedPreferences.
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer novoContainer() {
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> aguardarBoot(ProviderContainer c) async {
    c.read(notificacoesProvider);
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  testWidgets('lista notificações e "Marcar todas" zera as não lidas',
      (tester) async {
    final container = novoContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificacoesCentroScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Itens renderizam.
    expect(find.text('Consulta cancelada'), findsOneWidget);
    expect(find.text('Novo agendamento'), findsOneWidget);

    // Há não lidas no estado inicial.
    expect(container.read(unreadCountProvider) > 0, isTrue);

    await tester.tap(find.text('Marcar todas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(unreadCountProvider), 0);
  });

  test('markRead alterna o estado de leitura de um item', () async {
    final container = novoContainer();
    await aguardarBoot(container);

    final notifier = container.read(notificacoesProvider.notifier);
    final id = container.read(notificacoesProvider).first.id;

    await notifier.markRead(id);
    expect(
      container.read(notificacoesProvider).firstWhere((n) => n.id == id).read,
      isTrue,
    );
  });
}
