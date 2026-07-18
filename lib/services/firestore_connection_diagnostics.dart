library;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'firestore_retry.dart';
import 'firestore_config.dart';

const _firestoreHost = 'firestore.googleapis.com';
const _firebaseProjectId = 'ishtirakati-260f7';
const _diagnosticTimeout = Duration(seconds: 30);

const firebaseCoreVersion = '4.11.0';
const firebaseAuthVersion = '6.5.4';
const cloudFirestoreVersion = '6.6.0';
const firebaseAppCheckVersion = '0.4.5';
const firebaseIosSdkVersion = String.fromEnvironment(
  'FIREBASE_IOS_SDK_VERSION',
  defaultValue: '12.15.0',
);
const iosDependencyManager = String.fromEnvironment(
  'IOS_DEPENDENCY_MANAGER',
  defaultValue: 'Swift Package Manager',
);

enum FirestoreRestOutcome {
  success,
  missingDocument,
  unauthenticated,
  permissionDenied,
  invalidTarget,
  rateLimited,
  serviceFailure,
  dnsFailure,
  socketFailure,
  tlsFailure,
  timeout,
  clientFailure,
  noUser,
  tokenFailure,
  unexpectedFailure,
}

class FirestoreRestDiagnostic {
  final FirestoreRestOutcome outcome;
  final int? httpStatus;
  final int? commitHttpStatus;
  final bool dnsSucceeded;
  final bool connectionSucceeded;
  final Duration elapsed;
  final String? exceptionType;

  const FirestoreRestDiagnostic({
    required this.outcome,
    required this.httpStatus,
    this.commitHttpStatus,
    required this.dnsSucceeded,
    required this.connectionSucceeded,
    required this.elapsed,
    this.exceptionType,
  });
}

class FirestoreNativeDiagnostic {
  final bool succeeded;
  final bool? documentExists;
  final String? firebaseCode;
  final String? safeMessage;
  final Duration elapsed;
  final String? firebasePlugin;
  final String? exceptionType;
  final int attemptCount;

  const FirestoreNativeDiagnostic({
    required this.succeeded,
    required this.documentExists,
    required this.firebaseCode,
    required this.safeMessage,
    required this.elapsed,
    this.firebasePlugin,
    this.exceptionType,
    this.attemptCount = 0,
  });
}

class FirestoreConnectionDiagnostic {
  final FirestoreRestDiagnostic rest;
  final FirestoreNativeDiagnostic native;
  final DateTime completedAt;

  const FirestoreConnectionDiagnostic({
    required this.rest,
    required this.native,
    required this.completedAt,
  });
}

class FirestoreConnectionDiagnostics {
  FirestoreConnectionDiagnostics._();

  static const enabled = bool.fromEnvironment(
    'INTERNAL_BUILD',
    defaultValue: kDebugMode,
  );

  static final ValueNotifier<bool> running = ValueNotifier(false);
  static final ValueNotifier<FirestoreConnectionDiagnostic?> lastResult =
      ValueNotifier(null);

  static Future<FirestoreConnectionDiagnostic> run() async {
    if (!enabled) {
      throw StateError('Firestore diagnostics are disabled in this build.');
    }
    if (running.value) {
      final current = lastResult.value;
      if (current != null) return current;
      throw StateError('Firestore diagnostics are already running.');
    }

    running.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final result = FirestoreConnectionDiagnostic(
          rest: const FirestoreRestDiagnostic(
            outcome: FirestoreRestOutcome.noUser,
            httpStatus: null,
            dnsSucceeded: false,
            connectionSucceeded: false,
            elapsed: Duration.zero,
          ),
          native: const FirestoreNativeDiagnostic(
            succeeded: false,
            documentExists: null,
            firebaseCode: 'unauthenticated',
            safeMessage: null,
            elapsed: Duration.zero,
            attemptCount: 0,
          ),
          completedAt: DateTime.now(),
        );
        lastResult.value = result;
        return result;
      }

      final tokenWatch = Stopwatch()..start();
      String? token;
      try {
        token = await user.getIdToken(true).timeout(_diagnosticTimeout);
      } catch (error) {
        tokenWatch.stop();
        final result = FirestoreConnectionDiagnostic(
          rest: FirestoreRestDiagnostic(
            outcome:
                error is TimeoutException
                    ? FirestoreRestOutcome.timeout
                    : FirestoreRestOutcome.tokenFailure,
            httpStatus: null,
            dnsSucceeded: false,
            connectionSucceeded: false,
            elapsed: tokenWatch.elapsed,
            exceptionType: error.runtimeType.toString(),
          ),
          native: await _runNative(user.uid),
          completedAt: DateTime.now(),
        );
        lastResult.value = result;
        return result;
      }
      tokenWatch.stop();

      final rest =
          token == null || token.isEmpty
              ? FirestoreRestDiagnostic(
                outcome: FirestoreRestOutcome.tokenFailure,
                httpStatus: null,
                dnsSucceeded: false,
                connectionSucceeded: false,
                elapsed: tokenWatch.elapsed,
                exceptionType: 'EmptyFirebaseIdToken',
              )
              : await _runRest(uid: user.uid, idToken: token);
      token = null;
      final native = await _runNative(user.uid);
      final result = FirestoreConnectionDiagnostic(
        rest: rest,
        native: native,
        completedAt: DateTime.now(),
      );
      lastResult.value = result;
      return result;
    } finally {
      running.value = false;
    }
  }

  static Future<FirestoreRestDiagnostic> _runRest({
    required String uid,
    required String idToken,
  }) async {
    final watch = Stopwatch()..start();
    var dnsSucceeded = false;
    var connectionSucceeded = false;
    try {
      final addresses = await InternetAddress.lookup(
        _firestoreHost,
      ).timeout(_diagnosticTimeout);
      dnsSucceeded = addresses.isNotEmpty;
      if (!dnsSucceeded) {
        return FirestoreRestDiagnostic(
          outcome: FirestoreRestOutcome.dnsFailure,
          httpStatus: null,
          dnsSucceeded: false,
          connectionSucceeded: false,
          elapsed: watch.elapsed,
          exceptionType: 'EmptyDnsResult',
        );
      }

      final uri = Uri.https(
        _firestoreHost,
        '/v1/projects/$_firebaseProjectId/databases/'
        '${FirestoreConfig.databaseId}/documents/users/${Uri.encodeComponent(uid)}',
      );
      final client = http.Client();
      try {
        final request = http.Request('GET', uri)
          ..headers[HttpHeaders.authorizationHeader] = 'Bearer $idToken';
        final response = await client.send(request).timeout(_diagnosticTimeout);
        connectionSucceeded = true;
        await response.stream.drain<void>().timeout(_diagnosticTimeout);
        int? commitHttpStatus;
        var outcome = outcomeForHttpStatus(response.statusCode);
        if (response.statusCode == HttpStatus.notFound) {
          final commitRequest =
              http.Request(
                  'POST',
                  Uri.https(
                    _firestoreHost,
                    '/v1/projects/$_firebaseProjectId/databases/'
                    '${FirestoreConfig.databaseId}/documents:commit',
                  ),
                )
                ..headers[HttpHeaders.authorizationHeader] = 'Bearer $idToken'
                ..headers[HttpHeaders.contentTypeHeader] = 'application/json'
                ..body = '{"writes":[]}';
          final commitResponse = await client
              .send(commitRequest)
              .timeout(_diagnosticTimeout);
          commitHttpStatus = commitResponse.statusCode;
          await commitResponse.stream.drain<void>().timeout(_diagnosticTimeout);
          outcome = outcomeForProbeStatuses(
            documentStatus: response.statusCode,
            commitStatus: commitHttpStatus,
          );
        }
        watch.stop();
        return FirestoreRestDiagnostic(
          outcome: outcome,
          httpStatus: response.statusCode,
          commitHttpStatus: commitHttpStatus,
          dnsSucceeded: true,
          connectionSucceeded: true,
          elapsed: watch.elapsed,
        );
      } finally {
        client.close();
      }
    } on HandshakeException catch (error) {
      return _restException(
        FirestoreRestOutcome.tlsFailure,
        watch,
        dnsSucceeded,
        connectionSucceeded,
        error,
      );
    } on SocketException catch (error) {
      return _restException(
        dnsSucceeded
            ? FirestoreRestOutcome.socketFailure
            : FirestoreRestOutcome.dnsFailure,
        watch,
        dnsSucceeded,
        connectionSucceeded,
        error,
      );
    } on TimeoutException catch (error) {
      return _restException(
        FirestoreRestOutcome.timeout,
        watch,
        dnsSucceeded,
        connectionSucceeded,
        error,
      );
    } on http.ClientException catch (error) {
      return _restException(
        FirestoreRestOutcome.clientFailure,
        watch,
        dnsSucceeded,
        connectionSucceeded,
        error,
      );
    } catch (error) {
      return _restException(
        FirestoreRestOutcome.unexpectedFailure,
        watch,
        dnsSucceeded,
        connectionSucceeded,
        error,
      );
    }
  }

  static FirestoreRestDiagnostic _restException(
    FirestoreRestOutcome outcome,
    Stopwatch watch,
    bool dnsSucceeded,
    bool connectionSucceeded,
    Object error,
  ) {
    watch.stop();
    debugPrint(
      'Firestore REST diagnostic failed: host=$_firestoreHost '
      'type=${error.runtimeType}.',
    );
    return FirestoreRestDiagnostic(
      outcome: outcome,
      httpStatus: null,
      dnsSucceeded: dnsSucceeded,
      connectionSucceeded: connectionSucceeded,
      elapsed: watch.elapsed,
      exceptionType: error.runtimeType.toString(),
    );
  }

  static Future<FirestoreNativeDiagnostic> _runNative(String uid) async {
    final watch = Stopwatch()..start();
    var attempts = 0;
    try {
      final snapshot = await FirestoreRetry.run(
        operation: 'diagnostic-native-read',
        action:
            () => FirestoreConfig.instance
                .collection('users')
                .doc(uid)
                .get(const GetOptions(source: Source.server)),
        onEvent: (event) => attempts = event.attempt,
      );
      watch.stop();
      return FirestoreNativeDiagnostic(
        succeeded: true,
        documentExists: snapshot.exists,
        firebaseCode: null,
        safeMessage: null,
        elapsed: watch.elapsed,
        attemptCount: attempts,
      );
    } on FirebaseException catch (error, stackTrace) {
      watch.stop();
      final safeMessage = redactSensitive(error.message ?? '', uid: uid);
      debugPrint(
        'Firestore native diagnostic failed: plugin=${error.plugin} '
        'code=${error.code} message=${safeMessage.isEmpty ? '<empty>' : safeMessage}.',
      );
      debugPrintStack(
        label: 'Firestore native diagnostic stack',
        stackTrace: stackTrace,
      );
      return FirestoreNativeDiagnostic(
        succeeded: false,
        documentExists: null,
        firebaseCode: error.code,
        safeMessage: safeMessage.isEmpty ? null : safeMessage,
        elapsed: watch.elapsed,
        firebasePlugin: error.plugin,
        exceptionType: error.runtimeType.toString(),
        attemptCount: attempts,
      );
    } on TimeoutException {
      watch.stop();
      return FirestoreNativeDiagnostic(
        succeeded: false,
        documentExists: null,
        firebaseCode: 'timeout',
        safeMessage: null,
        elapsed: watch.elapsed,
        exceptionType: 'TimeoutException',
        attemptCount: attempts,
      );
    } catch (error, stackTrace) {
      watch.stop();
      debugPrint(
        'Firestore native diagnostic failed: type=${error.runtimeType}.',
      );
      debugPrintStack(
        label: 'Firestore native diagnostic stack',
        stackTrace: stackTrace,
      );
      return FirestoreNativeDiagnostic(
        succeeded: false,
        documentExists: null,
        firebaseCode: 'non-firebase-error',
        safeMessage: error.runtimeType.toString(),
        elapsed: watch.elapsed,
        exceptionType: error.runtimeType.toString(),
        attemptCount: attempts,
      );
    }
  }

  @visibleForTesting
  static FirestoreRestOutcome outcomeForHttpStatus(int statusCode) {
    if (statusCode == 200) return FirestoreRestOutcome.success;
    if (statusCode == 400) return FirestoreRestOutcome.invalidTarget;
    if (statusCode == 401) return FirestoreRestOutcome.unauthenticated;
    if (statusCode == 403) return FirestoreRestOutcome.permissionDenied;
    if (statusCode == 404) return FirestoreRestOutcome.missingDocument;
    if (statusCode == 429) return FirestoreRestOutcome.rateLimited;
    if (statusCode >= 500) return FirestoreRestOutcome.serviceFailure;
    return FirestoreRestOutcome.unexpectedFailure;
  }

  @visibleForTesting
  static FirestoreRestOutcome outcomeForProbeStatuses({
    required int documentStatus,
    required int commitStatus,
  }) {
    if (documentStatus != HttpStatus.notFound) {
      return outcomeForHttpStatus(documentStatus);
    }
    if (commitStatus == HttpStatus.notFound ||
        commitStatus == HttpStatus.badRequest) {
      return FirestoreRestOutcome.invalidTarget;
    }
    if (commitStatus == HttpStatus.unauthorized) {
      return FirestoreRestOutcome.unauthenticated;
    }
    if (commitStatus == HttpStatus.forbidden) {
      return FirestoreRestOutcome.permissionDenied;
    }
    if (commitStatus == HttpStatus.tooManyRequests) {
      return FirestoreRestOutcome.rateLimited;
    }
    if (commitStatus >= 500) return FirestoreRestOutcome.serviceFailure;
    return FirestoreRestOutcome.missingDocument;
  }

  @visibleForTesting
  static String redactSensitive(String message, {required String uid}) {
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
}
