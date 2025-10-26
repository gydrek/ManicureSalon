import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/services/connectivity_service.dart';
import 'package:nastya_app/widgets/no_internet_screen.dart';
import 'package:nastya_app/providers/language_provider.dart';

/// Обгортка для сторінок з перевіркою підключення до інтернету
/// Показує NoInternetScreen якщо немає підключення, інакше основний контент
class ConnectivityWrapper extends StatelessWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        // Якщо немає підключення - показуємо NoInternetScreen
        if (!connectivity.isConnected) {
          return NoInternetScreen();
        }

        // Якщо є підключення - показуємо основний контент
        return child;
      },
    );
  }
}

/// Mixin для додавання методів роботи з підключенням до сторінок
mixin ConnectivityMixin<T extends StatefulWidget> on State<T> {
  
  /// Перевірити чи є підключення перед виконанням операції
  bool checkConnection() {
    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    
    if (!connectivity.isConnected) {
      _showNoInternetDialog();
      return false;
    }
    
    return true;
  }

  /// Показати діалог про відсутність інтернету
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.wifi_off,
          color: Colors.red,
          size: 48,
        ),
        title: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return Text(
              language.getText('Немає підключення', 'Нет подключения'),
            );
          },
        ),
        content: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return Text(
              language.getText('Для виконання цієї операції необхідне підключення до інтернету.', 'Для выполнения этой операции необходимо подключение к интернету.'),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Зрозуміло', 'Понятно'),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<ConnectivityService>(context, listen: false)
                  .checkConnectivity();
            },
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Повторити', 'Повторить'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Виконати операцію тільки за наявності інтернету
  Future<T> executeWithConnection<T>(Future<T> Function() operation) async {
    if (!checkConnection()) {
      throw Consumer<LanguageProvider>(
        builder: (context, language, child) {
          return Text(
            language.getText('Немає підключення до інтернету', 'Нет подключения к интернету'),
          );
        },
      );
    }
    
    try {
      return await operation();
    } catch (e) {
      // Якщо помилка пов'язана з мережею, перевіряємо підключення
      final connectivity = Provider.of<ConnectivityService>(context, listen: false);
      connectivity.checkConnectivity();
      rethrow;
    }
  }
}