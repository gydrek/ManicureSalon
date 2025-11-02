import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nastya_app/models/models.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Колекції
  CollectionReference get _mastersCollection =>
      _firestore.collection('masters');
  CollectionReference get _clientsCollection =>
      _firestore.collection('clients');
  CollectionReference get _sessionsCollection =>
      _firestore.collection('sessions');

  // ===== МЕТОДИ ДЛЯ МАЙСТРІВ =====

  /// Отримати всіх майстрів
  Future<List<Master>> getMasters() async {
    try {
      final QuerySnapshot snapshot = await _mastersCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Додаємо ID документа
        return Master.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Помилка отримання майстрів: $e');
      return [];
    }
  }

  /// Отримати майстра за ID
  Future<Master?> getMasterById(String id) async {
    try {
      final DocumentSnapshot doc = await _mastersCollection.doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Master.fromFirestore(data);
      }
      return null;
    } catch (e) {
      print('Помилка отримання майстра: $e');
      return null;
    }
  }

  /// Додати майстра
  Future<String?> addMaster(Master master) async {
    try {
      final DocumentReference docRef = await _mastersCollection.add(
        master.toFirestore(),
      );
      return docRef.id;
    } catch (e) {
      print('Помилка додавання майстра: $e');
      return null;
    }
  }

  /// Оновити майстра
  Future<bool> updateMaster(String masterId, Master master) async {
    try {
      await _mastersCollection.doc(masterId).update(master.toFirestore());
      print('Майстра оновлено: ${master.name}');
      return true;
    } catch (e) {
      print('Помилка оновлення майстра: $e');
      return false;
    }
  }

  /// Завантажити майстрів з БД (без автоматичного додавання)
  Future<void> initializeMasters() async {
    try {
      print('Завантажуємо майстрів з БД...');
      final masters = await getMasters();
      print('Знайдено майстрів у БД: ${masters.length}');

      if (masters.isEmpty) {
        print(
          '⚠️ Майстри не знайдені в БД. Додайте їх вручну через Firebase Console або адмін панель.',
        );
      } else {
        print('✅ Майстри успішно завантажені з БД:');
        for (final master in masters) {
          print('  - ${master.name} (${master.nameRu}) - ${master.status}');
        }

        // Оновлюємо локалізацію для існуючих майстрів якщо потрібно
        await _updateExistingMastersWithLocalization(masters);
      }
    } catch (e) {
      print('❌ Помилка завантаження майстрів з БД: $e');
    }
  }

  /// Оновити існуючих майстрів з локалізацією
  Future<void> _updateExistingMastersWithLocalization(
    List<Master> masters,
  ) async {
    final masterTranslations = {
      'Настя': 'Настя',
      'Ніка': 'Ника',
      'Олена': 'Елена',
    };

    for (final master in masters) {
      bool needsUpdate = false;
      Master updatedMaster = master;

      // Якщо немає російського імені, додаємо його
      if (master.nameRu == null || master.nameRu!.isEmpty) {
        final ruName = masterTranslations[master.name] ?? master.name;
        updatedMaster = Master(
          id: master.id,
          name: master.name,
          nameRu: ruName,
          status: master.status,
        );
        needsUpdate = true;
      }

      if (needsUpdate && master.id != null) {
        await updateMaster(master.id!, updatedMaster);
        print('Додано локалізацію для майстра: ${master.name}');
      }
    }
  }

  /// Очистити всіх майстрів (для тестування)
  Future<void> clearAllMasters() async {
    try {
      final QuerySnapshot snapshot = await _mastersCollection.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('Всі майстрині видалені');
    } catch (e) {
      print('Помилка очищення майстрів: $e');
    }
  }

  // ===== МЕТОДИ ДЛЯ КЛІЄНТІВ =====

  /// Отримати або створити клієнта за іменем та телефоном
  Future<String?> getOrCreateClient(String name, String phone) async {
    try {
      print('🔍 Шукаємо клієнта: name="$name", phone="$phone"');
      
      // Спочатку шукаємо за телефоном (більш надійно)
      QuerySnapshot existingClients = await _clientsCollection
          .where('phone', isEqualTo: phone)
          .get();

      // Якщо знайшли за телефоном, перевіряємо чи потрібно оновити ім'я
      if (existingClients.docs.isNotEmpty) {
        final clientDoc = existingClients.docs.first;
        final clientData = clientDoc.data() as Map<String, dynamic>;
        final existingName = clientData['name'] as String;
        
        print('📱 Знайшли клієнта за телефоном: existingName="$existingName", newName="$name"');
        
        // Якщо ім'я змінилось, оновлюємо його
        if (existingName != name) {
          print('🔄 Оновлюємо ім\'я клієнта: "$existingName" -> "$name"');
          await _clientsCollection.doc(clientDoc.id).update({'name': name});
        }
        
        return clientDoc.id;
      }

      // Якщо не знайшли за телефоном, шукаємо за ім'ям та телефоном
      existingClients = await _clientsCollection
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .get();

      if (existingClients.docs.isNotEmpty) {
        print('👤 Знайшли клієнта за ім\'ям та телефоном');
        return existingClients.docs.first.id;
      }

      // Створюємо нового клієнта
      print('➕ Створюємо нового клієнта');
      final client = Client(name: name, phone: phone);
      final DocumentReference docRef = await _clientsCollection.add(
        client.toFirestore(),
      );
      print('✅ Створено нового клієнта з ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Помилка створення клієнта: $e');
      return null;
    }
  }

  /// Отримати всіх клієнтів
  Future<List<Client>> getClients() async {
    try {
      final QuerySnapshot snapshot = await _clientsCollection
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Client.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Помилка отримання клієнтів: $e');
      return [];
    }
  }

  /// Отримати унікальних клієнток з VIP статусом з обох колекцій (sessions + clients)
  Future<List<Map<String, dynamic>>> getUniqueClientsWithVipStatus() async {
    try {
      // Мапа для зберігання унікальних клієнток з їх VIP статусом
      final Map<String, Map<String, dynamic>> uniqueClients = {};

      // Спочатку завантажуємо клієнток з сесій
      final QuerySnapshot sessionsSnapshot = await _sessionsCollection.get();

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final clientName = data['clientName'] as String?;
        final phone = data['phone'] as String?;
        final isRegularClient = data['isRegularClient'] as bool? ?? false;

        if (clientName != null && clientName.isNotEmpty) {
          final key = clientName.toLowerCase().trim();

          // Якщо клієнтка вже є, оновлюємо VIP статус (true має пріоритет)
          if (uniqueClients.containsKey(key)) {
            uniqueClients[key]!['isRegularClient'] =
                uniqueClients[key]!['isRegularClient'] || isRegularClient;
            // Оновлюємо телефон якщо він порожній
            if ((uniqueClients[key]!['phone'] as String).isEmpty &&
                (phone ?? '').isNotEmpty) {
              uniqueClients[key]!['phone'] = phone!;
            }
          } else {
            uniqueClients[key] = {
              'name': clientName,
              'phone': phone ?? '',
              'isRegularClient': isRegularClient,
              'notes': null, // Клієнти з сесій спочатку без приміток
            };
          }
        }
      }

      // Потім завантажуємо клієнток з окремої колекції clients
      try {
        final QuerySnapshot clientsSnapshot = await _clientsCollection.get();

        for (final doc in clientsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final clientName = data['name'] as String?;
          final phone = data['phone'] as String?;
          final isRegularClient = data['isRegularClient'] as bool? ?? false;
          final notes = data['notes'] as String?; // Додаємо примітки

          if (clientName != null && clientName.isNotEmpty) {
            // Створюємо унікальний ключ на основі імені та телефону
            final name = clientName.trim();
            final normalizedPhone = (phone ?? '').trim();
            final uniqueKey =
                '${name.toLowerCase()}_${normalizedPhone.toLowerCase()}';

            // Перевіряємо чи є клієнт з таким іменем та телефоном в сесіях
            bool foundInSessions = false;
            String? matchingSessionKey;

            for (String sessionKey in uniqueClients.keys) {
              final sessionClient = uniqueClients[sessionKey]!;
              final sessionName = (sessionClient['name'] as String)
                  .toLowerCase();
              final sessionPhone = (sessionClient['phone'] as String)
                  .toLowerCase();

              // Порівнюємо за іменем та телефоном
              if (sessionName == name.toLowerCase() &&
                  (sessionPhone == normalizedPhone.toLowerCase() ||
                      (sessionPhone.isEmpty && normalizedPhone.isEmpty))) {
                foundInSessions = true;
                matchingSessionKey = sessionKey;
                break;
              }
            }

            if (foundInSessions && matchingSessionKey != null) {
              // Оновлюємо існуючого клієнта з сесій
              bool existingVipStatus =
                  uniqueClients[matchingSessionKey]!['isRegularClient'] as bool;
              uniqueClients[matchingSessionKey]!['isRegularClient'] =
                  existingVipStatus || isRegularClient;
              // Оновлюємо телефон якщо він порожній
              if ((uniqueClients[matchingSessionKey]!['phone'] as String)
                      .isEmpty &&
                  normalizedPhone.isNotEmpty) {
                uniqueClients[matchingSessionKey]!['phone'] = normalizedPhone;
              }
              // Додаємо або оновлюємо примітки з колекції clients
              uniqueClients[matchingSessionKey]!['notes'] = notes;
            } else {
              // Додаємо нового клієнта (без сесій) з унікальним ключем
              uniqueClients[uniqueKey] = {
                'name': name,
                'phone': normalizedPhone,
                'isRegularClient': isRegularClient,
                'notes': notes, // Додаємо примітки
              };
            }
          }
        }
      } catch (e) {
        print('Помилка доступу до колекції clients: $e');
        // Продовжуємо з клієнтами з сесій
      }

      // Сортуємо: спочатку VIP, потім по алфавіту
      final sortedClients = uniqueClients.values.toList();
      sortedClients.sort((a, b) {
        // Спочатку сортуємо по VIP статусу (VIP - перші)
        final aVip = a['isRegularClient'] as bool;
        final bVip = b['isRegularClient'] as bool;

        if (aVip && !bVip) return -1;
        if (!aVip && bVip) return 1;

        // Потім по алфавіту
        return (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        );
      });

      return sortedClients;
    } catch (e) {
      print('Помилка отримання унікальних клієнток: $e');
      return [];
    }
  }

  /// Отримати всіх клієнток з обох колекцій (sessions + clients) з VIP статусом
  Future<List<Map<String, dynamic>>> getAllClientsWithVipStatus() async {
    try {
      print('🔍 Завантажуємо клієнтів з VIP статусом (оптимізовано)');

      // Мапа для зберігання унікальних клієнток з їх VIP статусом
      final Map<String, Map<String, dynamic>> uniqueClients = {};

      // ОПТИМІЗОВАНО: Завантажуємо тільки останні сесії для визначення VIP статусу
      final QuerySnapshot sessionsSnapshot = await _sessionsCollection
          .orderBy('date', descending: true)
          .limit(1000) // Обмежуємо - для VIP статусу достатньо останніх сесій
          .get();
      print(
        'Завантажено останніх сесій для VIP аналізу: ${sessionsSnapshot.docs.length}',
      );

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final clientName = data['clientName'] as String?;
        final phone = data['phone'] as String?;
        final isRegularClient = data['isRegularClient'] as bool? ?? false;

        if (clientName != null && clientName.isNotEmpty) {
          final key = clientName.toLowerCase().trim();

          // Якщо клієнтка вже є, оновлюємо VIP статус (true має пріоритет)
          if (uniqueClients.containsKey(key)) {
            uniqueClients[key]!['isRegularClient'] =
                uniqueClients[key]!['isRegularClient'] || isRegularClient;
            // Оновлюємо телефон якщо він порожній
            if ((uniqueClients[key]!['phone'] as String).isEmpty &&
                (phone ?? '').isNotEmpty) {
              uniqueClients[key]!['phone'] = phone!;
            }
          } else {
            uniqueClients[key] = {
              'name': clientName,
              'phone': phone ?? '',
              'isRegularClient': isRegularClient,
              'hasSession': true,
              'notes': null, // Клієнти з сесій спочатку без приміток
            };
          }
        }
      }

      print('Клієнтів з сесій: ${uniqueClients.length}');

      // ОПТИМІЗОВАНО: Завантажуємо клієнтів з обмеженням
      try {
        final QuerySnapshot clientsSnapshot = await _clientsCollection
            .orderBy('name')
            .limit(200) // Обмежуємо кількість клієнтів
            .get();
        print('Завантажено з колекції clients: ${clientsSnapshot.docs.length}');

        int clientsWithoutSessions = 0;

        for (final doc in clientsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final clientName = data['name'] as String?;
          final phone = data['phone'] as String?;
          final isRegularClient = data['isRegularClient'] as bool? ?? false;
          final notes = data['notes'] as String?; // Додаємо примітки

          print(
            'Обробляю клієнта з колекції clients: $clientName, phone: $phone, isVip: $isRegularClient, notes: $notes',
          );

          if (clientName != null && clientName.isNotEmpty) {
            // Створюємо унікальний ключ на основі імені та телефону
            final name = clientName.trim();
            final normalizedPhone = (phone ?? '').trim();
            final uniqueKey =
                '${name.toLowerCase()}_${normalizedPhone.toLowerCase()}';

            // Перевіряємо чи є клієнт з таким іменем та телефоном в сесіях
            bool foundInSessions = false;
            String? matchingSessionKey;

            for (String sessionKey in uniqueClients.keys) {
              final sessionClient = uniqueClients[sessionKey]!;
              final sessionName = (sessionClient['name'] as String)
                  .toLowerCase();
              final sessionPhone = (sessionClient['phone'] as String)
                  .toLowerCase();

              // Порівнюємо за іменем та телефоном
              if (sessionName == name.toLowerCase() &&
                  (sessionPhone == normalizedPhone.toLowerCase() ||
                      (sessionPhone.isEmpty && normalizedPhone.isEmpty))) {
                foundInSessions = true;
                matchingSessionKey = sessionKey;
                break;
              }
            }

            if (foundInSessions && matchingSessionKey != null) {
              // Оновлюємо існуючого клієнта з сесій
              bool existingVipStatus =
                  uniqueClients[matchingSessionKey]!['isRegularClient'] as bool;
              uniqueClients[matchingSessionKey]!['isRegularClient'] =
                  existingVipStatus || isRegularClient;
              // Оновлюємо телефон якщо він порожній
              if ((uniqueClients[matchingSessionKey]!['phone'] as String)
                      .isEmpty &&
                  normalizedPhone.isNotEmpty) {
                uniqueClients[matchingSessionKey]!['phone'] = normalizedPhone;
              }
              // Додаємо або оновлюємо примітки з колекції clients
              uniqueClients[matchingSessionKey]!['notes'] = notes;
              print(
                'Оновлено існуючого клієнта: $name (VIP: ${uniqueClients[matchingSessionKey]!['isRegularClient']}, Notes: $notes)',
              );
            } else {
              // Додаємо нового клієнта (без сесій) з унікальним ключем
              uniqueClients[uniqueKey] = {
                'name': name,
                'phone': normalizedPhone,
                'isRegularClient': isRegularClient,
                'hasSession': false,
                'notes': notes, // Додаємо примітки
              };
              clientsWithoutSessions++;
              print(
                'Додано нового клієнта без сесій: $name (Phone: $normalizedPhone, VIP: $isRegularClient, Notes: $notes)',
              );
            }
          }
        }

        print('Всього клієнтів без сесій: $clientsWithoutSessions');
      } catch (e) {
        print('Помилка завантаження з колекції clients: $e');
      }

      print('Всього унікальних клієнтів: ${uniqueClients.length}');

      // Сортуємо: спочатку VIP, потім по алфавіту
      final sortedClients = uniqueClients.values.toList();
      sortedClients.sort((a, b) {
        // Спочатку сортуємо по VIP статусу (VIP - перші)
        final aVip = a['isRegularClient'] as bool;
        final bVip = b['isRegularClient'] as bool;

        if (aVip && !bVip) return -1;
        if (!aVip && bVip) return 1;

        // Потім по алфавіту
        return (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        );
      });

      return sortedClients;
    } catch (e) {
      print('Помилка отримання всіх клієнток: $e');
      return [];
    }
  }

  /// Додати нового клієнта в колекцію clients
  Future<String?> addClient(Client client) async {
    try {
      print('Додаємо клієнта в Firestore: ${client.toFirestore()}');
      final DocumentReference docRef = await _clientsCollection.add(
        client.toFirestore(),
      );
      print('Клієнт доданий з ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Помилка додавання клієнта: $e');
      return null;
    }
  }

  /// Оновити існуючого клієнта
  Future<bool> updateClient(String clientId, Client client) async {
    try {
      print(
        'Оновлюємо клієнта в Firestore: ID=$clientId, дані=${client.toFirestore()}',
      );

      // Спочатку отримуємо старі дані клієнта для порівняння
      final oldClientDoc = await _clientsCollection.doc(clientId).get();
      final oldClientData = oldClientDoc.data() as Map<String, dynamic>?;

      // Оновлюємо клієнта в колекції clients
      await _clientsCollection.doc(clientId).update(client.toFirestore());

      // Якщо змінилося ім'я, телефон або VIP статус, оновлюємо всі сесії цього клієнта
      if (oldClientData != null) {
        final oldName = oldClientData['name'] as String?;
        final oldPhone = oldClientData['phone'] as String?;
        final oldIsRegular = oldClientData['isRegularClient'] as bool? ?? false;

        if (oldName != client.name ||
            oldPhone != client.phone ||
            oldIsRegular != client.isRegularClient) {
          print(
            'Дані клієнта змінились (ім\'я: $oldName->${client.name}, телефон: $oldPhone->${client.phone}, VIP: $oldIsRegular->${client.isRegularClient}), оновлюємо сесії...',
          );
          await _updateClientSessionsData(
            clientId,
            oldName ?? '',
            oldPhone ?? '',
            client.name,
            client.phone ?? '',
            client.isRegularClient,
          );
        }
      }

      print('Клієнт та його сесії оновлені успішно');
      return true;
    } catch (e) {
      print('Помилка оновлення клієнта: $e');
      return false;
    }
  }

  /// Оновити дані клієнта у всіх його сесіях
  Future<void> _updateClientSessionsData(
    String clientId,
    String oldName,
    String oldPhone,
    String newName,
    String newPhone,
    bool isRegularClient,
  ) async {
    try {
      print(
        '🔄 Оновлюємо сесії клієнта: clientId=$clientId, oldName="$oldName", newName="$newName", VIP=$isRegularClient',
      );

      // Множина для відстеження оновлених документів (уникаємо дублікатів)
      final Set<String> updatedDocIds = {};

      // 1. ПРІОРИТЕТ: Шукаємо сесії за ім'ям та телефоном (для клієнток створених через сесії)
      if (oldName.isNotEmpty && oldPhone.isNotEmpty) {
        print('🔍 Шукаємо сесії за oldName="$oldName" та oldPhone="$oldPhone"');
        final namePhoneQuery = await _sessionsCollection
            .where('clientName', isEqualTo: oldName)
            .where('phone', isEqualTo: oldPhone)
            .get();

        print(
          '📊 Знайдено сесій за ім\'ям+телефоном: ${namePhoneQuery.docs.length}',
        );

        for (final doc in namePhoneQuery.docs) {
          await doc.reference.update({
            'clientId':
                clientId, // Важливо: встановлюємо clientId для майбутніх оновлень
            'clientName': newName,
            'phone': newPhone,
            'isRegularClient': isRegularClient,
          });
          updatedDocIds.add(doc.id);
          print(
            '✅ Оновлено сесію ${doc.id}: "$oldName"->"$newName", "$oldPhone"->"$newPhone", VIP->$isRegularClient',
          );
        }
      }

      // 2. Шукаємо сесії за clientId (для клієнток з колекції clients)
      print('🔍 Шукаємо сесії за clientId="$clientId"');
      final clientIdQuery = await _sessionsCollection
          .where('clientId', isEqualTo: clientId)
          .get();
      print('📊 Знайдено сесій за clientId: ${clientIdQuery.docs.length}');

      for (final doc in clientIdQuery.docs) {
        // Перевіряємо, чи не оновили вже цей документ
        if (!updatedDocIds.contains(doc.id)) {
          await doc.reference.update({
            'clientName': newName,
            'phone': newPhone,
            'isRegularClient': isRegularClient,
          });
          updatedDocIds.add(doc.id);
          print(
            '✅ Оновлено сесію ${doc.id} за clientId: "$newName", "$newPhone", VIP->$isRegularClient',
          );
        } else {
          print('⏭️ Сесія ${doc.id} вже була оновлена');
        }
      }

      // 3. ДОДАТКОВО: Якщо змінилося ім'я, шукаємо сесії з новим ім'ям, але старим VIP статусом
      if (oldName != newName && newName.isNotEmpty) {
        print(
          '🔍 Додатковий пошук сесій з новим ім\'ям="$newName" для оновлення VIP статусу',
        );
        final newNameQuery = await _sessionsCollection
            .where('clientName', isEqualTo: newName)
            .get();

        for (final doc in newNameQuery.docs) {
          if (!updatedDocIds.contains(doc.id)) {
            final sessionData = doc.data() as Map<String, dynamic>;
            final currentVip = sessionData['isRegularClient'] as bool? ?? false;

            // Оновлюємо тільки якщо VIP статус відрізняється
            if (currentVip != isRegularClient) {
              await doc.reference.update({
                'clientId': clientId,
                'isRegularClient': isRegularClient,
              });
              updatedDocIds.add(doc.id);
              print(
                '✅ Оновлено VIP статус для сесії ${doc.id}: VIP $currentVip->$isRegularClient',
              );
            }
          }
        }
      }

      print(
        '🎉 Оновлення завершено. Всього оновлено сесій: ${updatedDocIds.length}',
      );
    } catch (e) {
      print('❌ Помилка оновлення сесій клієнта: $e');
    }
  }

  /// Видалити клієнта
  Future<bool> deleteClient(String clientId) async {
    try {
      print('Видаляємо клієнта з Firestore: ID=$clientId');
      await _clientsCollection.doc(clientId).delete();
      print('Клієнт видалений успішно');
      return true;
    } catch (e) {
      print('Помилка видалення клієнта: $e');
      return false;
    }
  }

  /// Знайти ID клієнта за іменем та телефоном (або створити запис, якщо не існує)
  Future<String?> findClientId(String name, String phone) async {
    try {
      print('🔍 Шукаємо клієнта: name="$name", phone="$phone"');

      // Спочатку шукаємо в колекції clients
      final query = await _clientsCollection
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .get();

      if (query.docs.isNotEmpty) {
        final clientId = query.docs.first.id;
        print('✅ Знайдено клієнта в колекції clients: ID=$clientId');
        return clientId;
      }

      print('⚠️ Клієнта не знайдено в колекції clients, шукаємо в сесіях...');

      // Якщо не знайдено в clients, шукаємо в сесіях і створюємо запис
      final sessionsQuery = await _sessionsCollection
          .where('clientName', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (sessionsQuery.docs.isNotEmpty) {
        // Знайшли клієнтку в сесіях, створюємо запис в clients
        final sessionData =
            sessionsQuery.docs.first.data() as Map<String, dynamic>;
        final isRegularClient =
            sessionData['isRegularClient'] as bool? ?? false;

        print('📋 Створюємо запис клієнта з даних сесії: VIP=$isRegularClient');

        final client = Client(
          name: name,
          phone: phone,
          isRegularClient: isRegularClient,
        );

        final newClientRef = await _clientsCollection.add(client.toFirestore());
        final newClientId = newClientRef.id;

        print('✅ Створено новий запис клієнта: ID=$newClientId');

        // Оновлюємо всі сесії цієї клієнтки з новим clientId
        final allSessionsQuery = await _sessionsCollection
            .where('clientName', isEqualTo: name)
            .where('phone', isEqualTo: phone)
            .get();

        for (final doc in allSessionsQuery.docs) {
          await doc.reference.update({'clientId': newClientId});
        }

        print(
          '🔗 Оновлено ${allSessionsQuery.docs.length} сесій з новим clientId',
        );

        return newClientId;
      }

      print('❌ Клієнта не знайдено ні в clients, ні в sessions');
      return null;
    } catch (e) {
      print('❌ Помилка пошуку/створення клієнта: $e');
      return null;
    }
  }

  /// Отримати клієнта за ID
  Future<Client?> getClientById(String clientId) async {
    try {
      final doc = await _clientsCollection.doc(clientId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Client.fromFirestore(data..['id'] = doc.id);
      }
      return null;
    } catch (e) {
      print('Помилка отримання клієнта за ID: $e');
      return null;
    }
  }

  // ===== МЕТОДИ ДЛЯ СЕСІЙ =====

  /// Додати нову сесію
  Future<String?> addSession(Session session) async {
    try {
      print('Додаємо сесію в Firestore: ${session.toFirestore()}');
      final DocumentReference docRef = await _sessionsCollection.add(
        session.toFirestore(),
      );
      print('Сесія додана з ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Помилка додавання сесії: $e');
      return null;
    }
  }

  /// Отримати сесії за майстром та датою
  Future<List<Session>> getSessionsByMasterAndDate(
    String masterId,
    String date,
  ) async {
    try {
      print('Шукаємо сесії в Firestore: masterId=$masterId, date=$date');

      // Спрощений запит без сортування
      final QuerySnapshot snapshot = await _sessionsCollection
          .where('masterId', isEqualTo: masterId)
          .where('date', isEqualTo: date)
          .get();

      print('Знайдено документів у Firestore: ${snapshot.docs.length}');

      final sessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        print('Документ ${doc.id}: $data');
        return Session.fromFirestore(data);
      }).toList();

      // Сортуємо в коді
      sessions.sort((a, b) => a.time.compareTo(b.time));

      print('Перетворено в сесії: ${sessions.length}');
      return sessions;
    } catch (e) {
      print('Помилка отримання сесій: $e');
      return [];
    }
  }

  /// Отримати всі сесії
  Future<List<Session>> getAllSessions() async {
    try {
      print('🔍 Завантажуємо останні сесії для архіву (оптимізовано)');

      // ОПТИМІЗОВАНО: Завантажуємо тільки останні сесії з сортуванням в БД
      final QuerySnapshot snapshot = await _sessionsCollection
          .orderBy('date', descending: true)
          .limit(500) // Обмежуємо кількість - архів показує останні сесії
          .get();

      print(
        '📊 Завантажено для архіву: ${snapshot.docs.length} сесій (замість всіх)',
      );

      final sessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }).toList();

      // БД вже відсортувала за датою, додатково сортуємо за часом
      sessions.sort((a, b) {
        final dateCompare = b.date.compareTo(
          a.date,
        ); // Спочатку нові (вже відсортовані БД)
        if (dateCompare != 0) return dateCompare;
        return b.time.compareTo(a.time); // Потім за часом (нові спочатку)
      });

      return sessions;
    } catch (e) {
      print('Помилка отримання всіх сесій: $e');
      return [];
    }
  }

  /// Отримати сесії майстра за місяць (для календаря)
  Future<List<Session>> getSessionsByMasterAndMonth(
    String masterId,
    int year,
    int month,
  ) async {
    try {
      print('🔍 Шукаємо сесії майстра $masterId за $month/$year');

      // Простий запит тільки по майстру (без діапазону дат)
      final QuerySnapshot snapshot = await _sessionsCollection
          .where('masterId', isEqualTo: masterId)
          .get();

      print('📊 Знайдено всіх документів майстра: ${snapshot.docs.length}');

      final allSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }).toList();

      // Фільтруємо по місяцю в коді
      final monthSessions = allSessions.where((session) {
        try {
          final dateParts = session.date.split('-');
          final sessionYear = int.parse(dateParts[0]);
          final sessionMonth = int.parse(dateParts[1]);

          return sessionYear == year && sessionMonth == month;
        } catch (e) {
          print('❌ Помилка парсингу дати: ${session.date}');
          return false;
        }
      }).toList();

      // Сортуємо в коді
      monthSessions.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.time.compareTo(b.time);
      });

      print(
        '✅ Відфільтровано для місяця $month/$year: ${monthSessions.length} сесій',
      );
      for (final session in monthSessions) {
        print('   📅 ${session.date} ${session.time} - ${session.clientName}');
      }

      return monthSessions;
    } catch (e) {
      print('❌ Помилка отримання сесій за місяць: $e');
      return [];
    }
  }

  /// ОПТИМІЗОВАНИЙ метод: Отримати всі сесії за місяць (для всіх майстрів одразу)
  Future<List<Session>> getSessionsByMonth(int year, int month) async {
    try {
      final requestTime = DateTime.now().millisecondsSinceEpoch;
      print('🔍 Завантажуємо сесії за $month/$year з фільтрацією в БД (запит #$requestTime)');

      // Створюємо дати початку і кінця місяця
      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final nextMonth = month == 12 ? 1 : month + 1;
      final nextYear = month == 12 ? year + 1 : year;
      final endDate = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

      print('📅 Період запиту: $startDate до $endDate');

      // ОПТИМІЗОВАНО: Фільтруємо в БД, а не в коді!
      // Додаємо Source.server для обходу локального кешу Firestore
      final QuerySnapshot snapshot = await _sessionsCollection
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThan: endDate)
          .orderBy('date', descending: true)
          .limit(200) // Обмежуємо кількість для безпеки
          .get(const GetOptions(source: Source.server));

      print(
        '📊 Знайдено документів за місяць: ${snapshot.docs.length} (замість завантаження всіх)',
      );

      final sessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }).toList();

      // БД вже відфільтрувала і відсортувала за нас!
      print('✅ Завантажено для місяця $month/$year: ${sessions.length} сесій (запит #$requestTime)');
      
      // Показуємо останні кілька записів для debug
      if (sessions.isNotEmpty) {
        final recentSessions = sessions.take(3).map((s) => '${s.date} ${s.time} ${s.clientName}').join(', ');
        print('📋 Останні записи: $recentSessions');
      }

      return sessions;
    } catch (e) {
      print('❌ Помилка отримання сесій за місяць: $e');
      return [];
    }
  }

  /// Отримати сесії за період (оптимізований для home.dart)
  Future<List<Session>> getSessionsForPeriod(DateTime startDate, DateTime endDate) async {
    try {
      final requestTime = DateTime.now().millisecondsSinceEpoch;
      final startDateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDateStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      
      print('🔍 Завантажуємо сесії за період $startDateStr - $endDateStr (запит #$requestTime)');

      // Один запит замість багатьох
      final QuerySnapshot snapshot = await _sessionsCollection
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThan: endDateStr)
          .orderBy('date', descending: false) // Сортуємо по зростанню для home.dart
          .limit(500) // Збільшуємо ліміт для 3-х місяців
          .get(const GetOptions(source: Source.server));

      print('📊 Знайдено документів за період: ${snapshot.docs.length}');

      final sessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }).toList();

      print('✅ Завантажено за period ${startDateStr}-${endDateStr}: ${sessions.length} сесій (запит #$requestTime)');
      
      if (sessions.isNotEmpty) {
        final recentSessions = sessions.take(3).map((s) => '${s.date} ${s.time} ${s.clientName}').join(', ');
        print('📋 Перші записи: $recentSessions');
      }

      return sessions;
    } catch (e) {
      print('❌ Помилка отримання сесій за період: $e');
      return [];
    }
  }

  /// Отримати сесію за ID
  Future<Session?> getSessionById(String sessionId) async {
    try {
      final DocumentSnapshot doc = await _sessionsCollection
          .doc(sessionId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }
      return null;
    } catch (e) {
      print('Помилка отримання сесії за ID: $e');
      return null;
    }
  }

  /// Оновити сесію
  Future<bool> updateSession(String sessionId, Session session) async {
    try {
      await _sessionsCollection.doc(sessionId).update(session.toFirestore());
      return true;
    } catch (e) {
      print('Помилка оновлення сесії: $e');
      return false;
    }
  }

  /// Видалити сесію
  Future<bool> deleteSession(String sessionId) async {
    try {
      await _sessionsCollection.doc(sessionId).delete();
      return true;
    } catch (e) {
      print('Помилка видалення сесії: $e');
      return false;
    }
  }

  // ===== REAL-TIME STREAMING =====

  /// Stream для отримання майстрів в реальному часі
  Stream<List<Master>> mastersStream() {
    return _mastersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Master.fromFirestore(data);
      }).toList();
    });
  }

  /// Stream для отримання сесій в реальному часі
  Stream<List<Session>> sessionsStream(String masterId, String date) {
    return _sessionsCollection
        .where('masterId', isEqualTo: masterId)
        .where('date', isEqualTo: date)
        .orderBy('time')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return Session.fromFirestore(data);
          }).toList();
        });
  }

  /// Отримати сесії за діапазон дат (для аналітики)
  Future<List<Session>> getSessionsForDateRange(
    String startDate,
    String endDate,
  ) async {
    try {
      print('🔍 Завантажуємо сесії за період: $startDate - $endDate');

      // Спробуємо спочатку з простим запитом по одному полю
      QuerySnapshot snapshot;
      try {
        snapshot = await _sessionsCollection
            .where('date', isGreaterThanOrEqualTo: startDate)
            .where('date', isLessThanOrEqualTo: endDate)
            .get();
      } catch (indexError) {
        print('⚠️ Помилка з індексом, завантажуємо всі сесії: $indexError');
        // Якщо не працює з фільтрами, завантажуємо всі сесії та фільтруємо локально
        snapshot = await _sessionsCollection.get();
      }

      print('📊 Знайдено сесій до фільтрації: ${snapshot.docs.length}');

      final allSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }).toList();

      // Фільтруємо локально якщо потрібно
      final filteredSessions = allSessions.where((session) {
        return session.date.compareTo(startDate) >= 0 && 
               session.date.compareTo(endDate) <= 0;
      }).toList();

      print('✅ Завантажено сесій за період $startDate - $endDate: ${filteredSessions.length}');

      return filteredSessions;
    } catch (e) {
      print('❌ Помилка отримання сесій за діапазон дат: $e');
      return [];
    }
  }

  /// Перевірити, чи має клієнтка сесії (для безпечного видалення)
  Future<Map<String, dynamic>> checkClientSessions(
    String clientId,
    String clientName,
    String? clientPhone,
  ) async {
    try {
      print(
        '🔍 Перевіряємо сесії клієнтки: ID=$clientId, name="$clientName", phone="$clientPhone"',
      );

      int totalSessions = 0;
      List<Map<String, dynamic>> recentSessions = [];

      // 1. Шукаємо сесії за clientId
      final clientIdQuery = await _sessionsCollection
          .where('clientId', isEqualTo: clientId)
          .get();

      totalSessions += clientIdQuery.docs.length;
      print('📊 Знайдено сесій за clientId: ${clientIdQuery.docs.length}');

      // Додаємо останні сесії для показу
      for (final doc in clientIdQuery.docs.take(3)) {
        final data = doc.data() as Map<String, dynamic>;
        recentSessions.add({
          'date': data['date'],
          'time': data['time'],
          'masterId': data['masterId'],
        });
      }

      // 2. Шукаємо сесії за ім'ям та телефоном (для клієнток створених через сесії)
      if (clientPhone != null && clientPhone.isNotEmpty) {
        final namePhoneQuery = await _sessionsCollection
            .where('clientName', isEqualTo: clientName)
            .where('phone', isEqualTo: clientPhone)
            .get();

        // Рахуємо тільки унікальні сесії (не враховуємо ті, що вже знайшли за clientId)
        final Set<String> existingSessionIds = clientIdQuery.docs
            .map((doc) => doc.id)
            .toSet();
        int additionalSessions = 0;

        for (final doc in namePhoneQuery.docs) {
          if (!existingSessionIds.contains(doc.id)) {
            additionalSessions++;
            if (recentSessions.length < 5) {
              final data = doc.data() as Map<String, dynamic>;
              recentSessions.add({
                'date': data['date'],
                'time': data['time'],
                'masterId': data['masterId'],
              });
            }
          }
        }

        totalSessions += additionalSessions;
        print(
          '📊 Знайдено додаткових сесій за ім\'ям+телефоном: $additionalSessions',
        );
      }
      // 3. Якщо телефону немає, шукаємо тільки за ім'ям (менш надійно)
      else {
        final nameQuery = await _sessionsCollection
            .where('clientName', isEqualTo: clientName)
            .get();

        final Set<String> existingSessionIds = clientIdQuery.docs
            .map((doc) => doc.id)
            .toSet();
        int additionalSessions = 0;

        for (final doc in nameQuery.docs) {
          if (!existingSessionIds.contains(doc.id)) {
            additionalSessions++;
            if (recentSessions.length < 5) {
              final data = doc.data() as Map<String, dynamic>;
              recentSessions.add({
                'date': data['date'],
                'time': data['time'],
                'masterId': data['masterId'],
              });
            }
          }
        }

        totalSessions += additionalSessions;
        print('📊 Знайдено додаткових сесій за ім\'ям: $additionalSessions');
      }

      // Сортуємо сесії за датою (новіші спочатку)
      recentSessions.sort((a, b) {
        final dateCompare = (b['date'] as String).compareTo(
          a['date'] as String,
        );
        if (dateCompare != 0) return dateCompare;
        return (b['time'] as String).compareTo(a['time'] as String);
      });

      print('✅ Загальна кількість сесій клієнтки: $totalSessions');

      return {
        'totalSessions': totalSessions,
        'hasSessions': totalSessions > 0,
        'recentSessions': recentSessions
            .take(3)
            .toList(), // Показуємо тільки 3 останні
      };
    } catch (e) {
      print('❌ Помилка перевірки сесій клієнтки: $e');
      return {
        'totalSessions': 0,
        'hasSessions': false,
        'recentSessions': <Map<String, dynamic>>[],
        'error': e.toString(),
      };
    }
  }
}
