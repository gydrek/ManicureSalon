import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/models.dart';
import '../providers/language_provider.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  LanguageProvider? _languageProvider;

  /// Ініціалізація FCM сервісу
  Future<void> initialize({LanguageProvider? languageProvider}) async {
    _languageProvider = languageProvider;
    
    try {
      // Запитуємо дозволи для сповіщень
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM дозволи надано');
      } else {
        print('❌ FCM дозволи відхилено');
        return;
      }

      // Отримуємо FCM токен
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        print('📱 FCM токен отримано: ${_fcmToken!.substring(0, 20)}...');
        await _saveTokenToFirestore();
      }

      // Налаштовуємо обробники повідомлень
      _setupMessageHandlers();

      // Налаштовуємо локальні сповіщення для обробки FCM
      await _setupLocalNotifications();

      print('🚀 FCM сервіс ініціалізовано');
    } catch (e) {
      print('❌ Помилка ініціалізації FCM: $e');
    }
  }

  /// Зберігаємо токен пристрою в Firestore
  Future<void> _saveTokenToFirestore() async {
    if (_fcmToken == null) return;

    try {
      final deviceInfo = {
        'token': _fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Зберігаємо токен в колекції device_tokens
      await _firestore
          .collection('device_tokens')
          .doc(_fcmToken)
          .set(deviceInfo, SetOptions(merge: true));

      print('💾 Токен збережено в Firestore');
    } catch (e) {
      print('❌ Помилка збереження токена: $e');
    }
  }

  /// Налаштовуємо обробники FCM повідомлень
  void _setupMessageHandlers() {
    // Коли застосунок відкритий і приходить повідомлення
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 FCM повідомлення отримано (foreground): ${message.messageId}');
      _handleMessage(message);
    });

    // Коли користувач натискає на сповіщення
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 FCM повідомлення відкрито: ${message.messageId}');
      _handleMessageTap(message);
    });

    // Перевіряємо чи застосунок був відкритий через сповіщення
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 Застосунок відкрито через FCM: ${message.messageId}');
        _handleMessageTap(message);
      }
    });
  }

  /// Налаштовуємо локальні сповіщення для відображення FCM
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/notification_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(initializationSettings);
  }

  /// Обробка FCM повідомлення коли застосунок відкритий
  void _handleMessage(RemoteMessage message) {
    // Показуємо локальне сповіщення
    _showLocalNotification(message);
  }

  /// Обробка натискання на FCM сповіщення
  void _handleMessageTap(RemoteMessage message) {
    // Тут можна додати навігацію до конкретного екрану
    // Наприклад, відкрити сесію з певним ID
    
    final sessionId = message.data['sessionId'];
    if (sessionId != null) {
      print('🎯 Перехід до сесії: $sessionId');
      // TODO: Додати навігацію до sessionEdit або іншого екрану
    }
  }

  /// Показуємо локальне сповіщення для FCM повідомлення
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'Сповіщення';
    final body = notification.body ?? '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'fcm_channel',
          'FCM Сповіщення',
          channelDescription: 'Сповіщення з сервера',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: '',
          ),
        ),
        iOS: DarwinNotificationDetails(
          subtitle: _getSubtitleForNotificationType(message.data['type']),
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  /// Отримуємо підзаголовок для iOS на основі типу сповіщення
  String _getSubtitleForNotificationType(String? type) {
    switch (type) {
      case 'session_reminder':
        return 'Нагадування про запис';
      case 'session_end':
        return 'Сесія завершена';
      case 'auto_missed':
        return 'Автоматично пропущено';
      default:
        return 'Сповіщення';
    }
  }



  /// Відправляємо FCM повідомлення про новий запис
  Future<void> sendSessionReminderNotification({
    required Session session,
    required String masterName,
    required DateTime reminderTime,
  }) async {
    print('📱 FCM: Створюємо нагадування для сесії ${session.id}');
    
    // Перевіряємо статус сесії
    if (session.status != 'в очікуванні') {
      print('⚠️ FCM: Пропускаємо створення сповіщення - статус: ${session.status}');
      return;
    }
    
    try {
      // Локалізований текст
      final title = _languageProvider?.getText(
        'Нагадування про запис', 
        'Напоминание о записи'
      ) ?? 'Нагадування про запис';
      
      final bodyText = _languageProvider?.getText(
        'Через 30 хвилин: ${session.clientName} у майстрині $masterName',
        'Через 30 минут: ${session.clientName} у мастрицы $masterName'
      ) ?? 'Через 30 хвилин: ${session.clientName} у майстрині $masterName';

      // Перевіряємо, чи є sessionId
      if (session.id == null) {
        print('❌ ПОМИЛКА: session.id є null! Не можна створити FCM сповіщення');
        return;
      }

      print('✅ Створюємо FCM сповіщення з sessionId: ${session.id}');

      final notificationData = {
        'type': 'session_reminder',
        'sessionId': session.id,
        'title': title,
        'body': bodyText,
        'reminderTime': reminderTime.toIso8601String(),
        'sessionTime': session.time,
        'sessionDate': session.date,
        'clientName': session.clientName,
        'masterName': masterName,
        'service': session.service,
      };

      // Зберігаємо в колекцію scheduled_notifications для обробки Cloud Function
      await _firestore.collection('scheduled_notifications').add({
        ...notificationData,
        'scheduledFor': Timestamp.fromDate(reminderTime),
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('📅 FCM сповіщення заплановано на $reminderTime');
    } catch (e) {
      print('❌ Помилка планування FCM сповіщення: $e');
    }
  }





  /// Оновлюємо заплановані FCM сповіщення для сесії
  Future<void> updateSessionNotifications({
    required Session session,
    required String masterName,
  }) async {
    try {
      // Перевіряємо статус сесії
      if (session.status != 'в очікуванні') {
        print('🗑️ Видаляємо сповіщення для сесії ${session.id} - статус змінено на: ${session.status}');
        await cancelSessionNotifications(session.id!);
        return;
      }

      // Знаходимо всі незаплановані сповіщення для цієї сесії
      final notifications = await _firestore
          .collection('scheduled_notifications')
          .where('sessionId', isEqualTo: session.id)
          .where('processed', isEqualTo: false)
          .get();

      if (notifications.docs.isEmpty) {
        // Якщо сповіщень немає, створюємо нове (тільки якщо статус "в очікуванні")
        print('📅 Сповіщень для сесії ${session.id} не знайдено, створюємо нове');
        await sendSessionReminderNotification(
          session: session,
          masterName: masterName,
          reminderTime: DateTime.parse('${session.date} ${session.time}:00')
              .subtract(const Duration(minutes: 30)),
        );
        return;
      }

      // Оновлюємо існуючі сповіщення
      for (final doc in notifications.docs) {
        final newReminderTime = DateTime.parse('${session.date} ${session.time}:00')
            .subtract(const Duration(minutes: 30));

        // Перевіряємо, чи нове сповіщення ще актуальне
        if (newReminderTime.isAfter(DateTime.now())) {
          // Локалізований текст
          final title = _languageProvider?.getText(
            'Нагадування про запис', 
            'Напоминание о записи'
          ) ?? 'Нагадування про запис';
          
          final bodyText = _languageProvider?.getText(
            'Через 30 хвилин: ${session.clientName} у майстрині $masterName',
            'Через 30 минут: ${session.clientName} у мастрицы $masterName'
          ) ?? 'Через 30 хвилин: ${session.clientName} у майстрині $masterName';

          // Оновлюємо існуюче сповіщення
          await doc.reference.update({
            'title': title,
            'body': bodyText,
            'reminderTime': newReminderTime.toIso8601String(),
            'scheduledFor': Timestamp.fromDate(newReminderTime),
            'sessionTime': session.time,
            'sessionDate': session.date,
            'clientName': session.clientName,
            'masterName': masterName,
            'service': session.service,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✏️ Оновлено сповіщення ${doc.id} для сесії ${session.id}');
        } else {
          // Якщо час вже минув, видаляємо старе сповіщення
          await doc.reference.delete();
          print('🗑️ Видалено застаріле сповіщення ${doc.id} для сесії ${session.id}');
        }
      }

      print('✅ FCM сповіщення для сесії ${session.id} оновлено');
    } catch (e) {
      print('❌ Помилка оновлення FCM сповіщень: $e');
    }
  }

  /// Оновлюємо існуюче сповіщення для сесії замість створення нового
  Future<void> updateSessionReminderNotification({
    required Session session,
    required String masterName,
    required DateTime reminderTime,
  }) async {
    print('🔄 FCM: Оновлюємо нагадування для сесії ${session.id}');
    try {
      // Спочатку знаходимо існуюче сповіщення для цієї сесії
      final existingNotifications = await _firestore
          .collection('scheduled_notifications')
          .where('sessionId', isEqualTo: session.id)
          .where('type', isEqualTo: 'session_reminder')
          .where('processed', isEqualTo: false)
          .get();

      // Локалізований текст
      final title = _languageProvider?.getText(
        'Нагадування про запис', 
        'Напоминание о записи'
      ) ?? 'Нагадування про запис';
      
      final bodyText = _languageProvider?.getText(
        'Через 30 хвилин: ${session.clientName} у майстра $masterName',
        'Через 30 минут: ${session.clientName} у мастера $masterName'
      ) ?? 'Через 30 хвилин: ${session.clientName} у майстра $masterName';

      final notificationData = {
        'type': 'session_reminder',
        'sessionId': session.id,
        'title': title,
        'body': bodyText,
        'reminderTime': reminderTime.toIso8601String(),
        'sessionTime': session.time,
        'sessionDate': session.date,
        'clientName': session.clientName,
        'masterName': masterName,
        'service': session.service,
        'scheduledFor': Timestamp.fromDate(reminderTime),
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (existingNotifications.docs.isNotEmpty) {
        // Оновлюємо існуюче сповіщення
        final existingDoc = existingNotifications.docs.first;
        await existingDoc.reference.update(notificationData);
        print('🔄 Оновлено існуюче FCM сповіщення ${existingDoc.id} на $reminderTime');
      } else {
        // Створюємо нове сповіщення якщо немає існуючого
        await _firestore.collection('scheduled_notifications').add(notificationData);
        print('📅 Створено нове FCM сповіщення на $reminderTime');
      }
    } catch (e) {
      print('❌ Помилка оновлення FCM сповіщення: $e');
    }
  }

  /// Скасовуємо заплановані FCM сповіщення для сесії
  Future<void> cancelSessionNotifications(String sessionId) async {
    try {
      // Знаходимо всі незаплановані сповіщення для цієї сесії
      final notifications = await _firestore
          .collection('scheduled_notifications')
          .where('sessionId', isEqualTo: sessionId)
          .where('processed', isEqualTo: false)
          .get();

      // ОНОВЛЕНО: Видаляємо сповіщення повністю замість позначення cancelled
      for (final doc in notifications.docs) {
        await doc.reference.delete();
        print('🗑️ Видалено сповіщення ${doc.id} для сесії $sessionId');
      }

      print('🗑️ FCM сповіщення для сесії $sessionId скасовано');
    } catch (e) {
      print('❌ Помилка скасування FCM сповіщень: $e');
    }
  }

  /// Отримуємо поточний FCM токен
  String? get fcmToken => _fcmToken;

  /// Оновлюємо токен при зміні
  Future<void> refreshToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        await _saveTokenToFirestore();
        print('🔄 FCM токен оновлено');
      }
    } catch (e) {
      print('❌ Помилка оновлення FCM токена: $e');
    }
  }

  /// Відписуємося від FCM при виході з застосунку
  Future<void> dispose() async {
    try {
      if (_fcmToken != null) {
        // Позначаємо токен як неактивний
        await _firestore
            .collection('device_tokens')
            .doc(_fcmToken)
            .update({'isActive': false});
      }
    } catch (e) {
      print('❌ Помилка деактивації FCM токена: $e');    
    }
  }
}