@echo off
echo 📦 Збірка Nastya Salon App для PRODUCTION релізу
echo.
echo Збірка APK для Android...
flutter build apk --dart-define=ENVIRONMENT=production --release

echo.
echo ✅ APK готовий: build\app\outputs\flutter-apk\app-release.apk
echo.
echo Збірка Windows exe...
flutter build windows --dart-define=ENVIRONMENT=production --release

echo.
echo ✅ Windows exe готовий: build\windows\x64\runner\Release\
echo.
pause