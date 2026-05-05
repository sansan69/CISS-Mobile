# Encrypted Initialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update `ThemeModeController` and `main.dart` to use encrypted Hive boxes.

**Architecture:** Initialize `ProviderContainer` early in `main.dart` to retrieve the encryption cipher from `OfflineQueue`, then use it to open all Hive boxes.

**Tech Stack:** Flutter, Riverpod, Hive, Flutter Secure Storage

---

### Task 1: Update ThemeModeController

**Files:**
- Modify: `lib/app/theme/theme_mode_controller.dart`

- [ ] **Step 1: Add init method and rename provider**
Add the `init` method to `ThemeModeController` class and rename `themeModeProvider` to `themeModeControllerProvider`.

```dart
  Future<void> init(HiveAesCipher? cipher) async {
    await Hive.openBox(boxName, encryptionCipher: cipher);
    state = _readInitialMode();
  }
```

- [ ] **Step 2: Update usages of themeModeProvider**
Update `lib/app/app.dart` and `lib/shared/widgets/theme_mode_selector.dart`.

### Task 2: Update main.dart Initialization

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update Hive initialization logic**
Move `ProviderContainer` creation earlier and use it to get the cipher and initialize boxes.

```dart
  final container = ProviderContainer();
  final queue = container.read(offlineQueueProvider);
  final cipher = await queue.getEncryptionCipher();
  
  await Hive.initFlutter();
  await Hive.openBox<Map>(OfflineQueue.boxName, encryptionCipher: cipher);
  await container.read(themeModeControllerProvider.notifier).init(cipher);
```

### Task 3: Verification

- [ ] **Step 1: Run flutter analyze**
Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 2: Commit changes**
Commit message: "feat: enable encrypted Hive boxes on startup"
