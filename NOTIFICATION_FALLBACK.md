# Альтернативна конфігурація AndroidManifest.xml (якщо будуть проблеми)

## Якщо виникнуть подальші проблеми з receivers, можна спростити конфігурацію:

1. Видаліть ці рядки з AndroidManifest.xml:
```xml
<!-- Ресивер для відновлення сповіщень після перезавантаження -->
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
          android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</receiver>

<!-- Ресивер для сповіщень -->
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
          android:exported="false" />
```

2. Також видаліть з дозволів:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Це означатиме, що сповіщення не відновлюватимуться після перезавантаження телефону, 
але основна функціональність працюватиме.