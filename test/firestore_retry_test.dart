import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/firestore_retry.dart';

void main() {
  test(
    'unavailable is attempted five times with exponential backoff',
    () async {
      var calls = 0;
      final delays = <Duration>[];

      await expectLater(
        FirestoreRetry.run<void>(
          operation: 'first-create',
          random: Random(7),
          sleeper: (delay) async => delays.add(delay),
          action: () async {
            calls++;
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          },
        ),
        throwsA(isA<FirebaseException>()),
      );

      expect(calls, 5);
      expect(delays, hasLength(4));
      expect(delays[0].inMilliseconds, inInclusiveRange(500, 900));
      expect(delays[1].inMilliseconds, inInclusiveRange(1000, 2000));
      expect(delays[2].inMilliseconds, inInclusiveRange(2000, 4000));
      expect(delays[3].inMilliseconds, inInclusiveRange(4000, 8000));
    },
  );

  test('permission-denied is never retried', () async {
    var calls = 0;
    final delays = <Duration>[];

    await expectLater(
      FirestoreRetry.run<void>(
        operation: 'first-create',
        sleeper: (delay) async => delays.add(delay),
        action: () async {
          calls++;
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        },
      ),
      throwsA(isA<FirebaseException>()),
    );

    expect(calls, 1);
    expect(delays, isEmpty);
  });
}
