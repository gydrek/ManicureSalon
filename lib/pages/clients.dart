import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nastya_app/widgets/update_info_widget.dart';
import 'package:nastya_app/pages/clientAdd.dart';
import 'package:nastya_app/pages/clientEdit.dart';
import 'package:nastya_app/widgets/connectivity_wrapper.dart';
import 'package:nastya_app/providers/language_provider.dart';


class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClientsInit();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Ініціалізація без оновлення AppStateProvider (щоб уникнути помилки під час build)
  Future<void> _loadClientsInit() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await _firestoreService.getAllClientsWithVipStatus();
      
      print('Завантажено клієнтів: ${clients.length}');
      print('Клієнти без сесій: ${clients.where((c) => !(c['hasSession'] as bool? ?? true)).length}');
      
      // Сортуємо: VIP спочатку, потім за алфавітом
      clients.sort((a, b) {
        final aIsVip = a['isRegularClient'] as bool;
        final bIsVip = b['isRegularClient'] as bool;
        
        if (aIsVip && !bIsVip) return -1;
        if (!aIsVip && bIsVip) return 1;
        return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
      });

      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });
    } catch (e) {
      print('Помилка завантаження клієнтів: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Оновлення з AppStateProvider (для свайпу)
  Future<void> _loadClients({bool showMessage = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Оновлюємо через AppStateProvider (при свайпі - примусово для оновлення часу)
      await Provider.of<AppStateProvider>(context, listen: false).refreshAllData(forceRefresh: showMessage);
      
      final clients = await _firestoreService.getAllClientsWithVipStatus();
      
      print('Завантажено клієнтів: ${clients.length}');
      print('Клієнти без сесій: ${clients.where((c) => !(c['hasSession'] as bool? ?? true)).length}');
      
      // Сортуємо: VIP спочатку, потім за алфавітом
      clients.sort((a, b) {
        final aIsVip = a['isRegularClient'] as bool;
        final bIsVip = b['isRegularClient'] as bool;
        
        if (aIsVip && !bIsVip) return -1;
        if (!aIsVip && bIsVip) return 1;
        return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
      });

      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });
      
      // Показуємо повідомлення про оновлення (тільки при свайпі)
      if (showMessage && context.mounted) {
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
                      language.getText('Клієнтки оновлені свайпом', 'Клиентки обновлены свайпом'),
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
    } catch (e) {
      print('Помилка завантаження клієнтів: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        final name = (client['name'] as String).toLowerCase();
        final phone = (client['phone'] as String).toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return Text(
              language.getText('Не вдалося здійснити дзвінок', 'Не удалось совершить звонок'),
            );
          },
        )),
      );
    }
  }

  Future<void> _sendWhatsApp(String phoneNumber) async {
    // Прибираємо всі пробіли та спеціальні символи
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+49$cleanPhone';
    }
    
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Consumer<LanguageProvider>(
          builder: (context, language, child) {
            return Text(
              language.getText('Не вдалося відкрити WhatsApp', 'Не удалось открыть WhatsApp'),
            );
          },
        )),
      );
    }
  }

  Future<String?> _getClientId(Map<String, dynamic> client) async {
    try {
      // Спробуємо знайти клієнта в колекції clients за іменем та телефоном
      return await _firestoreService.findClientId(
        client['name'] as String,
        client['phone'] as String,
      );
    } catch (e) {
      print('Помилка пошуку клієнта: $e');
      return null;
    }
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    final isVip = client['isRegularClient'] as bool;
    final name = client['name'] as String;
    final phone = client['phone'] as String;
    final hasSession = client['hasSession'] as bool? ?? true; // За замовчуванням true для старих даних
    final notes = client['notes'] as String?; // Додаємо примітки

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Верхня частина: аватар, ім'я, статуси та кнопки телефону
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Аватар
                CircleAvatar(
                  backgroundColor: isVip ? Colors.amber : Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),
                
                SizedBox(width: 16),
                
                // Ім'я та статуси
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ім'я та статуси
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isVip ? FontWeight.bold : FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          // Індикатор стану клієнта
                          if (!hasSession) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Consumer<LanguageProvider> (
                                builder: (context, language, child) {
                                  return Text(
                                    language.getText('Без записів', 'Без записей'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 4),
                          ],
                          if (isVip) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.diamond, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'VIP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      // Телефон
                      if (phone.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          phone,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      
                      // Примітки
                      if (notes != null && notes.isNotEmpty) ...[
                        SizedBox(height: 6),
                        Container(
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
                                Icons.note_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  notes,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Кнопки телефону та WhatsApp (зверху справа)
                if (phone.isNotEmpty) ...[
                  SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return IconButton(
                            icon: Icon(Icons.phone, color: Colors.blue[600]),
                            onPressed: () => _makePhoneCall(phone),
                            tooltip: language.getText('Зателефонувати', 'Позвонить'),
                            iconSize: 28,
                            constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.all(8),
                          );
                        },
                      ),
                      Consumer<LanguageProvider>(
                        builder: (context, language, child) {
                          return IconButton(
                            icon: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                            onPressed: () => _sendWhatsApp(phone),
                            tooltip: language.getText('WhatsApp', 'WhatsApp'),
                            iconSize: 28,
                            constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.all(8),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
            
            // Нижня частина: кнопка редагування (знизу справа)
            Row(
              children: [
                Spacer(),
                Consumer<LanguageProvider>(
                  builder: (context, language, child) {
                    return IconButton(
                      icon: Icon(Icons.edit_outlined, color: Colors.orange[600]),
                      onPressed: () async {
                        // Потрібно передати ID клієнта для редагування
                        // Спочатку знайдемо ID клієнта в колекції clients
                        final clientId = await _getClientId(client);
                    if (clientId != null) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClientEditPage(
                            clientData: client,
                            clientId: clientId,
                          ),
                        ),
                      );
                      
                      // Якщо клієнт був оновлений, оновлюємо список
                      if (result == true) {
                        _loadClients();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Consumer<LanguageProvider>(
                            builder: (context, language, child) {
                              return Text(
                                language.getText('Не вдалося знайти клієнтку для редагування', 'Не удалось найти клиентку для редактирования'),
                              );
                            },
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  tooltip: language.getText('Редагувати клієнтку', 'Редактировать клиентку'),
                  iconSize: 28,
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.all(8),
                );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              language.getText('Клієнтки', 'Клиентки'),
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
        child: RefreshIndicator(
          onRefresh: () => _loadClients(showMessage: true),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
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
              child: Column(
                children: [
                  // Інформація про останнє оновлення
                  UpdateInfoWidget(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  
                  // Пошук
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: language.getText('Пошук клієнток...(Ім\'я, телефон)', 'Поиск клиенток...(Имя, телефон)'),
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 8, left: 4),
                                child: Text(
                                  language.getText(
                                    'Знайдено збігів: ${_filteredClients.length}',
                                    'Найдено совпадений: ${_filteredClients.length}'
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  // Статистика
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Consumer<LanguageProvider>(
                      builder: (context, language, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '${_clients.length}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  language.getText('Всього', 'Всего'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 35,
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                            ),
                            Column(
                              children: [
                                Text(
                                  '${_clients.where((c) => c['isRegularClient'] as bool).length}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                                Text(
                                  'VIP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 35,
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                            ),
                            Column(
                              children: [
                                Text(
                                  '${_clients.where((c) => !(c['hasSession'] as bool? ?? true)).length}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  language.getText('Без записів', 'Без записей'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Список клієнтів або стани завантаження/порожнього списку
                  _isLoading
                      ? Container(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : _filteredClients.isEmpty
                          ? Container(
                              height: 300,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    SizedBox(height: 16),
                                    Consumer<LanguageProvider>(
                                      builder: (context, language, child) {
                                        return Text(
                                          _searchController.text.isNotEmpty
                                              ? language.getText('Клієнток не знайдено', 'Клиенток не найдено')
                                              : language.getText('Клієнток ще немає', 'Клиенток еще нет'),
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                ..._filteredClients.map((client) => _buildClientCard(client)).toList(),
                                SizedBox(height: 16), // Додаткове місце внизу
                              ],
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Consumer<LanguageProvider>(
        builder: (context, language, child) {
          return FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientAddPage(),
                ),
              );
              
              // Якщо клієнт був доданий, оновлюємо список
              if (result == true) {
                _loadClients();
              }
            },
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: Icon(Icons.person_add),
            tooltip: language.getText('Додати клієнтку', 'Добавить клиентку'),
          );
        },
      ),
      ),
    );
  }
}