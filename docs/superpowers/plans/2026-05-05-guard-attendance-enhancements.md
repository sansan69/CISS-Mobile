# Guard Attendance Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate site selection based on location/district and add a searchable site picker for guards.

**Architecture:** 
- Add `_initLocationCheck` to `GuardAttendanceScreen` for automatic GPS capture.
- Implement distance calculation to auto-select the nearest site from the guard's district.
- Replace the site dropdown with a searchable modal picker for better usability.

**Tech Stack:** Flutter, Riverpod, Geolocator

---

### Task 1: District-Based Site Filtering

**Files:**
- Modify: `lib/features/guard/presentation/screens/guard_attendance_screen.dart`

- [ ] **Step 1: Filter sites by guard district**

Modify the `sitesAsync.when` data block to filter sites by `profile.district`.

```dart
// Inside sitesAsync.when data: (sites)
final filteredSites = sites.where((s) => s.district == profile.district).toList();
```

- [ ] **Step 2: Update the Site Dropdown to use filtered list**

Temporary update to the existing dropdown to verify filtering.

```dart
// Change 'sites' to 'filteredSites' in DropdownButtonFormField items
items: filteredSites.map((site) => ...).toList(),
```

- [ ] **Step 3: Verify filtering**

Run: `flutter test test/attendance_flow_verification_test.dart` (or manual run if no test exists)
Expected: Guard only sees sites from their own district.

- [ ] **Step 4: Commit**

```bash
git add lib/features/guard/presentation/screens/guard_attendance_screen.dart
git commit -m "feat: filter attendance sites by guard district"
```

---

### Task 2: Automatic Location Check & Nearest Site Selection

**Files:**
- Modify: `lib/features/guard/presentation/screens/guard_attendance_screen.dart`

- [ ] **Step 1: Implement `_findNearestSite` helper**

```dart
SiteOptionModel? _findNearestSite(Position position, List<SiteOptionModel> sites) {
  if (sites.isEmpty) return null;
  SiteOptionModel? nearest;
  double minDistance = double.infinity;

  for (final site in sites) {
    if (site.lat == null || site.lng == null) continue;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      site.lat!,
      site.lng!,
    );
    if (distance < minDistance) {
      minDistance = distance;
      nearest = site;
    }
  }
  return nearest;
}
```

- [ ] **Step 2: Implement `_initLocationCheck` and call in `initState`**

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initLocationCheck();
  });
}

Future<void> _initLocationCheck() async {
  await _captureLocation();
  if (_position != null) {
    final sites = ref.read(attendanceSitesProvider).valueOrNull ?? [];
    final profile = ref.read(guardProfileProvider).valueOrNull;
    if (profile != null) {
      final filtered = sites.where((s) => s.district == profile.district).toList();
      final nearest = _findNearestSite(_position!, filtered);
      if (nearest != null && mounted) {
        setState(() {
          _site = nearest;
          _dutyPoint = nearest.dutyPoints.isNotEmpty ? nearest.dutyPoints.first : null;
          _shift = _dutyPoint?.shiftTemplates.isNotEmpty == true ? _dutyPoint!.shiftTemplates.first : null;
        });
      }
    }
  }
}
```

- [ ] **Step 3: Verify auto-selection**

Run: `flutter run`
Expected: Location check triggers automatically on load. If successful, the nearest site in the district is selected.

- [ ] **Step 4: Commit**

```bash
git add lib/features/guard/presentation/screens/guard_attendance_screen.dart
git commit -m "feat: auto-capture location and select nearest site on load"
```

---

### Task 3: Searchable Site Picker UI

**Files:**
- Modify: `lib/features/guard/presentation/screens/guard_attendance_screen.dart`

- [ ] **Step 1: Implement `_showSitePicker` modal**

```dart
void _showSitePicker(List<SiteOptionModel> sites) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        // Implementation with Search Bar and filtered ListView
        // ... (standard search implementation)
      },
    ),
  );
}
```

- [ ] **Step 2: Replace Dropdown with Searchable Trigger**

```dart
// Replace DropdownButtonFormField with:
InkWell(
  onTap: () => _showSitePicker(filteredSites),
  child: IgnorePointer(
    child: TextFormField(
      controller: TextEditingController(text: _site?.siteName ?? ''),
      decoration: const InputDecoration(
        labelText: 'Site',
        suffixIcon: Icon(Icons.search_rounded),
      ),
    ),
  ),
),
```

- [ ] **Step 3: Verify search functionality**

Run: `flutter run`
Expected: Tapping Site opens a searchable list. Filtering by name works. Selection updates the main screen state.

- [ ] **Step 4: Commit**

```bash
git add lib/features/guard/presentation/screens/guard_attendance_screen.dart
git commit -m "feat: replace site dropdown with searchable picker"
```

---

### Task 4: Location Service Warning & Retry

**Files:**
- Modify: `lib/features/guard/presentation/screens/guard_attendance_screen.dart`

- [ ] **Step 1: Add high-contrast warning if location fails**

```dart
if (_error != null && _error!.contains('Location'))
  StateBlock(
    icon: Icons.location_off_rounded,
    title: 'Location Required',
    message: _error!,
    onRetry: _initLocationCheck,
  ),
```

- [ ] **Step 2: Verify warning UI**

Run: Disable GPS and open the app.
Expected: "Location Required" state block appears with a Retry button.

- [ ] **Step 3: Commit**

```bash
git add lib/features/guard/presentation/screens/guard_attendance_screen.dart
git commit -m "feat: add location warning and retry logic"
```
