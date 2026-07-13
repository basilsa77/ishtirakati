/// المخزن المركزي للاشتراكات: حفظ محلي عبر SharedPreferences،
/// وإشعار كل الشاشات بالتغييرات عبر ChangeNotifier.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import '../data/presets.dart';
import 'category_classifier.dart';
import 'ai_extractor.dart';
import 'notification_service.dart';
import 'remote_catalog.dart';
import 'cloud_sync.dart';
import 'secure_data_codec.dart';

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore._({
    SecureDataCodec? dataCodec,
    SecureKeyStore? secretStore,
  })  : _dataCodec = dataCodec ?? SecureDataCodec(),
        _secretStore = secretStore ?? const IosSecureKeyStore();

  @visibleForTesting
  SubscriptionStore.testing({
    SecureDataCodec? dataCodec,
    SecureKeyStore? secretStore,
  }) : this._(dataCodec: dataCodec, secretStore: secretStore);

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
  static const int _maxImportBytes = 2 * 1024 * 1024;
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
  bool _hasOnboarded = false;
  bool _loaded = false;
  String? _storageError;

  /// false = تعذر فك تشفير البيانات عند الإقلاع؛ نمنع الكتابة فوقها
  /// حفاظًا عليها حتى تنجح القراءة في تشغيل لاحق.
  bool _storageHealthy = true;
  final SecureDataCodec _dataCodec;
  final SecureKeyStore _secretStore;

  List<Subscription> get items => List.unmodifiable(_items);
  String get defaultCurrency => _defaultCurrency;
  double get monthlyBudget => _monthlyBudget;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get privateNotifications => _privateNotifications;
  bool get appLockEnabled => _appLockEnabled;
  String get aiApiKey => _aiApiKey;
  String get aiProvider => _aiProvider;
  String get themeMode => _themeMode;
  bool get hasOnboarded => _hasOnboarded;
  bool get isLoaded => _loaded;
  bool get storageHealthy => _storageHealthy;
  String? get storageError => _storageError;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultCurrency = prefs.getString(_currencyKey) ?? 'SAR';
    _monthlyBudget = prefs.getDouble(_budgetKey) ?? 0;
    _notificationsEnabled = prefs.getBool(_notifKey) ?? true;
    _privateNotifications = prefs.getBool(_privateNotifKey) ?? true;
    _appLockEnabled = prefs.getBool(_lockKey) ?? false;
    _hasOnboarded = prefs.getBool(_onboardKey) ?? false;
    _aiProvider = prefs.getString(_aiProviderKey) ?? 'gemini';
    _themeMode = prefs.getString(_themeModeKey) ?? 'system';
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
          throw const SecureDataException('صيغة البيانات المشفرة غير صالحة.');
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
        _storageError =
            'تعذر فتح البيانات المشفرة. البيانات الأصلية محفوظة ولم تُستبدل.';
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

  Future<void> _persist() async {
    _ensureWritable();
    final prefs = await SharedPreferences.getInstance();
    final plain = jsonEncode(_items.map((s) => s.toJson()).toList());
    final encrypted = await _dataCodec.encrypt(plain);
    await prefs.setString(_encryptedSubsKey, encrypted);
    await prefs.remove(_legacySubsKey);
    // إعادة جدولة الإشعارات مع كل تغيير (لا ننتظرها).
    // ignore: unawaited_futures
    NotificationService.instance
        .rescheduleAll(
          _items,
          enabled: _notificationsEnabled,
          privateContent: _privateNotifications,
        );
    // مزامنة سحابية مؤجلة إن كان المستخدم مسجلًا.
    CloudSync.schedulePush();
  }

  void _ensureWritable() {
    if (!_storageHealthy) {
      throw SecureDataException(
        _storageError ?? 'التخزين مقفل لحماية بياناتك من الاستبدال.',
      );
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
      await prefs.remove('${_aiKeyKey}_mirror');
      await prefs.remove(_aiKeyKey);
    } else {
      final keychainReady = await _secretStore.writeAll(_aiKeyKey, next);
      if (!keychainReady) {
        throw const SecureDataException(
          'تعذر حفظ مفتاح الذكاء الاصطناعي في Keychain.',
        );
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
    await NotificationService.instance
        .rescheduleAll(
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
      } else if (sub.priceHistory.isEmpty &&
          old.priceHistory.isNotEmpty) {
        sub.priceHistory = old.priceHistory;
      }
      // النماذج القديمة لا تحمل إحصائيات الاستخدام، فلا نفقدها عند التعديل.
      if (sub.usageCount == 0 && old.usageCount > 0) {
        sub.usageCount = old.usageCount;
        sub.lastUsedAt = old.lastUsedAt;
      }
      _items[index] = sub;
    } else {
      _items.insert(0, sub);
    }
    await _persist();
    notifyListeners();
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
    final names = _items
        .where((s) => s.category == 'أخرى')
        .map((s) => s.name)
        .toList();
    if (names.isEmpty || _aiApiKey.trim().isEmpty) return 0;
    final categories = await AiExtractor.classifyNames(names, _aiApiKey, providerId: _aiProvider);
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
    _items.clear();
    await _persist();
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

  /// استيراد بيانات من نص JSON مُصدَّر سابقًا.
  /// يعيد عدد الاشتراكات المستوردة، أو -1 إذا كان النص غير صالح.
  Future<int> importJson(String raw) async {
    try {
      _ensureWritable();
      if (utf8.encode(raw).length > _maxImportBytes) return -1;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return -1;
      final list = data['subscriptions'];
      if (list is! List || list.length > _maxImportRecords) return -1;
      var count = 0;
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final sub = Subscription.fromJson(e);
          final index = _items.indexWhere((s) => s.id == sub.id);
          if (index >= 0) {
            _items[index] = sub;
          } else {
            _items.add(sub);
          }
          count += 1;
        }
      }
      final budget = (data['monthlyBudget'] as num?)?.toDouble();
      if (budget != null && budget >= 0) _monthlyBudget = budget;
      final currency = data['defaultCurrency'] as String?;
      if (currency != null && currency.isNotEmpty) {
        _defaultCurrency = currency;
      }
      await _persist();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_budgetKey, _monthlyBudget);
      await prefs.setString(_currencyKey, _defaultCurrency);
      notifyListeners();
      return count;
    } catch (_) {
      return -1;
    }
  }

  /// يمحو بيانات هذا التثبيت بعد نجاح حذف الحساب والسحابة.
  Future<void> clearLocalForAccountDeletion() async {
    await NotificationService.instance.cancelAll();
    await _dataCodec.deleteAllKeys();
    await _secretStore.deleteAll(_aiKeyKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _items.clear();
    _defaultCurrency = 'SAR';
    _monthlyBudget = 0;
    _notificationsEnabled = true;
    _appLockEnabled = false;
    _aiApiKey = '';
    _aiProvider = 'gemini';
    _themeMode = 'system';
    _hasOnboarded = false;
    _storageHealthy = true;
    _storageError = null;
    notifyListeners();
  }

  // ------------------------- إحصائيات -------------------------

  List<Subscription> get active =>
      _items.where((s) => !s.isPaused && !s.isCompleted()).toList();

  List<Subscription> get paused =>
      _items.where((s) => s.isPaused).toList();

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
    final list = active
        .where((s) => s.daysUntilRenewal(from) <= withinDays)
        .toList()
      ..sort(
        (a, b) => a.daysUntilRenewal(from).compareTo(b.daysUntilRenewal(from)),
      );
    return list;
  }

  /// الإنفاق الفعلي شهرًا بشهر لآخر [months] شهرًا (لعملة محددة).
  List<MapEntry<String, double>> monthlySpendHistory(
    String currency, {
    int months = 6,
    DateTime? from,
  }) {
    const labels = [
      'ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون',
      'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس',
    ];
    final ref = from ?? DateTime.now();
    final out = <MapEntry<String, double>>[];
    for (var i = months - 1; i >= 0; i--) {
      final d = DateTime(ref.year, ref.month - i, 1);
      var total = 0.0;
      for (final s in _items.where((s) => s.currency == currency)) {
        total += s.paymentsInMonth(d.year, d.month) * s.price;
      }
      out.add(MapEntry(labels[d.month - 1], total));
    }
    return out;
  }

  /// التجارب المجانية النشطة مرتبة بالأقرب انتهاءً.
  List<Subscription> get activeTrials {
    final list = _items.where((s) => !s.isPaused && s.isTrialActive()).toList()
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
