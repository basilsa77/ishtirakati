enum SpendingPointStatus { actual, estimated, noData }

class SpendingPoint {
  final DateTime month;
  final double? amount;
  final SpendingPointStatus status;

  const SpendingPoint._({
    required this.month,
    required this.amount,
    required this.status,
  });

  factory SpendingPoint.actual({
    required DateTime month,
    required double amount,
  }) => SpendingPoint._(
    month: _month(month),
    amount: _validAmount(amount),
    status: SpendingPointStatus.actual,
  );

  factory SpendingPoint.estimated({
    required DateTime month,
    required double amount,
  }) => SpendingPoint._(
    month: _month(month),
    amount: _validAmount(amount),
    status: SpendingPointStatus.estimated,
  );

  factory SpendingPoint.noData({required DateTime month}) => SpendingPoint._(
    month: _month(month),
    amount: null,
    status: SpendingPointStatus.noData,
  );

  bool get hasAmount => amount != null;

  static DateTime _month(DateTime value) => DateTime(value.year, value.month);

  static double _validAmount(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'amount',
        'Must be finite and non-negative',
      );
    }
    return value;
  }
}

abstract final class SpendingHistory {
  static List<SpendingPoint> unavailable({
    required DateTime now,
    int months = 6,
  }) {
    if (months < 1) {
      throw ArgumentError.value(months, 'months', 'Must be positive');
    }
    final current = DateTime(now.year, now.month);
    return List<SpendingPoint>.generate(
      months,
      (index) => SpendingPoint.noData(
        month: DateTime(current.year, current.month - (months - index - 1)),
      ),
      growable: false,
    );
  }

  static double? actualAverage(Iterable<SpendingPoint> points) {
    final actual = points
        .where(
          (point) =>
              point.status == SpendingPointStatus.actual && point.hasAmount,
        )
        .map((point) => point.amount!)
        .toList(growable: false);
    if (actual.isEmpty) return null;
    return actual.reduce((sum, value) => sum + value) / actual.length;
  }
}
