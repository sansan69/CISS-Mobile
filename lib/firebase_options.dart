import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCB-xr1tID8r8ZHcUxRe8HBkg_agNTEw9s',
    appId: '1:1041149201339:android:7b26e030f9400f1f5b929e',
    messagingSenderId: '1041149201339',
    projectId: 'ciss-workforce',
    storageBucket: 'ciss-workforce.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCEa_oHr9CBgDB5_3nm7JYRQeuGW6umWbA',
    appId: '1:1041149201339:ios:80f4b431bff0d45b5b929e',
    messagingSenderId: '1041149201339',
    projectId: 'ciss-workforce',
    storageBucket: 'ciss-workforce.firebasestorage.app',
    iosBundleId: 'co.in.ciss.cissMobile',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD_oZTSoD5P7KukyR90097fnNFvIVcdISs',
    appId: '1:1041149201339:web:d8bc8ce567b2f0955b929e',
    messagingSenderId: '1041149201339',
    projectId: 'ciss-workforce',
    storageBucket: 'ciss-workforce.firebasestorage.app',
    iosBundleId: 'co.in.ciss.cissMobile',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD_oZTSoD5P7KukyR90097fnNFvIVcdISs',
    appId: '1:1041149201339:web:d8bc8ce567b2f0955b929e',
    messagingSenderId: '1041149201339',
    projectId: 'ciss-workforce',
    authDomain: 'ciss-workforce.firebaseapp.com',
    storageBucket: 'ciss-workforce.firebasestorage.app',
    measurementId: 'G-D1EK2DELHD',
  );

  static const FirebaseOptions windows = web;

  static const FirebaseOptions linux = web;
}
