import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nastya_app/models/models.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/providers/language_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isInitialized = false;
  LanguageProvider? _languageProvider;

  // Таймери для відстеження закінчення сесій
  final Map<String, Timer> _sessionTimers = {};
  final Map<String, Timer> _autoMissedTimers = {};

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
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation == null) {
      print('⚠️ Android implementation не знайдено');
      return;
    }

    // Канал для нагадувань про сесії
    const AndroidNotificationChannel sessionChannel =
        AndroidNotificationChannel(
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
    const AndroidNotificationChannel simpleTestChannel =
        AndroidNotificationChannel(
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
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Обробка натискання на сповіщення
    if (kDebugMode) {
      print('Натиснуто на сповіщення: ${response.payload}');
    }
  }

  /// Встановити провайдер мови для локалізації сповіщень
  void setLanguageProvider(LanguageProvider languageProvider) {
    _languageProvider = languageProvider;
  }

  /// Отримати інформацію про майстриню
  Future<String> _getMasterName(String masterId) async {
    try {
      final master = await _firestoreService.getMasterById(masterId);
      if (master != null) {
        final languageCode =
            _languageProvider?.currentLocale.languageCode ?? 'uk';
        return master.getLocalizedName(languageCode);
      }
    } catch (e) {
      print('❌ Помилка отримання імені майстрині: $e');
    }
    return 'Невідома майстриня';
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
    final notificationsEnabled =
        prefs.getBool('notifications_$masterId') ?? true;

    if (!notificationsEnabled) {
      if (kDebugMode) {
        print('Сповіщення для майстра $masterName вимкнені');
      }
      return;
    }

    // Час сповіщення - за 30 хвилин до сесії
    final notificationTime = sessionDateTime.subtract(
      const Duration(minutes: 30),
    );
    final now = DateTime.now();

    if (kDebugMode) {
      print('Час сповіщення: $notificationTime');
      print('Поточний час: $now');
      print('Різниця: ${notificationTime.difference(now).inMinutes} хвилин');
    }

    // Перевіряємо, чи час сповіщення ще не минув
    if (notificationTime.isBefore(now)) {
      if (kDebugMode) {
        print(
          '⚠️ Час для сповіщення вже минув. Сесія занадто близько або в минулому.',
        );
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
        print(
          '✅ Сповіщення успішно заплановано для сесії $sessionId на $notificationTime',
        );

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
            IOSFlutterLocalNotificationsPlugin
          >()
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

  /// Запланувати сповіщення про завершення сесії
  void scheduleSessionEndNotification(Session session) {
    try {
      final sessionDateTime = _parseSessionDateTime(session);
      final sessionEndTime = sessionDateTime.add(
        Duration(minutes: session.duration),
      );
      final now = DateTime.now();

      // Перевіряємо, чи сесія ще не закінчилась
      if (sessionEndTime.isBefore(now)) {
        print(
          '⏰ Сесія ${session.id} вже закінчилась, пропускаємо планування сповіщення',
        );
        return;
      }

      // Скасовуємо попередні таймери для цієї сесії
      _cancelSessionTimers(session.id!);

      // Плануємо сповіщення про завершення сесії
      final timeUntilEnd = sessionEndTime.difference(now);
      _sessionTimers[session.id!] = Timer(timeUntilEnd, () {
        _showSessionEndNotification(session);
        _scheduleAutoMissedTimer(session);
      });

      print(
        '⏰ Заплановано сповіщення для сесії ${session.id} на ${sessionEndTime.toIso8601String()}',
      );
    } catch (e) {
      print('❌ Помилка планування сповіщення: $e');
    }
  }

  /// Запланувати автоматичну зміну статусу на "пропущено" через 15 хвилин після завершення
  void _scheduleAutoMissedTimer(Session session) {
    _autoMissedTimers[session.id!] = Timer(Duration(minutes: 15), () {
      _autoMarkAsMissed(session);
    });

    print(
      '⏰ Заплановано автоматичну зміну статусу на "пропущено" для сесії ${session.id} через 15 хвилин',
    );
  }

  /// Показати сповіщення про завершення сесії
  Future<void> _showSessionEndNotification(Session session) async {
    // Отримуємо ім'я майстрині
    final masterName = await _getMasterName(session.masterId);

    // Локалізовані тексти
    final title =
        _languageProvider?.getText('⏰ Сеанс завершен', '⏰ Сеанс завершен') ??
        '⏰ Сеанс завершен';
    final updateStatusText =
        _languageProvider?.getText(
          'Будь ласка, оновіть статус запису',
          'Пожалуйста, обновите статус записи',
        ) ??
        'Будь ласка, оновіть статус запису';
    final masterText =
        _languageProvider?.getText('Майстриня', 'Мастерица') ?? 'Майстриня';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'session_end_channel',
          'Завершення сесій',
          channelDescription: 'Сповіщення про завершення сесій',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body =
        '${session.clientName} - ${session.service}\n$masterText: $masterName\n$updateStatusText';

    await _flutterLocalNotificationsPlugin.show(
      session.id.hashCode,
      title,
      body,
      details,
    );

    print(
      '📱 Показано сповіщення про завершення сесії для ${session.clientName} у майстрині $masterName',
    );
  }

  /// Автоматично позначити сесію як пропущену
  Future<void> _autoMarkAsMissed(Session session) async {
    try {
      // Перевіряємо поточний статус сесії
      final currentSession = await _firestoreService.getSessionById(
        session.id!,
      );

      if (currentSession != null && currentSession.status == 'в очікуванні') {
        // Оновлюємо статус на "пропущено"
        final updatedSession = Session(
          id: currentSession.id,
          masterId: currentSession.masterId,
          clientId: currentSession.clientId,
          clientName: currentSession.clientName,
          phone: currentSession.phone,
          service: currentSession.service,
          duration: currentSession.duration,
          date: currentSession.date,
          time: currentSession.time,
          notes: currentSession.notes,
          price: currentSession.price,
          isRegularClient: currentSession.isRegularClient,
          status: 'пропущено',
        );

        await _firestoreService.updateSession(
          currentSession.id!,
          updatedSession,
        );

        // Показуємо сповіщення про автоматичну зміну статусу
        await _showAutoMissedNotification(session);

        print(
          '🔄 Автоматично змінено статус сесії ${session.id} на "пропущено"',
        );
      } else {
        print(
          'ℹ️ Сесія ${session.id} вже має статус "${currentSession?.status}", пропускаємо автоматичну зміну',
        );
      }
    } catch (e) {
      print('❌ Помилка автоматичної зміни статусу: $e');
    }
  }

  /// Показати сповіщення про автоматичну зміну статусу на "пропущено"
  Future<void> _showAutoMissedNotification(Session session) async {
    // Отримуємо ім'я майстрині
    final masterName = await _getMasterName(session.masterId);

    // Локалізовані тексти
    final title =
        _languageProvider?.getText(
          '🔄 Статус запису: "Пропущено"',
          '🔄 Статус записи: "Пропущено"',
        ) ??
        '🔄 Статус запису: "Пропущено"';
    final statusChangedText =
        _languageProvider?.getText(
          'Статус змінено на "Пропущено"',
          'Статус изменен на "Пропущено"',
        ) ??
        'Статус змінено на "Пропущено"';
    final masterText =
        _languageProvider?.getText('Майстриня', 'Мастерица') ?? 'Майстриня';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'auto_missed_channel',
          'Автоматичні зміни статусу',
          channelDescription: 'Сповіщення про автоматичні зміни статусу сесій',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body =
        '${session.clientName} - ${session.service}\n$masterText: $masterName\n$statusChangedText';

    await _flutterLocalNotificationsPlugin.show(
      (session.id.hashCode + 1000), // Інший ID для уникнення конфліктів
      title,
      body,
      details,
    );

    print(
      '� Показано сповіщення про автоматичну зміну статусу для ${session.clientName} у майстрині $masterName',
    );
  }

  /// Скасувати таймери для сесії (коли статус змінюється вручну)
  void cancelSessionTimers(String sessionId) {
    _cancelSessionTimers(sessionId);
    print('⏹️ Скасовано таймери для сесії $sessionId');
  }

  void _cancelSessionTimers(String sessionId) {
    _sessionTimers[sessionId]?.cancel();
    _sessionTimers.remove(sessionId);

    _autoMissedTimers[sessionId]?.cancel();
    _autoMissedTimers.remove(sessionId);
  }

  /// Запланувати сповіщення для всіх активних сесій
  Future<void> scheduleNotificationsForActiveSessions(
    List<Session> sessions,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Фільтруємо тільки сесії на сьогодні та в майбутньому зі статусом "в очікуванні"
    final activeSessions = sessions.where((session) {
      try {
        final sessionDate = DateTime.parse(session.date);
        final sessionDateTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
        );

        return (sessionDateTime.isAtSameMomentAs(today) ||
                sessionDateTime.isAfter(today)) &&
            session.status == 'в очікуванні';
      } catch (e) {
        return false;
      }
    }).toList();

    print(
      '📅 Планування сповіщень для ${activeSessions.length} активних сесій',
    );

    for (final session in activeSessions) {
      scheduleSessionEndNotification(session);
    }
  }

  DateTime _parseSessionDateTime(Session session) {
    final dateParts = session.date.split('-');
    final timeParts = session.time.split(':');

    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  /// Очистити всі таймери (при закритті додатку)
  void dispose() {
    for (final timer in _sessionTimers.values) {
      timer.cancel();
    }
    for (final timer in _autoMissedTimers.values) {
      timer.cancel();
    }

    _sessionTimers.clear();
    _autoMissedTimers.clear();

    print('🧹 Очищено всі таймери сповіщень');
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
