import 'dart:collection';

import '../models/subscription.dart';

/// A single payment occurrence inside a rolling renewal window.
class RenewalOccurrence {
  final Subscription subscription;
  final DateTime date;
  final double amount;

  const RenewalOccurrence({
    required this.subscription,
    required this.date,
    required this.amount,
  });

  String get currency => subscription.currency;
}

/// Immutable result for the local, rolling 30-day renewal window.
class RenewalWindowSummary {
  final DateTime start;
  final DateTime endExclusive;
  final List<RenewalOccurrence> _occurrences;
  final Map<String, double> _totalsByCurrency;
  final List<Subscription> _subscriptions;

  RenewalWindowSummary._({
    required this.start,
    required this.endExclusive,
    required List<RenewalOccurrence> occurrences,
    required Map<String, double> totalsByCurrency,
    required List<Subscription> subscriptions,
  }) : _occurrences = List<RenewalOccurrence>.unmodifiable(occurrences),
       _totalsByCurrency = Map<String, double>.unmodifiable(totalsByCurrency),
       _subscriptions = List<Subscription>.unmodifiable(subscriptions);

  List<RenewalOccurrence> get occurrences => UnmodifiableListView(_occurrences);

  Map<String, double> get totalsByCurrency =>
      UnmodifiableMapView(_totalsByCurrency);

  /// Every subscription represented in [occurrences], at most once per id.
  List<Subscription> get subscriptions => UnmodifiableListView(_subscriptions);

  int get paymentCount => _occurrences.length;
  int get uniqueSubscriptionCount => _subscriptions.length;
  bool get isEmpty => _occurrences.isEmpty;
}

/// Calculates actual renewal occurrences in the local interval
/// `[start-of-day, start-of-day + 30 calendar days)`.
abstract final class RenewalWindow {
  static const int durationInDays = 30;

  static RenewalWindowSummary calculate(
    Iterable<Subscription> subscriptions, {
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toLocal();
    final start = DateTime(reference.year, reference.month, reference.day);
    final endExclusive = DateTime(
      start.year,
      start.month,
      start.day + durationInDays,
    );
    final dayBeforeStart = DateTime(start.year, start.month, start.day - 1);
    final sourceOrder = <Subscription, int>{};
    final occurrences = <RenewalOccurrence>[];

    var sourceIndex = 0;
    for (final subscription in subscriptions) {
      sourceOrder[subscription] = sourceIndex++;
      if (subscription.isPaused || subscription.isCompleted(dayBeforeStart)) {
        continue;
      }

      final lastInstallment = subscription.lastInstallmentDate;
      if (lastInstallment != null && lastInstallment.isBefore(start)) {
        continue;
      }

      var month = DateTime(start.year, start.month);
      while (month.isBefore(endExclusive)) {
        for (final renewal in subscription.renewalsInMonth(
          month.year,
          month.month,
        )) {
          if (renewal.isBefore(start) || !renewal.isBefore(endExclusive)) {
            continue;
          }
          if (lastInstallment != null && renewal.isAfter(lastInstallment)) {
            continue;
          }
          occurrences.add(
            RenewalOccurrence(
              subscription: subscription,
              date: renewal,
              amount: subscription.priceAt(renewal),
            ),
          );
        }
        month = DateTime(month.year, month.month + 1);
      }
    }

    occurrences.sort((left, right) {
      final byDate = left.date.compareTo(right.date);
      if (byDate != 0) return byDate;
      final bySource = (sourceOrder[left.subscription] ?? 0).compareTo(
        sourceOrder[right.subscription] ?? 0,
      );
      if (bySource != 0) return bySource;
      return left.subscription.id.compareTo(right.subscription.id);
    });

    final totals = <String, double>{};
    final uniqueSubscriptions = <String, Subscription>{};
    for (final occurrence in occurrences) {
      totals.update(
        occurrence.currency,
        (value) => value + occurrence.amount,
        ifAbsent: () => occurrence.amount,
      );
      uniqueSubscriptions.putIfAbsent(
        occurrence.subscription.id,
        () => occurrence.subscription,
      );
    }

    return RenewalWindowSummary._(
      start: start,
      endExclusive: endExclusive,
      occurrences: occurrences,
      totalsByCurrency: totals,
      subscriptions: uniqueSubscriptions.values.toList(growable: false),
    );
  }
}
