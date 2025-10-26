# iOS Build Setup через GitHub Actions

## Кроки налаштування:

### 1. Базова збірка (без підпису):
- Використовуйте `ios-build.yml` - він створить непідписану збірку
- Запускається автоматично при push/PR або вручну
- Результат: zip-файл з Runner.app

### 2. Для підписаної збірки (App Store):

#### Потрібні секрети в GitHub Repository Settings > Secrets:

1. **APPLE_CERTIFICATE_BASE64**: 
   - Експортуйте сертифікат з Keychain в .p12 формат
   - Конвертуйте в base64: `base64 -i certificate.p12`

2. **APPLE_CERTIFICATE_PASSWORD**:
   - Пароль для .p12 сертифіката

3. **APPSTORE_ISSUER_ID**:
   - App Store Connect > Users and Access > Keys > Issuer ID

4. **APPSTORE_KEY_ID**:
   - App Store Connect > Users and Access > Keys > Key ID

5. **APPSTORE_PRIVATE_KEY**:
   - Завантажте .p8 файл з App Store Connect
   - Скопіюйте весь вміст файлу

#### Налаштування Bundle ID:
1. Оновіть `bundle-id` в `ios-release.yml`
2. Переконайтеся що Bundle ID збігається з App Store Connect

### 3. Запуск збірки:

#### Автоматично:
- При push в main/master (базова збірка)
- При створенні тегу версії `v1.0.0` (release збірка)

#### Вручну:
1. GitHub Repository > Actions
2. Виберіть потрібний workflow
3. Натисніть "Run workflow"

### 4. Завантаження результату:
- Перейдіть в GitHub Actions > відповідний run
- Завантажте artifact із секції "Artifacts"

### 5. Версії та теги:
Для release збірки створіть тег:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Примітки:
- macOS runners мають ліміт хвилин (безкоштовно 2000 хв/місяць)
- Для App Store потрібен платний Apple Developer аккаунт
- Перша збірка може зайняти 10-15 хвилин