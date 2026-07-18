import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/renewal_intelligence.dart';

Subscription _sub({
  required String id,
  required DateTime anchor,
  double price = 100,
  String currency = 'SAR',
  bool paused = false,
  int usage = 0,
  DateTime? trialEnd,
  List<PriceChange>? history,
}) {
  return Subscription(
    id: id,
    name: 'خدمة $id',
    emoji: '🔖',
    price: price,
    currency: currency,
    cycle: BillingCycle.monthly,
    anchorDate: anchor,
    category: 'أخرى',
    isPaused: paused,
    usageCount: usage,
    trialEndDate: trialEnd,
    priceHistory: history,
  );
}

void main() {
  final now = DateTime(2026, 7, 10);

  test('اللقطة تفصل المبالغ حسب العملة وتتجاهل المتوقف', () {
    final snapshot = RenewalIntelligence.snapshot(
      [
        _sub(id: 'a', anchor: DateTime(2026, 6, 12), price: 20),
        _sub(id: 'b', anchor: DateTime(2026, 6, 15), price: 30),
        _sub(
          id: 'usd',
          anchor: DateTime(2026, 6, 11),
          price: 9,
          currency: 'USD',
        ),
        _sub(id: 'paused', anchor: DateTime(2026, 6, 11), paused: true),
      ],
      currency: 'SAR',
      now: now,
    );

    expect(snapshot.activeCount, 3);
    expect(snapshot.dueIn7Days, 3);
    expect(snapshot.amountIn7Days, 50);
    expect(snapshot.monthlyCommitment, 50);
  });

  test('التجربة القريبة تتقدم ولا يتكرر الاشتراك في قائمة القرار', () {
    final trial = _sub(
      id: 'trial',
      anchor: DateTime(2026, 6, 11),
      trialEnd: DateTime(2026, 7, 12),
    );
    final decisions = RenewalIntelligence.decisions([trial], now: now);
    expect(decisions, hasLength(1));
    expect(decisions.single.kind, DecisionKind.trialEnding);
    expect(decisions.single.priority, DecisionPriority.urgent);
  });

  test('ارتفاع السعر يظهر بعد حالات التجديد العاجلة', () {
    final urgent = _sub(id: 'urgent', anchor: DateTime(2026, 6, 11));
    final increased = _sub(
      id: 'increase',
      anchor: DateTime(2026, 6, 25),
      price: 130,
      usage: 4,
      history: [PriceChange(oldPrice: 100, changedAt: DateTime(2026, 7, 1))],
    );
    final decisions = RenewalIntelligence.decisions([
      increased,
      urgent,
    ], now: now);
    expect(decisions.first.subscription.id, 'urgent');
    expect(decisions.last.kind, DecisionKind.priceIncrease);
  });

  test('لا يقترح مراجعة الاشتراكات المتوقفة', () {
    final decisions = RenewalIntelligence.decisions([
      _sub(id: 'paused', anchor: DateTime(2026, 6, 11), paused: true),
    ], now: now);
    expect(decisions, isEmpty);
  });
}
