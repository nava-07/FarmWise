import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/translations_map.dart';
import '../services/scheduler_service.dart';

class SupportedLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String localeCode;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.localeCode,
  });
}

class LanguageProvider extends ChangeNotifier {
  static const List<SupportedLanguage> supportedLanguages = [
    SupportedLanguage(code: 'en', name: 'English', nativeName: 'English', localeCode: 'en_IN'),
    SupportedLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', localeCode: 'hi_IN'),
    SupportedLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', localeCode: 'ta_IN'),
    SupportedLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు', localeCode: 'te_IN'),
    SupportedLanguage(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', localeCode: 'kn_IN'),
    SupportedLanguage(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', localeCode: 'ml_IN'),
    SupportedLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी', localeCode: 'mr_IN'),
    SupportedLanguage(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', localeCode: 'gu_IN'),
    SupportedLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', localeCode: 'bn_IN'),
    SupportedLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', localeCode: 'pa_IN'),
    SupportedLanguage(code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ', localeCode: 'or_IN'),
    SupportedLanguage(code: 'as', name: 'Assamese', nativeName: 'অসমীয়া', localeCode: 'as_IN'),
    SupportedLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو', localeCode: 'ur_IN'),
    SupportedLanguage(code: 'sa', name: 'Sanskrit', nativeName: 'संस्कृत', localeCode: 'sa_IN'),
    SupportedLanguage(code: 'kok', name: 'Konkani', nativeName: 'कोंकणी', localeCode: 'kok_IN'),
    SupportedLanguage(code: 'mni', name: 'Manipuri (Meitei)', nativeName: 'মৈতৈলোন্', localeCode: 'mni_IN'),
    SupportedLanguage(code: 'brx', name: 'Bodo', nativeName: 'बड़ो', localeCode: 'brx_IN'),
    SupportedLanguage(code: 'doi', name: 'Dogri', nativeName: 'डोगरी', localeCode: 'doi_IN'),
    SupportedLanguage(code: 'ks', name: 'Kashmiri', nativeName: 'کأشُر', localeCode: 'ks_IN'),
    SupportedLanguage(code: 'mai', name: 'Maithili', nativeName: 'मैथिली', localeCode: 'mai_IN'),
    SupportedLanguage(code: 'ne', name: 'Nepali', nativeName: 'नेपाली', localeCode: 'ne_NP'),
    SupportedLanguage(code: 'sat', name: 'Santali', nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ', localeCode: 'sat_IN'),
    SupportedLanguage(code: 'sd', name: 'Sindhi', nativeName: 'سنڌي', localeCode: 'sd_IN'),
  ];

  static SupportedLanguage _current = supportedLanguages.first;

  static String get currentLanguageCode => _current.code;
  static String get currentLanguageName => _current.name;
  static String get currentLanguageNative => _current.nativeName;
  static String get currentLocaleCode => _current.localeCode;

  SupportedLanguage get currentLanguage => _current;

  LanguageProvider() {
    loadSavedLanguage();
  }

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('selected_language_code') ?? 'en';
    
    _current = supportedLanguages.firstWhere(
      (lang) => lang.code == savedCode,
      orElse: () => supportedLanguages.first,
    );
    notifyListeners();
  }

  Future<void> setLanguage(SupportedLanguage lang) async {
    if (_current.code == lang.code) return;
    
    _current = lang;
    notifyListeners(); // Instantly apply language without restarting!

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language_code', lang.code);
    await prefs.setString('selected_language_name', lang.name);
    await prefs.setString('selected_language_native', lang.nativeName);
    await prefs.setString('user_profile_preferred_language', lang.code);
    SchedulerService.schedulePreciseNotifications();
  }

  String translate(String text) {
    return TranslationsMap.translate(text, _current.code);
  }
}

extension LocalizationExtension on String {
  String tr(BuildContext context) {
    try {
      final provider = Provider.of<LanguageProvider>(context, listen: true);
      return provider.translate(this);
    } catch (_) {
      return this;
    }
  }
}
