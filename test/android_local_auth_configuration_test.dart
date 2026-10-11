import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android local_auth host has FragmentActivity and AppCompat themes', () {
    final activity =
        File(
          'android/app/src/main/kotlin/co/in/ciss/ciss_mobile/MainActivity.kt',
        ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final dayTheme =
        File('android/app/src/main/res/values/styles.xml').readAsStringSync();
    final nightTheme =
        File(
          'android/app/src/main/res/values-night/styles.xml',
        ).readAsStringSync();

    expect(
      activity,
      contains('class MainActivity : FlutterFragmentActivity()'),
    );
    expect(gradle, contains('implementation("androidx.appcompat:appcompat:'));
    expect(dayTheme, contains('parent="Theme.AppCompat.Light.NoActionBar"'));
    expect(nightTheme, contains('parent="Theme.AppCompat.NoActionBar"'));
  });
}
