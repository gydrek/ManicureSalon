import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/models/models.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/services/notification_service.dart';
import 'package:provider/provider.dart';

// Клас для валідації телефонних номерів
class PhoneValidator {
  static const Map<String, Map<String, dynamic>> countryCodes = {
    '+380': {
      'name': 'Україна',
      'nameRu': 'Украина',
      'minLength': 9,
      'maxLength': 9,
      'pattern': r'^[0-9]{9}$',
    },
    '+49': {
      'name': 'Німеччина',
      'nameRu': 'Германия',
      'minLength': 10,
      'maxLength': 11,
      'pattern': r'^[0-9]{10,11}$',
    },
  };

  static String? validatePhone(String countryCode, String phoneNumber, LanguageProvider language) {
    final config = countryCodes[countryCode];
    if (config == null) return language.getText('Невідомий код країни', 'Неизвестный код страны');
    
    if (phoneNumber.isEmpty) {
      return language.getText('Номер телефону обов\'язковий', 'Номер телефона обязательный');
    }
    
    final RegExp pattern = RegExp(config['pattern']);
    if (!pattern.hasMatch(phoneNumber)) {
      final countryName = language.currentLocale.languageCode == 'ru' 
          ? config['nameRu'] 
          : config['name'];
      return language.getText(
        'Невірний формат для $countryName (потрібно ${config['minLength']}-${config['maxLength']} цифр)',
        'Неверный формат для $countryName (нужно ${config['minLength']}-${config['maxLength']} цифр)'
      );
    }
    
    return null;
  }
}

class SessionAddPage extends StatefulWidget {
  final String masterName;
  final String masterId;
  final DateTime selectedDate;

  const SessionAddPage({
    super.key,
    required this.masterName,
    required this.masterId,
    required this.selectedDate,
  });

  @override
  State<SessionAddPage> createState() => _SessionAddPageState();
}

class _SessionAddPageState extends State<SessionAddPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _clientNotesController = TextEditingController(); // Примітки клієнта
  final _notesController = TextEditingController(); // Примітки сесії
  final _priceController = TextEditingController();
  
  String _selectedService = 'Манікюр';
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _duration = 60; // хвилини
  bool _isLoading = false;
  bool _isRegularClient = false; // Додаємо стан для галочки "Постійна клієнтка"
  String _selectedStatus = "в очікуванні"; // Статус запису
  String _selectedCountryCode = '+49'; // За замовчуванням німецький номер
  
  // Список унікальних клієнток для автозаповнення
  List<Map<String, dynamic>> _availableClients = [];

  // Функція для генерації підказки про кількість цифр
  String _getDigitsHint(String currentText, String countryCode, LanguageProvider language) {
    final config = PhoneValidator.countryCodes[countryCode];
    if (config == null) return '';
    
    final currentLength = currentText.length;
    final minLength = config['minLength'];
    final maxLength = config['maxLength'];
    
    if (currentLength == 0) return '';
    
    if (currentLength < minLength) {
      final remaining = minLength - currentLength;
      if (minLength == maxLength) {
        return language.getText(
          'Введіть ще $remaining ${remaining == 1 ? 'цифру' : 'цифри'}',
          'Введите еще $remaining ${remaining == 1 ? 'цифру' : remaining < 5 ? 'цифры' : 'цифр'}'
        );
      } else {
        final maxRemaining = maxLength - currentLength;
        return language.getText(
          'Введіть ще $remaining-$maxRemaining ${remaining == 1 ? 'цифру' : 'цифри'}',
          'Введите еще $remaining-$maxRemaining ${remaining == 1 ? 'цифру' : remaining < 5 ? 'цифры' : 'цифр'}'
        );
      }
    } else if (currentLength > maxLength) {
      final excess = currentLength - maxLength;
      return language.getText(
        'Забагато цифр! Видаліть $excess ${excess == 1 ? 'цифру' : 'цифри'}',
        'Слишком много цифр! Удалите $excess ${excess == 1 ? 'цифру' : excess < 5 ? 'цифры' : 'цифр'}'
      );
    }
    
    return language.getText('✓ Номер введено правильно', '✓ Номер введен правильно');
  }

  final List<String> _services = [
    'Манікюр',
    'Педикюр', 
    'Наращування нігтів',
    'Дизайн нігтів',
    'Покриття гель-лак',
    'Зняття покриття',
    'Корекція',
  ];

  // Метод для отримання локалізованої назви послуги
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

  final List<int> _durations = [30, 45, 60, 90, 120, 150, 180]; // хвилини

  @override
  void initState() {
    super.initState();
    _loadAvailableClients();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _phoneController.dispose();
    _clientNotesController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Завантажуємо список доступних клієнток для автозаповнення
  Future<void> _loadAvailableClients() async {
    try {
      final clients = await _firestoreService.getUniqueClientsWithVipStatus();
      setState(() {
        _availableClients = clients;
      });
    } catch (e) {
      print('Помилка завантаження клієнток: $e');
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteTextColor: Theme.of(context).colorScheme.onSurface,
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveSession() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Формуємо повний номер телефону з вибраним кодом країни
        final fullPhoneNumber = '$_selectedCountryCode ${_phoneController.text.trim()}';
        
        // Отримуємо або створюємо клієнта
        final clientId = await _firestoreService.getOrCreateClient(
          _clientNameController.text.trim(),
          fullPhoneNumber,
        );

        if (clientId == null) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
          throw Exception(language.getText('Не вдалося створити клієнта', 'Не удалось создать клиентку'));
        }

        // Оновлюємо примітки клієнта якщо вони є
        if (_clientNotesController.text.trim().isNotEmpty) {
          final clientData = Client(
            id: clientId,
            name: _clientNameController.text.trim(),
            phone: fullPhoneNumber,
            isRegularClient: _isRegularClient,
            notes: _clientNotesController.text.trim(),
          );
          await _firestoreService.updateClient(clientId, clientData);
          print('Оновлено примітки клієнта: ${_clientNotesController.text.trim()}');
        }

        // Формуємо дату в форматі YYYY-MM-DD
        final dateString = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';
        
        print('Створюємо сесію: masterId=${widget.masterId}, clientId=$clientId, date=$dateString');
        
        // Створюємо сесію
        final session = Session(
          masterId: widget.masterId,
          clientId: clientId,
          clientName: _clientNameController.text.trim(),
          phone: fullPhoneNumber,
          service: _selectedService,
          duration: _duration,
          date: dateString,
          time: _formatTime(_selectedTime),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          price: _priceController.text.trim().isEmpty ? null : double.tryParse(_priceController.text.trim()),
          isRegularClient: _isRegularClient,
          status: _selectedStatus,
        );

        print('Дані сесії: ${session.toFirestore()}');
        
        // Зберігаємо в базу даних
        final sessionId = await _firestoreService.addSession(session);
        print('Сесія збережена з ID: $sessionId');

        // Плануємо сповіщення за 30 хвилин до сесії
        try {
          // Знаходимо ім'я майстра
          final appState = Provider.of<AppStateProvider>(context, listen: false);
          final master = appState.masters.firstWhere((m) => m.id == session.masterId);
          
          // Перетворюємо дату та час в DateTime
          final sessionDateTime = DateTime.parse('${session.date} ${session.time}:00');
          
          await NotificationService().scheduleSessionReminder(
            sessionId: sessionId ?? '',
            clientName: session.clientName,
            masterName: master.name,
            sessionDateTime: sessionDateTime,
            masterId: session.masterId,
          );
        } catch (e) {
          print('Помилка планування сповіщення: $e');
        }

        if (mounted) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      language.getText('Запис успішно збережено!', 'Запись успешно сохранена!'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              duration: Duration(seconds: 1),
              elevation: 6,
            ),
          );
          
          // Повертаємось до списку записів з результатом
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${language.getText('Помилка збереження', 'Ошибка сохранения')}: $e',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              duration: Duration(seconds: 1),
              elevation: 6,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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
              language.getText('Новий запис', 'Новая запись'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Інформаційна картка
                  Container(
                    width: double.infinity,
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
                    child: Column(
                      children: [
                        Row(
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
                              child: Consumer2<LanguageProvider, AppStateProvider>(
                                builder: (context, language, appState, child) {
                                  final master = appState.masters.firstWhere(
                                    (m) => m.id == widget.masterId,
                                    orElse: () => appState.masters.first,
                                  );
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${language.getText('Майстриня', 'Мастерица')}: ${master.getLocalizedName(language.currentLocale.languageCode)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${language.getText('Дата', 'Дата')}: ${_formatDate(widget.selectedDate, language)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Форма додавання запису
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return Text(
                        language.getText('Інформація про клієнта', 'Информация о клиентке'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Ім'я клієнта з автозаповненням
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      // Показуємо всіх клієнтів при порожньому полі або фільтруємо за введеним текстом
                      List<Map<String, dynamic>> filteredClients;
                      
                      if (textEditingValue.text.isEmpty) {
                        // Показуємо всіх клієнтів при фокусі на полі
                        filteredClients = _availableClients.toList();
                      } else {
                        // Фільтруємо клієнтів за введеним текстом
                        filteredClients = _availableClients
                            .where((client) => (client['name'] as String)
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()))
                            .toList();
                      }
                      
                      // Сортуємо: VIP клієнти спочатку, потім звичайні
                      filteredClients.sort((a, b) {
                        final aIsVip = a['isRegularClient'] as bool;
                        final bIsVip = b['isRegularClient'] as bool;
                        
                        if (aIsVip && !bIsVip) return -1;
                        if (!aIsVip && bIsVip) return 1;
                        return (a['name'] as String).compareTo(b['name'] as String);
                      });
                      
                      return filteredClients;
                    },
                    displayStringForOption: (client) => client['name'] as String,
                    onSelected: (client) {
                      _clientNameController.text = client['name'] as String;
                      
                      // Заповнюємо телефон та визначаємо код країни
                      if ((client['phone'] as String).isNotEmpty) {
                        String phone = client['phone'] as String;
                        // Визначаємо код країни та прибираємо його з номера
                        for (String code in PhoneValidator.countryCodes.keys) {
                          if (phone.startsWith('$code ')) {
                            _selectedCountryCode = code;
                            phone = phone.substring(code.length + 1);
                            break;
                          }
                        }
                        _phoneController.text = phone;
                      }
                      
                      // Заповнюємо примітки клієнта
                      _clientNotesController.text = (client['notes'] as String?) ?? '';
                      
                      // Автоматично встановлюємо VIP статус
                      setState(() {
                        _isRegularClient = client['isRegularClient'] as bool;
                      });
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: BoxConstraints(maxHeight: 200),
                            width: MediaQuery.of(context).size.width - 32,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final client = options.elementAt(index);
                                final isVip = client['isRegularClient'] as bool;
                                
                                return ListTile(
                                  leading: Icon(
                                    Icons.person_outline,
                                    color: isVip ? Colors.amber : null,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          client['name'] as String,
                                          style: TextStyle(
                                            fontWeight: isVip ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (isVip) ...[
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
                                  subtitle: (client['phone'] as String).isNotEmpty
                                      ? Text(client['phone'] as String)
                                      : null,
                                  onTap: () => onSelected(client),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      // Синхронізуємо початкове значення
                      if (controller.text != _clientNameController.text) {
                        controller.text = _clientNameController.text;
                      }
                      
                      _clientNameController.addListener(() {
                        if (_clientNameController.text != controller.text) {
                          controller.text = _clientNameController.text;
                        }
                      });
                      
                      return Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            decoration: InputDecoration(
                              labelText: language.getText("Ім'я клієнта", "Имя клиентки"),
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return language.getText("Введіть ім'я клієнта", "Введите имя клиентки");
                              }
                              return null;
                            },
                            onChanged: (value) {
                              _clientNameController.text = value;
                            },
                          );
                        },
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Телефон з вибором коду країни
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: language.getText('Телефон*', 'Телефон*'),
                          prefixIcon: Icon(Icons.phone_outlined),
                          // Випадаючий список з кодом країни як префікс
                          prefix: Container(
                            padding: EdgeInsets.only(right: 8),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                isDense: true,
                                items: PhoneValidator.countryCodes.entries.map((entry) {
                                  final code = entry.key;
                                  return DropdownMenuItem<String>(
                                    value: code,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        code,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedCountryCode = newValue;
                                      // НЕ очищуємо поле - залишаємо введені цифри
                                    });
                                  }
                                },
                                selectedItemBuilder: (BuildContext context) {
                                  return PhoneValidator.countryCodes.keys.map<Widget>((String code) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        code,
                                        style: TextStyle(
                                           fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                          hintText: _selectedCountryCode == '+380' 
                              ? '67 123 4567' 
                              : '176 12345678',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            _selectedCountryCode == '+380' ? 9 : 11
                          ),
                        ],
                        onChanged: (value) {
                          // Оновлюємо інтерфейс для показу підказки
                          setState(() {});
                        },
                        validator: (value) {
                          return PhoneValidator.validatePhone(
                            _selectedCountryCode, 
                            value ?? '', 
                            language
                          );
                        },
                      );
                    },
                  ),
                  
                  // Підказка про кількість цифр
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      final hint = _getDigitsHint(_phoneController.text, _selectedCountryCode, language);
                      if (hint.isEmpty) return SizedBox.shrink();
                      
                      final isSuccess = hint.contains('✓');
                      final isError = hint.contains('Забагато') || hint.contains('Слишком');
                      
                      return Padding(
                        padding: EdgeInsets.only(left: 12, top: 4),
                        child: Row(
                          children: [
                            Icon(
                              isSuccess ? Icons.check_circle : 
                              isError ? Icons.error : Icons.info,
                              size: 14,
                              color: isSuccess ? Colors.green : 
                                     isError ? Colors.red : Colors.orange,
                            ),
                            SizedBox(width: 4),
                            Text(
                              hint,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSuccess ? Colors.green : 
                                       isError ? Colors.red : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Примітки клієнтки
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return TextFormField(
                        controller: _clientNotesController,
                        decoration: InputDecoration(
                          labelText: language.getText('Примітки про клієнта', 'Примечания о клиентке'),
                          prefixIcon: Icon(Icons.person_pin_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          helperText: language.getText('Додаткова інформація про клієнтку', 'Дополнительная информация о клиентке'),
                        ),
                        maxLines: 2,
                      );
                    },
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Галочка "Постійна клієнтка"
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isRegularClient,
                          onChanged: (bool? value) {
                            setState(() {
                              _isRegularClient = value ?? false;
                            });
                          },
                          activeColor: Colors.amber,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Consumer<LanguageProvider>(
                                builder: (context, language, child) {
                                  return Row(
                                    children: [
                                      Text(
                                        language.getText('Постійна клієнтка', 'Постоянная клиентка'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      if (_isRegularClient) ...[
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
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Деталі запису
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return Text(
                        language.getText('Деталі запису', 'Детали записи'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Вибір послуги
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return DropdownButtonFormField<String>(
                        value: _selectedService,
                        decoration: InputDecoration(
                          labelText: language.getText('Послуга', 'Услуга'),
                          prefixIcon: Icon(Icons.design_services_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        items: _services.map((String service) {
                          return DropdownMenuItem<String>(
                            value: service,
                            child: Text(_getLocalizedService(service, language)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedService = newValue!;
                          });
                        },
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Час і тривалість
                  Row(
                    children: [
                      // Час
                      Expanded(
                        child: InkWell(
                          onTap: _selectTime,
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Consumer<LanguageProvider>(
                                      builder: (context, language, child) {
                                        return Text(
                                          language.getText('Час', 'Время'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                      _formatTime(_selectedTime),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Тривалість
                      Expanded(
                        child: Consumer<LanguageProvider>(
                          builder: (context, language, child) {
                            return DropdownButtonFormField<int>(
                              value: _duration,
                              decoration: InputDecoration(
                                labelText: language.getText('Тривалість', 'Длительность'),
                                prefixIcon: Icon(Icons.timer_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                              ),
                              items: _durations.map((int duration) {
                                return DropdownMenuItem<int>(
                                  value: duration,
                                  child: Text('$duration ${language.getText('хв', 'мин')}'),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                setState(() {
                                  _duration = newValue!;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Ціна
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: language.getText('Ціна (€)', 'Цена (€)'),
                          prefixIcon: Icon(Icons.euro_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          suffixText: '€',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return language.getText('Введіть ціну послуги', 'Введите цену услуги');
                          }
                          final price = double.tryParse(value);
                          if (price == null) {
                            return language.getText('Введіть коректну ціну', 'Введите корректную цену');
                          }
                          if (price < 0) {
                            return language.getText('Ціна не може бути від\'ємною', 'Цена не может быть отрицательной');
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Примітки
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: language.getText('Примітки (необов\'язково)', 'Примечания (необязательно)'),
                          prefixIcon: Icon(Icons.note_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        maxLines: 3,
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Статус запису
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: language.getText('Статус запису', 'Статус записи'),
                            prefixIcon: Icon(Icons.assignment_outlined),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: "в очікуванні",
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(Icons.schedule, color: Colors.orange, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    language.getText("В очікуванні", "В ожидании"),
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: "успішно",
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    language.getText("Успішно", "Успешно"),
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: "пропущено",
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    language.getText("Пропущено", "Пропущено"),
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Кнопки дій
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                language.getText('Скасувати', 'Отменить'),
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          
                          SizedBox(width: 16),
                          
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      language.getText('Зберегти', 'Сохранить'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
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