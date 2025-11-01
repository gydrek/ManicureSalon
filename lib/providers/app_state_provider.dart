import 'package:flutter/foundation.dart';
import 'package:nastya_app/models/models.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/services/notification_service.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'dart:async';

/// Глобальний провайдер стану для всього додатку
/// Централізує управління даними та оновленнями
class AppStateProvider extends ChangeNotifier {
  static final AppStateProvider _instance = AppStateProvider._internal();
  factory AppStateProvider() => _instance;
  AppStateProvider._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  LanguageProvider? _languageProvider;

  /// Встановити провайдер мови для локалізації
  void setLanguageProvider(LanguageProvider languageProvider) {
    _languageProvider = languageProvider;

    // Слухаємо зміни мови і оновлюємо дані при зміні
    languageProvider.addListener(() {
      _calculateNextSessions(); // Перерахунок з новою мовою
      notifyListeners();
    });
  }

  // ===== СТАН ДАНИХ =====
  List<Master> _masters = [];
  List<Client> _clients = [];
  Map<String, List<Session>> _sessionsByMaster = {}; // masterId -> sessions
  Map<String, String> _nextSessionsByMaster =
      {}; // masterId -> next session info

  bool _isLoading = false;
  DateTime _lastUpdate = DateTime.now();
  Timer? _autoUpdateTimer;
  int _lastSessionCount = 0; // Кількість сесій при останньому оновленні

  // Розширене кешування для оптимізації БД запитів
  static const Duration _cacheTTL = Duration(minutes: 4); // Збалансований TTL для синхронізації та економії
  static const Duration _longCacheTTL = Duration(
    minutes: 10,
  ); // Для майстрів (збалансовано)
  DateTime? _lastDataLoad;
  DateTime? _lastMastersLoad;
  DateTime? _lastClientsLoad;
  bool _cacheInvalidated = false; // Прапор інвалідації кешу
  String _cacheVersion = '1.0'; // Версія кешу для інвалідації при оновленнях

  // ===== ГЕТТЕРИ =====
  List<Master> get masters => _masters;
  List<Client> get clients => _clients;
  Map<String, List<Session>> get sessionsByMaster => _sessionsByMaster;
  Map<String, String> get nextSessionsByMaster => _nextSessionsByMaster;
  bool get isLoading => _isLoading;
  DateTime get lastUpdate => _lastUpdate;
  int get lastSessionCount => _lastSessionCount;

  // ===== КЕШИРУВАННЯ =====
  /// Інвалідувати кеш (викликати після CRUD операцій)
  void invalidateCache() {
    print('🔄 Інвалідуємо кеш AppStateProvider - наступний запит буде свіжим');
    _cacheInvalidated = true; // Позначаємо кеш як інвалідований
    _lastDataLoad = null; // Скидаємо час останнього завантаження сесій
    _lastClientsLoad = null; // Скидаємо кеш клієнтів
    // Майстрів не скидаємо, оскільки вони рідко змінюються
    _cacheVersion =
        '${DateTime.now().millisecondsSinceEpoch}'; // Нова версія кешу
    notifyListeners();
  }

  /// Примусово оновити тільки клієнтів (обходимо кеш)
  Future<void> refreshClientsOnly() async {
    try {
      print('🔄 Примусово оновлюємо клієнтів...');
      _lastClientsLoad = null; // Скидаємо кеш клієнтів
      final clients = await _firestoreService.getClients();
      _clients = clients;
      _lastClientsLoad = DateTime.now();
      print('✅ Клієнти оновлені: ${clients.length}');
      notifyListeners();
    } catch (e) {
      print('❌ Помилка оновлення клієнтів: $e');
    }
  }

  /// Повністю очистити кеш (використовувати при критичних оновленнях)
  void clearAllCache() {
    print('🧹 Повністю очищуємо весь кеш AppStateProvider');
    _cacheInvalidated = true;
    _lastDataLoad = null;
    _lastMastersLoad = null;
    _lastClientsLoad = null;
    _cacheVersion = '${DateTime.now().millisecondsSinceEpoch}';
    notifyListeners();
  }

  // ===== ІНІЦІАЛІЗАЦІЯ =====
  Future<void> initialize() async {
    print('🚀 Ініціалізуємо AppStateProvider');

    // Завантажуємо початкові дані
    await refreshAllData();

    // ОПТИМІЗОВАНО: Збалансоване автооновлення для синхронізації та економії БД
    _autoUpdateTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (!_isLoading) {
        print('⏰ Автооновлення (кожні 5 хв - збалансована синхронізація)...');
        refreshAllData(forceRefresh: false); // Використовуємо кеш, якщо можливо
      }
    });

    print('✅ AppStateProvider ініціалізовано');
  }

  // ===== ОСНОВНІ МЕТОДИ =====

  /// Оновити всі дані (майстри, клієнти, сесії) з інтелектуальним кешуванням
  Future<void> refreshAllData({bool forceRefresh = false}) async {
    if (_isLoading) return; // Уникаємо подвійних завантажень

    // Інтелектуальна перевірка кешу для сесій
    bool needsSessionReload =
        forceRefresh ||
        _cacheInvalidated ||
        _lastDataLoad == null ||
        DateTime.now().difference(_lastDataLoad!) >= _cacheTTL;

    if (!needsSessionReload && _sessionsByMaster.isNotEmpty) {
      print(
        '📦 Використовуємо кешовані сесії (${DateTime.now().difference(_lastDataLoad!).inMinutes} хв тому)',
      );
      // Все ж таки перевіряємо майстрів і клієнтів окремо
      await _loadMasters();
      await _loadClients();
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      print('🔄 Оновлюємо дані з БД (кеш-версія: $_cacheVersion)...');

      // Завантажуємо паралельно з індивідуальним кешуванням
      await Future.wait([_loadMasters(), _loadClients(), _loadAllSessions(forceRefresh: forceRefresh)]);

      _lastUpdate = DateTime.now();
      _lastDataLoad = DateTime.now(); // Оновлюємо час завантаження
      _cacheInvalidated = false; // Скидуємо прапор інвалідації
      print(
        '✅ Дані оновлено з БД о ${_formatTime(_lastUpdate)} (майстри: ${_masters.length}, клієнти: ${_clients.length}, сесії: ${_sessionsByMaster.values.expand((s) => s).length})',
      );

      // Плануємо сповіщення для всіх активних сесій
      await _scheduleNotificationsForActiveSessions();
    } catch (e) {
      print('❌ Помилка оновлення даних: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Завантажити тільки майстрів
  Future<void> _loadMasters() async {
    try {
      // Перевіряємо кеш для майстрів (довгий TTL, оскільки рідко змінюються)
      if (_lastMastersLoad != null && _masters.isNotEmpty) {
        final timeSinceLoad = DateTime.now().difference(_lastMastersLoad!);
        if (timeSinceLoad < _longCacheTTL && !_cacheInvalidated) {
          print(
            '📦 Використовуємо кешованих майстрів (${timeSinceLoad.inMinutes} хв тому)',
          );
          return;
        }
      }

      final masters = await _firestoreService.getMasters();
      _masters = masters;
      _lastMastersLoad = DateTime.now();
      print('📋 Завантажено майстрів з БД: ${masters.length}');
    } catch (e) {
      print('❌ Помилка завантаження майстрів: $e');
    }
  }

  /// Завантажити тільки клієнтів
  Future<void> _loadClients() async {
    try {
      // Перевіряємо кеш для клієнтів
      if (_lastClientsLoad != null && _clients.isNotEmpty) {
        final timeSinceLoad = DateTime.now().difference(_lastClientsLoad!);
        if (timeSinceLoad < _cacheTTL && !_cacheInvalidated) {
          print(
            '📦 Використовуємо кешованих клієнтів (${timeSinceLoad.inMinutes} хв тому)',
          );
          return;
        }
      }

      final clients = await _firestoreService.getClients();
      _clients = clients;
      _lastClientsLoad = DateTime.now();
      print('👥 Завантажено клієнтів з БД: ${clients.length}');
    } catch (e) {
      print('❌ Помилка завантаження клієнтів: $e');
    }
  }

  /// Завантажити всі сесії поточного місяця
  Future<void> _loadAllSessions({bool forceRefresh = false}) async {
    try {
      // Перевіряємо кеш для сесій (короткий TTL, оскільки часто змінюються)
      if (!forceRefresh && _lastDataLoad != null && _sessionsByMaster.isNotEmpty) {
        final timeSinceLoad = DateTime.now().difference(_lastDataLoad!);
        if (timeSinceLoad < _cacheTTL && !_cacheInvalidated) {
          print(
            '📦 Використовуємо кешовані сесії (${timeSinceLoad.inMinutes} хв тому)',
          );
          return;
        }
      }
      
      if (forceRefresh) {
        print('🔥 ФОРСОВАНЕ оновлення сесій - обходимо кеш!');
      }

      final now = DateTime.now();
      print('🔄 Завантажуємо сесії з БД...');
      final sessions = await _firestoreService.getSessionsByMonth(
        now.year,
        now.month,
      );

      // Групуємо сесії по майстрах
      _sessionsByMaster.clear();
      for (final session in sessions) {
        if (!_sessionsByMaster.containsKey(session.masterId)) {
          _sessionsByMaster[session.masterId] = [];
        }
        _sessionsByMaster[session.masterId]!.add(session);
      }

      // Сортуємо сесії для кожного майстра
      for (final masterId in _sessionsByMaster.keys) {
        _sessionsByMaster[masterId]!.sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          return a.time.compareTo(b.time);
        });
      }

      // Обчислюємо наступні сесії
      _calculateNextSessions();

      // Детекція змін для синхронізації між пристроями
      if (_lastSessionCount != sessions.length) {
        print(
          '🔄 Виявлено зміни в кількості сесій: ${_lastSessionCount} → ${sessions.length}',
        );
        if (_lastSessionCount > 0) {
          // Не перший раз - є реальні зміни
          _cacheInvalidated = true; // Інвалідуємо кеш для форсованого оновлення на інших пристроях
        }
      }

      // Оновлюємо статистику
      _lastSessionCount = sessions.length;

      print(
        '📅 Завантажено сесій з БД: ${sessions.length} (кеш на $_cacheTTL хв)',
      );
    } catch (e) {
      print('❌ Помилка завантаження сесій: $e');
    }
  }

  /// Обчислити наступні сесії для всіх майстрів
  void _calculateNextSessions() {
    _nextSessionsByMaster.clear();

    final now = DateTime.now();
    final currentDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final master in _masters) {
      final masterId = master.id!;
      final sessions = _sessionsByMaster[masterId] ?? [];

      if (sessions.isEmpty) {
        _nextSessionsByMaster[masterId] =
            _languageProvider?.getText(
              'Немає будь-яких записів',
              'Нет каких-либо записей',
            ) ??
            'Немає будь-яких записів';
        continue;
      }

      // Знаходимо найближчу майбутню сесію
      final futureSessions = sessions.where((session) {
        if (session.date.compareTo(currentDate) > 0) {
          return true; // Майбутня дата
        } else if (session.date == currentDate) {
          return session.time.compareTo(currentTime) >
              0; // Майбутній час сьогодні
        }
        return false;
      }).toList();

      if (futureSessions.isEmpty) {
        _nextSessionsByMaster[masterId] =
            _languageProvider?.getText(
              'Немає майбутніх записів',
              'Нет будущих записей',
            ) ??
            'Немає майбутніх записів';
      } else {
        final nextSession = futureSessions.first;
        final sessionDate = DateTime.parse(nextSession.date);
        final formattedDate = _formatDateShort(sessionDate);
        _nextSessionsByMaster[masterId] =
            '${nextSession.clientName} - $formattedDate ${nextSession.time}';
      }
    }
  }

  // ===== МЕТОДИ ДЛЯ КОНКРЕТНИХ СТОРІНОК =====

  /// Отримати сесії майстра на конкретну дату
  List<Session> getSessionsForMasterAndDate(String masterId, String date) {
    final allSessions = _sessionsByMaster[masterId] ?? [];
    return allSessions.where((session) => session.date == date).toList();
  }

  /// Отримати всі сесії майстра
  List<Session> getSessionsForMaster(String masterId) {
    return _sessionsByMaster[masterId] ?? [];
  }

  /// Отримати наступну сесію майстра
  String getNextSessionForMaster(String masterId) {
    return _nextSessionsByMaster[masterId] ?? 'Завантаження...';
  }

  /// Отримати інформацію про поточну або наступну сесію з індикатором статусу
  Map<String, dynamic> getCurrentOrNextSessionForMaster(String masterId) {
    final allSessions = getSessionsForMaster(masterId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Перевіряємо, чи є взагалі записи у майстра
    final hasAnySessions = allSessions.isNotEmpty;

    // Фільтруємо тільки сесії на сьогодні і в майбутньому
    final sessions = allSessions.where((session) {
      try {
        final dateParts = session.date.split('-');
        final sessionDate = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        return sessionDate.isAtSameMomentAs(today) ||
            sessionDate.isAfter(today);
      } catch (e) {
        return false;
      }
    }).toList();

    print(
      '🔍 getCurrentOrNextSessionForMaster: masterId=$masterId, всього записів: ${allSessions.length}, актуальних сесій: ${sessions.length}',
    );
    print('📊 Кеш інвалідований: $_cacheInvalidated, останнє завантаження: $_lastDataLoad');
    if (sessions.isNotEmpty) {
      print('📋 Актуальні сесії: ${sessions.map((s) => '${s.date} ${s.time} ${s.clientName}').join(', ')}');
    }

    // Шукаємо поточну сесію (яка зараз триває)
    for (final session in sessions) {
      try {
        final dateParts = session.date.split('-');
        final timeParts = session.time.split(':');
        final sessionStartTime = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        final sessionEndTime = sessionStartTime.add(
          Duration(minutes: session.duration),
        );

        final isCurrent =
            now.isAfter(sessionStartTime) && now.isBefore(sessionEndTime);
        if (isCurrent) {
          print(
            '🔍 Знайдено поточну сесію: ${session.date} ${session.time} - ${session.clientName}',
          );
        }

        // Перевіряємо чи сесія зараз триває
        if (isCurrent) {
          final endTime =
              '${sessionEndTime.hour.toString().padLeft(2, '0')}:${sessionEndTime.minute.toString().padLeft(2, '0')}';
          return {
            'status': 'current',
            'session': session,
            'displayText': '${session.time}-$endTime ${session.clientName}',
            'endTime': sessionEndTime,
          };
        }
      } catch (e) {
        continue;
      }
    }

    // Якщо поточної сесії немає, шукаємо наступну
    for (final session in sessions) {
      try {
        final dateParts = session.date.split('-');
        final timeParts = session.time.split(':');
        final sessionDateTime = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        if (sessionDateTime.isAfter(now)) {
          final sessionDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
          final formattedDate = _formatDateShort(sessionDate);
          final sessionEndTime = sessionDateTime.add(
            Duration(minutes: session.duration),
          );
          final endTime =
              '${sessionEndTime.hour.toString().padLeft(2, '0')}:${sessionEndTime.minute.toString().padLeft(2, '0')}';

          return {
            'status': 'next',
            'session': session,
            'displayText':
                '$formattedDate ${session.time}-$endTime ${session.clientName}',
            'startTime': sessionDateTime,
          };
        }
      } catch (e) {
        continue;
      }
    }

    // Визначаємо тип відсутності записів
    final noSessionsType = hasAnySessions ? 'no_future' : 'no_sessions';

    return {
      'status': 'none',
      'session': null,
      'displayText': null, // Буде встановлено в UI залежно від мови
      'noSessionsType': noSessionsType,
    };
  }

  // ===== МЕТОДИ ОНОВЛЕННЯ =====

  /// Додати нову сесію (оновлює локальний стан)
  Future<String?> addSession(Session session) async {
    final sessionId = await _firestoreService.addSession(session);
    if (sessionId != null) {
      // Оновлюємо локальний стан
      final updatedSession = Session(
        id: sessionId,
        masterId: session.masterId,
        clientId: session.clientId,
        clientName: session.clientName,
        phone: session.phone,
        service: session.service,
        duration: session.duration,
        date: session.date,
        time: session.time,
        notes: session.notes,
        price: session.price,
      );

      if (!_sessionsByMaster.containsKey(session.masterId)) {
        _sessionsByMaster[session.masterId] = [];
      }
      _sessionsByMaster[session.masterId]!.add(updatedSession);
      _sessionsByMaster[session.masterId]!.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.time.compareTo(b.time);
      });

      _calculateNextSessions();

      // Плануємо сповіщення для нової сесії (якщо статус "в очікуванні")
      if (updatedSession.status == 'в очікуванні') {
        _notificationService.scheduleSessionEndNotification(updatedSession);
      }

      // Інвалідуємо кеш після додавання нового запису
      _lastDataLoad = null;
      print('📝 Новий запис додано, кеш інвалідовано');

      notifyListeners();
    }
    return sessionId;
  }

  /// Оновити сесію
  Future<bool> updateSession(String sessionId, Session session) async {
    final success = await _firestoreService.updateSession(sessionId, session);
    if (success) {
      // Скасовуємо сповіщення для цієї сесії (якщо статус змінився)
      cancelSessionNotifications(sessionId);

      // Знаходимо та оновлюємо в локальному стані
      for (final masterId in _sessionsByMaster.keys) {
        final index = _sessionsByMaster[masterId]!.indexWhere(
          (s) => s.id == sessionId,
        );
        if (index != -1) {
          _sessionsByMaster[masterId]![index] = session;
          _calculateNextSessions();

          // Інвалідуємо кеш після оновлення запису
          _lastDataLoad = null;
          print('✏️ Запис оновлено, кеш інвалідовано');

          notifyListeners();
          break;
        }
      }
    }
    return success;
  }

  /// Видалити сесію
  Future<bool> deleteSession(String sessionId) async {
    final success = await _firestoreService.deleteSession(sessionId);
    if (success) {
      // Видаляємо з локального стану
      for (final masterId in _sessionsByMaster.keys) {
        _sessionsByMaster[masterId]!.removeWhere((s) => s.id == sessionId);
      }
      _calculateNextSessions();

      // Інвалідуємо кеш після видалення запису
      _lastDataLoad = null;
      print('🗑️ Запис видалено, кеш інвалідовано');

      notifyListeners();
    }
    return success;
  }

  // ===== ДОПОМІЖНІ МЕТОДИ =====

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  String _formatDateShort(DateTime date) {
    final today = DateTime.now();
    final tomorrow = today.add(Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return _languageProvider?.getText('Сьогодні', 'Сегодня') ?? 'Сьогодні';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return _languageProvider?.getText('Завтра', 'Завтра') ?? 'Завтра';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ===== СПОВІЩЕННЯ =====

  /// Запланувати сповіщення для всіх активних сесій
  Future<void> _scheduleNotificationsForActiveSessions() async {
    try {
      // Ініціалізуємо сервіс сповіщень
      await _notificationService.initialize();

      // Передаємо провайдер мови в сервіс сповіщень
      if (_languageProvider != null) {
        _notificationService.setLanguageProvider(_languageProvider!);
      }

      // Збираємо всі сесії
      final allSessions = <Session>[];
      for (final sessions in _sessionsByMaster.values) {
        allSessions.addAll(sessions);
      }

      // Плануємо сповіщення
      await _notificationService.scheduleNotificationsForActiveSessions(
        allSessions,
      );

      print('📱 Заплановано сповіщення для активних сесій');
    } catch (e) {
      print('❌ Помилка планування сповіщень: $e');
    }
  }

  /// Скасувати таймери сповіщень для сесії (коли статус змінюється)
  void cancelSessionNotifications(String sessionId) {
    _notificationService.cancelSessionTimers(sessionId);
  }

  // ===== УПРАВЛІННЯ КЕШЕМ =====

  /// Отримати інформацію про стан кешу
  Map<String, dynamic> getCacheInfo() {
    final now = DateTime.now();
    return {
      'cacheVersion': _cacheVersion,
      'isInvalidated': _cacheInvalidated,
      'lastDataLoad': _lastDataLoad?.toIso8601String(),
      'lastMastersLoad': _lastMastersLoad?.toIso8601String(),
      'lastClientsLoad': _lastClientsLoad?.toIso8601String(),
      'sessionCacheAge': _lastDataLoad != null
          ? now.difference(_lastDataLoad!).inMinutes
          : null,
      'mastersCacheAge': _lastMastersLoad != null
          ? now.difference(_lastMastersLoad!).inMinutes
          : null,
      'clientsCacheAge': _lastClientsLoad != null
          ? now.difference(_lastClientsLoad!).inMinutes
          : null,
      'sessionTTL': _cacheTTL.inMinutes,
      'mastersTTL': (_longCacheTTL.inMinutes),
      'dataCount': {
        'masters': _masters.length,
        'clients': _clients.length,
        'sessions': _sessionsByMaster.values.expand((s) => s).length,
      },
    };
  }

  /// Примусово оновити конкретний тип даних
  Future<void> forceReloadData({
    bool masters = false,
    bool clients = false,
    bool sessions = false,
  }) async {
    print(
      '🔄 Примусове оновлення: майстри=$masters, клієнти=$clients, сесії=$sessions',
    );

    if (masters) _lastMastersLoad = null;
    if (clients) _lastClientsLoad = null;
    if (sessions) _lastDataLoad = null;

    _cacheInvalidated = true;
    await refreshAllData(forceRefresh: true);
  }

  // ===== ОЧИЩЕННЯ =====

  void dispose() {
    _autoUpdateTimer?.cancel();
    _notificationService.dispose();
    super.dispose();
  }
}
