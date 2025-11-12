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
  // ТИМЧАСОВО ЗАКОМЕНТОВАНО: LanguageProvider? _languageProvider;

  /// Ініціалізація FCM сервісу
  Future<void> initialize({LanguageProvider? languageProvider}) async {
    // ТИМЧАСОВО ЗАКОМЕНТОВАНО: _languageProvider = languageProvider;
    
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
    try {
      final notificationData = {
        'type': 'session_reminder',
        'sessionId': session.id,
        'title': 'Нагадування про запис',
        'body': 'Через 30 хвилин: ${session.clientName} у майстра $masterName',
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

  /// Відправляємо FCM повідомлення про завершення сесії
  Future<void> sendSessionEndNotification({
    required Session session,
    required String masterName,
    required DateTime endTime,
  }) async {
    try {
      final notificationData = {
        'type': 'session_end',
        'sessionId': session.id,
        'title': '⏰ Сеанс завершен',
        'body': '${session.clientName} - ${session.service}\nМайстриня: $masterName\nБудь ласка, оновіть статус запису',
        'endTime': endTime.toIso8601String(),
        'sessionTime': session.time,
        'sessionDate': session.date,
        'clientName': session.clientName,
        'masterName': masterName,
        'service': session.service,
      };

      // Зберігаємо в колекцію scheduled_notifications для обробки Cloud Function
      await _firestore.collection('scheduled_notifications').add({
        ...notificationData,
        'scheduledFor': Timestamp.fromDate(endTime),
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('📅 FCM сповіщення про завершення заплановано на $endTime');
    } catch (e) {
      print('❌ Помилка планування FCM сповіщення про завершення: $e');
    }
  }

  /// Відправляємо FCM повідомлення про автоматичне пропущення
  Future<void> sendAutoMissedNotification({
    required Session session,
    required String masterName,
    required DateTime missedTime,
  }) async {
    try {
      final notificationData = {
        'type': 'auto_missed',
        'sessionId': session.id,
        'title': '❌ Запис пропущено',
        'body': '${session.clientName} - ${session.service}\nМайстриня: $masterName\nЗапис автоматично позначено як пропущений',
        'missedTime': missedTime.toIso8601String(),
        'sessionTime': session.time,
        'sessionDate': session.date,
        'clientName': session.clientName,
        'masterName': masterName,
        'service': session.service,
      };

      // Зберігаємо в колекцію scheduled_notifications для обробки Cloud Function
      await _firestore.collection('scheduled_notifications').add({
        ...notificationData,
        'scheduledFor': Timestamp.fromDate(missedTime),
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('📅 FCM сповіщення про автопропущення заплановано на $missedTime');
    } catch (e) {
      print('❌ Помилка планування FCM сповіщення про автопропущення: $e');
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

      // Позначаємо їх як скасовані
      for (final doc in notifications.docs) {
        await doc.reference.update({
          'cancelled': true,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
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