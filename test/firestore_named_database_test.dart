import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/firestore_config.dart';
import 'package:ishtirakati/services/firestore_rest_fallback.dart';

void main() {
  test('production database ID is the Enterprise named database default', () {
    expect(FirestoreConfig.databaseId, 'default');
    final firebaseConfig = File('firebase.json').readAsStringSync();
    final deploymentWorkflow =
        File('.github/workflows/deploy-firestore.yml').readAsStringSync();
    expect(firebaseConfig, contains('"database": "default"'));
    expect(deploymentWorkflow, contains("c.firestore?.database!=='default'"));
  });

  test('production operations never use the implicit Firestore instance', () {
    final violations = <String>[];
    final implicitInstance = RegExp(r'FirebaseFirestore\.instance(?!For)');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (implicitInstance.hasMatch(entity.readAsStringSync())) {
        violations.add(entity.path);
      }
    }
    expect(violations, isEmpty);
  });

  test('REST document and commit paths target databases/default', () {
    final uris = <Uri>[
      FirestoreRestFallback.commitUriForTesting,
      FirestoreRestFallback.documentUriForTesting('test-user'),
    ];
    for (final uri in uris) {
      expect(uri.path, contains('/databases/default/'));
      expect(uri.path, isNot(contains('/databases/(default)/')));
    }

    final createBody =
        FirestoreRestFallback.buildCreateOnlyCommitBody(
          uid: 'test-user',
          backup: '{"v":2,"n":"AA","c":"AA","m":"AA"}',
        ).toString();
    final updateBody =
        FirestoreRestFallback.buildRevisionUpdateCommitBody(
          uid: 'test-user',
          backup: '{"v":2,"n":"AA","c":"AA","m":"AA"}',
          revision: 2,
          remoteUpdateTime: '2026-07-18T00:00:00.000000Z',
        ).toString();
    expect(createBody, contains('/databases/default/'));
    expect(updateBody, contains('/databases/default/'));
    expect('$createBody$updateBody', isNot(contains('/databases/(default)/')));
  });

  test('first-create and revision update preserve conflict preconditions', () {
    final create = FirestoreRestFallback.buildCreateOnlyCommitBody(
      uid: 'test-user',
      backup: '{"v":2,"n":"AA","c":"AA","m":"AA"}',
    );
    final createWrite = (create['writes']! as List).single as Map;
    expect(createWrite['currentDocument'], <String, Object>{'exists': false});

    final update = FirestoreRestFallback.buildRevisionUpdateCommitBody(
      uid: 'test-user',
      backup: '{"v":2,"n":"AA","c":"AA","m":"AA"}',
      revision: 8,
      remoteUpdateTime: '2026-07-18T00:00:00.000000Z',
    );
    final updateWrite = (update['writes']! as List).single as Map;
    expect(updateWrite['currentDocument'], <String, Object>{
      'updateTime': '2026-07-18T00:00:00.000000Z',
    });
  });
}
