import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/services/connectivity_service.dart';
import 'package:nastya_app/providers/language_provider.dart';

/// Екран блокування коли немає інтернету
class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Іконка відсутності інтернету
                Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.shade200,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.wifi_off,
                    size: 80,
                    color: Colors.red.shade400,
                  ),
                ),
                
                SizedBox(height: 32),
                
                // Заголовок
                Consumer<LanguageProvider>(
                  builder: (context, language, child) {
                    return Text(
                      language.getText('Немає підключення до інтернету', 'Нет подключения к интернету'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                
                SizedBox(height: 16),
                
                // Опис
                Consumer<LanguageProvider>(
                  builder: (context, language, child) {
                    return Text(
                      language.getText('Для роботи застосунку необхідне підключення до інтернету.\nПідключіться до Wi-Fi або мобільного інтернету.', 'Для работы приложения необходимо подключение к интернету.\nПодключитесь к Wi-Fi или мобильному интернету.'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                
                SizedBox(height: 48),
                
                // Кнопка повторної перевірки
                Consumer<ConnectivityService>(
                  builder: (context, connectivity, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: connectivity.isChecking 
                            ? null 
                            : () {
                                connectivity.checkConnectivity();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: connectivity.isChecking
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Consumer<LanguageProvider>(
                                    builder: (context, language, child) {
                                      return Text(
                                        language.getText('Перевіряємо підключення...', 'Проверяем подключение...'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh, size: 20),
                                  SizedBox(width: 8),
                                  Consumer<LanguageProvider>(
                                    builder: (context, language, child) {
                                      return Text(
                                        language.getText('Спробувати знову', 'Попробовать снова'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: 24),
                
                // Додаткові поради
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Consumer<LanguageProvider>(
                            builder: (context, language, child) {
                              return Text(
                                language.getText('Поради для підключення:', 'Советы по подключению:'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildTip(context, '• Перевірте налаштування Wi-Fi', '• Проверьте настройки Wi-Fi'),
                      _buildTip(context, '• Увімкніть мобільні дані', '• Включите мобильные данные'),
                      _buildTip(context, '• Перезапустіть роутер', '• Перезапустите роутер'),
                      _buildTip(context, '• Зверніться до провайдера', '• Обратитесь к провайдеру'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(BuildContext context, String ukrainianText, String russianText) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return Text(
              language.getText(ukrainianText, russianText),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            );
          },
        ),
      ),
    );
  }
}