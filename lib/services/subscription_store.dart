/// المخزن المركزي للاشتراكات: حفظ محلي عبر SharedPreferences،
/// وإشعار كل الشاشات بالتغييرات عبر ChangeNotifier.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import '../models/subscription_schema.dart';
import '../data/presets.dart';
import '../l10n/app_localizations.dart';
import 'category_classifier.dart';
import 'ai_extractor.dart';
import 'notification_service.dart';
import 'remote_catalog.dart';
import 'cloud_sync.dart';
import 'email_identity_store.dart';
import 'financial_assistant.dart';
import 'secure_data_codec.dart';

enum EncryptedFileBackupImportStatus {
  success,
  invalidPayload,
  unsupportedVersion,
  decryptionFailed,
}

@immutable
class EncryptedFileBackupImportResult {
  const EncryptedFileBackupImportResult(this.status, {this.importedCount = 0});

  final EncryptedFileBackupImportStatus status;
  final int importedCount;
}

class EncryptedFileBackupTooLargeException implements Exception {
  const EncryptedFileBackupTooLargeException();
}

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore._({
    SecureDataCodec? dataCodec,
    SecureKeyStore? secretStore,
    EmailIdentityStore? emailIdentityStore,
    Future<void> Function()? cancelNotificationsForDeletion,
  }) : _dataCodec = dataCodec ?? SecureDataCodec(),
       _secretStore = secretStore ?? const IosSecureKeyStore(),
       _emailIdentityStore = emailIdentityStore ?? EmailIdentityStore.instance,
       _cancelNotificationsForDeletion =
           cancelNotificationsForDeletion ??
           NotificationService.instance.cancelAllForDeletion;

  @visibleForTesting
  SubscriptionStore.testing({
    SecureDataCodec? dataCodec,
    SecureKeyStore? secretStore,
    EmailIdentityStore? emailIdentityStore,
    Future<void> Function()? cancelNotificationsForDeletion,
  }) : this._(
         dataCodec: dataCodec,
         secretStore: secretStore,
         emailIdentityStore: emailIdentityStore,
         cancelNotificationsForDeletion: cancelNotificationsForDeletion,
       );

  static final SubscriptionStore instance = SubscriptionStore._();

  static const String _legacySubsKey = 'ishtirakati_subs_v1';
  static const String _encryptedSubsKey = 'ishtirakati_subs_v2_encrypted';
  static const String _backupSubsKey = 'ishtirakati_subs_v2_backup';
  static const String _currencyKey = 'ishtirakati_default_currency';
  static const String _budgetKey = 'ishtirakati_monthly_budget';
  static const String _notifKey = 'ishtirakati_notifications_enabled';
  static const String _privateNotifKey = 'ishtirakati_private_notifications';
  static const String _lockKey = 'ishtirakati_app_lock';
  static const String _aiKeyKey = 'ishtirakati_ai_api_key';
  static const String _aiProviderKey = 'ishtirakati_ai_provider';
  static const String _onboardKey = 'ishtirakati_onboarded_v1';
  static const String _themeModeKey = 'ishtirakati_theme_mode';
  static const String _languageModeKey = 'ishtirakati_language_mode_v15';

  /// Maximum authenticated plaintext accepted by the existing JSON importer.
  /// File-backup limits account separately for the AES envelope/Base64 growth.
  static const int maxImportBytes = 2 * 1024 * 1024;
  static const int _maxImportRecords = 5000;

  final List<Subscription> _items = [];
  String _defaultCurrency = 'SAR';
  double _monthlyBudget = 0; // 0 = غير مفعّلة
  bool _notificationsEnabled = true;
  bool _privateNotifications = true;
  bool _appLockEnabled = false;
  String _aiApiKey = '';
  String _aiProvider = 'gemini';
  String _themeMode = 'system'; // dark | light | system
  String _languageMode = 'system'; // ar | en | system
  bool _hasOnboarded = false;
  bool _loaded = false;
  String? _storageError;

  /// false = تعذر فك تشفير البيانات عند الإقلاع؛ نمنع الكتابة فوقها
  /// حفاظًا عليها حتى تنجح القراءة في تشغيل لاحق.
  bool _storageHealthy = true;
  final SecureDataCodec _dataCodec;
  final SecureKeyStore _secretStore;
  final EmailIdentityStore _emailIdentityStore;
  final Future<void> Function() _cancelNotificationsForDeletion;

  List<Subscription> get items => List.unmodifiable(_items);
  String get defaultCurrency => _defaultCurrency;
  double get monthlyBudget => _monthlyBudget;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get privateNotifications => _privateNotifications;
  bool get appLockEnabled => _appLockEnabled;
  String get aiApiKey => _aiApiKey;
  String get aiProvider => _aiProvider;
  String get themeMode => _themeMode;
  String get languageMode => _languageMode;
  bool get hasOnboarded => _hasOnboarded;
  bool get isLoaded => _loaded;
  bool get storageHealthy => _storageHealthy;
  String? get storageError => _storageError;

  Future<void> load() async {
    _storageHealthy = false;
    _storageError = tr('secureStorageLocked');
    try {
      await _loadFromStorage();
    } catch (_) {
      _storageHealthy = false;
      _storageError = tr('secureStorageLocked');
      _loaded = true;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultCurrency = prefs.getString(_currencyKey) ?? 'SAR';
    _monthlyBudget = prefs.getDouble(_budgetKey) ?? 0;
    _notificationsEnabled = prefs.getBool(_notifKey) ?? true;
    _privateNotifications = prefs.getBool(_privateNotifKey) ?? true;
    _appLockEnabled = prefs.getBool(_lockKey) ?? false;
    _hasOnboarded = prefs.getBool(_onboardKey) ?? false;
    _aiProvider = prefs.getString(_aiProviderKey) ?? 'gemini';
    _themeMode = prefs.getString(_themeModeKey) ?? 'system';
    final storedLanguage = prefs.getString(_languageModeKey);
    _languageMode = switch (storedLanguage) {
      'ar' || 'en' || 'system' => storedLanguage!,
      _ => 'system',
    };
    // Keychain أولًا. نسخ v12 غير الآمنة تُقرأ فقط لترحيلها إلى Keychain.
    _aiApiKey = '';
    final secureAiValues = await _secretStore.readAll(_aiKeyKey);
    if (secureAiValues.isNotEmpty) _aiApiKey = secureAiValues.first;
    if (_aiApiKey.isEmpty) {
      final mirror = prefs.getString('${_aiKeyKey}_mirror') ?? '';
      if (mirror.isNotEmpty) {
        try {
          final legacyValue = utf8.decode(base64Url.decode(mirror));
          final migrated = await _secretStore.writeAll(_aiKeyKey, legacyValue);
          if (migrated) {
            _aiApiKey = legacyValue;
            await prefs.remove('${_aiKeyKey}_mirror');
            await prefs.remove(_aiKeyKey);
          }
        } catch (_) {}
      }
    }
    if (_aiApiKey.isEmpty) {
      final legacyValue = prefs.getString(_aiKeyKey) ?? '';
      if (legacyValue.isNotEmpty) {
        final migrated = await _secretStore.writeAll(_aiKeyKey, legacyValue);
        if (migrated) {
          _aiApiKey = legacyValue;
          await prefs.remove(_aiKeyKey);
          await prefs.remove('${_aiKeyKey}_mirror');
        }
      }
    }
    if (_aiApiKey.isNotEmpty) {
      final keychainReady = await _secretStore.writeAll(_aiKeyKey, _aiApiKey);
      if (keychainReady) {
        await prefs.remove('${_aiKeyKey}_mirror');
        await prefs.remove(_aiKeyKey);
      }
    }

    final encrypted = prefs.getString(_encryptedSubsKey);
    final records = <dynamic>[];
    var needsMigration = false;
    if (encrypted != null && encrypted.isNotEmpty) {
      try {
        final decoded = jsonDecode(await _dataCodec.decrypt(encrypted));
        if (decoded is! List) {
          throw SecureDataException(tr('securePayloadInvalid'));
        }
        records.addAll(decoded);
        _storageHealthy = true;
        _storageError = null;
      } catch (_) {
        // نحفظ السجل كما هو ونمنع أي كتابة أو مزامنة حتى تنجح استعادته.
        final backup = prefs.getString(_backupSubsKey);
        if (backup == null || backup.isEmpty) {
          await prefs.setString(_backupSubsKey, encrypted);
        }
        _storageHealthy = false;
        _storageError = tr('secureRecordLocked');
      }
    } else {
      // ترحيل بيانات الإصدارات السابقة إلى صيغة مشفّرة مرة واحدة.
      _storageHealthy = true;
      _storageError = null;
      records.addAll(prefs.getStringList(_legacySubsKey) ?? const <String>[]);
      needsMigration = records.isNotEmpty;
    }
    _items.clear();
    for (final raw in records) {
      try {
        final map = raw is String ? jsonDecode(raw) : raw;
        if (map is Map<String, dynamic>) {
          final sub = Subscription.fromJson(map);
          _applyLocalCategory(sub);
          _items.add(sub);
        }
      } catch (_) {
        // تجاهل السجلات التالفة بدل تعطيل التطبيق.
      }
    }
    if (needsMigration) await _persist();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _persistItems(_items);

  Future<void> _persistItems(List<Subscription> items) async {
    _ensureWritable();
    final prefs = await SharedPreferences.getInstance();
    final plain = jsonEncode(items.map((s) => s.toJson()).toList());
    final encrypted = await _dataCodec.encrypt(plain);
    if (!await prefs.setString(_encryptedSubsKey, encrypted) ||
        prefs.getString(_encryptedSubsKey) != encrypted) {
      throw SecureDataException(tr('secureStorageLocked'));
    }
    await prefs.remove(_legacySubsKey);
    // إعادة جدولة الإشعارات مع كل تغيير (لا ننتظرها).
    // ignore: unawaited_futures
    NotificationService.instance.rescheduleAll(
      items,
      enabled: _notificationsEnabled,
      privateContent: _privateNotifications,
    );
    // مزامنة سحابية مؤجلة إن كان المستخدم مسجلًا.
    CloudSync.schedulePush();
  }

  void _ensureWritable() {
    if (!_storageHealthy) {
      throw SecureDataException(_storageError ?? tr('secureStorageLocked'));
    }
  }

  Future<void> setOnboarded() async {
    _hasOnboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardKey, true);
  }

  Future<void> setThemeMode(String mode) async {
    if (mode != 'dark' && mode != 'light' && mode != 'system') return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
    notifyListeners();
  }

  Future<void> setLanguageMode(String mode) async {
    if (mode != 'ar' && mode != 'en' && mode != 'system') return;
    _languageMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageModeKey, mode);
    notifyListeners();
  }

  Future<void> setAiProvider(String id) async {
    _aiProvider = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiProviderKey, id);
    notifyListeners();
  }

  Future<void> setAiApiKey(String value) async {
    final next = value.trim();
    final prefs = await SharedPreferences.getInstance();
    if (next.isEmpty) {
      await _secretStore.deleteAll(_aiKeyKey);
      if ((await _secretStore.readAll(_aiKeyKey)).isNotEmpty) {
        throw SecureDataException(tr('secureStorageLocked'));
      }
      await prefs.remove('${_aiKeyKey}_mirror');
      await prefs.remove(_aiKeyKey);
      if (prefs.containsKey('${_aiKeyKey}_mirror') ||
          prefs.containsKey(_aiKeyKey)) {
        throw SecureDataException(tr('secureStorageLocked'));
      }
    } else {
      final keychainReady = await _secretStore.writeAll(_aiKeyKey, next);
      if (!keychainReady) {
        throw SecureDataException(tr('secureAiKeySaveFailed'));
      }
      await prefs.remove('${_aiKeyKey}_mirror');
      await prefs.remove(_aiKeyKey);
    }
    _aiApiKey = next;
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLockEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockKey, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, value);
    await NotificationService.instance.rescheduleAll(
      _items,
      enabled: value,
      privateContent: _privateNotifications,
    );
    notifyListeners();
  }

  Future<void> setPrivateNotifications(bool value) async {
    _privateNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privateNotifKey, value);
    await NotificationService.instance.rescheduleAll(
      _items,
      enabled: _notificationsEnabled,
      privateContent: value,
    );
    notifyListeners();
  }

  Future<void> upsert(Subscription sub) async {
    _ensureWritable();
    _applyLocalCategory(sub);
    final index = _items.indexWhere((s) => s.id == sub.id);
    if (index >= 0) {
      // تسجيل تغيّر السعر في السجل قبل الاستبدال.
      final old = _items[index];
      if ((old.price - sub.price).abs() > 0.001) {
        sub.priceHistory = [
          ...old.priceHistory,
          PriceChange(oldPrice: old.price, changedAt: DateTime.now()),
        ];
      } else if (sub.priceHistory.isEmpty && old.priceHistory.isNotEmpty) {
        sub.priceHistory = old.priceHistory;
      }
      // النماذج القديمة لا تحمل إحصائيات الاستخدام، فلا نفقدها عند التعديل.
      if (sub.usageCount == 0 && old.usageCount > 0) {
        sub.usageCount = old.usageCount;
        sub.lastUsedAt = old.lastUsedAt;
      }
      _preserveLocalReviewMetadata(old, sub);
      _items[index] = sub;
    } else {
      _items.insert(0, sub);
    }
    await _persist();
    notifyListeners();
  }

  void _preserveLocalReviewMetadata(
    Subscription existing,
    Subscription replacement,
  ) {
    replacement.ignoredDuplicateGroupKeys.addAll(
      existing.ignoredDuplicateGroupKeys,
    );
  }

  /// Persists a duplicate-review dismissal in the existing encrypted record.
  ///
  /// The operation is idempotent and fails closed: every in-memory mutation is
  /// rolled back if encryption or persistence fails.
  Future<bool> ignoreDuplicateGroup(DuplicateSubscriptionGroup group) async {
    final ids =
        group.subscriptions
            .map((item) => item.id)
            .where((id) => id.isNotEmpty)
            .toList();
    if (ids.toSet().length < 2 ||
        FinancialAssistant.duplicateGroupKey(ids) != group.groupKey) {
      return false;
    }
    return ignoreDuplicateGroupBySubscriptionIds(ids);
  }

  @visibleForTesting
  Future<bool> ignoreDuplicateGroupBySubscriptionIds(
    Iterable<String> subscriptionIds,
  ) async {
    _ensureWritable();
    final ids =
        subscriptionIds.where((id) => id.isNotEmpty).toSet().toList()..sort();
    if (ids.length < 2) return false;

    final members = <Subscription>[];
    for (final id in ids) {
      final index = _items.indexWhere((item) => item.id == id);
      if (index < 0) return false;
      members.add(_items[index]);
    }

    final groupKey = FinancialAssistant.duplicateGroupKey(ids);
    if (members.every(
      (item) => item.ignoredDuplicateGroupKeys.contains(groupKey),
    )) {
      return true;
    }

    final previous = <Subscription, Set<String>>{
      for (final item in members)
        item: Set<String>.of(item.ignoredDuplicateGroupKeys),
    };
    for (final item in members) {
      item.ignoredDuplicateGroupKeys.add(groupKey);
    }
    try {
      await _persist();
    } catch (_) {
      for (final entry in previous.entries) {
        entry.key.ignoredDuplicateGroupKeys
          ..clear()
          ..addAll(entry.value);
      }
      rethrow;
    }
    notifyListeners();
    return true;
  }

  void _applyLocalCategory(Subscription sub) {
    if (!kCategories.contains(sub.category) || sub.category == 'أخرى') {
      final suggestion = CategoryClassifier.suggest(sub.name);
      if (suggestion.category != 'أخرى') sub.category = suggestion.category;
    }
  }

  /// يعيد تصنيف العناصر التي بقيت في «أخرى» بعد وصول الكتالوج الشبكي.
  Future<void> reclassifyUnknowns() async {
    _ensureWritable();
    var changed = false;
    for (final sub in _items) {
      if (sub.category != 'أخرى') continue;
      final suggestion = CategoryClassifier.suggest(
        sub.name,
        remote: RemoteCatalog.instance.services,
      );
      if (suggestion.category != 'أخرى') {
        sub.category = suggestion.category;
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<int> reclassifyUnknownsWithAi() async {
    _ensureWritable();
    final names =
        _items.where((s) => s.category == 'أخرى').map((s) => s.name).toList();
    if (names.isEmpty || _aiApiKey.trim().isEmpty) return 0;
    final categories = await AiExtractor.classifyNames(
      names,
      _aiApiKey,
      providerId: _aiProvider,
    );
    var changed = 0;
    for (final sub in _items) {
      final category = categories[sub.name];
      if (sub.category == 'أخرى' && category != null) {
        sub.category = category;
        changed += 1;
      }
    }
    if (changed > 0) {
      await _persist();
      notifyListeners();
    }
    return changed;
  }

  Future<void> remove(String id) async {
    _ensureWritable();
    _items.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> togglePause(String id) async {
    _ensureWritable();
    final index = _items.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _items[index].isPaused = !_items[index].isPaused;
      await _persist();
      notifyListeners();
    }
  }

  /// يسجل استخدامًا واحدًا للاشتراك دون إرسال أي بيانات خارج الجهاز.
  Future<void> recordUsage(String id, {DateTime? at}) async {
    _ensureWritable();
    final index = _items.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final sub = _items[index];
    sub.usageCount = (sub.usageCount + 1).clamp(0, 100000).toInt();
    sub.lastUsedAt = at ?? DateTime.now();
    await _persist();
    notifyListeners();
  }

  /// Records that the user consciously reviewed the subscription terms.
  /// This is local financial metadata and follows the same encrypted persist path.
  Future<void> markReviewed(String id, {DateTime? at}) async {
    _ensureWritable();
    final index = _items.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _items[index].lastReviewedAt = at ?? DateTime.now();
    await _persist();
    notifyListeners();
  }

  List<Subscription> get neverUsed =>
      _items.where((s) => !s.isPaused && s.usageCount == 0).toList();

  double savingsFor(String currency) => paused
      .where((s) => s.currency == currency)
      .fold(0, (sum, s) => sum + s.monthlyCost);

  Future<void> clearAll() async {
    _ensureWritable();
    // Persist the empty candidate before mutating memory. If encryption or the
    // durable write fails, the caller sees an error and the user's in-memory
    // subscriptions remain intact instead of entering a partially-cleared
    // state. The existing persistence path intentionally retains its current
    // cloud-sync behavior.
    await _persistItems(const <Subscription>[]);
    _items.clear();
    notifyListeners();
  }

  Future<void> setDefaultCurrency(String code) async {
    _defaultCurrency = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, code);
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double value) async {
    _monthlyBudget = value < 0 ? 0 : value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, _monthlyBudget);
    notifyListeners();
  }

  // --------------------- نسخ احتياطي واستعادة ---------------------

  /// تصدير كل البيانات كنص JSON واحد (للحفظ في الملاحظات أو الملفات).
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'ishtirakati',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'defaultCurrency': _defaultCurrency,
      'monthlyBudget': _monthlyBudget,
      'subscriptions': _items.map((s) => s.toJson()).toList(),
    });
  }

  /// Creates the cloud payload with the same AES-256-GCM/Keychain policy used
  /// by the local record. Only the ciphertext envelope leaves the device.
  Future<String> exportEncryptedCloudBackup() async {
    _ensureWritable();
    return _dataCodec.encrypt(exportJson());
  }

  /// Creates a restorable file payload using the existing AES-GCM/Keychain
  /// codec, while refusing plaintext that the matching importer cannot accept.
  /// Cloud Sync deliberately keeps using [exportEncryptedCloudBackup].
  Future<String> exportEncryptedFileBackup() async {
    _ensureWritable();
    final plain = exportJson();
    if (utf8.encode(plain).length > maxImportBytes) {
      throw const EncryptedFileBackupTooLargeException();
    }
    return _dataCodec.encrypt(plain);
  }

  /// Decrypts a cloud payload in memory and imports it only after successful
  /// authentication. A missing/wrong Keychain key leaves local data untouched.
  Future<int> importEncryptedCloudBackup(String encrypted) async {
    try {
      _ensureWritable();
      final plain = await _dataCodec.decrypt(encrypted);
      return importJson(plain);
    } on SecureDataException {
      return -1;
    }
  }

  /// Strict file-only restore path.
  ///
  /// The AES implementation and Keychain policy remain in [SecureDataCodec].
  /// After authenticated decryption, this method verifies the metadata that is
  /// inside the ciphertext before delegating to the backward-compatible JSON
  /// importer. Cloud restores continue to use [importEncryptedCloudBackup].
  Future<EncryptedFileBackupImportResult> importEncryptedFileBackup(
    String encrypted, {
    required String expectedApp,
    required int expectedPayloadVersion,
  }) async {
    late final String plain;
    try {
      _ensureWritable();
      plain = await _dataCodec.decrypt(encrypted);
    } on SecureDataException {
      return const EncryptedFileBackupImportResult(
        EncryptedFileBackupImportStatus.decryptionFailed,
      );
    }

    try {
      if (utf8.encode(plain).length > maxImportBytes) {
        return const EncryptedFileBackupImportResult(
          EncryptedFileBackupImportStatus.invalidPayload,
        );
      }
      final decoded = jsonDecode(plain);
      const expectedKeys = <String>{
        'app',
        'version',
        'exportedAt',
        'defaultCurrency',
        'monthlyBudget',
        'subscriptions',
      };
      if (decoded is! Map<String, dynamic> ||
          decoded.length != expectedKeys.length ||
          decoded.keys.toSet().difference(expectedKeys).isNotEmpty ||
          decoded['app'] != expectedApp) {
        return const EncryptedFileBackupImportResult(
          EncryptedFileBackupImportStatus.invalidPayload,
        );
      }

      final payloadVersion = decoded['version'];
      if (payloadVersion is! int) {
        return const EncryptedFileBackupImportResult(
          EncryptedFileBackupImportStatus.invalidPayload,
        );
      }
      if (payloadVersion != expectedPayloadVersion) {
        return const EncryptedFileBackupImportResult(
          EncryptedFileBackupImportStatus.unsupportedVersion,
        );
      }

      final exportedAt = decoded['exportedAt'];
      final defaultCurrency = decoded['defaultCurrency'];
      final monthlyBudget = decoded['monthlyBudget'];
      if (exportedAt is! String ||
          DateTime.tryParse(exportedAt) == null ||
          defaultCurrency is! String ||
          defaultCurrency.isEmpty ||
          monthlyBudget is! num ||
          !monthlyBudget.isFinite ||
          monthlyBudget < 0) {
        return const EncryptedFileBackupImportResult(
          EncryptedFileBackupImportStatus.invalidPayload,
        );
      }

      final subscriptions = decoded['subscriptions'];
      if (subscriptions is! List || subscriptions.length > _maxImportRecords) {
        return const EncryptedFileBackupImportResult(
          EncryptedFileBackupImportStatus.invalidPayload,
        );
      }
      for (final record in subscriptions) {
        if (record is! Map<String, dynamic>) {
          return const EncryptedFileBackupImportResult(
            EncryptedFileBackupImportStatus.invalidPayload,
          );
        }
        final schemaVersion = record['schemaVersion'];
        // Missing schema metadata remains a supported legacy record. Current
        // exports always emit an integer; malformed or future schemas must not
        // be silently downgraded by a release that does not understand them.
        if (schemaVersion == null) continue;
        if (schemaVersion is! int || schemaVersion < 1) {
          return const EncryptedFileBackupImportResult(
            EncryptedFileBackupImportStatus.invalidPayload,
          );
        }
        if (schemaVersion > SubscriptionSchema.currentVersion) {
          return const EncryptedFileBackupImportResult(
            EncryptedFileBackupImportStatus.unsupportedVersion,
          );
        }
      }

      final imported = await importJson(plain);
      if (imported < 0) {
        return const EncryptedFileBackupImportResult(
          EncryptedFileBackupImportStatus.invalidPayload,
        );
      }
      return EncryptedFileBackupImportResult(
        EncryptedFileBackupImportStatus.success,
        importedCount: imported,
      );
    } on FormatException {
      return const EncryptedFileBackupImportResult(
        EncryptedFileBackupImportStatus.invalidPayload,
      );
    } on TypeError {
      return const EncryptedFileBackupImportResult(
        EncryptedFileBackupImportStatus.invalidPayload,
      );
    }
  }

  /// استيراد بيانات من نص JSON مُصدَّر سابقًا.
  /// يعيد عدد الاشتراكات المستوردة، أو -1 إذا كان النص غير صالح.
  Future<int> importJson(String raw) async {
    try {
      _ensureWritable();
      if (utf8.encode(raw).length > maxImportBytes) return -1;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return -1;
      final list = data['subscriptions'];
      if (list is! List || list.length > _maxImportRecords) return -1;
      final candidateItems = List<Subscription>.of(_items);
      var count = 0;
      for (final e in list) {
        if (e is! Map<String, dynamic>) return -1;
        final sub = Subscription.fromJson(e);
        final index = candidateItems.indexWhere((s) => s.id == sub.id);
        if (index >= 0) {
          _preserveLocalReviewMetadata(candidateItems[index], sub);
          candidateItems[index] = sub;
        } else {
          candidateItems.add(sub);
        }
        count += 1;
      }
      var candidateBudget = _monthlyBudget;
      final budget = (data['monthlyBudget'] as num?)?.toDouble();
      if (budget != null) {
        if (!budget.isFinite || budget < 0) return -1;
        candidateBudget = budget;
      }
      var candidateCurrency = _defaultCurrency;
      final currency = data['defaultCurrency'] as String?;
      if (currency != null && currency.isNotEmpty) {
        if (!currencySymbols.containsKey(currency)) return -1;
        candidateCurrency = currency;
      }
      final prefs = await SharedPreferences.getInstance();
      final previousBudget = prefs.getDouble(_budgetKey);
      final previousCurrency = prefs.getString(_currencyKey);
      final budgetSaved = await prefs.setDouble(_budgetKey, candidateBudget);
      final currencySaved = await prefs.setString(
        _currencyKey,
        candidateCurrency,
      );
      if (!budgetSaved ||
          !currencySaved ||
          prefs.getDouble(_budgetKey) != candidateBudget ||
          prefs.getString(_currencyKey) != candidateCurrency) {
        await _restoreImportPreferences(
          prefs,
          budget: previousBudget,
          currency: previousCurrency,
        );
        return -1;
      }
      try {
        await _persistItems(candidateItems);
      } catch (_) {
        await _restoreImportPreferences(
          prefs,
          budget: previousBudget,
          currency: previousCurrency,
        );
        rethrow;
      }
      _items
        ..clear()
        ..addAll(candidateItems);
      _monthlyBudget = candidateBudget;
      _defaultCurrency = candidateCurrency;
      notifyListeners();
      return count;
    } catch (_) {
      return -1;
    }
  }

  Future<void> _restoreImportPreferences(
    SharedPreferences prefs, {
    required double? budget,
    required String? currency,
  }) async {
    if (budget == null) {
      await prefs.remove(_budgetKey);
    } else {
      await prefs.setDouble(_budgetKey, budget);
    }
    if (currency == null) {
      await prefs.remove(_currencyKey);
    } else {
      await prefs.setString(_currencyKey, currency);
    }
  }

  /// يمحو بيانات هذا التثبيت بعد نجاح حذف الحساب والسحابة.
  Future<void> clearLocalForAccountDeletion() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await attempt(_cancelNotificationsForDeletion);
    await attempt(_emailIdentityStore.forget);
    await attempt(_dataCodec.deleteAllKeys);
    await attempt(() async {
      await _secretStore.deleteAll(_aiKeyKey);
      if ((await _secretStore.readAll(_aiKeyKey)).isNotEmpty) {
        throw SecureDataException(tr('secureStorageLocked'));
      }
    });
    await attempt(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.clear() || prefs.getKeys().isNotEmpty) {
        throw SecureDataException(tr('secureStorageLocked'));
      }
    });
    _items.clear();
    _defaultCurrency = 'SAR';
    _monthlyBudget = 0;
    _notificationsEnabled = true;
    _appLockEnabled = false;
    _aiApiKey = '';
    _aiProvider = 'gemini';
    _themeMode = 'system';
    _languageMode = 'system';
    _hasOnboarded = false;
    _storageHealthy = true;
    _storageError = null;
    notifyListeners();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  // ------------------------- إحصائيات -------------------------

  List<Subscription> get active =>
      _items.where((s) => !s.isPaused && !s.isCompleted()).toList();

  List<Subscription> get paused => _items.where((s) => s.isPaused).toList();

  /// إجمالي شهري لكل عملة (النشطة فقط).
  Map<String, double> monthlyTotals() {
    final totals = <String, double>{};
    for (final s in active) {
      totals[s.currency] = (totals[s.currency] ?? 0) + s.monthlyCost;
    }
    return totals;
  }

  /// إجمالي سنوي لكل عملة (النشطة فقط).
  Map<String, double> yearlyTotals() {
    final totals = <String, double>{};
    for (final s in active) {
      totals[s.currency] = (totals[s.currency] ?? 0) + s.yearlyCost;
    }
    return totals;
  }

  /// إجمالي ما دُفع منذ البداية لكل عملة (كل الاشتراكات).
  Map<String, double> lifetimeTotals([DateTime? from]) {
    final totals = <String, double>{};
    for (final s in _items) {
      totals[s.currency] = (totals[s.currency] ?? 0) + s.totalSpent(from);
    }
    return totals;
  }

  /// ما توفّره شهريًا من الاشتراكات الموقوفة، لكل عملة.
  Map<String, double> pausedSavingsMonthly() {
    final totals = <String, double>{};
    for (final s in paused) {
      totals[s.currency] = (totals[s.currency] ?? 0) + s.monthlyCost;
    }
    return totals;
  }

  /// التجديدات القادمة خلال [withinDays] يومًا، مرتبة بالأقرب.
  List<Subscription> upcoming({int withinDays = 30, DateTime? from}) {
    final list =
        active.where((s) => s.daysUntilRenewal(from) <= withinDays).toList()
          ..sort(
            (a, b) =>
                a.daysUntilRenewal(from).compareTo(b.daysUntilRenewal(from)),
          );
    return list;
  }

  /// الإنفاق الفعلي شهرًا بشهر لآخر [months] شهرًا (لعملة محددة).
  List<MapEntry<String, double>> monthlySpendHistory(
    String currency, {
    int months = 6,
    DateTime? from,
  }) {
    final ref = from ?? DateTime.now();
    final out = <MapEntry<String, double>>[];
    for (var i = months - 1; i >= 0; i--) {
      final d = DateTime(ref.year, ref.month - i, 1);
      var total = 0.0;
      for (final s in _items.where((s) => s.currency == currency)) {
        total += s.spendingInMonth(d.year, d.month);
      }
      out.add(MapEntry(formatMonthAbbreviation(d), total));
    }
    return out;
  }

  /// التجارب المجانية النشطة مرتبة بالأقرب انتهاءً.
  List<Subscription> get activeTrials {
    final list =
        _items.where((s) => !s.isPaused && s.isTrialActive()).toList()
          ..sort((a, b) => a.trialEndDate!.compareTo(b.trialEndDate!));
    return list;
  }

  /// التكلفة الشهرية حسب التصنيف لعملة محددة (النشطة فقط).
  Map<String, double> monthlyByCategory(String currency) {
    final map = <String, double>{};
    for (final s in active.where((s) => s.currency == currency)) {
      map[s.category] = (map[s.category] ?? 0) + s.monthlyCost;
    }
    return map;
  }

  /// العملة الأكثر استخدامًا (أو الافتراضية إن لم توجد اشتراكات).
  String get dominantCurrency {
    if (active.isEmpty) return _defaultCurrency;
    final counts = <String, int>{};
    for (final s in active) {
      counts[s.currency] = (counts[s.currency] ?? 0) + 1;
    }
    var best = _defaultCurrency;
    var bestCount = -1;
    counts.forEach((c, n) {
      if (n > bestCount) {
        best = c;
        bestCount = n;
      }
    });
    return best;
  }
}
