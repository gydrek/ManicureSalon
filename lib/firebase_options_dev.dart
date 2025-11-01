import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase опції для development середовища (тестова БД)
class DevelopmentFirebaseOptions {
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
          'DevelopmentFirebaseOptions have not been configured for linux',
        );
      default:
        throw UnsupportedError(
          'DevelopmentFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDcPnmqruzobZAFpCwXwiWHrnD0unTdJSM',
    appId: '1:760861241087:web:dummy-replace',
    messagingSenderId: '760861241087',
    projectId: 'manicure-salon-ba7ad',
    authDomain: 'manicure-salon-ba7ad.firebaseapp.com',
    storageBucket: 'manicure-salon-ba7ad.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDcPnmqruzobZAFpCwXwiWHrnD0unTdJSM',
    appId: '1:760861241087:android:1ce3183d71431263c3a6ca',
    messagingSenderId: '760861241087',
    projectId: 'manicure-salon-ba7ad',
    storageBucket: 'manicure-salon-ba7ad.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDcPnmqruzobZAFpCwXwiWHrnD0unTdJSM',
    appId: '1:760861241087:ios:dummy-replace',
    messagingSenderId: '760861241087',
    projectId: 'manicure-salon-ba7ad',
    storageBucket: 'manicure-salon-ba7ad.firebasestorage.app',
    iosBundleId: 'com.nastyaApp.ManicureSalon',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDcPnmqruzobZAFpCwXwiWHrnD0unTdJSM',
    appId: '1:760861241087:macos:dummy-replace',
    messagingSenderId: '760861241087',
    projectId: 'manicure-salon-ba7ad',
    storageBucket: 'manicure-salon-ba7ad.firebasestorage.app',
    iosBundleId: 'com.nastyaApp.ManicureSalon',
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