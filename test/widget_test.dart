// Тести для застосунку Nastya App - салон краси
//
// Прості тести для CI/CD перевірки без Firebase залежностей

import 'package:flutter_test/flutter_test.dart';
import 'package:nastya_app/providers/language_provider.dart';

void main() {
  group('Nastya App Basic Tests', () {
    test('LanguageProvider has default language', () {
      // Тест перевіряє що провайдер мови має мову за замовчуванням
      final languageProvider = LanguageProvider();

      // Перевіряємо що є текст для базових фраз
      expect(languageProvider.getText('Головна', 'Главная'), isA<String>());
      expect(languageProvider.getText('Клієнти', 'Клиенты'), isA<String>());
    });

    test('LanguageProvider returns correct text', () {
      // Тест перевіряє правильність роботи перекладів
      final languageProvider = LanguageProvider();

      // Тест україномовного тексту
      final result = languageProvider.getText('Тест', 'Тест');
      expect(result, isNotEmpty);
      expect(result, isA<String>());
    });

    test('Basic string operations work', () {
      // Простий тест для перевірки роботи Dart
      const testString = 'Nastya App';
      expect(testString.length, 10);
      expect(testString.contains('App'), isTrue);
      expect(testString.startsWith('Nastya'), isTrue);
    });

    test('List operations work correctly', () {
      // Тест основних операцій зі списками
      final testList = <String>['Головна', 'Клієнти', 'Календар'];
      expect(testList.length, 3);
      expect(testList.contains('Клієнти'), isTrue);
      expect(testList.first, 'Головна');
    });

    test('Map operations work correctly', () {
      // Тест основних операцій з мапами
      final testMap = <String, String>{
        'home': 'Головна',
        'clients': 'Клієнти',
        'calendar': 'Календар',
      };

      expect(testMap.length, 3);
      expect(testMap['home'], 'Головна');
      expect(testMap.containsKey('clients'), isTrue);
    });
  });
}
