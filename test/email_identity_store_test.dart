import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ishtirakati/services/email_identity_store.dart';

class _FakeEmailKeychain implements EmailIdentityKeychain {
  String? canonical;
  final List<String> legacy;
  bool allowCanonicalWrite;
  bool allowCanonicalDelete;
  bool allowLegacyDelete;

  _FakeEmailKeychain({
    this.canonical,
    List<String>? legacy,
    this.allowCanonicalWrite = true,
    this.allowCanonicalDelete = true,
    this.allowLegacyDelete = true,
  }) : legacy = legacy ?? <String>[];

  @override
  Future<void> deleteCanonical() async {
    if (!allowCanonicalDelete) throw StateError('canonical delete failed');
    canonical = null;
  }

  @override
  Future<void> deleteLegacy() async {
    if (!allowLegacyDelete) throw StateError('legacy delete failed');
    legacy.clear();
  }

  @override
  Future<String?> readCanonical() async => canonical;

  @override
  Future<List<String>> readLegacy() async => List<String>.of(legacy);

  @override
  Future<void> writeCanonical(String email) async {
    if (!allowCanonicalWrite) throw StateError('canonical write failed');
    canonical = email;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'migrates legacy Keychain email before deleting every legacy copy',
    () async {
      const email = 'owner@example.com';
      SharedPreferences.setMockInitialValues({
        EmailIdentityStore.legacyPreferenceKey: 'stale@example.com',
      });
      final keychain = _FakeEmailKeychain(legacy: [email]);
      final store = EmailIdentityStore(keychain: keychain);

      expect(await store.readAndMigrate(), email);

      final prefs = await SharedPreferences.getInstance();
      expect(keychain.canonical, email);
      expect(keychain.legacy, isEmpty);
      expect(prefs.getString(EmailIdentityStore.legacyPreferenceKey), isNull);
    },
  );

  test(
    'failed canonical migration preserves every legacy recovery copy',
    () async {
      const email = 'owner@example.com';
      SharedPreferences.setMockInitialValues({
        EmailIdentityStore.legacyPreferenceKey: email,
      });
      final keychain = _FakeEmailKeychain(
        legacy: [email],
        allowCanonicalWrite: false,
      );
      final store = EmailIdentityStore(keychain: keychain);

      await expectLater(
        store.readAndMigrate(),
        throwsA(isA<EmailIdentityStorageException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(keychain.canonical, isNull);
      expect(keychain.legacy, [email]);
      expect(prefs.getString(EmailIdentityStore.legacyPreferenceKey), email);
    },
  );

  test(
    'opt-out forgets canonical, Keychain legacy, and preferences legacy',
    () async {
      SharedPreferences.setMockInitialValues({
        EmailIdentityStore.legacyPreferenceKey: 'preference@example.com',
      });
      final keychain = _FakeEmailKeychain(
        canonical: 'canonical@example.com',
        legacy: ['legacy@example.com'],
      );
      final store = EmailIdentityStore(keychain: keychain);

      await store.forget();

      final prefs = await SharedPreferences.getInstance();
      expect(keychain.canonical, isNull);
      expect(keychain.legacy, isEmpty);
      expect(prefs.getString(EmailIdentityStore.legacyPreferenceKey), isNull);
    },
  );

  test(
    'forget fails closed when canonical deletion cannot be verified',
    () async {
      final keychain = _FakeEmailKeychain(
        canonical: 'owner@example.com',
        allowCanonicalDelete: false,
      );
      final store = EmailIdentityStore(keychain: keychain);

      await expectLater(
        store.forget(),
        throwsA(isA<EmailIdentityStorageException>()),
      );
      expect(keychain.canonical, 'owner@example.com');
    },
  );

  test('forget fails closed when a legacy Keychain copy remains', () async {
    final keychain = _FakeEmailKeychain(
      legacy: ['legacy@example.com'],
      allowLegacyDelete: false,
    );
    final store = EmailIdentityStore(keychain: keychain);

    await expectLater(
      store.forget(),
      throwsA(isA<EmailIdentityStorageException>()),
    );
    expect(keychain.legacy, ['legacy@example.com']);
  });

  test('serialized opt-out cannot be undone by an earlier migration', () async {
    final keychain = _FakeEmailKeychain(legacy: ['owner@example.com']);
    final store = EmailIdentityStore(keychain: keychain);

    final migration = store.readAndMigrate();
    final optOut = store.forget();

    expect(await migration, 'owner@example.com');
    await optOut;
    expect(keychain.canonical, isNull);
    expect(keychain.legacy, isEmpty);
  });
}
