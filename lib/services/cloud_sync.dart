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
import 'cloud_account_binding.dart';
import 'secure_data_codec.dart';
import 'subscription_store.dart';
import 'firebase_build_config.dart';
import 'firebase_rest_auth.dart';
import 'firestore_config.dart';
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
  accountMismatch,
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
  }) => CloudSyncStatus(
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

enum CloudSyncWriteOperation { firstCreate, transactionUpdate, restUpdate }

class CloudSyncWriteOutcome {
  final CloudSyncWriteOperation operation;
  final bool documentExisted;
  final int revision;
  final CloudSyncDelivery delivery;
  final int attempts;
  final int? restHttpStatus;
  final String? restOutcome;
  final bool hasPendingWrites;

  const CloudSyncWriteOutcome({
    required this.operation,
    required this.documentExisted,
    required this.revision,
    this.delivery = CloudSyncDelivery.serverConfirmed,
    this.attempts = 1,
    this.restHttpStatus,
    this.restOutcome,
    this.hasPendingWrites = false,
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

  const CloudSyncResult.queued() : this._(success: false, queued: true);
}

enum CloudRestRestoreOutcome { restored, missing, failed }

class CloudRestRestoreResult {
  final CloudRestRestoreOutcome outcome;
  final int imported;
  final CloudSyncFailure failure;

  const CloudRestRestoreResult.restored(this.imported)
    : outcome = CloudRestRestoreOutcome.restored,
      failure = CloudSyncFailure.none;

  const CloudRestRestoreResult.missing()
    : outcome = CloudRestRestoreOutcome.missing,
      imported = 0,
      failure = CloudSyncFailure.none;

  const CloudRestRestoreResult.failed(this.failure)
    : outcome = CloudRestRestoreOutcome.failed,
      imported = 0;
}

class CloudSync {
  CloudSync._();

  static const internalDiagnosticsEnabled = FirebaseBuildConfig.internalBuild;
  static bool _pushQueued = false;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _pendingConfirmationSubscription;
  static const _schemaVersion = 2;
  static const _legacySchemaVersion = 1;
  static const _encryption = 'AES-256-GCM';

  static const _maxBackupBytes = 850000;
  static const _revisionKeyPrefix = CloudAccountBinding.revisionKeyPrefix;
  static const _pendingRevisionKeyPrefix =
      CloudAccountBinding.pendingRevisionKeyPrefix;
  static FirebaseTokenProvider? get _appCheckTokenProvider =>
      FirebaseBuildConfig.appCheckEnabled ? AuthService.getAppCheckToken : null;
  static final ValueNotifier<CloudSyncStatus> status = ValueNotifier(
    const CloudSyncStatus(CloudSyncPhase.idle),
  );

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    return FirestoreConfig.instance.collection('users').doc(user.uid);
  }

  static const _safeDocumentPath = 'users/<uid>';

  static bool _fail(CloudSyncFailure failure, String message) {
    status.value = status.value.copyWith(
      phase: CloudSyncPhase.failure,
      failure: failure,
      message: message,
      delivery:
          failure == CloudSyncFailure.conflict
              ? CloudSyncDelivery.conflict
              : CloudSyncDelivery.failed,
    );
    return false;
  }

  static Future<bool> _ensureAccountBinding(String uid) async {
    try {
      final binding = await CloudAccountBinding.ensureBound(uid);
      if (binding == CloudAccountBindingResult.mismatch) {
        return _fail(
          CloudSyncFailure.accountMismatch,
          tr('cloudAccountMismatch'),
        );
      }
      return true;
    } on CloudAccountBindingException {
      return _fail(
        CloudSyncFailure.storageLocked,
        tr('cloudAccountBindingUnavailable'),
      );
    } catch (_) {
      return _fail(
        CloudSyncFailure.storageLocked,
        tr('cloudAccountBindingUnavailable'),
      );
    }
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
    final databaseMissing =
        isFirestore &&
        normalized == 'not-found' &&
        isFirestoreDatabaseMissingMessage(message);
    final documentMissing =
        isFirestore &&
        normalized == 'not-found' &&
        isFirestoreDocumentMissingMessage(message);
    return switch (normalized) {
      'permission-denied' => tr('cloudPermissionDenied'),
      'unauthenticated' => tr('cloudUnauthenticated'),
      'not-found' when isStorage => tr('cloudStorageResourceNotFound'),
      'not-found' when databaseMissing => tr('cloudFirestoreDatabaseNotFound'),
      'not-found' when documentMissing => tr('cloudSyncDocumentNotFound'),
      'not-found' when isFirestore => tr('cloudFirestoreResourceNotFound'),
      'not-found' => tr('cloudResourceNotFound'),
      'bucket-not-found' ||
      'object-not-found' => tr('cloudStorageResourceNotFound'),
      'failed-precondition' => tr('cloudFailedPrecondition'),
      'app-not-authorized' => tr('cloudAppNotAuthorized'),
      'network-request-failed' => tr('cloudOffline'),
      'unavailable' ||
      'internal' ||
      'resource-exhausted' => tr('cloudServiceUnavailable'),
      'deadline-exceeded' => tr('cloudTimeout'),
      _ => tr('cloudFirebaseError', {'code': code}),
    };
  }

  @visibleForTesting
  static bool isFirestoreDatabaseMissingMessage(String message) {
    final normalized = message.toLowerCase();
    final saysMissing =
        normalized.contains('not found') ||
        normalized.contains('does not exist') ||
        normalized.contains('doesn\'t exist') ||
        normalized.contains('not available');
    return normalized.contains('database') && saysMissing;
  }

  @visibleForTesting
  static bool isFirestoreDocumentMissingMessage(String message) {
    final normalized = message.toLowerCase();
    final saysMissing =
        normalized.contains('not found') ||
        normalized.contains('does not exist') ||
        normalized.contains('doesn\'t exist') ||
        normalized.contains('no document');
    return normalized.contains('document') && saysMissing;
  }

  @visibleForTesting
  static bool isMissingFirestoreDocumentException(FirebaseException error) {
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
      'unavailable' ||
      'internal' ||
      'resource-exhausted' => CloudSyncFailure.serviceUnavailable,
      'deadline-exceeded' => CloudSyncFailure.timeout,
      'not-found' ||
      'failed-precondition' ||
      'bucket-not-found' ||
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
    Future<T> Function() operation, {
    String operationName = 'firestore-operation',
  }) => FirestoreRetry.run(
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
    safe =
        safe
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
    return 'project=${options.projectId} database=${FirestoreConfig.databaseId} '
        'document=$_safeDocumentPath';
  }

  static void _logFirebaseOperation(String operation) {
    debugPrint(
      'Cloud sync Firebase target: operation=$operation '
      '${_safeFirebaseTarget()}.',
    );
  }

  @visibleForTesting
  static bool canPushRevision({
    required int localRevision,
    required int remoteRevision,
    required bool remoteExists,
  }) => !remoteExists || localRevision == remoteRevision;

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
    final fingerprint = await CloudAccountBinding.fingerprint(uid);
    return prefs.getInt('$_revisionKeyPrefix$fingerprint') ?? 0;
  }

  static Future<void> _saveLocalRevision(String uid, int revision) async {
    final prefs = await SharedPreferences.getInstance();
    final fingerprint = await CloudAccountBinding.fingerprint(uid);
    await prefs.setInt('$_revisionKeyPrefix$fingerprint', revision);
    await prefs.remove('$_pendingRevisionKeyPrefix$fingerprint');
  }

  static Future<void> _savePendingRevision(String uid, int revision) async {
    final prefs = await SharedPreferences.getInstance();
    final fingerprint = await CloudAccountBinding.fingerprint(uid);
    await prefs.setInt('$_pendingRevisionKeyPrefix$fingerprint', revision);
  }

  static Future<void> _clearPendingRevision(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final fingerprint = await CloudAccountBinding.fingerprint(uid);
    await prefs.remove('$_pendingRevisionKeyPrefix$fingerprint');
    await _pendingConfirmationSubscription?.cancel();
    _pendingConfirmationSubscription = null;
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
      (firebaseCode == 'unavailable' || firebaseCode == 'deadline-exceeded');

  @visibleForTesting
  static bool shouldClearStalePendingRevision({
    required int localRevision,
    required FirestoreRestReadOutcome probeOutcome,
  }) => localRevision == 0 && probeOutcome == FirestoreRestReadOutcome.missing;

  @visibleForTesting
  static Future<CloudSyncResult> restoreAndPushViaRest({
    required Future<CloudRestRestoreResult> Function() restore,
    required Future<bool> Function() upload,
    required CloudSyncFailure Function() uploadFailure,
  }) async {
    final restoreResult = await restore();
    if (restoreResult.outcome == CloudRestRestoreOutcome.failed) {
      return CloudSyncResult.failed(restoreResult.failure);
    }

    final uploaded = await upload();
    if (!uploaded) {
      return CloudSyncResult.failed(uploadFailure());
    }
    return CloudSyncResult.success(
      imported:
          restoreResult.outcome == CloudRestRestoreOutcome.restored
              ? restoreResult.imported
              : 0,
    );
  }

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
      return _fail(CloudSyncFailure.unauthenticated, tr('cloudSignInToSync'));
    }
    if (preflight == CloudSyncFailure.storageLocked) {
      return _fail(CloudSyncFailure.storageLocked, tr('cloudStorageLocked'));
    }
    if (doc == null || uid == null) return false;
    if (!await _ensureAccountBinding(uid)) return false;
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
      final outcome = await _writeCloudDocument(doc, backup, localRevision);
      if (shouldPersistConfirmedRevision(outcome.delivery)) {
        await _saveLocalRevision(uid, outcome.revision);
      } else if (outcome.delivery == CloudSyncDelivery.queuedLocally) {
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
          hasPendingWrites: outcome.hasPendingWrites,
          restHttpStatus: outcome.restHttpStatus,
          restOutcome: outcome.restOutcome,
        );
        if (outcome.hasPendingWrites) {
          _watchPendingConfirmation(doc, uid, outcome.revision);
        }
        return false;
      }
      status.value = CloudSyncStatus(
        CloudSyncPhase.success,
        updatedAt: DateTime.now(),
        message:
            outcome.operation == CloudSyncWriteOperation.firstCreate
                ? tr('cloudFirstCreateSuccess')
                : tr('cloudUpdateSuccess'),
        operation: switch (outcome.operation) {
          CloudSyncWriteOperation.firstCreate => 'first-create',
          CloudSyncWriteOperation.transactionUpdate => 'transaction-update',
          CloudSyncWriteOperation.restUpdate => 'rest-update',
        },
        documentExisted: outcome.documentExisted,
        revision: outcome.revision,
        delivery: CloudSyncDelivery.serverConfirmed,
        attemptCount: outcome.attempts,
        hasPendingWrites: false,
        restHttpStatus: outcome.restHttpStatus,
        restOutcome: outcome.restOutcome ?? status.value.restOutcome,
      );
      return true;
    } on _CloudRevisionConflict {
      return _fail(CloudSyncFailure.conflict, tr('cloudConflict'));
    } on TimeoutException {
      return _fail(CloudSyncFailure.timeout, tr('cloudTimeout'));
    } on FirebaseException catch (error, stackTrace) {
      return _failFirebase(
        error,
        stackTrace,
        operation: status.value.operation ?? firebaseOperation,
      );
    } on SecureDataException catch (_) {
      return _fail(CloudSyncFailure.storageLocked, tr('cloudStorageLocked'));
    } catch (error) {
      debugPrint('Cloud push failed (${error.runtimeType}).');
      return _fail(CloudSyncFailure.unknown, tr('cloudSyncUnknown'));
    }
  }

  static Map<String, Object> _encryptedBackupPayload(
    String backup,
    int revision,
  ) => {
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
        .listen(
          (snapshot) async {
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
          },
          onError: (Object error) {
            debugPrint(
              'Pending Firestore confirmation failed (${error.runtimeType}).',
            );
          },
        );
  }

  static Future<CloudSyncWriteOutcome> _writeCloudDocument(
    DocumentReference<Map<String, dynamic>> doc,
    String backup,
    int localRevision,
  ) => writeWithTransportPolicy(
    localRevision: localRevision,
    restFirstCreateEnabled: FirebaseBuildConfig.restFirstCreateEnabled,
    restUpdateEnabled: FirebaseBuildConfig.restUpdateFallbackEnabled,
    restFirstCreate: () => _createFirstCloudDocumentViaRest(backup),
    nativeFirstCreate: () => _createFirstCloudDocument(doc, backup),
    restUpdate: () => _updateCloudDocumentViaRest(backup, localRevision),
    nativeUpdate:
        () => _transactionUpdateCloudDocument(doc, backup, localRevision),
  );

  @visibleForTesting
  static Future<CloudSyncWriteOutcome> writeWithTransportPolicy({
    required int localRevision,
    required bool restFirstCreateEnabled,
    required bool restUpdateEnabled,
    required Future<CloudSyncWriteOutcome> Function() restFirstCreate,
    required Future<CloudSyncWriteOutcome> Function() nativeFirstCreate,
    required Future<CloudSyncWriteOutcome> Function() restUpdate,
    required Future<CloudSyncWriteOutcome> Function() nativeUpdate,
  }) {
    if (localRevision == 0) {
      return restFirstCreateEnabled ? restFirstCreate() : nativeFirstCreate();
    }
    return restUpdateEnabled ? restUpdate() : nativeUpdate();
  }

  static Future<CloudSyncWriteOutcome> _transactionUpdateCloudDocument(
    DocumentReference<Map<String, dynamic>> doc,
    String backup,
    int localRevision,
  ) async {
    _setWriteDiagnostics(
      operation: 'transaction-update',
      documentExisted: true,
      revision: localRevision + 1,
    );
    _logFirebaseOperation('firestore.transaction-update');
    final revision = await _runFirestoreOperation(
      () => FirestoreConfig.instance.runTransaction<int>((transaction) async {
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
      }),
      operationName: 'transaction-update',
    );
    return CloudSyncWriteOutcome(
      operation: CloudSyncWriteOperation.transactionUpdate,
      documentExisted: true,
      revision: revision,
      attempts: status.value.attemptCount,
    );
  }

  static Future<CloudSyncWriteOutcome> _createFirstCloudDocumentViaRest(
    String backup,
  ) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'firestore_rest',
        code: 'unauthenticated',
      );
    }
    _setWriteDiagnostics(
      operation: 'rest-first-create-probe',
      documentExisted: null,
      revision: 1,
    );
    final probe = await FirestoreRestFallback.readEncryptedBackup(
      uid: user.uid,
      tokenProvider: user.getIdToken,
      appCheckTokenProvider: _appCheckTokenProvider,
    );
    _recordRestResult(
      httpStatus: probe.httpStatus,
      outcome: 'probe-${probe.outcome.name}',
      attempts: probe.attempts,
      exceptionType: probe.exceptionType,
      documentExisted:
          probe.outcome == FirestoreRestReadOutcome.found
              ? true
              : probe.outcome == FirestoreRestReadOutcome.missing
              ? false
              : null,
    );
    if (probe.outcome == FirestoreRestReadOutcome.found) {
      throw const _CloudRevisionConflict();
    }
    if (probe.outcome == FirestoreRestReadOutcome.networkFailure ||
        probe.outcome == FirestoreRestReadOutcome.rateLimited ||
        probe.outcome == FirestoreRestReadOutcome.serviceUnavailable) {
      return CloudSyncWriteOutcome(
        operation: CloudSyncWriteOperation.firstCreate,
        documentExisted: false,
        revision: 1,
        delivery: CloudSyncDelivery.queuedLocally,
        attempts: probe.attempts,
        restHttpStatus: probe.httpStatus,
        restOutcome: 'probe-${probe.outcome.name}',
        hasPendingWrites: false,
      );
    }
    if (probe.outcome != FirestoreRestReadOutcome.missing) {
      _throwRestReadFailure(probe);
    }

    // Build 42 may have left only this sync marker behind. The encrypted
    // subscriptions, Keychain key, and Firestore cache are intentionally kept.
    if (shouldClearStalePendingRevision(
      localRevision: 0,
      probeOutcome: probe.outcome,
    )) {
      await _clearPendingRevision(user.uid);
    }
    _setWriteDiagnostics(
      operation: 'rest-first-create',
      documentExisted: false,
      revision: 1,
    );
    final create = await FirestoreRestFallback.createFirstEncryptedBackup(
      uid: user.uid,
      backup: backup,
      tokenProvider: user.getIdToken,
      appCheckTokenProvider: _appCheckTokenProvider,
    );
    _recordRestResult(
      httpStatus: create.httpStatus,
      outcome: create.outcome.name,
      attempts: probe.attempts + create.attempts,
      exceptionType: create.exceptionType,
      documentExisted: false,
    );
    if (create.confirmed) {
      return CloudSyncWriteOutcome(
        operation: CloudSyncWriteOperation.firstCreate,
        documentExisted: false,
        revision: 1,
        attempts: probe.attempts + create.attempts,
        restHttpStatus: create.httpStatus,
        restOutcome: create.outcome.name,
      );
    }
    if (create.outcome == FirestoreRestCreateOutcome.conflict) {
      throw const _CloudRevisionConflict();
    }
    if (create.outcome == FirestoreRestCreateOutcome.permissionDenied) {
      throw FirebaseException(
        plugin: 'firestore_rest',
        code: 'permission-denied',
      );
    }
    if (create.outcome == FirestoreRestCreateOutcome.unauthenticated) {
      throw FirebaseException(
        plugin: 'firestore_rest',
        code: 'unauthenticated',
      );
    }
    if (create.outcome == FirestoreRestCreateOutcome.networkFailure ||
        create.outcome == FirestoreRestCreateOutcome.rateLimited ||
        create.outcome == FirestoreRestCreateOutcome.serviceUnavailable) {
      return CloudSyncWriteOutcome(
        operation: CloudSyncWriteOperation.firstCreate,
        documentExisted: false,
        revision: 1,
        delivery: CloudSyncDelivery.queuedLocally,
        attempts: probe.attempts + create.attempts,
        restHttpStatus: create.httpStatus,
        restOutcome: create.outcome.name,
        hasPendingWrites: false,
      );
    }
    throw FirebaseException(plugin: 'firestore_rest', code: 'invalid-argument');
  }

  static Future<CloudSyncWriteOutcome> _updateCloudDocumentViaRest(
    String backup,
    int localRevision,
  ) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'firestore_rest',
        code: 'unauthenticated',
      );
    }
    _setWriteDiagnostics(
      operation: 'rest-update-probe',
      documentExisted: null,
      revision: localRevision + 1,
    );
    final probe = await FirestoreRestFallback.readEncryptedBackup(
      uid: user.uid,
      tokenProvider: user.getIdToken,
      appCheckTokenProvider: _appCheckTokenProvider,
    );
    _recordRestResult(
      httpStatus: probe.httpStatus,
      outcome: 'probe-${probe.outcome.name}',
      attempts: probe.attempts,
      exceptionType: probe.exceptionType,
      documentExisted:
          probe.outcome == FirestoreRestReadOutcome.found
              ? true
              : probe.outcome == FirestoreRestReadOutcome.missing
              ? false
              : null,
    );
    if (probe.outcome == FirestoreRestReadOutcome.missing) {
      throw const _CloudRevisionConflict();
    }
    if (probe.outcome != FirestoreRestReadOutcome.found ||
        probe.document == null) {
      _throwRestReadFailure(probe);
    }
    final remote = probe.document!;
    if (remote.revision != localRevision ||
        remote.schemaVersion != _schemaVersion ||
        remote.encryption != _encryption ||
        !FirestoreRestFallback.isEncryptedBackupEnvelope(remote.backup)) {
      throw const _CloudRevisionConflict();
    }
    final nextRevision = remote.revision + 1;
    _setWriteDiagnostics(
      operation: 'rest-update',
      documentExisted: true,
      revision: nextRevision,
    );
    final update = await FirestoreRestFallback.updateEncryptedBackup(
      uid: user.uid,
      backup: backup,
      nextRevision: nextRevision,
      remoteUpdateTime: remote.updateTime,
      tokenProvider: user.getIdToken,
      appCheckTokenProvider: _appCheckTokenProvider,
    );
    _recordRestResult(
      httpStatus: update.httpStatus,
      outcome: update.outcome.name,
      attempts: probe.attempts + update.attempts,
      exceptionType: update.exceptionType,
      documentExisted: true,
    );
    if (update.confirmed) {
      return CloudSyncWriteOutcome(
        operation: CloudSyncWriteOperation.restUpdate,
        documentExisted: true,
        revision: nextRevision,
        attempts: probe.attempts + update.attempts,
        restHttpStatus: update.httpStatus,
        restOutcome: update.outcome.name,
      );
    }
    if (update.outcome == FirestoreRestUpdateOutcome.conflict) {
      throw const _CloudRevisionConflict();
    }
    if (update.outcome == FirestoreRestUpdateOutcome.permissionDenied) {
      throw FirebaseException(
        plugin: 'firestore_rest',
        code: 'permission-denied',
      );
    }
    if (update.outcome == FirestoreRestUpdateOutcome.unauthenticated) {
      throw FirebaseException(
        plugin: 'firestore_rest',
        code: 'unauthenticated',
      );
    }
    throw FirebaseException(
      plugin: 'firestore_rest',
      code:
          update.outcome == FirestoreRestUpdateOutcome.networkFailure
              ? 'unavailable'
              : update.outcome == FirestoreRestUpdateOutcome.invalidPayload
              ? 'invalid-argument'
              : 'unavailable',
    );
  }

  static void _recordRestResult({
    required int? httpStatus,
    required String outcome,
    required int attempts,
    required String? exceptionType,
    required bool? documentExisted,
  }) {
    status.value = status.value.copyWith(
      restHttpStatus: httpStatus,
      restOutcome: outcome,
      attemptCount: attempts,
      exceptionType: exceptionType,
      documentExisted: documentExisted,
    );
  }

  static Never _throwRestReadFailure(FirestoreRestReadResult result) {
    final code = switch (result.outcome) {
      FirestoreRestReadOutcome.unauthenticated => 'unauthenticated',
      FirestoreRestReadOutcome.permissionDenied => 'permission-denied',
      FirestoreRestReadOutcome.invalidDocument => 'data-loss',
      FirestoreRestReadOutcome.rateLimited => 'resource-exhausted',
      FirestoreRestReadOutcome.serviceUnavailable ||
      FirestoreRestReadOutcome.networkFailure => 'unavailable',
      _ => 'unknown',
    };
    throw FirebaseException(plugin: 'firestore_rest', code: code);
  }

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
      if (pending) {
        return CloudSyncWriteOutcome(
          operation: CloudSyncWriteOperation.firstCreate,
          documentExisted: false,
          revision: 1,
          delivery: CloudSyncDelivery.queuedLocally,
          attempts: status.value.attemptCount,
          restHttpStatus: status.value.restHttpStatus,
          restOutcome: status.value.restOutcome,
          hasPendingWrites: true,
        );
      }
      final restOutcome = await _restCreateAfterNativeFailure(
        backup: backup,
        firebaseCode: error.code,
      );
      if (restOutcome != null) return restOutcome;
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
          hasPendingWrites: true,
        );
      }
      final restOutcome = await _restCreateAfterNativeFailure(
        backup: backup,
        firebaseCode: 'deadline-exceeded',
      );
      if (restOutcome != null) return restOutcome;
      rethrow;
    }
  }

  static Future<CloudSyncWriteOutcome?> _restCreateAfterNativeFailure({
    required String backup,
    required String firebaseCode,
  }) async {
    if (!shouldUseRestFallback(
      enabled: FirebaseBuildConfig.restFallbackEnabled,
      localRevision: 0,
      firebaseCode: firebaseCode,
    )) {
      return null;
    }
    final user = AuthService.currentUser;
    if (user == null) return null;
    final rest = await FirestoreRestFallback.createFirstEncryptedBackup(
      uid: user.uid,
      backup: backup,
      tokenProvider: user.getIdToken,
      appCheckTokenProvider: _appCheckTokenProvider,
    );
    _recordRestResult(
      httpStatus: rest.httpStatus,
      outcome: rest.outcome.name,
      attempts: status.value.attemptCount + rest.attempts,
      exceptionType: rest.exceptionType,
      documentExisted: false,
    );
    if (rest.confirmed) {
      return CloudSyncWriteOutcome(
        operation: CloudSyncWriteOperation.firstCreate,
        documentExisted: false,
        revision: 1,
        attempts: status.value.attemptCount,
        restHttpStatus: rest.httpStatus,
        restOutcome: rest.outcome.name,
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
    return null;
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
      _fail(CloudSyncFailure.unauthenticated, tr('cloudSignInToRestore'));
      return -1;
    }
    if (uid == null) return -1;
    if (!await _ensureAccountBinding(uid)) return -1;
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
        _fail(CloudSyncFailure.invalidBackup, tr('cloudInvalidBackup'));
        return -1;
      }
      if (schemaVersion == _schemaVersion && encryption != _encryption) {
        _fail(CloudSyncFailure.invalidBackup, tr('cloudInvalidBackup'));
        return -1;
      }
      final encrypted = schemaVersion == _schemaVersion;
      final count =
          encrypted
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
      _fail(CloudSyncFailure.timeout, tr('cloudRestoreTimeout'));
      return -1;
    } on FirebaseException catch (error, stackTrace) {
      _failFirebase(error, stackTrace, operation: 'firestore.pull-document');
      return -1;
    } catch (error) {
      debugPrint('Cloud pull failed (${error.runtimeType}).');
      _fail(CloudSyncFailure.unknown, tr('cloudRestoreUnknown'));
      return -1;
    }
  }

  static Future<CloudRestRestoreResult> _pullViaRest() async {
    final user = AuthService.currentUser;
    if (user == null) {
      _fail(CloudSyncFailure.unauthenticated, tr('cloudSignInToRestore'));
      return const CloudRestRestoreResult.failed(
        CloudSyncFailure.unauthenticated,
      );
    }
    if (!await _ensureAccountBinding(user.uid)) {
      return CloudRestRestoreResult.failed(status.value.failure);
    }
    _setSyncing();
    final result = await FirestoreRestFallback.readEncryptedBackup(
      uid: user.uid,
      tokenProvider: user.getIdToken,
      appCheckTokenProvider: _appCheckTokenProvider,
    );
    _recordRestResult(
      httpStatus: result.httpStatus,
      outcome: 'restore-${result.outcome.name}',
      attempts: result.attempts,
      exceptionType: result.exceptionType,
      documentExisted:
          result.outcome == FirestoreRestReadOutcome.found
              ? true
              : result.outcome == FirestoreRestReadOutcome.missing
              ? false
              : null,
    );
    if (result.outcome != FirestoreRestReadOutcome.found ||
        result.document == null) {
      if (result.outcome == FirestoreRestReadOutcome.missing) {
        return const CloudRestRestoreResult.missing();
      }
      try {
        _throwRestReadFailure(result);
      } on FirebaseException catch (error, stackTrace) {
        _failFirebase(error, stackTrace, operation: 'rest-restore');
        return CloudRestRestoreResult.failed(status.value.failure);
      }
    }
    final remote = result.document!;
    if (remote.schemaVersion != _schemaVersion ||
        remote.encryption != _encryption ||
        utf8.encode(remote.backup).length > _maxBackupBytes ||
        !FirestoreRestFallback.isEncryptedBackupEnvelope(remote.backup)) {
      _fail(CloudSyncFailure.invalidBackup, tr('cloudInvalidBackup'));
      return const CloudRestRestoreResult.failed(
        CloudSyncFailure.invalidBackup,
      );
    }
    try {
      final count = await SubscriptionStore.instance.importEncryptedCloudBackup(
        remote.backup,
      );
      if (count < 0) {
        _fail(
          CloudSyncFailure.storageLocked,
          tr('cloudEncryptedRestoreFailed'),
        );
        return const CloudRestRestoreResult.failed(
          CloudSyncFailure.storageLocked,
        );
      }
      await _saveLocalRevision(user.uid, remote.revision);
      status.value = status.value.copyWith(
        phase: CloudSyncPhase.success,
        updatedAt: DateTime.now(),
        revision: remote.revision,
        delivery: CloudSyncDelivery.serverConfirmed,
        hasPendingWrites: false,
      );
      return CloudRestRestoreResult.restored(count);
    } on SecureDataException {
      _fail(CloudSyncFailure.storageLocked, tr('cloudStorageLocked'));
      return const CloudRestRestoreResult.failed(
        CloudSyncFailure.storageLocked,
      );
    }
  }

  /// Restores a backup before uploading the latest local state.
  static Future<CloudSyncResult> restoreAndPush() async {
    final doc = _doc();
    final uid = AuthService.currentUser?.uid;
    if (doc == null) {
      _fail(CloudSyncFailure.unauthenticated, tr('cloudSignInToSync'));
      return const CloudSyncResult.failed(CloudSyncFailure.unauthenticated);
    }
    if (uid == null || !await _ensureAccountBinding(uid)) {
      return CloudSyncResult.failed(status.value.failure);
    }
    if (FirebaseBuildConfig.restUpdateFallbackEnabled) {
      return restoreAndPushViaRest(
        restore: _pullViaRest,
        upload: push,
        uploadFailure: () => status.value.failure,
      );
    }
    try {
      final exists =
          (await _runFirestoreOperation(
            () => doc.get(const GetOptions(source: Source.server)),
          )).exists;
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
      _fail(CloudSyncFailure.timeout, tr('cloudTimeout'));
      return const CloudSyncResult.failed(CloudSyncFailure.timeout);
    } on FirebaseException catch (error, stackTrace) {
      _failFirebase(error, stackTrace, operation: 'firestore.restore-probe');
      return CloudSyncResult.failed(status.value.failure);
    } catch (error) {
      debugPrint('Cloud restore failed (${error.runtimeType}).');
      _fail(CloudSyncFailure.unknown, tr('cloudAccountSyncUnknown'));
      return const CloudSyncResult.failed(CloudSyncFailure.unknown);
    }
  }

  /// Uploads once and fails closed on a genuine revision conflict.
  ///
  /// A blind pull-then-push cannot distinguish a deletion from an older local
  /// record because the current encrypted payload has no tombstones. Keeping
  /// both sides untouched is safer than resurrecting a deletion or silently
  /// discarding a same-ID edit. A future explicit resolver can make that choice
  /// after the encrypted record schema gains merge metadata.
  static Future<CloudSyncResult> syncNow() async {
    final uploaded = await push();
    if (uploaded) return const CloudSyncResult.success();
    if (status.value.phase == CloudSyncPhase.queued) {
      return const CloudSyncResult.queued();
    }
    if (status.value.failure != CloudSyncFailure.conflict) {
      return CloudSyncResult.failed(status.value.failure);
    }
    return const CloudSyncResult.failed(CloudSyncFailure.conflict);
  }

  /// حذف النسخة الخاصة بالمستخدم قبل حذف حساب المصادقة.
  static Future<void> deleteRemoteData() async {
    final doc = _doc();
    final uid = AuthService.currentUser?.uid;
    if (doc == null) throw StateError('No authenticated cloud document.');
    if (uid == null || !await _ensureAccountBinding(uid)) {
      throw StateError('Cloud account binding rejected the deletion.');
    }
    try {
      await _runFirestoreOperation(doc.delete);
    } on FirebaseException catch (error, stackTrace) {
      _failFirebase(error, stackTrace, operation: 'firestore.delete-document');
      rethrow;
    }
    final prefs = await SharedPreferences.getInstance();
    final fingerprint = await CloudAccountBinding.fingerprint(uid);
    await prefs.remove('$_revisionKeyPrefix$fingerprint');
    await prefs.remove('$_pendingRevisionKeyPrefix$fingerprint');
    status.value = const CloudSyncStatus(CloudSyncPhase.idle);
  }

  /// رفع مؤجل بعد كل تعديل (يجمع التعديلات المتتابعة في رفعة واحدة).
  static void schedulePush() {
    final scheduledUid = AuthService.currentUser?.uid;
    if (scheduledUid == null ||
        !SubscriptionStore.instance.storageHealthy ||
        _pushQueued) {
      return;
    }
    _pushQueued = true;
    Future.delayed(const Duration(seconds: 4), () async {
      _pushQueued = false;
      if (AuthService.currentUser?.uid != scheduledUid) return;
      await push();
    });
  }
}

class _CloudRevisionConflict implements Exception {
  const _CloudRevisionConflict();
}
