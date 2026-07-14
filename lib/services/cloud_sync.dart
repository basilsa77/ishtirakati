/// المزامنة السحابية: نسخة من بياناتك في مستند خاص بحسابك في Firestore،
/// محمي بقواعد أمان تمنع أي مستخدم آخر من قراءته.
/// محلي أولًا: التطبيق يعمل كاملًا بدون تسجيل دخول.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'auth_service.dart';
import 'subscription_store.dart';

enum CloudSyncPhase { idle, syncing, success, failure }

enum CloudSyncFailure {
  none,
  unauthenticated,
  storageLocked,
  payloadTooLarge,
  invalidBackup,
  timeout,
  offline,
  permissionDenied,
  conflict,
  unknown,
}

class CloudSyncStatus {
  final CloudSyncPhase phase;
  final DateTime? updatedAt;
  final CloudSyncFailure failure;
  final String? message;

  const CloudSyncStatus(
    this.phase, {
    this.updatedAt,
    this.failure = CloudSyncFailure.none,
    this.message,
  });
}

class CloudSyncResult {
  final bool success;
  final int imported;
  final CloudSyncFailure failure;

  const CloudSyncResult._({
    required this.success,
    this.imported = 0,
    this.failure = CloudSyncFailure.none,
  });

  const CloudSyncResult.success({int imported = 0})
      : this._(success: true, imported: imported);

  const CloudSyncResult.failed(CloudSyncFailure failure)
      : this._(success: false, failure: failure);
}

class CloudSync {
  CloudSync._();

  static bool _pushQueued = false;
  static const _schemaVersion = 1;
  static const _maxBackupBytes = 850000;
  static const _networkTimeout = Duration(seconds: 10);
  static const _revisionKeyPrefix = 'ishtirakati_cloud_revision_v15_';
  static final ValueNotifier<CloudSyncStatus> status =
      ValueNotifier(const CloudSyncStatus(CloudSyncPhase.idle));

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  static bool _fail(CloudSyncFailure failure, String message) {
    status.value = CloudSyncStatus(
      CloudSyncPhase.failure,
      failure: failure,
      message: message,
    );
    return false;
  }

  @visibleForTesting
  static String messageForFirebaseCode(String code) => switch (code) {
        'permission-denied' => tr('cloudPermissionDenied'),
        'unauthenticated' => tr('cloudUnauthenticated'),
        'not-found' => tr('cloudResourceNotFound'),
        'unavailable' || 'network-request-failed' => tr('cloudOffline'),
        'deadline-exceeded' => tr('cloudTimeout'),
        _ => tr('cloudFirebaseError', {'code': code}),
      };

  static CloudSyncFailure _failureForFirebaseCode(String code) =>
      switch (code) {
        'permission-denied' => CloudSyncFailure.permissionDenied,
        'unauthenticated' => CloudSyncFailure.unauthenticated,
        'unavailable' || 'network-request-failed' => CloudSyncFailure.offline,
        'deadline-exceeded' => CloudSyncFailure.timeout,
        _ => CloudSyncFailure.unknown,
      };

  static bool _failFirebase(FirebaseException error) {
    debugPrint('Cloud sync failed with Firebase code: ${error.code}.');
    return _fail(
      _failureForFirebaseCode(error.code),
      messageForFirebaseCode(error.code),
    );
  }

  @visibleForTesting
  static bool canPushRevision({
    required int localRevision,
    required int remoteRevision,
    required bool remoteExists,
  }) =>
      !remoteExists || localRevision == remoteRevision;

  static Future<int> _localRevision(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_revisionKeyPrefix$uid') ?? 0;
  }

  static Future<void> _saveLocalRevision(String uid, int revision) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_revisionKeyPrefix$uid', revision);
  }

  /// رفع نسخة كاملة من البيانات إلى حساب المستخدم.
  static Future<bool> push() async {
    final doc = _doc();
    final uid = AuthService.currentUser?.uid;
    if (doc == null) {
      return _fail(
        CloudSyncFailure.unauthenticated,
        tr('cloudSignInToSync'),
      );
    }
    if (uid == null) {
      return _fail(
        CloudSyncFailure.unauthenticated,
        tr('cloudSignInToSync'),
      );
    }
    if (!SubscriptionStore.instance.storageHealthy) {
      return _fail(
        CloudSyncFailure.storageLocked,
        tr('cloudStorageLocked'),
      );
    }
    status.value = const CloudSyncStatus(CloudSyncPhase.syncing);
    try {
      final backup = SubscriptionStore.instance.exportJson();
      if (utf8.encode(backup).length > _maxBackupBytes) {
        return _fail(
          CloudSyncFailure.payloadTooLarge,
          tr('cloudPayloadTooLarge'),
        );
      }
      final localRevision = await _localRevision(uid);
      final nextRevision = await FirebaseFirestore.instance
          .runTransaction<int>((transaction) async {
            final snapshot = await transaction.get(doc);
            final remoteRevision =
                (snapshot.data()?['revision'] as num?)?.toInt() ?? 0;
            if (!canPushRevision(
              localRevision: localRevision,
              remoteRevision: remoteRevision,
              remoteExists: snapshot.exists,
            )) {
              throw const _CloudRevisionConflict();
            }
            final next = remoteRevision + 1;
            transaction.set(doc, {
              'backup': backup,
              'updatedAt': FieldValue.serverTimestamp(),
              'schemaVersion': _schemaVersion,
              'revision': next,
            });
            return next;
          })
          .timeout(_networkTimeout);
      await _saveLocalRevision(uid, nextRevision);
      status.value = CloudSyncStatus(
        CloudSyncPhase.success,
        updatedAt: DateTime.now(),
      );
      return true;
    } on _CloudRevisionConflict {
      return _fail(
        CloudSyncFailure.conflict,
        tr('cloudConflict'),
      );
    } on TimeoutException {
      return _fail(
        CloudSyncFailure.timeout,
        tr('cloudTimeout'),
      );
    } on FirebaseException catch (error) {
      return _failFirebase(error);
    } catch (error) {
      debugPrint('Cloud push failed (${error.runtimeType}).');
      return _fail(
        CloudSyncFailure.unknown,
        tr('cloudSyncUnknown'),
      );
    }
  }

  /// جلب النسخة السحابية ودمجها مع المحلي.
  /// يعيد عدد العناصر المستوردة، -1 إن لم توجد نسخة أو فشل الجلب.
  static Future<int> pull() async {
    final doc = _doc();
    final uid = AuthService.currentUser?.uid;
    if (doc == null) {
      _fail(
        CloudSyncFailure.unauthenticated,
        tr('cloudSignInToRestore'),
      );
      return -1;
    }
    if (uid == null) return -1;
    status.value = const CloudSyncStatus(CloudSyncPhase.syncing);
    try {
      final snap = await doc.get().timeout(_networkTimeout);
      final data = snap.data();
      final raw = data?['backup'] as String?;
      final schemaVersion = data?['schemaVersion'];
      final revision = (data?['revision'] as num?)?.toInt() ?? 0;
      if (raw == null || raw.isEmpty ||
          (schemaVersion != null && schemaVersion != _schemaVersion) ||
          utf8.encode(raw).length > _maxBackupBytes) {
        _fail(
          CloudSyncFailure.invalidBackup,
          tr('cloudInvalidBackup'),
        );
        return -1;
      }
      final count = await SubscriptionStore.instance.importJson(raw);
      if (count >= 0) await _saveLocalRevision(uid, revision);
      status.value = CloudSyncStatus(
        count >= 0 ? CloudSyncPhase.success : CloudSyncPhase.failure,
        updatedAt: count >= 0 ? DateTime.now() : null,
      );
      return count;
    } on TimeoutException {
      _fail(
        CloudSyncFailure.timeout,
        tr('cloudRestoreTimeout'),
      );
      return -1;
    } on FirebaseException catch (error) {
      _failFirebase(error);
      return -1;
    } catch (error) {
      debugPrint('Cloud pull failed (${error.runtimeType}).');
      _fail(
        CloudSyncFailure.unknown,
        tr('cloudRestoreUnknown'),
      );
      return -1;
    }
  }

  /// Restores a backup before uploading the latest local state.
  static Future<CloudSyncResult> restoreAndPush() async {
    final doc = _doc();
    if (doc == null) {
      _fail(
        CloudSyncFailure.unauthenticated,
        tr('cloudSignInToSync'),
      );
      return const CloudSyncResult.failed(CloudSyncFailure.unauthenticated);
    }
    try {
      final exists = (await doc.get().timeout(_networkTimeout)).exists;
      if (!exists) {
        final uploaded = await push();
        return uploaded
            ? const CloudSyncResult.success()
            : CloudSyncResult.failed(status.value.failure);
      }
      final restored = await pull();
      if (restored < 0) {
        return CloudSyncResult.failed(status.value.failure);
      }
      final uploaded = await push();
      return uploaded
          ? CloudSyncResult.success(imported: restored)
          : CloudSyncResult.failed(status.value.failure);
    } on TimeoutException {
      _fail(
        CloudSyncFailure.timeout,
        tr('cloudTimeout'),
      );
      return const CloudSyncResult.failed(CloudSyncFailure.timeout);
    } on FirebaseException catch (error) {
      _failFirebase(error);
      return CloudSyncResult.failed(status.value.failure);
    } catch (error) {
      debugPrint('Cloud restore failed (${error.runtimeType}).');
      _fail(
        CloudSyncFailure.unknown,
        tr('cloudAccountSyncUnknown'),
      );
      return const CloudSyncResult.failed(CloudSyncFailure.unknown);
    }
  }

  /// Uploads first, then resolves a genuine revision conflict by restoring
  /// and merging the newer cloud copy before retrying once.
  static Future<CloudSyncResult> syncNow() async {
    final uploaded = await push();
    if (uploaded) return const CloudSyncResult.success();
    if (status.value.failure != CloudSyncFailure.conflict) {
      return CloudSyncResult.failed(status.value.failure);
    }
    return restoreAndPush();
  }

  /// حذف النسخة الخاصة بالمستخدم قبل حذف حساب المصادقة.
  static Future<void> deleteRemoteData() async {
    final doc = _doc();
    final uid = AuthService.currentUser?.uid;
    if (doc == null) throw StateError('No authenticated cloud document.');
    await doc.delete().timeout(_networkTimeout);
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_revisionKeyPrefix$uid');
    }
    status.value = const CloudSyncStatus(CloudSyncPhase.idle);
  }

  /// رفع مؤجل بعد كل تعديل (يجمع التعديلات المتتابعة في رفعة واحدة).
  static void schedulePush() {
    if (!AuthService.isSignedIn ||
        !SubscriptionStore.instance.storageHealthy ||
        _pushQueued) {
      return;
    }
    _pushQueued = true;
    Future.delayed(const Duration(seconds: 4), () async {
      _pushQueued = false;
      await push();
    });
  }
}

class _CloudRevisionConflict implements Exception {
  const _CloudRevisionConflict();
}
