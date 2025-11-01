class Master {
  final String? id;
  final String name; // Ім'я українською (за замовчуванням)
  final String? nameRu; // Ім'я російською
  final String status;

  Master({this.id, required this.name, this.nameRu, required this.status});

  // Для SQLite (залишимо для сумісності, але не використовуємо)
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'nameRu': nameRu, 'status': status};
  }

  factory Master.fromMap(Map<String, dynamic> map) {
    return Master(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      nameRu: map['nameRu'],
      status: map['status'] ?? 'available',
    );
  }

  // Для Firestore
  Map<String, dynamic> toFirestore() {
    return {'name': name, 'nameRu': nameRu, 'status': status};
  }

  factory Master.fromFirestore(Map<String, dynamic> data) {
    return Master(
      id: data['id'],
      name: data['name'] ?? '',
      nameRu: data['nameRu'],
      status: data['status'] ?? 'available',
    );
  }

  // Методи для отримання локалізованого контенту
  String getLocalizedName(String languageCode) {
    if (languageCode == 'ru' && nameRu != null && nameRu!.isNotEmpty) {
      return nameRu!;
    }
    return name;
  }
}

class Client {
  final String? id;
  final String name;
  final String? phone;
  final String? email;
  final bool isRegularClient; // VIP статус
  final String? notes; // Примітки

  Client({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.isRegularClient = false,
    this.notes,
  });

  // Для SQLite (залишимо для сумісності)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'isRegularClient': isRegularClient,
      'notes': notes,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      isRegularClient: map['isRegularClient'] ?? false,
      notes: map['notes'],
    );
  }

  // Для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'isRegularClient': isRegularClient,
      'notes': notes,
    };
  }

  factory Client.fromFirestore(Map<String, dynamic> data) {
    return Client(
      id: data['id'],
      name: data['name'] ?? '',
      phone: data['phone'],
      email: data['email'],
      isRegularClient: data['isRegularClient'] ?? false,
      notes: data['notes'],
    );
  }
}

class Session {
  final String? id;
  final String masterId;
  final String clientId;
  final String clientName;
  final String? phone;
  final String service;
  final int duration;
  final String date;
  final String time;
  final String? notes;
  final double? price; // Ціна в євро
  final bool isRegularClient; // Постійна клієнтка
  final String status; // Статус запису: "в очікуванні", "успішно", "пропущено"

  Session({
    this.id,
    required this.masterId,
    required this.clientId,
    required this.clientName,
    this.phone,
    required this.service,
    required this.duration,
    required this.date,
    required this.time,
    this.notes,
    this.price,
    this.isRegularClient = false,
    this.status = "в очікуванні",
  });

  // Для SQLite (залишимо для сумісності)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'master_id': masterId,
      'client_id': clientId,
      'client_name': clientName,
      'phone': phone,
      'service': service,
      'duration': duration,
      'date': date,
      'time': time,
      'notes': notes,
      'price': price,
      'isRegularClient': isRegularClient,
      'status': status,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id']?.toString(),
      masterId: map['master_id']?.toString() ?? '',
      clientId: map['client_id']?.toString() ?? '',
      clientName: map['client_name'] ?? '',
      phone: map['phone'],
      service: map['service'] ?? '',
      duration: map['duration']?.toInt() ?? 60,
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      notes: map['notes'],
      price: map['price']?.toDouble(),
      isRegularClient: map['isRegularClient'] ?? false,
      status: map['status'] ?? "в очікуванні",
    );
  }

  // Для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'masterId': masterId,
      'clientId': clientId,
      'clientName': clientName,
      'phone': phone,
      'service': service,
      'duration': duration,
      'date': date,
      'time': time,
      'notes': notes,
      'price': price,
      'isRegularClient': isRegularClient,
      'status': status,
    };
  }

  factory Session.fromFirestore(Map<String, dynamic> data) {
    return Session(
      id: data['id'],
      masterId: data['masterId'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      phone: data['phone'],
      service: data['service'] ?? '',
      duration: data['duration']?.toInt() ?? 60,
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      notes: data['notes'],
      price: data['price']?.toDouble(),
      isRegularClient: data['isRegularClient'] ?? false,
      status: data['status'] ?? "в очікуванні",
    );
  }
}
