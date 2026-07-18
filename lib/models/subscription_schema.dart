/// Pure, deterministic migrations for records created by older releases.
abstract final class SubscriptionSchema {
  static const currentVersion = 14;

  static Map<String, dynamic> migrateToV12(Map<String, dynamic> source) {
    final record = Map<String, dynamic>.from(source);
    final version = (record['schemaVersion'] as num?)?.toInt() ?? 11;
    if (version > 12) return record;

    record.putIfAbsent('kind', () => 0);
    record.putIfAbsent('isFamily', () => false);
    record.putIfAbsent('familyMembers', () => 2);
    record.putIfAbsent('usageCount', () => 0);
    record.putIfAbsent('reminderDays', () => 3);
    record.putIfAbsent('iconUrl', () => '');
    record.putIfAbsent('priceHistory', () => <Object>[]);
    record['schemaVersion'] = 12;
    return record;
  }

  static Map<String, dynamic> migrateToV13(Map<String, dynamic> source) {
    final sourceVersion = (source['schemaVersion'] as num?)?.toInt() ?? 11;
    if (sourceVersion > 13) {
      return Map<String, dynamic>.from(source);
    }

    final record =
        sourceVersion <= 12
            ? migrateToV12(source)
            : Map<String, dynamic>.from(source);
    record.putIfAbsent('autoRenews', () => true);
    record.putIfAbsent('isEssential', () => false);
    record.putIfAbsent('planName', () => '');
    record.putIfAbsent('lastReviewedAt', () => null);
    record['schemaVersion'] = 13;
    return record;
  }

  /// Adds local duplicate-review metadata without changing any existing field.
  ///
  /// The metadata remains inside the already encrypted subscription payload, so
  /// v13 records migrate safely and future-version records remain untouched.
  static Map<String, dynamic> migrateToV14(Map<String, dynamic> source) {
    final sourceVersion = (source['schemaVersion'] as num?)?.toInt() ?? 11;
    if (sourceVersion > currentVersion) {
      return Map<String, dynamic>.from(source);
    }

    final record =
        sourceVersion <= 13
            ? migrateToV13(source)
            : Map<String, dynamic>.from(source);
    record.putIfAbsent('ignoredDuplicateGroupKeys', () => <Object>[]);
    record['schemaVersion'] = currentVersion;
    return record;
  }
}
