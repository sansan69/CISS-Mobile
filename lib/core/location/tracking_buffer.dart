import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../offline/willingness_queue.dart' show willingnessOrigin;

/// One spooled location sample together with the identity of whoever captured
/// it.
///
/// The spool file is shared by every account that ever signed in on a device,
/// so a bare sample cannot be attributed safely: dispatching it with whatever
/// credentials happen to be current could file one guard's breadcrumbs under
/// another guard's session. Each entry therefore records the capturing owner
/// (the guard's employee document id) and the API origin it was captured for.
///
/// [owner] and [origin] are null only for legacy rows written before the
/// envelope existed. Those rows are never dispatched; they stay quarantined
/// until the spool's sample cap retires them.
class TrackingSpoolEntry {
  const TrackingSpoolEntry({required this.sample, this.owner, this.origin});

  final Map<String, dynamic> sample;
  final String? owner;
  final String? origin;

  /// True when this row carries enough identity to be dispatched at all.
  bool get isAttributed =>
      owner != null &&
      owner!.isNotEmpty &&
      origin != null &&
      origin!.isNotEmpty;

  /// True when the currently signed-in guard, talking to [origin], is entitled
  /// to deliver this sample.
  bool belongsTo({required String owner, required String origin}) =>
      isAttributed &&
      this.owner == owner &&
      willingnessOrigin(this.origin!) == willingnessOrigin(origin);

  Map<String, dynamic> toEnvelopeJson() => <String, dynamic>{
    'owner': owner,
    'origin': origin,
    'sample': sample,
  };

  /// Parses one spool line. A line without the envelope is a legacy sample and
  /// keeps a null owner so it can never be attributed by accident.
  static TrackingSpoolEntry? fromLine(Map<String, dynamic> decoded) {
    final sample = decoded['sample'];
    if (sample is Map &&
        decoded.containsKey('owner') &&
        decoded.containsKey('origin')) {
      final owner = decoded['owner'];
      final origin = decoded['origin'];
      return TrackingSpoolEntry(
        sample: Map<String, dynamic>.from(sample),
        owner: owner is String ? owner : null,
        origin: origin is String ? origin : null,
      );
    }
    return TrackingSpoolEntry(sample: Map<String, dynamic>.from(decoded));
  }

  /// Envelope form is kept whenever any identity was recorded, so a partially
  /// attributed row stays distinguishable from a genuinely legacy one.
  String encode() =>
      (owner != null || origin != null)
          ? jsonEncode(toEnvelopeJson())
          : jsonEncode(sample);
}

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
/// * **Ownership:** every line is an envelope carrying the capturing guard and
///   API origin plus the sample. Only rows matching the dispatching guard and
///   origin are delivered; anything else is retained. See [TrackingSpoolEntry].
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
    final dir =
        directory ??
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

  /// Appends [sample] to the live spool, tagged with the guard ([owner]) and
  /// API origin that captured it. Safe to call from the background isolate; a
  /// single small append to an O_APPEND file is atomic.
  Future<void> add(
    Map<String, dynamic> sample, {
    String? owner,
    String? origin,
  }) async {
    final line =
        TrackingSpoolEntry(
          sample: sample,
          owner: owner,
          origin: origin,
        ).encode();
    await _liveFile.writeAsString(
      '$line\n',
      mode: FileMode.append,
      flush: true,
    );
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

  /// All buffered entries in oldest-first order, **without** draining. Values
  /// from the live spool plus any leftover drain file.
  Future<List<TrackingSpoolEntry>> pending() async {
    final samples = <TrackingSpoolEntry>[];
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
  Future<List<TrackingSpoolEntry>> readPending() async {
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
  ///
  /// Entries the current guard is not entitled to deliver stay in the spool
  /// rather than being dropped or reassigned to the active credentials.
  Future<void> commit(List<TrackingSpoolEntry> remaining) async {
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

  List<TrackingSpoolEntry> _cap(List<TrackingSpoolEntry> samples) {
    if (samples.length <= maxSamples) return samples;
    return samples.sublist(samples.length - maxSamples);
  }

  String _encodeLines(List<TrackingSpoolEntry> samples) {
    final buffer = StringBuffer();
    for (final sample in samples) {
      buffer.writeln(sample.encode());
    }
    return buffer.toString();
  }

  Future<List<TrackingSpoolEntry>> _readLines(File file) async {
    final String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      debugPrint('TrackingBuffer: could not read ${file.path}: $e');
      return const [];
    }
    final samples = <TrackingSpoolEntry>[];
    for (final line in content.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map) {
          final entry = TrackingSpoolEntry.fromLine(
            Map<String, dynamic>.from(decoded),
          );
          if (entry != null) samples.add(entry);
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
      return content.split('\n').where((line) => line.trim().isNotEmpty).length;
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
    final lines =
        (await live.readAsString())
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
