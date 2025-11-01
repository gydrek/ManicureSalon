/// Конфігурація застосунку для різних середовищ
class AppConfig {
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Поточне середовище (development, production)
  static String get environment => _environment;

  /// Чи це продакшн версія
  static bool get isProduction => _environment == 'production';

  /// Чи це розробницька версія  
  static bool get isDevelopment => _environment == 'development';

  /// Налаштування для різних середовищ
  static const Map<String, AppEnvironment> _environments = {
    'development': AppEnvironment(
      name: 'Development',
      firebaseProjectId: 'manicure-salon-ba7ad', // Замініть на ID нового проекту
      apiUrl: 'https://api.nastya-salon.com',
      enableLogging: true, // Можете залишити логування для налагодження
      enableAnalytics: true,
    ),
    'production': AppEnvironment(
      name: 'Production',
      firebaseProjectId: 'nastya-manicure-salon-prod', // Продакшн БД (замініть на реальний ID)
      apiUrl: 'https://api.nastya-salon.com',
      enableLogging: false,
      enableAnalytics: true,
    ),
  };

  /// Поточна конфігурація середовища
  static AppEnvironment get current => _environments[_environment]!;

  /// Версія застосунку
  static const String appVersion = '1.0.0-beta';

  /// Назва застосунку
  static const String appName = 'Манікюрний салон';

  /// Debug інформація
  static String get debugInfo => '''
Environment: ${current.name}
Firebase Project: ${current.firebaseProjectId}
Version: $appVersion
Logging: ${current.enableLogging}
Analytics: ${current.enableAnalytics}
''';
}

/// Конфігурація для конкретного середовища
class AppEnvironment {
  final String name;
  final String firebaseProjectId;
  final String apiUrl;
  final bool enableLogging;
  final bool enableAnalytics;

  const AppEnvironment({
    required this.name,
    required this.firebaseProjectId,
    required this.apiUrl,
    required this.enableLogging,
    required this.enableAnalytics,
  });
}