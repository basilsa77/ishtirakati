import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ishtirakati/services/secure_data_codec.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AES-GCM uses a fresh nonce for every encryption', () async {
    final codec = SecureDataCodec(keyStore: _MemoryKeyStore());

    final first = await codec.encrypt('same sensitive financial record');
    final second = await codec.encrypt('same sensitive financial record');
    final firstEnvelope = jsonDecode(first) as Map<String, dynamic>;
    final secondEnvelope = jsonDecode(second) as Map<String, dynamic>;

    expect(firstEnvelope['n'], isNot(secondEnvelope['n']));
    expect(firstEnvelope['c'], isNot(secondEnvelope['c']));
    expect(await codec.decrypt(first), 'same sensitive financial record');
    expect(await codec.decrypt(second), 'same sensitive financial record');
  });

  test('AES-GCM rejects nonce, ciphertext, and tag tampering', () async {
    final codec = SecureDataCodec(keyStore: _MemoryKeyStore());
    final encrypted = await codec.encrypt('authenticated payload');
    final envelope = jsonDecode(encrypted) as Map<String, dynamic>;

    for (final field in <String>['n', 'c', 'm']) {
      final tampered = Map<String, dynamic>.of(envelope);
      tampered[field] = _flipBase64UrlCharacter(tampered[field] as String);

      await expectLater(
        codec.decrypt(jsonEncode(tampered)),
        throwsA(isA<SecureDataException>()),
        reason: 'tampered field=$field',
      );
    }
  });

  test('AES-GCM rejects malformed and unsupported envelopes', () async {
    final codec = SecureDataCodec(keyStore: _MemoryKeyStore());
    final encrypted = await codec.encrypt('authenticated payload');
    final envelope = jsonDecode(encrypted) as Map<String, dynamic>;

    await expectLater(
      codec.decrypt(jsonEncode({...envelope, 'v': 2})),
      throwsA(isA<SecureDataException>()),
    );
    await expectLater(
      codec.decrypt(jsonEncode({...envelope, 'm': 'AA=='})),
      throwsA(isA<SecureDataException>()),
    );
    await expectLater(
      codec.decrypt('{"v":1,"n":"not-base64"}'),
      throwsA(isA<SecureDataException>()),
    );
  });
}

String _flipBase64UrlCharacter(String value) {
  final replacement = value.startsWith('A') ? 'B' : 'A';
  return '$replacement${value.substring(1)}';
}
