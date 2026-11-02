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
///
/// ## Owner scoping and age
/// Keys are deliberately caller-defined, but the API enforces that the caller's
/// account identity is part of the key (see `MobileRepository`). Persisted
/// entries carry their fetch timestamp so [readJson] can refuse to serve data
/// older than [maxFallbackAge]. Entries written by older app versions (raw JSON
/// without a timestamp) are treated as misses: the cache is disposable, and
/// un-stamped data must never be replayed for whichever account is signed in.
class ReadCache {
  ReadCache({DateTime Function()? now, ReadCacheStore? store})
    : _now = now ?? DateTime.now,
      _store = store ?? MemoryReadCacheStore();

  final DateTime Function() _now;
  final ReadCacheStore _store;
  final Map<String, _Entry> _entries = HashMap<String, _Entry>();

  /// Default freshness window before a value is considered stale.
  static const Duration defaultTtl = Duration(minutes: 5);

  /// Maximum age of a persisted entry that may still be served as an offline
  /// fallback. Anything older is treated as a miss.
  static const Duration maxFallbackAge = Duration(hours: 24);

  /// Envelope keys for the persisted representation.
  static const String fetchedAtKey = 'fetchedAt';
  static const String valueKey = 'value';

  int get length => _entries.length;

  /// Writes [json] to memory and (best-effort) persists it to [store] with the
  /// current timestamp.
  void setJson(String key, Map<String, dynamic> json) {
    final entry = _Entry(json, _now());
    _entries[key] = entry;
    // Fire-and-forget: never block the request path on disk I/O.
    unawaited(
      _store.write(key, _encodeEntry(entry)).catchError((_) {}),
    );
  }

  /// Returns the cached value from memory, ignoring age (offline fallback).
  /// Returns `null` when absent or of the wrong shape.
  Map<String, dynamic>? peekJson(String key) {
    final entry = _entries[key];
    return _valueOf(entry);
  }

  /// Reads a value, preferring memory and falling back to the durable store.
  ///
  /// When [maxAge] is provided, entries fetched longer ago than that are
  /// treated as misses (and evicted from memory). Pass [maxFallbackAge] on an
  /// offline-fallback path so a stale payload can never be served indefinitely.
  Future<Map<String, dynamic>?> readJson(
    String key, {
    Duration? maxAge,
  }) async {
    final inMemory = _entries[key];
    if (inMemory != null) {
      if (_isExpired(inMemory, maxAge)) {
        _entries.remove(key);
        return null;
      }
      return _valueOf(inMemory);
    }
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final entry = _decodeEntry(raw);
      if (entry == null) return null;
      if (_isExpired(entry, maxAge)) {
        // Do not leave an un-servable entry in the hot path.
        unawaited(_store.delete(key).catchError((_) {}));
        return null;
      }
      _entries[key] = entry;
      return _valueOf(entry);
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

  /// Clears memory and the durable store. Awaits the store so callers such as
  /// the local-data purger can guarantee data is gone before continuing.
  Future<void> clear() async {
    _entries.clear();
    try {
      await _store.clear();
    } catch (_) {
      // Best-effort: an unavailable store has nothing durable to clear.
    }
  }

  Map<String, dynamic>? _valueOf(_Entry? entry) {
    if (entry == null) return null;
    final value = entry.value;
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  bool _isExpired(_Entry entry, Duration? maxAge) {
    if (maxAge == null) return false;
    return _now().toUtc().difference(entry.fetchedAt.toUtc()) > maxAge;
  }

  String _encodeEntry(_Entry entry) {
    return jsonEncode(<String, dynamic>{
      fetchedAtKey: entry.fetchedAt.toUtc().toIso8601String(),
      valueKey: entry.value,
    });
  }

  _Entry? _decodeEntry(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final value = decoded[valueKey];
    if (value is! Map) return null;
    final fetchedAtRaw = decoded[fetchedAtKey];
    if (fetchedAtRaw is! String) return null;
    final fetchedAt = DateTime.tryParse(fetchedAtRaw);
    if (fetchedAt == null) return null;
    return _Entry(Map<String, dynamic>.from(value), fetchedAt);
  }
}

class _Entry {
  _Entry(this.value, this.fetchedAt);

  final Object? value;
  final DateTime fetchedAt;
}
