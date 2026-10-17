import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../l10n/translations_map.dart';
import 'notification_service.dart';
import 'scheduler_service.dart';

class WelcomeService {
  /// Track whether we've already shown a welcome notification in this app session.
  /// This resets when the app process is killed (cleared from recents).
  static bool _sessionNotificationShown = false;

  static Future<void> checkAndShowWelcomeNotification() async {
    // Only show one notification per app session (process lifetime)
    if (_sessionNotificationShown) return;
    _sessionNotificationShown = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = LanguageProvider.currentLanguageCode;
      final bool hasOpenedBefore = prefs.getBool('has_seen_welcome_v1') ?? false;

      // Ensure daily 10 AM schedule is aligned whenever user enters app
      SchedulerService.schedulePreciseNotifications();

      // Fetch today's weather
      String? weatherInfo;
      final locStr = prefs.getString('userLocation');
      if (locStr != null) {
        try {
          final locJson = jsonDecode(locStr) as Map<String, dynamic>;
          final double lat = (locJson['lat'] as num).toDouble();
          final double lon = (locJson['lon'] as num).toDouble();

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
            weatherInfo =
                '${TranslationsMap.translate("Today's weather in your area:", langCode)} $temp°C, $status.';
          }
        } catch (e) {
          debugPrint('WelcomeService weather fetch failed: $e');
        }
      }

      if (!hasOpenedBefore) {
        // FIRST TIME INSTALL — Welcome notification (no "back")
        await prefs.setBool('has_seen_welcome_v1', true);

        final title = TranslationsMap.translate('Welcome to FarmWise! 🌾🚜', langCode);
        String body;
        if (weatherInfo != null) {
          body = '$weatherInfo ${TranslationsMap.translate("Start your smart farming journey today!", langCode)}';
        } else {
          body = TranslationsMap.translate(
              "Welcome! Set up your farm profile and explore AI-powered crop guidance, disease scanning, and more!", langCode);
        }

        await NotificationService().showNotification(id: 101, title: title, body: body);
      } else {
        // RETURNING USER — Welcome Back with weather
        final title = TranslationsMap.translate('Welcome back to FarmWise! 🚜', langCode);
        String body;
        if (weatherInfo != null) {
          body = '$weatherInfo ${TranslationsMap.translate("Have a productive day in the field!", langCode)}';
        } else {
          body = TranslationsMap.translate(
              "Welcome back! Check today's crop guidance and daily farm schedule for a productive field day!", langCode);
        }

        await NotificationService().showNotification(id: 102, title: title, body: body);
      }
    } catch (e) {
      debugPrint('Error in WelcomeService: $e');
    }
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
