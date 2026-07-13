import '../models/subscription.dart';

class MonthlyForecast {
  final DateTime month;
  final double total;
  final int paymentCount;

  const MonthlyForecast({
    required this.month,
    required this.total,
    required this.paymentCount,
  });
}

class DuplicateSubscriptionGroup {
  final String serviceName;
  final List<Subscription> subscriptions;
  final double avoidableMonthlyCost;

  const DuplicateSubscriptionGroup({
    required this.serviceName,
    required this.subscriptions,
    required this.avoidableMonthlyCost,
  });
}

enum FinancialReviewReason {
  duplicate,
  unusedAutoRenewal,
  priceIncrease,
  overdueReview,
}

class FinancialReviewItem {
  final Subscription subscription;
  final FinancialReviewReason reason;
  final int priority;

  const FinancialReviewItem({
    required this.subscription,
    required this.reason,
    required this.priority,
  });
}

class PlanComparison {
  final double currentMonthlyCost;
  final double alternativeMonthlyCost;

  const PlanComparison({
    required this.currentMonthlyCost,
    required this.alternativeMonthlyCost,
  });

  double get monthlyDifference =>
      alternativeMonthlyCost - currentMonthlyCost;
  double get annualDifference => monthlyDifference * 12;
  bool get alternativeSavesMoney => monthlyDifference < 0;
}

class FinancialAssistantSnapshot {
  final String currency;
  final List<MonthlyForecast> forecast;
  final List<DuplicateSubscriptionGroup> duplicateGroups;
  final List<FinancialReviewItem> reviewItems;
  final double potentialMonthlySavings;

  const FinancialAssistantSnapshot({
    required this.currency,
    required this.forecast,
    required this.duplicateGroups,
    required this.reviewItems,
    required this.potentialMonthlySavings,
  });

  double get nextMonthForecast => forecast.isEmpty ? 0 : forecast.first.total;
  double get next12MonthsForecast =>
      forecast.fold(0.0, (sum, item) => sum + item.total);
}

abstract final class FinancialAssistant {
  static FinancialAssistantSnapshot analyze(
    Iterable<Subscription> subscriptions, {
    required String currency,
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final active = subscriptions
        .where((item) =>
            item.currency == currency &&
            !item.isPaused &&
            !item.isCompleted(today))
        .toList();
    final forecast = _forecast(active, today);
    final duplicateGroups = _duplicates(active);
    final duplicateIds = <String>{
      for (final group in duplicateGroups)
        for (final item in group.subscriptions) item.id,
    };
    final reviewItems = <FinancialReviewItem>[];
    final reviewedIds = <String>{};
    final savingsIds = <String>{};
    var savings = 0.0;

    for (final group in duplicateGroups) {
      final sorted = [...group.subscriptions]
        ..sort((a, b) => a.monthlyCost.compareTo(b.monthlyCost));
      for (final item in sorted.skip(1)) {
        reviewItems.add(FinancialReviewItem(
          subscription: item,
          reason: FinancialReviewReason.duplicate,
          priority: 100,
        ));
        reviewedIds.add(item.id);
        if (!item.isEssential && savingsIds.add(item.id)) {
          savings += item.monthlyCost;
        }
      }
    }

    for (final item in active) {
      if (item.isEssential) continue;
      if (reviewedIds.contains(item.id)) continue;
      if (item.usageCount == 0 && item.autoRenews) {
        reviewItems.add(FinancialReviewItem(
          subscription: item,
          reason: FinancialReviewReason.unusedAutoRenewal,
          priority: 90 - item.daysUntilRenewal(today).clamp(0, 30).toInt(),
        ));
        if (savingsIds.add(item.id)) savings += item.monthlyCost;
        continue;
      }
      final increase = item.priceChangePercent;
      if (increase != null && increase >= 10) {
        reviewItems.add(FinancialReviewItem(
          subscription: item,
          reason: FinancialReviewReason.priceIncrease,
          priority: 70 + increase.clamp(0, 25).round(),
        ));
        continue;
      }
      final reviewedAt = item.lastReviewedAt;
      if (item.autoRenews &&
          !duplicateIds.contains(item.id) &&
          (reviewedAt == null || today.difference(_day(reviewedAt)).inDays >= 180)) {
        reviewItems.add(FinancialReviewItem(
          subscription: item,
          reason: FinancialReviewReason.overdueReview,
          priority: 45,
        ));
      }
    }
    reviewItems.sort((a, b) => b.priority.compareTo(a.priority));

    return FinancialAssistantSnapshot(
      currency: currency,
      forecast: forecast,
      duplicateGroups: duplicateGroups,
      reviewItems: reviewItems,
      potentialMonthlySavings: savings,
    );
  }

  static PlanComparison comparePlans(
    Subscription current, {
    required double alternativePrice,
    required BillingCycle alternativeCycle,
  }) {
    final alternativeMonthly =
        alternativePrice * alternativeCycle.cyclesPerYear / 12;
    return PlanComparison(
      currentMonthlyCost: current.monthlyCost,
      alternativeMonthlyCost: alternativeMonthly,
    );
  }

  static List<MonthlyForecast> _forecast(
    List<Subscription> active,
    DateTime today,
  ) {
    return List.generate(12, (index) {
      final month = Subscription.addMonths(DateTime(today.year, today.month), index);
      var total = 0.0;
      var count = 0;
      for (final item in active) {
        for (final renewal in item.renewalsInMonth(month.year, month.month)) {
          if (renewal.isBefore(today)) continue;
          final lastInstallment = item.lastInstallmentDate;
          if (lastInstallment != null && renewal.isAfter(lastInstallment)) continue;
          total += item.price;
          count += 1;
        }
      }
      return MonthlyForecast(month: month, total: total, paymentCount: count);
    });
  }

  static List<DuplicateSubscriptionGroup> _duplicates(
    List<Subscription> active,
  ) {
    final grouped = <String, List<Subscription>>{};
    for (final item in active) {
      final key = _serviceKey(item);
      if (key.length < 3) continue;
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final output = <DuplicateSubscriptionGroup>[];
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;
      final sorted = [...entry.value]
        ..sort((a, b) => a.monthlyCost.compareTo(b.monthlyCost));
      output.add(DuplicateSubscriptionGroup(
        serviceName: sorted.first.name,
        subscriptions: sorted,
        avoidableMonthlyCost:
            sorted.skip(1).fold(0.0, (sum, item) => sum + item.monthlyCost),
      ));
    }
    output.sort((a, b) =>
        b.avoidableMonthlyCost.compareTo(a.avoidableMonthlyCost));
    return output;
  }

  static String _serviceKey(Subscription item) {
    final uri = Uri.tryParse(item.manageUrl);
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (host != null && host.isNotEmpty) return host;
    const ignored = {
      'pro', 'plus', 'premium', 'basic', 'family', 'monthly', 'yearly',
      'احترافي', 'برو', 'بلس', 'عائلي', 'شهري', 'سنوي', 'الخطة', 'اشتراك',
    };
    final normalized = item.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
        .trim();
    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !ignored.contains(token))
        .join(' ');
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
