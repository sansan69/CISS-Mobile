import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Keeps one retry identity for an unchanged leave submission.
class LeaveRequestIdentity {
  String? _payloadKey;
  String? _clientRequestId;

  String forPayload(Map<String, dynamic> payload) {
    final normalized = <String, dynamic>{
      for (final key in payload.keys.toList()..sort())
        if (key != 'clientRequestId') key: payload[key],
    };
    final payloadKey = jsonEncode(normalized);
    if (_payloadKey != payloadKey) {
      _payloadKey = payloadKey;
      _clientRequestId = const Uuid().v4();
    }
    return _clientRequestId!;
  }

  void reset() {
    _payloadKey = null;
    _clientRequestId = null;
  }
}
