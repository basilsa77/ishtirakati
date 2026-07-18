import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/subscription.dart';

/// One renewal occurrence ready to be grouped for the calendar timeline.
///
/// [occursAt] is converted to the device's local time before its day key is
/// calculated. The amount and currency are captured at occurrence creation so
/// grouping remains deterministic even if the subscription is edited later.
@immutable
class RenewalDayItem {
  final Subscription subscription;
  final DateTime occursAt;
  final double amount;
  final String currency;

  const RenewalDayItem({
    required this.subscription,
    required this.occursAt,
    required this.amount,
    required this.currency,
  });

  DateTime get localOccurrence => occursAt.toLocal();
}

/// All renewal occurrences that fall on the same local calendar day.
@immutable
class RenewalDayGroup {
  final DateTime date;
  final List<RenewalDayItem> items;
  final Map<String, double> totalsByCurrency;

  const RenewalDayGroup._({
    required this.date,
    required this.items,
    required this.totalsByCurrency,
  });

  int get itemCount => items.length;
}

/// Pure local-day grouping used by the renewal timeline.
///
/// Groups are ordered chronologically. Items are ordered by local occurrence
/// time; items with the same instant retain the caller's input order. Currency
/// totals put [preferredCurrency] first, then use currency-code order.
abstract final class RenewalDayGrouping {
  static List<RenewalDayGroup> group(
    Iterable<RenewalDayItem> source, {
    String? preferredCurrency,
  }) {
    final indexed = source.indexed.toList(growable: false);
    indexed.sort((first, second) {
      final dateOrder = first.$2.localOccurrence.compareTo(
        second.$2.localOccurrence,
      );
      return dateOrder != 0 ? dateOrder : first.$1.compareTo(second.$1);
    });

    final grouped = SplayTreeMap<DateTime, List<RenewalDayItem>>();
    for (final (_, item) in indexed) {
      final local = item.localOccurrence;
      final day = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(day, () => <RenewalDayItem>[]).add(item);
    }

    return List<RenewalDayGroup>.unmodifiable(
      grouped.entries.map((entry) {
        final totals = <String, double>{};
        for (final item in entry.value) {
          totals.update(
            item.currency,
            (current) => current + item.amount,
            ifAbsent: () => item.amount,
          );
        }
        final orderedTotals = totals.entries.toList(growable: false)
          ..sort((first, second) {
            if (first.key == preferredCurrency &&
                second.key != preferredCurrency) {
              return -1;
            }
            if (second.key == preferredCurrency &&
                first.key != preferredCurrency) {
              return 1;
            }
            return first.key.compareTo(second.key);
          });
        return RenewalDayGroup._(
          date: entry.key,
          items: List<RenewalDayItem>.unmodifiable(entry.value),
          totalsByCurrency: Map<String, double>.unmodifiable(
            Map<String, double>.fromEntries(orderedTotals),
          ),
        );
      }),
    );
  }
}
