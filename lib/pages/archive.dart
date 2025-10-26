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

class _ArchivePageState extends State<ArchivePage> {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<Session> _allSessions = [];
  List<Session> _filteredSessions = [];
  List<Master> _masters = [];
  
  String _selectedMasterFilter = 'Всі майстрині';
  String _selectedStatusFilter = 'Всі статуси';
  DateTime? _selectedDate;
  bool _isLoading = true;

  String _getLocalizedService(String service, LanguageProvider language) {
    switch (service) {
      case 'Манікюр':
        return language.getText('Манікюр', 'Маникюр');
      case 'Педикюр':
        return language.getText('Педикюр', 'Педикюр');
      case 'Наращування нігтів':
        return language.getText('Наращування нігтів', 'Наращивание ногтей');
      case 'Дизайн нігтів':
        return language.getText('Дизайн нігтів', 'Дизайн ногтей');
      case 'Покриття гель-лак':
        return language.getText('Покриття гель-лак', 'Покрытие гель-лак');
      case 'Зняття покриття':
        return language.getText('Зняття покриття', 'Снятие покрытия');
      case 'Корекція':
        return language.getText('Корекція', 'Коррекция');
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
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Спочатку намагаємося використати дані з AppStateProvider
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      
      if (appState.masters.isNotEmpty) {
        // Використовуємо кешовані дані з AppStateProvider
        print('📦 Використовуємо кешовані дані з AppStateProvider');
        final allSessionsFromProvider = _getAllSessionsFromProvider(appState);
        
        setState(() {
          _allSessions = allSessionsFromProvider;
          _filteredSessions = allSessionsFromProvider;
          _masters = appState.masters;
          _isLoading = false;
        });
      } else {
        // Якщо AppStateProvider ще не завантажений, робимо прямі запити
        print('🔄 AppStateProvider порожній, завантажуємо напряму');
        final sessions = await _firestoreService.getAllSessions();
        final masters = await _firestoreService.getMasters();
        
        setState(() {
          _allSessions = sessions;
          _filteredSessions = sessions;
          _masters = masters;
          _isLoading = false;
        });
      }
      
      _applyFilters();
    } catch (e) {
      print('Помилка завантаження даних: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Отримуємо всі сесії з AppStateProvider
  List<Session> _getAllSessionsFromProvider(AppStateProvider appState) {
    final allSessions = <Session>[];
    
    // Збираємо сесії всіх майстрів
    for (final masterId in appState.sessionsByMaster.keys) {
      allSessions.addAll(appState.sessionsByMaster[masterId] ?? []);
    }
    
    // Сортуємо по даті (найновіші спочатку)
    allSessions.sort((a, b) {
      int dateCompare = b.date.compareTo(a.date);
      if (dateCompare == 0) {
        return b.time.compareTo(a.time);
      }
      return dateCompare;
    });
    
    return allSessions;
  }
  
  void _applyFilters() {
    setState(() {
      _filteredSessions = _allSessions.where((session) {
        // Фільтр по майстру
        bool masterMatch = _selectedMasterFilter == 'Всі майстрині' || 
            session.masterId == _selectedMasterFilter;
        
        // Фільтр по статусу
        bool statusMatch = _selectedStatusFilter == 'Всі статуси' || 
            session.status == _selectedStatusFilter;
        
        // Фільтр по даті
        bool dateMatch = _selectedDate == null || 
            session.date == _formatDateForComparison(_selectedDate!);
        
        return masterMatch && statusMatch && dateMatch;
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
  
  String _formatDateForComparison(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  String _formatDateDisplay(DateTime date) {
    final language = Provider.of<LanguageProvider>(context, listen: false);
    final months = _getLocalizedMonths(language);
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
  
  void _showDatePicker() async {
    final language = Provider.of<LanguageProvider>(context, listen: false);
    final locale = language.currentLocale.languageCode == 'uk' 
        ? Locale('uk', 'UA') 
        : Locale('ru', 'RU');
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(Duration(days: 365)),
      locale: locale,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _applyFilters();
    }
  }
  
  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _applyFilters();
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
        actions: [
          GestureDetector(
            onLongPress: _selectedDate != null ? _clearDateFilter : null,
            child: Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    color: _selectedDate != null 
                        ? Colors.amber.shade300 
                        : Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _showDatePicker,
                  tooltip: _selectedDate != null 
                      ? '${language.getText('Вибрана дата', 'Выбранная дата')}: ${_formatDateDisplay(_selectedDate!)}}' 
                      : language.getText('Вибрати дату', 'Выбрать дату'),
                );
              },
            ),
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
                          language.getText('Завантажуємо архів...', 'Загружаем архив...'),
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
                print('🔄 Оновлення архіву через свайп...');
                
                // Використовуємо AppStateProvider для примусового оновлення (для оновлення часу)
                await Provider.of<AppStateProvider>(context, listen: false).refreshAllData(forceRefresh: true);
                
                // Оновлюємо локальні дані архіву
                final appState = Provider.of<AppStateProvider>(context, listen: false);
                final allSessionsFromProvider = _getAllSessionsFromProvider(appState);
                
                setState(() {
                  _allSessions = allSessionsFromProvider;
                  _filteredSessions = allSessionsFromProvider;
                  _masters = appState.masters;
                });
                
                _applyFilters();
                
                print('✅ Архів оновлено з новим часом');
                
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
                              return Text(language.getText('Архів оновлено свайпом', 'Архив обновлен свайпом'));
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
                        color: Theme.of(context).colorScheme.primaryContainer,
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
                              Expanded(
                                child: _buildMasterFilter(),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildStatusFilter(),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          
                          // Індикатор активного фільтра дати
                          if (_selectedDate != null)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.amber.shade700,
                                  ),
                                  SizedBox(width: 6),
                                  Consumer<LanguageProvider>(
                                    builder: (context, language, child) {
                                      return Text(
                                        '${language.getText('Фільтр', 'Фильтр')}: ${_formatDateDisplay(_selectedDate!)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade800,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _clearDateFilter,
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.amber.shade700,
                                    ),
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
                        ? Container(
                            height: 400,
                            child: _buildEmptyState(),
                          )
                        : Column(
                            children: List.generate(
                              _filteredSessions.length,
                              (index) {
                                final session = _filteredSessions[index];
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          labelText: Provider.of<LanguageProvider>(context, listen: false).getText('Майстриня', 'Мастерица'),
          prefixIcon: Icon(Icons.person_outline),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        items: masterOptions.map((masterId) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
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
          labelText: Provider.of<LanguageProvider>(context, listen: false).getText('Статус', 'Статус'),
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
                    Icon(Icons.schedule, color: Colors.orange.shade600, size: 20),
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
                    Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 20),
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
                    Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 20),
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
    int successful = _filteredSessions.where((s) => s.status == 'успішно').length;
    int pending = _filteredSessions.where((s) => s.status == 'в очікуванні').length;
    int missed = _filteredSessions.where((s) => s.status == 'пропущено').length;
    
    return Consumer<LanguageProvider>(
      builder: (context, language, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatChip(language.getText('Всього', 'Всего'), total, Colors.blue),
            _buildStatChip(language.getText('Успішно', 'Успешно'), successful, Colors.green),
            _buildStatChip(language.getText('Очікують', 'Ожидают'), pending, Colors.orange),
            _buildStatChip(language.getText('Пропущено', 'Пропущено'), missed, Colors.red),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
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
            Icon(
              Icons.archive_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return Column(
                  children: [
                    Text(
                      language.getText('Записи не знайдені', 'Записи не найдены'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      language.getText('Спробуйте змінити фільтри', 'Попробуйте изменить фильтры'),
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
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.diamond, color: Colors.white, size: 12),
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
                          return Text(
                            '${language.getText('Час', 'Время')}: ${session.time} (${session.duration} ${language.getText('хв', 'мин')})',
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
                      if (session.notes != null && session.notes!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
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
                icon: Icon(
                  Icons.phone,
                  color: Colors.blue[600],
                  size: 28,
                ),
                tooltip: Provider.of<LanguageProvider>(context, listen: false).getText('Подзвонити', 'Позвонить'),
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
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
                tooltip: Provider.of<LanguageProvider>(context, listen: false).getText('Написати в WhatsApp', 'Написать в WhatsApp'),
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
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
              tooltip: Provider.of<LanguageProvider>(context, listen: false).getText('Редагувати запис', 'Редактировать запись'),
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
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
    );    if (result == true) {
      // Інвалідуємо кеш в глобальному провайдері
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.invalidateCache();
      
      _loadData(); // Перезавантажуємо дані після редагування
    }
  }
}
