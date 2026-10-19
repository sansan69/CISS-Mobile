import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'offline_request.dart';

class OfflineQueueIdentity {
  const OfflineQueueIdentity({required this.ownerUid, required this.origin});
  final String? ownerUid;
  final String origin;
}

String _normalizedOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasAuthority) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
  return '${uri.scheme.toLowerCase()}://${uri.authority.toLowerCase()}';
}

String _streamKey({
  required String path,
  required Map<String, dynamic> body,
  required String? ownerUid,
  required bool publicProof,
}) {
  if (publicProof) {
    final employee = body['employeeId'] ?? body['employeeDocId'] ?? '';
    return 'public:${body['attendanceSessionId'] ?? employee}';
  }
  if (ownerUid != null &&
      (path == '/api/attendance/submit' ||
          path == '/api/mobile/attendance/break')) {
    // Attendance and break actions mutate one employee-wide server session.
    // Keep them ordered together across sites and endpoint paths.
    return 'guard-attendance:$ownerUid';
  }
  final causalId =
      body['requestId'] ?? body['workOrderId'] ?? body['attendanceSessionId'];
  return 'owner:${ownerUid ?? ''}:$path:${causalId ?? ''}';
}

class OfflineQueue extends ChangeNotifier {
  static const String boxName = 'offline_queue';
  static const String _keyName = 'hive_encryption_key';
  static const _metaName = 'offline_queue_meta';
  Future<void> _writes = Future.value();
  final _uuid = const Uuid();
  final _secureStorage = const FlutterSecureStorage();
  Future<OfflineQueueIdentity> Function()? _identityProvider;

  void bindIdentity(Future<OfflineQueueIdentity> Function() provider) {
    _identityProvider = provider;
  }

  Future<HiveAesCipher?> getEncryptionCipher() async {
    try {
      String? key = await _secureStorage.read(key: _keyName);
      if (key == null) {
        final newKey = Hive.generateSecureKey();
        await _secureStorage.write(
          key: _keyName,
          value: base64UrlEncode(newKey),
        );
        return HiveAesCipher(newKey);
      }
      return HiveAesCipher(base64Url.decode(key));
    } catch (e) {
      debugPrint(
        'Encryption cipher error — queue will operate unencrypted: $e',
      );
      return null;
    }
  }

  Future<void> init() async {
    final cipher = await getEncryptionCipher();
    await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
    await Hive.openBox<dynamic>(_metaName, encryptionCipher: cipher);
    // One-time migration in insertion order, even when legacy timestamps tie.
    var sequence = (_meta.get('sequence') as int?) ?? 0;
    for (final key in _box.keys.toList()) {
      try {
        final row = Map<String, dynamic>.from(_box.get(key)!);
        final existing = row['sequence'] is int ? row['sequence'] as int : 0;
        if (existing > sequence) sequence = existing;
        if (row['streamKey'] == null) {
          row['state'] = 'quarantined';
          row['lastError'] = 'legacy_identity_missing';
          row['streamKey'] = 'legacy:$key';
          await _box.put(key, row);
        }
        if (existing == 0) {
          row['sequence'] = ++sequence;
          await _box.put(key, row);
        }
      } catch (_) {
        debugPrint(
          'OfflineQueue: unreadable legacy row retained for recovery.',
        );
      }
    }
    await _meta.put('sequence', sequence);
  }

  Box<Map> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('OfflineQueue not initialized. Call init() first.');
    }
    return Hive.box<Map>(boxName);
  }

  /// Whether the persistent queue has been opened by app bootstrap.
  ///
  /// Widgets can be built while startup is still recovering from a storage
  /// or encryption error. Reading the queue count must not crash the whole
  /// screen in that window; mutating operations still fail loudly until the
  /// queue is initialized.
  bool get isInitialized => Hive.isBoxOpen(boxName);

  Box<dynamic> get _meta => Hive.box<dynamic>(_metaName);
  int get pendingCount =>
      isInitialized
          ? getQueuedRequests().where((r) => r.state == 'pending').length
          : 0;
  int get rejectedCount =>
      isInitialized
          ? getQueuedRequests().where((r) => r.state == 'rejected').length
          : 0;
  DateTime? get oldestPending =>
      isInitialized
          ? getQueuedRequests()
              .where((r) => r.state == 'pending')
              .firstOrNull
              ?.createdAt
          : null;
  DateTime? get lastAcknowledgedAt =>
      Hive.isBoxOpen(_metaName)
          ? DateTime.tryParse(_meta.get('lastAck')?.toString() ?? '')
          : null;
  String? get lastFailureReason =>
      Hive.isBoxOpen(_metaName) ? _meta.get('lastFailure') as String? : null;
  Future<void> acknowledge(String id, DateTime at) async {
    // Retire before storing health metadata; stable request IDs make replay safe.
    await removeRequest(id);
    await _meta.put('lastAck', at.toIso8601String());
    notifyListeners();
  }

  int get queueSize => isInitialized ? _box.length : 0;

  static const int maxQueueSize = 100;

  Future<void> enqueue({
    required String path,
    required String method,
    required Map<String, dynamic> body,
  }) {
    // Capture the owner/deployment at the call site; serializing durable writes
    // must not rebind an earlier request after a later account switch.
    final identityFuture = _identityProvider?.call();
    final next = _writes.then((_) async {
      if (_box.length >= maxQueueSize) {
        throw StateError(
          'Sync queue is full. Connect and sync before recording more.',
        );
      }
      final id = _uuid.v4();
      final identity = await identityFuture;
      final publicProof =
          path == '/api/attendance/submit' &&
          body['attendanceVerificationToken'] is String &&
          (body['attendanceVerificationToken'] as String).trim().isNotEmpty;
      final sequence = ((_meta.get('sequence') as int?) ?? 0) + 1;
      await _meta.put('sequence', sequence);
      final request = OfflineRequest(
        id: id,
        path: path,
        method: method,
        body: {
          ...body,
          if (path == '/api/attendance/submit' &&
              body['clientRequestId'] == null)
            'clientRequestId': id,
        },
        ownerUid: publicProof ? null : identity?.ownerUid,
        origin: identity == null ? null : _normalizedOrigin(identity.origin),
        streamKey: _streamKey(
          path: path,
          body: body,
          ownerUid: publicProof ? null : identity?.ownerUid,
          publicProof: publicProof,
        ),
        state:
            identity == null || (!publicProof && identity.ownerUid == null)
                ? 'quarantined'
                : 'pending',
        lastError:
            identity == null || (!publicProof && identity.ownerUid == null)
                ? 'identity_unavailable_at_enqueue'
                : null,
        createdAt: DateTime.now(),
        sequence: sequence,
      );
      await _box.put(id, request.toJson());
      notifyListeners();
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  List<OfflineRequest> getQueuedRequests() {
    final requests = <OfflineRequest>[];
    for (final entry in _box.values) {
      try {
        final map = Map<String, dynamic>.from(entry);
        requests.add(OfflineRequest.fromJson(map));
      } catch (e) {
        debugPrint('Skipping corrupted offline queue entry: $e');
      }
    }
    requests.sort((a, b) => a.sequence.compareTo(b.sequence));
    return requests;
  }

  Future<void> removeRequest(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  Future<void> updateRequest(OfflineRequest request) async {
    await _box.put(request.id, request.toJson());
    if (request.lastError != null) {
      await _meta.put('lastFailure', request.lastError);
    }
    notifyListeners();
  }

  Future<void> clear() async {
    await _box.clear();
    notifyListeners();
  }
}
