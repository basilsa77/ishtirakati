import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ishtirakati/l10n/app_localizations.dart';
import 'package:ishtirakati/models/subscription.dart';
import 'package:ishtirakati/models/subscription_schema.dart';
import 'package:ishtirakati/screens/settings_screen.dart';
import 'package:ishtirakati/services/backup_file_service.dart';
import 'package:ishtirakati/services/secure_data_codec.dart';
import 'package:ishtirakati/services/subscription_store.dart';
import 'package:ishtirakati/theme.dart';

class _MemoryKeyStore implements SecureKeyStore {
  final List<String> values = <String>[];

  @override
  Future<void> deleteAll(String key) async => values.clear();

  @override
  Future<List<String>> readAll(String key) async => List<String>.of(values);

  @override
  Future<bool> writeAll(String key, String value) async {
    if (!values.contains(value)) values.add(value);
    return true;
  }
}

class _ToggleCodec extends SecureDataCodec {
  _ToggleCodec({required super.keyStore});

  bool failEncryption = false;

  @override
  Future<String> encrypt(String plainText) {
    if (failEncryption) {
      throw const SecureDataException('injected persistence failure');
    }
    return super.encrypt(plainText);
  }
}

class _FakeGateway implements BackupFileGateway {
  BackupShareStatus shareStatus = BackupShareStatus.success;
  String? selectedFile;
  String? sharedContents;

  @override
  Future<String?> pickEncryptedBackup() async => selectedFile;

  @override
  Future<BackupShareStatus> shareTextFile({
    required String contents,
    required String fileName,
    required String mimeType,
    required Rect sharePositionOrigin,
  }) async {
    sharedContents = contents;
    return shareStatus;
  }
}

Subscription _subscription(
  String id,
  String name, {
  String notes = 'private note must not enter CSV',
}) => Subscription(
  id: id,
  name: name,
  emoji: '',
  price: 49.95,
  currency: 'SAR',
  cycle: BillingCycle.monthly,
  anchorDate: DateTime(2026, 7, 1),
  category: 'أخرى',
  notes: notes,
  manageUrl: 'https://private.example/account',
);

Future<SubscriptionStore> _storeWith(
  SecureDataCodec codec,
  SecureKeyStore keys, {
  int count = 1,
}) async {
  final store = SubscriptionStore.testing(dataCodec: codec, secretStore: keys);
  await store.load();
  for (var index = 0; index < count; index++) {
    await store.upsert(
      _subscription('subscription-$index', 'Private Service $index'),
    );
  }
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  test('encrypted file round-trips with the same Keychain key only', () async {
    final keys = _MemoryKeyStore();
    final source = await _storeWith(SecureDataCodec(keyStore: keys), keys);
    final sourceService = BackupFileService(
      store: source,
      gateway: _FakeGateway(),
      now: () => DateTime.utc(2026, 7, 19, 12),
    );

    final file = await sourceService.createEncryptedBackupFile();
    final outer = jsonDecode(file) as Map<String, dynamic>;
    expect(outer.keys.toSet(), <String>{
      'app',
      'fileType',
      'fileVersion',
      'payloadSchemaVersion',
      'encryption',
      'createdAt',
      'payload',
    });
    expect(file, isNot(contains('Private Service')));
    expect(file, isNot(contains('private note')));
    expect(file, isNot(contains(SecureDataCodec.keyName)));
    expect(file, isNot(contains(keys.values.single)));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final target = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await target.load();
    final result = await BackupFileService(
      store: target,
      gateway: _FakeGateway(),
    ).importEncryptedBackupFile(file);

    expect(result.status, BackupImportStatus.success);
    expect(result.importedCount, 1);
    expect(target.items.single.toJson(), source.items.single.toJson());
  });

  test('a file larger than the old 2 MiB cap still round-trips', () async {
    final keys = _MemoryKeyStore();
    final codec = SecureDataCodec(keyStore: keys);
    final source = SubscriptionStore.testing(
      dataCodec: codec,
      secretStore: keys,
    );
    await source.load();
    const chunk =
        'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
    final largeNote = List<String>.filled(16500, chunk).join();
    await source.upsert(
      _subscription('large', 'Large Restorable Backup', notes: largeNote),
    );
    final file =
        await BackupFileService(
          store: source,
          gateway: _FakeGateway(),
        ).createEncryptedBackupFile();
    final fileBytes = utf8.encode(file).length;
    expect(fileBytes, greaterThan(2 * 1024 * 1024));
    expect(fileBytes, lessThanOrEqualTo(BackupFileService.maxFileBytes));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final target = SubscriptionStore.testing(
      dataCodec: SecureDataCodec(keyStore: keys),
      secretStore: keys,
    );
    await target.load();
    final result = await BackupFileService(
      store: target,
      gateway: _FakeGateway(),
    ).importEncryptedBackupFile(file);
    expect(result.status, BackupImportStatus.success);
    expect(target.items.single.notes.length, largeNote.length);
  });

  test(
    'corrupt, unsupported, extra-key and invalid payload files fail closed',
    () async {
      final keys = _MemoryKeyStore();
      final store = await _storeWith(SecureDataCodec(keyStore: keys), keys);
      final service = BackupFileService(store: store, gateway: _FakeGateway());
      final valid =
          jsonDecode(await service.createEncryptedBackupFile())
              as Map<String, dynamic>;

      final unsupported = <String, dynamic>{...valid, 'fileVersion': 999};
      expect(
        (await service.importEncryptedBackupFile(
          jsonEncode(unsupported),
        )).status,
        BackupImportStatus.unsupportedVersion,
      );

      final extraKey = <String, dynamic>{...valid, 'unexpected': true};
      expect(
        (await service.importEncryptedBackupFile(jsonEncode(extraKey))).status,
        BackupImportStatus.invalidFile,
      );

      final invalidPayload = <String, dynamic>{...valid, 'payload': '{}'};
      expect(
        (await service.importEncryptedBackupFile(
          jsonEncode(invalidPayload),
        )).status,
        BackupImportStatus.invalidFile,
      );

      final ciphertext =
          jsonDecode(valid['payload'] as String) as Map<String, dynamic>;
      final encoded = ciphertext['c'] as String;
      ciphertext['c'] =
          '${encoded.startsWith('A') ? 'B' : 'A'}${encoded.substring(1)}';
      final corrupted = <String, dynamic>{
        ...valid,
        'payload': jsonEncode(ciphertext),
      };
      expect(
        (await service.importEncryptedBackupFile(jsonEncode(corrupted))).status,
        BackupImportStatus.decryptionFailed,
      );
      expect(store.items.single.name, 'Private Service 0');
    },
  );

  test(
    'authenticated inner app, payload, and record schemas are strict',
    () async {
      final keys = _MemoryKeyStore();
      final codec = SecureDataCodec(keyStore: keys);
      final store = await _storeWith(codec, keys);
      final service = BackupFileService(store: store, gateway: _FakeGateway());
      final outer =
          jsonDecode(await service.createEncryptedBackupFile())
              as Map<String, dynamic>;
      final record = _subscription('incoming', 'Incoming').toJson();

      Future<BackupImportStatus> importInner(Map<String, dynamic> inner) async {
        final wrapped = <String, dynamic>{
          ...outer,
          'payload': await codec.encrypt(jsonEncode(inner)),
        };
        return (await service.importEncryptedBackupFile(
          jsonEncode(wrapped),
        )).status;
      }

      expect(
        await importInner(<String, dynamic>{
          'app': 'different-app',
          'version': BackupFileService.payloadSchemaVersion,
          'exportedAt': DateTime.utc(2026, 7, 19).toIso8601String(),
          'defaultCurrency': 'SAR',
          'monthlyBudget': 0,
          'subscriptions': <Object>[record],
        }),
        BackupImportStatus.invalidFile,
      );
      expect(
        await importInner(<String, dynamic>{
          'app': BackupFileService.appIdentifier,
          'version': 999,
          'exportedAt': DateTime.utc(2026, 7, 19).toIso8601String(),
          'defaultCurrency': 'SAR',
          'monthlyBudget': 0,
          'subscriptions': <Object>[record],
        }),
        BackupImportStatus.unsupportedVersion,
      );
      expect(
        await importInner(<String, dynamic>{
          'app': BackupFileService.appIdentifier,
          'version': BackupFileService.payloadSchemaVersion,
          'exportedAt': DateTime.utc(2026, 7, 19).toIso8601String(),
          'defaultCurrency': 'SAR',
          'monthlyBudget': 0,
          'subscriptions': <Object>[
            <String, dynamic>{
              ...record,
              'schemaVersion': SubscriptionSchema.currentVersion + 1,
            },
          ],
        }),
        BackupImportStatus.unsupportedVersion,
      );
      expect(
        await importInner(<String, dynamic>{
          'app': BackupFileService.appIdentifier,
          'version': BackupFileService.payloadSchemaVersion,
          'exportedAt': DateTime.utc(2026, 7, 19).toIso8601String(),
          'defaultCurrency': 'SAR',
          'subscriptions': <Object>[record],
        }),
        BackupImportStatus.invalidFile,
      );
      expect(
        await importInner(<String, dynamic>{
          'app': BackupFileService.appIdentifier,
          'version': BackupFileService.payloadSchemaVersion,
          'exportedAt': DateTime.utc(2026, 7, 19).toIso8601String(),
          'defaultCurrency': 'SAR',
          'monthlyBudget': 0,
          'subscriptions': <Object>[record],
          'unexpected': true,
        }),
        BackupImportStatus.invalidFile,
      );
      expect(store.items.single.name, 'Private Service 0');
    },
  );

  test('dismissed export is not reported as success', () async {
    final keys = _MemoryKeyStore();
    final store = await _storeWith(SecureDataCodec(keyStore: keys), keys);
    final gateway = _FakeGateway()..shareStatus = BackupShareStatus.dismissed;
    final status = await BackupFileService(
      store: store,
      gateway: gateway,
    ).shareEncryptedBackup(const Rect.fromLTWH(1, 1, 1, 1));

    expect(status, BackupShareStatus.dismissed);
    expect(gateway.sharedContents, isNotNull);
  });

  test(
    'CSV excludes unnecessary private fields and neutralizes formulas',
    () async {
      final keys = _MemoryKeyStore();
      final store = SubscriptionStore.testing(
        dataCodec: SecureDataCodec(keyStore: keys),
        secretStore: keys,
      );
      await store.load();
      await store.upsert(_subscription('formula', '=HYPERLINK("bad")'));

      final csv =
          BackupFileService(
            store: store,
            gateway: _FakeGateway(),
          ).createHumanReadableCsv();
      expect(csv, contains("'=HYPERLINK"));
      expect(csv, isNot(contains('private note must not enter CSV')));
      expect(csv, isNot(contains('private.example')));
    },
  );

  test('clearAll preserves memory when encrypted persistence fails', () async {
    final keys = _MemoryKeyStore();
    final codec = _ToggleCodec(keyStore: keys);
    final store = await _storeWith(codec, keys);
    codec.failEncryption = true;

    await expectLater(store.clearAll(), throwsA(isA<SecureDataException>()));
    expect(store.items, hasLength(1));
    expect(store.items.single.id, 'subscription-0');
  });

  testWidgets('delete cancellation stops before any mutation', (tester) async {
    final keys = _MemoryKeyStore();
    final store = await _storeWith(SecureDataCodec(keyStore: keys), keys);
    await _pumpSettings(tester, store, _FakeGateway());

    await _openDeleteSheet(tester);
    await tester.tap(find.byKey(v17DeleteCancelKey));
    await tester.pumpAndSettle();

    expect(store.items, hasLength(1));
    expect(find.byKey(v17DeleteFinalConfirmKey), findsNothing);
  });

  testWidgets('dismissed encrypted export aborts deletion', (tester) async {
    final keys = _MemoryKeyStore();
    final store = await _storeWith(SecureDataCodec(keyStore: keys), keys);
    final gateway = _FakeGateway()..shareStatus = BackupShareStatus.dismissed;
    await _pumpSettings(tester, store, gateway);

    await _openDeleteSheet(tester);
    await tester.tap(find.byKey(v17DeleteEncryptedBackupKey));
    await tester.pumpAndSettle();

    expect(gateway.sharedContents, isNotNull);
    expect(store.items, hasLength(1));
    expect(find.byKey(v17DeleteFinalConfirmKey), findsNothing);
  });

  testWidgets('delete requires two choices and shows the actual count', (
    tester,
  ) async {
    final keys = _MemoryKeyStore();
    final store = await _storeWith(
      SecureDataCodec(keyStore: keys),
      keys,
      count: 3,
    );
    await _pumpSettings(tester, store, _FakeGateway());

    await _openDeleteSheet(tester);
    await tester.tap(find.byKey(v17DeleteWithoutExportKey));
    await tester.pumpAndSettle();

    expect(store.items, hasLength(3), reason: 'first choice is not deletion');
    final dialog = find.byType(CupertinoAlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('3')),
      findsOneWidget,
    );
    expect(find.byKey(v17DeleteFinalConfirmKey), findsOneWidget);

    await tester.tap(find.byKey(v17DeleteFinalConfirmKey));
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
  });

  testWidgets('CSV cancellation and final cancellation preserve data', (
    tester,
  ) async {
    final keys = _MemoryKeyStore();
    final store = await _storeWith(SecureDataCodec(keyStore: keys), keys);
    final gateway = _FakeGateway();
    await _pumpSettings(tester, store, gateway);

    await _openDeleteSheet(tester);
    await tester.tap(find.byKey(v17DeleteCsvKey));
    await tester.pumpAndSettle();
    final csvActions = find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.byType(CupertinoDialogAction),
    );
    await tester.tap(csvActions.first);
    await tester.pumpAndSettle();
    expect(gateway.sharedContents, isNull);
    expect(store.items, hasLength(1));

    await _openDeleteSheet(tester);
    await tester.tap(find.byKey(v17DeleteWithoutExportKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(v17DeleteCancelKey));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
  });

  testWidgets('data actions fit Arabic and English phone and iPad widths', (
    tester,
  ) async {
    final keys = _MemoryKeyStore();
    final store = await _storeWith(SecureDataCodec(keyStore: keys), keys);
    for (final locale in const <Locale>[Locale('ar'), Locale('en')]) {
      for (final width in const <double>[375, 390, 744]) {
        await _pumpSettings(
          tester,
          store,
          _FakeGateway(),
          locale: locale,
          width: width,
        );
        await _openDeleteSheet(tester);
        expect(find.byKey(v17DeleteEncryptedBackupKey), findsOneWidget);
        expect(find.byKey(v17DeleteCsvKey), findsOneWidget);
        expect(find.byKey(v17DeleteWithoutExportKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(v17DeleteCancelKey));
        await tester.pumpAndSettle();
      }
    }
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  SubscriptionStore store,
  BackupFileGateway gateway, {
  Locale locale = const Locale('ar'),
  double width = 390,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await AppLocalizations.load(locale);
  setDefaultFormattingLocale(locale);
  final height = width == 744 ? 1133.0 : 844.0;
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(size: Size(width, height)),
          child: child!,
        );
      },
      home: Material(
        child: SettingsScreen(
          store: store,
          backupFileService: BackupFileService(store: store, gateway: gateway),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDeleteSheet(WidgetTester tester) async {
  final deleteButton = find.byKey(v17DataDeleteButtonKey);
  await tester.scrollUntilVisible(
    deleteButton,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
}
