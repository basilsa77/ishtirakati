import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/services/secure_data_codec.dart';
import 'package:ishtirakati/services/subscription_store.dart';

class _MemoryKeyStore implements SecureKeyStore {
  final List<String> values = [];
  bool allowWrites;

  _MemoryKeyStore({this.allowWrites = true});

  @override
  Future<List<String>> readAll(String key) async => List.of(values);

  @override
  Future<bool> writeAll(String key, String value) async {
    if (!allowWrites) return false;
    if (!values.contains(value)) values.add(value);
    return true;
  }

  @override
  Future<void> deleteAll(String key) async => values.clear();
}

Subscription _sensitiveSubscription() => Subscription(
  id: 'cloud-encryption-test',
  name: 'Confidential Service Name',
  emoji: '',
  price: 149.99,
  currency: 'SAR',
  cycle: BillingCycle.monthly,
  anchorDate: DateTime(2026, 7, 1),
  category: 'أخرى',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cloud backup contains AES-GCM ciphertext only', () async {
    final keys = _MemoryKeyStore();
    final codec = SecureDataCodec(keyStore: keys);
    final store = SubscriptionStore.testing(
      dataCodec: codec,
      secretStore: keys,
    );
    await store.load();
    await store.upsert(_sensitiveSubscription());

    final payload = await store.exportEncryptedCloudBackup();
    final envelope = jsonDecode(payload) as Map<String, dynamic>;

    expect(envelope.keys.toSet(), {'v', 'n', 'c', 'm'});
    expect(payload, isNot(contains('Confidential Service Name')));
    expect(payload, isNot(contains('subscriptions')));
    expect(await codec.decrypt(payload), contains('Confidential Service Name'));
  });

  test('encrypted cloud backup restores with the same Keychain key', () async {
    final keys = _MemoryKeyStore();
    final sourceCodec = SecureDataCodec(keyStore: keys);
    final source = SubscriptionStore.testing(
      dataCodec: sourceCodec,
      secretStore: keys,
    );
    await source.load();
    await source.upsert(_sensitiveSubscription());
    final payload = await source.exportEncryptedCloudBackup();

    SharedPreferences.setMockInitialValues({});
    final target = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await target.load();

    expect(await target.importEncryptedCloudBackup(payload), 1);
    expect(target.items.single.name, 'Confidential Service Name');
  });

  test('wrong Keychain key fails closed without changing local data', () async {
    final sourceKeys = _MemoryKeyStore();
    final source = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: sourceKeys),
      secretStore: sourceKeys,
    );
    await source.load();
    await source.upsert(_sensitiveSubscription());
    final payload = await source.exportEncryptedCloudBackup();

    SharedPreferences.setMockInitialValues({});
    final otherKeys = _MemoryKeyStore();
    final target = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: otherKeys),
      secretStore: otherKeys,
    );
    await target.load();

    expect(await target.importEncryptedCloudBackup(payload), -1);
    expect(target.items, isEmpty);
  });

  test('Keychain write failure prevents creating a cloud backup', () async {
    final keys = _MemoryKeyStore(allowWrites: false);
    final store = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await store.load();

    await expectLater(
      store.exportEncryptedCloudBackup(),
      throwsA(isA<SecureDataException>()),
    );
  });
}
