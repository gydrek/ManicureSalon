import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/providers/language_provider.dart';

/// Віджет з інформацією про оновлення даних
/// Показує час останнього оновлення та кнопку для ручного оновлення
class UpdateInfoWidget extends StatelessWidget {
  final EdgeInsets? margin;
  
  const UpdateInfoWidget({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          margin: margin ?? EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
              right: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.update,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Text(
                          languageProvider.getText('Оновлено: ${_formatTime(appState.lastUpdate)}', 'Обновлено: ${_formatTime(appState.lastUpdate)}'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 2),
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Text(
                          languageProvider.getText('Автооновлення: 5 хв', 'Автообновление: 5 мин'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: appState.isLoading 
                    ? Colors.grey.withValues(alpha: 0.1)
                    : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: appState.isLoading 
                      ? Colors.grey.withValues(alpha: 0.3)
                      : Colors.blue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    appState.isLoading 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        )
                      : Icon(
                          Icons.swipe_down,
                          color: Colors.blue,
                          size: 18,
                        ),
                    SizedBox(width: 4),
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Text(
                          languageProvider.getText(appState.isLoading ? 'Оновлення...' : 'Свайп ↓', appState.isLoading ? 'Обновление...' : 'Свайп ↓'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: appState.isLoading ? Colors.grey : Colors.blue,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}