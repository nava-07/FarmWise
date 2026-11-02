import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (!kIsWeb) {
        tz_data.initializeTimeZones();
      }
      
      if (kIsWeb) {
        _isInitialized = true;
        return;
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      // Cancel any legacy scheduled alarms to prevent unwanted background notification spam
      await _notifications.cancelAll();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || !_isInitialized) return;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      } else if (!kIsWeb && Platform.isIOS) {
        final iosImplementation = _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await iosImplementation?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  Future<void> showNotification({
    int id = 0,
    String title = '',
    String body = '',
    String? payload,
  }) async {
    if (!_isInitialized) await init();
    if (kIsWeb) {
      debugPrint('[WEB NOTIFICATION] Title: $title | Body: $body');
      return;
    }
    try {
      final androidDetails = AndroidNotificationDetails(
        'farmwise_general_channel',
        'FarmWise Notifications',
        channelDescription: 'Important updates, tasks, and weather intel from FarmWise',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) await init();
    if (kIsWeb) {
      debugPrint('[WEB SCHEDULED] ID: $id | Title: $title | Date: $scheduledDate | Body: $body');
      return;
    }
    try {
      const androidDetails = AndroidNotificationDetails(
        'farmwise_daily_schedule_channel',
        'Daily Task Schedule',
        channelDescription: 'Daily alerts at 10 AM with scheduled farming tasks',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling notification with exactAllowWhileIdle: $e');
      try {
        await _notifications.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'farmwise_daily_schedule_channel',
              'Daily Task Schedule',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(''),
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexact,
          payload: payload,
        );
      } catch (fallbackError) {
        debugPrint('Fallback schedule failed: $fallbackError');
      }
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb || !_isInitialized) return;
    await _notifications.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_isInitialized) return;
    await _notifications.cancelAll();
  }
}
