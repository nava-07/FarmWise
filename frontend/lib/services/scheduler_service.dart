import 'notification_service.dart';

class SchedulerService {
  static Future<void> schedulePreciseNotifications() async {
    // Disabled: User only wants Welcome (on first download) and Welcome Back (after clearing RAM/cache).
    // All recurring/scheduled background task alarms are disabled to prevent notification spam.
    try {
      await NotificationService().cancelAll();
    } catch (_) {}
  }
}
