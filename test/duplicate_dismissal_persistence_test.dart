import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/models/subscription_schema.dart';
import 'package:ishtirakati/services/financial_assistant.dart';
import 'package:ishtirakati/services/secure_data_codec.dart';
import 'package:ishtirakati/services/subscription_store.dart';

class _MemoryKeyStore implements SecureKeyStore {
  final List<String> values = [];

  @override
  Future<void> deleteAll(String key) async => values.clear();

  @override
  Future<List<String>> readAll(String key) async => List.of(values);

  @override
  Future<bool> writeAll(String key, String value) async {
    if (!values.contains(value)) values.add(value);
    return true;
  }
}

class _ToggleEncryptCodec extends SecureDataCodec {
  bool failEncryption = false;

  _ToggleEncryptCodec({required super.keyStore});

  @override
  Future<String> encrypt(String plainText) {
    if (failEncryption) {
      throw const SecureDataException('test persistence failure');
    }
    return super.encrypt(plainText);
  }
}

Subscription _subscription({
  required String id,
  String name = 'Netflix Premium',
  String currency = 'SAR',
  double price = 50,
  Set<String>? ignoredDuplicateGroupKeys,
}) => Subscription(
  id: id,
  name: name,
  emoji: 'N',
  price: price,
  currency: currency,
  cycle: BillingCycle.monthly,
  anchorDate: DateTime(2026, 1, 1),
  category: 'ترفيه ومشاهدة',
  ignoredDuplicateGroupKeys: ignoredDuplicateGroupKeys,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('v13 migrates to v14 with compatible duplicate metadata', () {
    final legacy = <String, dynamic>{
      'schemaVersion': 13,
      'id': 'legacy',
      'name': 'Netflix',
      'price': 50,
      'currency': 'SAR',
      'cycle': BillingCycle.monthly.index,
      'anchor': '2026-01-01',
      'category': 'ترفيه ومشاهدة',
    };

    final migrated = SubscriptionSchema.migrateToV14(legacy);
    final decoded = Subscription.fromJson(migrated);

    expect(migrated['schemaVersion'], 14);
    expect(migrated['ignoredDuplicateGroupKeys'], isEmpty);
    expect(decoded.id, 'legacy');
    expect(decoded.ignoredDuplicateGroupKeys, isEmpty);
  });

  test('duplicate group identity is stable and lookup covers every member', () {
    final first = _subscription(id: 'first');
    final second = _subscription(id: 'second', price: 75);

    final forward = FinancialAssistant.duplicateGroupKey([first.id, second.id]);
    final reverse = FinancialAssistant.duplicateGroupKey([second.id, first.id]);
    final groups = FinancialAssistant.findDuplicateGroups([
      first,
      second,
    ], now: DateTime(2026, 7, 1));
    final index = FinancialAssistant.indexDuplicateGroupsBySubscriptionId(
      groups,
    );

    expect(forward, reverse);
    expect(groups.single.groupKey, forward);
    expect(index.keys, containsAll(<String>{'first', 'second'}));
    expect(identical(index['first'], index['second']), isTrue);
  });

  test('all-currency discovery never combines different currencies', () {
    final groups = FinancialAssistant.findDuplicateGroups([
      _subscription(id: 'sar-only', currency: 'SAR'),
      _subscription(id: 'aed-one', currency: 'AED'),
      _subscription(id: 'aed-two', currency: 'AED', price: 60),
    ], now: DateTime(2026, 7, 1));

    expect(groups, hasLength(1));
    expect(
      groups.single.subscriptions.map((item) => item.id),
      containsAll(<String>{'aed-one', 'aed-two'}),
    );
    expect(
      groups.single.subscriptions.every((item) => item.currency == 'AED'),
      isTrue,
    );
  });

  test(
    'ignored group is excluded while explicit diagnostics can retrieve it',
    () {
      final first = _subscription(id: 'first');
      final second = _subscription(id: 'second');
      final key = FinancialAssistant.duplicateGroupKey([first.id, second.id]);
      first.ignoredDuplicateGroupKeys.add(key);

      expect(
        FinancialAssistant.findDuplicateGroups([
          first,
          second,
        ], now: DateTime(2026, 7, 1)),
        isEmpty,
      );
      final snapshot = FinancialAssistant.analyze(
        [first, second],
        currency: 'SAR',
        now: DateTime(2026, 7, 1),
      );
      expect(snapshot.duplicateGroups, isEmpty);
      expect(
        snapshot.reviewItems.where(
          (item) => item.reason == FinancialReviewReason.duplicate,
        ),
        isEmpty,
      );
      final diagnostic = FinancialAssistant.findDuplicateGroups(
        [first, second],
        now: DateTime(2026, 7, 1),
        includeIgnored: true,
      );
      expect(diagnostic.single.groupKey, key);
      expect(diagnostic.single.isIgnored, isTrue);
    },
  );

  test('dismissal persists across restart and ordinary upsert', () async {
    final keys = _MemoryKeyStore();
    final source = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await source.load();
    await source.upsert(_subscription(id: 'first'));
    await source.upsert(_subscription(id: 'second', price: 75));
    final group =
        FinancialAssistant.findDuplicateGroups(
          source.items,
          now: DateTime(2026, 7, 1),
        ).single;

    expect(await source.ignoreDuplicateGroup(group), isTrue);
    expect(
      FinancialAssistant.findDuplicateGroups(
        source.items,
        now: DateTime(2026, 7, 1),
      ),
      isEmpty,
    );

    await source.upsert(_subscription(id: 'first', price: 55));
    expect(
      source.items
          .firstWhere((item) => item.id == 'first')
          .ignoredDuplicateGroupKeys,
      contains(group.groupKey),
    );

    final restarted = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await restarted.load();
    expect(
      FinancialAssistant.findDuplicateGroups(
        restarted.items,
        now: DateTime(2026, 7, 1),
      ),
      isEmpty,
    );
    expect(
      restarted.items.every(
        (item) => item.ignoredDuplicateGroupKeys.contains(group.groupKey),
      ),
      isTrue,
    );
  });

  test('encrypted backup round-trip retains the dismissal', () async {
    final keys = _MemoryKeyStore();
    final source = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await source.load();
    await source.upsert(_subscription(id: 'first'));
    await source.upsert(_subscription(id: 'second'));
    final group =
        FinancialAssistant.findDuplicateGroups(
          source.items,
          now: DateTime(2026, 7, 1),
        ).single;
    await source.ignoreDuplicateGroup(group);
    final encryptedBackup = await source.exportEncryptedCloudBackup();

    expect(encryptedBackup, isNot(contains(group.groupKey)));
    SharedPreferences.setMockInitialValues({});
    final restored = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await restored.load();

    expect(await restored.importEncryptedCloudBackup(encryptedBackup), 2);
    expect(
      FinancialAssistant.findDuplicateGroups(
        restored.items,
        now: DateTime(2026, 7, 1),
      ),
      isEmpty,
    );
    expect(
      restored.items.every(
        (item) => item.ignoredDuplicateGroupKeys.contains(group.groupKey),
      ),
      isTrue,
    );
  });

  test('persistence failure rolls back every dismissal mutation', () async {
    final keys = _MemoryKeyStore();
    final codec = _ToggleEncryptCodec(keyStore: keys);
    final store = SubscriptionStore.testing(
      dataCodec: codec,
      secretStore: keys,
    );
    await store.load();
    await store.upsert(_subscription(id: 'first'));
    await store.upsert(_subscription(id: 'second'));
    final group =
        FinancialAssistant.findDuplicateGroups(
          store.items,
          now: DateTime(2026, 7, 1),
        ).single;

    codec.failEncryption = true;
    await expectLater(
      store.ignoreDuplicateGroup(group),
      throwsA(isA<SecureDataException>()),
    );

    expect(
      store.items.every((item) => item.ignoredDuplicateGroupKeys.isEmpty),
      isTrue,
    );
    expect(
      FinancialAssistant.findDuplicateGroups(
        store.items,
        now: DateTime(2026, 7, 1),
      ),
      hasLength(1),
    );
  });

  test('older import cannot erase an existing local dismissal', () async {
    final keys = _MemoryKeyStore();
    final store = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await store.load();
    await store.upsert(_subscription(id: 'first'));
    await store.upsert(_subscription(id: 'second'));
    final group =
        FinancialAssistant.findDuplicateGroups(
          store.items,
          now: DateTime(2026, 7, 1),
        ).single;
    await store.ignoreDuplicateGroup(group);

    final legacyBackup = jsonEncode({
      'app': 'ishtirakati',
      'version': 2,
      'subscriptions': [
        _subscription(id: 'first').toJson()
          ..remove('ignoredDuplicateGroupKeys')
          ..['schemaVersion'] = 13,
        _subscription(id: 'second').toJson()
          ..remove('ignoredDuplicateGroupKeys')
          ..['schemaVersion'] = 13,
      ],
    });

    expect(await store.importJson(legacyBackup), 2);
    expect(
      store.items.every(
        (item) => item.ignoredDuplicateGroupKeys.contains(group.groupKey),
      ),
      isTrue,
    );
  });
}
