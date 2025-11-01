# 🚀 Nastya Salon App - Міграція на продакшн

## 📋 Кроки для міграції на робочу БД:

### 1. Створення нового Firebase проекту

1. Перейдіть на [Firebase Console](https://console.firebase.google.com/)
2. Натисніть "Create a project" або "Додати проект"
3. Назвіть проект: `nastya-manicure-salon-prod` (або інша назва)
4. Виберіть налаштування Google Analytics (рекомендується увімкнути)
5. Створіть проект

### 2. Налаштування Firestore Database

1. У новому проекті перейдіть до "Firestore Database"
2. Натисніть "Create database"
3. Виберіть **Production mode** (не Test mode!)
4. Виберіть локацію (рекомендується `europe-west3` для Європи)
5. Натисніть "Enable"

### 3. Налаштування правил безпеки Firestore

У розділі "Firestore Database" → "Rules" встановіть такі правила:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Дозволяємо читання та запис для всіх колекцій
    // У майбутньому можна додати автентифікацію
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### 4. Додавання платформ до Firebase проекту

#### Android:
1. У Firebase Console натисніть "Add app" → Android
2. Package name: `com.nastya.salon`
3. App nickname: `Nastya Salon Android`
4. Завантажте `google-services.json`
5. Скопіюйте дані з файлу до `lib/firebase_options_prod.dart`

#### iOS (якщо потрібно):
1. Натисніть "Add app" → iOS
2. Bundle ID: `com.nastya.salon`
3. App nickname: `Nastya Salon iOS`
4. Завантажте `GoogleService-Info.plist`
5. Скопіюйте дані до `lib/firebase_options_prod.dart`

#### Web (якщо потрібно):
1. Натисніть "Add app" → Web
2. App nickname: `Nastya Salon Web`
3. Скопіюйте конфігурацію до `lib/firebase_options_prod.dart`

### 5. Оновлення конфігурації

1. Відкрийте файл `lib/firebase_options_prod.dart`
2. Замініть всі `YOUR-PROD-*` значення на реальні з Firebase Console
3. Замініть `nastya-manicure-salon-prod` на реальний project ID

### 6. Тестування

#### Development (тестова БД):
```bash
# Запустіть з тестовою БД
./run_dev.bat
# або
flutter run --dart-define=ENVIRONMENT=development
```

#### Production (робоча БД):
```bash
# Запустіть з робочою БД
./run_prod.bat
# або
flutter run --dart-define=ENVIRONMENT=production
```

### 7. Створення релізу

```bash
# Створіть релізні файли
./build_release.bat
```

Це створить:
- `build/app/outputs/flutter-apk/app-release.apk` - для Android
- `build/windows/x64/runner/Release/` - для Windows

### 8. Міграція даних (опціонально)

Якщо потрібно перенести дані з тестової БД:

1. У Firebase Console старого проекту перейдіть до "Firestore Database"
2. Експортуйте дані через "Import/Export"
3. У новому проекті імпортуйте дані

### 9. Перевірка

1. Запустіть застосунок в production режимі
2. Переконайтесь, що логи показують правильний Firebase project
3. Створіть тестову сесію та перевірте, що дані зберігаються в новій БД
4. Перевірте, що всі функції працюють

### 10. Розповсюдження

- **Android**: Завантажте APK файл на Google Play Console або поширюйте напряму
- **Windows**: Поширюйте exe файл з папки Release

## 🔧 Налаштування після міграції

### Оновлення версії застосунку

У файлі `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Змініть на актуальну версію
```

### Вимкнення debug режиму

У продакшн версії всі debug логи автоматично вимикаються завдяки `AppConfig.enableLogging: false`.

## 🚨 Важливі зауваження

1. **Безпека**: Ніколи не додавайте реальні API ключі до git репозиторію
2. **Тестування**: Завжди тестуйте продакшн версію перед релізом
3. **Бекапи**: Регулярно створюйте бекапи Firestore БД
4. **Моніторинг**: Налаштуйте Firebase Analytics для відстеження використання

## 📱 Поточний стан

- ✅ Структура проекту готова
- ✅ Конфігурація для різних середовищ створена
- ⏳ Потрібно створити новий Firebase проект та оновити ключі
- ⏳ Потрібно протестувати продакшн версію