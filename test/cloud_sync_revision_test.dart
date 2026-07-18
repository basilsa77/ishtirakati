import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/cloud_sync.dart';
import 'package:ishtirakati/services/firestore_rest_fallback.dart';

void main() {
  test('revision conflicts fail closed instead of blind pull-then-push', () {
    final source = File('lib/services/cloud_sync.dart').readAsStringSync();
    final start = source.indexOf('static Future<CloudSyncResult> syncNow()');
    final end = source.indexOf('static Future<void> deleteRemoteData()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final syncNow = source.substring(start, end);
    expect(syncNow, isNot(contains('return restoreAndPush()')));
    expect(
      syncNow,
      contains('CloudSyncResult.failed(CloudSyncFailure.conflict)'),
    );
  });

  group('cloud revision conflict protection', () {
    test('first upload is allowed when no remote document exists', () {
      expect(
        CloudSync.canPushRevision(
          localRevision: 0,
          remoteRevision: 0,
          remoteExists: false,
        ),
        isTrue,
      );
    });

    test('matching revision can advance safely', () {
      expect(
        CloudSync.canPushRevision(
          localRevision: 7,
          remoteRevision: 7,
          remoteExists: true,
        ),
        isTrue,
      );
    });

    test('newer cloud data cannot be overwritten', () {
      expect(
        CloudSync.canPushRevision(
          localRevision: 6,
          remoteRevision: 7,
          remoteExists: true,
        ),
        isFalse,
      );
    });

    test('a new device must restore an existing cloud copy first', () {
      expect(
        CloudSync.canPushRevision(
          localRevision: 0,
          remoteRevision: 3,
          remoteExists: true,
        ),
        isFalse,
      );
    });

    test('only transient Firestore failures are retried', () {
      expect(CloudSync.isRetryableFirebaseCode('unavailable'), isTrue);
      expect(CloudSync.isRetryableFirebaseCode('aborted'), isTrue);
      expect(CloudSync.isRetryableFirebaseCode('internal'), isFalse);
      expect(CloudSync.isRetryableFirebaseCode('permission-denied'), isFalse);
      expect(CloudSync.isRetryableFirebaseCode('unauthenticated'), isFalse);
      expect(CloudSync.isRetryableFirebaseCode('not-found'), isFalse);
    });

    test(
      'revision zero goes directly to first create without a server probe',
      () async {
        var firstCreateCalls = 0;
        var transactionCalls = 0;
        final outcome = await CloudSync.writeWithoutPreflightRead(
          localRevision: 0,
          firstCreate: () async {
            firstCreateCalls++;
            return const CloudSyncWriteOutcome(
              operation: CloudSyncWriteOperation.firstCreate,
              documentExisted: false,
              revision: 1,
            );
          },
          transactionUpdate: () async {
            transactionCalls++;
            throw StateError('transaction must not run');
          },
        );

        expect(firstCreateCalls, 1);
        expect(transactionCalls, 0);
        expect(outcome.operation, CloudSyncWriteOperation.firstCreate);
        expect(outcome.documentExisted, isFalse);
        expect(outcome.revision, 1);
      },
    );

    test(
      'first-create failure is not hidden by a transaction fallback',
      () async {
        var transactionCalls = 0;
        await expectLater(
          CloudSync.writeWithoutPreflightRead(
            localRevision: 0,
            firstCreate:
                () async =>
                    throw FirebaseException(
                      plugin: 'cloud_firestore',
                      code: 'unavailable',
                    ),
            transactionUpdate: () async {
              transactionCalls++;
              throw StateError('transaction must not run');
            },
          ),
          throwsA(isA<FirebaseException>()),
        );
        expect(transactionCalls, 0);
      },
    );

    test('existing cloud document stays on transaction update', () async {
      var firstCreateCalls = 0;
      var transactionCalls = 0;
      final outcome = await CloudSync.writeWithoutPreflightRead(
        localRevision: 4,
        transactionUpdate: () async {
          transactionCalls++;
          return const CloudSyncWriteOutcome(
            operation: CloudSyncWriteOperation.transactionUpdate,
            documentExisted: true,
            revision: 5,
          );
        },
        firstCreate: () async {
          firstCreateCalls++;
          throw StateError('first create not expected');
        },
      );

      expect(transactionCalls, 1);
      expect(firstCreateCalls, 0);
      expect(outcome.operation, CloudSyncWriteOperation.transactionUpdate);
      expect(outcome.documentExisted, isTrue);
      expect(outcome.revision, 5);
    });

    test(
      'REST-first create bypasses Native before any pending write',
      () async {
        var restCalls = 0;
        var nativeCalls = 0;
        final outcome = await CloudSync.writeWithTransportPolicy(
          localRevision: 0,
          restFirstCreateEnabled: true,
          restUpdateEnabled: true,
          restFirstCreate: () async {
            restCalls++;
            return const CloudSyncWriteOutcome(
              operation: CloudSyncWriteOperation.firstCreate,
              documentExisted: false,
              revision: 1,
              restHttpStatus: 200,
              restOutcome: 'serverConfirmed',
            );
          },
          nativeFirstCreate: () async {
            nativeCalls++;
            throw StateError('Native first-create must not run');
          },
          restUpdate: () async => throw StateError('update must not run'),
          nativeUpdate: () async => throw StateError('update must not run'),
        );

        expect(restCalls, 1);
        expect(nativeCalls, 0);
        expect(outcome.delivery, CloudSyncDelivery.serverConfirmed);
        expect(outcome.hasPendingWrites, isFalse);
        expect(outcome.restHttpStatus, 200);
      },
    );

    test(
      'REST update policy bypasses Native for confirmed revisions',
      () async {
        var restCalls = 0;
        var nativeCalls = 0;
        final outcome = await CloudSync.writeWithTransportPolicy(
          localRevision: 1,
          restFirstCreateEnabled: true,
          restUpdateEnabled: true,
          restFirstCreate: () async => throw StateError('create must not run'),
          nativeFirstCreate:
              () async => throw StateError('create must not run'),
          restUpdate: () async {
            restCalls++;
            return const CloudSyncWriteOutcome(
              operation: CloudSyncWriteOperation.restUpdate,
              documentExisted: true,
              revision: 2,
              restHttpStatus: 200,
            );
          },
          nativeUpdate: () async {
            nativeCalls++;
            throw StateError('Native update must not run');
          },
        );

        expect(restCalls, 1);
        expect(nativeCalls, 0);
        expect(outcome.revision, 2);
      },
    );

    test('disabled REST flags preserve the Native paths', () async {
      var nativeFirstCalls = 0;
      var nativeUpdateCalls = 0;
      await CloudSync.writeWithTransportPolicy(
        localRevision: 0,
        restFirstCreateEnabled: false,
        restUpdateEnabled: false,
        restFirstCreate: () async => throw StateError('REST must not run'),
        nativeFirstCreate: () async {
          nativeFirstCalls++;
          return const CloudSyncWriteOutcome(
            operation: CloudSyncWriteOperation.firstCreate,
            documentExisted: false,
            revision: 1,
          );
        },
        restUpdate: () async => throw StateError('REST must not run'),
        nativeUpdate: () async => throw StateError('update must not run'),
      );
      await CloudSync.writeWithTransportPolicy(
        localRevision: 1,
        restFirstCreateEnabled: false,
        restUpdateEnabled: false,
        restFirstCreate: () async => throw StateError('create must not run'),
        nativeFirstCreate: () async => throw StateError('create must not run'),
        restUpdate: () async => throw StateError('REST must not run'),
        nativeUpdate: () async {
          nativeUpdateCalls++;
          return const CloudSyncWriteOutcome(
            operation: CloudSyncWriteOperation.transactionUpdate,
            documentExisted: true,
            revision: 2,
          );
        },
      );

      expect(nativeFirstCalls, 1);
      expect(nativeUpdateCalls, 1);
    });

    test('missing REST probe permits stale pending marker migration', () {
      expect(
        CloudSync.shouldClearStalePendingRevision(
          localRevision: 0,
          probeOutcome: FirestoreRestReadOutcome.missing,
        ),
        isTrue,
      );
      expect(
        CloudSync.shouldClearStalePendingRevision(
          localRevision: 0,
          probeOutcome: FirestoreRestReadOutcome.found,
        ),
        isFalse,
      );
    });

    test(
      'confirmed REST 404 creates the first cloud revision exactly once',
      () async {
        var restoreCalls = 0;
        var uploadCalls = 0;
        final result = await CloudSync.restoreAndPushViaRest(
          restore: () async {
            restoreCalls++;
            return const CloudRestRestoreResult.missing();
          },
          upload: () async {
            uploadCalls++;
            return true;
          },
          uploadFailure: () => CloudSyncFailure.unknown,
        );

        expect(restoreCalls, 1);
        expect(uploadCalls, 1);
        expect(result.success, isTrue);
        expect(result.imported, 0);
      },
    );

    test(
      'successful REST restore uploads the merged state exactly once',
      () async {
        var uploadCalls = 0;
        final result = await CloudSync.restoreAndPushViaRest(
          restore: () async => const CloudRestRestoreResult.restored(4),
          upload: () async {
            uploadCalls++;
            return true;
          },
          uploadFailure: () => CloudSyncFailure.unknown,
        );

        expect(uploadCalls, 1);
        expect(result.success, isTrue);
        expect(result.imported, 4);
      },
    );

    test(
      'REST permission, timeout, network, and malformed failures never upload',
      () async {
        const failures = <CloudSyncFailure>[
          CloudSyncFailure.permissionDenied,
          CloudSyncFailure.timeout,
          CloudSyncFailure.serviceUnavailable,
          CloudSyncFailure.invalidBackup,
        ];

        for (final failure in failures) {
          var uploadCalls = 0;
          final result = await CloudSync.restoreAndPushViaRest(
            restore: () async => CloudRestRestoreResult.failed(failure),
            upload: () async {
              uploadCalls++;
              return true;
            },
            uploadFailure: () => CloudSyncFailure.unknown,
          );

          expect(uploadCalls, 0, reason: 'failure=$failure');
          expect(result.success, isFalse, reason: 'failure=$failure');
          expect(result.failure, failure, reason: 'failure=$failure');
        }
      },
    );

    test('failed first-create upload is returned without a retry', () async {
      var uploadCalls = 0;
      final result = await CloudSync.restoreAndPushViaRest(
        restore: () async => const CloudRestRestoreResult.missing(),
        upload: () async {
          uploadCalls++;
          return false;
        },
        uploadFailure: () => CloudSyncFailure.permissionDenied,
      );

      expect(uploadCalls, 1);
      expect(result.success, isFalse);
      expect(result.failure, CloudSyncFailure.permissionDenied);
    });

    test('queued writes never persist as confirmed revisions', () {
      expect(
        CloudSync.shouldPersistConfirmedRevision(
          CloudSyncDelivery.queuedLocally,
        ),
        isFalse,
      );
      expect(
        CloudSync.shouldPersistConfirmedRevision(
          CloudSyncDelivery.serverConfirmed,
        ),
        isTrue,
      );
    });

    test('REST fallback is restricted to first-create transient failures', () {
      expect(
        CloudSync.shouldUseRestFallback(
          enabled: true,
          localRevision: 0,
          firebaseCode: 'unavailable',
        ),
        isTrue,
      );
      expect(
        CloudSync.shouldUseRestFallback(
          enabled: false,
          localRevision: 0,
          firebaseCode: 'unavailable',
        ),
        isFalse,
      );
      expect(
        CloudSync.shouldUseRestFallback(
          enabled: true,
          localRevision: 1,
          firebaseCode: 'unavailable',
        ),
        isFalse,
      );
      expect(
        CloudSync.shouldUseRestFallback(
          enabled: true,
          localRevision: 0,
          firebaseCode: 'permission-denied',
        ),
        isFalse,
      );
    });
  });

  group('cloud synchronization preflight', () {
    test('requires an authenticated Firebase user', () {
      expect(
        CloudSync.preflightFailure(signedIn: false, storageHealthy: true),
        CloudSyncFailure.unauthenticated,
      );
    });

    test('blocks synchronization when Keychain-backed storage is locked', () {
      expect(
        CloudSync.preflightFailure(signedIn: true, storageHealthy: false),
        CloudSyncFailure.storageLocked,
      );
    });

    test('allows synchronization only after both checks pass', () {
      expect(
        CloudSync.preflightFailure(signedIn: true, storageHealthy: true),
        CloudSyncFailure.none,
      );
    });
  });

  group('cloud schema migration compatibility', () {
    test(
      'accepts unversioned and v1 legacy documents for one-way migration',
      () {
        expect(CloudSync.isSupportedCloudSchema(null), isTrue);
        expect(CloudSync.isSupportedCloudSchema(1), isTrue);
      },
    );

    test('accepts encrypted v2 and rejects unknown formats', () {
      expect(CloudSync.isSupportedCloudSchema(2), isTrue);
      expect(CloudSync.isSupportedCloudSchema(3), isFalse);
      expect(CloudSync.isSupportedCloudSchema('2'), isFalse);
    });
  });
}
