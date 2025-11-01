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

  static String? validatePhone(
    String countryCode,
    String phoneNumber,
    LanguageProvider language,
  ) {
    final config = countryCodes[countryCode];
    if (config == null)
      return language.getText('Невідомий код країни', 'Неизвестный код страны');

    if (phoneNumber.isEmpty) {
      return language.getText(
        'Номер телефону обов\'язковий',
        'Номер телефона обязательный',
      );
    }

    final RegExp pattern = RegExp(config['pattern']);
    if (!pattern.hasMatch(phoneNumber)) {
      final countryName = language.currentLocale.languageCode == 'ru'
          ? config['nameRu']
          : config['name'];
      return language.getText(
        'Невірний формат для $countryName (потрібно ${config['minLength']}-${config['maxLength']} цифр)',
        'Неверный формат для $countryName (нужно ${config['minLength']}-${config['maxLength']} цифр)',
      );
    }

    return null;
  }
}

class SessionEditPage extends StatefulWidget {
  final Session session;

  const SessionEditPage({super.key, required this.session});

  @override
  State<SessionEditPage> createState() => _SessionEditPageState();
}

class _SessionEditPageState extends State<SessionEditPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _clientNotesController = TextEditingController(); // Примітки клієнта
  final _notesController = TextEditingController(); // Примітки сесії
  final _priceController = TextEditingController();

  String _selectedService = 'Манікюр класичний';
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _duration = 60; // хвилини
  bool _isLoading = false;
  bool _isRegularClient = false; // Додаємо стан для галочки "Постійна клієнтка"
  String _selectedStatus = "в очікуванні"; // Статус запису
  String _selectedCountryCode = '+49'; // За замовчуванням німецький номер

  // Функція для генерації підказки про кількість цифр
  String _getDigitsHint(
    String currentText,
    String countryCode,
    LanguageProvider language,
  ) {
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
          'Введите еще $remaining ${remaining == 1
              ? 'цифру'
              : remaining < 5
              ? 'цифры'
              : 'цифр'}',
        );
      } else {
        final maxRemaining = maxLength - currentLength;
        return language.getText(
          'Введіть ще $remaining-$maxRemaining ${remaining == 1 ? 'цифру' : 'цифри'}',
          'Введите еще $remaining-$maxRemaining ${remaining == 1
              ? 'цифру'
              : remaining < 5
              ? 'цифры'
              : 'цифр'}',
        );
      }
    } else if (currentLength > maxLength) {
      final excess = currentLength - maxLength;
      return language.getText(
        'Забагато цифр! Видаліть $excess ${excess == 1 ? 'цифру' : 'цифри'}',
        'Слишком много цифр! Удалите $excess ${excess == 1
            ? 'цифру'
            : excess < 5
            ? 'цифры'
            : 'цифр'}',
      );
    }

    return language.getText(
      '✓ Номер введено правильно',
      '✓ Номер введен правильно',
    );
  }

  // Для автозаповнення клієнтів
  List<Map<String, dynamic>> _availableClients = [];

  // Майстри
  List<Master> _masters = [];
  String _selectedMasterId = '';

  // Метод для отримання локалізованих послуг
  List<String> _getLocalizedServices(LanguageProvider language) {
    return [
      language.getText('Манікюр класичний', 'Маникюр классический'),
      language.getText('Покриття гель-лак (руки)', 'Покрытие гель-лак (руки)'),
      language.getText('Манікюр', 'Маникюр'),
      language.getText('Наращування нігтів (стандарт)', 'Наращивание ногтей (стандарт)'),
      language.getText('Наращування нігтів (довге)', 'Наращивание ногтей (длинное)'),
      language.getText('Манікюр чоловічій', 'Маникюр мужской'),
      language.getText('Педикюр класичний', 'Педикюр классический'),
      language.getText('Педикюр класичний + покриття гель-лак', 'Педикюр классический + покрытие гель-лак'),
      language.getText('Покриття гель-лак (ноги)', 'Покрытие гель-лак (ноги)'),
      language.getText('Наращування вій', 'Наращивание ресниц'),
      language.getText('Наращування нижніх вій', 'Наращивание нижних ресниц'),
    ];
  }

  // Метод для отримання оригінальних послуг (для збереження в БД)
  final List<String> _originalServices = [
    'Манікюр класичний',
    'Покриття гель-лак (руки)',
    'Манікюр',
    'Наращування нігтів (стандарт)',
    'Наращування нігтів (довге)',
    'Манікюр чоловічій',
    'Педикюр класичний',
    'Педикюр класичний + покриття гель-лак',
    'Покриття гель-лак (ноги)',
    'Наращування вій',
    'Наращування нижніх вій',
  ];

  final List<int> _durations = [30, 60, 90, 120, 150, 180]; // хвилини

  // Метод для отримання опису тривалості
  String _getDurationDescription(int duration, LanguageProvider language) {
    switch (duration) {
      case 30:
        return language.getText('(0,5 години)', '(0,5 часа)');
      case 60:
        return language.getText('(1 година)', '(1 час)');
      case 90:
        return language.getText('(1,5 години)', '(1,5 часа)');
      case 120:
        return language.getText('(2 години)', '(2 часа)');
      case 150:
        return language.getText('(2,5 години)', '(2,5 часа)');
      case 180:
        return language.getText('(3 години)', '(3 часа)');
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    // Заповнюємо поля даними з існуючого запису
    _clientNameController.text = widget.session.clientName;

    // Визначаємо код країни та номер телефону
    String phoneValue = widget.session.phone ?? '';
    for (String code in PhoneValidator.countryCodes.keys) {
      if (phoneValue.startsWith('$code ')) {
        _selectedCountryCode = code;
        phoneValue = phoneValue.substring(
          code.length + 1,
        ); // Прибираємо код та пробіл
        break;
      }
    }
    _phoneController.text = phoneValue;

    _notesController.text = widget.session.notes ?? '';
    _priceController.text = widget.session.price?.toString() ?? '';
    _selectedService = widget.session.service;
    _duration = widget.session.duration;
    _selectedMasterId = widget.session.masterId;
    _isRegularClient = widget.session.isRegularClient;
    _selectedStatus = widget.session.status;

    // Завантажуємо примітки клієнта
    _loadClientNotes();

    // Парсимо час з рядка
    final timeParts = widget.session.time.split(':');
    _selectedTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    // Завантажуємо майстрів та клієнтів
    _loadMasters();
    _loadAvailableClients();
  }

  // Завантажуємо список доступних клієнтів для автозаповнення
  Future<void> _loadAvailableClients() async {
    try {
      final clients = await _firestoreService.getUniqueClientsWithVipStatus();
      _availableClients = clients;
    } catch (e) {
      print('Помилка завантаження клієнтів: $e');
    }
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

  // Завантажуємо примітки клієнта з колекції clients
  Future<void> _loadClientNotes() async {
    try {
      final clientId = await _firestoreService.findClientId(
        widget.session.clientName,
        widget.session.phone ?? '',
      );
      if (clientId != null) {
        final client = await _firestoreService.getClientById(clientId);
        if (client != null && client.notes != null) {
          setState(() {
            _clientNotesController.text = client.notes!;
          });
        }
      }
    } catch (e) {
      print('Помилка завантаження приміток клієнта: $e');
    }
  }

  // Завантажуємо список майстрів
  Future<void> _loadMasters() async {
    try {
      final masters = await _firestoreService.getMasters();
      setState(() {
        _masters = masters;
      });
    } catch (e) {
      print('Помилка завантаження майстрів: $e');
    }
  }

  String _formatDate(String dateString, LanguageProvider language) {
    final date = DateTime.parse(dateString);
    final ukrainianMonths = [
      'січня',
      'лютого',
      'березня',
      'квітня',
      'травня',
      'червня',
      'липня',
      'серпня',
      'вересня',
      'жовтня',
      'листопада',
      'грудня',
    ];
    final russianMonths = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    final months = language.getText(
      ukrainianMonths[date.month - 1],
      russianMonths[date.month - 1],
    );

    return '${date.day} $months ${date.year}';
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
              dialBackgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer,
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

  // Показати діалог вибору майстра
  Future<void> _showMasterSelection() async {
    if (_masters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return Text(
                language.getText(
                  'Завантаження майстринь...',
                  'Загрузка мастериц...',
                ),
              );
            },
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final Master? selectedMaster = await showDialog<Master>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return Text(
                language.getText('Оберіть майстриню', 'Выберите мастерицу'),
              );
            },
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _masters.length,
              itemBuilder: (context, index) {
                final master = _masters[index];
                final isSelected = master.id == _selectedMasterId;

                return Consumer<LanguageProvider>(
                  builder: (context, language, child) {
                    final localizedName = master.getLocalizedName(
                      language.currentLocale.languageCode,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondary,
                        child: Text(
                          localizedName.substring(0, 1).toUpperCase(),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        localizedName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop(master);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Consumer<LanguageProvider>(
                builder: (context, language, child) {
                  return Text(language.getText('Скасувати', 'Отменить'));
                },
              ),
            ),
          ],
        );
      },
    );

    if (selectedMaster != null) {
      setState(() {
        _selectedMasterId = selectedMaster.id!;
      });
    }
  }

  Future<void> _updateSession() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Формуємо повний номер телефону з префіксом
        final fullPhoneNumber =
            '$_selectedCountryCode ${_phoneController.text.trim()}';

        // Отримуємо або створюємо клієнта

        // Оновлюємо або створюємо клієнта
        final clientId = await _firestoreService.getOrCreateClient(
          _clientNameController.text.trim(),
          fullPhoneNumber,
        );

        if (clientId == null) {
          final language = Provider.of<LanguageProvider>(
            context,
            listen: false,
          );
          throw Exception(
            language.getText(
              'Не вдалося оновити дані клієнтки',
              'Не удалось обновить данные клиентки',
            ),
          );
        }

        print('Оновлюємо сесію: sessionId=${widget.session.id}');

        // Створюємо оновлену сесію
        final updatedSession = Session(
          id: widget.session.id,
          masterId: _selectedMasterId, // Використовуємо вибраного майстра
          clientId: clientId,
          clientName: _clientNameController.text.trim(),
          phone: fullPhoneNumber,
          service: _selectedService,
          duration: _duration,
          date: widget.session.date,
          time: _formatTime(_selectedTime),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          price: _priceController.text.trim().isEmpty
              ? null
              : double.tryParse(_priceController.text.trim()),
          isRegularClient: _isRegularClient,
          status: _selectedStatus, // Використовуємо вибраний статус
        );

        print('Оновлені дані сесії: ${updatedSession.toFirestore()}');

        // Оновлюємо в базі даних
        await _firestoreService.updateSession(
          widget.session.id!,
          updatedSession,
        );
        print('Сесія оновлена успішно');

        // Спочатку скасовуємо старе сповіщення
        try {
          await NotificationService().cancelSessionReminder(widget.session.id!);
        } catch (e) {
          print('Помилка скасування старого сповіщення: $e');
        }

        // Плануємо нове сповіщення за 30 хвилин до оновленої сесії
        try {
          // Знаходимо ім'я майстра
          final appState = Provider.of<AppStateProvider>(
            context,
            listen: false,
          );
          final master = appState.masters.firstWhere(
            (m) => m.id == updatedSession.masterId,
          );

          // Перетворюємо дату та час в DateTime
          final sessionDateTime = DateTime.parse(
            '${updatedSession.date} ${updatedSession.time}:00',
          );

          await NotificationService().scheduleSessionReminder(
            sessionId: widget.session.id!,
            clientName: updatedSession.clientName,
            masterName: master.name,
            sessionDateTime: sessionDateTime,
            masterId: updatedSession.masterId,
          );
        } catch (e) {
          print('Помилка планування нового сповіщення: $e');
        }

        // Оновлюємо примітки клієнта
        try {
          final existingClientId = await _firestoreService.findClientId(
            _clientNameController.text.trim(),
            fullPhoneNumber,
          );
          if (existingClientId != null) {
            // Отримуємо існуючі дані клієнта
            final existingClient = await _firestoreService.getClientById(
              existingClientId,
            );
            if (existingClient != null) {
              // Створюємо оновленого клієнта з новими примітками
              final updatedClient = Client(
                id: existingClient.id,
                name: existingClient.name,
                phone: existingClient.phone,
                isRegularClient: _isRegularClient,
                notes: _clientNotesController.text.trim().isNotEmpty
                    ? _clientNotesController.text.trim()
                    : null,
              );
              await _firestoreService.updateClient(
                existingClientId,
                updatedClient,
              );
            }
          }
        } catch (e) {
          print('Помилка оновлення приміток клієнта: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          language.getText(
                            'Запис успішно оновлено!',
                            'Запись успешно обновлена!',
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              duration: Duration(seconds: 2),
              elevation: 6,
            ),
          );

          // Повертаємось до списку записів з результатом
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Помилка оновлення: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          language.getText(
                            'Помилка оновлення: $e',
                            'Ошибка обновления: $e',
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              duration: Duration(seconds: 3),
              elevation: 6,
              behavior: SnackBarBehavior.floating,
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

  Future<void> _deleteSession() async {
    // Показуємо діалог підтвердження
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return AlertDialog(
              title: Text(
                language.getText('Видалити запис?', 'Удалить запись?'),
              ),
              content: Text(
                language.getText(
                  'Ви впевнені, що хочете видалити цей запис? Цю дію неможливо скасувати.',
                  'Вы уверены, что хотите удалить эту запись? Это действие нельзя отменить.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(language.getText('Скасувати', 'Отменить')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(language.getText('Видалити', 'Удалить')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Скасовуємо сповіщення перед видаленням сесії
        try {
          await NotificationService().cancelSessionReminder(widget.session.id!);
        } catch (e) {
          print('Помилка скасування сповіщення: $e');
        }

        await _firestoreService.deleteSession(widget.session.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.delete, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          language.getText('Запис видалено', 'Запись удалена'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange[600],
              duration: Duration(seconds: 2),
              elevation: 6,
            ),
          );

          // Повертаємось до списку записів з результатом
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Consumer<LanguageProvider>(
                builder: (context, language, child) {
                  return Text(
                    language.getText(
                      'Помилка видалення: $e',
                      'Ошибка удаления: $e',
                    ),
                  );
                },
              ),
              backgroundColor: Colors.red[600],
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
                language.getText(
                  'Редагування запису',
                  'Редактирование \nзаписи',
                ),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              );
            },
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            // Кнопка видалення
            Consumer<LanguageProvider>(
              builder: (context, language, child) {
                return IconButton(
                  onPressed: _isLoading ? null : _deleteSession,
                  icon: Icon(Icons.delete_outline),
                  tooltip: language.getText('Видалити запис', 'Удалить запись'),
                  color: Colors.red,
                  iconSize: 40,
                );
              },
            ),
          ],
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
                            Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: 0.7),
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
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Consumer<LanguageProvider>(
                                  builder: (context, language, child) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Consumer<AppStateProvider>(
                                                builder: (context, appState, child) {
                                                  final master = appState
                                                      .masters
                                                      .firstWhere(
                                                        (m) =>
                                                            m.id ==
                                                            _selectedMasterId,
                                                        orElse: () =>
                                                            appState
                                                                .masters
                                                                .isNotEmpty
                                                            ? appState
                                                                  .masters
                                                                  .first
                                                            : Master(
                                                                name:
                                                                    'Невідомо',
                                                                status:
                                                                    'active',
                                                              ),
                                                      );
                                                  final localizedName = master
                                                      .getLocalizedName(
                                                        language
                                                            .currentLocale
                                                            .languageCode,
                                                      );
                                                  return Text(
                                                    language.getText(
                                                      'Майстриня: $localizedName',
                                                      'Мастерица: $localizedName',
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onPrimaryContainer,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            // Кнопка зміни майстра
                                            IconButton(
                                              onPressed: _showMasterSelection,
                                              icon: Icon(
                                                Icons.swap_horiz,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                              tooltip: language.getText(
                                                'Змінити майстриню',
                                                'Изменить мастерицу',
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${language.getText('Дата:', 'Дата:')} ${_formatDate(widget.session.date, language)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withValues(alpha: 0.7),
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

                    // Форма редагування запису
                    Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          language.getText(
                            'Інформація про клієнтку',
                            'Информация о клиентке',
                          ),
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
                              .where(
                                (client) => (client['name'] as String)
                                    .toLowerCase()
                                    .contains(
                                      textEditingValue.text.toLowerCase(),
                                    ),
                              )
                              .toList();
                        }

                        // Сортуємо: VIP клієнти спочатку, потім звичайні
                        filteredClients.sort((a, b) {
                          final aIsVip = a['isRegularClient'] as bool;
                          final bIsVip = b['isRegularClient'] as bool;

                          if (aIsVip && !bIsVip) return -1;
                          if (!aIsVip && bIsVip) return 1;
                          return (a['name'] as String).compareTo(
                            b['name'] as String,
                          );
                        });

                        return filteredClients;
                      },
                      displayStringForOption: (client) =>
                          client['name'] as String,
                      onSelected: (client) {
                        _clientNameController.text = client['name'] as String;

                        // Заповнюємо телефон та визначаємо код країни
                        if ((client['phone'] as String).isNotEmpty) {
                          String phone = client['phone'] as String;
                          // Визначаємо код країни та прибираємо його з номера
                          for (String code
                              in PhoneValidator.countryCodes.keys) {
                            if (phone.startsWith('$code ')) {
                              _selectedCountryCode = code;
                              phone = phone.substring(code.length + 1);
                              break;
                            }
                          }
                          _phoneController.text = phone;
                        }

                        // Заповнюємо примітки клієнта
                        if (client['notes'] != null &&
                            (client['notes'] as String).isNotEmpty) {
                          _clientNotesController.text =
                              client['notes'] as String;
                        }

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
                                  final isVip =
                                      client['isRegularClient'] as bool;

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
                                              fontWeight: isVip
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isVip) ...[
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                    subtitle:
                                        (client['phone'] as String).isNotEmpty
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
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                            // Синхронізуємо початкове значення
                            if (controller.text != _clientNameController.text) {
                              controller.text = _clientNameController.text;
                            }

                            _clientNameController.addListener(() {
                              if (_clientNameController.text !=
                                  controller.text) {
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
                                    labelText: language.getText(
                                      "Ім'я клієнтки*",
                                      "Имя клиентки*",
                                    ),
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return language.getText(
                                        "Введіть ім'я клієнтки*",
                                        "Введите имя клиентки*",
                                      );
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
                                  items: PhoneValidator.countryCodes.entries
                                      .map((entry) {
                                        final code = entry.key;
                                        return DropdownMenuItem<String>(
                                          value: code,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              code,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedCountryCode = newValue;
                                        // НЕ очищуємо поле - залишаємо введені цифри
                                      });
                                    }
                                  },
                                  selectedItemBuilder: (BuildContext context) {
                                    return PhoneValidator.countryCodes.keys
                                        .map<Widget>((String code) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              code,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        })
                                        .toList();
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
                              _selectedCountryCode == '+380' ? 9 : 11,
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
                              language,
                            );
                          },
                        );
                      },
                    ),

                    // Підказка про кількість цифр
                    Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        final hint = _getDigitsHint(
                          _phoneController.text,
                          _selectedCountryCode,
                          language,
                        );
                        if (hint.isEmpty) return SizedBox.shrink();

                        final isSuccess = hint.contains('✓');
                        final isError =
                            hint.contains('Забагато') ||
                            hint.contains('Слишком');

                        return Padding(
                          padding: EdgeInsets.only(left: 12, top: 4),
                          child: Row(
                            children: [
                              Icon(
                                isSuccess
                                    ? Icons.check_circle
                                    : isError
                                    ? Icons.error
                                    : Icons.info,
                                size: 14,
                                color: isSuccess
                                    ? Colors.green
                                    : isError
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Text(
                                hint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSuccess
                                      ? Colors.green
                                      : isError
                                      ? Colors.red
                                      : Colors.orange,
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
                            labelText: language.getText(
                              'Примітки про клієнтку',
                              'Заметки о клиентке',
                            ),
                            prefixIcon: Icon(Icons.person_pin_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            helperText: language.getText(
                              'Додаткова інформація про клієнтку',
                              'Дополнительная информация о клиентке',
                            ),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
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
                                          language.getText(
                                            'Постійна клієнтка',
                                            'Постоянная клиентка',
                                          ),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                        if (_isRegularClient) ...[
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                        final localizedServices = _getLocalizedServices(
                          language,
                        );
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
                          isExpanded: true,
                          selectedItemBuilder: (BuildContext context) {
                            return localizedServices.map((String service) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  service,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList();
                          },
                          items: _originalServices.asMap().entries.map((entry) {
                            int index = entry.key;
                            String originalService = entry.value;
                            String localizedService = localizedServices[index];

                            return DropdownMenuItem<String>(
                              value:
                                  originalService, // Сохраняем оригинальное значение в БД
                              child: Text(
                                localizedService,
                              ), // Показываем локализованное
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Consumer<LanguageProvider>(
                                        builder: (context, language, child) {
                                          return Text(
                                            language.getText('Час', 'Время'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
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
                                  labelText: language.getText(
                                    'Тривалість',
                                    'Длительность',
                                  ),
                                  prefixIcon: Icon(Icons.timer_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                ),
                                selectedItemBuilder: (BuildContext context) {
                                  return _durations.map((int duration) {
                                    return Text(
                                      language.getText(
                                        '$duration хв',
                                        '$duration мин',
                                      ),
                                    );
                                  }).toList();
                                },
                                items: _durations.map((int duration) {
                                  return DropdownMenuItem<int>(
                                    value: duration,
                                    child: Text(
                                      language.getText(
                                        '$duration хв ${_getDurationDescription(duration, language)}',
                                        '$duration мин ${_getDurationDescription(duration, language)}',
                                      ),
                                    ),
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
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return language.getText(
                                'Введіть ціну послуги',
                                'Введите цену услуги',
                              );
                            }
                            final price = double.tryParse(value);
                            if (price == null) {
                              return language.getText(
                                'Введіть коректну ціну',
                                'Введите корректную цену',
                              );
                            }
                            if (price < 0) {
                              return language.getText(
                                'Ціна не може бути від\'ємною',
                                'Цена не может быть отрицательной',
                              );
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
                            labelText: language.getText(
                              'Примітки до запису \n(необов\'язково)',
                              'Заметки к записи \n(необязательно)',
                            ),
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
                      builder: (context, language, child) => Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: language.getText(
                              'Статус запису',
                              'Статус записи',
                            ),
                            prefixIcon: Icon(Icons.assignment_outlined),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
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
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.schedule,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    language.getText(
                                      "В очікуванні",
                                      "В ожидании",
                                    ),
                                    style: TextStyle(color: Colors.orange),
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
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    language.getText("Успішно", "Успешно"),
                                    style: TextStyle(color: Colors.green),
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
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    language.getText("Пропущено", "Пропущено"),
                                    style: TextStyle(color: Colors.red),
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
                      ),
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
                                onPressed: _isLoading ? null : _updateSession,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                      )
                                    : Text(
                                        language.getText('Оновити', 'Обновить'),
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
