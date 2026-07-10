/// تشفير بيانات التطبيق محليًا قبل حفظها في SharedPreferences.
/// مفتاح AES لا يغادر Keychain/Keystore الخاص بالنظام.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureDataException implements Exception {
  final String message;

  const SecureDataException(this.message);

  @override
  String toString() => message;
}

class SecureDataCodec {
  static const _keyName = 'ishtirakati_data_encryption_key_v1';

  final AesGcm _cipher = AesGcm.with256bits();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<SecretKey> _loadOrCreateKey() async {
    try {
      final encoded = await _storage.read(key: _keyName);
      if (encoded != null && encoded.isNotEmpty) {
        return SecretKey(base64Url.decode(encoded));
      }
      final generated = await _cipher.newSecretKey();
      final bytes = await generated.extractBytes();
      await _storage.write(key: _keyName, value: base64Url.encode(bytes));
      return SecretKey(bytes);
    } catch (_) {
      throw const SecureDataException(
        'تعذر الوصول إلى التخزين الآمن في الجهاز.',
      );
    }
  }

  Future<String> encrypt(String plainText) async {
    try {
      final box = await _cipher.encrypt(
        utf8.encode(plainText),
        secretKey: await _loadOrCreateKey(),
      );
      return jsonEncode({
        'v': 1,
        'n': base64Url.encode(box.nonce),
        'c': base64Url.encode(box.cipherText),
        'm': base64Url.encode(box.mac.bytes),
      });
    } on SecureDataException {
      rethrow;
    } catch (_) {
      throw const SecureDataException('تعذر تشفير البيانات محليًا.');
    }
  }

  Future<String> decrypt(String payload) async {
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic> || data['v'] != 1) {
        throw const FormatException();
      }
      final box = SecretBox(
        base64Url.decode(data['c'] as String),
        nonce: base64Url.decode(data['n'] as String),
        mac: Mac(base64Url.decode(data['m'] as String)),
      );
      final clear = await _cipher.decrypt(
        box,
        secretKey: await _loadOrCreateKey(),
      );
      return utf8.decode(clear);
    } on SecureDataException {
      rethrow;
    } catch (_) {
      throw const SecureDataException('تعذر فك تشفير البيانات المحلية.');
    }
  }
}
