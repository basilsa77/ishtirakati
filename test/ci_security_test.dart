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

  test('Git ignores credential material and generated Firebase logs', () {
    final ignore = File('.gitignore').readAsStringSync();
    for (final pattern in <String>[
      '**/GoogleService-Info.plist',
      '**/google-services.json',
      '.env.*',
      '*.p8',
      '*.p12',
      '*.mobileprovision',
      '*.jks',
      'firebase-service-account*.json',
      'firebase-debug.log*',
      'firestore-debug.log*',
    ]) {
      expect(ignore, contains(pattern), reason: 'missing ignore: $pattern');
    }
  });

  test('publishing helper requires explicit staging and a review branch', () {
    final helper = File('push_to_github.bat').readAsStringSync();
    expect(helper, isNot(contains('git add .')));
    expect(helper, isNot(contains('git branch -M main')));
    expect(helper, isNot(contains('git push -u origin main')));
    expect(helper, contains('git branch --show-current'));
    expect(helper, contains('Direct publication from main is forbidden'));
    expect(helper, contains('git diff --cached --name-only'));
    expect(helper, contains('git push -u origin "%CURRENT_BRANCH%"'));
  });
}
