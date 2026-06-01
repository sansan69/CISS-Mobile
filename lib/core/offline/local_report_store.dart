import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// A local copy of a submitted visit or training report, stored on-device
/// so the field officer can review past submissions even when offline.
class LocalReportCopy {
  const LocalReportCopy({
    required this.id,
    required this.type,
    required this.clientName,
    required this.siteName,
    required this.district,
    required this.dateLabel,
    required this.summary,
    required this.createdAt,
    this.syncedToServer = false,
    this.serverId,
    this.photoUrls = const <String>[],
    this.attachmentUrls = const <String>[],
  });

  final String id;
  final String type; // 'visit' | 'training'
  final String clientName;
  final String siteName;
  final String district;
  final String dateLabel;
  final String summary;
  final DateTime createdAt;
  final bool syncedToServer;
  final String? serverId;
  final List<String> photoUrls;
  final List<String> attachmentUrls;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'clientName': clientName,
    'siteName': siteName,
    'district': district,
    'dateLabel': dateLabel,
    'summary': summary,
    'createdAt': createdAt.toIso8601String(),
    'syncedToServer': syncedToServer,
    'serverId': serverId,
    'photoUrls': photoUrls,
    'attachmentUrls': attachmentUrls,
  };

  factory LocalReportCopy.fromJson(Map<String, dynamic> json) {
    return LocalReportCopy(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'visit',
      clientName: (json['clientName'] as String?) ?? '',
      siteName: (json['siteName'] as String?) ?? '',
      district: (json['district'] as String?) ?? '',
      dateLabel: (json['dateLabel'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      syncedToServer: json['syncedToServer'] == true,
      serverId: json['serverId'] as String?,
      photoUrls:
          (json['photoUrls'] as List<dynamic>?)?.whereType<String>().toList() ??
          const <String>[],
      attachmentUrls:
          (json['attachmentUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
    );
  }

  LocalReportCopy copyWith({
    bool? syncedToServer,
    String? serverId,
    List<String>? photoUrls,
    List<String>? attachmentUrls,
  }) {
    return LocalReportCopy(
      id: id,
      type: type,
      clientName: clientName,
      siteName: siteName,
      district: district,
      dateLabel: dateLabel,
      summary: summary,
      createdAt: createdAt,
      syncedToServer: syncedToServer ?? this.syncedToServer,
      serverId: serverId ?? this.serverId,
      photoUrls: photoUrls ?? this.photoUrls,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }

  /// Human-readable title for list display.
  String get title {
    if (type == 'visit') {
      return siteName.isNotEmpty ? siteName : 'Visit Report';
    }
    return summary.isNotEmpty ? summary : 'Training Report';
  }
}

/// Stores locally-submitted report copies in an encrypted Hive box.
class LocalReportStore {
  LocalReportStore(this._box);

  static const String boxName = 'local_reports';
  final Box<Map> _box;
  final _uuid = const Uuid();

  /// Save a local copy of a submitted report.
  Future<LocalReportCopy> saveCopy({
    required String type,
    required String clientName,
    required String siteName,
    required String district,
    required String dateLabel,
    required String summary,
    required List<String> photoUrls,
    List<String> attachmentUrls = const <String>[],
    bool syncedToServer = false,
    String? serverId,
    String? id,
  }) async {
    final copyId = id ?? _uuid.v4();
    final copy = LocalReportCopy(
      id: copyId,
      type: type,
      clientName: clientName,
      siteName: siteName,
      district: district,
      dateLabel: dateLabel,
      summary: summary,
      photoUrls: photoUrls,
      attachmentUrls: attachmentUrls,
      createdAt: DateTime.now(),
      syncedToServer: syncedToServer,
      serverId: serverId,
    );
    await _box.put(copyId, copy.toJson());
    return copy;
  }

  /// Mark a locally-queued report as synced (called after offline queue succeeds).
  Future<void> markSynced(
    String id, {
    String? serverId,
    List<String>? photoUrls,
    List<String>? attachmentUrls,
  }) async {
    final existing = _box.get(id);
    if (existing == null) return;
    final copy = LocalReportCopy.fromJson(Map<String, dynamic>.from(existing));
    await _box.put(
      id,
      copy
          .copyWith(
            syncedToServer: true,
            serverId: serverId,
            photoUrls: photoUrls,
            attachmentUrls: attachmentUrls,
          )
          .toJson(),
    );
  }

  /// Get all local report copies, newest first.
  List<LocalReportCopy> getAll() {
    return _box.values
        .map((e) => LocalReportCopy.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get local copies of a specific type.
  List<LocalReportCopy> getByType(String type) {
    return getAll().where((r) => r.type == type).toList();
  }

  /// Count unsynced reports.
  int get unsyncedCount => getAll().where((r) => !r.syncedToServer).length;

  Future<void> deleteCopy(String id) async {
    await _box.delete(id);
  }
}

final localReportStoreProvider = Provider<LocalReportStore>((ref) {
  final box = Hive.box<Map>(LocalReportStore.boxName);
  return LocalReportStore(box);
});
