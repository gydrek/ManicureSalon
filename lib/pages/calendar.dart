import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:developer' as developer;
import 'package:nastya_app/pages/clientList.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/widgets/update_info_widget.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/providers/language_provider.dart';

class CalendarPage extends StatefulWidget {
  final String masterName;
  final String masterId;

  const CalendarPage({
    super.key,
    required this.masterName,
    required this.masterId,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOff;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Firebase сервіс
  final FirestoreService _firestoreService = FirestoreService();

  // Кеш даних по місяцях для оптимізації
  final Map<String, Map<DateTime, List<Event>>> _monthCache = {};
  bool _isLoading = false;

  // Отримати локалізовані назви місяців
  Map<int, String> _getLocalizedMonths(LanguageProvider language) {
    return {
      1: language.getText('Січень', 'Январь'),
      2: language.getText('Лютий', 'Февраль'),
      3: language.getText('Березень', 'Март'),
      4: language.getText('Квітень', 'Апрель'),
      5: language.getText('Травень', 'Май'),
      6: language.getText('Червень', 'Июнь'),
      7: language.getText('Липень', 'Июль'),
      8: language.getText('Серпень', 'Август'),
      9: language.getText('Вересень', 'Сентябрь'),
      10: language.getText('Жовтень', 'Октябрь'),
      11: language.getText('Листопад', 'Ноябрь'),
      12: language.getText('Грудень', 'Декабрь'),
    };
  }

  // Отримати локалізовані назви днів тижня
  List<String> _getLocalizedDaysOfWeek(LanguageProvider language) {
    return [
      language.getText('Пн', 'Пн'),
      language.getText('Вт', 'Вт'),
      language.getText('Ср', 'Ср'),
      language.getText('Чт', 'Чт'),
      language.getText('Пт', 'Пт'),
      language.getText('Сб', 'Сб'),
      language.getText('Нд', 'Вс'),
    ];
  }

  @override
  void initState() {
    super.initState();

    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier([]);

    // Завантажуємо дані для поточного місяця
    _loadMonthEvents(_selectedDay!).then((_) {
      // Після завантаження оновлюємо selected events для поточного дня
      setState(() {
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
    });
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  /// Отримати шлях до фото майстрині
  String? _getMasterPhotoPath(String masterName) {
    // Перетворюємо ім'я майстрині на lowercase для назви файлу
    final name = masterName.toLowerCase();
    
    // Підтримувані формати фотографій
    final formats = ['jpg', 'jpeg', 'png', 'webp'];
    
    // Перевіряємо який формат файлу існує
    for (final format in formats) {
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

  // Оновлення даних календаря після повернення з інших сторінок
  Future<void> _refreshCalendarData() async {
    // Очищуємо кеш для поточного місяця
    final monthKey =
        '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';
    _monthCache.remove(monthKey);

    // Перезавантажуємо дані для поточного місяця
    await _loadMonthEvents(_focusedDay);

    // Оновлюємо події для обраного дня
    setState(() {
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  // Завантажити події для місяця (оптимізовано)
  Future<void> _loadMonthEvents(DateTime month) async {
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    // Перевіряємо кеш
    if (_monthCache.containsKey(monthKey)) {
      setState(() {
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      developer.log(
        '📅 Завантажуємо події для місяця: $monthKey, майстер: ${widget.masterId}',
        name: 'calendar',
      );

      // Завантажуємо всі сесії майстра за місяць
      final sessions = await _firestoreService.getSessionsByMasterAndMonth(
        widget.masterId,
        month.year,
        month.month,
      );

      developer.log(
        '✅ Знайдено сесій за місяць: ${sessions.length}',
        name: 'calendar',
      );

      // Групуємо по датах
      final Map<DateTime, List<Event>> monthEvents = {};

      for (final session in sessions) {
        try {
          // Парсимо дату з формату "2025-10-22"
          final dateParts = session.date.split('-');
          final eventDate = DateTime(
            int.parse(dateParts[0]), // рік
            int.parse(dateParts[1]), // місяць
            int.parse(dateParts[2]), // день
          );

          final event = Event(
            '${session.clientName} - ${session.time}',
            session.time,
          );

          if (monthEvents[eventDate] == null) {
            monthEvents[eventDate] = [];
          }
          monthEvents[eventDate]!.add(event);
        } catch (e) {
          developer.log(
            '❌ Помилка парсингу дати: ${session.date}, помилка: $e',
            name: 'calendar',
          );
        }
      }

      // Зберігаємо в кеш
      _monthCache[monthKey] = monthEvents;
      developer.log(
        '💾 Кешовано події для місяця $monthKey: ${monthEvents.length} днів',
        name: 'calendar',
      );

      setState(() {
        _isLoading = false;
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
    } catch (e) {
      developer.log('❌ Помилка завантаження подій: $e', name: 'calendar');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Отримати події для конкретного дня
  List<Event> _getEventsForDay(DateTime day) {
    final monthKey = '${day.year}-${day.month.toString().padLeft(2, '0')}';
    final monthEvents = _monthCache[monthKey];

    if (monthEvents == null) return [];

    final dayEvents = monthEvents[DateTime(day.year, day.month, day.day)] ?? [];
    developer.log(
      '📋 Події для дня ${day.day}.${day.month}: ${dayEvents.length}',
      name: 'calendar',
    );
    return dayEvents;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    // Завжди оновлюємо стан і переходимо до списку записів
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _rangeSelectionMode = RangeSelectionMode.toggledOff;
    });

    _selectedEvents.value = _getEventsForDay(selectedDay);

    // Переходимо до списку клієнтів при БУДЬ-ЯКОМУ натисканні на день
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientListPage(
          masterName: widget.masterName,
          masterId: widget.masterId,
          selectedDate: selectedDay,
        ),
      ),
    );

    // Якщо повернулися з ClientListPage, оновлюємо дані
    if (result != null || mounted) {
      await _refreshCalendarData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          title: Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return Text(
                language.getText('Календар', 'Календарь'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              );
            },
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            if (_isLoading)
              Container(
                margin: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            // Оновлюємо через централізований провайдер (з кешем)
            final appState = Provider.of<AppStateProvider>(
              context,
              listen: false,
            );
            await appState.refreshAllData(forceRefresh: true);

            // Також оновлюємо локальні дані календаря
            await _refreshCalendarData(); // Показуємо повідомлення
            if (mounted) {
              final language = Provider.of<LanguageProvider>(
                context,
                listen: false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        language.getText(
                          'Календар оновлено',
                          'Календарь обновлен',
                        ),
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
            child: Column(
              children: [
                // Інформація про оновлення
                UpdateInfoWidget(margin: EdgeInsets.symmetric(horizontal: 16)),

                // Інформаційна картка про майстра
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _getMasterPhotoPath(widget.masterName) == null
                              ? LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                )
                              : null,
                        ),
                        child: _getMasterPhotoPath(widget.masterName) != null
                            ? ClipOval(
                                child: Image.asset(
                                  _getMasterPhotoPath(widget.masterName)!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Якщо фото не завантажилось, показуємо іконку
                                    return Container(
                                      width: 50,
                                      height: 50,
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
                                        color: Colors.white,
                                        size: 25,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 25,
                              ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Consumer2<LanguageProvider, AppStateProvider>(
                              builder: (context, language, appState, child) {
                                final master = appState.masters.firstWhere(
                                  (m) => m.id == widget.masterId,
                                  orElse: () => appState.masters.first,
                                );
                                return Text(
                                  '${language.getText('Майстриня', 'Мастерица')}: ${master.getLocalizedName(language.currentLocale.languageCode)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Календар
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return TableCalendar<Event>(
                          firstDay: DateTime.utc(2024, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          eventLoader: _getEventsForDay,
                          rangeSelectionMode: _rangeSelectionMode,
                          locale: 'uk_UA', // Українська локалізація
                          // Українські назви днів тижня та місяців
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          daysOfWeekVisible: true,

                          // Стилізація
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            weekendTextStyle: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            holidayTextStyle: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary,
                              shape: BoxShape.circle,
                            ),
                            markersMaxCount: 1, // Показуємо тільки один маркер
                            canMarkersOverflow: false,

                            // Кастомний маркер з кількістю
                            markerSizeScale: 0.2,
                          ),

                          // Кастомний маркер з кількістю записів
                          calendarBuilders: CalendarBuilders<Event>(
                            markerBuilder: (context, day, events) {
                              developer.log(
                                '🔍 MarkerBuilder для дня ${day.day}.${day.month}: ${events.length} подій',
                                name: 'calendar',
                              );

                              if (events.isEmpty) return null;

                              final eventCount = events.length;
                              final displayText = eventCount > 4
                                  ? '4+'
                                  : eventCount.toString();
                              final markerColor = eventCount > 4
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary;

                              developer.log(
                                '📍 Створюємо маркер для дня ${day.day}: $displayText',
                                name: 'calendar',
                              );

                              return Positioned(
                                bottom: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: markerColor.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Стилізація заголовків
                          headerStyle: HeaderStyle(
                            formatButtonVisible: true,
                            titleCentered: true,
                            formatButtonShowsNext: false,
                            formatButtonDecoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            formatButtonTextStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            titleTextFormatter: (date, locale) {
                              final localizedMonths = _getLocalizedMonths(
                                language,
                              );
                              return '${localizedMonths[date.month]} ${date.year}';
                            },
                            titleTextStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),

                          // Локалізовані назви днів тижня
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            weekendStyle: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                            dowTextFormatter: (date, locale) {
                              final localizedDays = _getLocalizedDaysOfWeek(
                                language,
                              );
                              return localizedDays[date.weekday - 1];
                            },
                          ),

                          // Локалізовані назви форматів календаря
                          availableCalendarFormats: {
                            CalendarFormat.month: language.getText(
                              'Місяць',
                              'Месяц',
                            ),
                            CalendarFormat.twoWeeks: language.getText(
                              '2 тижні',
                              '2 недели',
                            ),
                            CalendarFormat.week: language.getText(
                              'Тиждень',
                              'Неделя',
                            ),
                          },

                          // Обробники подій
                          onDaySelected: _onDaySelected,
                          onFormatChanged: (format) {
                            if (_calendarFormat != format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            }
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                            // Завантажуємо дані для нового місяця
                            _loadMonthEvents(focusedDay);
                          },

                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                        );
                      },
                    ),
                  ),
                ),

                // Додаємо трохи відступу знизу
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Клас для подій календаря
class Event {
  final String title;
  final String time;

  const Event(this.title, this.time);

  @override
  String toString() => title;
}
