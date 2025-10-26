import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Ініціалізуємо часові зони
    tz.initializeTimeZones();

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
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Створюємо канал сповіщень для Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    // Запитуємо дозволи
    await _requestPermissions();

    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) {
      print('⚠️ Android implementation не знайдено');
      return;
    }

    // Канал для нагадувань про сесії
    const AndroidNotificationChannel sessionChannel = AndroidNotificationChannel(
      'session_reminders',
      'Нагадування про записи',
      description: 'Сповіщення про майбутні записи клієнток',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Канал для тестових сповіщень
    const AndroidNotificationChannel testChannel = AndroidNotificationChannel(
      'test_notifications',
      'Тестові сповіщення',
      description: 'Канал для тестових сповіщень',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Канал для простого тесту
    const AndroidNotificationChannel simpleTestChannel = AndroidNotificationChannel(
      'test_simple',
      'Простий тест',
      description: 'Канал для простого тесту',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    try {
      await androidImplementation.createNotificationChannel(sessionChannel);
      await androidImplementation.createNotificationChannel(testChannel);
      await androidImplementation.createNotificationChannel(simpleTestChannel);
      
      if (kDebugMode) {
        print('✅ Всі канали сповіщень створено успішно');
      }
    } catch (e) {
      print('❌ Помилка створення каналів: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.isDenied.then((value) {
        if (value) {
          Permission.notification.request();
        }
      });
    }

    if (Platform.isIOS) {
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

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Обробка натискання на сповіщення
    if (kDebugMode) {
      print('Натиснуто на сповіщення: ${response.payload}');
    }
  }

  Future<void> scheduleSessionReminder({
    required String sessionId,
    required String clientName,
    required String masterName,
    required DateTime sessionDateTime,
    required String masterId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kDebugMode) {
      print('Планування сповіщення для сесії $sessionId');
      print('Клієнт: $clientName, Майстер: $masterName');
      print('Час сесії: $sessionDateTime');
    }

    // Перевіряємо, чи увімкнені сповіщення для цього майстра
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_$masterId') ?? true;
    
    if (!notificationsEnabled) {
      if (kDebugMode) {
        print('Сповіщення для майстра $masterName вимкнені');
      }
      return;
    }

    // Час сповіщення - за 30 хвилин до сесії
    final notificationTime = sessionDateTime.subtract(const Duration(minutes: 30));
    final now = DateTime.now();
    
    if (kDebugMode) {
      print('Час сповіщення: $notificationTime');
      print('Поточний час: $now');
      print('Різниця: ${notificationTime.difference(now).inMinutes} хвилин');
    }
    
    // Перевіряємо, чи час сповіщення ще не минув
    if (notificationTime.isBefore(now)) {
      if (kDebugMode) {
        print('⚠️ Час для сповіщення вже минув. Сесія занадто близько або в минулому.');
        print('Рекомендується створювати записи мінімум за 30 хвилин.');
      }
      return;
    }
    
    // Якщо до сповіщення менше 1 хвилини - показуємо миттєве
    if (notificationTime.difference(now).inMinutes < 1) {
      if (kDebugMode) {
        print('⚡ Час сповіщення дуже близько, показуємо миттєве сповіщення');
      }
      
      await showImmediateNotification(
        title: 'Нагадування про запис',
        body: 'Незабаром: $clientName у майстра $masterName',
      );
      return;
    }

    // Створюємо унікальний ID для сповіщення
    final notificationId = sessionId.hashCode;

    // Налаштування для Android
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'session_reminders',
      'Нагадування про записи',
      channelDescription: 'Сповіщення про майбутні записи клієнток',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/notification_icon',
      enableVibration: true,
      playSound: true,
    );

    // Налаштування для iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Формуємо текст сповіщення
    final title = 'Нагадування про запис';
    final body = 'Через 30 хвилин: $clientName у майстра $masterName';

    // Плануємо сповіщення
    try {
      final scheduledTime = tz.TZDateTime.from(notificationTime, tz.local);
      
      if (kDebugMode) {
        print('📅 Час для планування: $scheduledTime');
        print('🌍 Часова зона: ${tz.local.name}');
        print('🔢 ID сповіщення: $notificationId');
      }
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'session_$sessionId',
      );

      if (kDebugMode) {
        print('✅ Сповіщення успішно заплановано для сесії $sessionId на $notificationTime');
        
        // Перевіряємо відразу після планування
        final pending = await getPendingNotifications();
        print('📋 Зараз заплановано сповіщень: ${pending.length}');
        for (final p in pending) {
          print('  - ID: ${p.id}, Title: ${p.title}');
        }
      }
    } catch (e) {
      print('❌ Помилка планування сповіщення: $e');
      rethrow;
    }
  }

  Future<void> cancelSessionReminder(String sessionId) async {
    final notificationId = sessionId.hashCode;
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
    
    if (kDebugMode) {
      print('Скасовано сповіщення для сесії $sessionId');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    
    if (kDebugMode) {
      print('Скасовано всі сповіщення');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    } else if (Platform.isIOS) {
      final settings = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return false;
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_notifications',
      'Тестові сповіщення',
      channelDescription: 'Канал для тестових сповіщень',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/notification_icon',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      999, // ID для тестових сповіщень
      title,
      body,
      platformChannelSpecifics,
      payload: 'test_notification',
    );

    if (kDebugMode) {
      print('Показано миттєве тестове сповіщення: $title - $body');
    }
  }

  Future<void> showSimpleTest() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Показуємо миттєве сповіщення
    await _flutterLocalNotificationsPlugin.show(
      999,
      'Простий тест',
      'Якщо бачите це - сповіщення працюють!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_simple',
          'Простий тест',
          channelDescription: 'Канал для простого тесту',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
    
    // Також плануємо тестове сповіщення через 1 хвилину
    try {
      final testTime = DateTime.now().add(Duration(minutes: 1));
      final scheduledTime = tz.TZDateTime.from(testTime, tz.local);
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        998, // Інший ID для запланованого тесту
        'Заплановане тестове сповіщення',
        'Це сповіщення було заплановано на 1 хвилину!',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_simple',
            'Простий тест',
            channelDescription: 'Канал для простого тесту',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'scheduled_test',
      );
      
      if (kDebugMode) {
        print('✅ Відправлено миттєвий тест + заплановано тест на ${testTime}');
      }
    } catch (e) {
      print('❌ Помилка планування тестового сповіщення: $e');
    }
  }
}