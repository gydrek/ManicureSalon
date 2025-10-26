import 'package:flutter/foundation.dart';
import 'package:nastya_app/models/models.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'dart:async';

/// Глобальний провайдер стану для всього додатку
/// Централізує управління даними та оновленнями
class AppStateProvider extends ChangeNotifier {
  static final AppStateProvider _instance = AppStateProvider._internal();
  factory AppStateProvider() => _instance;
  AppStateProvider._internal();

  final FirestoreService _firestoreService = FirestoreService();
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
  Map<String, String> _nextSessionsByMaster = {}; // masterId -> next session info
  
  bool _isLoading = false;
  DateTime _lastUpdate = DateTime.now();
  Timer? _autoUpdateTimer;
  int _lastSessionCount = 0; // Кількість сесій при останньому оновленні
  
  // Кеш для оптимізації (TTL = 3 хвилини)
  static const Duration _cacheTTL = Duration(minutes: 3);
  DateTime? _lastDataLoad;
  bool _cacheInvalidated = false; // Прапор інвалідації кешу

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
    notifyListeners();
  }

  // ===== ІНІЦІАЛІЗАЦІЯ =====
  Future<void> initialize() async {
    print('🚀 Ініціалізуємо AppStateProvider');
    
    // Завантажуємо початкові дані
    await refreshAllData();
    
    // Запускаємо автоматичне оновлення кожні 5 хвилин (оптимізовано)
    _autoUpdateTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (!_isLoading) {
        print('⏰ Автооновлення (кожні 5 хв)...');
        refreshAllData(forceRefresh: true); // Примусове оновлення по таймеру
      }
    });
    
    print('✅ AppStateProvider ініціалізовано');
  }

  // ===== ОСНОВНІ МЕТОДИ =====
  
  /// Оновити всі дані (майстри, клієнти, сесії)
  Future<void> refreshAllData({bool forceRefresh = false}) async {
    if (_isLoading) return; // Уникаємо подвійних завантажень
    
    // Перевіряємо кеш (якщо не примусове оновлення і кеш не інвалідований)
    if (!forceRefresh && !_cacheInvalidated && _lastDataLoad != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastDataLoad!);
      if (timeSinceLastLoad < _cacheTTL) {
        print('📦 Використовуємо кешовані дані (${timeSinceLastLoad.inMinutes} хв тому)');
        // НЕ оновлюємо _lastUpdate при використанні кешу
        notifyListeners();
        return;
      }
    }
    
    _setLoading(true);
    try {
      print('🔄 Оновлюємо всі дані з БД...');
      
      // Завантажуємо паралельно для швидкості
      await Future.wait([
        _loadMasters(),
        _loadClients(),
        _loadAllSessions(),
      ]);
      
      _lastUpdate = DateTime.now();
      _lastDataLoad = DateTime.now(); // Оновлюємо час завантаження
      _cacheInvalidated = false; // Скидуємо прапор інвалідації
      print('✅ Всі дані оновлено з БД о ${_formatTime(_lastUpdate)}');
      
    } catch (e) {
      print('❌ Помилка оновлення даних: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Завантажити тільки майстрів
  Future<void> _loadMasters() async {
    try {
      final masters = await _firestoreService.getMasters();
      _masters = masters;
      print('📋 Завантажено майстрів: ${masters.length}');
    } catch (e) {
      print('❌ Помилка завантаження майстрів: $e');
    }
  }

  /// Завантажити тільки клієнтів
  Future<void> _loadClients() async {
    try {
      final clients = await _firestoreService.getClients();
      _clients = clients;
      print('👥 Завантажено клієнтів: ${clients.length}');
    } catch (e) {
      print('❌ Помилка завантаження клієнтів: $e');
    }
  }

  /// Завантажити всі сесії поточного місяця
  Future<void> _loadAllSessions() async {
    try {
      final now = DateTime.now();
      final sessions = await _firestoreService.getSessionsByMonth(now.year, now.month);
      
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
      
      // Оновлюємо статистику
      _lastSessionCount = sessions.length;
      
      print('📅 Завантажено сесій: ${sessions.length}');
    } catch (e) {
      print('❌ Помилка завантаження сесій: $e');
    }
  }

  /// Обчислити наступні сесії для всіх майстрів
  void _calculateNextSessions() {
    _nextSessionsByMaster.clear();
    
    final now = DateTime.now();
    final currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    for (final master in _masters) {
      final masterId = master.id!;
      final sessions = _sessionsByMaster[masterId] ?? [];
      
      if (sessions.isEmpty) {
        _nextSessionsByMaster[masterId] = _languageProvider?.getText('Немає записів', 'Нет записей') ?? 'Немає записів';
        continue;
      }
      
      // Знаходимо найближчу майбутню сесію
      final futureSessions = sessions.where((session) {
        if (session.date.compareTo(currentDate) > 0) {
          return true; // Майбутня дата
        } else if (session.date == currentDate) {
          return session.time.compareTo(currentTime) > 0; // Майбутній час сьогодні
        }
        return false;
      }).toList();
      
      if (futureSessions.isEmpty) {
        _nextSessionsByMaster[masterId] = _languageProvider?.getText('Немає майбутніх записів', 'Нет будущих записей') ?? 'Немає майбутніх записів';
      } else {
        final nextSession = futureSessions.first;
        final sessionDate = DateTime.parse(nextSession.date);
        final formattedDate = _formatDateShort(sessionDate);
        _nextSessionsByMaster[masterId] = '${nextSession.clientName} - $formattedDate ${nextSession.time}';
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
    
    // Фільтруємо тільки сесії на сьогодні і в майбутньому
    final sessions = allSessions.where((session) {
      try {
        final dateParts = session.date.split('-');
        final sessionDate = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        return sessionDate.isAtSameMomentAs(today) || sessionDate.isAfter(today);
      } catch (e) {
        return false;
      }
    }).toList();
    
    print('🔍 getCurrentOrNextSessionForMaster: masterId=$masterId, актуальних сесій: ${sessions.length}');
    
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
        final sessionEndTime = sessionStartTime.add(Duration(minutes: session.duration));
        
        final isCurrent = now.isAfter(sessionStartTime) && now.isBefore(sessionEndTime);
        if (isCurrent) {
          print('🔍 Знайдено поточну сесію: ${session.date} ${session.time} - ${session.clientName}');
        }
        
        // Перевіряємо чи сесія зараз триває
        if (isCurrent) {
          final endTime = '${sessionEndTime.hour.toString().padLeft(2, '0')}:${sessionEndTime.minute.toString().padLeft(2, '0')}';
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
          final sessionEndTime = sessionDateTime.add(Duration(minutes: session.duration));
          final endTime = '${sessionEndTime.hour.toString().padLeft(2, '0')}:${sessionEndTime.minute.toString().padLeft(2, '0')}';
          
          return {
            'status': 'next',
            'session': session,
            'displayText': '$formattedDate ${session.time}-$endTime ${session.clientName}',
            'startTime': sessionDateTime,
          };
        }
      } catch (e) {
        continue;
      }
    }
    
    return {
      'status': 'none',
      'session': null,
      'displayText': 'Немає записів',
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
      // Знаходимо та оновлюємо в локальному стані
      for (final masterId in _sessionsByMaster.keys) {
        final index = _sessionsByMaster[masterId]!.indexWhere((s) => s.id == sessionId);
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
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return _languageProvider?.getText('Сьогодні', 'Сегодня') ?? 'Сьогодні';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return _languageProvider?.getText('Завтра', 'Завтра') ?? 'Завтра';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ===== ОЧИЩЕННЯ =====
  
  void dispose() {
    _autoUpdateTimer?.cancel();
    super.dispose();
  }
}