import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase опції для production середовища (робоча БД)
/// 
/// ⚠️ УВАГА: Замініть всі dummy ключі на реальні після створення нового Firebase проекту!
/// 
/// Кроки для налаштування:
/// 1. Створіть новий Firebase проект для продакшну
/// 2. Додайте всі платформи (Android, iOS, Web, Windows, macOS)
/// 3. Завантажте конфігураційні файли і замініть значення нижче
/// 4. Налаштуйте Firestore rules для продакшну
class ProductionFirebaseOptions {
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
          'ProductionFirebaseOptions have not been configured for linux',
        );
      default:
        throw UnsupportedError(
          'ProductionFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Замініть на реальні ключі з нового Firebase проекту
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR-PROD-WEB-API-KEY',
    appId: 'YOUR-PROD-WEB-APP-ID',
    messagingSenderId: 'YOUR-PROD-SENDER-ID',
    projectId: 'nastya-manicure-salon-prod', // Замініть на реальний ID
    authDomain: 'nastya-manicure-salon-prod.firebaseapp.com',
    storageBucket: 'nastya-manicure-salon-prod.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR-PROD-ANDROID-API-KEY',
    appId: 'YOUR-PROD-ANDROID-APP-ID',
    messagingSenderId: 'YOUR-PROD-SENDER-ID',
    projectId: 'nastya-manicure-salon-prod', // Замініть на реальний ID
    storageBucket: 'nastya-manicure-salon-prod.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR-PROD-IOS-API-KEY',
    appId: 'YOUR-PROD-IOS-APP-ID',
    messagingSenderId: 'YOUR-PROD-SENDER-ID',
    projectId: 'nastya-manicure-salon-prod', // Замініть на реальний ID
    storageBucket: 'nastya-manicure-salon-prod.firebasestorage.app',
    iosBundleId: 'com.nastya.salon', // Продакшн bundle ID без .dev
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR-PROD-MACOS-API-KEY',
    appId: 'YOUR-PROD-MACOS-APP-ID',
    messagingSenderId: 'YOUR-PROD-SENDER-ID',
    projectId: 'nastya-manicure-salon-prod', // Замініть на реальний ID
    authDomain: 'nastya-manicure-salon-prod.firebaseapp.com',
    storageBucket: 'nastya-manicure-salon-prod.firebasestorage.app',
    iosBundleId: 'com.nastya.salon',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR-PROD-WINDOWS-API-KEY',
    appId: 'YOUR-PROD-WINDOWS-APP-ID',
    messagingSenderId: 'YOUR-PROD-SENDER-ID',
    projectId: 'nastya-manicure-salon-prod', // Замініть на реальний ID
    authDomain: 'nastya-manicure-salon-prod.firebaseapp.com',
    storageBucket: 'nastya-manicure-salon-prod.firebasestorage.app',
  );
}