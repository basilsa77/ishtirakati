/// تشفير بيانات التطبيق محليًا (AES-256-GCM) قبل حفظها.
///
/// تصميم «لا يفقد البيانات أبدًا»:
/// - المفتاح يُخزن في Keychain وبنسخة مرآة محلية، ويُقرأ من أي موضع
///   متاح (يشمل مواضع الإصدارات السابقة بخيارات وصول مختلفة).
/// - عند فك التشفير نجرب كل المفاتيح المرشحة ونعتمد ما يجتاز تحقق MAC،
///   ثم «نشفي» بقية المواضع بنسخ المفتاح الصحيح إليها.
/// - إن تعذر Keychain كليًا (إعادة توقيع جانبي مثلًا) نستمر بالمرآة
///   المحلية بدل تعطيل التطبيق — والبيانات تبقى فوق تشفير قرص iOS.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureDataException implements Exception {
  final String message;

  const SecureDataException(this.message);

  @override
  String toString() => message;
}

class SecureDataCodec {
  static const _keyName = 'ishtirakati_data_encryption_key_v1';
  static const _prefsMirrorKey = 'ishtirakati_data_key_mirror_v1';

  final AesGcm _cipher = AesGcm.with256bits();

  /// مواضع Keychain المحتملة (الافتراضي + خيارات استخدمتها إصدارات سابقة).
  static const List<FlutterSecureStorage> _stores = [
    FlutterSecureStorage(),
    FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
    FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    ),
  ];

  /// كل المفاتيح المرشحة من كل المواضع (بدون تكرار).
  Future<List<List<int>>> _candidateKeys() async {
    final seen = <String>{};
    final keys = <List<int>>[];
    for (final store in _stores) {
      try {
        final encoded = await store.read(key: _keyName);
        if (encoded != null && encoded.isNotEmpty && seen.add(encoded)) {
          keys.add(base64Url.decode(encoded));
        }
      } catch (_) {
        // موضع غير متاح — نكمل للتالي.
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final mirror = prefs.getString(_prefsMirrorKey);
      if (mirror != null && mirror.isNotEmpty && seen.add(mirror)) {
        keys.add(base64Url.decode(mirror));
      }
    } catch (_) {}
    return keys;
  }

  /// نسخ المفتاح الصحيح إلى Keychain والمرآة المحلية (شفاء ذاتي).
  Future<void> _mirrorKey(List<int> bytes) async {
    final encoded = base64Url.encode(bytes);
    try {
      await _stores.first.write(key: _keyName, value: encoded);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsMirrorKey, encoded);
    } catch (_) {}
  }

  Future<List<int>> _primaryKey() async {
    final candidates = await _candidateKeys();
    if (candidates.isNotEmpty) {
      await _mirrorKey(candidates.first);
      return candidates.first;
    }
    // لا مفتاح في أي موضع: أنشئ واحدًا وانسخه للجميع.
    final generated = await _cipher.newSecretKey();
    final bytes = await generated.extractBytes();
    await _mirrorKey(bytes);
    return bytes;
  }

  Future<String> encrypt(String plainText) async {
    try {
      final box = await _cipher.encrypt(
        utf8.encode(plainText),
        secretKey: SecretKey(await _primaryKey()),
      );
      return jsonEncode({
        'v': 1,
        'n': base64Url.encode(box.nonce),
        'c': base64Url.encode(box.cipherText),
        'm': base64Url.encode(box.mac.bytes),
      });
    } catch (_) {
      throw const SecureDataException('تعذر تشفير البيانات محليًا.');
    }
  }

  Future<String> decrypt(String payload) async {
    final SecretBox box;
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic> || data['v'] != 1) {
        throw const FormatException();
      }
      box = SecretBox(
        base64Url.decode(data['c'] as String),
        nonce: base64Url.decode(data['n'] as String),
        mac: Mac(base64Url.decode(data['m'] as String)),
      );
    } catch (_) {
      throw const SecureDataException('صيغة البيانات المشفرة غير صالحة.');
    }

    // جرّب كل المفاتيح المرشحة — أول مفتاح يجتاز تحقق MAC هو الصحيح.
    for (final keyBytes in await _candidateKeys()) {
      try {
        final clear = await _cipher.decrypt(
          box,
          secretKey: SecretKey(keyBytes),
        );
        await _mirrorKey(keyBytes); // اعتمده في كل المواضع
        return utf8.decode(clear);
      } catch (_) {
        // مفتاح خاطئ — جرّب التالي.
      }
    }
    throw const SecureDataException('تعذر فك تشفير البيانات المحلية.');
  }
}
