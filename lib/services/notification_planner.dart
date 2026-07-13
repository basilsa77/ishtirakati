import '../models/subscription.dart';

class PlannedNotification {
  final DateTime when;
  final String title;
  final String body;
  final int priority;

  const PlannedNotification({
    required this.when,
    required this.title,
    required this.body,
    required this.priority,
  });
}

abstract final class NotificationPlanner {
  static List<PlannedNotification> build(
    Iterable<Subscription> subscriptions, {
    required DateTime now,
    bool privateContent = true,
    int limit = 60,
  }) {
    final planned = <PlannedNotification>[];
    for (final subscription in subscriptions) {
      if (subscription.isPaused || subscription.isCompleted(now)) continue;
      final trial = subscription.trialEndDate;
      if (trial != null) {
        final when = DateTime(trial.year, trial.month, trial.day - 2, 10);
        if (when.isAfter(now)) {
          planned.add(PlannedNotification(
            when: when,
            title: privateContent
                ? 'تجربة مجانية تنتهي قريبًا'
                : 'تجربة ${subscription.name} تنتهي قريبًا',
            body: privateContent
                ? 'راجع التجربة قبل تحولها إلى اشتراك مدفوع.'
                : 'راجعها قبل ${trial.year}/${trial.month}/${trial.day}.',
            priority: 120,
          ));
        }
      }
      if (!subscription.autoRenews) continue;
      final renewal = subscription.nextRenewal(now);
      final leadDays = subscription.reminderDays > 0
          ? subscription.reminderDays
          : (subscription.cycle == BillingCycle.yearly ? 7 : 3);
      final when = DateTime(
        renewal.year,
        renewal.month,
        renewal.day - leadDays,
        10,
      );
      if (!when.isAfter(now)) continue;
      planned.add(PlannedNotification(
        when: when,
        title: privateContent
            ? 'اشتراك سيتجدد قريبًا'
            : 'تجديد قريب: ${subscription.name}',
        body: privateContent
            ? 'راجع اشتراكاتك قبل موعد الخصم.'
            : 'سيُخصم ${fmtMoney(subscription.price, subscription.currency)} بعد $leadDays ${leadDays == 1 ? 'يوم' : 'أيام'}.',
        priority: 70 +
            (subscription.isEssential ? 10 : 0) +
            (subscription.cycle == BillingCycle.yearly ? 8 : 0),
      ));
    }
    planned.sort((a, b) {
      final date = a.when.compareTo(b.when);
      return date != 0 ? date : b.priority.compareTo(a.priority);
    });
    return planned.take(limit.clamp(0, 60).toInt()).toList(growable: false);
  }
}
