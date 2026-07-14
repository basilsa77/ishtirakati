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
import 'firebase_build_config.dart';
import 'firestore_rest_fallback.dart';
import 'firestore_retry.dart';

enum CloudSyncPhase { idle, syncing, queued, success, failure }

enum CloudSyncDelivery {
  none,
  serverConfirmed,
  queuedLocally,
  failed,
  conflict,
}

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
  final String? operation;
  final String? firebaseCode;
  final bool? documentExisted;
  final int? revision;
  final CloudSyncDelivery delivery;
  final int attemptCount;
  final int? retryDelayMs;
  final String? firebasePlugin;
  final String? firebaseMessage;
  final String? exceptionType;
  final bool? hasPendingWrites;
  final int? restHttpStatus;
  final String? restOutcome;

  const CloudSyncStatus(
    this.phase, {
    this.updatedAt,
    this.failure = CloudSyncFailure.none,
    this.message,
    this.operation,
    this.firebaseCode,
    this.documentExisted,
    this.revision,
    this.delivery = CloudSyncDelivery.none,
    this.attemptCount = 0,
    this.retryDelayMs,
    this.firebasePlugin,
    this.firebaseMessage,
    this.exceptionType,
    this.hasPendingWrites,
    this.restHttpStatus,
    this.restOutcome,
  });

  CloudSyncStatus copyWith({
    CloudSyncPhase? phase,
    DateTime? updatedAt,
    CloudSyncFailure? failure,
    String? message,
    String? operation,
    String? firebaseCode,
    bool? documentExisted,
    int? revision,
    CloudSyncDelivery? delivery,
    int? attemptCount,
    int? retryDelayMs,
    String? firebasePlugin,
    String? firebaseMessage,
    String? exceptionType,
    bool? hasPendingWrites,
    int? restHttpStatus,
    String? restOutcome,
  }) =>
      CloudSyncStatus(
        phase ?? this.phase,
        updatedAt: updatedAt ?? this.updatedAt,
        failure: failure ?? this.failure,
        message: message ?? this.message,
        operation: operation ?? this.operation,
        firebaseCode: firebaseCode ?? this.firebaseCode,
        documentExisted: documentExisted ?? this.documentExisted,
        revision: revision ?? this.revision,
        delivery: delivery ?? this.delivery,
        attemptCount: attemptCount ?? this.attemptCount,
        retryDelayMs: retryDelayMs ?? this.retryDelayMs,
        firebasePlugin: firebasePlugin ?? this.firebasePlugin,
        firebaseMessage: firebaseMessage ?? this.firebaseMessage,
        exceptionType: exceptionType ?? this.exceptionType,
        hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
        restHttpStatus: restHttpStatus ?? this.restHttpStatus,
        restOutcome: restOutcome ?? this.restOutcome,
      );
}

enum CloudSyncWriteOperation { firstCreate, transactionUpdate }

class CloudSyncWriteOutcome {
  final CloudSyncWriteOperation operation;
  final bool documentExisted;
  final int revision;
  final CloudSyncDelivery delivery;
  final int attempts;
  final int? restHttpStatus;

  const CloudSyncWriteOutcome({
    required this.operation,
    required this.documentExisted,
    required this.revision,
    this.delivery = CloudSyncDelivery.serverConfirmed,
    this.attempts = 1,
    this.restHttpStatus,
  });
}

class CloudSyncResult {
  final bool success;
  final int imported;
  final CloudSyncFailure failure;
  final bool queued;

  const CloudSyncResult._({
    required this.success,
    this.imported = 0,
    this.failure = CloudSyncFailure.none,
    this.queued = false,
  });

  const CloudSyncResult.success({int imported = 0})
      : this._(success: true, imported: imported);

  const CloudSyncResult.failed(CloudSyncFailure failure)
      : this._(success: false, failure: failure);

  const CloudSyncResult.queued()
      : this._(success: false, queued: true);
}

class CloudSync {
  CloudSync._();

  static const internalDiagnosticsEnabled =
      FirebaseBuildConfig.internalBuild;
  static bool _pushQueued = false;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _pendingConfirmationSubscription;
  static const _schemaVersion = 2;
  static const _legacySchemaVersion = 1;
  static const _encryption = 'AES-256-GCM';
  /// The production project uses Firestore's default database. Named database
  /// instances must not be used for this path.
  static const databaseId = '(default)';
  static const _maxBackupBytes = 850000;
  static const _revisionKeyPrefix = 'ishtirakati_cloud_revision_v15_';
  static const _pendingRevisionKeyPrefix =
      'ishtirakati_cloud_pending_revision_v15_';
  static final ValueNotifier<CloudSyncStatus> status =
      ValueNotifier(const CloudSyncStatus(CloudSyncPhase.idle));

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  static const _safeDocumentPath = 'users/<uid>';

  static bool _fail(CloudSyncFailure failure, String message) {
    status.value = status.value.copyWith(
      phase: CloudSyncPhase.failure,
      failure: failure,
      message: message,
      delivery: failure == CloudSyncFailure.conflict
          ? CloudSyncDelivery.conflict
          : CloudSyncDelivery.failed,
    );
    return false;
  }

  static void _setSyncing() {
    status.value = CloudSyncStatus(
      CloudSyncPhase.syncing,
      updatedAt: status.value.updatedAt,
    );
  }

  static void _setWriteDiagnostics({
    required String operation,
    required bool? documentExisted,
    required int revision,
  }) {
    status.value = status.value.copyWith(
      phase: CloudSyncPhase.syncing,
      operation: operation,
      documentExisted: documentExisted,
      revision: revision,
      delivery: CloudSyncDelivery.none,
    );
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
  static bool isMissingFirestoreDocumentException(
    FirebaseException error,
  ) {
    if (error.code != 'not-found') return false;
    final message = error.message ?? '';
    return !isFirestoreDatabaseMissingMessage(message) &&
        isFirestoreDocumentMissingMessage(message);
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

  @visibleForTesting
  static bool isRetryableFirebaseCode(String code) {
    return FirestoreRetry.isRetryableCode(code);
  }

  static Future<T> _runFirestoreOperation<T>(
    Future<T> Function() operation,
    {
    String operationName = 'firestore-operation',
  }) =>
      FirestoreRetry.run(
        operation: operationName,
        action: operation,
        onEvent: (event) {
          status.value = status.value.copyWith(
            operation: event.operation,
            attemptCount: event.attempt,
            retryDelayMs: event.nextDelayMs,
            firebaseCode: event.code,
          );
          if (event.nextDelayMs != null) {
            debugPrint(
              'Cloud sync retry: operation=${event.operation} '
              'attempt=${event.attempt}/${event.maxAttempts} '
              'code=${event.code} delayMs=${event.nextDelayMs}.',
            );
          }
        },
      );

  static bool _failFirebase(
    FirebaseException error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    final uid = AuthService.currentUser?.uid;
    final safeMessage = sanitizeFirebaseMessage(
      error.message ?? '',
      uid: uid ?? '',
    );
    status.value = status.value.copyWith(
      firebaseCode: error.code,
      firebasePlugin: error.plugin,
      firebaseMessage: safeMessage,
      exceptionType: error.runtimeType.toString(),
    );
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

  @visibleForTesting
  static String sanitizeFirebaseMessage(String message, {required String uid}) {
    var safe = message;
    if (uid.isNotEmpty) {
      safe = safe
          .replaceAll(uid, '<uid>')
          .replaceAll(Uri.encodeComponent(uid), '<uid>');
    }
    safe = safe
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9._~-]+', caseSensitive: false),
          'Bearer <token>',
        )
        .replaceAll(
          RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
          '<email>',
        )
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .trim();
    return safe.length <= 500 ? safe : safe.substring(0, 500);
  }

  static String _safeFirebaseTarget() {
    final options = Firebase.app().options;
    return 'project=${options.projectId} database=$databaseId '
        'document=$_safeDocumentPath';
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
    await prefs.remove('$_pendingRevisionKeyPrefix$uid');
  }

  static Future<void> _savePendingRevision(String uid, int revision) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_pendingRevisionKeyPrefix$uid', revision);
  }

  @visibleForTesting
  static bool shouldPersistConfirmedRevision(CloudSyncDelivery delivery) =>
      delivery == CloudSyncDelivery.serverConfirmed;

  @visibleForTesting
  static bool shouldUseRestFallback({
    required bool enabled,
    required int localRevision,
    required String firebaseCode,
  }) =>
      enabled &&
      localRevision == 0 &&
      (firebaseCode == 'unavailable' ||
          firebaseCode == 'deadline-exceeded');

  static Future<bool> _hasPendingFirstCreate(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    if (!FirebaseBuildConfig.offlineQueueEnabled) return false;
    try {
      final snapshot = await doc.get(const GetOptions(source: Source.cache));
      final revision = (snapshot.data()?['revision'] as num?)?.toInt();
      return snapshot.exists &&
          revision == 1 &&
          snapshot.metadata.hasPendingWrites;
    } catch (_) {
      return false;
    }
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
    _setSyncing();
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
      firebaseOperation = 'firestore.sync-transaction';
      _logFirebaseOperation(firebaseOperation);
      final outcome = await _writeCloudDocument(
        doc,
        backup,
        localRevision,
      );
      if (shouldPersistConfirmedRevision(outcome.delivery)) {
        await _saveLocalRevision(uid, outcome.revision);
      } else {
        await _savePendingRevision(uid, outcome.revision);
      }
      if (outcome.delivery == CloudSyncDelivery.queuedLocally) {
        status.value = status.value.copyWith(
          phase: CloudSyncPhase.queued,
          updatedAt: DateTime.now(),
          message: tr('cloudQueuedLocally'),
          operation: 'first-create',
          documentExisted: false,
          revision: outcome.revision,
          delivery: CloudSyncDelivery.queuedLocally,
          hasPendingWrites: true,
          restHttpStatus: outcome.restHttpStatus,
        );
        _watchPendingConfirmation(doc, uid, outcome.revision);
        return false;
      }
      status.value = CloudSyncStatus(
        CloudSyncPhase.success,
        updatedAt: DateTime.now(),
        message: outcome.operation == CloudSyncWriteOperation.firstCreate
            ? tr('cloudFirstCreateSuccess')
            : tr('cloudUpdateSuccess'),
        operation: outcome.operation == CloudSyncWriteOperation.firstCreate
            ? 'first-create'
            : 'transaction-update',
        documentExisted: outcome.documentExisted,
        revision: outcome.revision,
        delivery: CloudSyncDelivery.serverConfirmed,
        attemptCount: outcome.attempts,
        hasPendingWrites: false,
        restHttpStatus: outcome.restHttpStatus,
        restOutcome: status.value.restOutcome,
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
        operation: status.value.operation ?? firebaseOperation,
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

  static void _watchPendingConfirmation(
    DocumentReference<Map<String, dynamic>> doc,
    String uid,
    int expectedRevision,
  ) {
    unawaited(_pendingConfirmationSubscription?.cancel());
    _pendingConfirmationSubscription = doc
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) async {
      final revision = (snapshot.data()?['revision'] as num?)?.toInt();
      if (!snapshot.exists ||
          revision != expectedRevision ||
          snapshot.metadata.hasPendingWrites ||
          snapshot.metadata.isFromCache ||
          AuthService.currentUser?.uid != uid) {
        return;
      }
      await _saveLocalRevision(uid, expectedRevision);
      status.value = status.value.copyWith(
        phase: CloudSyncPhase.success,
        updatedAt: DateTime.now(),
        message: tr('cloudFirstCreateSuccess'),
        delivery: CloudSyncDelivery.serverConfirmed,
        hasPendingWrites: false,
        revision: expectedRevision,
      );
      await _pendingConfirmationSubscription?.cancel();
      _pendingConfirmationSubscription = null;
    }, onError: (Object error) {
      debugPrint(
        'Pending Firestore confirmation failed (${error.runtimeType}).',
      );
    });
  }

  static Future<CloudSyncWriteOutcome> _writeCloudDocument(
    DocumentReference<Map<String, dynamic>> doc,
    String backup,
    int localRevision,
  ) =>
      writeWithoutPreflightRead(
        localRevision: localRevision,
        firstCreate: () => _createFirstCloudDocument(doc, backup),
        transactionUpdate: () async {
          _setWriteDiagnostics(
            operation: 'transaction-update',
            documentExisted: true,
            revision: localRevision + 1,
          );
          _logFirebaseOperation('firestore.transaction-update');
          final revision = await _runFirestoreOperation(
            () => FirebaseFirestore.instance.runTransaction<int>(
              (transaction) async {
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
              },
            ),
            operationName: 'transaction-update',
          );
          return CloudSyncWriteOutcome(
            operation: CloudSyncWriteOperation.transactionUpdate,
            documentExisted: true,
            revision: revision,
            attempts: status.value.attemptCount,
          );
        },
      );

  static Future<CloudSyncWriteOutcome> _createFirstCloudDocument(
    DocumentReference<Map<String, dynamic>> doc,
    String backup,
  ) async {
    _setWriteDiagnostics(
      operation: 'first-create',
      documentExisted: false,
      revision: 1,
    );
    _logFirebaseOperation('firestore.first-create');
    try {
      await _runFirestoreOperation(
        () => doc.set(
          _encryptedBackupPayload(backup, 1),
          SetOptions(merge: false),
        ),
        operationName: 'first-create',
      );
      return CloudSyncWriteOutcome(
        operation: CloudSyncWriteOperation.firstCreate,
        documentExisted: false,
        revision: 1,
        attempts: status.value.attemptCount,
      );
    } on FirebaseException catch (error) {
      final pending = await _hasPendingFirstCreate(doc);
      status.value = status.value.copyWith(hasPendingWrites: pending);
      if (shouldUseRestFallback(
        enabled: FirebaseBuildConfig.restFallbackEnabled,
        localRevision: 0,
        firebaseCode: error.code,
      )) {
        final user = AuthService.currentUser;
        if (user == null) rethrow;
        final rest = await FirestoreRestFallback.createFirstEncryptedBackup(
          uid: user.uid,
          backup: backup,
          tokenProvider: user.getIdToken,
        );
        status.value = status.value.copyWith(
          restHttpStatus: rest.httpStatus,
          restOutcome: rest.outcome.name,
          attemptCount: status.value.attemptCount + rest.attempts,
          exceptionType: rest.exceptionType,
        );
        if (rest.confirmed) {
          return CloudSyncWriteOutcome(
            operation: CloudSyncWriteOperation.firstCreate,
            documentExisted: false,
            revision: 1,
            attempts: status.value.attemptCount,
            restHttpStatus: rest.httpStatus,
          );
        }
        if (rest.outcome == FirestoreRestCreateOutcome.conflict) {
          throw const _CloudRevisionConflict();
        }
        if (rest.outcome == FirestoreRestCreateOutcome.permissionDenied) {
          throw FirebaseException(
            plugin: 'firestore_rest',
            code: 'permission-denied',
          );
        }
        if (rest.outcome == FirestoreRestCreateOutcome.unauthenticated) {
          throw FirebaseException(
            plugin: 'firestore_rest',
            code: 'unauthenticated',
          );
        }
      }
      if (pending) {
        return CloudSyncWriteOutcome(
          operation: CloudSyncWriteOperation.firstCreate,
          documentExisted: false,
          revision: 1,
          delivery: CloudSyncDelivery.queuedLocally,
          attempts: status.value.attemptCount,
          restHttpStatus: status.value.restHttpStatus,
        );
      }
      rethrow;
    } on TimeoutException {
      final pending = await _hasPendingFirstCreate(doc);
      if (pending) {
        return CloudSyncWriteOutcome(
          operation: CloudSyncWriteOperation.firstCreate,
          documentExisted: false,
          revision: 1,
          delivery: CloudSyncDelivery.queuedLocally,
          attempts: status.value.attemptCount,
        );
      }
      rethrow;
    }
  }

  @visibleForTesting
  static Future<CloudSyncWriteOutcome> writeWithoutPreflightRead({
    required int localRevision,
    required Future<CloudSyncWriteOutcome> Function() firstCreate,
    required Future<CloudSyncWriteOutcome> Function() transactionUpdate,
  }) async {
    if (localRevision == 0) {
      return firstCreate();
    }
    return transactionUpdate();
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
    _setSyncing();
    try {
      final snap = await _runFirestoreOperation(doc.get);
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
      final exists = (await _runFirestoreOperation(
        () => doc.get(const GetOptions(source: Source.server)),
      ))
          .exists;
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
    if (status.value.phase == CloudSyncPhase.queued) {
      return const CloudSyncResult.queued();
    }
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
      await _runFirestoreOperation(doc.delete);
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
      await prefs.remove('$_pendingRevisionKeyPrefix$uid');
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
