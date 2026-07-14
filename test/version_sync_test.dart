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
    )
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'تعذر قراءة version من pubspec.yaml');
    expect(
      kAppVersion,
      match!.group(1),
      reason:
          'حدث kAppVersion في lib/services/update_checker.dart ليطابق pubspec.yaml وإلا سيظهر بانر التحديث دائمًا.',
    );
    expect(kAppBuildNumber, match.group(2));
  });
}
