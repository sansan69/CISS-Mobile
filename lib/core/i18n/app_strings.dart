import 'package:flutter/widgets.dart';

import 'app_language.dart';

/// Interface strings for the guard and field-officer portals.
///
/// English values are identical to the shipped wording, so screens keep their
/// current copy whenever no language scope is present (widget tests, previews).
class AppStrings {
  const AppStrings._(this._values);

  final Map<String, String> _values;

  static const AppStrings english = AppStrings._(_en);

  static AppStrings forLanguage(AppLanguage language) => switch (language) {
    AppLanguage.english => english,
    AppLanguage.hindi => const AppStrings._(_hi),
    AppLanguage.malayalam => const AppStrings._(_ml),
  };

  /// Falls back to English when a screen is rendered without a language scope.
  static AppStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStringsScope>()?.strings ??
      english;

  String get navHome => _values['navHome']!;
  String get navAttendance => _values['navAttendance']!;
  String get navEmployees => _values['navEmployees']!;
  String get navDuties => _values['navDuties']!;
  String get navMore => _values['navMore']!;
  String get navDuty => _values['navDuty']!;
  String get navActivity => _values['navActivity']!;
  String get navProfile => _values['navProfile']!;
  String get language => _values['language']!;
  String get languageSubtitle => _values['languageSubtitle']!;
  String get trackingHealth => _values['trackingHealth']!;
  String get trackingHealthSubtitle => _values['trackingHealthSubtitle']!;
  String get ok => _values['ok']!;
  String get actionNeeded => _values['actionNeeded']!;
  String get fix => _values['fix']!;
  String get check => _values['check']!;
  String get backgroundLocation => _values['backgroundLocation']!;
  String get batteryUnrestricted => _values['batteryUnrestricted']!;
  String get notificationsAllowed => _values['notificationsAllowed']!;
  String get trackingRunning => _values['trackingRunning']!;
  String get trackingRunningYes => _values['trackingRunningYes']!;
  String get trackingRunningNo => _values['trackingRunningNo']!;
  String get readinessTitle => _values['readinessTitle']!;
  String get readinessSubtitle => _values['readinessSubtitle']!;
  String get readinessAllGood => _values['readinessAllGood']!;
  String get readinessLater => _values['readinessLater']!;
  String get readinessOpenSettings => _values['readinessOpenSettings']!;
  String get readinessRecheck => _values['readinessRecheck']!;
  String get readinessNotifications => _values['readinessNotifications']!;
  String get readinessLocationItem => _values['readinessLocationItem']!;
  String get readinessBackgroundItem => _values['readinessBackgroundItem']!;
  String get readinessCameraItem => _values['readinessCameraItem']!;
  String get readinessActivityItem => _values['readinessActivityItem']!;
  String get readinessAutostart => _values['readinessAutostart']!;
  String get readinessAutostartWhy => _values['readinessAutostartWhy']!;
  String get readinessOpenAutostart => _values['readinessOpenAutostart']!;
  String get readinessNotificationsWhy => _values['readinessNotificationsWhy']!;
  String get readinessLocationWhy => _values['readinessLocationWhy']!;
  String get readinessBackgroundLocationWhy =>
      _values['readinessBackgroundLocationWhy']!;
  String get readinessCameraWhy => _values['readinessCameraWhy']!;
  String get readinessActivityWhy => _values['readinessActivityWhy']!;
  String get readinessBatteryWhy => _values['readinessBatteryWhy']!;
  String get readinessBannerTitle => _values['readinessBannerTitle']!;
  String get readinessBannerBody => _values['readinessBannerBody']!;
  String get readinessStateGranted => _values['readinessStateGranted']!;
  String get readinessStateDenied => _values['readinessStateDenied']!;
  String get readinessStateBlocked => _values['readinessStateBlocked']!;
  String get readinessStateNotAsked => _values['readinessStateNotAsked']!;
  String get readinessStateNotNeeded => _values['readinessStateNotNeeded']!;
  String get readinessStateUnknown => _values['readinessStateUnknown']!;
  String get readinessAllow => _values['readinessAllow']!;
  String get readinessOpenBatterySettings =>
      _values['readinessOpenBatterySettings']!;
  String get readinessContinue => _values['readinessContinue']!;
  String get readinessGrantRemaining => _values['readinessGrantRemaining']!;
  String get readinessProgress => _values['readinessProgress']!;
  String get readinessTwoStepNote => _values['readinessTwoStepNote']!;
  String get readinessLaterHint => _values['readinessLaterHint']!;
  String get readinessChecking => _values['readinessChecking']!;
  String get readinessOpenScreen => _values['readinessOpenScreen']!;
  String get readinessOemTitle => _values['readinessOemTitle']!;
  String get readinessOemBody => _values['readinessOemBody']!;
  String get readinessOemOpenSettings =>
      _values['readinessOemOpenSettings']!;
  String get readinessOemStepSelect => _values['readinessOemStepSelect']!;
  String get readinessOemStepUnrestrict =>
      _values['readinessOemStepUnrestrict']!;
  String get readinessOemStepVerify => _values['readinessOemStepVerify']!;
  String get attendanceOnDuty => _values['attendanceOnDuty']!;
  String get attendanceCheckedOut => _values['attendanceCheckedOut']!;
  String get attendanceCheckOutMissing => _values['attendanceCheckOutMissing']!;
  String get attendanceDuplicateCheckIn =>
      _values['attendanceDuplicateCheckIn']!;
  String get attendanceSince => _values['attendanceSince']!;
  String get attendanceSinceYesterday => _values['attendanceSinceYesterday']!;
  String get attendanceReviewNotice => _values['attendanceReviewNotice']!;
  String get attendanceReviewNoticeHint =>
      _values['attendanceReviewNoticeHint']!;
  String get attendanceCarriedOver => _values['attendanceCarriedOver']!;
  String get attendanceCheckInLabel => _values['attendanceCheckInLabel']!;
  String get attendanceCheckOutLabel => _values['attendanceCheckOutLabel']!;
  String get attendanceNotRecorded => _values['attendanceNotRecorded']!;
  String get dutyCloseShiftHint => _values['dutyCloseShiftHint']!;
  String get navigate => _values['navigate']!;
  String get navigateUnavailable => _values['navigateUnavailable']!;
  String get policyUnavailableTitle => _values['policyUnavailableTitle']!;
  String get policyUnavailableBody => _values['policyUnavailableBody']!;
  String get policyOpenInBrowser => _values['policyOpenInBrowser']!;
  String get deviceThisDevice => _values['deviceThisDevice']!;
  String get deviceIdUnavailable => _values['deviceIdUnavailable']!;
  String get timelineHistoryUnavailable =>
      _values['timelineHistoryUnavailable']!;

  /// Resolves a string by key. The OEM guide owns a brand-to-key table, so it
  /// carries keys rather than one getter per manufacturer; a missing key
  /// renders empty instead of throwing, and `test/oem_autostart_test.dart`
  /// keeps every shipped key present in all three languages.
  String label(String key) => _values[key] ?? '';

  /// Fills `{name}` placeholders. Unknown placeholders are kept so a missing
  /// value shows up in review rather than silently deleting the sentence.
  String fill(String template, Map<String, Object> values) =>
      template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
        final value = values[match.group(1)];
        return value == null ? match.group(0)! : '$value';
      });
}

/// Publishes the active [AppStrings] to the widget tree.
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      oldWidget.strings != strings;
}

const Map<String, String> _en = <String, String>{
  'navHome': 'Home',
  'navAttendance': 'Attendance',
  'navEmployees': 'Employees',
  'navDuties': 'Duties',
  'navMore': 'More',
  'navDuty': 'Duty',
  'navActivity': 'Activity',
  'navProfile': 'Profile',
  'language': 'Language',
  'languageSubtitle': 'Choose the language for menus and labels',
  'trackingHealth': 'Tracking health',
  'trackingHealthSubtitle': 'Keep duty tracking working in the background',
  'ok': 'OK',
  'actionNeeded': 'Action needed',
  'fix': 'Fix',
  'check': 'Check',
  'backgroundLocation': 'Location access',
  'batteryUnrestricted': 'Battery unrestricted',
  'notificationsAllowed': 'Notifications allowed',
  'trackingRunning': 'Tracking service',
  'trackingRunningYes': 'Running',
  'trackingRunningNo': 'Stopped',
  'readinessTitle': 'Duty readiness',
  'readinessSubtitle':
      'Permissions and device settings that keep duty tracking working',
  'readinessAllGood': 'Everything needed for tracking is in place',
  'readinessLater': 'Later',
  'readinessOpenSettings': 'Open settings',
  'readinessRecheck': 'Check again',
  'readinessNotifications': 'Notifications',
  'readinessLocationItem': 'Location while using the app',
  'readinessBackgroundItem': 'Location in the background',
  'readinessCameraItem': 'Camera',
  'readinessActivityItem': 'Physical activity',
  'readinessAutostart': 'Auto-start after restart',
  'readinessAutostartWhy':
      'Some phone brands stop background apps. If your brand appears here, allow CISS to auto-start and stay protected.',
  'readinessOpenAutostart': 'Open auto-start settings',
  'readinessNotificationsWhy':
      'Duty alerts, check-in reminders and emergency messages arrive here, and Android requires this for the tracking notification.',
  'readinessLocationWhy':
      'Location is recorded only during duty hours so the control room can see site presence.',
  'readinessBackgroundLocationWhy':
      'Without this, position reporting stops when the app is not on screen, and a swipe-away during duty leaves a gap.',
  'readinessCameraWhy':
      'Photo proof is captured at check-in and when reporting an incident.',
  'readinessActivityWhy':
      'Movement type helps separate a patrol from a parked vehicle and saves battery.',
  'readinessBatteryWhy':
      'Android suspends background apps unless they are exempt. Set CISS to Unrestricted, then allow auto-start on the next step.',
  'readinessBannerTitle': 'Finish device setup',
  'readinessBannerBody': 'Some permissions or device settings are still missing.',
  'readinessStateGranted': 'Allowed',
  'readinessStateDenied': 'Denied',
  'readinessStateBlocked': 'Blocked',
  'readinessStateNotAsked': 'Not asked',
  'readinessStateNotNeeded': 'Not needed',
  'readinessStateUnknown': 'Unknown',
  'readinessAllow': 'Allow',
  'readinessOpenBatterySettings': 'Open battery settings',
  'readinessContinue': 'Continue',
  'readinessGrantRemaining': 'Allow remaining',
  'readinessProgress': '{ready} of {total} steps ready',
  'readinessTwoStepNote':
      'Android asks for this in two steps: allow location first, then choose "Allow all the time" on the next prompt.',
  'readinessLaterHint':
      'You can finish this later from More → Device setup. Check-in stays available.',
  'readinessChecking': 'Checking this device…',
  'readinessOpenScreen': 'Device setup',
  'readinessOemTitle': 'Keep CISS running on {brand}',
  'readinessOemBody':
      'This brand suspends background apps unless they are exempt. Allow CISS to run without restriction and to start on its own, then come back and check again.',
  'readinessOemOpenSettings': 'Open settings',
  'readinessOemStepSelect': 'Select CISS Workforce',
  'readinessOemStepUnrestrict': 'Choose "Don\'t restrict" or no restriction',
  'readinessOemStepVerify': 'Return here and tap Check again',
  'readinessOemPathXiaomi':
      'Settings → Apps → CISS Workforce → Battery saver → No restrictions',
  'readinessOemPathOppo':
      'Settings → Battery → App battery management → CISS Workforce → Allow background running',
  'readinessOemPathVivo':
      'Settings → Battery → Background power consumption management → CISS Workforce → Allow',
  'readinessOemPathHuawei':
      'Settings → Battery → App launch → CISS Workforce → Manage manually, then allow it as a Protected app',
  'readinessOemPathSamsung':
      'Settings → Battery and device care → Battery → Background usage limits → add CISS Workforce to Never sleeping apps',
  'readinessOemPathOnePlus':
      'Settings → Battery → Battery optimisation → CISS Workforce → Don\'t optimise, then allow Auto-launch',
  'readinessOemPathGeneric':
      'Settings → Apps → CISS Workforce → Battery → Unrestricted, then allow background activity',
  'attendanceOnDuty': 'On duty',
  'attendanceCheckedOut': 'Checked out',
  'attendanceCheckOutMissing': 'Check-out missing',
  'attendanceDuplicateCheckIn': 'Second check-in',
  'attendanceSince': 'since {time}',
  'attendanceSinceYesterday': 'since {time} (yesterday)',
  'attendanceReviewNotice': 'Check-outs to review: {count}',
  'attendanceReviewNoticeHint': 'Tap to see them',
  'attendanceCarriedOver': 'Carried over from the previous day',
  'attendanceCheckInLabel': 'Check-in',
  'attendanceCheckOutLabel': 'Check-out',
  'attendanceNotRecorded': 'Not recorded',
  'dutyCloseShiftHint':
      'This shift was not closed. Open attendance and record the check-out.',
  'navigate': 'Navigate',
  'navigateUnavailable': 'No maps app or browser could open this location.',
  'policyUnavailableTitle': 'Page not available offline',
  'policyUnavailableBody':
      'This page could not be loaded. Check your connection and try again, or open it in your browser.',
  'policyOpenInBrowser': 'Open in browser',
  'deviceThisDevice': 'This device',
  'deviceIdUnavailable': 'This phone does not report an identifier.',
  'timelineHistoryUnavailable': 'Movement history could not be loaded',
};

const Map<String, String> _hi = <String, String>{
  'navHome': 'होम',
  'navAttendance': 'उपस्थिति',
  'navEmployees': 'कर्मचारी',
  'navDuties': 'ड्यूटी',
  'navMore': 'अधिक',
  'navDuty': 'ड्यूटी',
  'navActivity': 'गतिविधि',
  'navProfile': 'प्रोफ़ाइल',
  'language': 'भाषा',
  'languageSubtitle': 'मेनू और लेबल के लिए भाषा चुनें',
  'trackingHealth': 'ट्रैकिंग स्थिति',
  'trackingHealthSubtitle': 'ड्यूटी ट्रैकिंग बैकग्राउंड में चालू रखें',
  'ok': 'ठीक है',
  'actionNeeded': 'कार्रवाई आवश्यक',
  'fix': 'ठीक करें',
  'check': 'जाँचें',
  'backgroundLocation': 'लोकेशन अनुमति',
  'batteryUnrestricted': 'बैटरी प्रतिबंध हटाएं',
  'notificationsAllowed': 'सूचनाएं अनुमत',
  'trackingRunning': 'ट्रैकिंग सेवा',
  'trackingRunningYes': 'चालू',
  'trackingRunningNo': 'बंद',
  'readinessTitle': 'ड्यूटी तैयारी',
  'readinessSubtitle':
      'ड्यूटी ट्रैकिंग चालू रखने के लिए अनुमतियाँ और डिवाइस सेटिंग्स',
  'readinessAllGood': 'ट्रैकिंग के लिए ज़रूरी सब कुछ पूरा है',
  'readinessLater': 'बाद में',
  'readinessOpenSettings': 'सेटिंग्स खोलें',
  'readinessRecheck': 'फिर जाँचें',
  'readinessNotifications': 'सूचनाएं',
  'readinessLocationItem': 'ऐप इस्तेमाल के दौरान लोकेशन',
  'readinessBackgroundItem': 'बैकग्राउंड में लोकेशन',
  'readinessCameraItem': 'कैमरा',
  'readinessActivityItem': 'शारीरिक गतिविधि',
  'readinessAutostart': 'रीस्टार्ट के बाद ऑटो-स्टार्ट',
  'readinessAutostartWhy':
      'कुछ फ़ोन ब्रांड बैकग्राउंड ऐप बंद कर देते हैं। अगर आपका ब्रांड यहाँ दिखे, तो CISS को ऑटो-स्टार्ट और सुरक्षित रहने दें।',
  'readinessOpenAutostart': 'ऑटो-स्टार्ट सेटिंग्स खोलें',
  'readinessNotificationsWhy':
      'ड्यूटी अलर्ट, चेक-इन रिमाइंडर और आपात संदेश यहीं आते हैं, और ट्रैकिंग नोटिफिकेशन के लिए Android इसे ज़रूरी रखता है।',
  'readinessLocationWhy':
      'लोकेशन सिर्फ़ ड्यूटी के समय दर्ज होती है ताकि कंट्रोल रूम साइट पर मौजूदगी देख सके।',
  'readinessBackgroundLocationWhy':
      'इसके बिना ऐप स्क्रीन पर न होने पर लोकेशन भेजना रुक जाता है और ड्यूटी के दौरान अंतराल बन सकता है।',
  'readinessCameraWhy': 'चेक-इन और घटना रिपोर्ट में फ़ोटो प्रमाण ली जाती है।',
  'readinessActivityWhy':
      'गतिविधि प्रकार से पैदल गश्त और खड़ी गाड़ी में फ़र्क़ होता है और बैटरी बचती है।',
  'readinessBatteryWhy':
      'Android बैकग्राउंड ऐप को रोक देता है जब तक वह छूट न पाए। CISS को Unrestricted करें, फिर अगले चरण में ऑटो-स्टार्ट दें।',
  'readinessBannerTitle': 'डिवाइस सेटअप पूरा करें',
  'readinessBannerBody': 'कुछ अनुमतियाँ या सेटिंग्स अभी बाकी हैं।',
  'readinessStateGranted': 'अनुमत',
  'readinessStateDenied': 'अस्वीकृत',
  'readinessStateBlocked': 'अवरुद्ध',
  'readinessStateNotAsked': 'नहीं पूछा',
  'readinessStateNotNeeded': 'ज़रूरत नहीं',
  'readinessStateUnknown': 'अज्ञात',
  'readinessAllow': 'अनुमति दें',
  'readinessOpenBatterySettings': 'बैटरी सेटिंग्स खोलें',
  'readinessContinue': 'जारी रखें',
  'readinessGrantRemaining': 'बाकी अनुमतियाँ दें',
  'readinessProgress': '{total} में से {ready} चरण पूरे',
  'readinessTwoStepNote':
      'Android यह दो चरणों में पूछता है: पहले लोकेशन दें, फिर अगले प्रॉम्प्ट पर "Allow all the time" चुनें।',
  'readinessLaterHint':
      'इसे बाद में More → Device setup से पूरा कर सकते हैं। चेक-इन उपलब्ध रहता है।',
  'readinessChecking': 'इस डिवाइस की जाँच हो रही है…',
  'readinessOpenScreen': 'डिवाइस सेटअप',
  'readinessOemTitle': '{brand} पर CISS चालू रखें',
  'readinessOemBody':
      'यह ब्रांड बैकग्राउंड ऐप रोक देता है। CISS को बिना रोकटोक चलने दें और अपने आप शुरू होने दें, फिर वापस आकर जाँचें।',
  'readinessOemOpenSettings': 'सेटिंग्स खोलें',
  'readinessOemStepSelect': 'CISS Workforce चुनें',
  'readinessOemStepUnrestrict': '"प्रतिबंध न लगाएं" चुनें',
  'readinessOemStepVerify': 'यहाँ वापस आकर फिर जाँचें दबाएं',
  'readinessOemPathXiaomi':
      'सेटिंग्स → ऐप्स → CISS Workforce → बैटरी सेवर → कोई प्रतिबंध नहीं',
  'readinessOemPathOppo':
      'सेटिंग्स → बैटरी → ऐप बैटरी प्रबंधन → CISS Workforce → बैकग्राउंड चलाने दें',
  'readinessOemPathVivo':
      'सेटिंग्स → बैटरी → बैकग्राउंड पावर प्रबंधन → CISS Workforce → अनुमति दें',
  'readinessOemPathHuawei':
      'सेटिंग्स → बैटरी → ऐप लॉन्च → CISS Workforce → मैन्युअल प्रबंधन, फिर संरक्षित ऐप में अनुमति दें',
  'readinessOemPathSamsung':
      'सेटिंग्स → बैटरी और डिवाइस देखभाल → बैटरी → बैकग्राउंड उपयोग सीमाएं → CISS Workforce को "कभी न सोने वाले ऐप" में डालें',
  'readinessOemPathOnePlus':
      'सेटिंग्स → बैटरी → बैटरी ऑप्टिमाइज़ेशन → CISS Workforce → ऑप्टिमाइज़ न करें, फिर ऑटो-लॉन्च दें',
  'readinessOemPathGeneric':
      'सेटिंग्स → ऐप्स → CISS Workforce → बैटरी → असीमित, फिर बैकग्राउंड गतिविधि दें',
  'attendanceOnDuty': 'ड्यूटी पर',
  'attendanceCheckedOut': 'चेक-आउट हो गया',
  'attendanceCheckOutMissing': 'चेक-आउट दर्ज नहीं',
  'attendanceDuplicateCheckIn': 'दूसरा चेक-इन',
  'attendanceSince': '{time} से',
  'attendanceSinceYesterday': '{time} से (कल)',
  'attendanceReviewNotice': 'समीक्षा बाकी चेक-आउट: {count}',
  'attendanceReviewNoticeHint': 'देखने के लिए टैप करें',
  'attendanceCarriedOver': 'पिछले दिन से जारी',
  'attendanceCheckInLabel': 'चेक-इन',
  'attendanceCheckOutLabel': 'चेक-आउट',
  'attendanceNotRecorded': 'दर्ज नहीं',
  'dutyCloseShiftHint':
      'यह शिफ्ट बंद नहीं हुई। उपस्थिति खोलकर चेक-आउट दर्ज करें।',
  'navigate': 'रास्ता देखें',
  'navigateUnavailable': 'इस जगह को खोलने के लिए कोई मैप ऐप या ब्राउज़र नहीं मिला।',
  'policyUnavailableTitle': 'पेज ऑफ़लाइन उपलब्ध नहीं',
  'policyUnavailableBody':
      'यह पेज लोड नहीं हो सका। कनेक्शन जाँचकर फिर कोशिश करें, या ब्राउज़र में खोलें।',
  'policyOpenInBrowser': 'ब्राउज़र में खोलें',
  'deviceThisDevice': 'यह डिवाइस',
  'deviceIdUnavailable': 'यह फ़ोन कोई पहचान नहीं देता।',
  'timelineHistoryUnavailable': 'गतिविधि इतिहास लोड नहीं हो सका',
};

const Map<String, String> _ml = <String, String>{
  'navHome': 'ഹോം',
  'navAttendance': 'ഹാജർ',
  'navEmployees': 'ജീവനക്കാർ',
  'navDuties': 'ഡ്യൂട്ടി',
  'navMore': 'കൂടുതൽ',
  'navDuty': 'ഡ്യൂട്ടി',
  'navActivity': 'പ്രവർത്തനം',
  'navProfile': 'പ്രൊഫൈൽ',
  'language': 'ഭാഷ',
  'languageSubtitle': 'മെനുകൾക്കും ലേബലുകൾക്കും ഭാഷ തിരഞ്ഞെടുക്കുക',
  'trackingHealth': 'ട്രാക്കിംഗ് നില',
  'trackingHealthSubtitle': 'ഡ്യൂട്ടി ട്രാക്കിംഗ് പശ്ചാത്തലത്തിൽ പ്രവർത്തിപ്പിക്കുക',
  'ok': 'കുഴപ്പമില്ല',
  'actionNeeded': 'നടപടി വേണം',
  'fix': 'ശരിയാക്കുക',
  'check': 'പരിശോധിക്കുക',
  'backgroundLocation': 'ലൊക്കേഷൻ അനുമതി',
  'batteryUnrestricted': 'ബാറ്ററി നിയന്ത്രണം ഒഴിവാക്കുക',
  'notificationsAllowed': 'അറിയിപ്പുകൾ അനുവദിച്ചു',
  'trackingRunning': 'ട്രാക്കിംഗ് സേവനം',
  'trackingRunningYes': 'പ്രവർത്തിക്കുന്നു',
  'trackingRunningNo': 'നിന്നു',
  'readinessTitle': 'ഡ്യൂട്ടി സന്നദ്ധത',
  'readinessSubtitle':
      'ഡ്യൂട്ടി ട്രാക്കിംഗ് പ്രവർത്തിപ്പിക്കാൻ വേണ്ട അനുമതികളും ക്രമീകരണങ്ങളും',
  'readinessAllGood': 'ട്രാക്കിംഗിന് വേണ്ടതെല്ലാം തയ്യാറാണ്',
  'readinessLater': 'പിന്നീട്',
  'readinessOpenSettings': 'ക്രമീകരണങ്ങൾ തുറക്കുക',
  'readinessRecheck': 'വീണ്ടും പരിശോധിക്കുക',
  'readinessNotifications': 'അറിയിപ്പുകൾ',
  'readinessLocationItem': 'ആപ്പ് ഉപയോഗിക്കുമ്പോൾ ലൊക്കേഷൻ',
  'readinessBackgroundItem': 'പശ്ചാത്തലത്തിൽ ലൊക്കേഷൻ',
  'readinessCameraItem': 'ക്യാമറ',
  'readinessActivityItem': 'ശാരീരിക പ്രവർത്തനം',
  'readinessAutostart': 'റീസ്റ്റാർട്ടിന് ശേഷം ഓട്ടോ-സ്റ്റാർട്ട്',
  'readinessAutostartWhy':
      'ചില ഫോൺ ബ്രാൻഡുകൾ പശ്ചാത്തല ആപ്പുകൾ നിർത്തും. നിങ്ങളുടെ ബ്രാൻഡ് ഇവിടെ കാണുന്നുവെങ്കിൽ CISS-നെ ഓട്ടോ-സ്റ്റാർട്ട് അനുവദിക്കുക.',
  'readinessOpenAutostart': 'ഓട്ടോ-സ്റ്റാർട്ട് ക്രമീകരണങ്ങൾ തുറക്കുക',
  'readinessNotificationsWhy':
      'ഡ്യൂട്ടി അലേർട്ടുകളും ഹാജർ ഓർമ്മപ്പെടുത്തലുകളും ഇവിടെയാണ് വരുന്നത്; ട്രാക്കിംഗ് നോട്ടിഫിക്കേഷന് ഇത് ആവശ്യമാണ്.',
  'readinessLocationWhy':
      'ഡ്യൂട്ടി സമയത്ത് മാത്രമാണ് ലൊക്കേഷൻ രേഖപ്പെടുത്തുന്നത്.',
  'readinessBackgroundLocationWhy':
      'ഇതില്ലാതെ ആപ്പ് സ്ക്രീനിലില്ലാത്തപ്പോൾ ലൊക്കേഷൻ നിലയ്ക്കും, ഡ്യൂട്ടിക്കിടെ വിടവ് ഉണ്ടാകാം.',
  'readinessCameraWhy':
      'ഹാജരും സംഭവ റിപ്പോർട്ടുകളും സ്ഥിരീകരിക്കാൻ ഫോട്ടോ എടുക്കുന്നു.',
  'readinessActivityWhy':
      'നടത്തമോ വാഹനമോ എന്ന് തിരിച്ചറിയാൻ സഹായിക്കുന്നു, ബാറ്ററിയും ലാഭിക്കുന്നു.',
  'readinessBatteryWhy':
      'ഒഴിവാക്കൽ ഇല്ലെങ്കിൽ Android പശ്ചാത്തല ആപ്പ് നിർത്തും. CISS-നെ Unrestricted ആക്കി അടുത്ത ഘട്ടത്തിൽ ഓട്ടോ-സ്റ്റാർട്ട് അനുവദിക്കുക.',
  'readinessBannerTitle': 'ഡിവൈസ് ക്രമീകരണം പൂർത്തിയാക്കുക',
  'readinessBannerBody': 'ചില അനുമതികളോ ക്രമീകരണങ്ങളോ ബാക്കിയുണ്ട്.',
  'readinessStateGranted': 'അനുവദിച്ചു',
  'readinessStateDenied': 'നിഷേധിച്ചു',
  'readinessStateBlocked': 'തടഞ്ഞു',
  'readinessStateNotAsked': 'ചോദിച്ചിട്ടില്ല',
  'readinessStateNotNeeded': 'ആവശ്യമില്ല',
  'readinessStateUnknown': 'അജ്ഞാതം',
  'readinessAllow': 'അനുവദിക്കുക',
  'readinessOpenBatterySettings': 'ബാറ്ററി ക്രമീകരണങ്ങൾ തുറക്കുക',
  'readinessContinue': 'തുടരുക',
  'readinessGrantRemaining': 'ബാക്കിയുള്ളവ അനുവദിക്കുക',
  'readinessProgress': '{total}-ൽ {ready} ഘട്ടങ്ങൾ തയ്യാർ',
  'readinessTwoStepNote':
      'Android ഇത് രണ്ട് ഘട്ടങ്ങളിലായി ചോദിക്കും: ആദ്യം ലൊക്കേഷൻ അനുവദിക്കുക, പിന്നെ അടുത്ത സന്ദേശത്തിൽ "Allow all the time" തിരഞ്ഞെടുക്കുക.',
  'readinessLaterHint':
      'ഇത് പിന്നീട് More → Device setup-ൽ പൂർത്തിയാക്കാം. ചെക്ക്-ഇൻ ലഭ്യമാണ്.',
  'readinessChecking': 'ഈ ഡിവൈസ് പരിശോധിക്കുന്നു…',
  'readinessOpenScreen': 'ഡിവൈസ് സെറ്റപ്പ്',
  'readinessOemTitle': '{brand}-ൽ CISS പ്രവർത്തിപ്പിക്കുക',
  'readinessOemBody':
      'ഈ ബ്രാൻഡ് പശ്ചാത്തല ആപ്പുകൾ നിർത്തും. CISS-നെ നിയന്ത്രണമില്ലാതെ ഓടാനും സ്വയം ആരംഭിക്കാനും അനുവദിച്ച ശേഷം തിരികെ വന്ന് പരിശോധിക്കുക.',
  'readinessOemOpenSettings': 'ക്രമീകരണങ്ങൾ തുറക്കുക',
  'readinessOemStepSelect': 'CISS Workforce തിരഞ്ഞെടുക്കുക',
  'readinessOemStepUnrestrict': '"നിയന്ത്രിക്കരുത്" തിരഞ്ഞെടുക്കുക',
  'readinessOemStepVerify': 'ഇവിടെ തിരികെ വന്ന് വീണ്ടും പരിശോധിക്കുക',
  'readinessOemPathXiaomi':
      'ക്രമീകരണങ്ങൾ → ആപ്പുകൾ → CISS Workforce → ബാറ്ററി സേവർ → നിയന്ത്രണമില്ല',
  'readinessOemPathOppo':
      'ക്രമീകരണങ്ങൾ → ബാറ്ററി → ആപ്പ് ബാറ്ററി മാനേജ്മെന്റ് → CISS Workforce → പശ്ചാത്തലത്തിൽ ഓടാൻ അനുവദിക്കുക',
  'readinessOemPathVivo':
      'ക്രമീകരണങ്ങൾ → ബാറ്ററി → പശ്ചാത്തല പവർ മാനേജ്മെന്റ് → CISS Workforce → അനുവദിക്കുക',
  'readinessOemPathHuawei':
      'ക്രമീകരണങ്ങൾ → ബാറ്ററി → ആപ്പ് ലോഞ്ച് → CISS Workforce → സ്വമേധയാ നിയന്ത്രിക്കുക, പിന്നെ സംരക്ഷിത ആപ്പായി അനുവദിക്കുക',
  'readinessOemPathSamsung':
      'ക്രമീകരണങ്ങൾ → ബാറ്ററിയും ഉപകരണ പരിചരണവും → ബാറ്ററി → പശ്ചാത്തല ഉപയോഗ പരിധി → CISS Workforce-നെ "ഒരിക്കലും ഉറങ്ങാത്ത ആപ്പുകളിൽ" ചേർക്കുക',
  'readinessOemPathOnePlus':
      'ക്രമീകരണങ്ങൾ → ബാറ്ററി → ബാറ്ററി ഒപ്റ്റിമൈസേഷൻ → CISS Workforce → ഒപ്റ്റിമൈസ് ചെയ്യരുത്, പിന്നെ ഓട്ടോ-ലോഞ്ച് അനുവദിക്കുക',
  'readinessOemPathGeneric':
      'ക്രമീകരണങ്ങൾ → ആപ്പുകൾ → CISS Workforce → ബാറ്ററി → അൺറെസ്ട്രിക്റ്റഡ്, പിന്നെ പശ്ചാത്തല പ്രവർത്തനം അനുവദിക്കുക',
  'attendanceOnDuty': 'ഡ്യൂട്ടിയിൽ',
  'attendanceCheckedOut': 'ചെക്ക്-ഔട്ട് ആയി',
  'attendanceCheckOutMissing': 'ചെക്ക്-ഔട്ട് രേഖപ്പെടുത്തിയിട്ടില്ല',
  'attendanceDuplicateCheckIn': 'രണ്ടാമത്തെ ചെക്ക്-ഇൻ',
  'attendanceSince': '{time} മുതൽ',
  'attendanceSinceYesterday': '{time} മുതൽ (ഇന്നലെ)',
  'attendanceReviewNotice': 'പരിശോധിക്കേണ്ട ചെക്ക്-ഔട്ടുകൾ: {count}',
  'attendanceReviewNoticeHint': 'കാണാൻ ടാപ്പ് ചെയ്യുക',
  'attendanceCarriedOver': 'മുൻ ദിവസത്തിൽ നിന്ന് തുടരുന്നത്',
  'attendanceCheckInLabel': 'ചെക്ക്-ഇൻ',
  'attendanceCheckOutLabel': 'ചെക്ക്-ഔട്ട്',
  'attendanceNotRecorded': 'രേഖപ്പെടുത്തിയിട്ടില്ല',
  'dutyCloseShiftHint':
      'ഈ ഷിഫ്റ്റ് അവസാനിച്ചിട്ടില്ല. ഹാജർ തുറന്ന് ചെക്ക്-ഔട്ട് രേഖപ്പെടുത്തുക.',
  'navigate': 'വഴി കാണുക',
  'navigateUnavailable':
      'ഈ സ്ഥലം തുറക്കാൻ മാപ്പ് ആപ്പോ ബ്രൗസറോ കണ്ടെത്തിയില്ല.',
  'policyUnavailableTitle': 'പേജ് ഓഫ്‌ലൈനിൽ ലഭ്യമല്ല',
  'policyUnavailableBody':
      'ഈ പേജ് ലോഡ് ചെയ്യാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക, അല്ലെങ്കിൽ ബ്രൗസറിൽ തുറക്കുക.',
  'policyOpenInBrowser': 'ബ്രൗസറിൽ തുറക്കുക',
  'deviceThisDevice': 'ഈ ഡിവൈസ്',
  'deviceIdUnavailable': 'ഈ ഫോൺ ഒരു ഐഡന്റിഫയർ നൽകുന്നില്ല.',
  'timelineHistoryUnavailable': 'ചലന ചരിത്രം ലോഡ് ചെയ്യാനായില്ല',
};
