import 'dart:async';
import 'dart:collection';
import 'dart:convert';

/// Durable backing store for [ReadCache]. Implementations persist string
/// payloads keyed by [key]. A fault-tolerant store should degrade to no-ops
/// (returning `null` / nothing) rather than throwing, so the cache never breaks
/// the request that is using it.
abstract interface class ReadCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

/// In-memory store. Safe default used in tests and whenever a durable store is
/// unavailable.
class MemoryReadCacheStore implements ReadCacheStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

/// An in-memory + pluggable durable read cache for raw JSON API responses.
///
/// Values are stored as `Map<String, dynamic>` in memory for fast repeat reads,
/// and mirrored as JSON strings to [store] (e.g. a Hive box) for persistence
/// across launches. Every [ReadCacheStore] operation is wrapped so a storage
/// failure degrades to in-memory-only and never breaks the caller.
///
/// The cache holds raw payloads (not parsed models) so it works generically
/// without per-model serialization. Callers choose which keys to cache via an
/// allowlist enforced upstream.
class ReadCache {
  ReadCache({DateTime Function()? now, ReadCacheStore? store})
    : _now = now ?? DateTime.now,
      _store = store ?? MemoryReadCacheStore();

  final DateTime Function() _now;
  final ReadCacheStore _store;
  final Map<String, _Entry> _entries = HashMap<String, _Entry>();

  /// Default freshness window before a value is considered stale.
  static const Duration defaultTtl = Duration(minutes: 5);

  int get length => _entries.length;

  /// Writes [json] to memory and (best-effort) persists it to [store].
  void setJson(String key, Map<String, dynamic> json) {
    _entries[key] = _Entry(json, _now());
    // Fire-and-forget: never block the request path on disk I/O.
    unawaited(
      _store.write(key, jsonEncode(json)).catchError((_) {}),
    );
  }

  /// Returns the cached value from memory, ignoring age (offline fallback).
  /// Returns `null` when absent or of the wrong shape.
  Map<String, dynamic>? peekJson(String key) {
    final entry = _entries[key];
    if (entry != null && entry.value is Map) {
      return Map<String, dynamic>.from(entry.value as Map);
    }
    return null;
  }

  /// Reads a value, preferring memory and falling back to the durable store.
  Future<Map<String, dynamic>?> readJson(String key) async {
    final cached = peekJson(key);
    if (cached != null) return cached;
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        _entries[key] = _Entry(map, _now());
        return map;
      }
    } catch (_) {
      // Corrupt/undecodable entry — treat as a miss.
    }
    return null;
  }

  /// Whether [key] holds a value fetched within [ttl].
  bool isFresh(String key, {Duration? ttl}) {
    final entry = _entries[key];
    if (entry == null) return false;
    return _now().difference(entry.fetchedAt) <= (ttl ?? defaultTtl);
  }

  bool has(String key) => _entries.containsKey(key);

  void invalidate(String key) {
    _entries.remove(key);
    unawaited(_store.delete(key).catchError((_) {}));
  }

  void clear() {
    _entries.clear();
    unawaited(_store.clear().catchError((_) {}));
  }
}

class _Entry {
  _Entry(this.value, this.fetchedAt);

  final Object? value;
  final DateTime fetchedAt;
}
