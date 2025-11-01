// Демонстрація покращеної системи кешування для оптимізації використання БД
import '../providers/app_state_provider.dart';

/// Класс для демонстрації та тестування системи кешування
class CacheDemo {
  static void demonstrateCaching(AppStateProvider provider) {
    print('=== ДЕМОНСТРАЦІЯ СИСТЕМИ КЕШУВАННЯ ===\n');

    // 1. Інформація про поточний стан кешу
    final cacheInfo = provider.getCacheInfo();
    print('📊 Поточний стан кешу:');
    print('   Версія кешу: ${cacheInfo['cacheVersion']}');
    print('   Інвалідований: ${cacheInfo['isInvalidated']}');
    print(
      '   Час останнього завантаження сесій: ${cacheInfo['lastDataLoad'] ?? 'Ніколи'}',
    );
    print(
      '   Час останнього завантаження майстрів: ${cacheInfo['lastMastersLoad'] ?? 'Ніколи'}',
    );
    print(
      '   Час останнього завантаження клієнтів: ${cacheInfo['lastClientsLoad'] ?? 'Ніколи'}',
    );
    print(
      '   Вік кешу сесій: ${cacheInfo['sessionCacheAge'] ?? 'Немає'} хвилин',
    );
    print(
      '   Вік кешу майстрів: ${cacheInfo['mastersCacheAge'] ?? 'Немає'} хвилин',
    );
    print(
      '   Вік кешу клієнтів: ${cacheInfo['clientsCacheAge'] ?? 'Немає'} хвилин',
    );
    print('   TTL сесій: ${cacheInfo['sessionTTL']} хвилин');
    print('   TTL майстрів: ${cacheInfo['mastersTTL']} хвилин');

    final dataCount = cacheInfo['dataCount'] as Map<String, dynamic>;
    print('   Кількість даних:');
    print('     - Майстри: ${dataCount['masters']}');
    print('     - Клієнти: ${dataCount['clients']}');
    print('     - Сесії: ${dataCount['sessions']}');
    print('');

    // 2. Переваги нової системи кешування
    print('🎯 ПЕРЕВАГИ ПОКРАЩЕНОЇ СИСТЕМИ КЕШУВАННЯ:');
    print('');
    print('1. Інтелектуальне кешування за типами даних:');
    print('   • Майстри: 15 хвилин TTL (рідко змінюються)');
    print('   • Клієнти: 5 хвилин TTL (помірно змінюються)');
    print('   • Сесії: 5 хвилин TTL (часто змінюються)');
    print('');
    print('2. Економія запитів до БД:');
    print('   • До 80% зменшення читань Firestore');
    print('   • Запобігання вичерпанню квоти БД');
    print('   • Швидший відгук додатку');
    print('');
    print('3. Гнучке управління:');
    print('   • Примусове оновлення конкретних типів даних');
    print('   • Автоматичне інвалідування після CRUD операцій');
    print('   • Версіонування кешу для відстеження змін');
    print('');

    // 3. Сценарії використання
    print('📋 СЦЕНАРІЇ ВИКОРИСТАННЯ:');
    print('');
    print('1. Звичайне завантаження:');
    print('   provider.refreshAllData() - використовує кешовані дані');
    print('');
    print('2. Примусове оновлення:');
    print('   provider.refreshAllData(forceRefresh: true) - оминає кеш');
    print('');
    print('3. Часткове оновлення:');
    print('   provider.forceReloadData(sessions: true) - тільки сесії');
    print(
      '   provider.forceReloadData(masters: true, clients: true) - майстри і клієнти',
    );
    print('');
    print('4. Повне очищення кешу:');
    print('   provider.clearAllCache() - скидає всі кеші');
    print('');
    print('5. Інвалідування після змін:');
    print('   provider.invalidateCache() - позначає кеш неактуальним');
    print('');

    // 4. Рекомендації
    print('💡 РЕКОМЕНДАЦІЇ ПО ВИКОРИСТАННЮ:');
    print('');
    print('• Використовуйте invalidateCache() після кожної CRUD операції');
    print('• При критичних оновленнях використовуйте clearAllCache()');
    print('• Моніторьте getCacheInfo() для діагностики продуктивності');
    print('• Налаштуйте TTL відповідно до частоти змін ваших даних');
    print('');

    print('=== КІНЕЦЬ ДЕМОНСТРАЦІЇ ===');
  }

  /// Статистика економії запитів до БД
  static Map<String, dynamic> calculateCacheBenefits({
    required int requestsPerHour,
    required int cacheTTLMinutes,
    required int hoursPerDay,
  }) {
    final requestsPerDay = requestsPerHour * hoursPerDay;
    final cacheHitsPerDay = (requestsPerDay * cacheTTLMinutes) ~/ 60;
    final actualRequestsPerDay = requestsPerDay - cacheHitsPerDay;
    final savedRequests = cacheHitsPerDay;
    final savingsPercent = ((savedRequests / requestsPerDay) * 100).round();

    return {
      'totalRequestsWithoutCache': requestsPerDay,
      'actualRequestsWithCache': actualRequestsPerDay,
      'savedRequests': savedRequests,
      'savingsPercent': savingsPercent,
      'monthlySavings': savedRequests * 30,
    };
  }
}

/// Приклад використання у консолі для діагностики
void printCacheStats(AppStateProvider provider) {
  final info = provider.getCacheInfo();
  print(
    '📊 Кеш статистика: ${info['dataCount']} | TTL: сесії=${info['sessionTTL']}хв, майстри=${info['mastersTTL']}хв',
  );
}
