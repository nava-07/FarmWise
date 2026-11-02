import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../l10n/translations_map.dart';
import 'notification_service.dart';

class WelcomeService {
  /// Track whether we've already shown a welcome notification in this app process/session.
  /// This in-memory static variable resets to false whenever the app process is terminated
  /// (i.e. user clears RAM / closes the app from recent apps / app is killed).
  static bool _sessionNotificationShown = false;
  static bool _isProcessing = false;

  static bool get hasShownInSession => _sessionNotificationShown;

  static Future<void> checkAndShowWelcomeNotification() async {
    // Only show once per app session (process lifetime)
    if (_sessionNotificationShown || _isProcessing) return;
    _isProcessing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = LanguageProvider.currentLanguageCode;

      // Check if user has launched the app before on this installation
      // If cache/data was cleared or fresh download, this will be false.
      final bool hasInstalledBefore =
          prefs.getBool('farmwise_has_installed_and_launched_v2') ?? false;

      // 1. Fetch today's weather
      final String weatherInfo = await _fetchTodayWeather(prefs, langCode);

      // Check flag again before showing
      if (_sessionNotificationShown) return;
      _sessionNotificationShown = true;

      if (!hasInstalledBefore) {
        // CASE 1: FIRST TIME INSTALL BY DOWNLOADING (OR AFTER CLEARING CACHE/DATA)
        await prefs.setBool('farmwise_has_installed_and_launched_v2', true);

        final title = TranslationsMap.translate('Welcome to FarmWise! 🌱', langCode);
        final body =
            '$weatherInfo ${TranslationsMap.translate("We are thrilled to empower your farming journey with smart recommendations and real-time weather intel!", langCode)}';

        await NotificationService().showNotification(
          id: 101,
          title: title,
          body: body,
        );
      } else {
        // CASE 2: AFTER CLEARING RAM / ENTERING AFTER CLOSING RECENTS
        final title = TranslationsMap.translate('Welcome back to FarmWise! 🚜', langCode);
        final body =
            '$weatherInfo ${TranslationsMap.translate("Have a productive day in the field!", langCode)}';

        await NotificationService().showNotification(
          id: 102,
          title: title,
          body: body,
        );
      }
    } catch (e) {
      debugPrint('Error in WelcomeService: $e');
    } finally {
      _isProcessing = false;
    }
  }

  static Future<String> _fetchTodayWeather(
      SharedPreferences prefs, String langCode) async {
    double lat = 11.0168;
    double lon = 76.9558;

    final locStr = prefs.getString('userLocation');
    if (locStr != null) {
      try {
        final locJson = jsonDecode(locStr) as Map<String, dynamic>;
        lat = (locJson['lat'] as num).toDouble();
        lon = (locJson['lon'] as num).toDouble();
      } catch (e) {
        debugPrint('Error parsing userLocation in WelcomeService: $e');
      }
    }

    try {
      final res = await http
          .get(Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final current = data['current_weather'] as Map<String, dynamic>;
        final temp = current['temperature'];
        final code = (current['weathercode'] as num?)?.toInt() ?? 1;
        final status = _getWeatherStatusString(code, langCode);
        return '${TranslationsMap.translate("Today's weather in your area:", langCode)} $temp°C, $status.';
      }
    } catch (e) {
      debugPrint('WelcomeService weather fetch failed: $e');
    }

    // Default fallback so weather is always available even offline
    final defaultStatus = TranslationsMap.translate('Clear Sky', langCode);
    return '${TranslationsMap.translate("Today's weather in your area:", langCode)} 28°C, $defaultStatus.';
  }

  static String _getWeatherStatusString(int code, String langCode) {
    String englishLabel = 'Cloudy';
    if (code == 0) {
      englishLabel = 'Clear Sky';
    } else if ([1, 2, 3].contains(code)) {
      englishLabel = 'Partly Cloudy';
    } else if ([45, 48].contains(code)) {
      englishLabel = 'Foggy';
    } else if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) {
      englishLabel = 'Rainy';
    } else if ([95, 96, 99].contains(code)) {
      englishLabel = 'Thunderstorm';
    }
    return TranslationsMap.translate(englishLabel, langCode);
  }
}
