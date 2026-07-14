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
}
