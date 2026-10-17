import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../providers/language_provider.dart';
import '../l10n/translations_map.dart';
import 'notification_service.dart';

class SchedulerService {
  static Future<void> schedulePreciseNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = LanguageProvider.currentLanguageCode;
      final stored = prefs.getString('crop_events');
      
      List<Map<String, dynamic>> allEvents = [];
      if (stored != null) {
        try {
          final decoded = jsonDecode(stored) as List<dynamic>;
          allEvents = decoded.map((item) => item as Map<String, dynamic>).toList();
        } catch (e) {
          debugPrint('Error parsing stored events in SchedulerService: $e');
        }
      }

      final now = tz.TZDateTime.now(tz.local);

      // Schedule for the next 7 days at 10:00 AM local time
      for (int i = 0; i < 7; i++) {
        final dayDate = DateTime.now().add(Duration(days: i));
        final scheduledDate = tz.TZDateTime(tz.local, dayDate.year, dayDate.month, dayDate.day, 10, 0, 0);
        
        // Skip if 10 AM on this day has already passed
        if (scheduledDate.isBefore(now)) continue;

        final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
        final dayTasks = allEvents.where((e) {
          final dateMatch = e['date'] == dateStr;
          final notCompleted = (e['isCompleted'] == false || e['isCompleted'] == null);
          return dateMatch && notCompleted;
        }).toList();

        String title;
        String body;

        if (dayTasks.isNotEmpty) {
          title = TranslationsMap.translate('Daily 10 AM Farm Tasks 🌱', langCode);
          if (dayTasks.length == 1) {
            body = '${TranslationsMap.translate("You have 1 scheduled task for today:", langCode)} ${dayTasks.first['title']}';
          } else {
            final titles = dayTasks.map((t) => t['title']).join(', ');
            body = '${TranslationsMap.translate("You have scheduled tasks for today:", langCode)} ($titles)';
          }
        } else {
          title = TranslationsMap.translate('Daily 10 AM Farm Schedule 📋', langCode);
          body = TranslationsMap.translate('You have no farming tasks scheduled for today. Have a relaxed and wonderful day!', langCode);
        }

        await NotificationService().scheduleNotification(
          id: 200 + i,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
        );
        
        debugPrint('[SCHEDULER] Scheduled ID ${200 + i} for $dateStr at 10:00 AM -> Task count: ${dayTasks.length}');
      }
    } catch (e) {
      debugPrint('Error scheduling daily notifications: $e');
    }
  }
}
