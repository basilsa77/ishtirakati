import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/spending_history.dart';

void main() {
  test('distinguishes actual zero, no data, and an actual amount', () {
    final month = DateTime(2026, 7, 18, 23, 59);
    final actualZero = SpendingPoint.actual(month: month, amount: 0);
    final noData = SpendingPoint.noData(month: month);
    final actualAmount = SpendingPoint.actual(month: month, amount: 125.5);

    expect(actualZero.status, SpendingPointStatus.actual);
    expect(actualZero.amount, 0);
    expect(actualZero.hasAmount, isTrue);
    expect(noData.status, SpendingPointStatus.noData);
    expect(noData.amount, isNull);
    expect(noData.hasAmount, isFalse);
    expect(actualAmount.status, SpendingPointStatus.actual);
    expect(actualAmount.amount, 125.5);
  });

  test('actual averages exclude no-data and estimated months', () {
    final points = <SpendingPoint>[
      SpendingPoint.noData(month: DateTime(2026, 4)),
      SpendingPoint.estimated(month: DateTime(2026, 5), amount: 500),
      SpendingPoint.actual(month: DateTime(2026, 6), amount: 0),
      SpendingPoint.actual(month: DateTime(2026, 7), amount: 100),
    ];

    expect(SpendingHistory.actualAverage(points), 50);
    expect(
      SpendingHistory.actualAverage([
        SpendingPoint.noData(month: DateTime(2026, 7)),
      ]),
      isNull,
    );
  });

  test('unavailable history contains ordered no-data months only', () {
    final points = SpendingHistory.unavailable(
      now: DateTime(2026, 1, 15, 23, 59),
      months: 3,
    );

    expect(points.map((point) => point.month).toList(), [
      DateTime(2025, 11),
      DateTime(2025, 12),
      DateTime(2026, 1),
    ]);
    expect(
      points.every((point) => point.status == SpendingPointStatus.noData),
      isTrue,
    );
    expect(points.every((point) => point.amount == null), isTrue);
  });

  test('invalid spending values fail closed', () {
    expect(
      () => SpendingPoint.actual(month: DateTime(2026), amount: -1),
      throwsArgumentError,
    );
    expect(
      () => SpendingPoint.estimated(month: DateTime(2026), amount: double.nan),
      throwsArgumentError,
    );
  });
}
