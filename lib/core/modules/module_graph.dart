import 'module.dart';
import 'module_registry.dart';

/// Resultado de validação do grafo de módulos.
class GraphValidation {
  const GraphValidation({
    required this.ok,
    this.cycles = const [],
    this.missingDeps = const [],
    this.collectionConflicts = const [],
  });

  final bool ok;

  /// Ciclos detectados (cada item é a sequência de ids que forma o ciclo).
  final List<List<String>> cycles;

  /// Dependências apontando para módulos inexistentes (`module -> depId`).
  final List<String> missingDeps;

  /// Coleções "owned" reivindicadas por mais de um módulo (quebra de isolamento).
  final List<String> collectionConflicts;
}

/// Operações sobre o **Mapa de Dependências entre Módulos**.
///
/// Opera, por padrão, sobre [ModuleRegistry.modules], mas aceita uma lista
/// customizada (útil em testes).
class ModuleGraph {
  ModuleGraph([List<AppModule>? modules])
      : modules = modules ?? ModuleRegistry.modules {
    _byId = {for (final m in this.modules) m.id: m};
  }

  final List<AppModule> modules;
  late final Map<String, AppModule> _byId;

  AppModule? operator [](String id) => _byId[id];

  /// Dependências diretas de um módulo.
  List<AppModule> dependenciesOf(String id) =>
      [for (final dep in _byId[id]?.dependsOn ?? const []) if (_byId[dep] != null) _byId[dep]!];

  /// Módulos que dependem diretamente do módulo informado.
  List<AppModule> dependentsOf(String id) =>
      [for (final m in modules) if (m.dependsOn.contains(id)) m];

  /// Fecho transitivo: todas as dependências (diretas e indiretas) de um módulo.
  Set<String> transitiveDependencies(String id) {
    final result = <String>{};
    void visit(String current) {
      for (final dep in _byId[current]?.dependsOn ?? const []) {
        if (result.add(dep)) visit(dep);
      }
    }

    visit(id);
    return result;
  }

  /// Ordem topológica (uma ordem de implementação válida respeitando dependências).
  /// Lança [StateError] se houver ciclo.
  List<AppModule> topologicalOrder() {
    final visited = <String>{};
    final temp = <String>{};
    final order = <AppModule>[];

    void visit(AppModule m) {
      if (visited.contains(m.id)) return;
      if (!temp.add(m.id)) {
        throw StateError('Ciclo de dependência detectado em "${m.id}"');
      }
      for (final dep in m.dependsOn) {
        final depModule = _byId[dep];
        if (depModule != null) visit(depModule);
      }
      temp.remove(m.id);
      visited.add(m.id);
      order.add(m);
    }

    for (final m in modules) {
      visit(m);
    }
    return order;
  }

  /// Detecta todos os ciclos via DFS.
  List<List<String>> detectCycles() {
    final cycles = <List<String>>[];
    final state = <String, int>{}; // 0=branco,1=cinza,2=preto
    final stack = <String>[];

    void dfs(String id) {
      state[id] = 1;
      stack.add(id);
      for (final dep in _byId[id]?.dependsOn ?? const []) {
        if (_byId[dep] == null) continue;
        if (state[dep] == 1) {
          final start = stack.indexOf(dep);
          cycles.add([...stack.sublist(start), dep]);
        } else if (state[dep] != 2) {
          dfs(dep);
        }
      }
      stack.removeLast();
      state[id] = 2;
    }

    for (final m in modules) {
      if (state[m.id] != 2) dfs(m.id);
    }
    return cycles;
  }

  /// Valida o grafo: aciclicidade, dependências existentes e isolamento de
  /// coleções (cada coleção "owned" pertence a no máximo um módulo).
  GraphValidation validate() {
    final missing = <String>[];
    for (final m in modules) {
      for (final dep in m.dependsOn) {
        if (!_byId.containsKey(dep)) missing.add('${m.id} -> $dep');
      }
    }

    final owners = <String, String>{};
    final conflicts = <String>[];
    for (final m in modules) {
      for (final col in m.ownedCollections) {
        final existing = owners[col];
        if (existing != null && existing != m.id) {
          conflicts.add('$col (${m.id} vs $existing)');
        } else {
          owners[col] = m.id;
        }
      }
    }

    final cycles = detectCycles();
    return GraphValidation(
      ok: cycles.isEmpty && missing.isEmpty && conflicts.isEmpty,
      cycles: cycles,
      missingDeps: missing,
      collectionConflicts: conflicts,
    );
  }
}
