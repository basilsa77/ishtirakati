import 'dart:collection';
import 'dart:math' as math;

/// A category amount and its integer share of the whole distribution.
class FinancialDistributionEntry {
  final String category;
  final double amount;
  final int percentage;

  const FinancialDistributionEntry({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

/// A visible donut/legend slice. Aggregated slices retain their source entries
/// so the UI can expand "Other" without losing information.
class FinancialDistributionSlice extends FinancialDistributionEntry {
  final bool isAggregate;
  final List<FinancialDistributionEntry> _groupedEntries;

  FinancialDistributionSlice({
    required super.category,
    required super.amount,
    required super.percentage,
    this.isAggregate = false,
    List<FinancialDistributionEntry> groupedEntries = const [],
  }) : _groupedEntries = List<FinancialDistributionEntry>.unmodifiable(
         groupedEntries,
       );

  List<FinancialDistributionEntry> get groupedEntries =>
      UnmodifiableListView(_groupedEntries);

  bool get isExpandable => isAggregate && _groupedEntries.isNotEmpty;
}

class FinancialDistributionResult {
  final double total;
  final List<FinancialDistributionSlice> _slices;
  final List<FinancialDistributionEntry> _expandedEntries;

  FinancialDistributionResult._({
    required this.total,
    required List<FinancialDistributionSlice> slices,
    required List<FinancialDistributionEntry> expandedEntries,
  }) : _slices = List<FinancialDistributionSlice>.unmodifiable(slices),
       _expandedEntries = List<FinancialDistributionEntry>.unmodifiable(
         expandedEntries,
       );

  List<FinancialDistributionSlice> get slices => UnmodifiableListView(_slices);

  /// All positive source categories after duplicate names have been merged.
  List<FinancialDistributionEntry> get expandedEntries =>
      UnmodifiableListView(_expandedEntries);

  int get sourceCategoryCount => _expandedEntries.length;
  int get visibleCategoryCount => _slices.length;
  bool get hasExpandableOther => _slices.any((slice) => slice.isExpandable);
  bool get isEmpty => _slices.isEmpty;
}

/// Builds deterministic, testable financial distribution data for charts.
abstract final class FinancialDistribution {
  static const String defaultOtherCategory = 'أخرى';
  static const double defaultGroupingThresholdPercent = 3;

  static FinancialDistributionResult calculate(
    Iterable<MapEntry<String, double>> entries, {
    String otherCategory = defaultOtherCategory,
    double groupingThresholdPercent = defaultGroupingThresholdPercent,
  }) {
    if (!groupingThresholdPercent.isFinite ||
        groupingThresholdPercent < 0 ||
        groupingThresholdPercent >= 100) {
      throw ArgumentError.value(
        groupingThresholdPercent,
        'groupingThresholdPercent',
        'Must be finite and in the interval [0, 100).',
      );
    }

    final amounts = <String, double>{};
    final firstSeen = <String, int>{};
    var inputIndex = 0;
    for (final entry in entries) {
      if (!entry.value.isFinite || entry.value <= 0) {
        inputIndex += 1;
        continue;
      }
      firstSeen.putIfAbsent(entry.key, () => inputIndex);
      amounts.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
      inputIndex += 1;
    }

    final total = amounts.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0 || !total.isFinite) {
      return FinancialDistributionResult._(
        total: 0,
        slices: const [],
        expandedEntries: const [],
      );
    }

    final ranked = <_RankedEntry>[
      for (final entry in amounts.entries)
        _RankedEntry(
          category: entry.key,
          amount: entry.value,
          sourceIndex: firstSeen[entry.key] ?? 0,
          rawPercentage: entry.value / total * 100,
        ),
    ]..sort(_compareRanked);

    _assignLargestRemainderPercentages(ranked);
    final expandedEntries = <FinancialDistributionEntry>[
      for (final entry in ranked)
        FinancialDistributionEntry(
          category: entry.category,
          amount: entry.amount,
          percentage: entry.percentage,
        ),
    ];

    final regular = <_RankedEntry>[];
    final grouped = <_RankedEntry>[];
    var groupedSmallCategory = false;
    for (final entry in ranked) {
      final isOther = entry.category == otherCategory;
      final isSmall = entry.rawPercentage < groupingThresholdPercent;
      if (isOther || isSmall) {
        grouped.add(entry);
        groupedSmallCategory |= !isOther && isSmall;
      } else {
        regular.add(entry);
      }
    }

    final slices = <FinancialDistributionSlice>[
      for (final entry in regular)
        FinancialDistributionSlice(
          category: entry.category,
          amount: entry.amount,
          percentage: entry.percentage,
        ),
    ];
    if (grouped.isNotEmpty) {
      grouped.sort(_compareRanked);
      final groupedEntries = <FinancialDistributionEntry>[
        for (final entry in grouped)
          FinancialDistributionEntry(
            category: entry.category,
            amount: entry.amount,
            percentage: entry.percentage,
          ),
      ];
      slices.add(
        FinancialDistributionSlice(
          category: otherCategory,
          amount: grouped.fold<double>(0, (sum, entry) => sum + entry.amount),
          percentage: grouped.fold<int>(
            0,
            (sum, entry) => sum + entry.percentage,
          ),
          isAggregate: groupedSmallCategory,
          groupedEntries: groupedSmallCategory ? groupedEntries : const [],
        ),
      );
    }

    return FinancialDistributionResult._(
      total: total,
      slices: slices,
      expandedEntries: expandedEntries,
    );
  }

  static int _compareRanked(_RankedEntry left, _RankedEntry right) {
    final byAmount = right.amount.compareTo(left.amount);
    if (byAmount != 0) return byAmount;
    final bySource = left.sourceIndex.compareTo(right.sourceIndex);
    if (bySource != 0) return bySource;
    return left.category.compareTo(right.category);
  }

  static void _assignLargestRemainderPercentages(List<_RankedEntry> entries) {
    var assigned = 0;
    for (final entry in entries) {
      entry.percentage = entry.rawPercentage.floor();
      assigned += entry.percentage;
    }

    final remainderOrder = [...entries]..sort((left, right) {
      final leftRemainder = left.rawPercentage - left.rawPercentage.floor();
      final rightRemainder = right.rawPercentage - right.rawPercentage.floor();
      final byRemainder = rightRemainder.compareTo(leftRemainder);
      if (byRemainder != 0) return byRemainder;
      return _compareRanked(left, right);
    });
    final remaining = math.max(0, 100 - assigned);
    for (var index = 0; index < remaining; index += 1) {
      remainderOrder[index % remainderOrder.length].percentage += 1;
    }
  }
}

class _RankedEntry {
  final String category;
  final double amount;
  final int sourceIndex;
  final double rawPercentage;
  int percentage = 0;

  _RankedEntry({
    required this.category,
    required this.amount,
    required this.sourceIndex,
    required this.rawPercentage,
  });
}
