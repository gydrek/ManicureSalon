import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/models/models.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/pages/sessionEdit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nastya_app/widgets/update_info_widget.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();

  List<Session> _allSessions = [];
  List<Session> _filteredSessions = [];
  List<Master> _masters = [];

  String _selectedMasterFilter = 'Всі майстрині';
  String _selectedStatusFilter = 'Всі статуси';
  DateTime _selectedMonth = DateTime.now(); // Замінюємо _selectedDate на _selectedMonth
  bool _isLoading = true;

  String _getLocalizedService(String service, LanguageProvider language) {
    switch (service) {
      case 'Манікюр класичний':
        return language.getText('Манікюр класичний', 'Маникюр классический');
      case 'Покриття гель-лак (руки)':
        return language.getText('Покриття гель-лак (руки)', 'Покрытие гель-лак (руки)');
      case 'Манікюр':
        return language.getText('Манікюр', 'Маникюр');
      case 'Нарощування нігтів (стандарт)':
        return language.getText('Нарощування нігтів (стандарт)', 'Наращивание ногтей (стандарт)');
      case 'Нарощування нігтів (довге)':
        return language.getText('Нарощування нігтів (довге)', 'Наращивание ногтей (длинное)');
      case 'Манікюр чоловічий':
        return language.getText('Манікюр чоловічий', 'Маникюр мужской');
      case 'Педикюр класичний':
        return language.getText('Педикюр класичний', 'Педикюр классический');
      case 'Педикюр класиний + покриття гель-лак':
        return language.getText('Педикюр класиний + покриття гель-лак', 'Педикюр классический + покрытие гель-лак');
      case 'Покриття гель-лак (ноги)':
        return language.getText('Покриття гель-лак (ноги)', 'Покрытие гель-лак (ноги)');
      case 'Нарощування вій':
        return language.getText('Нарощування вій', 'Наращивание ресниц');
      case 'Нарощування нижніх вій':
        return language.getText('Нарощування нижніх вій', 'Наращивание нижних ресниц');
      case 'Ремонт':
        return language.getText('Ремонт', 'Ремонт');
      default:
        return service;
    }
  }

  List<String> _getLocalizedMonths(LanguageProvider language) {
    return [
      language.getText('січня', 'января'),
      language.getText('лютого', 'февраля'),
      language.getText('березня', 'марта'),
      language.getText('квітня', 'апреля'),
      language.getText('травня', 'мая'),
      language.getText('червня', 'июня'),
      language.getText('липня', 'июля'),
      language.getText('серпня', 'августа'),
      language.getText('вересня', 'сентября'),
      language.getText('жовтня', 'октября'),
      language.getText('листопада', 'ноября'),
      language.getText('грудня', 'декабря'),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
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
      print('📱 Архів: додаток повернувся в активний стан - оновлюємо дані...');
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      // Форсуємо оновлення для синхронізації з іншими пристроями
      appState.refreshAllData(forceRefresh: true).then((_) {
        // Також оновлюємо локальні дані архіву
        _loadData();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Завантажуємо дані архіву за ${_selectedMonth.month}/${_selectedMonth.year}');
      
      // Завантажуємо майстрів з AppStateProvider або напряму
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      
      if (appState.masters.isNotEmpty) {
        _masters = appState.masters;
      } else {
        _masters = await _firestoreService.getMasters();
      }

      // Завантажуємо сесії за обраний місяць
      final sessions = await _firestoreService.getSessionsByMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );

      setState(() {
        _allSessions = sessions;
        _filteredSessions = sessions;
        _isLoading = false;
      });

      _applyFilters();
      print('✅ Завантажено ${sessions.length} сесій за ${_selectedMonth.month}/${_selectedMonth.year}');
    } catch (e) {
      print('❌ Помилка завантаження даних: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Оновити дані тільки за поточний обраний місяць
  Future<void> _refreshCurrentMonth() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Оновлюємо дані архіву за ${_selectedMonth.month}/${_selectedMonth.year}...');

      // Оновлюємо майстрів з AppStateProvider
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      await appState.refreshAllData(forceRefresh: true);
      
      if (appState.masters.isNotEmpty) {
        _masters = appState.masters;
      } else {
        _masters = await _firestoreService.getMasters();
      }

      // Завантажуємо свіжі дані тільки за обраний місяць
      final sessions = await _firestoreService.getSessionsByMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );

      setState(() {
        _allSessions = sessions;
        _filteredSessions = sessions;
        _isLoading = false;
      });

      _applyFilters();
      print('✅ Дані архіву за ${_selectedMonth.month}/${_selectedMonth.year} оновлені (${sessions.length} сесій)');
    } catch (e) {
      print('❌ Помилка оновлення архіву: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Отримуємо всі сесії з AppStateProvider


  void _applyFilters() {
    setState(() {
      _filteredSessions = _allSessions.where((session) {
        // Фільтр по майстру
        bool masterMatch =
            _selectedMasterFilter == 'Всі майстрині' ||
            session.masterId == _selectedMasterFilter;

        // Фільтр по статусу
        bool statusMatch =
            _selectedStatusFilter == 'Всі статуси' ||
            session.status == _selectedStatusFilter;

        // Дата фільтрація не потрібна, оскільки завантажуємо тільки за обраний місяць
        return masterMatch && statusMatch;
      }).toList();

      // Сортуємо по даті (найновіші спочатку)
      _filteredSessions.sort((a, b) {
        int dateCompare = b.date.compareTo(a.date);
        if (dateCompare == 0) {
          return b.time.compareTo(a.time);
        }
        return dateCompare;
      });
    });
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
      // Перезавантажуємо дані для нового місяця
      await _loadData();
    }
  }

  String _getMonthName(DateTime date, LanguageProvider language) {
    final ukrainianMonths = [
      'Січень', 'Лютий', 'Березень', 'Квітень', 'Травень', 'Червень',
      'Липень', 'Серпень', 'Вересень', 'Жовтень', 'Листопад', 'Грудень',
    ];
    final russianMonths = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];

    final monthNames = language.currentLocale.languageCode == 'uk'
        ? ukrainianMonths
        : russianMonths;

    return '${monthNames[date.month - 1]} ${date.year}';
  }

  String _getMasterName(String masterId, String languageCode) {
    final master = _masters.firstWhere(
      (m) => m.id == masterId,
      orElse: () => Master(name: 'Невідомий майстер', status: 'unknown'),
    );
    return master.getLocalizedName(languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return Text(
                language.getText('Архів записів', 'Архив записей'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              );
            },
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          centerTitle: true,
          actions: [
            Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return IconButton(
                  icon: Icon(
                    Icons.date_range,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _selectMonth,
                  tooltip: '${language.getText('Місяць', 'Месяц')}: ${_getMonthName(_selectedMonth, language)}',
                );
              },
            ),
          ],
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
                              'Завантажуємо архів...',
                              'Загружаем архив...',
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
                    print('🔄 Оновлення архіву через свайп за ${_selectedMonth.month}/${_selectedMonth.year}...');

                    // Оновлюємо тільки поточний обраний місяць
                    await _refreshCurrentMonth();

                    print('✅ Архів за ${_selectedMonth.month}/${_selectedMonth.year} оновлено');

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
                                      'Архів оновлено свайпом',
                                      'Архив обновлен свайпом',
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
                    child: Column(
                      children: [
                        // Фільтри
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildMasterFilter()),
                                  SizedBox(width: 12),
                                  Expanded(child: _buildStatusFilter()),
                                ],
                              ),
                              SizedBox(height: 12),

                              // Індикатор обраного місяця
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.date_range,
                                      size: 16,
                                      color: Colors.brown,
                                    ),
                                    SizedBox(width: 6),
                                    Consumer<LanguageProvider>(
                                      builder: (context, language, child) {
                                        return Text(
                                          '${language.getText('Місяць', 'Месяц')}: ${_getMonthName(_selectedMonth, language)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.brown,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              _buildStatsRow(),
                            ],
                          ),
                        ),

                        // Інформація про останнє оновлення
                        UpdateInfoWidget(
                          margin: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                        ),

                        // Список записів або порожній стан
                        _filteredSessions.isEmpty
                            ? Container(height: 400, child: _buildEmptyState())
                            : Column(
                                children: List.generate(
                                  _filteredSessions.length,
                                  (index) {
                                    final session = _filteredSessions[index];
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      child: _buildSessionCard(session),
                                    );
                                  },
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

  Widget _buildMasterFilter() {
    List<String> masterOptions = ['Всі майстрині'];
    masterOptions.addAll(_masters.map((m) => m.id!));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedMasterFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).getText('Майстриня', 'Мастерица'),
          prefixIcon: Icon(Icons.person_outline),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        items: masterOptions.map((masterId) {
          final language = Provider.of<LanguageProvider>(
            context,
            listen: false,
          );
          String displayName = masterId == 'Всі майстрині'
              ? language.getText('Всі майстрині', 'Все мастерицы')
              : _getMasterName(masterId, language.currentLocale.languageCode);
          return DropdownMenuItem(
            value: masterId,
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedMasterFilter = value!;
          });
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedStatusFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).getText('Статус', 'Статус'),
          prefixIcon: Icon(Icons.assignment_outlined),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        items: [
          DropdownMenuItem(
            value: 'Всі статуси',
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.grey.shade600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        language.getText('Всі статуси', 'Все статусы'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          DropdownMenuItem(
            value: 'в очікуванні',
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        language.getText('В очікуванні', 'В ожидании'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          DropdownMenuItem(
            value: 'успішно',
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        language.getText('Успішно', 'Успешно'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          DropdownMenuItem(
            value: 'пропущено',
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Row(
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        language.getText('Пропущено', 'Пропущено'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _selectedStatusFilter = value!;
          });
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildStatsRow() {
    int total = _filteredSessions.length;
    int successful = _filteredSessions
        .where((s) => s.status == 'успішно')
        .length;
    int pending = _filteredSessions
        .where((s) => s.status == 'в очікуванні')
        .length;
    int missed = _filteredSessions.where((s) => s.status == 'пропущено').length;

    return Consumer<LanguageProvider>(
      builder: (context, language, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatChip(
              language.getText('Всього', 'Всего'),
              total,
              Colors.blue,
            ),
            _buildStatChip(
              language.getText('Успішно', 'Успешно'),
              successful,
              Colors.green,
            ),
            _buildStatChip(
              language.getText('Очікують', 'Ожидают'),
              pending,
              Colors.orange,
            ),
            _buildStatChip(
              language.getText('Пропущено', 'Пропущено'),
              missed,
              Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Column(
                  children: [
                    Text(
                      language.getText(
                        'Записи не знайдені',
                        'Записи не найдены',
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      language.getText(
                        'Спробуйте змінити фільтри',
                        'Попробуйте изменить фильтры',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Основний контент картки
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Верхній рядок з датою та статусом
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(session.date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    _buildStatusChip(session.status),
                  ],
                ),

                SizedBox(height: 12),

                // Основна інформація (з відступом справа для кнопок)
                Padding(
                  padding: EdgeInsets.only(right: 100), // Простір для кнопок
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Клієнт з VIP значком
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.clientName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (session.isRegularClient) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA500),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.diamond,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'VIP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: 4),

                      // Майстер
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            '${language.getText('Майстриня', 'Мастерица')}: ${_getMasterName(session.masterId, language.currentLocale.languageCode)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 2),

                      // Час та тривалість
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          // Розраховуємо час закінчення сесії
                          final startTime = session.time;
                          final timeParts = startTime.split(':');
                          final startMinutes = int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
                          final endMinutes = startMinutes + session.duration;
                          final endHour = (endMinutes ~/ 60).toString().padLeft(2, '0');
                          final endMinute = (endMinutes % 60).toString().padLeft(2, '0');
                          final endTime = '$endHour:$endMinute';
                          
                          return Text(
                            '${language.getText('Час', 'Время')}: $startTime-$endTime (${session.duration} ${language.getText('хв', 'мин')})',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 2),

                      // Послуга
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return Text(
                            '${language.getText('Послуга', 'Услуга')}: ${_getLocalizedService(session.service, language)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),

                      // Ціна
                      if (session.price != null) ...[
                        SizedBox(height: 2),
                        Consumer<LanguageProvider>(
                          builder: (context, language, child) {
                            return Text(
                              '${language.getText('Ціна', 'Цена')}: ${session.price!.toStringAsFixed(2)} €',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                      ],

                      // Примітки (якщо є)
                      if (session.notes != null &&
                          session.notes!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            session.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Кнопка телефону під статусом
          if (session.phone != null && session.phone!.isNotEmpty)
            Positioned(
              top: 50, // Нижче статусу
              right: 56, // Зліва від WhatsApp
              child: IconButton(
                onPressed: () => _makePhoneCall(session.phone!),
                icon: Icon(Icons.phone, color: Colors.blue[600], size: 28),
                tooltip: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).getText('Подзвонити', 'Позвонить'),
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),

          // WhatsApp кнопка під статусом
          if (session.phone != null && session.phone!.isNotEmpty)
            Positioned(
              top: 50, // Нижче статусу
              right: 8,
              child: IconButton(
                onPressed: () => _openWhatsApp(session.phone!),
                icon: FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366), // Офіційний колір WhatsApp
                  size: 28,
                ),
                tooltip: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).getText('Написати в WhatsApp', 'Написать в WhatsApp'),
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),

          // Кнопка редагування справа знизу
          Positioned(
            bottom: 8,
            right: 8,
            child: IconButton(
              onPressed: () => _editSession(session),
              icon: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
                size: 26,
              ),
              tooltip: Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).getText('Редагувати запис', 'Редактировать запись'),
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'успішно':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case 'пропущено':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.cancel_outlined;
        break;
      case 'в очікуванні':
      default:
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        icon = Icons.schedule;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          SizedBox(width: 4),
          Text(
            _getStatusText(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    final language = Provider.of<LanguageProvider>(context, listen: false);
    switch (status) {
      case 'успішно':
        return language.getText('Успішно', 'Успешно');
      case 'пропущено':
        return language.getText('Пропущено', 'Пропущено');
      case 'в очікуванні':
      default:
        return language.getText('В очікуванні', 'В ожидании');
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final language = Provider.of<LanguageProvider>(context, listen: false);
      final months = _getLocalizedMonths(language);
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _openWhatsApp(String phoneNumber) async {
    // Прибираємо всі символи крім цифр та +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  void _editSession(Session session) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionEditPage(session: session),
      ),
    );

    if (result == true) {
      // Інвалідуємо кеш в глобальному провайдері
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.invalidateCache();

      // Оновлюємо дані за поточний місяць
      await _refreshCurrentMonth();
    }
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
      'Січень', 'Лютий', 'Березень', 'Квітень', 'Травень', 'Червень',
      'Липень', 'Серпень', 'Вересень', 'Жовтень', 'Листопад', 'Грудень',
    ];
    final russianMonths = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
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
                      final year = DateTime.now().year - 8 + index;
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
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
