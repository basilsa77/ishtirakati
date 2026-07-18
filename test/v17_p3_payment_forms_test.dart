import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/l10n/app_localizations.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/screens/edit_subscription_screen.dart';
import 'package:ishtirakati/screens/quick_add_sheet.dart';
import 'package:ishtirakati/services/amount_input_parser.dart';
import 'package:ishtirakati/theme.dart';
import 'package:ishtirakati/widgets/app_material_root.dart';

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Locale locale,
  required double width,
  required Widget home,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await AppLocalizations.load(locale);
  setDefaultFormattingLocale(locale);
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(size: Size(width, 844), disableAnimations: true),
          child: AppMaterialRoot(child: child!),
        );
      },
      home: home,
    ),
  );
  await tester.pump();
}

Widget _quickAddHost({SubscriptionSaver? saveSubscription}) =>
    CupertinoPageScaffold(
      child: Builder(
        builder:
            (context) => Center(
              child: CupertinoButton(
                key: const Key('open-quick-add'),
                onPressed:
                    () => showQuickAddSheet(
                      context,
                      saveSubscription: saveSubscription,
                    ),
                child: const Text('Open'),
              ),
            ),
      ),
    );

Finder _textFieldInside(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byType(CupertinoTextField),
);

Future<void> _openQuickAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-quick-add')));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      260,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder);
  await tester.pump();
}

Subscription _subscription({String paymentMethod = 'غير محدد'}) => Subscription(
  id: 'legacy-payment',
  name: 'Legacy Service',
  emoji: 'L',
  price: 12.5,
  currency: 'SAR',
  cycle: BillingCycle.monthly,
  anchorDate: DateTime(2026, 7, 19),
  category: 'أخرى',
  paymentMethod: paymentMethod,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  group('localized amount parser', () {
    test('accepts dot, comma, Arabic separators, and Arabic digits', () {
      expect(parseLocalizedAmount('19.99'), 19.99);
      expect(parseLocalizedAmount('19,99'), 19.99);
      expect(parseLocalizedAmount('١٩٫٩٩'), 19.99);
      expect(parseLocalizedAmount('۱۹،۹۹'), 19.99);
      expect(parseLocalizedAmount('1,234.56'), 1234.56);
      expect(parseLocalizedAmount('1.234,56'), 1234.56);
      expect(parseLocalizedAmount('١٬٢٣٤٫٥٦'), 1234.56);
    });

    test('rejects malformed and non-finite numeric syntax', () {
      expect(parseLocalizedAmount(''), isNull);
      expect(parseLocalizedAmount('abc'), isNull);
      expect(parseLocalizedAmount('1,2,3'), isNull);
      expect(parseLocalizedAmount('1e6'), isNull);
      expect(parseLocalizedAmount('NaN'), isNull);
      expect(parseLocalizedAmount('Infinity'), isNull);
    });

    test('distinguishes every inline validation state', () {
      expect(validateAmountInput('').issue, AmountInputIssue.empty);
      expect(validateAmountInput('not money').issue, AmountInputIssue.invalid);
      expect(validateAmountInput('0').issue, AmountInputIssue.zero);
      expect(validateAmountInput('-0.01').issue, AmountInputIssue.negative);
      expect(validateAmountInput('7,25').value, 7.25);
    });
  });

  testWidgets('stored payment values keep distinct display-only labels', (
    tester,
  ) async {
    expect(kPaymentMethods, contains('رصيد المتجر'));
    expect(kPaymentMethods, contains('أخرى'));

    await AppLocalizations.load(const Locale('ar'));
    expect(localizedPaymentMethod('رصيد المتجر'), 'رصيد متجر التطبيقات');
    expect(localizedPaymentMethod('أخرى'), 'وسيلة دفع أخرى');
    expect(localizedPaymentMethod('وسيلة قديمة مخصصة'), 'وسيلة قديمة مخصصة');

    await AppLocalizations.load(const Locale('en'));
    expect(localizedPaymentMethod('رصيد المتجر'), 'App Store Balance');
    expect(localizedPaymentMethod('أخرى'), 'Other payment method');
    expect(localizedPaymentMethod('وسيلة قديمة مخصصة'), 'وسيلة قديمة مخصصة');
  });

  test('unknown legacy payment method survives model round-trip', () {
    const legacyValue = 'وسيلة قديمة مخصصة';
    final restored = Subscription.fromJson(
      _subscription(paymentMethod: legacyValue).toJson(),
    );
    expect(restored.paymentMethod, legacyValue);
  });

  testWidgets('quick amount starts empty with 0.00 as placeholder only', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in const [375.0, 390.0]) {
        await _pumpLocalized(
          tester,
          locale: locale,
          width: width,
          home: _quickAddHost(),
        );
        await _openQuickAdd(tester);
        final amount = tester.widget<CupertinoTextField>(
          _textFieldInside(const Key('quick-amount-field')),
        );
        expect(amount.controller?.text, isEmpty);
        expect(amount.placeholder, '0.00');
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('quick form reports every invalid case inline', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saves = 0;
    await _pumpLocalized(
      tester,
      locale: const Locale('en'),
      width: 375,
      home: _quickAddHost(
        saveSubscription: (_) async {
          saves += 1;
        },
      ),
    );
    await _openQuickAdd(tester);

    final name = _textFieldInside(const Key('quick-service-name-field'));
    final amount = _textFieldInside(const Key('quick-amount-field'));
    await tester.enterText(amount, '12');
    await _tapVisible(tester, const Key('quick-save-button'));
    expect(find.text('Enter the service name.'), findsOneWidget);

    await tester.enterText(name, 'Service');
    await tester.enterText(amount, '');
    await _tapVisible(tester, const Key('quick-save-button'));
    expect(find.text('Enter an amount.'), findsOneWidget);

    await tester.enterText(amount, 'not a number');
    await _tapVisible(tester, const Key('quick-save-button'));
    expect(find.text('Enter a valid numeric amount.'), findsOneWidget);

    await tester.enterText(amount, '0');
    await _tapVisible(tester, const Key('quick-save-button'));
    expect(find.text('The amount must be greater than zero.'), findsOneWidget);

    await tester.enterText(amount, '-5');
    await _tapVisible(tester, const Key('quick-save-button'));
    expect(find.text('The amount cannot be negative.'), findsOneWidget);
    expect(saves, 0);

    final field = tester.widget<CupertinoTextField>(amount);
    final decoration = field.decoration!;
    final context = tester.element(find.byKey(const Key('quick-amount-field')));
    expect((decoration.border! as Border).top.color, context.palette.danger);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick form accepts comma and saves exactly once', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<void>();
    final saved = <Subscription>[];
    await _pumpLocalized(
      tester,
      locale: const Locale('ar'),
      width: 390,
      home: _quickAddHost(
        saveSubscription: (subscription) {
          saved.add(subscription);
          return gate.future;
        },
      ),
    );
    await _openQuickAdd(tester);
    await tester.enterText(
      _textFieldInside(const Key('quick-service-name-field')),
      'Service',
    );
    await tester.enterText(
      _textFieldInside(const Key('quick-amount-field')),
      '١٢،٥٠',
    );
    final save = find.byKey(const Key('quick-save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(saved, hasLength(1));
    expect(saved.single.price, 12.5);

    gate.complete();
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
  });

  testWidgets('full form uses inline errors and prevents double submit', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<void>();
    final saved = <Subscription>[];
    await _pumpLocalized(
      tester,
      locale: const Locale('en'),
      width: 375,
      home: EditSubscriptionScreen(
        saveSubscription: (subscription) {
          saved.add(subscription);
          return gate.future;
        },
      ),
    );

    expect(
      tester
          .widget<CupertinoTextField>(
            _textFieldInside(const Key('full-amount-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
    await _tapVisible(tester, const Key('full-save-button'));
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 1200),
      3000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter the subscription name.'), findsOneWidget);
    expect(find.text('Enter an amount.'), findsOneWidget);
    expect(saved, isEmpty);

    await tester.enterText(
      _textFieldInside(const Key('full-service-name-field')),
      'Service',
    );
    await tester.enterText(
      _textFieldInside(const Key('full-amount-field')),
      '25.75',
    );
    await _tapVisible(tester, const Key('full-save-button'));
    final save = find.byKey(const Key('full-save-button'));
    await tester.tap(save);
    await tester.pump();
    expect(saved, hasLength(1));
    expect(saved.single.price, 25.75);

    gate.complete();
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
  });

  testWidgets('editing preserves an unknown legacy payment method', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const legacyValue = 'وسيلة قديمة مخصصة';
    Subscription? saved;
    await _pumpLocalized(
      tester,
      locale: const Locale('ar'),
      width: 390,
      home: EditSubscriptionScreen(
        existing: _subscription(paymentMethod: legacyValue),
        saveSubscription: (subscription) async {
          saved = subscription;
        },
      ),
    );
    expect(find.text(legacyValue), findsOneWidget);
    await _tapVisible(tester, const Key('full-save-button'));
    await tester.pumpAndSettle();
    expect(saved?.paymentMethod, legacyValue);
  });
}
