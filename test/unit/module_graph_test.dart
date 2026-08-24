import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/modules/module.dart';
import 'package:vitta_app/core/modules/module_graph.dart';
import 'package:vitta_app/core/modules/module_registry.dart';

/// Testes do **sistema de módulos / Mapa de Dependências** (AGENTS.md).
void main() {
  final graph = ModuleGraph();

  test('o grafo de módulos é válido (DAG, deps existem, isolamento)', () {
    final v = graph.validate();
    expect(v.cycles, isEmpty, reason: 'não deve haver ciclos');
    expect(v.missingDeps, isEmpty, reason: 'toda dependência deve existir');
    expect(v.collectionConflicts, isEmpty,
        reason: 'cada coleção "owned" pertence a um único módulo');
    expect(v.ok, isTrue);
  });

  test('ordem topológica respeita as dependências', () {
    final order = graph.topologicalOrder();
    final pos = {for (var i = 0; i < order.length; i++) order[i].id: i};
    for (final m in ModuleRegistry.modules) {
      for (final dep in m.dependsOn) {
        expect(pos[dep]! < pos[m.id]!, isTrue,
            reason: '"$dep" deve vir antes de "${m.id}"');
      }
    }
    expect(order.length, ModuleRegistry.modules.length);
  });

  test('arestas-chave do diagrama estão presentes', () {
    void edge(String from, String to) {
      expect(graph[from]!.dependsOn, contains(to),
          reason: '$from deve depender de $to');
    }

    edge('home', 'auth');
    edge('agendamentos', 'home');
    edge('recepcao', 'home');
    edge('criar_agendamento', 'agendamentos');
    edge('tickets', 'recepcao');
    edge('prever', 'recepcao');
    edge('ia', 'criar_agendamento');
    edge('financeiro', 'criar_agendamento');
    edge('integracoes', 'ia');
  });

  test('dependentsOf e transitiveDependencies funcionam', () {
    expect(graph.dependentsOf('auth').map((m) => m.id), contains('home'));
    final trans = graph.transitiveDependencies('integracoes');
    expect(trans, containsAll(['ia', 'criar_agendamento', 'agendamentos', 'home', 'auth']));
  });

  test('rotas dos módulos navegáveis são absolutas', () {
    for (final m in ModuleRegistry.modules) {
      if (m.route != null) {
        expect(m.route!.startsWith('/'), isTrue, reason: m.id);
      }
    }
  });

  test('detecta ciclo em um grafo inválido (sanidade do algoritmo)', () {
    WidgetsFlutterBinding.ensureInitialized();
    final cyclic = ModuleGraph(const [
      AppModule(
        id: 'a',
        title: 'A',
        code: 'A',
        icon: Icons.abc,
        priority: ModulePriority.p0,
        status: ModuleStatus.planned,
        dependsOn: ['b'],
      ),
      AppModule(
        id: 'b',
        title: 'B',
        code: 'B',
        icon: Icons.abc,
        priority: ModulePriority.p0,
        status: ModuleStatus.planned,
        dependsOn: ['a'],
      ),
    ]);
    expect(cyclic.detectCycles(), isNotEmpty);
    expect(() => cyclic.topologicalOrder(), throwsStateError);
  });
}
