import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/renewal_window.dart';

Subscription _subscription({
  required String id,
  required DateTime anchor,
  BillingCycle cycle = BillingCycle.monthly,
  double price = 10,
  String currency = 'SAR',
  bool isPaused = false,
  int? installments,
  List<PriceChange>? priceHistory,
}) {
  return Subscription(
    id: id,
    name: id,
    emoji: 'S',
    price: price,
    currency: currency,
    cycle: cycle,
    anchorDate: anchor,
    category: 'أخرى',
    isPaused: isPaused,
    kind:
        installments == null
            ? PaymentKind.subscription
            : PaymentKind.installment,
    totalInstallments: installments,
    priceHistory: priceHistory,
  );
}

void main() {
  group('RenewalWindow', () {
    test('uses the local half-open 30-calendar-day interval', () {
      final result = RenewalWindow.calculate([
        _subscription(
          id: 'at-start',
          anchor: DateTime(2025, 7, 1),
          cycle: BillingCycle.yearly,
        ),
        _subscription(
          id: 'at-end',
          anchor: DateTime(2025, 7, 31),
          cycle: BillingCycle.yearly,
        ),
      ], now: DateTime(2026, 7, 1, 23, 59, 59));

      expect(result.start, DateTime(2026, 7, 1));
      expect(result.endExclusive, DateTime(2026, 7, 31));
      expect(result.occurrences.map((item) => item.subscription.id), [
        'at-start',
      ]);
    });

    test('counts four and five weekly payments by their actual dates', () {
      final result = RenewalWindow.calculate([
        _subscription(
          id: 'five-weekly',
          anchor: DateTime(2026, 7, 1),
          cycle: BillingCycle.weekly,
        ),
        _subscription(
          id: 'four-weekly',
          anchor: DateTime(2026, 7, 3),
          cycle: BillingCycle.weekly,
        ),
      ], now: DateTime(2026, 7, 1));

      final bySubscription = <String, int>{};
      for (final occurrence in result.occurrences) {
        bySubscription.update(
          occurrence.subscription.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      expect(bySubscription, {'five-weekly': 5, 'four-weekly': 4});
      expect(result.paymentCount, 9);
      expect(result.uniqueSubscriptionCount, 2);
      expect(result.paymentCount, isNot(result.uniqueSubscriptionCount));
    });

    test('supports monthly, quarterly, and yearly occurrences', () {
      final result = RenewalWindow.calculate([
        _subscription(id: 'monthly', anchor: DateTime(2026, 6, 9)),
        _subscription(
          id: 'quarterly',
          anchor: DateTime(2026, 4, 10),
          cycle: BillingCycle.quarterly,
        ),
        _subscription(
          id: 'yearly',
          anchor: DateTime(2025, 7, 11),
          cycle: BillingCycle.yearly,
        ),
      ], now: DateTime(2026, 7, 1));

      expect(
        result.occurrences
            .map((item) => (item.subscription.id, item.date))
            .toList(),
        [
          ('monthly', DateTime(2026, 7, 9)),
          ('quarterly', DateTime(2026, 7, 10)),
          ('yearly', DateTime(2026, 7, 11)),
        ],
      );
    });

    test('excludes paused and already completed finite installments', () {
      final result = RenewalWindow.calculate([
        _subscription(
          id: 'paused',
          anchor: DateTime(2026, 7, 2),
          isPaused: true,
        ),
        _subscription(
          id: 'completed-before-window',
          anchor: DateTime(2026, 5, 1),
          installments: 2,
        ),
        _subscription(
          id: 'final-payment-on-start',
          anchor: DateTime(2026, 6, 1),
          installments: 2,
        ),
      ], now: DateTime(2026, 7, 1));

      expect(result.occurrences, hasLength(1));
      expect(
        result.occurrences.single.subscription.id,
        'final-payment-on-start',
      );
      expect(result.occurrences.single.date, DateTime(2026, 7, 1));
    });

    test('uses occurrence prices and keeps currency totals separate', () {
      final result = RenewalWindow.calculate([
        _subscription(
          id: 'weekly-sar',
          anchor: DateTime(2026, 7, 1),
          cycle: BillingCycle.weekly,
          price: 20,
          priceHistory: [
            PriceChange(oldPrice: 10, changedAt: DateTime(2026, 7, 15)),
          ],
        ),
        _subscription(
          id: 'monthly-usd',
          anchor: DateTime(2026, 7, 10),
          price: 7.5,
          currency: 'USD',
        ),
      ], now: DateTime(2026, 7, 1));

      expect(result.paymentCount, 6);
      expect(result.uniqueSubscriptionCount, 2);
      expect(result.totalsByCurrency['SAR'], 80);
      expect(result.totalsByCurrency['USD'], 7.5);
      expect(
        result.occurrences
            .where((item) => item.currency == 'SAR')
            .map((item) => item.amount),
        [10, 10, 20, 20, 20],
      );
    });
  });
}
