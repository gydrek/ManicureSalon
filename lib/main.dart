import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:nastya_app/firebase_options.dart';
import 'package:nastya_app/pages/home.dart';
import 'package:nastya_app/services/firestore_service.dart';
import 'package:nastya_app/providers/app_state_provider.dart';
import 'package:nastya_app/providers/language_provider.dart';
import 'package:nastya_app/services/connectivity_service.dart';
import 'package:nastya_app/services/notification_service.dart';
import 'package:nastya_app/widgets/no_internet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ініціалізація Firebase тільки якщо ще не ініціалізований
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  // Створюємо сервіси БЕЗ будь-якої ініціалізації тут  Ї\
  final connectivityService = ConnectivityService();
  final appState = AppStateProvider();
  final languageProvider = LanguageProvider();
  
  // Запускаємо додаток НЕГАЙНО - без очікування ініціалізації 
  runApp(MyApp(
    appState: appState, 
    connectivityService: connectivityService,
    languageProvider: languageProvider,
  ));
  
  // Відкладена ініціалізація через мікро-затримку 
  // Це дозволить платформним каналам повністю ініціалізуватися 
  Future.delayed(Duration(milliseconds: 100), () async {
    try {
      print('🔄 Починаємо відкладену ініціалізацію...');
      
      await languageProvider.loadSavedLanguage();
      print('✅ LanguageProvider готовий');
      
      // Встановлюємо LanguageProvider в AppStateProvider для локалізації
      appState.setLanguageProvider(languageProvider);
      
      await connectivityService.initialize();
      print('✅ ConnectivityService готовий');
      
      final firestoreService = FirestoreService();
      await firestoreService.initializeMasters();
      print('✅ FirestoreService готовий');
      
      await appState.initialize();
      print('✅ AppStateProvider готовий');
      
      // Ініціалізуємо сервіс сповіщень
      await NotificationService().initialize();
      print('✅ NotificationService готовий');
      
    } catch (e) {
      print('⚠️ Помилка відкладеної ініціалізації: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  final AppStateProvider appState;
  final ConnectivityService connectivityService;
  final LanguageProvider languageProvider;
  
  const MyApp({
    super.key, 
    required this.appState,
    required this.connectivityService,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: Consumer2<ConnectivityService, LanguageProvider>(
        builder: (context, connectivity, language, child) {
          return MaterialApp(
        debugShowCheckedModeBanner: false,
        
        // Локалізація
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('uk'), // Українська
          Locale('ru'), // Російська
        ],
        locale: language.currentLocale, // Динамічна мова з провайдера
        
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        ),
            initialRoute: '/',
            routes: {
              '/': (context) {
                // Відразу показуємо відповідний екран залежно від підключення
                return connectivity.isConnected ? HomePage() : NoInternetScreen();
              },
            },
          );
        },
      ),
    );
  }
}