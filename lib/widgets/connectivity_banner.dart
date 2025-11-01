import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/services/connectivity_service.dart';
import 'package:nastya_app/providers/language_provider.dart';

/// Віджет показу статусу підключення до інтернету
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, child) {
        // Показуємо банер тільки якщо немає підключення
        if (connectivity.isConnected) {
          return SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            language.getText(
                              'Немає підключення до інтернету',
                              'Нет подключения к интернету',
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 2),
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            language.getText(
                              'Підключіться до Wi-Fi або мобільного інтернету',
                              'Подключитесь к Wi-Fi или мобильному интернету',
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Кнопка повторної перевірки
                if (!connectivity.isChecking)
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return IconButton(
                        onPressed: () {
                          connectivity.checkConnectivity();
                        },
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: language.getText(
                          'Перевірити підключення',
                          'Проверить подключение',
                        ),
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      );
                    },
                  ),

                // Індикатор перевірки
                if (connectivity.isChecking)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
