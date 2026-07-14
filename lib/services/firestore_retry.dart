import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreRetryEvent {
  final String operation;
  final int attempt;
  final int maxAttempts;
  final int? nextDelayMs;
  final String? code;

  const FirestoreRetryEvent({
    required this.operation,
    required this.attempt,
    required this.maxAttempts,
    this.nextDelayMs,
    this.code,
  });
}

class FirestoreRetry {
  FirestoreRetry._();

  static const maxAttempts = 5;
  static const operationTimeout = Duration(seconds: 45);

  static bool isRetryableCode(String code) {
    final normalized = code.replaceFirst('storage/', '');
    return normalized == 'unavailable' ||
        normalized == 'deadline-exceeded' ||
        normalized == 'aborted' ||
        normalized == 'resource-exhausted';
  }

  @visibleForTesting
  static Duration delayForAttempt(int attempt, {required int jitterMs}) {
    final base = switch (attempt) {
      1 => 500,
      2 => 1000,
      3 => 2000,
      4 => 4000,
      _ => 8000,
    };
    final cap = switch (attempt) {
      1 => 900,
      2 => 2000,
      3 => 4000,
      4 => 8000,
      _ => 12000,
    };
    return Duration(milliseconds: min(base + jitterMs, cap));
  }

  static Future<T> run<T>({
    required String operation,
    required Future<T> Function() action,
    void Function(FirestoreRetryEvent event)? onEvent,
    int attempts = maxAttempts,
    Random? random,
    Future<void> Function(Duration delay)? sleeper,
  }) async {
    final jitter = random ?? Random.secure();
    final wait = sleeper ?? Future<void>.delayed;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      onEvent?.call(FirestoreRetryEvent(
        operation: operation,
        attempt: attempt,
        maxAttempts: attempts,
      ));
      try {
        return await action().timeout(operationTimeout);
      } on FirebaseException catch (error) {
        if (!isRetryableCode(error.code) || attempt == attempts) rethrow;
        final delay = delayForAttempt(
          attempt,
          jitterMs: jitter.nextInt(401),
        );
        onEvent?.call(FirestoreRetryEvent(
          operation: operation,
          attempt: attempt,
          maxAttempts: attempts,
          nextDelayMs: delay.inMilliseconds,
          code: error.code,
        ));
        await wait(delay);
      }
    }
    throw StateError('Firestore retry loop completed without a result.');
  }
}
