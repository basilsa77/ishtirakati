import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CloudAccountBindingResult { allowed, mismatch }

abstract interface class CloudAccountBindingStore {
  Set<String> getKeys();

  String? getString(String key);

  int? getInt(String key);

  Future<bool> setString(String key, String value);

  Future<bool> setInt(String key, int value);

  Future<bool> remove(String key);
}

class CloudAccountBindingException implements Exception {
  const CloudAccountBindingException();

  @override
  String toString() => 'Cloud account binding storage is unavailable.';
}

/// Binds installation-global local data to one Firebase account without
/// persisting the raw UID. Existing revision keys are migrated in place.
class CloudAccountBinding {
  CloudAccountBinding._();

  static const bindingKey = 'ishtirakati_cloud_account_binding_v1';
  static const revisionKeyPrefix = 'ishtirakati_cloud_revision_v15_';
  static const pendingRevisionKeyPrefix =
      'ishtirakati_cloud_pending_revision_v15_';

  static Future<CloudAccountBindingResult> ensureBound(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return ensureBoundWithStore(
      uid: uid,
      store: _SharedPreferencesCloudAccountBindingStore(preferences),
    );
  }

  static Future<String> fingerprint(String uid) async {
    if (uid.isEmpty) throw const CloudAccountBindingException();
    final hash = await Sha256().hash(utf8.encode(uid));
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  @visibleForTesting
  static Future<CloudAccountBindingResult> ensureBoundWithStore({
    required String uid,
    required CloudAccountBindingStore store,
  }) async {
    final accountFingerprint = await fingerprint(uid);
    final storedBinding = store.getString(bindingKey);
    if (storedBinding != null && storedBinding != accountFingerprint) {
      return CloudAccountBindingResult.mismatch;
    }

    const prefixes = <String>[revisionKeyPrefix, pendingRevisionKeyPrefix];
    final allowedSuffixes = <String>{uid, accountFingerprint};
    for (final key in store.getKeys()) {
      for (final prefix in prefixes) {
        if (key.startsWith(prefix) &&
            !allowedSuffixes.contains(key.substring(prefix.length))) {
          return CloudAccountBindingResult.mismatch;
        }
      }
    }

    for (final prefix in prefixes) {
      final legacyKey = '$prefix$uid';
      final fingerprintKey = '$prefix$accountFingerprint';
      if (!store.getKeys().contains(legacyKey)) continue;

      final legacyRevision = store.getInt(legacyKey);
      if (legacyRevision == null) throw const CloudAccountBindingException();
      final migratedRevision = store.getInt(fingerprintKey);
      if (migratedRevision != null && migratedRevision != legacyRevision) {
        throw const CloudAccountBindingException();
      }
      if (migratedRevision == null) {
        if (!await store.setInt(fingerprintKey, legacyRevision) ||
            store.getInt(fingerprintKey) != legacyRevision) {
          throw const CloudAccountBindingException();
        }
      }
    }

    if (storedBinding == null) {
      if (!await store.setString(bindingKey, accountFingerprint) ||
          store.getString(bindingKey) != accountFingerprint) {
        throw const CloudAccountBindingException();
      }
    }

    for (final prefix in prefixes) {
      final legacyKey = '$prefix$uid';
      if (!store.getKeys().contains(legacyKey)) continue;
      if (!await store.remove(legacyKey) ||
          store.getKeys().contains(legacyKey)) {
        throw const CloudAccountBindingException();
      }
    }
    return CloudAccountBindingResult.allowed;
  }
}

class _SharedPreferencesCloudAccountBindingStore
    implements CloudAccountBindingStore {
  final SharedPreferences preferences;

  const _SharedPreferencesCloudAccountBindingStore(this.preferences);

  @override
  Set<String> getKeys() => preferences.getKeys();

  @override
  int? getInt(String key) => preferences.getInt(key);

  @override
  String? getString(String key) => preferences.getString(key);

  @override
  Future<bool> remove(String key) => preferences.remove(key);

  @override
  Future<bool> setInt(String key, int value) => preferences.setInt(key, value);

  @override
  Future<bool> setString(String key, String value) =>
      preferences.setString(key, value);
}
