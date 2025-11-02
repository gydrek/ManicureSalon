import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/pages/calendar.dart';
import 'package:nastya_app/pages/clients.dart';
import 'package:nastya_app/pages/archive.dart';
import 'package:nastya_app/pages/settings.dart';
import 'package:nastya_app/pages/analytics.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/widgets/update_info_widget.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'package:nastya_app/models/models.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Коли додаток повертається в активний стан, оновлюємо дані
    if (state == AppLifecycleState.resumed) {
      print('📱 Додаток повернувся в активний стан - оновлюємо дані...');
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      // Форсуємо оновлення для синхронізації з іншими пристроями
      appState.refreshAllData(forceRefresh: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              title: Consumer<LanguageProvider>(
                builder: (context, language, child) {
                  return Text(
                    language.getText('Майстрині', 'Мастерицы'),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  );
                },
              ),
              centerTitle: true,
              elevation: 0,
            ),
            drawer: SafeArea(
              child: Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.spa,
                            size: 48,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          SizedBox(height: 8),
                          Consumer<LanguageProvider>(
                            builder: (context, language, child) {
                              return Text(
                                language.getText(
                                  'Манікюрний салон',
                                  'Маникюрный салон',
                                ),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.people_outline),
                      title: Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(language.getText('Клієнтки', 'Клиентки'));
                        },
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClientsPage(),
                          ),
                        );

                        // Оновлюємо дані після повернення з клієнтів (форсовано для синхронізації)
                        if (context.mounted) {
                          final appState = Provider.of<AppStateProvider>(
                            context,
                            listen: false,
                          );
                          await appState.refreshAllData(forceRefresh: true);
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.analytics_outlined),
                      title: Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            language.getText('Статистика', 'Статистика'),
                          );
                        },
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalyticsPage(),
                          ),
                        );

                        // Оновлюємо дані після повернення зі статистики (форсовано для синхронізації)
                        if (context.mounted) {
                          final appState = Provider.of<AppStateProvider>(
                            context,
                            listen: false,
                          );
                          await appState.refreshAllData(forceRefresh: true);
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.archive_outlined),
                      title: Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            language.getText('Архів записів', 'Архив записей'),
                          );
                        },
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArchivePage(),
                          ),
                        );

                        // Оновлюємо дані після повернення з архіву (форсовано для синхронізації)
                        if (context.mounted) {
                          final appState = Provider.of<AppStateProvider>(
                            context,
                            listen: false,
                          );
                          await appState.refreshAllData(forceRefresh: true);
                        }
                      },
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            language.getText('Налаштування', 'Настройки'),
                          );
                        },
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SettingsPage(),
                          ),
                        );

                        // Оновлюємо дані після повернення з налаштувань (форсовано для синхронізації)
                        if (context.mounted) {
                          final appState = Provider.of<AppStateProvider>(
                            context,
                            listen: false,
                          );
                          await appState.refreshAllData(forceRefresh: true);
                        }
                      },
                    ),

                    // Інформація про застосунок, можна розкоментувати за потреби

                    ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(language.getText('Про застосунок', 'О приложении'));
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Consumer<LanguageProvider>(
                              builder: (context, language, child) {
                                return Text(language.getText('Про застосунок', 'О приложении'));
                              },
                            ),
                            content: Consumer<LanguageProvider>(
                              builder: (context, language, child) {
                                return Text(language.getText(
                                  'Nogotochki (beta) v1.1.0 (build 2)',
                                  'Nogotochki (beta) v1.1.0 (build 2)',
                                ));
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            body: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                child: appState.isLoading
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
                                  language.getText(
                                    'Завантажуємо дані...',
                                    'Загружаем данные...',
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : appState.masters.isEmpty
                    ? Center(
                        child: Consumer<LanguageProvider>(
                          builder: (context, language, child) {
                            return Text(
                              language.getText(
                                'Майстрині не знайдені',
                                'Мастерицы не найдены',
                              ),
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            );
                          },
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await appState.refreshAllData(
                            forceRefresh: true,
                          ); // Примусове оновлення для оновлення часу

                          // Показуємо повідомлення про успішне оновлення
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Consumer<LanguageProvider>(
                                      builder: (context, language, child) {
                                        return Text(
                                          language.getText(
                                            'Дані оновлено свайпом',
                                            'Данные обновлены свайпом',
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                duration: Duration(seconds: 2),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        child: SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                // Інформація про останнє оновлення
                                UpdateInfoWidget(),

                                // Список майстрів
                                Consumer<LanguageProvider>(
                                  builder: (context, language, child) {
                                    // Сортуємо майстрів: спочатку по статусу, потім по імені
                                    final sortedMasters = List<Master>.from(
                                      appState.masters,
                                    );
                                    sortedMasters.sort((a, b) {
                                      final statusA = _getAutoStatus(
                                        a,
                                        appState,
                                      );
                                      final statusB = _getAutoStatus(
                                        b,
                                        appState,
                                      );

                                      // Сортування по статусу: вільна (0) -> зайнята (1) -> недоступна (2)
                                      final statusOrderA =
                                          statusA == MasterStatus.available
                                          ? 0
                                          : statusA == MasterStatus.busy
                                          ? 1
                                          : 2;
                                      final statusOrderB =
                                          statusB == MasterStatus.available
                                          ? 0
                                          : statusB == MasterStatus.busy
                                          ? 1
                                          : 2;

                                      if (statusOrderA != statusOrderB) {
                                        return statusOrderA.compareTo(
                                          statusOrderB,
                                        );
                                      }

                                      // Якщо статуси однакові, сортуємо по імені
                                      final nameA = a.getLocalizedName(
                                        language.currentLocale.languageCode,
                                      );
                                      final nameB = b.getLocalizedName(
                                        language.currentLocale.languageCode,
                                      );
                                      return nameA.compareTo(nameB);
                                    });

                                    return ListView.separated(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: sortedMasters.length,
                                      separatorBuilder: (context, index) =>
                                          SizedBox(height: 20),
                                      itemBuilder: (context, index) {
                                        final master = sortedMasters[index];
                                        final sessionInfo = appState
                                            .getCurrentOrNextSessionForMaster(
                                              master.id!,
                                            );
                                        return MasterCard(
                                          masterName: master.getLocalizedName(
                                            language.currentLocale.languageCode,
                                          ),
                                          masterId: master.id!,
                                          status: _getAutoStatus(
                                            master,
                                            appState,
                                          ),
                                          sessionInfo: sessionInfo,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Автоматично визначає статус майстрині на основі записів
  MasterStatus _getAutoStatus(Master master, AppStateProvider appState) {
    // Якщо статус встановлений вручну як "недоступна", не змінюємо його
    if (master.status == 'unavailable') {
      return MasterStatus.unavailable;
    }

    final now = DateTime.now();
    final twoHoursLater = now.add(Duration(hours: 2));

    // Отримуємо всі сесії цієї майстрині
    final allSessions = appState.getSessionsForMaster(master.id!);

    // Перевіряємо чи є поточні або майбутні записи
    final hasBusySession = allSessions.any((session) {
      try {
        // Парсимо дату сесії (формат: yyyy-mm-dd)
        final dateParts = session.date.split('-');
        final timeParts = session.time.split(':');
        final sessionStartTime = DateTime(
          int.parse(dateParts[0]), // рік
          int.parse(dateParts[1]), // місяць
          int.parse(dateParts[2]), // день
          int.parse(timeParts[0]), // година
          int.parse(timeParts[1]), // хвилина
        );

        // Час закінчення сесії (початок + тривалість)
        final sessionEndTime = sessionStartTime.add(
          Duration(minutes: session.duration),
        );

        // Перевіряємо різні сценарії:
        // 1. Поточна сесія (зараз між початком та кінцем сесії)
        final isCurrentSession =
            now.isAfter(sessionStartTime) && now.isBefore(sessionEndTime);

        // 2. Майбутня сесія в наступні 2 години
        final isFutureSessionInTwoHours =
            sessionStartTime.isAfter(now) &&
            sessionStartTime.isBefore(twoHoursLater);

        if (isCurrentSession) {
          print(
            '🔴 Майстер ${master.name} зайнята ЗАРАЗ: сесія ${session.clientName} до ${sessionEndTime.hour}:${sessionEndTime.minute.toString().padLeft(2, '0')}',
          );
        } else if (isFutureSessionInTwoHours) {
          print(
            '🟡 Майстер ${master.name} буде зайнята: сесія ${session.clientName} о ${sessionStartTime.hour}:${sessionStartTime.minute.toString().padLeft(2, '0')}',
          );
        }

        return isCurrentSession || isFutureSessionInTwoHours;
      } catch (e) {
        print(
          'Помилка парсингу дати/часу для сесії: ${session.date} ${session.time}',
        );
        return false;
      }
    });

    // Повертаємо відповідний статус
    return hasBusySession ? MasterStatus.busy : MasterStatus.available;
  }
}

enum MasterStatus { available, busy, unavailable }

class MasterCard extends StatelessWidget {
  final String masterName;
  final String masterId;
  final MasterStatus status;
  final Map<String, dynamic> sessionInfo;

  const MasterCard({
    super.key,
    required this.masterName,
    required this.masterId,
    required this.status,
    required this.sessionInfo,
  });

  Color _getStatusColor() {
    switch (status) {
      case MasterStatus.available:
        return Colors.green;
      case MasterStatus.busy:
        return Colors.orange;
      case MasterStatus.unavailable:
        return Colors.red;
    }
  }

  String _getStatusText(BuildContext context) {
    final language = Provider.of<LanguageProvider>(context, listen: false);
    switch (status) {
      case MasterStatus.available:
        return language.getText('Вільна', 'Свободна');
      case MasterStatus.busy:
        return language.getText('Зайнята', 'Занята');
      case MasterStatus.unavailable:
        return language.getText('Недоступна', 'Недоступна');
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case MasterStatus.available:
        return Icons.check_circle;
      case MasterStatus.busy:
        return Icons.schedule;
      case MasterStatus.unavailable:
        return Icons.cancel;
    }
  }

  String? _getMasterPhotoPath() {
    // Перетворюємо ім'я майстрині на lowercase для назви файлу
    final name = masterName.toLowerCase();
    
    // Підтримувані формати фотографій
    final formats = ['jpg', 'jpeg', 'png', 'webp'];
    
    // Перевіряємо який формат файлу існує
    for (final format in formats) {
      final path = 'assets/images/masters/$name.$format';
      // В Flutter assets завжди вважаються існуючими якщо вони додані в pubspec.yaml
      // Спробуємо з найпоширенішими іменами
      if (name == 'настя' || name == 'nastya' || name == 'анастасія' || name == 'анастасия') {
        return 'assets/images/masters/nastya.$format';
      } else if (name == 'ніка' || name == 'ника' || name == 'nika' || name == 'вероніка' || name == 'вероника') {
        return 'assets/images/masters/nika.$format';
      }
    }
    
    // Якщо фото не знайдено, повертаємо null
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            highlightColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.05),
            hoverColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.04),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CalendarPage(masterName: masterName, masterId: masterId),
                ),
              );

              // Якщо повернулися з календаря, оновлюємо дані (форсовано для синхронізації)
              if (context.mounted) {
                final appState = Provider.of<AppStateProvider>(
                  context,
                  listen: false,
                );
                await appState.refreshAllData(forceRefresh: true);
              }
            },
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Верхняя часть с именем и статусом
                  Row(
                    children: [
                      // Аватар мастера
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _getMasterPhotoPath() == null
                              ? LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                )
                              : null,
                        ),
                        child: _getMasterPhotoPath() != null
                            ? ClipOval(
                                child: Image.asset(
                                  _getMasterPhotoPath()!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Якщо фото не завантажилось, показуємо іконку
                                    return Container(
                                      width: 80,
                                      height: 80,
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
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              ),
                      ),
                      SizedBox(width: 16),

                      // Информация о мастере
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              masterName,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Индикатор статуса
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(),
                              color: _getStatusColor(),
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _getStatusText(context),
                              style: TextStyle(
                                color: _getStatusColor(),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Нижняя часть с информацией о следующем сеансе
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Consumer<LanguageProvider>(
                            builder: (context, language, child) {
                              final status = sessionInfo['status'] ?? 'none';
                              final displayText = sessionInfo['displayText'];

                              String finalText;
                              if (status == 'current') {
                                finalText = language.getText(
                                  'Зараз триває запис: $displayText',
                                  'Сейчас идет сеанс: $displayText',
                                );
                              } else if (status == 'next') {
                                finalText = language.getText(
                                  'Наступний сеанс: $displayText',
                                  'Следующий сеанс: $displayText',
                                );
                              } else {
                                // Для всіх випадків відсутності записів показуємо один текст
                                finalText = language.getText(
                                  'Немає записів на поточний місяць + 2 наступних',
                                  'Нет записей на текущий месяц + 2 следующих',
                                );
                              }

                              return Text(
                                finalText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
