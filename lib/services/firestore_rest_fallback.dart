import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum FirestoreRestCreateOutcome {
  serverConfirmed,
  conflict,
  unauthenticated,
  permissionDenied,
  rateLimited,
  serviceUnavailable,
  networkFailure,
  invalidPayload,
  unexpectedFailure,
}

class FirestoreRestCreateResult {
  final FirestoreRestCreateOutcome outcome;
  final int? httpStatus;
  final int attempts;
  final Duration elapsed;
  final String? exceptionType;
  final String? serverStatus;

  const FirestoreRestCreateResult({
    required this.outcome,
    required this.httpStatus,
    required this.attempts,
    required this.elapsed,
    this.exceptionType,
    this.serverStatus,
  });

  bool get confirmed => outcome == FirestoreRestCreateOutcome.serverConfirmed;
}

enum FirestoreRestReadOutcome {
  found,
  missing,
  unauthenticated,
  permissionDenied,
  rateLimited,
  serviceUnavailable,
  networkFailure,
  invalidDocument,
  unexpectedFailure,
}

class FirestoreRestDocument {
  final String backup;
  final int revision;
  final int schemaVersion;
  final String encryption;
  final String updateTime;

  const FirestoreRestDocument({
    required this.backup,
    required this.revision,
    required this.schemaVersion,
    required this.encryption,
    required this.updateTime,
  });
}

class FirestoreRestReadResult {
  final FirestoreRestReadOutcome outcome;
  final int? httpStatus;
  final int attempts;
  final Duration elapsed;
  final FirestoreRestDocument? document;
  final String? exceptionType;
  final String? serverStatus;

  const FirestoreRestReadResult({
    required this.outcome,
    required this.httpStatus,
    required this.attempts,
    required this.elapsed,
    this.document,
    this.exceptionType,
    this.serverStatus,
  });
}

enum FirestoreRestUpdateOutcome {
  serverConfirmed,
  conflict,
  unauthenticated,
  permissionDenied,
  rateLimited,
  serviceUnavailable,
  networkFailure,
  invalidPayload,
  unexpectedFailure,
}

class FirestoreRestUpdateResult {
  final FirestoreRestUpdateOutcome outcome;
  final int? httpStatus;
  final int attempts;
  final Duration elapsed;
  final String? exceptionType;
  final String? serverStatus;

  const FirestoreRestUpdateResult({
    required this.outcome,
    required this.httpStatus,
    required this.attempts,
    required this.elapsed,
    this.exceptionType,
    this.serverStatus,
  });

  bool get confirmed => outcome == FirestoreRestUpdateOutcome.serverConfirmed;
}

class FirestoreRestFallback {
  FirestoreRestFallback._();

  static const projectId = 'ishtirakati-260f7';
  static const databaseId = '(default)';
  static const _host = 'firestore.googleapis.com';
  static const _timeout = Duration(seconds: 30);
  static const _maxAttempts = 3;

  static Future<FirestoreRestCreateResult> createFirstEncryptedBackup({
    required String uid,
    required String backup,
    required Future<String?> Function(bool forceRefresh) tokenProvider,
    http.Client? client,
    Future<void> Function(Duration delay)? sleeper,
    Random? random,
  }) async {
    final watch = Stopwatch()..start();
    if (!isEncryptedBackupEnvelope(backup)) {
      watch.stop();
      return FirestoreRestCreateResult(
        outcome: FirestoreRestCreateOutcome.invalidPayload,
        httpStatus: null,
        attempts: 0,
        elapsed: watch.elapsed,
      );
    }

    final httpClient = client ?? http.Client();
    final shouldClose = client == null;
    final wait = sleeper ?? Future<void>.delayed;
    final jitter = random ?? Random.secure();
    var attempts = 0;
    var refreshedAfterUnauthorized = false;
    String? token;
    try {
      token = await tokenProvider(true).timeout(_timeout);
      if (token == null || token.isEmpty) {
        watch.stop();
        return FirestoreRestCreateResult(
          outcome: FirestoreRestCreateOutcome.unauthenticated,
          httpStatus: 401,
          attempts: attempts,
          elapsed: watch.elapsed,
        );
      }

      while (attempts < _maxAttempts) {
        attempts++;
        try {
          final response = await httpClient
              .post(
                _commitUri,
                headers: <String, String>{
                  HttpHeaders.authorizationHeader: 'Bearer $token',
                  HttpHeaders.contentTypeHeader: 'application/json',
                },
                body: jsonEncode(buildCreateOnlyCommitBody(
                  uid: uid,
                  backup: backup,
                )),
              )
              .timeout(_timeout);
          final serverStatus = _safeServerStatus(response.body);

          if (response.statusCode == 200 || response.statusCode == 201) {
            watch.stop();
            return FirestoreRestCreateResult(
              outcome: FirestoreRestCreateOutcome.serverConfirmed,
              httpStatus: response.statusCode,
              attempts: attempts,
              elapsed: watch.elapsed,
              serverStatus: serverStatus,
            );
          }
          if (response.statusCode == 401 && !refreshedAfterUnauthorized) {
            refreshedAfterUnauthorized = true;
            token = await tokenProvider(true).timeout(_timeout);
            if (token == null || token.isEmpty) {
              watch.stop();
              return FirestoreRestCreateResult(
                outcome: FirestoreRestCreateOutcome.unauthenticated,
                httpStatus: 401,
                attempts: attempts,
                elapsed: watch.elapsed,
                serverStatus: serverStatus,
              );
            }
            continue;
          }
          if (_isConflict(response.statusCode, serverStatus)) {
            watch.stop();
            return FirestoreRestCreateResult(
              outcome: FirestoreRestCreateOutcome.conflict,
              httpStatus: response.statusCode,
              attempts: attempts,
              elapsed: watch.elapsed,
              serverStatus: serverStatus,
            );
          }
          if (response.statusCode == 401) {
            watch.stop();
            return FirestoreRestCreateResult(
              outcome: FirestoreRestCreateOutcome.unauthenticated,
              httpStatus: 401,
              attempts: attempts,
              elapsed: watch.elapsed,
              serverStatus: serverStatus,
            );
          }
          if (response.statusCode == 403) {
            watch.stop();
            return FirestoreRestCreateResult(
              outcome: FirestoreRestCreateOutcome.permissionDenied,
              httpStatus: 403,
              attempts: attempts,
              elapsed: watch.elapsed,
              serverStatus: serverStatus,
            );
          }
          if ((response.statusCode == 429 || response.statusCode >= 500) &&
              attempts < _maxAttempts) {
            await wait(_retryDelay(attempts, jitter));
            continue;
          }
          watch.stop();
          return FirestoreRestCreateResult(
            outcome: response.statusCode == 429
                ? FirestoreRestCreateOutcome.rateLimited
                : response.statusCode >= 500
                    ? FirestoreRestCreateOutcome.serviceUnavailable
                    : FirestoreRestCreateOutcome.unexpectedFailure,
            httpStatus: response.statusCode,
            attempts: attempts,
            elapsed: watch.elapsed,
            serverStatus: serverStatus,
          );
        } on SocketException catch (error) {
          watch.stop();
          return _networkFailure(watch, attempts, error);
        } on HandshakeException catch (error) {
          watch.stop();
          return _networkFailure(watch, attempts, error);
        } on TimeoutException catch (error) {
          if (attempts < _maxAttempts) {
            await wait(_retryDelay(attempts, jitter));
            continue;
          }
          watch.stop();
          return _networkFailure(watch, attempts, error);
        } on http.ClientException catch (error) {
          watch.stop();
          return _networkFailure(watch, attempts, error);
        }
      }
    } on TimeoutException catch (error) {
      watch.stop();
      return _networkFailure(watch, attempts, error);
    } finally {
      token = null;
      if (shouldClose) httpClient.close();
    }

    watch.stop();
    return FirestoreRestCreateResult(
      outcome: FirestoreRestCreateOutcome.unexpectedFailure,
      httpStatus: null,
      attempts: attempts,
      elapsed: watch.elapsed,
    );
  }

  static Future<FirestoreRestReadResult> readEncryptedBackup({
    required String uid,
    required Future<String?> Function(bool forceRefresh) tokenProvider,
    http.Client? client,
    Future<void> Function(Duration delay)? sleeper,
    Random? random,
  }) async {
    final watch = Stopwatch()..start();
    final httpClient = client ?? http.Client();
    final shouldClose = client == null;
    final wait = sleeper ?? Future<void>.delayed;
    final jitter = random ?? Random.secure();
    var attempts = 0;
    var refreshedAfterUnauthorized = false;
    String? token;
    try {
      token = await tokenProvider(true).timeout(_timeout);
      if (token == null || token.isEmpty) {
        return _readResult(
          watch,
          FirestoreRestReadOutcome.unauthenticated,
          401,
          attempts,
        );
      }
      while (attempts < _maxAttempts) {
        attempts++;
        try {
          final response = await httpClient
              .get(
                _documentUri(uid),
                headers: <String, String>{
                  HttpHeaders.authorizationHeader: 'Bearer $token',
                },
              )
              .timeout(_timeout);
          final serverStatus = _safeServerStatus(response.body);
          if (response.statusCode == 200) {
            final document = _decodeDocument(response.body);
            return _readResult(
              watch,
              document == null
                  ? FirestoreRestReadOutcome.invalidDocument
                  : FirestoreRestReadOutcome.found,
              200,
              attempts,
              document: document,
            );
          }
          if (response.statusCode == 404) {
            return _readResult(
              watch,
              FirestoreRestReadOutcome.missing,
              404,
              attempts,
              serverStatus: serverStatus,
            );
          }
          if (response.statusCode == 401 && !refreshedAfterUnauthorized) {
            refreshedAfterUnauthorized = true;
            token = await tokenProvider(true).timeout(_timeout);
            if (token == null || token.isEmpty) {
              return _readResult(
                watch,
                FirestoreRestReadOutcome.unauthenticated,
                401,
                attempts,
                serverStatus: serverStatus,
              );
            }
            continue;
          }
          if (response.statusCode == 401 || response.statusCode == 403) {
            return _readResult(
              watch,
              response.statusCode == 401
                  ? FirestoreRestReadOutcome.unauthenticated
                  : FirestoreRestReadOutcome.permissionDenied,
              response.statusCode,
              attempts,
              serverStatus: serverStatus,
            );
          }
          if ((response.statusCode == 429 || response.statusCode >= 500) &&
              attempts < _maxAttempts) {
            await wait(_retryDelay(attempts, jitter));
            continue;
          }
          return _readResult(
            watch,
            response.statusCode == 429
                ? FirestoreRestReadOutcome.rateLimited
                : response.statusCode >= 500
                    ? FirestoreRestReadOutcome.serviceUnavailable
                    : FirestoreRestReadOutcome.unexpectedFailure,
            response.statusCode,
            attempts,
            serverStatus: serverStatus,
          );
        } on SocketException catch (error) {
          return _readNetworkFailure(watch, attempts, error);
        } on HandshakeException catch (error) {
          return _readNetworkFailure(watch, attempts, error);
        } on TimeoutException catch (error) {
          if (attempts < _maxAttempts) {
            await wait(_retryDelay(attempts, jitter));
            continue;
          }
          return _readNetworkFailure(watch, attempts, error);
        } on http.ClientException catch (error) {
          return _readNetworkFailure(watch, attempts, error);
        }
      }
    } on TimeoutException catch (error) {
      return _readNetworkFailure(watch, attempts, error);
    } finally {
      token = null;
      if (shouldClose) httpClient.close();
    }
    return _readResult(
      watch,
      FirestoreRestReadOutcome.unexpectedFailure,
      null,
      attempts,
    );
  }

  static Future<FirestoreRestUpdateResult> updateEncryptedBackup({
    required String uid,
    required String backup,
    required int nextRevision,
    required String remoteUpdateTime,
    required Future<String?> Function(bool forceRefresh) tokenProvider,
    http.Client? client,
    Future<void> Function(Duration delay)? sleeper,
    Random? random,
  }) async {
    final watch = Stopwatch()..start();
    if (!isEncryptedBackupEnvelope(backup) ||
        nextRevision < 2 ||
        remoteUpdateTime.isEmpty) {
      return _updateResult(
        watch,
        FirestoreRestUpdateOutcome.invalidPayload,
        null,
        0,
      );
    }
    final httpClient = client ?? http.Client();
    final shouldClose = client == null;
    final wait = sleeper ?? Future<void>.delayed;
    final jitter = random ?? Random.secure();
    var attempts = 0;
    var refreshedAfterUnauthorized = false;
    String? token;
    try {
      token = await tokenProvider(true).timeout(_timeout);
      if (token == null || token.isEmpty) {
        return _updateResult(
          watch,
          FirestoreRestUpdateOutcome.unauthenticated,
          401,
          attempts,
        );
      }
      while (attempts < _maxAttempts) {
        attempts++;
        try {
          final response = await httpClient
              .post(
                _commitUri,
                headers: <String, String>{
                  HttpHeaders.authorizationHeader: 'Bearer $token',
                  HttpHeaders.contentTypeHeader: 'application/json',
                },
                body: jsonEncode(buildRevisionUpdateCommitBody(
                  uid: uid,
                  backup: backup,
                  revision: nextRevision,
                  remoteUpdateTime: remoteUpdateTime,
                )),
              )
              .timeout(_timeout);
          final serverStatus = _safeServerStatus(response.body);
          if (response.statusCode == 200 || response.statusCode == 201) {
            return _updateResult(
              watch,
              FirestoreRestUpdateOutcome.serverConfirmed,
              response.statusCode,
              attempts,
              serverStatus: serverStatus,
            );
          }
          if (response.statusCode == 401 && !refreshedAfterUnauthorized) {
            refreshedAfterUnauthorized = true;
            token = await tokenProvider(true).timeout(_timeout);
            if (token == null || token.isEmpty) {
              return _updateResult(
                watch,
                FirestoreRestUpdateOutcome.unauthenticated,
                401,
                attempts,
                serverStatus: serverStatus,
              );
            }
            continue;
          }
          if (_isConflict(response.statusCode, serverStatus)) {
            return _updateResult(
              watch,
              FirestoreRestUpdateOutcome.conflict,
              response.statusCode,
              attempts,
              serverStatus: serverStatus,
            );
          }
          if (response.statusCode == 401 || response.statusCode == 403) {
            return _updateResult(
              watch,
              response.statusCode == 401
                  ? FirestoreRestUpdateOutcome.unauthenticated
                  : FirestoreRestUpdateOutcome.permissionDenied,
              response.statusCode,
              attempts,
              serverStatus: serverStatus,
            );
          }
          if ((response.statusCode == 429 || response.statusCode >= 500) &&
              attempts < _maxAttempts) {
            await wait(_retryDelay(attempts, jitter));
            continue;
          }
          return _updateResult(
            watch,
            response.statusCode == 429
                ? FirestoreRestUpdateOutcome.rateLimited
                : response.statusCode >= 500
                    ? FirestoreRestUpdateOutcome.serviceUnavailable
                    : FirestoreRestUpdateOutcome.unexpectedFailure,
            response.statusCode,
            attempts,
            serverStatus: serverStatus,
          );
        } on SocketException catch (error) {
          return _updateNetworkFailure(watch, attempts, error);
        } on HandshakeException catch (error) {
          return _updateNetworkFailure(watch, attempts, error);
        } on TimeoutException catch (error) {
          if (attempts < _maxAttempts) {
            await wait(_retryDelay(attempts, jitter));
            continue;
          }
          return _updateNetworkFailure(watch, attempts, error);
        } on http.ClientException catch (error) {
          return _updateNetworkFailure(watch, attempts, error);
        }
      }
    } on TimeoutException catch (error) {
      return _updateNetworkFailure(watch, attempts, error);
    } finally {
      token = null;
      if (shouldClose) httpClient.close();
    }
    return _updateResult(
      watch,
      FirestoreRestUpdateOutcome.unexpectedFailure,
      null,
      attempts,
    );
  }

  static Uri get _commitUri => Uri.https(
        _host,
        '/v1/projects/$projectId/databases/$databaseId/documents:commit',
      );

  static Uri _documentUri(String uid) => Uri.https(
        _host,
        '/v1/projects/$projectId/databases/$databaseId/documents/users/'
        '${Uri.encodeComponent(uid)}',
      );

  @visibleForTesting
  static Map<String, Object> buildCreateOnlyCommitBody({
    required String uid,
    required String backup,
  }) {
    final documentName =
        'projects/$projectId/databases/$databaseId/documents/users/$uid';
    return <String, Object>{
      'writes': <Object>[
        <String, Object>{
          'update': <String, Object>{
            'name': documentName,
            'fields': <String, Object>{
              'backup': <String, Object>{'stringValue': backup},
              'schemaVersion': <String, Object>{'integerValue': '2'},
              'revision': <String, Object>{'integerValue': '1'},
              'encryption': <String, Object>{
                'stringValue': 'AES-256-GCM',
              },
            },
          },
          'currentDocument': <String, Object>{'exists': false},
          'updateTransforms': <Object>[
            <String, Object>{
              'fieldPath': 'updatedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
          ],
        },
      ],
    };
  }

  @visibleForTesting
  static Map<String, Object> buildRevisionUpdateCommitBody({
    required String uid,
    required String backup,
    required int revision,
    required String remoteUpdateTime,
  }) {
    final documentName =
        'projects/$projectId/databases/$databaseId/documents/users/$uid';
    return <String, Object>{
      'writes': <Object>[
        <String, Object>{
          'update': <String, Object>{
            'name': documentName,
            'fields': <String, Object>{
              'backup': <String, Object>{'stringValue': backup},
              'schemaVersion': <String, Object>{'integerValue': '2'},
              'revision': <String, Object>{
                'integerValue': revision.toString(),
              },
              'encryption': <String, Object>{
                'stringValue': 'AES-256-GCM',
              },
            },
          },
          'currentDocument': <String, Object>{
            'updateTime': remoteUpdateTime,
          },
          'updateTransforms': <Object>[
            <String, Object>{
              'fieldPath': 'updatedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
          ],
        },
      ],
    };
  }

  static bool isEncryptedBackupEnvelope(String backup) {
    try {
      final decoded = jsonDecode(backup);
      if (decoded is! Map<String, dynamic>) return false;
      return decoded.keys.toSet().containsAll(<String>{'v', 'n', 'c', 'm'}) &&
          !decoded.containsKey('subscriptions');
    } catch (_) {
      return false;
    }
  }

  static bool _isConflict(int status, String? serverStatus) =>
      status == 409 ||
      status == 412 ||
      serverStatus == 'ALREADY_EXISTS' ||
      serverStatus == 'FAILED_PRECONDITION';

  static FirestoreRestDocument? _decodeDocument(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final fields = decoded['fields'];
      final updateTime = decoded['updateTime'];
      if (fields is! Map<String, dynamic> || updateTime is! String) return null;
      final backup = _stringField(fields['backup']);
      final revision = _integerField(fields['revision']);
      final schemaVersion = _integerField(fields['schemaVersion']);
      final encryption = _stringField(fields['encryption']);
      if (backup == null ||
          revision == null ||
          schemaVersion == null ||
          encryption == null ||
          updateTime.isEmpty) {
        return null;
      }
      return FirestoreRestDocument(
        backup: backup,
        revision: revision,
        schemaVersion: schemaVersion,
        encryption: encryption,
        updateTime: updateTime,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _stringField(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return value['stringValue'] as String?;
  }

  static int? _integerField(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final raw = value['integerValue'];
    return raw is String ? int.tryParse(raw) : (raw as num?)?.toInt();
  }

  static String? _safeServerStatus(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final error = decoded['error'];
      if (error is! Map<String, dynamic>) return null;
      final status = error['status'];
      return status is String && status.length <= 64 ? status : null;
    } catch (_) {
      return null;
    }
  }

  static Duration _retryDelay(int attempt, Random random) {
    final base = min(500 * (1 << (attempt - 1)), 4000);
    return Duration(milliseconds: base + random.nextInt(401));
  }

  static FirestoreRestCreateResult _networkFailure(
    Stopwatch watch,
    int attempts,
    Object error,
  ) =>
      FirestoreRestCreateResult(
        outcome: FirestoreRestCreateOutcome.networkFailure,
        httpStatus: null,
        attempts: attempts,
        elapsed: watch.elapsed,
        exceptionType: error.runtimeType.toString(),
      );

  static FirestoreRestReadResult _readResult(
    Stopwatch watch,
    FirestoreRestReadOutcome outcome,
    int? httpStatus,
    int attempts, {
    FirestoreRestDocument? document,
    String? exceptionType,
    String? serverStatus,
  }) {
    watch.stop();
    return FirestoreRestReadResult(
      outcome: outcome,
      httpStatus: httpStatus,
      attempts: attempts,
      elapsed: watch.elapsed,
      document: document,
      exceptionType: exceptionType,
      serverStatus: serverStatus,
    );
  }

  static FirestoreRestReadResult _readNetworkFailure(
    Stopwatch watch,
    int attempts,
    Object error,
  ) =>
      _readResult(
        watch,
        FirestoreRestReadOutcome.networkFailure,
        null,
        attempts,
        exceptionType: error.runtimeType.toString(),
      );

  static FirestoreRestUpdateResult _updateResult(
    Stopwatch watch,
    FirestoreRestUpdateOutcome outcome,
    int? httpStatus,
    int attempts, {
    String? exceptionType,
    String? serverStatus,
  }) {
    watch.stop();
    return FirestoreRestUpdateResult(
      outcome: outcome,
      httpStatus: httpStatus,
      attempts: attempts,
      elapsed: watch.elapsed,
      exceptionType: exceptionType,
      serverStatus: serverStatus,
    );
  }

  static FirestoreRestUpdateResult _updateNetworkFailure(
    Stopwatch watch,
    int attempts,
    Object error,
  ) =>
      _updateResult(
        watch,
        FirestoreRestUpdateOutcome.networkFailure,
        null,
        attempts,
        exceptionType: error.runtimeType.toString(),
      );
}
