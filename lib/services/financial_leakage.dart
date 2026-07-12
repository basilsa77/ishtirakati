import '../models/subscription.dart';

class FinancialLeakageSnapshot {
  final String currency;
  final double monthlyCommitment;
  final double annualCommitment;
  final double unusedAnnualExposure;
  final double familyMonthlyShare;
  final Subscription? mostExpensive;
  final List<Subscription> unused;

  const FinancialLeakageSnapshot({
    required this.currency,
    required this.monthlyCommitment,
    required this.annualCommitment,
    required this.unusedAnnualExposure,
    required this.familyMonthlyShare,
    required this.mostExpensive,
    required this.unused,
  });

  double get leakageRatio => annualCommitment <= 0
      ? 0
      : (unusedAnnualExposure / annualCommitment).clamp(0, 1);
}

abstract final class FinancialLeakage {
  static FinancialLeakageSnapshot calculate(
    Iterable<Subscription> subscriptions, {
    required String currency,
  }) {
    final active = subscriptions
        .where((item) =>
            item.currency == currency && !item.isPaused && !item.isCompleted())
        .toList();
    final unused = active.where((item) => item.usageCount == 0).toList()
      ..sort((a, b) => b.yearlyCost.compareTo(a.yearlyCost));
    final sorted = [...active]
      ..sort((a, b) => b.yearlyCost.compareTo(a.yearlyCost));

    return FinancialLeakageSnapshot(
      currency: currency,
      monthlyCommitment:
          active.fold(0, (total, item) => total + item.monthlyCost),
      annualCommitment:
          active.fold(0, (total, item) => total + item.yearlyCost),
      unusedAnnualExposure:
          unused.fold(0, (total, item) => total + item.yearlyCost),
      familyMonthlyShare: active
          .where((item) => item.isFamily)
          .fold(0, (total, item) => total + item.pricePerMember),
      mostExpensive: sorted.isEmpty ? null : sorted.first,
      unused: unused,
    );
  }
}
