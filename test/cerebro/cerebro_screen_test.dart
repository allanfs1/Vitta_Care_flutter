import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/cerebro/cerebro_screen.dart';
import 'package:vitta_app/features/cerebro/data/nota_repository.dart';
import 'package:vitta_app/features/cerebro/data/vault_demo.dart';
import 'package:vitta_app/features/cerebro/providers/cerebro_providers.dart';
import 'package:vitta_app/features/cerebro/ui/comum/barra_superior.dart';
import 'package:vitta_app/features/cerebro/ui/comum/status_bar.dart';
import 'package:vitta_app/features/cerebro/ui/direita/painel_direito.dart';
import 'package:vitta_app/features/cerebro/ui/editor/area_editor.dart';
import 'package:vitta_app/features/cerebro/ui/esquerda/painel_esquerdo.dart';
import 'package:vitta_app/features/cerebro/ui/rail/cerebro_rail.dart';

/// Smoke test das 3 densidades de layout do Cérebro (§10.1).
///
/// O objetivo não é congelar pixels e sim garantir que a tela monta sem
/// overflow em cada faixa de largura — o modo de falha clássico de uma tela
/// com quatro painéis simultâneos.
void main() {
  const clinica = 'clinica-teste';

  Future<ProviderContainer> montar(WidgetTester tester, Size tamanho) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = MemoriaNotaRepository();
    await repo.salvarLote(VaultDemo.gerar(clinica, alvo: 60));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseEnabledProvider.overrideWithValue(false),
        vaultProvider
            .overrideWith((ref) => VaultNotifier(ref, repo, clinica)),
      ],
      child: const MaterialApp(home: CerebroScreen()),
    ));

    // Carregamento e indexação do vault são assíncronos; sem `pumpAndSettle`
    // porque o grafo mantém um `Ticker` perpétuo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    return ProviderScope.containerOf(tester.element(find.byType(CerebroScreen)));
  }

  testWidgets('layout amplo mostra rail e os dois painéis', (tester) async {
    await montar(tester, const Size(1600, 900));

    expect(find.byType(CerebroBarraSuperior), findsOneWidget);
    expect(find.byType(CerebroRail), findsOneWidget);
    expect(find.byType(PainelEsquerdoView), findsOneWidget);
    expect(find.byType(PainelDireito), findsOneWidget);
    expect(find.byType(CerebroStatusBar), findsOneWidget);
  });

  testWidgets('layout médio mantém o rail e recolhe o painel direito',
      (tester) async {
    await montar(tester, const Size(1000, 800));

    expect(find.byType(CerebroRail), findsOneWidget);
    expect(find.byType(PainelEsquerdoView), findsOneWidget);
    // Painel direito vira gaveta: não é construído até ser aberto.
    expect(find.byType(PainelDireito), findsNothing);
  });

  testWidgets('layout compacto deixa só a área central', (tester) async {
    await montar(tester, const Size(700, 800));

    expect(find.byType(CerebroBarraSuperior), findsOneWidget);
    expect(find.byType(CerebroRail), findsNothing);
    expect(find.byType(PainelEsquerdoView), findsNothing);
    expect(find.byType(AreaEditor), findsOneWidget);
  });

  testWidgets('gaveta compacta traz rail e explorador juntos', (tester) async {
    await montar(tester, const Size(700, 800));

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CerebroRail), findsOneWidget);
    expect(find.byType(PainelEsquerdoView), findsOneWidget);
  });

  testWidgets('abrir uma nota monta abas, contexto e editor', (tester) async {
    final container = await montar(tester, const Size(1600, 900));

    final index = container.read(vaultProvider.notifier).index;
    final primeira = index.notas.values.firstWhere((n) => !n.excluida);
    container.read(abasProvider.notifier).abrir(primeira.id);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AreaEditor), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(container.read(abasProvider).notaAtiva, primeira.id);
  });
}
