/// Cache em memória (TTL) para respostas MCP — porta Dart de `src/lib/mcp-cache.js`.
///
/// Vive no processo do app; útil para listagens repetidas. TTL sugerido:
/// 2 min para listas, 30 s para dados em tempo real.
class McpCache {
  McpCache._();

  static final McpCache instance = McpCache._();

  final Map<String, _Entry> _store = {};

  /// Retorna o valor ou `null` se expirado/ausente (limpa entradas expiradas).
  Object? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.data;
  }

  /// Grava com expiração (TTL padrão 2 min).
  void set(String key, Object? data,
      {Duration ttl = const Duration(milliseconds: 120000)}) {
    _store[key] = _Entry(data, DateTime.now().add(ttl));
  }

  /// Remove todas as chaves que começam com [prefix].
  void invalidate(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Executa [fn] apenas se não houver cache válido para [key].
  Future<T> withCache<T>(String key, Future<T> Function() fn,
      {Duration ttl = const Duration(milliseconds: 120000)}) async {
    final cached = get(key);
    if (cached is T) return cached;
    final result = await fn();
    set(key, result, ttl: ttl);
    return result;
  }

  /// `{ active, expired, total }`.
  Map<String, int> stats() {
    var active = 0;
    var expired = 0;
    for (final e in _store.values) {
      if (e.isExpired) {
        expired++;
      } else {
        active++;
      }
    }
    return {'active': active, 'expired': expired, 'total': _store.length};
  }

  void clear() => _store.clear();
}

class _Entry {
  _Entry(this.data, this.expiresAt);

  final Object? data;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
