import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent, bounded, **cross-isolate-safe** buffer of location samples
/// captured while the live heartbeat POST could not reach the server.
///
/// ## Why a spool file, not Hive
/// The live heartbeat runs in the `flutter_background_service` background
/// isolate, but the batch flush runs in the main isolate. Hive boxes are
/// per-isolate: each isolate opens its own box and reads its keyset at open
/// time, so samples appended by the background isolate were invisible to the
/// main isolate (and concurrent writes could corrupt the box). This buffer
/// therefore persists to an append-only, line-delimited-JSON spool file
/// (`tracking_spool.ndjson`) that both isolates can share through `dart:io`.
///
/// ## Protocol
/// * **Writer (background isolate):** [add] appends one JSON line with
///   `FileMode.append` (a single small `write` to an O_APPEND file is atomic on
///   Android/POSIX, so appends never interleave).
/// * **Drainer (main isolate):** [readPending] atomically renames the live
///   spool aside and reads it oldest-first, so a concurrent [add] always lands
///   in a fresh live file and is never lost. [commit] rewrites the drain with
///   the un-sent remainder, letting the flush clear each chunk as it succeeds.
///
/// Samples are capped at [maxSamples], evicting the oldest, both while draining
/// and (lazily) while appending so a long offline stretch cannot grow the file
/// without bound.
class TrackingBuffer {
  TrackingBuffer({Directory? directory}) : _directoryOverride = directory;

  final Directory? _directoryOverride;

  static const String fileName = 'tracking_spool.ndjson';
  static const String drainFileName = 'tracking_spool.drain.ndjson';
  static const int maxSamples = 5000;

  Directory? _directory;
  bool _initialized = false;

  /// Best-effort in-memory tally of live-file lines, seeded lazily from disk.
  /// Only used to decide when to trim during [add]; never authoritative.
  int? _appendedCount;

  Future<void> init([Directory? directory]) async {
    final dir = directory ??
        _directoryOverride ??
        await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    _directory = dir;
    _initialized = true;
    _appendedCount = null;
  }

  Directory get _dir {
    if (!_initialized || _directory == null) {
      throw StateError('TrackingBuffer not initialized. Call init() first.');
    }
    return _directory!;
  }

  File get _liveFile => File('${_dir.path}/$fileName');
  File get _drainFile => File('${_dir.path}/$drainFileName');

  /// Appends [sample] to the live spool. Safe to call from the background
  /// isolate; a single small append to an O_APPEND file is atomic.
  Future<void> add(Map<String, dynamic> sample) async {
    final line = jsonEncode(sample);
    await _liveFile.writeAsString('$line\n', mode: FileMode.append, flush: true);
    final count = _appendedCount;
    if (count == null) {
      _appendedCount = await _countLines(_liveFile);
    } else {
      _appendedCount = count + 1;
      if (_appendedCount! > maxSamples) {
        await _trimLive();
      }
    }
  }

  /// All buffered samples in oldest-first order, **without** draining. Values
  /// from the live spool plus any leftover drain file.
  Future<List<Map<String, dynamic>>> pending() async {
    final samples = <Map<String, dynamic>>[];
    if (await _drainFile.exists()) {
      samples.addAll(await _readLines(_drainFile));
    }
    if (await _liveFile.exists()) {
      samples.addAll(await _readLines(_liveFile));
    }
    return _cap(samples);
  }

  /// Atomically takes ownership of the live spool and returns every pending
  /// sample oldest-first. Safe against a concurrent [add] from another isolate:
  /// the live file is renamed aside (never mutated in place), so new appends go
  /// to a fresh file this drain will not see or clobber.
  Future<List<Map<String, dynamic>>> readPending() async {
    final live = _liveFile;
    final drain = _drainFile;

    if (await live.exists()) {
      final segment = File(
        '${_dir.path}/tracking_spool.seg.'
        '${DateTime.now().microsecondsSinceEpoch}.ndjson',
      );
      await live.rename(segment.path);
      if (await drain.exists()) {
        await drain.writeAsString(
          await segment.readAsString(),
          mode: FileMode.append,
          flush: true,
        );
        await segment.delete();
      } else {
        await segment.rename(drain.path);
      }
    }

    _appendedCount = null;
    if (!await drain.exists()) return const [];
    final all = await _readLines(drain);
    if (all.length > maxSamples) {
      // Bound the on-disk drain after a long offline stretch: keep the newest
      // samples and drop the oldest, matching what we return.
      final capped = all.sublist(all.length - maxSamples);
      await commit(capped);
      return capped;
    }
    return all;
  }

  /// Persists [remaining] as the un-sent tail of the drained batch. The flush
  /// calls this after every successful chunk; passing an empty list clears the
  /// drain, so a fully delivered batch leaves nothing behind.
  Future<void> commit(List<Map<String, dynamic>> remaining) async {
    final drain = _drainFile;
    if (remaining.isEmpty) {
      if (await drain.exists()) await drain.delete();
      return;
    }
    final tmp = File('${_dir.path}/tracking_spool.drain.tmp');
    await tmp.writeAsString(_encodeLines(remaining), flush: true);
    await tmp.rename(drain.path);
  }

  /// Removes every buffered sample (live spool + drain). Used on teardown.
  Future<void> clear() async {
    final live = _liveFile;
    final drain = _drainFile;
    if (await live.exists()) await live.delete();
    if (await drain.exists()) await drain.delete();
    _appendedCount = null;
  }

  // ── internals ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _cap(
    List<Map<String, dynamic>> samples,
  ) {
    if (samples.length <= maxSamples) return samples;
    return samples.sublist(samples.length - maxSamples);
  }

  String _encodeLines(List<Map<String, dynamic>> samples) {
    final buffer = StringBuffer();
    for (final sample in samples) {
      buffer.writeln(jsonEncode(sample));
    }
    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> _readLines(File file) async {
    final String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      debugPrint('TrackingBuffer: could not read ${file.path}: $e');
      return const [];
    }
    final samples = <Map<String, dynamic>>[];
    for (final line in content.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map) {
          samples.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Skip a torn/partial trailing line rather than dropping the batch.
      }
    }
    return samples;
  }

  Future<int> _countLines(File file) async {
    try {
      final content = await file.readAsString();
      return content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _trimLive() async {
    final live = _liveFile;
    if (!await live.exists()) {
      _appendedCount = 0;
      return;
    }
    final lines = (await live.readAsString())
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length <= maxSamples) {
      _appendedCount = lines.length;
      return;
    }
    final kept = lines.sublist(lines.length - maxSamples);
    await live.writeAsString('${kept.join('\n')}\n', flush: true);
    _appendedCount = kept.length;
  }
}
