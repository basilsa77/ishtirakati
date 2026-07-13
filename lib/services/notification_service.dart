/// خدمة الإشعارات المحلية: تذكير قبل التجديد، يوم التجديد،
/// وقبل انتهاء التجارب المجانية. كل شيء على الجهاز بدون خادم.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/subscription.dart';
import 'notification_planner.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        // يدعم إصدارات flutter_timezone القديمة (String) والجديدة (TimezoneInfo).
        final dynamic info = await FlutterTimezone.getLocalTimezone();
        final String name =
            info is String ? info : (info.identifier as String);
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // نبقى على المنطقة الافتراضية إن تعذر الاكتشاف.
      }
      const settings = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      // فشل التهيئة لا يجب أن يمنع تشغيل التطبيق.
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final ok =
            await ios.requestPermissions(alert: true, badge: true, sound: true);
        return ok ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// يعيد جدولة كل الإشعارات من الصفر بناءً على الاشتراكات الحالية.
  /// (iOS يسمح بـ 64 إشعارًا معلقًا كحد أقصى — نجدول الأقرب أولًا.)
  Future<void> rescheduleAll(
    List<Subscription> subs, {
    required bool enabled,
    bool privateContent = true,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!enabled) return;

      final notifications = NotificationPlanner.build(
        subs,
        now: DateTime.now(),
        privateContent: privateContent,
      );
      for (var index = 0; index < notifications.length; index++) {
        final item = notifications[index];
        await _schedule(index + 1, item.title, item.body, item.when);
      }
    } catch (_) {
      // الجدولة اختيارية — لا نُسقط التطبيق بسببها.
    }
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
