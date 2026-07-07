/// خدمة الإشعارات المحلية: تذكير قبل التجديد، يوم التجديد،
/// وقبل انتهاء التجارب المجانية. كل شيء على الجهاز بدون خادم.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/subscription.dart';

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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final ok = await android.requestNotificationsPermission();
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
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!enabled) return;

      final now = DateTime.now();
      final active = subs.where((s) => !s.isPaused).toList()
        ..sort(
          (a, b) => a.daysUntilRenewal().compareTo(b.daysUntilRenewal()),
        );

      var id = 1;
      for (final s in active) {
        if (id > 58) break;
        final renewal = s.nextRenewal();

        if (s.reminderDays > 0) {
          final remindAt = DateTime(
            renewal.year,
            renewal.month,
            renewal.day - s.reminderDays,
            10,
          );
          if (remindAt.isAfter(now)) {
            await _schedule(
              id++,
              'تجديد قريب: ${s.name}',
              'سيُخصم ${fmtMoney(s.price, s.currency)} بعد ${s.reminderDays} '
              '${s.reminderDays == 1 ? "يوم" : "أيام"} — '
              'ألغِه الآن إن لم تعد تحتاجه.',
              remindAt,
            );
          }
        }

        final dayOf =
            DateTime(renewal.year, renewal.month, renewal.day, 9);
        if (dayOf.isAfter(now)) {
          await _schedule(
            id++,
            'يتجدد اليوم: ${s.name}',
            'سيُخصم ${fmtMoney(s.price, s.currency)} اليوم.',
            dayOf,
          );
        }

        final t = s.trialEndDate;
        if (t != null && id <= 60) {
          final warnAt = DateTime(t.year, t.month, t.day - 2, 10);
          if (warnAt.isAfter(now)) {
            await _schedule(
              id++,
              'تجربتك المجانية تنتهي قريبًا',
              '«${s.name}» ستتحول لاشتراك مدفوع في '
              '${t.year}/${t.month}/${t.day} — ألغِها إن لم تعجبك.',
              warnAt,
            );
          }
        }
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
        android: AndroidNotificationDetails(
          'renewals',
          'تنبيهات التجديد',
          channelDescription: 'تذكير قبل تجديد الاشتراكات',
          importance: Importance.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
