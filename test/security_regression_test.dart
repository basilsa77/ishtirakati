import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ishtirakati/services/account_deletion_service.dart';
import 'package:ishtirakati/services/ai_consent_service.dart';
import 'package:ishtirakati/services/safe_url.dart';
import 'package:ishtirakati/services/secure_data_codec.dart';
import 'package:ishtirakati/services/subscription_store.dart';

class _FakeKeyStore implements SecureKeyStore {
  final List<String> values;
  bool allowWrites;
  bool deleted = false;

  _FakeKeyStore({List<String>? values, this.allowWrites = true})
      : values = values ?? [];

  @override
  Future<List<String>> readAll(String key) async => List.of(values);

  @override
  Future<bool> writeAll(String key, String value) async {
    if (!allowWrites) return false;
    if (!values.contains(value)) values.add(value);
    return true;
  }

  @override
  Future<void> deleteAll(String key) async {
    deleted = true;
    values.clear();
  }
}

class _FailingDecryptCodec extends SecureDataCodec {
  _FailingDecryptCodec() : super(keyStore: _FakeKeyStore());

  @override
  Future<String> decrypt(String payload) async =>
      throw const SecureDataException('فشل اختباري');
}

class _DeletionCodec extends SecureDataCodec {
  bool deleted = false;

  _DeletionCodec() : super(keyStore: _FakeKeyStore());

  @override
  Future<void> deleteAllKeys() async {
    deleted = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('سياسة مفاتيح v11 الأمنية', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Keychain يسبق مرآة مختلفة', () async {
      final keychain = _FakeKeyStore();
      final codec = SecureDataCodec(keyStore: keychain);
      final encrypted = await codec.encrypt('بيانات حساسة');
      final wrongKey = base64Url.encode(List<int>.filled(32, 7));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SecureDataCodec.mirrorPreferenceKey, wrongKey);

      expect(await codec.decrypt(encrypted), 'بيانات حساسة');
    });

    test('المرآة تستعاد فقط عند غياب Keychain ثم ترمم Keychain', () async {
      final originalStore = _FakeKeyStore();
      final originalCodec = SecureDataCodec(keyStore: originalStore);
      final encrypted = await originalCodec.encrypt('سجل قديم');
      final encodedKey = originalStore.values.single;
      SharedPreferences.setMockInitialValues({
        SecureDataCodec.mirrorPreferenceKey: encodedKey,
      });
      final restoredStore = _FakeKeyStore();
      final restoredCodec = SecureDataCodec(keyStore: restoredStore);

      expect(await restoredCodec.decrypt(encrypted), 'سجل قديم');
      expect(restoredStore.values, contains(encodedKey));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureDataCodec.mirrorPreferenceKey), isNull);
      expect(await restoredCodec.mirrorFallbackEnabled, isFalse);
    });

    test('v13 لا يسمح بإنشاء مرآة مفاتيح جديدة', () async {
      final codec = SecureDataCodec(keyStore: _FakeKeyStore());

      expect(await codec.setMirrorFallbackEnabled(true), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureDataCodec.mirrorPreferenceKey), isNull);
    });

    test('لا ينشئ مرآة لمستخدم جديد عند فشل Keychain', () async {
      final codec = SecureDataCodec(
        keyStore: _FakeKeyStore(allowWrites: false),
      );

      await expectLater(codec.encrypt('لن تحفظ'), throwsA(isA<SecureDataException>()));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureDataCodec.mirrorPreferenceKey), isNull);
    });

    test('لا يحذف المرآة إن لم يفك مفتاح Keychain السجل الحالي', () async {
      final keychain = _FakeKeyStore();
      final codec = SecureDataCodec(keyStore: keychain);
      final encrypted = await codec.encrypt('السجل الصحيح');
      final correctKey = keychain.values.single;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SecureDataCodec.mirrorPreferenceKey, correctKey);
      await prefs.setBool(SecureDataCodec.mirrorOptInPreferenceKey, true);
      keychain.values
        ..clear()
        ..add(base64Url.encode(List<int>.filled(32, 9)));

      final disabled = await codec.setMirrorFallbackEnabled(
        false,
        verificationPayload: encrypted,
      );

      expect(disabled, isFalse);
      expect(prefs.getString(SecureDataCodec.mirrorPreferenceKey), correctKey);
    });
  });

  group('ترحيل مفتاح AI إلى Keychain في v13', () {
    test('يحذف المرآة بعد نجاح Keychain فقط', () async {
      const value = 'legacy-ai-key';
      SharedPreferences.setMockInitialValues({
        'ishtirakati_ai_api_key_mirror':
            base64Url.encode(utf8.encode(value)),
      });
      final keyStore = _FakeKeyStore();
      final store = SubscriptionStore.testing(
        dataCodec: SecureDataCodec(keyStore: _FakeKeyStore()),
        secretStore: keyStore,
      );

      await store.load();

      final prefs = await SharedPreferences.getInstance();
      expect(store.aiApiKey, value);
      expect(keyStore.values, contains(value));
      expect(prefs.getString('ishtirakati_ai_api_key_mirror'), isNull);
    });

    test('يبقي المرآة ولا يحمّل المفتاح عند فشل Keychain', () async {
      const value = 'legacy-ai-key';
      final encoded = base64Url.encode(utf8.encode(value));
      SharedPreferences.setMockInitialValues({
        'ishtirakati_ai_api_key_mirror': encoded,
      });
      final store = SubscriptionStore.testing(
        dataCodec: SecureDataCodec(keyStore: _FakeKeyStore()),
        secretStore: _FakeKeyStore(allowWrites: false),
      );

      await store.load();

      final prefs = await SharedPreferences.getInstance();
      expect(store.aiApiKey, isEmpty);
      expect(prefs.getString('ishtirakati_ai_api_key_mirror'), encoded);
    });
  });

  test('فشل فك التشفير يقفل الكتابة ويحفظ السجل الأصلي', () async {
    const encrypted = '{"v":1,"n":"bad","c":"bad","m":"bad"}';
    SharedPreferences.setMockInitialValues({
      'ishtirakati_subs_v2_encrypted': encrypted,
    });
    final store = SubscriptionStore.testing(
      dataCodec: _FailingDecryptCodec(),
      secretStore: _FakeKeyStore(),
    );

    await store.load();

    expect(store.storageHealthy, isFalse);
    await expectLater(store.clearAll(), throwsA(isA<SecureDataException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ishtirakati_subs_v2_encrypted'), encrypted);
    expect(prefs.getString('ishtirakati_subs_v2_backup'), encrypted);
  });

  test('حذف الحساب مرتب ولا يمسح المحلي عند فشل السحابة', () async {
    final calls = <String>[];

    await expectLater(
      AccountDeletionCoordinator.run(
        reauthenticate: () async => calls.add('reauth'),
        deleteCloud: () async {
          calls.add('cloud');
          throw StateError('offline');
        },
        deleteAccount: () async => calls.add('account'),
        clearLocal: () async => calls.add('local'),
      ),
      throwsStateError,
    );

    expect(calls, ['reauth', 'cloud']);
  });

  test('حذف الحساب الكامل ينفذ الترتيب الحساس', () async {
    final calls = <String>[];
    await AccountDeletionCoordinator.run(
      reauthenticate: () async => calls.add('reauth'),
      deleteCloud: () async => calls.add('cloud'),
      deleteAccount: () async => calls.add('account'),
      clearLocal: () async => calls.add('local'),
    );
    expect(calls, ['reauth', 'cloud', 'account', 'local']);
  });

  test('مسح الحساب المحلي يصفر المفاتيح والتفضيلات', () async {
    SharedPreferences.setMockInitialValues({'sensitive': 'value'});
    final codec = _DeletionCodec();
    final secretStore = _FakeKeyStore(values: ['ai-key']);
    final store = SubscriptionStore.testing(
      dataCodec: codec,
      secretStore: secretStore,
    );

    await store.clearLocalForAccountDeletion();

    expect(codec.deleted, isTrue);
    expect(secretStore.deleted, isTrue);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    expect(store.aiApiKey, isEmpty);
    expect(store.hasOnboarded, isFalse);
  });

  test('موافقة AI محفوظة لكل مزود على حدة', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AiConsentService.hasAdvisorConsent('gemini'), isFalse);
    await AiConsentService.rememberAdvisorConsent('gemini');
    expect(await AiConsentService.hasAdvisorConsent('gemini'), isTrue);
    expect(await AiConsentService.hasAdvisorConsent('openai'), isFalse);
  });

  test('سياسة الروابط تقبل HTTPS فقط', () {
    expect(normalizedHttpsUri('example.com/account')?.scheme, 'https');
    expect(normalizedHttpsUri('https://example.com/account'), isNotNull);
    expect(normalizedHttpsUri('http://example.com/account'), isNull);
    expect(normalizedHttpsUri('javascript:alert(1)'), isNull);
    expect(normalizedHttpsUri('https://user@example.com'), isNull);
  });
}
