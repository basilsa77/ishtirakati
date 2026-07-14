import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/models/subscription.dart';

void main() {
  test('v14 reads a v13 subscription without changing user data', () {
    final source = <String, dynamic>{
      'schemaVersion': 13,
      'id': 'v13-user-record',
      'name': 'خدمة حالية',
      'emoji': 'S',
      'price': 74.99,
      'currency': 'SAR',
      'cycle': BillingCycle.yearly.index,
      'anchorDate': '2026-05-12T00:00:00.000',
      'category': 'إنتاجية وذكاء اصطناعي',
      'notes': 'بيانات مستخدم موجودة',
      'isPaused': false,
      'paymentMethod': 'Apple Pay',
      'manageUrl': 'https://example.com/account',
      'reminderDays': 7,
      'isFamily': true,
      'familyMembers': 4,
      'autoRenews': true,
      'isEssential': true,
      'planName': 'احترافية',
      'usageCount': 6,
      'iconUrl': 'https://example.com/icon.png',
      'kind': PaymentKind.subscription.index,
      'priceHistory': <Object>[],
    };

    final decoded = Subscription.fromJson(source);
    final encoded = decoded.toJson();

    expect(encoded['schemaVersion'], 13);
    for (final key in <String>[
      'id',
      'name',
      'price',
      'currency',
      'category',
      'notes',
      'paymentMethod',
      'manageUrl',
      'reminderDays',
      'isFamily',
      'familyMembers',
      'autoRenews',
      'isEssential',
      'planName',
      'usageCount',
      'iconUrl',
      'kind',
    ]) {
      expect(encoded[key], source[key], reason: 'field $key must survive v14');
    }
  });

  test('v14 corrected screens do not use Material popup controls', () {
    const paths = <String>[
      'lib/screens/settings_screen.dart',
      'lib/screens/email_link_screen.dart',
      'lib/screens/subscriptions_screen.dart',
      'lib/screens/edit_subscription_screen.dart',
      'lib/screens/quick_add_sheet.dart',
    ];
    const forbidden = <String>[
      'DropdownButtonFormField',
      'PopupMenuButton',
      'showModalBottomSheet',
      'MaterialPageRoute',
      'SwitchListTile',
      'ScaffoldMessenger',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      for (final token in forbidden) {
        expect(source, isNot(contains(token)), reason: '$path contains $token');
      }
    }
  });
}
