import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Persistent, bounded buffer of location samples captured while the live
/// heartbeat POST could not reach the server.
///
/// ## Keying and ordering
/// Hive does **not** iterate keys in insertion order (its backing map is
/// hash-ordered), so `box.keys.first` is not necessarily the oldest sample.
/// To make eviction and `pending()` deterministic, each sample is stored under
/// a sortable key: a zero-padded microsecond sequence (monotonic, seeded from
/// the largest existing key so it survives restarts) joined to a random UUID.
/// Lexicographic key order therefore equals insertion order, and each key is
/// still unique via its UUID component.
///
/// The box is encrypted with the same [HiveAesCipher] as the `OfflineQueue`
/// (`main.dart` reuses one cipher for all encrypted boxes).
class TrackingBuffer {
  static const String boxName = 'tracking_buffer';
  static const int maxSamples = 5000;

  final _uuid = const Uuid();

  int _lastSeq = 0;
  bool _seqLoaded = false;

  Future<void> init(HiveAesCipher? cipher) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
    }
    // Re-derive the sequence floor from whatever is already on disk.
    _seqLoaded = false;
  }

  Box<Map> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('TrackingBuffer not initialized. Call init() first.');
    }
    return Hive.box<Map>(boxName);
  }

  /// Seeds [_lastSeq] from the largest existing key so a fresh process never
  /// reuses a sequence lower than samples already buffered.
  void _ensureSeqLoaded() {
    if (_seqLoaded) return;
    _seqLoaded = true;
    _lastSeq = 0;
    for (final key in _box.keys.cast<String>()) {
      final separator = key.indexOf(':');
      if (separator <= 0) continue;
      final value = int.tryParse(key.substring(0, separator));
      if (value != null && value > _lastSeq) _lastSeq = value;
    }
  }

  String _nextKey() {
    _ensureSeqLoaded();
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastSeq = now > _lastSeq ? now : _lastSeq + 1;
    return '${_lastSeq.toString().padLeft(20, '0')}:${_uuid.v4()}';
  }

  List<String> _orderedKeys() =>
      _box.keys.cast<String>().toList()..sort();

  /// Appends [sample] under a fresh sortable key, evicting the oldest keys once
  /// the buffer exceeds [maxSamples].
  Future<void> add(Map<String, dynamic> sample) async {
    final box = _box;
    await box.put(_nextKey(), sample);
    final overflow = box.length - maxSamples;
    if (overflow > 0) {
      await box.deleteAll(_orderedKeys().take(overflow));
    }
  }

  /// All buffered samples in oldest-first order.
  ///
  /// Values only — use [pendingWithIds] when the caller needs the keys to clear
  /// exactly what it flushed.
  List<Map<String, dynamic>> pending() {
    final box = _box;
    return _orderedKeys()
        .map((key) => box.get(key))
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  /// Buffered samples keyed by their storage id, in oldest-first order.
  ///
  /// The batch flush uses this so it can send the samples and then call
  /// [clear] with exactly the ids it sent — [pending] returns values only and
  /// therefore cannot tell the flush which keys to remove.
  Map<String, Map<String, dynamic>> pendingWithIds() {
    final box = _box;
    final result = <String, Map<String, dynamic>>{};
    for (final key in _orderedKeys()) {
      final value = box.get(key);
      if (value != null) {
        result[key] = Map<String, dynamic>.from(value);
      }
    }
    return result;
  }

  /// Removes the samples stored under [ids]. Unknown ids are ignored.
  Future<void> clear(Iterable<String> ids) async {
    final box = _box;
    final existing = ids.where(box.containsKey).toList();
    if (existing.isNotEmpty) {
      await box.deleteAll(existing);
    }
  }
}
