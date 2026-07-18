import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/financial_distribution.dart';

void main() {
  group('FinancialDistribution', () {
    test('groups categories below three percent and preserves details', () {
      final result = FinancialDistribution.calculate(const [
        MapEntry('A', 50),
        MapEntry('B', 47),
        MapEntry('C', 2),
        MapEntry('D', 1),
      ]);

      expect(result.total, 100);
      expect(result.slices.map((item) => item.category), ['A', 'B', 'أخرى']);
      expect(
        result.slices.fold<int>(0, (sum, item) => sum + item.percentage),
        100,
      );
      final other = result.slices.last;
      expect(other.amount, 3);
      expect(other.percentage, 3);
      expect(other.isExpandable, isTrue);
      expect(other.groupedEntries.map((item) => item.category), ['C', 'D']);
      expect(result.expandedEntries, hasLength(4));
    });

    test('merges an existing Other category with grouped small categories', () {
      final result = FinancialDistribution.calculate(const [
        MapEntry('Primary', 94),
        MapEntry('أخرى', 4),
        MapEntry('Tiny', 2),
      ]);

      expect(result.slices, hasLength(2));
      final other = result.slices.last;
      expect(other.category, 'أخرى');
      expect(other.amount, 6);
      expect(other.percentage, 6);
      expect(other.groupedEntries.map((item) => item.category), [
        'أخرى',
        'Tiny',
      ]);
    });

    test('largest-remainder rounding sums to 100 deterministically', () {
      final result = FinancialDistribution.calculate(const [
        MapEntry('First', 1),
        MapEntry('Second', 1),
        MapEntry('Third', 1),
      ]);

      expect(result.slices.map((item) => item.category), [
        'First',
        'Second',
        'Third',
      ]);
      expect(result.slices.map((item) => item.percentage), [34, 33, 33]);
      expect(
        result.expandedEntries.fold<int>(
          0,
          (sum, item) => sum + item.percentage,
        ),
        100,
      );
    });

    test(
      'merges duplicate names and excludes nonpositive or invalid values',
      () {
        final result = FinancialDistribution.calculate([
          const MapEntry('B', 10),
          const MapEntry('A', 10),
          const MapEntry('B', 5),
          const MapEntry('zero', 0),
          const MapEntry('negative', -1),
          const MapEntry('nan', double.nan),
          const MapEntry('infinite', double.infinity),
        ]);

        expect(result.total, 25);
        expect(result.slices.map((item) => item.category), ['B', 'A']);
        expect(result.slices.map((item) => item.amount), [15, 10]);
        expect(result.slices.map((item) => item.percentage), [60, 40]);
        expect(result.sourceCategoryCount, 2);
      },
    );

    test('does not group a category at exactly the three-percent boundary', () {
      final result = FinancialDistribution.calculate(const [
        MapEntry('Large', 97),
        MapEntry('Boundary', 3),
      ]);

      expect(result.slices.map((item) => item.category), ['Large', 'Boundary']);
      expect(result.hasExpandableOther, isFalse);
    });

    test('keeps equal-value ordering stable by first source occurrence', () {
      final result = FinancialDistribution.calculate(const [
        MapEntry('Second alphabetically', 10),
        MapEntry('First alphabetically', 10),
      ]);

      expect(result.slices.map((item) => item.category), [
        'Second alphabetically',
        'First alphabetically',
      ]);
    });

    test('rejects an invalid grouping threshold', () {
      expect(
        () => FinancialDistribution.calculate(const [
          MapEntry('A', 1),
        ], groupingThresholdPercent: 100),
        throwsArgumentError,
      );
    });
  });
}
