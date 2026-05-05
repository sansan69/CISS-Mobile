# Secure Storage Key Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update `OfflineQueue` to handle encryption keys using `flutter_secure_storage` for Hive box encryption.

**Architecture:** Use `flutter_secure_storage` to persist a 256-bit Hive encryption key. On initialization, check if a key exists; if not, generate a new one and store it. Use this key to open the `offline_queue` Hive box with `HiveAesCipher`.

**Tech Stack:** Flutter, Hive, flutter_secure_storage, uuid.

---

### Task 1: Update OfflineQueue with Secure Storage

**Files:**
- Modify: `lib/core/offline/offline_queue.dart`

- [ ] **Step 1: Add imports and class members**

Add `dart:convert` and `package:flutter_secure_storage/flutter_secure_storage.dart`.
Add `_keyName` and `_secureStorage` constants/members.

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'offline_request.dart';

class OfflineQueue extends ChangeNotifier {
  static const String boxName = 'offline_queue';
  static const String _keyName = 'hive_encryption_key';
  final _uuid = const Uuid();
  final _secureStorage = const FlutterSecureStorage();
  
  // ...
```

- [ ] **Step 2: Implement getEncryptionCipher**

```dart
  Future<HiveAesCipher?> getEncryptionCipher() async {
    String? key = await _secureStorage.read(key: _keyName);
    if (key == null) {
      final newKey = Hive.generateSecureKey();
      await _secureStorage.write(key: _keyName, value: base64UrlEncode(newKey));
      return HiveAesCipher(newKey);
    }
    return HiveAesCipher(base64Url.decode(key));
  }
```

- [ ] **Step 3: Update init to use encryption**

```dart
  Future<void> init() async {
    final cipher = await getEncryptionCipher();
    await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
  }
```

- [ ] **Step 4: Verify syntax**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit changes**

Run: `git add lib/core/offline/offline_queue.dart && git commit -m "feat: add secure key management for Hive encryption"`
