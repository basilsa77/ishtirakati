library;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _firestoreHost = 'firestore.googleapis.com';
const _firebaseProjectId = 'ishtirakati-260f7';
const _firestoreDatabaseId = '(default)';
const _diagnosticTimeout = Duration(seconds: 30);

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
  final bool dnsSucceeded;
  final bool connectionSucceeded;
  final Duration elapsed;
  final String? exceptionType;

  const FirestoreRestDiagnostic({
    required this.outcome,
    required this.httpStatus,
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

  const FirestoreNativeDiagnostic({
    required this.succeeded,
    required this.documentExists,
    required this.firebaseCode,
    required this.safeMessage,
    required this.elapsed,
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
            outcome: error is TimeoutException
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

      final rest = token == null || token.isEmpty
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
      final addresses = await InternetAddress.lookup(_firestoreHost)
          .timeout(_diagnosticTimeout);
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
        '$_firestoreDatabaseId/documents/users/${Uri.encodeComponent(uid)}',
      );
      final client = http.Client();
      try {
        final request = http.Request('GET', uri)
          ..headers[HttpHeaders.authorizationHeader] = 'Bearer $idToken';
        final response = await client.send(request).timeout(_diagnosticTimeout);
        connectionSucceeded = true;
        await response.stream.drain<void>().timeout(_diagnosticTimeout);
        watch.stop();
        return FirestoreRestDiagnostic(
          outcome: outcomeForHttpStatus(response.statusCode),
          httpStatus: response.statusCode,
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
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_diagnosticTimeout);
      watch.stop();
      return FirestoreNativeDiagnostic(
        succeeded: true,
        documentExists: snapshot.exists,
        firebaseCode: null,
        safeMessage: null,
        elapsed: watch.elapsed,
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
      );
    } on TimeoutException {
      watch.stop();
      return FirestoreNativeDiagnostic(
        succeeded: false,
        documentExists: null,
        firebaseCode: 'timeout',
        safeMessage: null,
        elapsed: watch.elapsed,
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
  static String redactSensitive(String message, {required String uid}) {
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
}
