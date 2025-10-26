import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/models/models.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/providers/language_provider.dart';
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

class ClientEditPage extends StatefulWidget {
  final Map<String, dynamic> clientData;
  final String clientId;

  const ClientEditPage({
    super.key,
    required this.clientData,
    required this.clientId,
  });

  @override
  State<ClientEditPage> createState() => _ClientEditPageState();
}

class _ClientEditPageState extends State<ClientEditPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  bool _isRegularClient = false;
  String _selectedCountryCode = '+49'; // За замовчуванням німецький номер

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

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  void _loadClientData() {
    _nameController.text = widget.clientData['name'] ?? '';
    
    // Обробляємо телефон - визначаємо код країни та номер
    String fullPhone = widget.clientData['phone'] ?? '';
    String phoneNumber = '';
    
    // Визначаємо код країни з існуючого номера
    for (String code in PhoneValidator.countryCodes.keys) {
      if (fullPhone.startsWith('$code ')) {
        _selectedCountryCode = code;
        phoneNumber = fullPhone.substring(code.length + 1);
        break;
      }
    }
    
    // Якщо не знайшли код, залишаємо як є (для зворотної сумісності)
    if (phoneNumber.isEmpty) {
      phoneNumber = fullPhone;
    }
    
    _phoneController.text = phoneNumber;
    
    _notesController.text = widget.clientData['notes'] ?? '';
    _isRegularClient = widget.clientData['isRegularClient'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateClient() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Формуємо повний номер телефону з вибраним кодом країни
        final fullPhoneNumber = '$_selectedCountryCode ${_phoneController.text.trim()}';
        
        // Створюємо клієнта з оновленими даними
        final client = Client(
          id: widget.clientId,
          name: _nameController.text.trim(),
          phone: fullPhoneNumber,
          isRegularClient: _isRegularClient,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        // Оновлюємо в базі даних
        final success = await _firestoreService.updateClient(widget.clientId, client);
        
        if (success && mounted) {
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
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          language.getText('Клієнтка успішно оновлена!', 'Клиентка успешно обновлена!'),
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
          
          // Повертаємось до списку клієнтів з результатом
          Navigator.pop(context, true);
        } else if (mounted) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
          throw Exception(language.getText('Не вдалося оновити клієнтку', 'Не удалось обновить клиентку'));
        }
      } catch (e) {
        if (mounted) {
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
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          '${language.getText('Помилка оновлення', 'Ошибка обновления')}: $e',
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

  Future<void> _deleteClient() async {
    // Показуємо діалог підтвердження
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, language, child) {
          return AlertDialog(
            title: Text(language.getText('Видалити клієнтку?', 'Удалить клиентку?')),
            content: Text(
              '${language.getText('Ви впевнені, що хочете видалити клієнтку', 'Вы уверены, что хотите удалить клиентку')} "${widget.clientData['name']}"?\n\n${language.getText('Цю дію неможливо скасувати.', 'Это действие невозможно отменить.')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(language.getText('Скасувати', 'Отменить')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(language.getText('Видалити', 'Удалить')),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _firestoreService.deleteClient(widget.clientId);
        
        if (success && mounted) {
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
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          language.getText('Клієнтка успішно видалена!', 'Клиентка успешно удалена!'),
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
          
          // Повертаємось до списку клієнтів з результатом
          Navigator.pop(context, true);
        } else if (mounted) {
          final language = Provider.of<LanguageProvider>(context, listen: false);
          throw Exception(language.getText('Не вдалося видалити клієнтку', 'Не удалось удалить клиентку'));
        }
      } catch (e) {
        if (mounted) {
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
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Text(
                          '${language.getText('Помилка видалення', 'Ошибка удаления')}: $e',
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
              language.getText('Редагування \nклієнтки', 'Редактирование \nклиентки'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Consumer<LanguageProvider>(
            builder: (context, language, child) {
              return IconButton(
                onPressed: _isLoading ? null : _deleteClient,
                icon: Icon(Icons.delete_outline),
                tooltip: language.getText('Видалити клієнтку', 'Удалить клиентку'),
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
                  // Заголовок
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
                            Icons.person_outline,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Consumer<LanguageProvider>(
                                builder: (context, language, child) {
                                  return Text(
                                    language.getText('Редагування клієнтки', 'Редактирование клиентки'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 4),
                              Consumer<LanguageProvider>(
                                builder: (context, language, child) {
                                  return Text(
                                    language.getText('Оновіть інформацію про клієнтку', 'Обновите информацию о клиентке'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
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
                  
                  SizedBox(height: 24),
                  
                  // Форма
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return Text(
                        language.getText('Основна інформація', 'Основная информация'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Ім'я клієнта
                  Consumer<LanguageProvider>(
                    builder: (context, language, child) {
                      return TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: language.getText("Ім'я клієнтки*", "Имя клиентки*"),
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return language.getText("Введіть ім'я клієнтки", "Введите имя клиентки");
                          }
                          return null;
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
                          helperText: language.getText('Додаткова інформація про клієнтку', 'Дополнительная информация о клиентке'),
                        ),
                        maxLines: 3,
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
                              onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                              onPressed: _isLoading ? null : _updateClient,
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
