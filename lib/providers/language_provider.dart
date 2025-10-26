import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = Locale('uk'); // За замовчуванням українська

  Locale get currentLocale => _currentLocale;

  // Завантаження збереженої мови при старті
  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('app_language') ?? 'uk';
    _currentLocale = Locale(savedLanguage);
    notifyListeners();
  }

  // Зміна мови
  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  // Отримання тексту залежно від мови
  String getText(String ukText, String ruText) {
    return _currentLocale.languageCode == 'ru' ? ruText : ukText;
  }
}