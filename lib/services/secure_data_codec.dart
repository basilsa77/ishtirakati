/// تشفير بيانات التطبيق محليًا بـAES-256-GCM قبل حفظها.
///
/// Keychain هو المصدر الوحيد للمفاتيح في v13. تُقرأ مرآة SharedPreferences
/// القديمة مرة واحدة فقط لإنقاذ بيانات الإصدارات السابقة، ثم تُرحّل إلى
/// Keychain وتُحذف بعد نجاح الكتابة الآمنة. لا يُنشئ هذا الإصدار أي مرآة جديدة.
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

/// فصل صغير يجعل سياسة المفاتيح قابلة للاختبار دون Keychain حقيقي.
abstract class SecureKeyStore {
  Future<List<String>> readAll(String key);
  Future<bool> writeAll(String key, String value);
  Future<void> deleteAll(String key);
}

class IosSecureKeyStore implements SecureKeyStore {
  const IosSecureKeyStore();

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

  @override
  Future<List<String>> readAll(String key) async {
    final values = <String>{};
    for (final store in _stores) {
      try {
        final value = await store.read(key: key);
        if (value != null && value.isNotEmpty) values.add(value);
      } catch (_) {
        // نجرب موضع Keychain التالي؛ لا ننتقل للمرآة إلا بعد فشلها كلها.
      }
    }
    return values.toList();
  }

  @override
  Future<bool> writeAll(String key, String value) async {
    var wroteAtLeastOne = false;
    for (final store in _stores) {
      try {
        await store.write(key: key, value: value);
        wroteAtLeastOne = true;
      } catch (_) {
        // نجاح موضع آمن واحد يكفي، ونستمر لمحاولة ترميم المواضع القديمة.
      }
    }
    return wroteAtLeastOne;
  }

  @override
  Future<void> deleteAll(String key) async {
    for (final store in _stores) {
      try {
        await store.delete(key: key);
      } catch (_) {}
    }
  }
}

class SecureDataCodec {
  static const keyName = 'ishtirakati_data_encryption_key_v1';
  static const mirrorPreferenceKey = 'ishtirakati_data_key_mirror_v1';
  static const mirrorOptInPreferenceKey =
      'ishtirakati_sideload_key_fallback_v1';

  final AesGcm _cipher = AesGcm.with256bits();
  final SecureKeyStore _keyStore;

  SecureDataCodec({SecureKeyStore? keyStore})
      : _keyStore = keyStore ?? const IosSecureKeyStore();

  Future<List<List<int>>> _keychainKeys() async {
    final keys = <List<int>>[];
    for (final encoded in await _keyStore.readAll(keyName)) {
      try {
        final bytes = base64Url.decode(encoded);
        if (bytes.length == 32) keys.add(bytes);
      } catch (_) {}
    }
    return keys;
  }

  Future<List<int>?> _legacyMirrorKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(mirrorPreferenceKey);
      if (encoded == null || encoded.isEmpty) return null;
      final bytes = base64Url.decode(encoded);
      return bytes.length == 32 ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  @Deprecated('v13 stores keys in Keychain only')
  Future<bool> get mirrorFallbackEnabled async {
    return false;
  }

  Future<bool> _writeKeychain(List<int> bytes) =>
      _keyStore.writeAll(keyName, base64Url.encode(bytes));

  Future<void> _deleteMirror() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(mirrorPreferenceKey);
    await prefs.remove(mirrorOptInPreferenceKey);
  }

  Future<bool> _acceptVerifiedKey(List<int> bytes) async {
    final keychainReady = await _writeKeychain(bytes);
    if (keychainReady) {
      // لا نحذف نسخة v12 إلا بعد إثبات أن المفتاح أصبح في Keychain.
      await _deleteMirror();
    }
    return keychainReady;
  }

  Future<List<int>> _primaryKey() async {
    final keychain = await _keychainKeys();
    if (keychain.isNotEmpty) return keychain.first;

    // ترحيل v12 متأخر: لا نقرأ المرآة إلا بعد غياب كل مفاتيح Keychain.
    final mirror = await _legacyMirrorKey();
    if (mirror != null) {
      if (await _acceptVerifiedKey(mirror)) return mirror;
      throw const SecureDataException(
        'تعذر ترحيل مفتاح البيانات القديم إلى Keychain. لم تُحفظ أي بيانات جديدة.',
      );
    }

    final generated = await _cipher.newSecretKey();
    final bytes = await generated.extractBytes();
    final keychainReady = await _writeKeychain(bytes);
    if (!keychainReady) {
      throw const SecureDataException(
        'تعذر إنشاء مفتاح آمن في Keychain. لم تُحفظ أي بيانات جديدة.',
      );
    }
    return bytes;
  }

  /// واجهة توافق قديمة: لا يمكن تفعيل المرآة في v13. يسمح التعطيل فقط بعد
  /// التحقق من أن Keychain يستطيع فك السجل الحالي.
  Future<bool> setMirrorFallbackEnabled(
    bool enabled, {
    String? verificationPayload,
  }) async {
    if (enabled) return false;

    final keychain = await _keychainKeys();
    if (keychain.isEmpty) return false;
    if (verificationPayload != null && verificationPayload.isNotEmpty) {
      final box = _decodeBox(verificationPayload);
      if (box == null) return false;
      var verified = false;
      for (final key in keychain) {
        if (await _tryDecrypt(box, key) != null) {
          verified = true;
          break;
        }
      }
      if (!verified) return false;
    }
    await _deleteMirror();
    return true;
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
    } on SecureDataException {
      rethrow;
    } catch (_) {
      throw const SecureDataException('تعذر تشفير البيانات محليًا.');
    }
  }

  Future<String> decrypt(String payload) async {
    final box = _decodeBox(payload);
    if (box == null) {
      throw const SecureDataException('صيغة البيانات المشفرة غير صالحة.');
    }

    // المرحلة الأولى: Keychain فقط.
    for (final keyBytes in await _keychainKeys()) {
      final clear = await _tryDecrypt(box, keyBytes);
      if (clear != null) {
        await _acceptVerifiedKey(keyBytes);
        return clear;
      }
    }

    // المرحلة الثانية: ترحيل نسخة v12 بعد فشل كل مفاتيح Keychain فعليًا.
    final mirror = await _legacyMirrorKey();
    if (mirror != null) {
      final clear = await _tryDecrypt(box, mirror);
      if (clear != null) {
        // عند فشل Keychain نعيد البيانات للقراءة فقط ونبقي النسخة القديمة
        // للمحاولة التالية؛ مسار الكتابة سيفشل مغلقًا كي لا نفقد البيانات.
        await _acceptVerifiedKey(mirror);
        return clear;
      }
    }
    throw const SecureDataException('تعذر فك تشفير البيانات المحلية.');
  }

  SecretBox? _decodeBox(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic> || data['v'] != 1) return null;
      return SecretBox(
        base64Url.decode(data['c'] as String),
        nonce: base64Url.decode(data['n'] as String),
        mac: Mac(base64Url.decode(data['m'] as String)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryDecrypt(SecretBox box, List<int> keyBytes) async {
    try {
      final clear = await _cipher.decrypt(
        box,
        secretKey: SecretKey(keyBytes),
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteAllKeys() async {
    await _keyStore.deleteAll(keyName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(mirrorPreferenceKey);
    await prefs.remove(mirrorOptInPreferenceKey);
  }
}
