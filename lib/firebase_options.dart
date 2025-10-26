import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDummy-Web-Key-Replace-Me',
    appId: '1:1006914970725:web:dummy-replace',
    messagingSenderId: '1006914970725',
    projectId: 'manicure-salon-334ba',
    authDomain: 'manicure-salon-334ba.firebaseapp.com',
    storageBucket: 'manicure-salon-334ba.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcIfM5JA435wetzx3br3VrFpuQEX2KVWY',
    appId: '1:1006914970725:android:6d799431ca0f825c06128c', 
    messagingSenderId: '1006914970725',
    projectId: 'manicure-salon-334ba',
    storageBucket: 'manicure-salon-334ba.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummy-iOS-Key-Replace-Me',
    appId: '1:1006914970725:ios:dummy-replace',
    messagingSenderId: '1006914970725',
    projectId: 'manicure-salon-334ba',
    storageBucket: 'manicure-salon-334ba.firebasestorage.app',
    iosBundleId: 'com.nastya.salon',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDummy-macOS-Key-Replace-Me',
    appId: '1:963410280493:macos:dummy-replace',
    messagingSenderId: '963410280493',
    projectId: 'manicure-salon',
    storageBucket: 'manicure-salon.firebasestorage.app',
    iosBundleId: 'com.nastya.salon',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDummy-Windows-Key-Replace-Me',
    appId: '1:963410280493:windows:dummy-replace',
    messagingSenderId: '963410280493',
    projectId: 'manicure-salon',
    authDomain: 'manicure-salon.firebaseapp.com',
    storageBucket: 'manicure-salon.firebasestorage.app',
  );
}