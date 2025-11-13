import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nastya_app/providers/language_provider.dart';

/// NotificationService - тільки для тестування дозволів у налаштуваннях
/// Всі планові сповіщення працюють через FCM Cloud Functions
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  LanguageProvider? _languageProvider;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Налаштування для Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/notification_icon');

    // Налаштування для iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Запитуємо дозволи
    await _requestPermissions();

    _isInitialized = true;
    print('✅ NotificationService ініціалізовано (тільки для тестування)');
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Локальне сповіщення натиснуто: ${response.payload}');
  }

  void setLanguageProvider(LanguageProvider languageProvider) {
    _languageProvider = languageProvider;
  }

  /// Перевірка дозволів на сповіщення
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    } else if (Platform.isIOS) {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return result?.isEnabled ?? false;
    }
    return false;
  }

  /// ТЕСТОВЕ СПОВІЩЕННЯ - єдина локальна функція що залишилась
  /// Використовується для перевірки дозволів та налаштувань
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    final String title = _languageProvider?.currentLocale.languageCode == 'uk' 
        ? '🧪 Тестове сповіщення'
        : '🧪 Тестовое уведомление';
        
    final String body = _languageProvider?.currentLocale.languageCode == 'uk'
        ? 'Сповіщення працюють правильно!'
        : 'Уведомления работают правильно!';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Тестові сповіщення',
      channelDescription: 'Канал для тестування сповіщень',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      999, // ID для тестових сповіщень
      title,
      body,
      platformChannelSpecifics,
    );

    print('🧪 Показано тестове сповіщення');
  }

  /// Показати негайне сповіщення (для налаштувань)
  Future<void> showImmediateNotification(String title, String body) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'immediate_channel',
      'Негайні сповіщення',
      channelDescription: 'Канал для негайних сповіщень',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      998, // ID для негайних сповіщень
      title,
      body,
      platformChannelSpecifics,
    );

    print('📱 Показано негайне сповіщення: $title');
  }

  /// Простий тест сповіщень
  Future<void> showSimpleTest() async {
    await showTestNotification();
  }
}