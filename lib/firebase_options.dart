import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'config/app_config.dart';
import 'firebase_options_dev.dart';
import 'firebase_options_prod.dart';

/// Автоматичний вибір Firebase конфігурації на основі середовища
/// 
/// Використання:
/// ```dart
/// import 'firebase_options.dart';
/// 
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
/// 
/// Для зміни середовища використовуйте:
/// - Development: `flutter run`
/// - Production: `flutter run --dart-define=ENVIRONMENT=production`
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Автоматично вибираємо конфігурацію на основі середовища
    if (AppConfig.isProduction) {
      print('🚀 Використовуємо PRODUCTION Firebase конфігурацію');
      return ProductionFirebaseOptions.currentPlatform;
    } else {
      print('🧪 Використовуємо DEVELOPMENT Firebase конфігурацію');
      return DevelopmentFirebaseOptions.currentPlatform;
    }
  }
  
  /// Отримати конфігурацію для конкретного середовища
  static FirebaseOptions getPlatformForEnvironment(String environment) {
    switch (environment.toLowerCase()) {
      case 'production':
        return ProductionFirebaseOptions.currentPlatform;
      case 'development':
      default:
        return DevelopmentFirebaseOptions.currentPlatform;
    }
  }

}
