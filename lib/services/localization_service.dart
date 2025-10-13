import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const MethodChannel _channel = MethodChannel('guardian_background_service');
  
  Locale _currentLocale = const Locale('es'); // Español por defecto
  bool _isInitialized = false;
  
  Locale get currentLocale => _currentLocale;
  bool get isInitialized => _isInitialized;
  
  // Lista de idiomas soportados (debe coincidir con AppLocalizations.supportedLocales)
  static const List<Locale> supportedLocales = [
    Locale('es'), // Español
    Locale('en'), // Inglés
  ];
  
  // Mapeo de códigos a nombres legibles
  static const Map<String, String> languageNames = {
    'es': 'Español 🇪🇸',
    'en': 'English 🇺🇸',
  };
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey);
    
    if (savedLanguage != null) {
      _currentLocale = Locale(savedLanguage);
    }
    
    _isInitialized = true;
    notifyListeners();
    
    // Notificar al sistema nativo sobre el idioma actual
    await _notifyNativeLanguageChange(_currentLocale.languageCode);
  }
  
  Future<void> setLanguage(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    
    _currentLocale = locale;
    notifyListeners();
    
    // Guardar preferencia
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    
    // Notificar al sistema nativo sobre el cambio de idioma
    await _notifyNativeLanguageChange(locale.languageCode);
  }
  
  Future<void> _notifyNativeLanguageChange(String languageCode) async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('setLanguage', {'language': languageCode});
      print('✅ Language changed to: $languageCode');
    } catch (e) {
      print('❌ Error notifying native language change: $e');
    }
  }
  
  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode;
  }
  
  bool get isSpanish => _currentLocale.languageCode == 'es';
  bool get isEnglish => _currentLocale.languageCode == 'en';
  
  // Método para obtener el código de idioma actual
  String get currentLanguageCode => _currentLocale.languageCode;
  
  // Método para obtener la bandera correspondiente
  String get currentFlag => isSpanish ? '🇪🇸' : '🇺🇸';
}
