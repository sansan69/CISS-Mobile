# Design Spec: Guard Attendance Location & Site Selection

**Date:** 2026-05-05
**Topic:** Guard Attendance location services and automated site selection

## 1. Overview
Enhance the Guard Attendance flow to automate site selection based on the guard's current GPS location and district. The system will ensure location services are enabled, filter sites by the guard's district, and automatically select the nearest site.

## 2. Architecture & Logic

### 2.1. Initial Location Capture
- **Trigger:** Automatic execution in `initState` of `GuardAttendanceScreen`.
- **Validation:** 
    - Check if location services are enabled.
    - Check/Request location permissions.
    - If disabled/denied, show a high-contrast prompt in the UI with a "Retry" action.

### 2.2. District Filtering
- The list of available sites will be strictly filtered by the `GuardProfileModel.district`.
- Guards from "Ernakulam" will only see and be able to select sites where `SiteOptionModel.district == "Ernakulam"`.

### 2.3. Nearest Site Auto-Selection
- **Calculation:** Use `Geolocator.distanceBetween(guardLat, guardLng, siteLat, siteLng)`.
- **Logic:** 
    - Iterate through all sites in the filtered district list.
    - Identify the site with the minimum distance.
    - Automatically update the `_site` state variable and trigger cascading updates for Duty Points and Shifts.

## 3. UI/UX Components

### 3.1. Searchable Site Selection
- Replace the current `DropdownButtonFormField` for Site Selection.
- **Trigger Field:** A read-only `TextFormField` showing the current selection or a "Search & Select Site" placeholder.
- **Search Modal:** Tapping the trigger opens a full-screen or bottom-sheet modal.
    - **Header:** Title and Close button.
    - **Search Bar:** Real-time text filtering of sites by name.
    - **List:** Displays sites (Site Name + District). The auto-selected site is clearly marked.

### 3.2. Location Status Feedback
- **Active:** Show "GPS Captured" with coordinates.
- **Disabled/Pending:** Show a descriptive block with a prominent "Enable Location" button if the automatic check fails.

## 4. Implementation Details

### 4.1. Key Methods in `GuardAttendanceScreen`
- `_initLocationCheck()`: Orchestrates the automatic flow.
- `_findNearestSite(Position position, List<SiteOptionModel> sites)`: Helper to calculate and select.
- `_showSitePicker()`: Opens the searchable selection UI.

### 4.2. Distance Calculation
```dart
double distance = Geolocator.distanceBetween(
  position.latitude,
  position.longitude,
  site.lat!,
  site.lng!,
);
```

## 5. Success Criteria
1. Opening the attendance tab automatically prompts for/checks location.
2. Sites are filtered by the guard's district.
3. The nearest site is pre-selected if coordinates are available.
4. Guards can manually search and select from the filtered list of sites.
