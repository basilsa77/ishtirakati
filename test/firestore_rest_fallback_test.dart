import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ishtirakati/services/firebase_build_config.dart';
import 'package:ishtirakati/services/firestore_rest_fallback.dart';

const encryptedBackup = '{"v":1,"n":"nonce","c":"cipher","m":"mac"}';

void main() {
  test('create-only commit contains encrypted v2 revision one payload', () {
    final body = FirestoreRestFallback.buildCreateOnlyCommitBody(
      uid: 'test-uid',
      backup: encryptedBackup,
    );
    final writes = body['writes']! as List<Object>;
    final write = writes.single as Map<String, Object>;
    final update = write['update']! as Map<String, Object>;
    final fields = update['fields']! as Map<String, Object>;

    expect(write['currentDocument'], {'exists': false});
    expect(write['updateTransforms'], [
      {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
    ]);
    expect(fields['backup'], {'stringValue': encryptedBackup});
    expect(fields['schemaVersion'], {'integerValue': '2'});
    expect(fields['revision'], {'integerValue': '1'});
    expect(fields['encryption'], {'stringValue': 'AES-256-GCM'});
    expect(jsonEncode(body), isNot(contains('subscriptions')));
  });

  test('HTTP 200 confirms creation without exposing the payload in result',
      () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token-1');
      return http.Response('{"commitTime":"2026-07-15T00:00:00Z"}', 200);
    });

    final result = await FirestoreRestFallback.createFirstEncryptedBackup(
      uid: 'test-uid',
      backup: encryptedBackup,
      tokenProvider: (_) async => 'token-1',
      client: client,
    );

    expect(result.confirmed, isTrue);
    expect(result.httpStatus, 200);
    expect(result.toString(), isNot(contains('token-1')));
    expect(result.toString(), isNot(contains(encryptedBackup)));
  });

  test('HTTP 409 never overwrites an existing document', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(
        '{"error":{"status":"ALREADY_EXISTS"}}',
        409,
      );
    });

    final result = await FirestoreRestFallback.createFirstEncryptedBackup(
      uid: 'test-uid',
      backup: encryptedBackup,
      tokenProvider: (_) async => 'token-1',
      client: client,
    );

    expect(result.outcome, FirestoreRestCreateOutcome.conflict);
    expect(calls, 1);
  });

  test('HTTP 401 refreshes the token once and then succeeds', () async {
    var requests = 0;
    var tokenRequests = 0;
    final client = MockClient((request) async {
      requests++;
      return requests == 1
          ? http.Response('{"error":{"status":"UNAUTHENTICATED"}}', 401)
          : http.Response('{"commitTime":"2026-07-15T00:00:00Z"}', 200);
    });

    final result = await FirestoreRestFallback.createFirstEncryptedBackup(
      uid: 'test-uid',
      backup: encryptedBackup,
      tokenProvider: (_) async => 'token-${++tokenRequests}',
      client: client,
    );

    expect(result.confirmed, isTrue);
    expect(tokenRequests, 2);
    expect(requests, 2);
  });

  test('HTTP 403 returns permission failure without retry', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{"error":{"status":"PERMISSION_DENIED"}}', 403);
    });

    final result = await FirestoreRestFallback.createFirstEncryptedBackup(
      uid: 'test-uid',
      backup: encryptedBackup,
      tokenProvider: (_) async => 'token-1',
      client: client,
    );

    expect(result.outcome, FirestoreRestCreateOutcome.permissionDenied);
    expect(calls, 1);
  });

  test('REST GET 404 proves the document is missing before create', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response('{"error":{"status":"NOT_FOUND"}}', 404);
    });

    final result = await FirestoreRestFallback.readEncryptedBackup(
      uid: 'test-uid',
      tokenProvider: (_) async => 'token-1',
      client: client,
    );

    expect(result.outcome, FirestoreRestReadOutcome.missing);
    expect(result.httpStatus, 404);
  });

  test('REST GET reads revision and updateTime without exposing backup',
      () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'fields': {
              'backup': {'stringValue': encryptedBackup},
              'schemaVersion': {'integerValue': '2'},
              'revision': {'integerValue': '7'},
              'encryption': {'stringValue': 'AES-256-GCM'},
            },
            'updateTime': '2026-07-15T01:02:03.000000Z',
          }),
          200,
        ));

    final result = await FirestoreRestFallback.readEncryptedBackup(
      uid: 'test-uid',
      tokenProvider: (_) async => 'token-1',
      client: client,
    );

    expect(result.outcome, FirestoreRestReadOutcome.found);
    expect(result.document?.revision, 7);
    expect(result.document?.updateTime, '2026-07-15T01:02:03.000000Z');
    expect(result.toString(), isNot(contains(encryptedBackup)));
  });

  test('REST update advances revision and uses updateTime precondition', () {
    final body = FirestoreRestFallback.buildRevisionUpdateCommitBody(
      uid: 'test-uid',
      backup: encryptedBackup,
      revision: 2,
      remoteUpdateTime: '2026-07-15T01:02:03.000000Z',
    );
    final write = (body['writes']! as List<Object>).single
        as Map<String, Object>;
    final update = write['update']! as Map<String, Object>;
    final fields = update['fields']! as Map<String, Object>;

    expect(fields['revision'], {'integerValue': '2'});
    expect(write['currentDocument'], {
      'updateTime': '2026-07-15T01:02:03.000000Z',
    });
    expect(write['updateTransforms'], [
      {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
    ]);
    expect(jsonEncode(body), isNot(contains('subscriptions')));
  });

  test('REST update HTTP 200 is server-confirmed', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      return http.Response('{"commitTime":"2026-07-15T00:00:00Z"}', 200);
    });

    final result = await FirestoreRestFallback.updateEncryptedBackup(
      uid: 'test-uid',
      backup: encryptedBackup,
      nextRevision: 2,
      remoteUpdateTime: '2026-07-15T01:02:03.000000Z',
      tokenProvider: (_) async => 'token-1',
      client: client,
    );

    expect(result.confirmed, isTrue);
    expect(result.httpStatus, 200);
  });

  test('REST update precondition conflict never overwrites newer data',
      () async {
    final client = MockClient((request) async => http.Response(
          '{"error":{"status":"FAILED_PRECONDITION"}}',
          412,
        ));

    final result = await FirestoreRestFallback.updateEncryptedBackup(
      uid: 'test-uid',
      backup: encryptedBackup,
      nextRevision: 2,
      remoteUpdateTime: '2026-07-15T01:02:03.000000Z',
      tokenProvider: (_) async => 'token-1',
      client: client,
    );

    expect(result.outcome, FirestoreRestUpdateOutcome.conflict);
  });

  test('App Check debug provider is restricted to internal App Check builds',
      () {
    expect(
      FirebaseBuildConfig.debugProviderAllowed(
        internal: false,
        appCheck: true,
        requested: true,
      ),
      isFalse,
    );
    expect(
      FirebaseBuildConfig.debugProviderAllowed(
        internal: true,
        appCheck: false,
        requested: true,
      ),
      isFalse,
    );
    expect(
      FirebaseBuildConfig.debugProviderAllowed(
        internal: true,
        appCheck: true,
        requested: true,
      ),
      isTrue,
    );
  });
}
