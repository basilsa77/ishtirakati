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
