import 'dart:convert';

import 'package:http/http.dart' as http;

/// Best-effort public IP hint (the server remains authoritative).
///
/// Returns the detected IP string, or null on any failure or parse error.
/// Never throws — callers treat this as a purely optional hint.
Future<String?> fetchPublicIp([http.Client? client]) async {
  try {
    final c = client ?? http.Client();
    final res = await c
        .get(Uri.parse('https://api.ipify.org?format=json'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    final ip = body is Map ? body['ip'] : null;
    return ip is String && ip.isNotEmpty ? ip : null;
  } catch (_) {
    return null;
  }
}
