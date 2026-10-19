import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/duty_models.dart';
import '../network/api_client.dart' show kApiRequestIdentityChanged;
import 'offline_queue.dart';

abstract interface class WillingnessStore {
  Future<List<Map<String, dynamic>>> read();
  Future<void> write(List<Map<String, dynamic>> rows);
}

/// Separate encrypted spool: willingness can never consume or evict attendance.
class HiveWillingnessStore implements WillingnessStore {
  Future<Box<dynamic>> _box() async {
    const name = 'duty_willingness_v1';
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(
      name,
      encryptionCipher: await OfflineQueue().getEncryptionCipher(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> read() async {
    final rows = (await _box()).get('rows') as List? ?? [];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<void> write(List<Map<String, dynamic>> rows) async =>
      (await _box()).put('rows', rows);
}

class WillingnessOperation {
  const WillingnessOperation({
    required this.id,
    required this.ownerUid,
    required this.apiBaseUrl,
    required this.workOrderId,
    required this.response,
    required this.expectedVersion,
    this.state = 'pending',
    this.attempted = false,
    this.reason,
    this.serverVersion,
    this.serverResponse,
    this.sequence = 0,
    this.createdAt,
    this.acknowledgedAt,
    this.retryCount = 0,
    this.nextAttemptAt,
  });
  final int sequence, retryCount;
  final DateTime? createdAt, acknowledgedAt, nextAttemptAt;
  final String id, ownerUid, apiBaseUrl, workOrderId, state;
  final WillingnessStatus response;
  final int expectedVersion;
  final bool attempted;
  final String? reason;
  final int? serverVersion;
  final WillingnessStatus? serverResponse;
  Map<String, dynamic> get body => {
    'response': response.name,
    'clientRequestId': id,
    'expectedVersion': expectedVersion,
  };
  Map<String, dynamic> toJson() => {
    ...body,
    'ownerUid': ownerUid,
    'apiBaseUrl': apiBaseUrl,
    'workOrderId': workOrderId,
    'state': state,
    'attempted': attempted,
    'reason': reason,
    'serverVersion': serverVersion,
    'serverResponse': serverResponse?.name,
    'sequence': sequence,
    'createdAt': createdAt?.toIso8601String(),
    'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    'retryCount': retryCount,
    'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    'conflictPolicy': 'latest-local-choice-with-server-cas',
  };
  factory WillingnessOperation.fromJson(
    Map<String, dynamic> json,
  ) => WillingnessOperation(
    sequence: json['sequence'] as int? ?? 0,
    retryCount: json['retryCount'] as int? ?? 0,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    acknowledgedAt: DateTime.tryParse(json['acknowledgedAt']?.toString() ?? ''),
    nextAttemptAt: DateTime.tryParse(json['nextAttemptAt']?.toString() ?? ''),
    id: json['clientRequestId'] as String,
    ownerUid: json['ownerUid'] as String,
    apiBaseUrl: json['apiBaseUrl'] as String,
    workOrderId: json['workOrderId'] as String,
    response: WillingnessStatus.values.byName(json['response'] as String),
    expectedVersion: json['expectedVersion'] as int,
    state: json['state'] as String? ?? 'pending',
    attempted: json['attempted'] == true,
    reason: json['reason'] as String?,
    serverVersion: json['serverVersion'] as int?,
    serverResponse:
        WillingnessStatus.values
            .where((e) => e.name == json['serverResponse'])
            .firstOrNull,
  );
  WillingnessOperation copy({
    int? sequence,
    int? retryCount,
    DateTime? acknowledgedAt,
    DateTime? nextAttemptAt,
    int? expectedVersion,
    String? state,
    bool? attempted,
    String? reason,
    int? serverVersion,
    WillingnessStatus? serverResponse,
  }) => WillingnessOperation(
    sequence: sequence ?? this.sequence,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
    acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    id: id,
    ownerUid: ownerUid,
    apiBaseUrl: apiBaseUrl,
    workOrderId: workOrderId,
    response: response,
    expectedVersion: expectedVersion ?? this.expectedVersion,
    state: state ?? this.state,
    attempted: attempted ?? this.attempted,
    reason: reason ?? this.reason,
    serverVersion: serverVersion ?? this.serverVersion,
    serverResponse: serverResponse ?? this.serverResponse,
  );
}

String willingnessOrigin(String value) =>
    value.replaceFirst(RegExp(r'/+$'), '');

class WillingnessQueue extends ChangeNotifier {
  WillingnessQueue(
    this.store, {
    DateTime Function()? now,
    double Function()? jitter,
  }) : _now = now ?? DateTime.now,
       _jitter = jitter ?? math.Random().nextDouble;
  final DateTime Function() _now;
  final double Function() _jitter;
  int _sequence = 0;
  final WillingnessStore store;
  final _rows = <WillingnessOperation>[];
  Future<void>? _loaded;
  Future<void> _writes = Future.value();
  bool _processing = false;
  static const capacity = 100;
  static const savedHistoryCapacity = 100;
  Future<void> load() => _loaded ??= _load();
  Future<void> _load() async {
    final rows = await store.read();
    for (final row in rows) {
      try {
        if (row['_kind'] == 'meta') {
          _sequence = math.max(_sequence, row['sequence'] as int? ?? 0);
          continue;
        }
        var op = WillingnessOperation.fromJson(row);
        if (op.sequence == 0) op = op.copy(sequence: ++_sequence);
        _sequence = math.max(_sequence, op.sequence);
        _rows.add(op);
      } catch (_) {
        /* Unowned/invalid rows never run. */
      }
    }
    notifyListeners();
  }

  Future<void> _change(void Function() action) {
    final next = _writes.then((_) async {
      // Roll back memory if the durable write fails; never claim pending saved.
      final before = List<WillingnessOperation>.of(_rows);
      final beforeSequence = _sequence;
      action();
      try {
        await store.write([
          ..._rows.map((e) => e.toJson()),
          {'_kind': 'meta', 'sequence': _sequence},
        ]);
      } catch (_) {
        _sequence = beforeSequence;
        _rows
          ..clear()
          ..addAll(before);
        rethrow;
      }
      notifyListeners();
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  List<WillingnessOperation> forOwner(String uid, String origin) => _rows
      .where(
        (e) => e.ownerUid == uid && e.apiBaseUrl == willingnessOrigin(origin),
      )
      .toList(growable: false);
  Future<WillingnessOperation> choose({
    required String ownerUid,
    required String apiBaseUrl,
    required String workOrderId,
    required WillingnessStatus response,
    required int expectedVersion,
  }) async {
    await load();
    if (ownerUid.isEmpty ||
        workOrderId.isEmpty ||
        expectedVersion < 0 ||
        !Uri.parse(apiBaseUrl).hasAuthority) {
      throw StateError(
        'A valid signed-in account and deployment are required.',
      );
    }
    var op = WillingnessOperation(
      id: const Uuid().v4(),
      ownerUid: ownerUid,
      apiBaseUrl: willingnessOrigin(apiBaseUrl),
      workOrderId: workOrderId,
      response: response,
      expectedVersion: expectedVersion,
      createdAt: _now(),
    );
    await _change(() {
      op = op.copy(sequence: ++_sequence);
      final same =
          _rows
              .where(
                (e) =>
                    e.ownerUid == op.ownerUid &&
                    e.apiBaseUrl == op.apiBaseUrl &&
                    e.workOrderId == op.workOrderId,
              )
              .toList();
      final acknowledged =
          same
              .where((e) => e.state == 'saved' && e.serverVersion != null)
              .lastOrNull;
      if (acknowledged != null &&
          acknowledged.serverVersion! > op.expectedVersion) {
        op = op.copy(expectedVersion: acknowledged.serverVersion);
      }
      final removable =
          same.where((e) => e.state != 'pending' || !e.attempted).toSet();
      final runnableAfterReplacement =
          _rows
              .where((e) => e.state == 'pending' && !removable.contains(e))
              .length;
      if (runnableAfterReplacement >= capacity) {
        throw StateError(
          'Response queue is full. Sync or review existing responses first.',
        );
      }
      _rows.removeWhere(removable.contains);
      _rows.add(op);
    });
    return op;
  }

  Future<void> process({
    required String? Function() owner,
    required String Function() origin,
    required Future<WillingnessReceipt> Function(WillingnessOperation) send,
  }) async {
    await load();
    if (_processing) return;
    _processing = true;
    final blocked = <String>{};
    try {
      while (true) {
        final pending =
            forOwner(owner() ?? '', origin())
                .where(
                  (e) =>
                      e.state == 'pending' && !blocked.contains(e.workOrderId),
                )
                .toList();
        if (pending.isEmpty) break;
        var op = pending.first;
        if (op.nextAttemptAt?.isAfter(_now()) ?? false) {
          blocked.add(op.workOrderId);
          continue;
        }
        await _change(() {
          final i = _rows.indexWhere((e) => e.id == op.id);
          if (i >= 0) {
            op = _rows[i].copy(attempted: true);
            _rows[i] = op;
          }
        });
        // A queued snapshot may have been coalesced while storage awaited.
        if (!_rows.any((e) => e.id == op.id) ||
            owner() != op.ownerUid ||
            willingnessOrigin(origin()) != op.apiBaseUrl) {
          continue;
        }
        try {
          final receipt = await send(op);
          await _change(() {
            final i = _rows.indexWhere((e) => e.id == op.id);
            if (i < 0) return;
            final successors =
                _rows
                    .where(
                      (e) =>
                          e.id != op.id &&
                          e.ownerUid == op.ownerUid &&
                          e.apiBaseUrl == op.apiBaseUrl &&
                          e.workOrderId == op.workOrderId &&
                          e.state == 'pending',
                    )
                    .toList();
            if (successors.isEmpty) {
              _rows[i] = op.copy(
                state: 'saved',
                acknowledgedAt: _now(),
                serverVersion: receipt.version,
              );
              final saved = _rows.where((e) => e.state == 'saved').toList();
              if (saved.length > savedHistoryCapacity) {
                final retired =
                    saved
                        .take(saved.length - savedHistoryCapacity)
                        .map((e) => e.id)
                        .toSet();
                _rows.removeWhere((e) => retired.contains(e.id));
              }
            } else {
              _rows.removeAt(i);
              for (final successor in successors) {
                if (!successor.attempted) {
                  final j = _rows.indexWhere((e) => e.id == successor.id);
                  _rows[j] = successor.copy(expectedVersion: receipt.version);
                }
              }
            }
          });
        } catch (error) {
          final status =
              error is DioException ? error.response?.statusCode : null;
          final terminal =
              status != null &&
              status >= 400 &&
              status < 500 &&
              status != 401 &&
              status != 408 &&
              status != 429;
          final data = error is DioException ? error.response?.data : null;
          final current =
              data is Map && data['willingness'] is Map
                  ? data['willingness'] as Map
                  : null;
          final serverResponse =
              WillingnessStatus.values
                  .where((e) => e.name == current?['response'])
                  .firstOrNull;
          final serverVersion =
              current?['version'] is int ? current!['version'] as int : null;
          final reason =
              error is DioException &&
                      error.message == kApiRequestIdentityChanged
                  ? 'Your account or deployment changed. This response remains pending and is safe to retry.'
                  : data is Map
                  ? data['error']?.toString() ??
                      'Response rejected. Refresh duty details.'
                  : 'Waiting for connection. Your response is not saved yet.';
          await _change(() {
            for (var i = 0; i < _rows.length; i++) {
              final row = _rows[i];
              if (row.ownerUid == op.ownerUid &&
                  row.apiBaseUrl == op.apiBaseUrl &&
                  row.workOrderId == op.workOrderId &&
                  row.state == 'pending') {
                _rows[i] = row.copy(
                  state: terminal ? 'rejected' : 'pending',
                  retryCount: row.retryCount + 1,
                  nextAttemptAt: _now().add(
                    Duration(
                      milliseconds:
                          (1000 *
                                  math.min(
                                    300,
                                    math.pow(
                                      2,
                                      math.min(row.retryCount + 1, 9),
                                    ),
                                  ) *
                                  (0.5 + _jitter().clamp(0, 1)))
                              .round(),
                    ),
                  ),
                  reason: reason,
                  serverVersion: serverVersion,
                  serverResponse: serverResponse,
                );
              }
            }
          });
          blocked.add(op.workOrderId);
        }
      }
    } finally {
      _processing = false;
    }
  }
}
