/// المزامنة السحابية: نسخة من بياناتك في مستند خاص بحسابك في Firestore،
/// محمي بقواعد أمان تمنع أي مستخدم آخر من قراءته.
/// محلي أولًا: التطبيق يعمل كاملًا بدون تسجيل دخول.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'auth_service.dart';
import 'secure_data_codec.dart';
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
  configuration,
  serviceUnavailable,
  appNotAuthorized,
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
  static const _schemaVersion = 2;
  static const _legacySchemaVersion = 1;
  static const _encryption = 'AES-256-GCM';
  /// The production project uses Firestore's default database. Named database
  /// instances must not be used for this path.
  static const databaseId = '(default)';
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

  static const _safeDocumentPath = 'users/<uid>';

  static bool _fail(CloudSyncFailure failure, String message) {
    status.value = CloudSyncStatus(
      CloudSyncPhase.failure,
      failure: failure,
      message: message,
    );
    return false;
  }

  @visibleForTesting
  static String messageForFirebaseCode(String code) =>
      messageForFirebaseFailure(code: code);

  @visibleForTesting
  static String messageForFirebaseFailure({
    required String code,
    String plugin = '',
    String message = '',
  }) {
    final normalized = code.replaceFirst('storage/', '');
    final isStorage = plugin.contains('storage') || code.startsWith('storage/');
    final isFirestore = plugin.contains('firestore');
    final databaseMissing = isFirestore &&
        normalized == 'not-found' &&
        isFirestoreDatabaseMissingMessage(message);
    final documentMissing = isFirestore &&
        normalized == 'not-found' &&
        isFirestoreDocumentMissingMessage(message);
    return switch (normalized) {
      'permission-denied' => tr('cloudPermissionDenied'),
      'unauthenticated' => tr('cloudUnauthenticated'),
      'not-found' when isStorage => tr('cloudStorageResourceNotFound'),
      'not-found' when databaseMissing =>
        tr('cloudFirestoreDatabaseNotFound'),
      'not-found' when documentMissing => tr('cloudSyncDocumentNotFound'),
      'not-found' when isFirestore => tr('cloudFirestoreResourceNotFound'),
      'not-found' => tr('cloudResourceNotFound'),
      'bucket-not-found' || 'object-not-found' =>
        tr('cloudStorageResourceNotFound'),
      'failed-precondition' => tr('cloudFailedPrecondition'),
      'app-not-authorized' => tr('cloudAppNotAuthorized'),
      'network-request-failed' => tr('cloudOffline'),
      'unavailable' || 'internal' || 'resource-exhausted' =>
        tr('cloudServiceUnavailable'),
      'deadline-exceeded' => tr('cloudTimeout'),
      _ => tr('cloudFirebaseError', {'code': code}),
    };
  }

  @visibleForTesting
  static bool isFirestoreDatabaseMissingMessage(String message) {
    final normalized = message.toLowerCase();
    final saysMissing = normalized.contains('not found') ||
        normalized.contains('does not exist') ||
        normalized.contains('doesn\'t exist') ||
        normalized.contains('not available');
    return normalized.contains('database') && saysMissing;
  }

  @visibleForTesting
  static bool isFirestoreDocumentMissingMessage(String message) {
    final normalized = message.toLowerCase();
    final saysMissing = normalized.contains('not found') ||
        normalized.contains('does not exist') ||
        normalized.contains('doesn\'t exist') ||
        normalized.contains('no document');
    return normalized.contains('document') && saysMissing;
  }

  @visibleForTesting
  static CloudSyncFailure failureForFirebaseCode(String code) {
    final normalized = code.replaceFirst('storage/', '');
    return switch (normalized) {
        'permission-denied' => CloudSyncFailure.permissionDenied,
        'unauthenticated' => CloudSyncFailure.unauthenticated,
        'network-request-failed' => CloudSyncFailure.offline,
        'unavailable' || 'internal' || 'resource-exhausted' =>
          CloudSyncFailure.serviceUnavailable,
        'deadline-exceeded' => CloudSyncFailure.timeout,
        'not-found' || 'failed-precondition' || 'bucket-not-found' ||
        'object-not-found' => CloudSyncFailure.configuration,
        'app-not-authorized' => CloudSyncFailure.appNotAuthorized,
        _ => CloudSyncFailure.unknown,
      };
  }

  static bool _failFirebase(
    FirebaseException error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    final uid = AuthService.currentUser?.uid;
    var safeMessage = error.message ?? '';
    if (uid != null && uid.isNotEmpty) {
      safeMessage = safeMessage.replaceAll(uid, '<uid>');
    }
    safeMessage = safeMessage
        .replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (safeMessage.length > 500) {
      safeMessage = safeMessage.substring(0, 500);
    }
    debugPrint(
      'Cloud sync Firebase failure: operation=$operation '
      'plugin=${error.plugin} code=${error.code} '
      'message=${safeMessage.isEmpty ? '<empty>' : safeMessage} '
      '${_safeFirebaseTarget()}.',
    );
    debugPrintStack(
      label: 'Cloud sync stack ($operation)',
      stackTrace: stackTrace,
    );
    return _fail(
      failureForFirebaseCode(error.code),
      messageForFirebaseFailure(
        code: error.code,
        plugin: error.plugin,
        message: error.message ?? '',
      ),
    );
  }

  static String _safeFirebaseTarget() {
    final options = Firebase.app().options;
    return 'project=${options.projectId} appId=${options.appId} '
        'storageBucket=${options.storageBucket ?? '<none>'} '
        'database=$databaseId document=$_safeDocumentPath';
  }

  static void _logFirebaseOperation(String operation) {
    debugPrint('Cloud sync Firebase target: operation=$operation '
        '${_safeFirebaseTarget()}.');
  }

  @visibleForTesting
  static bool canPushRevision({
    required int localRevision,
    required int remoteRevision,
    required bool remoteExists,
  }) =>
      !remoteExists || localRevision == remoteRevision;

  @visibleForTesting
  static bool shouldCreateInitialCloudDocument({
    required bool remoteExists,
    required int localRevision,
  }) =>
      !remoteExists && localRevision == 0;

  @visibleForTesting
  static CloudSyncFailure preflightFailure({
    required bool signedIn,
    required bool storageHealthy,
  }) {
    if (!signedIn) return CloudSyncFailure.unauthenticated;
    if (!storageHealthy) return CloudSyncFailure.storageLocked;
    return CloudSyncFailure.none;
  }

  @visibleForTesting
  static bool isSupportedCloudSchema(Object? schemaVersion) =>
      schemaVersion == null ||
      schemaVersion == _legacySchemaVersion ||
      schemaVersion == _schemaVersion;

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
    final preflight = preflightFailure(
      signedIn: doc != null && uid != null,
      storageHealthy: SubscriptionStore.instance.storageHealthy,
    );
    if (preflight == CloudSyncFailure.unauthenticated) {
      return _fail(
        CloudSyncFailure.unauthenticated,
        tr('cloudSignInToSync'),
      );
    }
    if (preflight == CloudSyncFailure.storageLocked) {
      return _fail(
        CloudSyncFailure.storageLocked,
        tr('cloudStorageLocked'),
      );
    }
    if (doc == null || uid == null) return false;
    status.value = const CloudSyncStatus(CloudSyncPhase.syncing);
    var firebaseOperation = 'firestore.prepare-encrypted-backup';
    try {
      final backup =
          await SubscriptionStore.instance.exportEncryptedCloudBackup();
      if (utf8.encode(backup).length > _maxBackupBytes) {
        return _fail(
          CloudSyncFailure.payloadTooLarge,
          tr('cloudPayloadTooLarge'),
        );
      }
      final localRevision = await _localRevision(uid);
      firebaseOperation = 'firestore.push-probe';
      _logFirebaseOperation(firebaseOperation);
      final initialSnapshot = await doc
          .get(const GetOptions(source: Source.server))
          .timeout(_networkTimeout);
      late final int nextRevision;
      if (shouldCreateInitialCloudDocument(
        remoteExists: initialSnapshot.exists,
        localRevision: localRevision,
      )) {
        firebaseOperation = 'firestore.create-initial-document';
        nextRevision = await _createInitialCloudDocument(doc, backup);
      } else {
        firebaseOperation = 'firestore.update-transaction';
        nextRevision = await _updateCloudDocument(doc, backup, localRevision);
      }
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
    } on FirebaseException catch (error, stackTrace) {
      return _failFirebase(
        error,
        stackTrace,
        operation: firebaseOperation,
      );
    } on SecureDataException catch (_) {
      return _fail(
        CloudSyncFailure.storageLocked,
        tr('cloudStorageLocked'),
      );
    } catch (error) {
      debugPrint('Cloud push failed (${error.runtimeType}).');
      return _fail(
        CloudSyncFailure.unknown,
        tr('cloudSyncUnknown'),
      );
    }
  }

  static Map<String, Object> _encryptedBackupPayload(
    String backup,
    int revision,
  ) =>
      {
        'backup': backup,
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': _schemaVersion,
        'revision': revision,
        'encryption': _encryption,
      };

  static Future<int> _createInitialCloudDocument(
    DocumentReference<Map<String, dynamic>> doc,
    String backup,
  ) async {
    _logFirebaseOperation('firestore.create-initial-document');
    await doc.set(_encryptedBackupPayload(backup, 1)).timeout(_networkTimeout);
    return 1;
  }

  static Future<int> _updateCloudDocument(
    DocumentReference<Map<String, dynamic>> doc,
    String backup,
    int localRevision,
  ) async {
    _logFirebaseOperation('firestore.update-transaction');
    return FirebaseFirestore.instance
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
          transaction.set(doc, _encryptedBackupPayload(backup, next));
          return next;
        })
        .timeout(_networkTimeout);
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
      final encryption = data?['encryption'];
      final revision = (data?['revision'] as num?)?.toInt() ?? 0;
      if (raw == null ||
          raw.isEmpty ||
          !isSupportedCloudSchema(schemaVersion) ||
          utf8.encode(raw).length > _maxBackupBytes) {
        _fail(
          CloudSyncFailure.invalidBackup,
          tr('cloudInvalidBackup'),
        );
        return -1;
      }
      if (schemaVersion == _schemaVersion && encryption != _encryption) {
        _fail(
          CloudSyncFailure.invalidBackup,
          tr('cloudInvalidBackup'),
        );
        return -1;
      }
      final encrypted = schemaVersion == _schemaVersion;
      final count = encrypted
          ? await SubscriptionStore.instance.importEncryptedCloudBackup(raw)
          : await SubscriptionStore.instance.importJson(raw);
      if (count < 0) {
        _fail(
          encrypted
              ? CloudSyncFailure.storageLocked
              : CloudSyncFailure.invalidBackup,
          encrypted
              ? tr('cloudEncryptedRestoreFailed')
              : tr('cloudInvalidBackup'),
        );
        return -1;
      }
      await _saveLocalRevision(uid, revision);
      status.value = CloudSyncStatus(
        CloudSyncPhase.success,
        updatedAt: DateTime.now(),
      );
      return count;
    } on TimeoutException {
      _fail(
        CloudSyncFailure.timeout,
        tr('cloudRestoreTimeout'),
      );
      return -1;
    } on FirebaseException catch (error, stackTrace) {
      _failFirebase(
        error,
        stackTrace,
        operation: 'firestore.pull-document',
      );
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
    } on FirebaseException catch (error, stackTrace) {
      _failFirebase(
        error,
        stackTrace,
        operation: 'firestore.restore-probe',
      );
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
    try {
      await doc.delete().timeout(_networkTimeout);
    } on FirebaseException catch (error, stackTrace) {
      _failFirebase(
        error,
        stackTrace,
        operation: 'firestore.delete-document',
      );
      rethrow;
    }
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
