import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Firestore deployment is gated and tested', () {
    final workflow =
        File('.github/workflows/deploy-firestore.yml').readAsStringSync();

    expect(workflow, contains("if: github.ref == 'refs/heads/main'"));
    expect(workflow, contains('environment: firebase-production'));

    final testRules = workflow.indexOf('npm run test:rules');
    final credentials = workflow.indexOf(
      'FIREBASE_SERVICE_ACCOUNT_ISHTIRAKATI_260F7',
    );
    final deploy = workflow.indexOf('firebase-tools deploy');

    expect(testRules, greaterThanOrEqualTo(0));
    expect(credentials, greaterThan(testRules));
    expect(deploy, greaterThan(credentials));
  });
}
