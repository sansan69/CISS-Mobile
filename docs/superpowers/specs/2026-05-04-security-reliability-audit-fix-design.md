# Design: Security & Reliability Audit Fixes (Approach 1)

**Date:** 2026-05-04  
**Topic:** Audit remediation for background tracking and local storage.  
**Approach:** Approach 1 (Independent Fortress)

## 1. Overview
This design addresses critical security and reliability issues identified during the system audit. The goal is to ensure background tracking is authenticated and resilient, and that local offline data is encrypted and protected.

## 2. Architecture: Independent Background Authentication

### Problem
The `BackgroundTrackingService` currently sends location heartbeats without an `Authorization` header, making it vulnerable to spoofing. Furthermore, the background isolate lacks access to the main app's authentication state.

### Solution
Initialize an independent Firebase instance within the background service isolate to handle its own token management.

- **Initialization:** Call `Firebase.initializeApp` within the `onStart` entry point of the background service.
- **Token Retrieval:** Use `FirebaseAuth.instance.currentUser?.getIdToken(false)` before every heartbeat request.
- **Request Format:** Update the heartbeat `http.post` call to include a `Bearer` token in the `Authorization` header.

## 3. Storage: Hardware-Backed Encrypted Hive Boxes

### Problem
The `OfflineQueue` stores sensitive data (base64 photo strings, employee IDs) in plain-text Hive boxes, which are accessible on a compromised device.

### Solution
Use AES encryption for Hive boxes, with the key stored securely in the device's hardware-backed storage.

- **Key Management:** 
  - Use `flutter_secure_storage` to check for an existing encryption key.
  - If no key exists, generate a 256-bit key using `Hive.generateSecureKey()`.
  - Store the key in `flutter_secure_storage`.
- **Box Configuration:** 
  - Update `main.dart` and `OfflineQueue.init()` to open the `offline_queue` box using `HiveAesCipher`.
  - Apply the same encryption to the `ThemeModeController` box for consistency.

## 4. Reliability: Hardened Permission and Sync Logic

### Problem
Production runs can be hindered by accidental permission revocation or incomplete offline synchronization.

### Solution
- **Permission Watcher:** Implement a check in `AuthGate` and during background execution to detect missing `POST_NOTIFICATIONS` or `LOCATION` permissions.
- **Sync Cleanup:** Modify `SyncService` to purge heavy base64 data from the local `OfflineRequest` objects immediately after a successful backend submission.
- **Method Support:** Ensure `SyncService` and `MobileRepository` correctly handle `PATCH` and `PUT` methods for all offline actions.

## 5. Success Criteria
- [ ] Background heartbeats include a valid Firebase ID token in the headers.
- [ ] `offline_queue` Hive file is unreadable by plain-text viewers.
- [ ] App remains functional and syncs correctly after a simulated network outage.
- [ ] No hard crashes occur if permissions are revoked during background execution.
