import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'uk'; // за замовчуванням українська
  Map<String, bool> _masterNotifications = {}; // id майстра -> включені сповіщення
  bool _isLoading = true;
  bool _hasChanges = false;
  
  // Початкові значення для порівняння
  String _initialLanguage = 'uk';
  Map<String, bool> _initialMasterNotifications = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Спочатку завантажуємо тільки мову з SharedPreferences
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      _selectedLanguage = languageProvider.currentLocale.languageCode;
      _initialLanguage = _selectedLanguage; // Зберігаємо початкове значення
      
      // Потім окремо завантажуємо майстрів з Firebase
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      if (appState.masters.isEmpty) {
        await appState.refreshAllData(forceRefresh: false);
      }
      
      // І тільки потім завантажуємо налаштування сповіщень
      final prefs = await SharedPreferences.getInstance();
      _masterNotifications.clear();
      _initialMasterNotifications.clear();
      for (final master in appState.masters) {
        final key = 'notifications_${master.id}';
        final value = prefs.getBool(key) ?? true;
        _masterNotifications[master.id!] = value;
        _initialMasterNotifications[master.id!] = value; // Зберігаємо початкове значення
      }
      
      setState(() {
        _isLoading = false;
        _updateHasChanges(); // Перевіряємо чи є зміни після завантаження
      });
      
    } catch (e) {
      // Якщо помилка - показуємо спрощений інтерфейс тільки з мовою
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Помилка завантаження: $e', 'Ошибка загрузки: $e'),
                );
              },
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    // Зберігаємо мову через LanguageProvider
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await languageProvider.changeLanguage(_selectedLanguage);
    
    // Зберігаємо налаштування сповіщень
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _masterNotifications.entries) {
      final key = 'notifications_${entry.key}';
      await prefs.setBool(key, entry.value);
    }
    
    setState(() {
      _hasChanges = false;
      // Оновлюємо початкові значення після збереження
      _initialLanguage = _selectedLanguage;
      _initialMasterNotifications = Map.from(_masterNotifications);
    });
    
    // Показуємо повідомлення про успішне збереження
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return Text(
              language.getText('Налаштування збережено успішно!', 'Настройки сохранены успешно!'),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Через невелику затримку повертаємося на головну сторінку
    await Future.delayed(Duration(milliseconds: 500));
    Navigator.of(context).pop();
  }

  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _selectedLanguage) {
      setState(() {
        _selectedLanguage = newLanguage;
        _updateHasChanges();
      });
    }
  }

  void _onNotificationChanged(String masterId, bool value) {
    setState(() {
      _masterNotifications[masterId] = value;
      _updateHasChanges();
    });
  }

  /// Перевіряє чи є реальні зміни відносно початкових значень
  void _updateHasChanges() {
    bool hasRealChanges = false;
    
    // Перевіряємо зміну мови
    if (_selectedLanguage != _initialLanguage) {
      hasRealChanges = true;
    }
    
    // Перевіряємо зміни в налаштуваннях сповіщень
    if (!hasRealChanges) {
      for (final entry in _masterNotifications.entries) {
        final initialValue = _initialMasterNotifications[entry.key] ?? true;
        if (entry.value != initialValue) {
          hasRealChanges = true;
          break;
        }
      }
      
      // Додатково перевіряємо чи є нові майстри в поточних налаштуваннях
      // яких не було в початкових (на випадок динамічного додавання майстрів)
      if (!hasRealChanges) {
        for (final entry in _initialMasterNotifications.entries) {
          if (!_masterNotifications.containsKey(entry.key)) {
            hasRealChanges = true;
            break;
          }
        }
      }
    }
    
    _hasChanges = hasRealChanges;
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      child: PopScope(
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && _hasChanges) {
            final shouldPop = await _showUnsavedChangesDialog();
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Налаштування', 'Настройки'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            centerTitle: true,
          ),
          body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(height: 16),
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            language.getText('Завантажуємо налаштування...', 'Загружаем настройки...'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Розділ мови
                          _buildLanguageSection(),
                          
                          SizedBox(height: 25),
                          
                          // Розділ сповіщень
                          _buildNotificationsSection(),
                          
          SizedBox(height: 25),
          
          // Кнопка збереження
          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: 12),
              Consumer<LanguageProvider>(
                builder: (context, language, child) {
                  return Text(
                    language.getText('Мова застосунку', 'Язык приложения'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Україська
          RadioListTile<String>(
            value: 'uk',
            groupValue: _selectedLanguage,
            onChanged: _onLanguageChanged,
            title: Row(
              children: [
                Text(
                  '🇺🇦',
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'Українська',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            activeColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
          
          // Російська
          RadioListTile<String>(
            value: 'ru',
            groupValue: _selectedLanguage,
            onChanged: _onLanguageChanged,
            title: Row(
              children: [
                Text(
                  '🇷🇺',
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'Русский',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            activeColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    final appState = Provider.of<AppStateProvider>(context);
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Consumer<LanguageProvider>(
                  builder: (context, language, child) {
                    return Text(
                      language.getText('Сповіщення про записи', 'Уведомления о записях'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ),
              // Кнопка тестування сповіщень (іконка)
              Consumer<LanguageProvider>(
                builder: (context, language, child) {
                  return IconButton(
                    onPressed: _testNotification,
                    icon: Icon(
                      Icons.notifications_active,
                      color: Theme.of(context).colorScheme.primary,
                      size: 35,
                    ),
                    tooltip: language.getText('Тест сповіщень', 'Тест уведомлений'),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.all(8),
                    ),
                  );
                },
              ),
            ],
          ),
          
          SizedBox(height: 8),

          Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return Text(
                language.getText('Оберіть майстринь, для яких потрібні сповіщення про майбутні записи', 'Выберите мастериц, для которых нужны уведомления о будущих записях'),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          
          // Список майстрів з перемикачами
          if (appState.masters.isEmpty)
            Center(
              child: Consumer<LanguageProvider>(
                builder: (context, language, child) {
                  return Text(
                    language.getText('Майстрині не знайдені', 'Мастерицы не найдены'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  );
                },
              ),
            )
          else
            ...appState.masters.map((master) {
              final isEnabled = _masterNotifications[master.id] ?? true;
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: SwitchListTile(
                  value: isEnabled,
                  onChanged: (value) => _onNotificationChanged(master.id!, value),
                  title: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              master.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  activeColor: Theme.of(context).colorScheme.primary,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }


  Future<void> _testNotification() async {
    final language = Provider.of<LanguageProvider>(context, listen: false);
    
    try {
      print('🧪 Починаємо тест сповіщень...');
      
      // Перевіряємо чи дозволи надані
      final notificationService = NotificationService();
      final permissionsEnabled = await notificationService.areNotificationsEnabled();
      
      print('🔒 Дозволи на сповіщення: $permissionsEnabled');
      
      if (!permissionsEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language.getText(
                'Дозволи на сповіщення не надані. Перейдіть в налаштування телефону.',
                'Разрешения на уведомления не предоставлены. Перейдите в настройки телефона.'
              ),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Показуємо миттєве сповіщення для тестування
      print('📲 Відправляємо миттєве сповіщення...');
      
      await notificationService.showImmediateNotification(
        title: language.getText('Тестове сповіщення', 'Тестовое уведомление'),
        body: language.getText(
          'Сповіщення працюють правильно! ✅',
          'Уведомления работают правильно! ✅'
        ),
      );

      print('🎉 Сповіщення відправлено успішно!');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.getText(
              'Тестове сповіщення відправлено!',
              'Тестовое уведомление отправлено!'
            ),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Помилка тестування сповіщень: $e');
      
      // Спробуємо простий fallback тест
      try {
        print('🔄 Спробуємо простий тест...');
        await _simpleNotificationTest();
      } catch (fallbackError) {
        print('❌ Простий тест також не спрацював: $fallbackError');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language.getText(
              'Помилка тестування: $e',
              'Ошибка тестирования: $e'
            ),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _simpleNotificationTest() async {
    final notificationService = NotificationService();
    
    // Спробуємо простий метод через сервіс
    await notificationService.showSimpleTest();
    
    print('✅ Простий тест відправлено');
  }



  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _hasChanges ? _saveSettings : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _hasChanges 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey.shade300,
          foregroundColor: _hasChanges 
              ? Theme.of(context).colorScheme.onPrimary 
              : Colors.grey.shade600,
          elevation: _hasChanges ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.save,
              size: 24,
            ),
            SizedBox(width: 12),
            Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Зберегти налаштування', 'Сохранить настройки'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }



  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
            ),
            SizedBox(width: 8),
            Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Незбережені зміни', 'Несохранённые \nизменения'),
                );
              },
            ),
          ],
        ),
        content: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return Text(
              language.getText('У вас є незбережені зміни. Ви дійсно хочете вийти без збереження?', 'У вас есть несохранённые изменения. Вы действительно хотите выйти без сохранения?'),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Залишитися', 'Остаться'),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Text(
                  language.getText('Вийти без збереження', 'Выйти без сохранения'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}