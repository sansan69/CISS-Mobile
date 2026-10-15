import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the selected top-level menu in [FieldOfficerShell].
/// Dashboard quick-action buttons and notifications write to this provider.
final fieldOfficerTabIndexProvider = StateProvider<int>((ref) => 0);

const fieldOfficerHomeTabIndex = 0;
const fieldOfficerAttendanceTabIndex = 1;
const fieldOfficerEmployeesTabIndex = 2;
const fieldOfficerDutiesTabIndex = 3;
const fieldOfficerMoreTabIndex = 4;
const fieldOfficerReportsTabIndex = 5;
const fieldOfficerTabCount = 6;

/// Reports is opened from More and notifications, while More remains the
/// selected item in the five-button navigation bar.
int fieldOfficerVisibleTabIndex(int tabIndex) =>
    tabIndex == fieldOfficerReportsTabIndex
        ? fieldOfficerMoreTabIndex
        : tabIndex;
