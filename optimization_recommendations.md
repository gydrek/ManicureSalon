# 🔥 Оптимізація Firestore для архіву

## 📊 Поточна ситуація:
- **getAllSessions()** завантажує ВСІ записи (може бути 1000+ документів)
- Кожне відкриття архіву = 1 запит на всі сесії
- Свайп оновлення = 5 запитів (3 + 2 дублювання)
- Автооновлення кожні 3 хв = 3 запити

## ⚠️ Ризики:
- **Ліміт reads:** 50,000/день (безкоштовно)
- При 1000 сесій + відкриття архіву 10 разів = 10,000 reads
- Свайп оновлення 20 разів = 10,000 reads  
- **Разом за день:** ~20,000-30,000 reads

## 🚀 Рішення:

### 1. Пагінація для архіву:
```dart
// Завантажувати по 50 записів
Future<List<Session>> getSessionsPaginated({
  int limit = 50,
  DocumentSnapshot? startAfter,
}) async {
  Query query = _sessionsCollection
    .orderBy('date', descending: true)
    .limit(limit);
    
  if (startAfter != null) {
    query = query.startAfterDocument(startAfter);
  }
  
  final snapshot = await query.get();
  return _parseSessions(snapshot);
}
```

### 2. Кешування з TTL:
```dart
class SessionCache {
  static final Map<String, CachedData> _cache = {};
  static const Duration TTL = Duration(minutes: 5);
  
  static Future<List<Session>> getCachedSessions() async {
    final key = 'all_sessions';
    final cached = _cache[key];
    
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < TTL) {
      return cached.data;
    }
    
    // Завантажуємо тільки якщо кеш застарілий
    final fresh = await FirestoreService().getAllSessions();
    _cache[key] = CachedData(fresh, DateTime.now());
    return fresh;
  }
}
```

### 3. Фільтрація на сервері:
```dart
// Замість завантаження всіх і фільтрації локально
Future<List<Session>> getSessionsByFilter({
  String? masterId,
  String? status,
  DateTime? date,
}) async {
  Query query = _sessionsCollection;
  
  if (masterId != null && masterId != 'Всі майстрині') {
    query = query.where('masterId', isEqualTo: masterId);
  }
  
  if (status != null && status != 'Всі статуси') {
    query = query.where('status', isEqualTo: status);
  }
  
  if (date != null) {
    final dateStr = _formatDate(date);
    query = query.where('date', isEqualTo: dateStr);
  }
  
  final snapshot = await query.get();
  return _parseSessions(snapshot);
}
```

### 4. Оптимізація оновлень:
```dart
// Уникати дублювання запитів при свайпі
Future<void> _loadDataOptimized() async {
  // Використовуємо дані з AppStateProvider замість повторних запитів
  final appState = Provider.of<AppStateProvider>(context, listen: false);
  
  setState(() {
    _masters = appState.masters;
    // Отримуємо сесії з глобального стану
    _allSessions = _getSessionsFromAppState(appState);
    _filteredSessions = _allSessions;
    _isLoading = false;
  });
  
  _applyFilters();
}
```

## 📈 Очікувані результати:
- **Зменшення reads:** з 30,000 до 5,000-8,000/день
- **Швидкість:** завантаження архіву 2-3 сек замість 5-10 сек
- **Кешування:** 80% запитів з кешу
- **Пагінація:** завантаження по потребі

## 🎯 Пріоритети:
1. **Високий:** Кешування + уникнення дублювання
2. **Середній:** Фільтрація на сервері  
3. **Низький:** Пагінація (для великих архівів)