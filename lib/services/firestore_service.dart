import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nastya_app/models/models.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Колекції
  CollectionReference get _mastersCollection => _firestore.collection('masters');
  CollectionReference get _clientsCollection => _firestore.collection('clients');
  CollectionReference get _sessionsCollection => _firestore.collection('sessions');

  // ===== МЕТОДИ ДЛЯ МАЙСТРІВ =====
  
  /// Отримати всіх майстрів
  Future<List<Master>> getMasters() async {
    try {
      final QuerySnapshot snapshot = await _mastersCollection
          .get();
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
      final DocumentReference docRef = await _mastersCollection.add(master.toFirestore());
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
        print('⚠️ Майстри не знайдені в БД. Додайте їх вручну через Firebase Console або адмін панель.');
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
  Future<void> _updateExistingMastersWithLocalization(List<Master> masters) async {
    final masterTranslations = {
      'Настя': 'Настя',
      'Ніка': 'Ника', 
      'Олена': 'Елена',
      'Спеціалізація': 'Специализация',
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
          specialization: master.specialization,
          specializationRu: master.specializationRu ?? masterTranslations[master.specialization] ?? master.specialization,
        );
        needsUpdate = true;
      }

      // Якщо немає російської спеціалізації, додаємо її
      if (master.specializationRu == null || master.specializationRu!.isEmpty) {
        final ruSpecialization = masterTranslations[master.specialization] ?? master.specialization;
        updatedMaster = Master(
          id: updatedMaster.id,
          name: updatedMaster.name,
          nameRu: updatedMaster.nameRu,
          status: updatedMaster.status,
          specialization: updatedMaster.specialization,
          specializationRu: ruSpecialization,
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
      // Шукаємо існуючого клієнта
      final QuerySnapshot existingClients = await _clientsCollection
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .get();

      if (existingClients.docs.isNotEmpty) {
        return existingClients.docs.first.id;
      }

      // Створюємо нового клієнта
      final client = Client(name: name, phone: phone);
      final DocumentReference docRef = await _clientsCollection.add(client.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Помилка створення клієнта: $e');
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
            if ((uniqueClients[key]!['phone'] as String).isEmpty && (phone ?? '').isNotEmpty) {
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
            final uniqueKey = '${name.toLowerCase()}_${normalizedPhone.toLowerCase()}';
            
            // Перевіряємо чи є клієнт з таким іменем та телефоном в сесіях
            bool foundInSessions = false;
            String? matchingSessionKey;
            
            for (String sessionKey in uniqueClients.keys) {
              final sessionClient = uniqueClients[sessionKey]!;
              final sessionName = (sessionClient['name'] as String).toLowerCase();
              final sessionPhone = (sessionClient['phone'] as String).toLowerCase();
              
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
              bool existingVipStatus = uniqueClients[matchingSessionKey]!['isRegularClient'] as bool;
              uniqueClients[matchingSessionKey]!['isRegularClient'] = existingVipStatus || isRegularClient;
              // Оновлюємо телефон якщо він порожній
              if ((uniqueClients[matchingSessionKey]!['phone'] as String).isEmpty && normalizedPhone.isNotEmpty) {
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
            (b['name'] as String).toLowerCase());
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
      // Мапа для зберігання унікальних клієнток з їх VIP статусом
      final Map<String, Map<String, dynamic>> uniqueClients = {};
      
      // Спочатку завантажуємо клієнток з сесій
      final QuerySnapshot sessionsSnapshot = await _sessionsCollection.get();
      print('Знайдено сесій: ${sessionsSnapshot.docs.length}');
      
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
            if ((uniqueClients[key]!['phone'] as String).isEmpty && (phone ?? '').isNotEmpty) {
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
      
      // Потім завантажуємо клієнток з окремої колекції clients
      try {
        final QuerySnapshot clientsSnapshot = await _clientsCollection.get();
        print('Знайдено в колекції clients: ${clientsSnapshot.docs.length}');
        
        int clientsWithoutSessions = 0;
        
        for (final doc in clientsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final clientName = data['name'] as String?;
          final phone = data['phone'] as String?;
          final isRegularClient = data['isRegularClient'] as bool? ?? false;
          final notes = data['notes'] as String?; // Додаємо примітки
          
          print('Обробляю клієнта з колекції clients: $clientName, phone: $phone, isVip: $isRegularClient, notes: $notes');
          
          if (clientName != null && clientName.isNotEmpty) {
            // Створюємо унікальний ключ на основі імені та телефону
            final name = clientName.trim();
            final normalizedPhone = (phone ?? '').trim();
            final uniqueKey = '${name.toLowerCase()}_${normalizedPhone.toLowerCase()}';
            
            // Перевіряємо чи є клієнт з таким іменем та телефоном в сесіях
            bool foundInSessions = false;
            String? matchingSessionKey;
            
            for (String sessionKey in uniqueClients.keys) {
              final sessionClient = uniqueClients[sessionKey]!;
              final sessionName = (sessionClient['name'] as String).toLowerCase();
              final sessionPhone = (sessionClient['phone'] as String).toLowerCase();
              
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
              bool existingVipStatus = uniqueClients[matchingSessionKey]!['isRegularClient'] as bool;
              uniqueClients[matchingSessionKey]!['isRegularClient'] = existingVipStatus || isRegularClient;
              // Оновлюємо телефон якщо він порожній
              if ((uniqueClients[matchingSessionKey]!['phone'] as String).isEmpty && normalizedPhone.isNotEmpty) {
                uniqueClients[matchingSessionKey]!['phone'] = normalizedPhone;
              }
              // Додаємо або оновлюємо примітки з колекції clients
              uniqueClients[matchingSessionKey]!['notes'] = notes;
              print('Оновлено існуючого клієнта: $name (VIP: ${uniqueClients[matchingSessionKey]!['isRegularClient']}, Notes: $notes)');
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
              print('Додано нового клієнта без сесій: $name (Phone: $normalizedPhone, VIP: $isRegularClient, Notes: $notes)');
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
               (b['name'] as String).toLowerCase());
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
      final DocumentReference docRef = await _clientsCollection.add(client.toFirestore());
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
      print('Оновлюємо клієнта в Firestore: ID=$clientId, дані=${client.toFirestore()}');
      await _clientsCollection.doc(clientId).update(client.toFirestore());
      print('Клієнт оновлений успішно');
      return true;
    } catch (e) {
      print('Помилка оновлення клієнта: $e');
      return false;
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

  /// Знайти ID клієнта за іменем та телефоном
  Future<String?> findClientId(String name, String phone) async {
    try {
      final query = await _clientsCollection
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      
      return null;
    } catch (e) {
      print('Помилка пошуку клієнта: $e');
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
      final DocumentReference docRef = await _sessionsCollection.add(session.toFirestore());
      print('Сесія додана з ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Помилка додавання сесії: $e');
      return null;
    }
  }

  /// Отримати сесії за майстром та датою
  Future<List<Session>> getSessionsByMasterAndDate(String masterId, String date) async {
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
      // Спрощений запит без складного сортування
      final QuerySnapshot snapshot = await _sessionsCollection.get();

      final sessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }).toList();
      
      // Сортуємо в коді замість в Firestore
      sessions.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date); // Спочатку нові
        if (dateCompare != 0) return dateCompare;
        return a.time.compareTo(b.time); // Потім за часом
      });
      
      return sessions;
    } catch (e) {
      print('Помилка отримання всіх сесій: $e');
      return [];
    }
  }

  /// Отримати сесії майстра за місяць (для календаря)
  Future<List<Session>> getSessionsByMasterAndMonth(String masterId, int year, int month) async {
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
      
      print('✅ Відфільтровано для місяця $month/$year: ${monthSessions.length} сесій');
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
      print('🔍 Завантажуємо ВСІ сесії за $month/$year');
      
      // Один запит для всіх сесій
      final QuerySnapshot snapshot = await _sessionsCollection.get();

      print('📊 Знайдено всіх документів: ${snapshot.docs.length}');
      
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
      
      print('✅ Відфільтровано для місяця $month/$year: ${monthSessions.length} сесій');
      
      return monthSessions;
    } catch (e) {
      print('❌ Помилка отримання сесій за місяць: $e');
      return [];
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
  Future<List<Session>> getSessionsForDateRange(String startDate, String endDate) async {
    try {
      print('🔍 Завантажуємо сесії за період: $startDate - $endDate');
      
      // Отримуємо сесії за діапазон дат використовуючи фільтри Firestore
      final QuerySnapshot snapshot = await _sessionsCollection
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date')
          .orderBy('time')
          .get();
      
      print('📊 Знайдено сесій за період: ${snapshot.docs.length}');
      
      final sessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Session.fromFirestore(data);
      }).toList();
      
      print('✅ Завантажено сесій за період $startDate - $endDate: ${sessions.length}');
      
      return sessions;
    } catch (e) {
      print('❌ Помилка отримання сесій за діапазон дат: $e');
      return [];
    }
  }
}