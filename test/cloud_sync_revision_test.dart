import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/cloud_sync.dart';

void main() {
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
      expect(CloudSync.isRetryableFirebaseCode('internal'), isTrue);
      expect(CloudSync.isRetryableFirebaseCode('permission-denied'), isFalse);
      expect(CloudSync.isRetryableFirebaseCode('unauthenticated'), isFalse);
      expect(CloudSync.isRetryableFirebaseCode('not-found'), isFalse);
    });

    test('transaction document not-found falls back to first create', () async {
      var firstCreateCalls = 0;
      final outcome = await CloudSync.writeWithFirstCreateFallback(
        localRevision: 0,
        documentExists: () async => true,
        transactionUpdate: () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'The requested document was not found.',
        ),
        firstCreate: () async {
          firstCreateCalls++;
        },
      );

      expect(firstCreateCalls, 1);
      expect(outcome.operation, CloudSyncWriteOperation.firstCreate);
      expect(outcome.documentExisted, isFalse);
      expect(outcome.revision, 1);
    });

    test('missing database never falls back to document creation', () async {
      var firstCreateCalls = 0;

      await expectLater(
        CloudSync.writeWithFirstCreateFallback(
          localRevision: 0,
          documentExists: () async => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'The database (default) does not exist.',
          ),
          transactionUpdate: () async => 1,
          firstCreate: () async {
            firstCreateCalls++;
          },
        ),
        throwsA(isA<FirebaseException>()),
      );

      expect(firstCreateCalls, 0);
    });

    test('existing cloud document stays on transaction update', () async {
      var firstCreateCalls = 0;
      var transactionCalls = 0;
      final outcome = await CloudSync.writeWithFirstCreateFallback(
        localRevision: 4,
        documentExists: () async => throw StateError('probe not expected'),
        transactionUpdate: () async {
          transactionCalls++;
          return 5;
        },
        firstCreate: () async {
          firstCreateCalls++;
        },
      );

      expect(transactionCalls, 1);
      expect(firstCreateCalls, 0);
      expect(outcome.operation, CloudSyncWriteOperation.transactionUpdate);
      expect(outcome.documentExisted, isTrue);
      expect(outcome.revision, 5);
    });
  });

  group('cloud synchronization preflight', () {
    test('requires an authenticated Firebase user', () {
      expect(
        CloudSync.preflightFailure(
          signedIn: false,
          storageHealthy: true,
        ),
        CloudSyncFailure.unauthenticated,
      );
    });

    test('blocks synchronization when Keychain-backed storage is locked', () {
      expect(
        CloudSync.preflightFailure(
          signedIn: true,
          storageHealthy: false,
        ),
        CloudSyncFailure.storageLocked,
      );
    });

    test('allows synchronization only after both checks pass', () {
      expect(
        CloudSync.preflightFailure(
          signedIn: true,
          storageHealthy: true,
        ),
        CloudSyncFailure.none,
      );
    });
  });

  group('cloud schema migration compatibility', () {
    test('accepts unversioned and v1 legacy documents for one-way migration', () {
      expect(CloudSync.isSupportedCloudSchema(null), isTrue);
      expect(CloudSync.isSupportedCloudSchema(1), isTrue);
    });

    test('accepts encrypted v2 and rejects unknown formats', () {
      expect(CloudSync.isSupportedCloudSchema(2), isTrue);
      expect(CloudSync.isSupportedCloudSchema(3), isFalse);
      expect(CloudSync.isSupportedCloudSchema('2'), isFalse);
    });
  });
}
