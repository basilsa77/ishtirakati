import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/cloud_account_binding.dart';

void main() {
  const firstUid = 'firebase-user-a';
  const secondUid = 'firebase-user-b';

  test(
    'first account is bound by fingerprint without persisting raw UID',
    () async {
      final store = _MemoryBindingStore();

      expect(
        await CloudAccountBinding.ensureBoundWithStore(
          uid: firstUid,
          store: store,
        ),
        CloudAccountBindingResult.allowed,
      );

      final fingerprint = await CloudAccountBinding.fingerprint(firstUid);
      expect(fingerprint, hasLength(64));
      expect(store.values[CloudAccountBinding.bindingKey], fingerprint);
      expect(store.values.toString(), isNot(contains(firstUid)));
    },
  );

  test('the same account remains allowed', () async {
    final fingerprint = await CloudAccountBinding.fingerprint(firstUid);
    final store = _MemoryBindingStore({
      CloudAccountBinding.bindingKey: fingerprint,
    });

    expect(
      await CloudAccountBinding.ensureBoundWithStore(
        uid: firstUid,
        store: store,
      ),
      CloudAccountBindingResult.allowed,
    );
  });

  test(
    'a different account is rejected without changing the binding',
    () async {
      final fingerprint = await CloudAccountBinding.fingerprint(firstUid);
      final store = _MemoryBindingStore({
        CloudAccountBinding.bindingKey: fingerprint,
      });

      expect(
        await CloudAccountBinding.ensureBoundWithStore(
          uid: secondUid,
          store: store,
        ),
        CloudAccountBindingResult.mismatch,
      );
      expect(store.values[CloudAccountBinding.bindingKey], fingerprint);
    },
  );

  test('legacy raw UID revision keys are migrated and erased', () async {
    final store = _MemoryBindingStore({
      '${CloudAccountBinding.revisionKeyPrefix}$firstUid': 8,
      '${CloudAccountBinding.pendingRevisionKeyPrefix}$firstUid': 9,
    });

    expect(
      await CloudAccountBinding.ensureBoundWithStore(
        uid: firstUid,
        store: store,
      ),
      CloudAccountBindingResult.allowed,
    );

    final fingerprint = await CloudAccountBinding.fingerprint(firstUid);
    expect(
      store.values['${CloudAccountBinding.revisionKeyPrefix}$fingerprint'],
      8,
    );
    expect(
      store
          .values['${CloudAccountBinding.pendingRevisionKeyPrefix}$fingerprint'],
      9,
    );
    expect(store.values.keys.where((key) => key.endsWith(firstUid)), isEmpty);
  });

  test('a legacy revision belonging to another UID fails closed', () async {
    final store = _MemoryBindingStore({
      '${CloudAccountBinding.revisionKeyPrefix}$firstUid': 4,
    });

    expect(
      await CloudAccountBinding.ensureBoundWithStore(
        uid: secondUid,
        store: store,
      ),
      CloudAccountBindingResult.mismatch,
    );
    expect(store.values, hasLength(1));
  });

  test('binding persistence failure throws and does not allow sync', () async {
    final store = _MemoryBindingStore()..failWrites = true;

    await expectLater(
      CloudAccountBinding.ensureBoundWithStore(uid: firstUid, store: store),
      throwsA(isA<CloudAccountBindingException>()),
    );
    expect(store.values, isEmpty);
  });

  test('delayed push verifies that the authenticated UID did not change', () {
    final source = File('lib/services/cloud_sync.dart').readAsStringSync();
    expect(source, contains('AuthService.currentUser?.uid != scheduledUid'));
  });
}

class _MemoryBindingStore implements CloudAccountBindingStore {
  final Map<String, Object> values;
  bool failWrites = false;

  _MemoryBindingStore([Map<String, Object>? initial])
    : values = Map<String, Object>.of(initial ?? const {});

  @override
  Set<String> getKeys() => values.keys.toSet();

  @override
  int? getInt(String key) => values[key] as int?;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<bool> remove(String key) async {
    if (failWrites) return false;
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }
}
