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
import 'fcm_service.dart';

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

    // Очищаємо старі заплановані сповіщення
    await cleanupOldScheduledNotifications();

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

    // Канал для запланованих сповіщень про завершення сесій
    const AndroidNotificationChannel sessionEndScheduledChannel =
        AndroidNotificationChannel(
          'session_end_scheduled',
          'Завершення сесій (заплановані)',
          description: 'Заплановані сповіщення про завершення сесій',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

    // Канал для запланованих сповіщень про автоматично пропущені сесії
    const AndroidNotificationChannel autoMissedScheduledChannel =
        AndroidNotificationChannel(
          'auto_missed_scheduled',
          'Автоматично пропущені (заплановані)',
          description: 'Заплановані сповіщення про автоматично пропущені сесії',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

    try {
      await androidImplementation.createNotificationChannel(sessionChannel);
      await androidImplementation.createNotificationChannel(testChannel);
      await androidImplementation.createNotificationChannel(simpleTestChannel);
      await androidImplementation.createNotificationChannel(sessionEndScheduledChannel);
      await androidImplementation.createNotificationChannel(autoMissedScheduledChannel);

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

  /// Отримати локалізовану назву послуги
  String _getLocalizedService(String service) {
    if (_languageProvider == null) return service;
    
    switch (service) {
      case 'Манікюр класичний':
        return _languageProvider!.getText('Манікюр класичний', 'Маникюр классический');
      case 'Покриття гель-лак (руки)':
        return _languageProvider!.getText('Покриття гель-лак (руки)', 'Покрытие гель-лак (руки)');
      case 'Манікюр':
        return _languageProvider!.getText('Манікюр', 'Маникюр');
      case 'Нарощування нігтів (стандарт)':
        return _languageProvider!.getText('Нарощування нігтів (стандарт)', 'Наращивание ногтей (стандарт)');
      case 'Нарощування нігтів (довге)':
        return _languageProvider!.getText('Нарощування нігтів (довге)', 'Наращивание ногтей (длинное)');
      case 'Манікюр чоловічий':
        return _languageProvider!.getText('Манікюр чоловічий', 'Маникюр мужской');
      case 'Педикюр класичний':
        return _languageProvider!.getText('Педикюр класичний', 'Педикюр классический');
      case 'Педикюр класичний + покриття гель-лак':
        return _languageProvider!.getText('Педикюр класичний + покриття гель-лак', 'Педикюр классический + покрытие гель-лак');
      case 'Покриття гель-лак (ноги)':
        return _languageProvider!.getText('Покриття гель-лак (ноги)', 'Покрытие гель-лак (ноги)');
      case 'Нарощування вій':
        return _languageProvider!.getText('Нарощування вій', 'Наращивание ресниц');
      case 'Нарощування нижніх вій':
        return _languageProvider!.getText('Нарощування нижніх вій', 'Наращивание нижних ресниц');
      case 'Ремонт':
        return _languageProvider!.getText('Ремонт', 'Ремонт');
      default:
        return service;
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

    // Формуємо текст сповіщення
    final title = 'Нагадування про запис';
    final body = 'Через 30 хвилин: $clientName у майстра $masterName';

    // Налаштування для Android
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'session_reminders',
          'Нагадування про записи',
          channelDescription: 'Сповіщення про майбутні записи клієнток',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/notification_icon',
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: '',
          ),
        );

    // Налаштування для iOS
    final DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          subtitle: 'Нагадування про запис',
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

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

      // Також плануємо через FCM для синхронізації між пристроями
      try {
        // Створюємо мінімальну Session для FCM (з обов'язковими полями)
        final sessionForFCM = Session(
          id: sessionId,
          masterId: masterId,
          clientId: 'unknown', // Поки не маємо clientId в цьому контексті
          clientName: clientName,
          service: 'Запис', // Загальна назва
          duration: 60, // Стандартна тривалість
          date: DateTime.now().toIso8601String().split('T')[0], // Поточна дата як заглушка
          time: DateTime.now().toIso8601String().split('T')[1].substring(0, 5), // Поточний час як заглушка
          status: 'в очікуванні',
        );

        await FCMService().sendSessionReminderNotification(
          session: sessionForFCM,
          masterName: masterName,
          reminderTime: notificationTime,
        );
        if (kDebugMode) {
          print('✅ FCM сповіщення також заплановано');
        }
      } catch (e) {
        print('⚠️ Помилка планування FCM сповіщення: $e');
        // Не падаємо, локальне сповіщення все одно працює
      }

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

    // Також скасовуємо FCM сповіщення
    try {
      await FCMService().cancelSessionNotifications(sessionId);
      if (kDebugMode) {
        print('✅ FCM сповіщення також скасовано');
      }
    } catch (e) {
      print('⚠️ Помилка скасування FCM сповіщення: $e');
    }

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
      return settings?.isEnabled == true;
    }
    return false;
  }

  /// Очистити старі заплановані сповіщення при запуску застосунку
  Future<void> cleanupOldScheduledNotifications() async {
    try {
      final pendingNotifications = await getPendingNotifications();

      for (final notification in pendingNotifications) {
        // Перевіряємо чи це наші заплановані сповіщення
        if (notification.payload?.startsWith('session_end_') == true || 
            notification.payload?.startsWith('auto_missed_') == true) {
          
          // Можна додати логіку для перевірки чи сесія ще актуальна
          // Наразі просто виводимо інформацію
          print('📋 Знайдено заплановане сповіщення: ${notification.title} (ID: ${notification.id})');
        }
      }

      print('🧹 Перевірка старих запланованих сповіщень завершена. Знайдено: ${pendingNotifications.length}');
    } catch (e) {
      print('❌ Помилка очищення старих сповіщень: $e');
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'test_notifications',
          'Тестові сповіщення',
          channelDescription: 'Канал для тестових сповіщень',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/notification_icon',
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: '',
          ),
        );

    final DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          subtitle: 'Миттєве сповіщення',
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
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

      // Плануємо сповіщення про завершення сесії (Timer - працює тільки поки застосунок активний)
      final timeUntilEnd = sessionEndTime.difference(now);
      _sessionTimers[session.id!] = Timer(timeUntilEnd, () {
        _showSessionEndNotification(session);
        _scheduleAutoMissedTimer(session);
      });

      // ДОДАТКОВО: Плануємо реальне сповіщення через flutter_local_notifications
      // Це сповіщення спрацює навіть якщо застосунок закритий
      _scheduleRealSessionEndNotification(session, sessionEndTime);

      // Плануємо також сповіщення про автоматичне пропущення через 15 хвилин після завершення
      final autoMissedTime = sessionEndTime.add(Duration(minutes: 15));
      _scheduleRealAutoMissedNotification(session, autoMissedTime);

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

  /// Запланувати реальне сповіщення про завершення сесії (працює навіть коли застосунок закритий)
  Future<void> _scheduleRealSessionEndNotification(Session session, DateTime sessionEndTime) async {
    try {
      final masterName = await _getMasterName(session.masterId);
      final localizedService = _getLocalizedService(session.service);
      
      final title = _languageProvider?.getText('⏰ Сеанс завершен', '⏰ Сеанс завершен') ?? '⏰ Сеанс завершен';
      final body = '${session.clientName} - $localizedService\nМайстриня: $masterName\nБудь ласка, оновіть статус запису';
      
      final scheduledTime = tz.TZDateTime.from(sessionEndTime, tz.local);
      final notificationId = session.id.hashCode + 2000; // Унікальний ID для планованих сповіщень

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'session_end_scheduled',
            'Завершення сесій (заплановані)',
            channelDescription: 'Заплановані сповіщення про завершення сесій',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: '',
            ),
          ),
          iOS: DarwinNotificationDetails(
            subtitle: 'Сесія завершена',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'session_end_${session.id}',
      );

      print('📅 Заплановано реальне сповіщення про завершення сесії ${session.id} на $sessionEndTime');
    } catch (e) {
      print('❌ Помилка планування реального сповіщення: $e');
    }
  }

  /// Запланувати реальне сповіщення про автоматичне пропущення (працює навіть коли застосунок закритий)
  Future<void> _scheduleRealAutoMissedNotification(Session session, DateTime autoMissedTime) async {
    try {
      final masterName = await _getMasterName(session.masterId);
      final localizedService = _getLocalizedService(session.service);
      
      final title = _languageProvider?.getText('❌ Запис пропущено', '❌ Запись пропущена') ?? '❌ Запис пропущено';
      final body = '${session.clientName} - $localizedService\nМайстриня: $masterName\nЗапис автоматично позначено як пропущений';
      
      final scheduledTime = tz.TZDateTime.from(autoMissedTime, tz.local);
      final notificationId = session.id.hashCode + 3000; // Унікальний ID для auto-missed сповіщень

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'auto_missed_scheduled',
            'Автоматично пропущені (заплановані)',
            channelDescription: 'Заплановані сповіщення про автоматично пропущені сесії',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: '',
            ),
          ),
          iOS: DarwinNotificationDetails(
            subtitle: 'Автоматично пропущено',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'auto_missed_${session.id}',
      );

      print('📅 Заплановано реальне сповіщення про автоматичне пропущення сесії ${session.id} на $autoMissedTime');
    } catch (e) {
      print('❌ Помилка планування реального auto-missed сповіщення: $e');
    }
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

    final localizedService = _getLocalizedService(session.service);
    final body =
        '${session.clientName} - $localizedService\n$masterText: $masterName\n$updateStatusText';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'session_end_channel',
          'Завершення сесій',
          channelDescription: 'Сповіщення про завершення сесій',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: '',
          ),
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      subtitle: 'Сесія завершена',
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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

      if (currentSession == null) {
        print('ℹ️ Сесія ${session.id} більше не існує (видалена), пропускаємо автоматичну зміну статусу');
        return;
      }

      if (currentSession.status == 'в очікуванні') {
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
          'ℹ️ Сесія ${session.id} вже має статус "${currentSession.status}", пропускаємо автоматичну зміну',
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
          '🔴 Статус запису: "Пропущено"',
          '🔴 Статус записи: "Пропущено"',
        ) ??
        '🔴 Статус запису: "Пропущено"';
    final statusChangedText =
        _languageProvider?.getText(
          'Статус змінено на "Пропущено"',
          'Статус изменен на "Пропущено"',
        ) ??
        'Статус змінено на "Пропущено"';
    final masterText =
        _languageProvider?.getText('Майстриня', 'Мастерица') ?? 'Майстриня';

    final localizedService = _getLocalizedService(session.service);
    final body =
        '${session.clientName} - $localizedService\n$masterText: $masterName\n$statusChangedText';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'auto_missed_channel',
          'Автоматично пропущені',
          channelDescription: 'Сповіщення про автоматично пропущені сесії',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: '',
          ),
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      subtitle: 'Автоматично пропущено',
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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
    // Скасовуємо таймери
    _sessionTimers[sessionId]?.cancel();
    _sessionTimers.remove(sessionId);

    _autoMissedTimers[sessionId]?.cancel();
    _autoMissedTimers.remove(sessionId);

    // Скасовуємо заплановані сповіщення
    _cancelScheduledNotifications(sessionId);
  }

  /// Скасувати заплановані сповіщення для сесії
  Future<void> _cancelScheduledNotifications(String sessionId) async {
    try {
      // Скасовуємо сповіщення про завершення сесії
      final sessionEndNotificationId = sessionId.hashCode + 2000;
      await _flutterLocalNotificationsPlugin.cancel(sessionEndNotificationId);

      // Скасовуємо сповіщення про автоматичне пропущення
      final autoMissedNotificationId = sessionId.hashCode + 3000;
      await _flutterLocalNotificationsPlugin.cancel(autoMissedNotificationId);

      print('🗑️ Скасовано заплановані сповіщення для сесії $sessionId');
    } catch (e) {
      print('❌ Помилка скасування запланованих сповіщень: $e');
    }
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

  /// Отримати інформацію про активні таймери (для debug)
  Map<String, dynamic> getTimersInfo() {
    return {
      'sessionTimers': _sessionTimers.keys.toList(),
      'autoMissedTimers': _autoMissedTimers.keys.toList(),
      'totalSessionTimers': _sessionTimers.length,
      'totalAutoMissedTimers': _autoMissedTimers.length,
    };
  }

  Future<void> showSimpleTest() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Показуємо миттєве сповіщення
    const title = 'Простий тест';
    const body = 'Якщо бачите це - сповіщення працюють!';
    
    await _flutterLocalNotificationsPlugin.show(
      999,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'test_simple',
          'Простий тест',
          channelDescription: 'Канал для простого тесту',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: '',
          ),
        ),
        iOS: DarwinNotificationDetails(
          subtitle: 'Тестове сповіщення',
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );

    // Також плануємо тестове сповіщення через 1 хвилину
    try {
      final testTime = DateTime.now().add(Duration(minutes: 1));
      final scheduledTime = tz.TZDateTime.from(testTime, tz.local);

      const scheduledTitle = 'Заплановане тестове сповіщення';
      const scheduledBody = 'Це сповіщення було заплановано на 1 хвилину!';
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        998, // Інший ID для запланованого тесту
        scheduledTitle,
        scheduledBody,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'test_simple',
            'Простий тест',
            channelDescription: 'Канал для простого тесту',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              scheduledBody,
              contentTitle: scheduledTitle,
              summaryText: '',
            ),
          ),
          iOS: DarwinNotificationDetails(
            subtitle: 'Заплановане тестове сповіщення',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
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
