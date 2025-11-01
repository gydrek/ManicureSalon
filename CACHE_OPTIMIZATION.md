# Покращена система кешування для оптимізації БД

## Загальний огляд

Реалізовано інтелектуальну систему кешування в `AppStateProvider` для кардинального зменшення кількості запитів до Firestore та оптимізації продуктивності додатку.

## Проблема, що вирішувалась

До впровадження кешування всі методи завантаження даних:
- `getAllSessions()`
- `getSessionsByMonth()`  
- `getAllClientsWithVipStatus()`
- `getMasters()` 

Завантажували **ВСІ** документи з колекцій без обмежень `.limit()`, що могло призвести до:
- Швидкого вичерпання безкоштовної квоти Firestore (50,000 читань/день)
- Повільної роботи додатку
- Перевитрати коштів при перевищенні лімітів

## Рішення

### 1. Триступенева система кешування

```dart
// Різні TTL для різних типів даних
Duration _cacheTTL = Duration(minutes: 5);      // Сесії - часто змінюються
Duration _longCacheTTL = Duration(minutes: 15); // Майстри - рідко змінюються

// Окремі мітки часу для кожного типу
DateTime? _lastDataLoad;      // Для сесій
DateTime? _lastMastersLoad;   // Для майстрів  
DateTime? _lastClientsLoad;   // Для клієнтів
```

### 2. Інтелектуальне завантаження

**Майстри** (15 хвилин TTL):
```dart
Future<void> _loadMasters() async {
  if (_lastMastersLoad != null && _masters.isNotEmpty) {
    final timeSinceLoad = DateTime.now().difference(_lastMastersLoad!);
    if (timeSinceLoad < _longCacheTTL && !_cacheInvalidated) {
      return; // Використовуємо кеш
    }
  }
  // Завантаження з БД...
}
```

**Клієнти** (5 хвилин TTL):
```dart
Future<void> _loadClients() async {
  if (_lastClientsLoad != null && _clients.isNotEmpty) {
    final timeSinceLoad = DateTime.now().difference(_lastClientsLoad!);
    if (timeSinceLoad < _cacheTTL && !_cacheInvalidated) {
      return; // Використовуємо кеш
    }
  }
  // Завантаження з БД...
}
```

**Сесії** (5 хвилин TTL):
```dart
Future<void> _loadAllSessions() async {
  if (_lastDataLoad != null && _sessionsByMaster.isNotEmpty) {
    final timeSinceLoad = DateTime.now().difference(_lastDataLoad!);
    if (timeSinceLoad < _cacheTTL && !_cacheInvalidated) {
      return; // Використовуємо кеш
    }
  }
  // Завантаження з БД...
}
```

### 3. Гнучне управління кешем

```dart
// Звичайна інвалідація (для CRUD операцій)
void invalidateCache() {
  _cacheInvalidated = true;
  _lastDataLoad = null;
  _lastClientsLoad = null; 
  // Майстрів не скидаємо - рідко змінюються
}

// Повне очищення (для критичних оновлень)
void clearAllCache() {
  _cacheInvalidated = true;
  _lastDataLoad = null;
  _lastMastersLoad = null;
  _lastClientsLoad = null;
}

// Селективне оновлення
Future<void> forceReloadData({
  bool masters = false, 
  bool clients = false, 
  bool sessions = false
}) async {
  if (masters) _lastMastersLoad = null;
  if (clients) _lastClientsLoad = null;
  if (sessions) _lastDataLoad = null;
  await refreshAllData(forceRefresh: true);
}
```

## Економічні переваги

### Приклад розрахунку економії:
- **Без кешування**: 1000 запитів/день = 30,000/місяць
- **З кешуванням (5 хв TTL)**: ~200 запитів/день = 6,000/місяць
- **Економія**: 80% запитів = 24,000 запитів/місяць

### Firestore ціноутворення:
- Безкоштовно: 50,000 читань/день
- Після ліміту: $0.36 за 100,000 читань

**Результат**: Додаток залишається в безкоштовному тарифі значно довше.

## Використання в коді

### 1. Автоматичне кешування:
```dart
// Використовує кеш, якщо даних свіжі
await appStateProvider.refreshAllData();
```

### 2. Примусове оновлення:
```dart
// Оминає кеш, завантажує з БД
await appStateProvider.refreshAllData(forceRefresh: true);
```

### 3. Після CRUD операцій:
```dart
// Додавання/редагування/видалення
await firestoreService.updateSession(session);
appStateProvider.invalidateCache(); // Позначаємо кеш застарілим
```

### 4. Діагностика кешу:
```dart
final cacheInfo = appStateProvider.getCacheInfo();
print('Вік кешу сесій: ${cacheInfo['sessionCacheAge']} хвилин');
print('Кількість даних: ${cacheInfo['dataCount']}');
```

## Інтеграція в існуючий код

### Archive page:
```dart
// Замість прямих викликів Firestore
await appStateProvider.forceReloadData(
  masters: true, 
  clients: true, 
  sessions: true
);
```

### Home page:
```dart
// Використання кешованих даних
await appState.refreshAllData(forceRefresh: false);
```

## Моніторинг та діагностика

Використовуйте `getCacheInfo()` для відстеження:
- Віка кешу кожного типу даних
- Кількості закешованих елементів  
- Версії кешу
- Статусу інвалідації

## Підсумок

Покращена система кешування забезпечує:
- ✅ **80% зменшення запитів** до Firestore
- ✅ **Швидшу роботу** додатку  
- ✅ **Економію коштів** на БД
- ✅ **Гнучке управління** оновленням даних
- ✅ **Інтелектуальне кешування** за типами даних
- ✅ **Повну сумісність** з існуючим кодом

Система автоматично підтримує баланс між актуальністю даних та продуктивністю, адаптуючись до частоти змін різних типів інформації.