import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/pages/sessionAdd.dart';
import 'package:nastya_app/pages/sessionEdit.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/models/models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nastya_app/widgets/update_info_widget.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/providers/language_provider.dart';

class ClientListPage extends StatefulWidget {
  final String masterName;
  final String masterId;
  final DateTime selectedDate;

  const ClientListPage({
    super.key,
    required this.masterName,
    required this.masterId,
    required this.selectedDate,
  });

  @override
  State<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends State<ClientListPage> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Session> _sessions = [];
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

  @override
  void initState() {
    super.initState();
    print('=== ПОЧАТОК ДЕБАГІНГУ ===');
    print('Майстер ID: ${widget.masterId}');
    print('Обрана дата: ${widget.selectedDate}');
    print('Ім\'я майстра: ${widget.masterName}');
    _testLoadAllSessions(); // Спочатку дивимося всі записи
    _loadSessions(); // Потім завантажуємо фільтровані
  }

  // Тестовий метод для показу всіх записів  
  Future<void> _testLoadAllSessions() async {
    try {
      print('========================');
      print('ТЕСТ: Завантажуємо ВСІ записи з бази...');
      final allSessions = await _firestoreService.getAllSessions();
      print('Загальна кількість записів у базі: ${allSessions.length}');
      
      if (allSessions.isEmpty) {
        print('❌ БАЗА ДАНИХ ПОРОЖНЯ! Немає жодного запису.');
        print('Потрібно спочатку створити запис через SessionAddPage');
      } else {
        print('✅ Знайдено записи в базі:');
        for (int i = 0; i < allSessions.length; i++) {
          final session = allSessions[i];
          print('  📝 Запис ${i+1}:');
          print('     Клієнт: ${session.clientName}');
          print('     Дата: ${session.date}');
          print('     Час: ${session.time}');
          print('     Майстер ID: ${session.masterId}');
          print('     Поточний майстер ID: ${widget.masterId}');
          print('     Співпадає: ${session.masterId == widget.masterId ? "✅ ТАК" : "❌ НІ"}');
          print('     ---');
        }
      }
      print('========================');
    } catch (e) {
      print('❌ Помилка завантаження всіх записів: $e');
    }
  }

  Future<void> _loadSessions() async {
    try {
      final dateString = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';
      print('Завантажуємо сесії для майстра ${widget.masterId} на дату $dateString');
      
      final sessions = await _firestoreService.getSessionsByMasterAndDate(
        widget.masterId,
        dateString,
      );
      
      print('Знайдено сесій: ${sessions.length}');
      for (int i = 0; i < sessions.length; i++) {
        print('Сесія $i: ${sessions[i].clientName} - ${sessions[i].time}');
      }
      
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      print('Помилка завантаження сесій: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Завантажуємо примітки клієнта з колекції clients
  Future<String?> _getClientNotes(Session session) async {
    try {
      final clientId = await _firestoreService.findClientId(session.clientName, session.phone ?? '');
      if (clientId != null) {
        final client = await _firestoreService.getClientById(clientId);
        return client?.notes;
      }
      return null;
    } catch (e) {
      print('Помилка отримання приміток клієнта: $e');
      return null;
    }
  }

  String _formatDate(DateTime date, LanguageProvider language) {
    final monthNames = [
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
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  // Відкрити WhatsApp з номером
  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 1),
          content: Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return Text(
                language.getText('Номер телефону не вказано', 'Номер телефона не указан'),
              );
            },
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Очищаємо номер від зайвих символів
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Розумне форматування номерів для різних країн
    String formattedPhone = cleanPhone;
    
    if (cleanPhone.startsWith('+')) {
      // Номер вже має міжнародний код
      formattedPhone = cleanPhone;
    } else if (cleanPhone.startsWith('0')) {
      // Визначаємо країну за довжиною та структурою номера
      if (cleanPhone.length >= 10 && cleanPhone.length <= 12) {
        // Перевіряємо чи це український номер (довжина 10 після 0)
        if (cleanPhone.length == 10) {
          formattedPhone = '+38$cleanPhone';  // Українські номери
        } else if (cleanPhone.length == 11) {
          // Може бути німецький номер (0 + 10 цифр)
          formattedPhone = '+49${cleanPhone.substring(1)}';  // Німецькі номери
        } else {
          // За замовчуванням додаємо код України
          formattedPhone = '+38$cleanPhone';
        }
      } else {
        formattedPhone = '+38$cleanPhone';  // За замовчуванням Україна
      }
    } else if (cleanPhone.startsWith('49')) {
      // Німецький код без +
      formattedPhone = '+$cleanPhone';
    } else if (cleanPhone.startsWith('38')) {
      // Український код без +
      formattedPhone = '+$cleanPhone';
    } else if (cleanPhone.length >= 10) {
      // Номер без коду країни - визначаємо за довжиною
      if (cleanPhone.length == 9 || cleanPhone.length == 10) {
        formattedPhone = '+380$cleanPhone';  // Україна без 0
      } else if (cleanPhone.length == 10 || cleanPhone.length == 11) {
        formattedPhone = '+49$cleanPhone';   // Німеччина без 0
      } else {
        formattedPhone = '+$cleanPhone';     // Додаємо + до будь-якого номера
      }
    } else {
      formattedPhone = '+$cleanPhone';
    }

    print('📞 Форматування номера: "$phone" → "$cleanPhone" → "$formattedPhone"');

    final whatsappUrl = 'https://wa.me/$formattedPhone';
    print('🔗 Спроба відкрити URL: $whatsappUrl');
    
    try {
      final uri = Uri.parse(whatsappUrl);
      print('✅ URI створено успішно: $uri');
      
      // Спробуємо запустити напряму без canLaunchUrl
      print('🚀 Спроба запуску WhatsApp...');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      print('✅ WhatsApp запущено успішно');
      
    } catch (e) {
      print('❌ Основний метод не спрацював: $e');
      print('🔄 Спробуємо альтернативний метод...');
      
      try {
        // Спробуємо через whatsapp:// протокол
        final alternativeUrl = 'whatsapp://send?phone=$formattedPhone';
        final alternativeUri = Uri.parse(alternativeUrl);
        print('🔗 Спроба альтернативного URL: $alternativeUrl');
        
        await launchUrl(alternativeUri, mode: LaunchMode.externalApplication);
        print('✅ Альтернативний метод спрацював');
        
      } catch (e2) {
        print('❌ Альтернативний метод також не спрацював: $e2');
        if (mounted) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text(language.getText('WhatsApp не встановлено або він недоступний', 'WhatsApp не установлен или недоступен')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  // Здійснити дзвінок
  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 1),
          content: Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return Text(
                language.getText('Номер телефону не вказано', 'Номер телефона не указан'),
              );
            },
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Очищаємо номер від зайвих символів
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Розумне форматування номерів для різних країн
    String formattedPhone = cleanPhone;
    
    if (cleanPhone.startsWith('+')) {
      // Номер вже має міжнародний код
      formattedPhone = cleanPhone;
    } else if (cleanPhone.startsWith('0')) {
      // Визначаємо країну за довжиною та структурою номера
      if (cleanPhone.length >= 10 && cleanPhone.length <= 12) {
        // Перевіряємо чи це український номер (довжина 10 після 0)
        if (cleanPhone.length == 10) {
          formattedPhone = '+38$cleanPhone';  // Українські номери
        } else if (cleanPhone.length == 11) {
          // Може бути німецький номер (0 + 10 цифр)
          formattedPhone = '+49${cleanPhone.substring(1)}';  // Німецькі номери
        } else {
          // За замовчуванням додаємо код України
          formattedPhone = '+38$cleanPhone';
        }
      } else {
        formattedPhone = '+38$cleanPhone';  // За замовчуванням Україна
      }
    } else if (cleanPhone.startsWith('49')) {
      // Німецький код без +
      formattedPhone = '+$cleanPhone';
    } else if (cleanPhone.startsWith('38')) {
      // Український код без +
      formattedPhone = '+$cleanPhone';
    } else if (cleanPhone.length >= 10) {
      // Номер без коду країни - визначаємо за довжиною
      if (cleanPhone.length == 9 || cleanPhone.length == 10) {
        formattedPhone = '+380$cleanPhone';  // Україна без 0
      } else if (cleanPhone.length == 10 || cleanPhone.length == 11) {
        formattedPhone = '+49$cleanPhone';   // Німеччина без 0
      } else {
        formattedPhone = '+$cleanPhone';     // Додаємо + до будь-якого номера
      }
    } else {
      formattedPhone = '+$cleanPhone';
    }

    print('📞 Форматування номера для дзвінка: "$phone" → "$cleanPhone" → "$formattedPhone"');

    final phoneUrl = 'tel:$formattedPhone';
    print('📞 Спроба здійснити дзвінок: $phoneUrl');
    
    try {
      final uri = Uri.parse(phoneUrl);
      
      if (await canLaunchUrl(uri)) {
        print('✅ Запускаємо телефонний дзвінок...');
        await launchUrl(uri);
        print('✅ Дзвінок ініційований успішно');
      } else {
        print('❌ Не вдається здійснити дзвінок');
        if (mounted) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text(language.getText('Не вдається здійснити дзвінок', 'Не удается совершить звонок')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Помилка здійснення дзвінка: $e');
      if (mounted) {
        final language = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 1),
            content: Text(language.getText('Помилка здійснення дзвінка', 'Ошибка совершения звонка')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Редагувати запис
  void _editSession(Session session) async {
    // Перехід до сторінки редагування
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionEditPage(
          session: session,
        ),
      ),
    );
    
    // Оновлюємо список якщо запис було змінено
    if (result == true) {
      // Інвалідуємо кеш в глобальному провайдері
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.invalidateCache();
      
      _loadSessions();
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
            return Column(
              children: [
                Text(
                  language.getText('Записи', 'Записи'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(widget.selectedDate, language),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Оновлюємо через централізований провайдер (примусово для оновлення часу)
            final appState = Provider.of<AppStateProvider>(context, listen: false);
            await appState.refreshAllData(forceRefresh: true);
            
            // Також оновлюємо локальні дані
            await _loadSessions();
            
            // Показуємо повідомлення
            if (mounted) {
              final language = Provider.of<LanguageProvider>(context, listen: false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(language.getText('Записи оновлено', 'Записи обновлены')),
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
                UpdateInfoWidget(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                ),
              
                // Информационная карточка
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
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
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Consumer<LanguageProvider>(
                          builder: (context, language, child) {
                            return Text(
                              '${language.getText('Записів', 'Записей')}: ${_sessions.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              
                // Контент залежно від стану
                _isLoading
                  ? Container(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : _sessions.isEmpty
                      ? Container(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                SizedBox(height: 16),
                                Consumer<LanguageProvider>(
                                  builder: (context, language, child) {
                                    return Text(
                                      language.getText('Записів на цей день немає', 'Записей на этот день нет'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 8),
                                Consumer<LanguageProvider>(
                                  builder: (context, language, child) {
                                    return Text(
                                      language.getText('Додайте новий запис кнопкою +', 'Добавьте новую запись кнопкой +'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: _sessions.map((session) {
                            return Container(
                              margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                onTap: () => _editSession(session),
                                child: Stack(
                                  children: [
                                    // Основний контент картки
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 16),
                                          // Основна інформація
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Ім'я клієнта з бейджиком постійної клієнтки
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        session.clientName,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (session.isRegularClient) ...[
                                                      SizedBox(width: 8),
                                                      Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Color(0xFFFFD700), // Золотий
                                                              Color(0xFFFFA500), // Помаранчевий
                                                            ],
                                                          ),
                                                          borderRadius: BorderRadius.circular(12),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Color(0xFFFFD700).withValues(alpha: 0.4),
                                                              blurRadius: 6,
                                                              offset: Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.diamond,
                                                              color: Colors.white,
                                                              size: 14,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'VIP',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                shadows: [
                                                                  Shadow(
                                                                    color: Colors.black.withValues(alpha: 0.3),
                                                                    offset: Offset(0, 1),
                                                                    blurRadius: 2,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                
                                                // Примітки клієнта
                                                FutureBuilder<String?>(
                                                  future: _getClientNotes(session),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                                                      return Column(
                                                        children: [
                                                          SizedBox(height: 4),
                                                          Container(
                                                            width: double.infinity,
                                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(
                                                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.person_pin_outlined,
                                                                  size: 14,
                                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                ),
                                                                SizedBox(width: 6),
                                                                Expanded(
                                                                  child: Text(
                                                                    snapshot.data!,
                                                                    style: TextStyle(
                                                                      fontSize: 12,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                      fontStyle: FontStyle.italic,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }
                                                    return SizedBox.shrink();
                                                  },
                                                ),
                                                
                                                SizedBox(height: 4),
                                                Consumer<LanguageProvider>(
                                                  builder: (context, language, child) {
                                                    return Text('${language.getText('Час', 'Время')}: ${session.time} (${session.duration} ${language.getText('хв', 'мин')})');
                                                  },
                                                ),
                                                SizedBox(height: 2),
                                                Consumer<LanguageProvider>(
                                                  builder: (context, language, child) {
                                                    return Text(
                                                      '${language.getText('Послуга', 'Услуга')}: ${_getLocalizedService(session.service, language)}',
                                                      style: TextStyle(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                if (session.price != null) ...[
                                                  SizedBox(height: 2),
                                                  Consumer<LanguageProvider>(
                                                    builder: (context, language, child) {
                                                      return Text(
                                                        '${language.getText('Ціна', 'Цена')}: ${session.price!.toStringAsFixed(2)} €',
                                                        style: TextStyle(
                                                          color: Colors.green[700],
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                                // Відображення приміток якщо вони є
                                                if (session.notes != null && session.notes!.isNotEmpty) ...[
                                                  SizedBox(height: 4),
                                                  Container(
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(
                                                          Icons.note_alt,
                                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            session.notes!,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                            maxLines: 3,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                
                                                // Статус запису з можливістю швидкої зміни
                                                SizedBox(height: 6),
                                                Consumer<LanguageProvider>(
                                                  builder: (context, language, child) {
                                                    return GestureDetector(
                                                      onTap: () => _showStatusDialog(session),
                                                      child: Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: _getStatusColor(session.status),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(
                                                            color: _getStatusBorderColor(session.status),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              _getStatusIcon(session.status),
                                                              size: 14,
                                                              color: _getStatusIconColor(session.status),
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              _getStatusText(session.status, language),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w500,
                                                                color: _getStatusTextColor(session.status),
                                                              ),
                                                            ),
                                                            SizedBox(width: 4),
                                                            Icon(
                                                              Icons.edit,
                                                              size: 12,
                                                              color: _getStatusIconColor(session.status),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 108), // Простір для кнопок справа
                                        ],
                                      ),
                                    ),
                                    
                                    // Кнопка телефону зліва зверху
                                    if (session.phone != null && session.phone!.isNotEmpty)
                                      Positioned(
                                        top: 8,
                                        right: 56, // Зліва від WhatsApp
                                        child: IconButton(
                                          onPressed: () => _makePhoneCall(session.phone),
                                          icon: Icon(
                                            Icons.phone,
                                            color: Colors.blue[600],
                                            size: 40,
                                          ),
                                          tooltip: Provider.of<LanguageProvider>(context, listen: false).getText('Подзвонити', 'Позвонить'),
                                          padding: EdgeInsets.all(4),
                                          constraints: BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                      ),
                                    
                                    // WhatsApp кнопка справа зверху
                                    if (session.phone != null && session.phone!.isNotEmpty)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          onPressed: () => _openWhatsApp(session.phone),
                                          icon: FaIcon(
                                            FontAwesomeIcons.whatsapp,
                                            color: Color(0xFF25D366), // Офіційний колір WhatsApp
                                            size: 40,
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
                                          size: 30,
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
                              ),
                            );
                          }).toList(),
                        ),
                
                // Додаємо трохи відступу знизу
                SizedBox(height: 80), // Простір для floating action button
              ],
            ),
          ),
        ),
      ),

      // Кнопка плюс СПРАВА ЗНИЗУ
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Перехід до додавання нового запису з параметрами
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionAddPage(
                masterName: widget.masterName,
                masterId: widget.masterId,
                selectedDate: widget.selectedDate,
              ),
            ),
          );
          
          // Оновлюємо список після додавання
          if (result == true) {
            // Інвалідуємо кеш в глобальному провайдері
            final appState = Provider.of<AppStateProvider>(context, listen: false);
            appState.invalidateCache();
            
            _loadSessions();
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 6,
        child: Icon(
          Icons.add,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
  
  // Допоміжні методи для статусу
  Color _getStatusColor(String status) {
    switch (status) {
      case "успішно":
        return Colors.green.shade50;
      case "пропущено":
        return Colors.red.shade50;
      case "в очікуванні":
      default:
        return Colors.orange.shade50;
    }
  }
  
  Color _getStatusBorderColor(String status) {
    switch (status) {
      case "успішно":
        return Colors.green.shade200;
      case "пропущено":
        return Colors.red.shade200;
      case "в очікуванні":
      default:
        return Colors.orange.shade200;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case "успішно":
        return Icons.check_circle_outline;
      case "пропущено":
        return Icons.cancel_outlined;
      case "в очікуванні":
      default:
        return Icons.schedule;
    }
  }
  
  Color _getStatusIconColor(String status) {
    switch (status) {
      case "успішно":
        return Colors.green.shade600;
      case "пропущено":
        return Colors.red.shade600;
      case "в очікуванні":
      default:
        return Colors.orange.shade600;
    }
  }
  
  String _getStatusText(String status, LanguageProvider language) {
    switch (status) {
      case "успішно":
        return language.getText("Успішно", "Успешно");
      case "пропущено":
        return language.getText("Пропущено", "Пропущено");
      case "в очікуванні":
      default:
        return language.getText("В очікуванні", "В ожидании");
    }
  }
  
  Color _getStatusTextColor(String status) {
    switch (status) {
      case "успішно":
        return Colors.green.shade700;
      case "пропущено":  
        return Colors.red.shade700;
      case "в очікуванні":
      default:
        return Colors.orange.shade700;
    }
  }
  
  // Діалог зміни статусу
  void _showStatusDialog(Session session) {
    showDialog(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, language, child) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text(
                  language.getText('Змінити статус запису', 'Изменить статус записи'),
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${language.getText('Клієнт', 'Клиент')}: ${session.clientName}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text('${language.getText('Час', 'Время')}: ${session.time}'),
                  Text('${language.getText('Послуга', 'Услуга')}: ${_getLocalizedService(session.service, language)}'),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              language.getText('Виберіть новий статус:', 'Выберите новый статус:'),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            
            // Кнопки статусів з кольорами та іконками
            Column(
              children: [
                // В очікуванні
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 8),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.schedule, size: 20),
                    label: Text(language.getText('В очікуванні', 'В ожидании')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade50,
                      foregroundColor: Colors.orange.shade700,
                      elevation: 2,
                      side: BorderSide(color: Colors.orange.shade200),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _updateSessionStatus(session, "в очікуванні"),
                  ),
                ),
                
                // Успішно
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 8),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.check_circle_outline, size: 20),
                    label: Text(language.getText('Успішно', 'Успешно')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade700,
                      elevation: 2,
                      side: BorderSide(color: Colors.green.shade200),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _updateSessionStatus(session, "успішно"),
                  ),
                ),
                
                // Пропущено
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.cancel_outlined, size: 20),
                    label: Text(language.getText('Пропущено', 'Пропущено')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      elevation: 2,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _updateSessionStatus(session, "пропущено"),
                  ),
                ),
                
                // Скасувати
                Container(
                  width: double.infinity,
                  child: TextButton(
                    child: Text(
                      language.getText('Скасувати', 'Отменить'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
            contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
            actionsPadding: EdgeInsets.zero,
            actions: [], // Прибираємо старі actions
          );
        },
      ),
    );
  }
  
  // Оновлення статусу сесії
  Future<void> _updateSessionStatus(Session session, String newStatus) async {
    Navigator.pop(context); // Закриваємо діалог
    
    try {
      final updatedSession = Session(
        id: session.id,
        masterId: session.masterId,
        clientId: session.clientId,
        clientName: session.clientName,
        phone: session.phone,
        service: session.service,
        duration: session.duration,
        date: session.date,
        time: session.time,
        notes: session.notes,
        price: session.price,
        isRegularClient: session.isRegularClient,
        status: newStatus,
      );
      
      await _firestoreService.updateSession(session.id!, updatedSession);
      
      // Оновлюємо UI
      setState(() {
        _loadSessions();
      });
      
      final language = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language.getText('Статус запису оновлено', 'Статус записи обновлен')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final language = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${language.getText('Помилка оновлення статусу', 'Ошибка обновления статуса')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}