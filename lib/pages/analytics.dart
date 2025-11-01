import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/models/models.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/widgets/update_info_widget.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  List<Master> _masters = [];
  Map<String, int> _masterStats = {};
  Map<String, double> _masterRevenue = {};
  Map<String, Color> _masterColors = {};
  double _totalRevenue = 0.0;

  // Кешування та час оновлення
  DateTime? _lastUpdateTime;
  String _lastSelectedMonthKey = '';
  static const Duration _cacheValidDuration = Duration(minutes: 3);

  // Кольори для кругової діаграми
  final List<Color> _chartColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentMonthKey = '${_selectedMonth.year}-${_selectedMonth.month}';
      final now = DateTime.now();

      // Перевіряємо чи потрібно використовувати кеш
      final shouldUseCache =
          !forceRefresh &&
          _lastUpdateTime != null &&
          _lastSelectedMonthKey == currentMonthKey &&
          now.difference(_lastUpdateTime!) < _cacheValidDuration &&
          _masters.isNotEmpty;

      if (shouldUseCache) {
        print('📱 Використовуємо кеш для статистики за $currentMonthKey');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('🔄 Оновлюємо дані статистики за $currentMonthKey');

      // Завантажуємо майстрів
      _masters = await _firestoreService.getMasters();

      // Ініціалізуємо статистику
      _masterStats.clear();
      _masterRevenue.clear();
      _masterColors.clear();

      for (int i = 0; i < _masters.length; i++) {
        final master = _masters[i];
        _masterColors[master.id!] = _chartColors[i % _chartColors.length];
        _masterStats[master.id!] = 0;
        _masterRevenue[master.id!] = 0.0;
      }

      // Завантажуємо сесії за вибраний місяць
      await _loadSessionsForMonth();

      // Оновлюємо час останнього оновлення та ключ місяця
      _lastUpdateTime = now;
      _lastSelectedMonthKey = currentMonthKey;
    } catch (e) {
      print('Помилка завантаження даних аналітики: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSessionsForMonth() async {
    try {
      // Отримуємо початок і кінець місяця
      final startOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final endOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      );

      final startDateString = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endDateString = DateFormat('yyyy-MM-dd').format(endOfMonth);

      // Завантажуємо сесії за період
      final sessions = await _firestoreService.getSessionsForDateRange(
        startDateString,
        endDateString,
      );

      print('📊 Analytics Debug:');
      print('📅 Період: $startDateString - $endDateString');
      print('📊 Знайдено сесій: ${sessions.length}');
      print('👥 Майстрині: ${_masters.map((m) => '${m.name}(${m.id})').join(', ')}');

      // Рахуємо записи та загальну ціну по майстрах
      _masterStats.clear();
      _masterRevenue.clear();
      _totalRevenue = 0.0;

      for (final master in _masters) {
        _masterStats[master.id!] = 0;
        _masterRevenue[master.id!] = 0.0;
      }

      for (final session in sessions) {
        print('📋 Сесія: ${session.clientName}, майстер: ${session.masterId}, ціна: ${session.price}, дата: ${session.date}');
        
        if (_masterStats.containsKey(session.masterId)) {
          _masterStats[session.masterId] = _masterStats[session.masterId]! + 1;
          // Додаємо ціну до загальної суми та до майстра
          if (session.price != null) {
            _totalRevenue += session.price!;
            _masterRevenue[session.masterId] =
                _masterRevenue[session.masterId]! + session.price!;
          }
          print('✅ Додано до майстра ${session.masterId}: кількість=${_masterStats[session.masterId]}, дохід=${_masterRevenue[session.masterId]}');
        } else {
          print('❌ Майстер ${session.masterId} не знайдений в списку майстрів!');
        }
      }

      print('🏆 Фінальна статистика:');
      for (final master in _masters) {
        print('${master.name}: ${_masterStats[master.id!]} записів, ${_masterRevenue[master.id!]}€');
      }

      setState(() {});
    } catch (e) {
      print('Помилка завантаження сесій: $e');
    }
  }

  Future<void> _selectMonth() async {
    final language = Provider.of<LanguageProvider>(context, listen: false);

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) =>
          _MonthPickerDialog(selectedMonth: _selectedMonth, language: language),
    );

    if (result != null) {
      setState(() {
        _selectedMonth = result;
      });
      // Примусово оновлюємо дані при зміні місяця
      await _loadData(forceRefresh: true);
    }
  }

  String _getMonthName(DateTime date, LanguageProvider language) {
    final ukrainianMonths = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень',
    ];
    final russianMonths = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    final months = language.getText(
      ukrainianMonths[date.month - 1],
      russianMonths[date.month - 1],
    );

    return '$months ${date.year}';
  }

  List<PieChartSectionData> _generateChartSections() {
    final List<PieChartSectionData> sections = [];
    final totalSessions = _masterStats.values.fold(
      0,
      (sum, count) => sum + count,
    );

    if (totalSessions == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 100,
          title: '',
          radius: 100,
        ),
      ];
    }

    _masterStats.forEach((masterId, sessionCount) {
      if (sessionCount > 0) {
        final percentage = (sessionCount / totalSessions * 100);

        sections.add(
          PieChartSectionData(
            color: _masterColors[masterId]!,
            value: percentage,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    return sections;
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
                language.getText('Статистика', 'Статистика'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              );
            },
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: _isLoading
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
                              'Завантажуємо статистику...',
                              'Загружаем статистику...',
                            ),
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
              : RefreshIndicator(
                  onRefresh: () async {
                    final appState = Provider.of<AppStateProvider>(
                      context,
                      listen: false,
                    );
                    await appState.refreshAllData(
                      forceRefresh: true,
                    ); // Оновлюємо глобальний час
                    await _loadData(forceRefresh: true);

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
                                      'Статистику оновлено свайпом',
                                      'Статистика обновлена свайпом',
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Інформація про останнє оновлення
                          UpdateInfoWidget(),

                          // Основний контент
                          // Вибір місяця
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
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
                                Icon(
                                  Icons.calendar_month,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Consumer<LanguageProvider>(
                                    builder: (context, language, child) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            language.getText(
                                              'Обраний період:',
                                              'Выбранный период:',
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          Text(
                                            _getMonthName(
                                              _selectedMonth,
                                              language,
                                            ),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _selectMonth,
                                  icon: Icon(Icons.edit_calendar),
                                  label: Consumer<LanguageProvider>(
                                    builder: (context, language, child) {
                                      return Text(
                                        language.getText('Змінити', 'Изменить'),
                                      );
                                    },
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 24),

                          // Загальна статистика
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.secondary,
                                  Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Consumer<LanguageProvider>(
                              builder: (context, language, child) {
                                final totalSessions = _masterStats.values.fold(
                                  0,
                                  (sum, count) => sum + count,
                                );
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.assessment,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          language.getText(
                                            'Загальна статистика',
                                            'Общая статистика',
                                          ),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Column(
                                          children: [
                                            Text(
                                              '$totalSessions',
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              language.getText(
                                                'Записів',
                                                'Записей',
                                              ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: 1,
                                          height: 50,
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              '${_totalRevenue.toStringAsFixed(2)}€',
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              language.getText(
                                                'Загальна ціна',
                                                'Общая цена',
                                              ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          SizedBox(height: 24),

                          // Заголовок діаграми
                          Consumer<LanguageProvider>(
                            builder: (context, language, child) {
                              return Text(
                                language.getText(
                                  'Розподіл записів по майстриням',
                                  'Распределение записей по мастерицам',
                                ),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 16),

                          // Кругова діаграма
                          Container(
                            height: 300,
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child:
                                _masterStats.values.fold(
                                      0,
                                      (sum, count) => sum + count,
                                    ) ==
                                    0
                                ? Center(
                                    child: Consumer<LanguageProvider>(
                                      builder: (context, language, child) {
                                        return Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.analytics_outlined,
                                              size: 64,
                                              color: Colors.grey.shade400,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              language.getText(
                                                'Немає даних за цей період',
                                                'Нет данных за этот период',
                                              ),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  )
                                : PieChart(
                                    PieChartData(
                                      sections: _generateChartSections(),
                                      borderData: FlBorderData(show: false),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 0,
                                    ),
                                  ),
                          ),

                          SizedBox(height: 24),

                          // Легенда
                          Consumer<LanguageProvider>(
                            builder: (context, language, child) {
                              return Text(
                                language.getText(
                                  'Деталізована статистика',
                                  'Детализированная статистика',
                                ),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 16),

                          // Список майстрів зі статистикою
                          Builder(
                            builder: (context) {
                              // Сортуємо майстрів спочатку по доходу (спадаючи), потім по кількості записів (спадаючи)
                              final sortedMasters = List<Master>.from(_masters);
                              sortedMasters.sort((a, b) {
                                final revenueA = _masterRevenue[a.id!] ?? 0.0;
                                final revenueB = _masterRevenue[b.id!] ?? 0.0;
                                final sessionCountA = _masterStats[a.id!] ?? 0;
                                final sessionCountB = _masterStats[b.id!] ?? 0;
                                
                                // Спочатку порівнюємо по доходу (більший дохід - вище)
                                final revenueComparison = revenueB.compareTo(revenueA);
                                if (revenueComparison != 0) {
                                  return revenueComparison;
                                }
                                
                                // Якщо дохід однаковий, порівнюємо по кількості записів (більше записів - вище)
                                return sessionCountB.compareTo(sessionCountA);
                              });
                              
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: sortedMasters.length,
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final master = sortedMasters[index];
                              final sessionCount =
                                  _masterStats[master.id!] ?? 0;
                              final totalSessions = _masterStats.values.fold(
                                0,
                                (sum, count) => sum + count,
                              );
                              final percentage = totalSessions > 0
                                  ? (sessionCount / totalSessions * 100)
                                  : 0.0;

                              return Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _masterColors[master.id!]!
                                        .withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Кольоровий індикатор
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: _masterColors[master.id!]!,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 16),

                                    // Інформація про майстра
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Consumer<LanguageProvider>(
                                            builder:
                                                (context, language, child) {
                                                  return Text(
                                                    master.getLocalizedName(
                                                      language
                                                          .currentLocale
                                                          .languageCode,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                    ),
                                                  );
                                                },
                                          ),
                                          SizedBox(height: 4),
                                          Consumer<LanguageProvider>(
                                            builder:
                                                (context, language, child) {
                                                  return Text(
                                                    language.getText(
                                                      '$sessionCount записів',
                                                      '$sessionCount записей',
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Відсоток та дохід
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        // Відсоток
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _masterColors[master.id!]!
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            '${percentage.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: _masterColors[master.id!]!,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        // Дохід майстра
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.euro,
                                                size: 16,
                                                color: Colors.green[700],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '${(_masterRevenue[master.id!] ?? 0.0).toStringAsFixed(2)}€',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                                },
                              );
                            },
                          ),

                          SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime selectedMonth;
  final LanguageProvider language;

  const _MonthPickerDialog({
    required this.selectedMonth,
    required this.language,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.selectedMonth.year;
    _selectedMonth = widget.selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final ukrainianMonths = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень',
    ];
    final russianMonths = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    final monthNames = widget.language.currentLocale.languageCode == 'uk'
        ? ukrainianMonths
        : russianMonths;

    return AlertDialog(
      title: Text(widget.language.getText('Оберіть місяць', 'Выберите месяц')),
      content: Container(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Вибір року
            Row(
              children: [
                Text(
                  widget.language.getText('Рік:', 'Год:'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    isExpanded: true,
                    items: List.generate(10, (index) {
                      final year = DateTime.now().year - 5 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text('$year'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Вибір місяця
            Text(
              widget.language.getText('Місяць:', 'Месяц:'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthIndex = index + 1;
                  final isSelected = monthIndex == _selectedMonth;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMonth = monthIndex;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          monthNames[index],
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.language.getText('Скасувати', 'Отменить')),
        ),
        ElevatedButton(
          onPressed: () {
            final selectedDate = DateTime(_selectedYear, _selectedMonth, 1);
            Navigator.pop(context, selectedDate);
          },
          child: Text(widget.language.getText('Вибрати', 'Выбрать')),
        ),
      ],
    );
  }
}
