import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Сервіс для перевірки підключення до інтернету
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isConnected = true; // Оптимістично припускаємо, що є підключення
  bool _isChecking = false; // Не показуємо перевірку на початку

  /// Чи є підключення до інтернету
  bool get isConnected => _isConnected;

  /// Чи відбувається перевірка підключення
  bool get isChecking => _isChecking;

  /// Чи сервіс готовий (перевірка завершена хоча б раз)
  bool get isReady => !_isChecking;

  /// Ініціалізація сервісу
  Future<void> initialize() async {
    print('🌐 Ініціалізуємо ConnectivityService');

    // Слухаємо зміни підключення (основна функція сервісу)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      print('📱 Зміна підключення: $results');
      _onConnectivityChanged(results);
    });

    // Швидка початкова перевірка у фоні (не блокуємо UI)
    checkConnectivity();

    print('✅ ConnectivityService ініціалізовано');
  }

  /// Перевірка підключення до інтернету
  Future<void> checkConnectivity() async {
    if (_isChecking) return;

    _isChecking = true;
    notifyListeners();

    try {
      print('🔍 Починаємо перевірку підключення...');

      // Перевіряємо наявність з'єднання
      final connectivityResults = await _connectivity.checkConnectivity();
      print('🔍 Результат connectivity: $connectivityResults');

      if (connectivityResults.contains(ConnectivityResult.none)) {
        _isConnected = false;
        print('❌ Немає підключення до мережі');
      } else {
        // Спрощена перевірка - якщо є будь-яке підключення, вважаємо що інтернет є
        // Додаткову перевірку робимо з коротким таймаутом
        _isConnected = await _hasInternetConnection().timeout(
          Duration(seconds: 3),
          onTimeout: () {
            print('⏰ Таймаут перевірки - припускаємо що інтернет є');
            return true; // При таймауті припускаємо що є підключення
          },
        );
        print(
          _isConnected ? '✅ Інтернет підключено' : '❌ Інтернет недоступний',
        );
      }
    } catch (e) {
      print('❌ Помилка перевірки підключення: $e');
      // При помилці припускаємо що підключення є
      _isConnected = true;
    } finally {
      _isChecking = false;
      notifyListeners();
      print(
        '🔍 Перевірка завершена: isConnected=$_isConnected, isChecking=$_isChecking',
      );
    }
  }

  /// Додаткова перевірка доступності інтернету через ping
  Future<bool> _hasInternetConnection() async {
    try {
      print('🔍 Перевіряємо доступність інтернету (google.com)...');

      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(Duration(seconds: 2)); // Короткий таймаут

      final hasConnection =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      print('🔍 Результат перевірки google.com: $hasConnection');

      return hasConnection;
    } catch (e) {
      print('🔍 Помилка перевірки google.com: $e');
      return true; // При помилці припускаємо що інтернет є
    }
  }

  /// Обробка зміни підключення
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    print('🔄 Зміна підключення: $results');
    checkConnectivity();
  }

  /// Отримати текстовий статус підключення
  String getConnectionStatus() {
    if (_isChecking) {
      return 'Перевіряємо підключення...';
    } else if (_isConnected) {
      return 'Підключено до інтернету';
    } else {
      return 'Немає підключення до інтернету';
    }
  }

  /// Отримати іконку статусу
  String getConnectionIcon() {
    if (_isChecking) {
      return '🔄';
    } else if (_isConnected) {
      return '🟢';
    } else {
      return '🔴';
    }
  }

  /// Очищення ресурсів
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
