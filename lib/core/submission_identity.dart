import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Keeps one server idempotency key for retries of the same user submission.
class SubmissionIdentity {
  SubmissionIdentity({String Function()? newId})
    : _newId = newId ?? const Uuid().v4;

  final String Function() _newId;
  String? _fingerprint;
  String? _id;
  final Map<String, Object?> _capturedValues = {};

  String forPayload(
    Map<String, dynamic> payload, {
    Set<String> ignoredKeys = const {},
  }) {
    final fingerprint = jsonEncode(
      _canonical({
        for (final entry in payload.entries)
          if (!ignoredKeys.contains(entry.key)) entry.key: entry.value,
      }),
    );
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _id = _newId();
      _capturedValues.clear();
    }
    return _id!;
  }

  T capture<T>(String key, T value) =>
      (_capturedValues.putIfAbsent(key, () => value) as T);

  T? readCapture<T>(String key) => _capturedValues[key] as T?;

  void complete() {
    _fingerprint = null;
    _id = null;
    _capturedValues.clear();
  }

  static Object? _canonical(Object? value) {
    if (value is List) return value.map(_canonical).toList();
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    return value;
  }
}
