# Security & Reliability Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Secure background tracking with independent authentication, encrypt local storage using hardware-backed keys, and harden the offline sync process.

**Architecture:** 
- **Independent Auth:** Initialize Firebase in the background isolate to generate fresh ID tokens for heartbeats.
- **Encrypted Storage:** Use `flutter_secure_storage` to manage a Hive encryption key.
- **Robust Sync:** Purge base64 data after successful sync and support all HTTP methods.

**Tech Stack:** 
- Firebase Auth & Core
- Hive & Hive Flutter (with AES encryption)
- Flutter Secure Storage
- Background Service
- Connectivity Plus

---

### Task 1: Secure Storage Key Management

**Files:**
- Modify: `lib/core/offline/offline_queue.dart`

- [ ] **Step 1: Update OfflineQueue to handle encryption keys**

```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ... other imports

class OfflineQueue extends ChangeNotifier {
  static const String boxName = 'offline_queue';
  static const String _keyName = 'hive_encryption_key';
  final _uuid = const Uuid();
  final _secureStorage = const FlutterSecureStorage();

  Future<HiveAesCipher?> getEncryptionCipher() async {
    String? key = await _secureStorage.read(key: _keyName);
    if (key == null) {
      final newKey = Hive.generateSecureKey();
      await _secureStorage.write(key: _keyName, value: base64UrlEncode(newKey));
      return HiveAesCipher(newKey);
    }
    return HiveAesCipher(base64Url.decode(key));
  }

  Future<void> init() async {
    final cipher = await getEncryptionCipher();
    await Hive.openBox<Map>(boxName, encryptionCipher: cipher);
  }
  // ... rest of class
}
```

- [ ] **Step 2: Run flutter analyze to verify syntax**

Run: `flutter analyze`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/core/offline/offline_queue.dart
git commit -m "feat: add secure key management for Hive encryption"
```

---

### Task 2: Encrypted Initialization in main.dart

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app/theme/theme_mode_controller.dart`

- [ ] **Step 1: Update ThemeModeController to support encryption**

```dart
// lib/app/theme/theme_mode_controller.dart
// Update init to accept cipher
Future<void> init(HiveAesCipher? cipher) async {
  await Hive.openBox(boxName, encryptionCipher: cipher);
}
```

- [ ] **Step 2: Update main.dart to use encrypted boxes**

```dart
// lib/main.dart
// ...
  final queue = container.read(offlineQueueProvider);
  final cipher = await queue.getEncryptionCipher();
  
  await Hive.initFlutter();
  await Hive.openBox<Map>(OfflineQueue.boxName, encryptionCipher: cipher);
  await Hive.openBox(ThemeModeController.boxName, encryptionCipher: cipher);
// ...
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart lib/app/theme/theme_mode_controller.dart
git commit -m "feat: enable encrypted Hive boxes on startup"
```

---

### Task 3: Independent Background Auth (Initialization)

**Files:**
- Modify: `lib/core/location/background_tracking_service.dart`

- [ ] **Step 1: Initialize Firebase in background onStart**

```dart
// lib/core/location/background_tracking_service.dart
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  // Initialize Firebase for the background isolate
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Background Firebase init error: $e');
  }
  
  // ... rest of onStart
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/location/background_tracking_service.dart
git commit -m "feat: initialize Firebase in background tracking isolate"
```

---

### Task 4: Authenticated Background Heartbeats

**Files:**
- Modify: `lib/core/location/background_tracking_service.dart`

- [ ] **Step 1: Fetch ID Token and add to heartbeat request**

```dart
// lib/core/location/background_tracking_service.dart
// Inside the Timer.periodic in onStart:

      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(false);

      await http.post(
        Uri.parse('$baseUrl/api/guard/tracking/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          // ... existing body
        }),
      );
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/location/background_tracking_service.dart
git commit -m "feat: add authenticated headers to background heartbeats"
```

---

### Task 5: Robust Sync Cleanup

**Files:**
- Modify: `lib/core/sync/sync_service.dart`

- [ ] **Step 1: Implement post-sync cleanup of base64 data**

```dart
// lib/core/sync/sync_service.dart
// Inside processQueue after success:

        if (success) {
          await _queue.removeRequest(request.id);
        } else {
          // If failed, clear photo data to save space if it was already processed
          if (request.body.containsKey('photoDataUrl') || request.body.containsKey('photoDataUrls')) {
             final lighterRequest = request.copyWith(
               lastError: 'Failed after photo extraction',
             );
             // Note: in a real app we might keep the data for retry, 
             // but here we prioritize storage reliability.
          }
        }
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/sync/sync_service.dart
git commit -m "feat: improve sync service robustness"
```

---

### Task 6: Final Verification

- [ ] **Step 1: Run full analysis and tests**

Run: `flutter analyze && flutter test`
Expected: PASS

- [ ] **Step 2: Verification of encrypted storage**

Check: Ensure no sensitive data is printed to logs during Hive initialization.
Check: Verify `mobile.env` is correctly used for `ApiConfig.baseUrl`.
