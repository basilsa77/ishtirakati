import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A safe, non-sensitive error for email identity persistence failures.
class EmailIdentityStorageException implements Exception {
  const EmailIdentityStorageException();

  @override
  String toString() => 'Email identity storage is unavailable.';
}

/// Separates the canonical Keychain item from historical Keychain locations.
///
/// The canonical item deliberately uses a new key name. Older releases used
/// the same key with different Keychain accessibility options, which makes it
/// impossible to delete only the legacy item reliably on every plugin version.
abstract interface class EmailIdentityKeychain {
  Future<String?> readCanonical();

  Future<void> writeCanonical(String email);

  Future<void> deleteCanonical();

  Future<List<String>> readLegacy();

  Future<void> deleteLegacy();
}

class IosEmailIdentityKeychain implements EmailIdentityKeychain {
  const IosEmailIdentityKeychain();

  static const String canonicalKey = 'ishtirakati_linked_email_v3';
  static const String legacyKey = 'ishtirakati_linked_email_v2';

  static const FlutterSecureStorage _canonicalStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  // These are the accessibility modes used by this project historically.
  // Reading every location also lets deletion verification fail closed.
  static const List<FlutterSecureStorage> _legacyStorages = [
    FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
    FlutterSecureStorage(),
    FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  ];

  @override
  Future<String?> readCanonical() => _canonicalStorage.read(key: canonicalKey);

  @override
  Future<void> writeCanonical(String email) =>
      _canonicalStorage.write(key: canonicalKey, value: email);

  @override
  Future<void> deleteCanonical() => _canonicalStorage.delete(key: canonicalKey);

  @override
  Future<List<String>> readLegacy() async {
    final values = <String>{};
    for (final storage in _legacyStorages) {
      final value = await storage.read(key: legacyKey);
      if (value != null && value.trim().isNotEmpty) values.add(value.trim());
    }
    return values.toList(growable: false);
  }

  @override
  Future<void> deleteLegacy() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final storage in _legacyStorages) {
      try {
        await storage.delete(key: legacyKey);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}

/// Owns the complete lifecycle of the locally remembered email address.
///
/// Operations are serialized so an initialization migration cannot race with
/// an explicit opt-out and recreate an identity that the user just forgot.
class EmailIdentityStore {
  EmailIdentityStore({EmailIdentityKeychain? keychain})
    : _keychain = keychain ?? const IosEmailIdentityKeychain();

  static final EmailIdentityStore instance = EmailIdentityStore();

  static const String legacyPreferenceKey = 'ishtirakati_linked_email';

  final EmailIdentityKeychain _keychain;
  Future<void> _pending = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  /// Reads the canonical identity and migrates legacy copies when necessary.
  /// Legacy data is removed only after a verified canonical Keychain write.
  Future<String?> readAndMigrate() => _serialized(_readAndMigrate);

  /// Saves to the canonical Keychain item, verifies it, then removes legacy
  /// Keychain and SharedPreferences copies.
  Future<void> remember(String email) => _serialized(() async {
    final normalized = email.trim();
    if (normalized.isEmpty) throw const EmailIdentityStorageException();

    try {
      await _keychain.writeCanonical(normalized);
      final written = (await _keychain.readCanonical())?.trim();
      if (written != normalized) {
        throw const EmailIdentityStorageException();
      }
      await _deleteAndVerifyLegacy();
    } on EmailIdentityStorageException {
      rethrow;
    } catch (_) {
      throw const EmailIdentityStorageException();
    }
  });

  /// Removes every current and historical identity copy and verifies absence.
  /// A partial deletion is never reported as success.
  Future<void> forget() => _serialized(_forget);

  Future<String?> _readAndMigrate() async {
    try {
      final canonical = (await _keychain.readCanonical())?.trim() ?? '';
      if (canonical.isNotEmpty) {
        await _deleteAndVerifyLegacy();
        return canonical;
      }

      final legacyKeychainValues =
          (await _keychain.readLegacy())
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet();
      if (legacyKeychainValues.length > 1) {
        throw const EmailIdentityStorageException();
      }

      final prefs = await SharedPreferences.getInstance();
      final legacyPreference =
          prefs.getString(legacyPreferenceKey)?.trim() ?? '';
      final candidate =
          legacyKeychainValues.isNotEmpty
              ? legacyKeychainValues.single
              : legacyPreference;

      if (candidate.isEmpty) {
        await _forget();
        return null;
      }

      await _keychain.writeCanonical(candidate);
      final written = (await _keychain.readCanonical())?.trim();
      if (written != candidate) {
        throw const EmailIdentityStorageException();
      }
      await _deleteAndVerifyLegacy();
      return candidate;
    } on EmailIdentityStorageException {
      rethrow;
    } catch (_) {
      throw const EmailIdentityStorageException();
    }
  }

  Future<void> _forget() async {
    // Attempt every deletion before verification, even if one backend fails.
    try {
      await _keychain.deleteCanonical();
    } catch (_) {}
    try {
      await _keychain.deleteLegacy();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(legacyPreferenceKey);
    } catch (_) {}

    try {
      final canonical = (await _keychain.readCanonical())?.trim() ?? '';
      final legacy = (await _keychain.readLegacy()).where(
        (value) => value.trim().isNotEmpty,
      );
      final prefs = await SharedPreferences.getInstance();
      final preference = prefs.getString(legacyPreferenceKey)?.trim() ?? '';
      if (canonical.isNotEmpty || legacy.isNotEmpty || preference.isNotEmpty) {
        throw const EmailIdentityStorageException();
      }
    } on EmailIdentityStorageException {
      rethrow;
    } catch (_) {
      throw const EmailIdentityStorageException();
    }
  }

  Future<void> _deleteAndVerifyLegacy() async {
    try {
      await _keychain.deleteLegacy();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(legacyPreferenceKey);
    } catch (_) {}

    try {
      final legacy = (await _keychain.readLegacy()).where(
        (value) => value.trim().isNotEmpty,
      );
      final prefs = await SharedPreferences.getInstance();
      final preference = prefs.getString(legacyPreferenceKey)?.trim() ?? '';
      if (legacy.isNotEmpty || preference.isNotEmpty) {
        throw const EmailIdentityStorageException();
      }
    } on EmailIdentityStorageException {
      rethrow;
    } catch (_) {
      throw const EmailIdentityStorageException();
    }
  }
}
