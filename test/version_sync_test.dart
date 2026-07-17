/// حارس الإصدار: يضمن تطابق kAppVersion مع رقم الإصدار في pubspec.yaml.
library;

/// اختلافهما يسبب ظهور بانر "نسخة أحدث متاحة" بشكل دائم للمستخدم.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/update_checker.dart';

void main() {
  test('kAppVersion يطابق إصدار pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'تعذر قراءة version من pubspec.yaml');
    expect(
      kAppVersion,
      match!.group(1),
      reason:
          'حدث kAppVersion في lib/services/update_checker.dart ليطابق pubspec.yaml وإلا سيظهر بانر التحديث دائمًا.',
    );
    expect(kAppBuildNumber, match.group(2));
  });

  test('v16 metadata and CI artifact names stay synchronized', () {
    const release = '$kAppVersion+$kAppBuildNumber';
    const artifact = 'Ishtirakati-$kAppVersion-build$kAppBuildNumber';
    final readme = File('README.md').readAsStringSync();
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final workflow = File('.github/workflows/build-ipa.yml').readAsStringSync();
    final buildGuide = File('BUILD_IPA_GUIDE.md').readAsStringSync();
    final pushScript = File('push_to_github.bat').readAsStringSync();
    final settings =
        File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(readme, startsWith('# اشتراكاتي $release'));
    expect(readme, contains('- النسخة: `$release`'));
    expect(
      RegExp(
        r'^##\s+(\d+\.\d+\.\d+\+\d+)',
        multiLine: true,
      ).firstMatch(changelog)?.group(1),
      release,
    );
    expect(workflow, contains('$artifact-\${SHORT_SHA}-unsigned.ipa'));
    expect(
      workflow,
      contains('pubspec-lock-v$kAppVersion-build$kAppBuildNumber'),
    );
    expect(buildGuide, contains('$artifact-<SHA>-unsigned.ipa'));
    expect(pushScript, contains('RELEASE_VERSION=$kAppVersion'));
    expect(pushScript, contains('v$release:'));
    expect(settings, contains(r"'$kAppVersion ($kAppBuildNumber)'"));
    expect(settings, contains('value: kAppVersion'));
    expect(settings, contains('value: kAppBuildNumber'));
  });
}
