/// Pure, deterministic migrations for records created by older releases.
abstract final class SubscriptionSchema {
  static const currentVersion = 12;

  static Map<String, dynamic> migrateToV12(Map<String, dynamic> source) {
    final record = Map<String, dynamic>.from(source);
    final version = (record['schemaVersion'] as num?)?.toInt() ?? 11;
    if (version > currentVersion) return record;

    record.putIfAbsent('kind', () => 0);
    record.putIfAbsent('isFamily', () => false);
    record.putIfAbsent('familyMembers', () => 2);
    record.putIfAbsent('usageCount', () => 0);
    record.putIfAbsent('reminderDays', () => 3);
    record.putIfAbsent('iconUrl', () => '');
    record.putIfAbsent('priceHistory', () => <Object>[]);
    record['schemaVersion'] = currentVersion;
    return record;
  }
}

