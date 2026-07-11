/// Local-only renewal intelligence used by the v11 decision center.
library;

import '../models/subscription.dart';

enum DecisionKind { trialEnding, renewalSoon, priceIncrease, neverUsed }

enum DecisionPriority { urgent, high, normal }

class DecisionInsight {
  final Subscription subscription;
  final DecisionKind kind;
  final DecisionPriority priority;
  final String title;
  final String detail;
  final int score;

  const DecisionInsight({
    required this.subscription,
    required this.kind,
    required this.priority,
    required this.title,
    required this.detail,
    required this.score,
  });
}

class RenewalSnapshot {
  final String currency;
  final int activeCount;
  final int dueIn7Days;
  final int dueIn30Days;
  final int trialsEndingSoon;
  final double amountIn7Days;
  final double amountIn30Days;
  final double monthlyCommitment;

  const RenewalSnapshot({
    required this.currency,
    required this.activeCount,
    required this.dueIn7Days,
    required this.dueIn30Days,
    required this.trialsEndingSoon,
    required this.amountIn7Days,
    required this.amountIn30Days,
    required this.monthlyCommitment,
  });
}

class RenewalIntelligence {
  RenewalIntelligence._();

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static RenewalSnapshot snapshot(
    List<Subscription> subscriptions, {
    required String currency,
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final active = subscriptions
        .where((item) => !item.isPaused && !item.isCompleted(today))
        .toList();
    var due7 = 0;
    var due30 = 0;
    var trials = 0;
    var amount7 = 0.0;
    var amount30 = 0.0;
    var monthly = 0.0;

    for (final item in active) {
      if (item.currency == currency) monthly += item.monthlyCost;
      final days = item.daysUntilRenewal(today);
      if (days >= 0 && days <= 30) {
        due30 += 1;
        if (item.currency == currency) amount30 += item.price;
      }
      if (days >= 0 && days <= 7) {
        due7 += 1;
        if (item.currency == currency) amount7 += item.price;
      }
      final trialEnd = item.trialEndDate;
      if (trialEnd != null) {
        final remaining = _day(trialEnd).difference(today).inDays;
        if (remaining >= 0 && remaining <= 7) trials += 1;
      }
    }

    return RenewalSnapshot(
      currency: currency,
      activeCount: active.length,
      dueIn7Days: due7,
      dueIn30Days: due30,
      trialsEndingSoon: trials,
      amountIn7Days: amount7,
      amountIn30Days: amount30,
      monthlyCommitment: monthly,
    );
  }

  /// Returns at most one highest-value decision per subscription.
  static List<DecisionInsight> decisions(
    List<Subscription> subscriptions, {
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final output = <DecisionInsight>[];

    for (final item in subscriptions) {
      if (item.isPaused || item.isCompleted(today)) continue;
      final trialEnd = item.trialEndDate;
      if (trialEnd != null) {
        final days = _day(trialEnd).difference(today).inDays;
        if (days >= 0 && days <= 7) {
          output.add(DecisionInsight(
            subscription: item,
            kind: DecisionKind.trialEnding,
            priority: days <= 2
                ? DecisionPriority.urgent
                : DecisionPriority.high,
            title: days == 0
                ? 'تنتهي تجربة ${item.name} اليوم'
                : 'تجربة ${item.name} تنتهي خلال $days أيام',
            detail: 'راجع قرار الاستمرار قبل بدء الخصم التلقائي.',
            score: 110 - days,
          ));
          continue;
        }
      }

      final renewalDays = item.daysUntilRenewal(today);
      if (renewalDays >= 0 && renewalDays <= 3 && item.usageCount == 0) {
        output.add(DecisionInsight(
          subscription: item,
          kind: DecisionKind.renewalSoon,
          priority: DecisionPriority.urgent,
          title: '${item.name} يتجدد قريبًا بلا استخدام مسجل',
          detail: 'راجع حاجتك للخدمة قبل موعد الخصم.',
          score: 100 - renewalDays,
        ));
        continue;
      }

      final increase = item.priceChangePercent;
      if (increase != null && increase >= 10) {
        output.add(DecisionInsight(
          subscription: item,
          kind: DecisionKind.priceIncrease,
          priority: increase >= 25
              ? DecisionPriority.high
              : DecisionPriority.normal,
          title: 'ارتفع سعر ${item.name} بنسبة ${increase.round()}٪',
          detail: 'قارن الباقة الحالية بالبدائل قبل التجديد القادم.',
          score: 70 + increase.clamp(0, 24).round(),
        ));
        continue;
      }

      if (item.usageCount == 0) {
        output.add(DecisionInsight(
          subscription: item,
          kind: DecisionKind.neverUsed,
          priority: DecisionPriority.normal,
          title: '${item.name} بلا استخدام مسجل',
          detail: 'سجل استخدامك أو راجع جدوى الاستمرار.',
          score: 50 + item.monthlyCost.clamp(0, 40).round(),
        ));
      }
    }

    output.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.subscription.name.compareTo(b.subscription.name);
    });
    return output;
  }
}
