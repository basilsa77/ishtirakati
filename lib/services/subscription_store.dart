/// المخزن المركزي للاشتراكات: حفظ محلي عبر SharedPreferences،
/// وإشعار كل الشاشات بالتغييرات عبر ChangeNotifier.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import 'notification_service.dart';

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore._();

  static final SubscriptionStore instance = SubscriptionStore._();

  static const String _subsKey = 'ishtirakati_subs_v1';
  static const String _currencyKey = 'ishtirakati_default_currency';
  static const String _budgetKey = 'ishtirakati_monthly_budget';
  static const String _notifKey = 'ishtirakati_notifications_enabled';
  static const String _lockKey = 'ishtirakati_app_lock';
  static const String _aiKeyKey = 'ishtirakati_ai_api_key';

  final List<Subscription> _items = [];
  String _defaultCurrency = 'SAR';
  double _monthlyBudget = 0; // 0 = غير مفعّلة
  bool _notificationsEnabled = true;
  bool _appLockEnabled = false;
  String _aiApiKey = '';
  bool _loaded = false;

  List<Subscription> get items => List.unmodifiable(_items);
  String get defaultCurrency => _defaultCurrency;
  double get monthlyBudget => _monthlyBudget;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get appLockEnabled => _appLockEnabled;
  String get aiApiKey => _aiApiKey;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultCurrency = prefs.getString(_currencyKey) ?? 'SAR';
    _monthlyBudget = prefs.getDouble(_budgetKey) ?? 0;
    _notificationsEnabled = prefs.getBool(_notifKey) ?? true;
    _appLockEnabled = prefs.getBool(_lockKey) ?? false;
    // مفتاح الذكاء الاصطناعي: مخزن مشفّرًا في Keychain النظام.
    try {
      const secure = FlutterSecureStorage();
      _aiApiKey = await secure.read(key: _aiKeyKey) ?? '';
      // ترحيل من التخزين القديم غير المشفر إن وُجد.
      final legacy = prefs.getString(_aiKeyKey) ?? '';
      if (_aiApiKey.isEmpty && legacy.isNotEmpty) {
        _aiApiKey = legacy;
        await secure.write(key: _aiKeyKey, value: legacy);
      }
      if (legacy.isNotEmpty) await prefs.remove(_aiKeyKey);
    } catch (_) {
      _aiApiKey = prefs.getString(_aiKeyKey) ?? '';
    }
    _items.clear();
    for (final raw in prefs.getStringList(_subsKey) ?? const <String>[]) {
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          _items.add(Subscription.fromJson(map));
        }
      } catch (_) {
        // تجاهل السجلات التالفة بدل تعطيل التطبيق.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _subsKey,
      _items.map((s) => jsonEncode(s.toJson())).toList(),
    );
    // إعادة جدولة الإشعارات مع كل تغيير (لا ننتظرها).
    // ignore: unawaited_futures
    NotificationService.instance
        .rescheduleAll(_items, enabled: _notificationsEnabled);
  }

  Future<void> setAiApiKey(String value) async {
    _aiApiKey = value.trim();
    try {
      const secure = FlutterSecureStorage();
      if (_aiApiKey.isEmpty) {
        await secure.delete(key: _aiKeyKey);
      } else {
        await secure.write(key: _aiKeyKey, value: _aiApiKey);
      }
    } catch (_) {
      // احتياط نادر: أجهزة لا تدعم Keychain.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_aiKeyKey, _aiApiKey);
    }
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
        .rescheduleAll(_items, enabled: value);
    notifyListeners();
  }

  Future<void> upsert(Subscription sub) async {
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
      _items[index] = sub;
    } else {
      _items.insert(0, sub);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> togglePause(String id) async {
    final index = _items.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _items[index].isPaused = !_items[index].isPaused;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
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
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return -1;
      final list = data['subscriptions'];
      if (list is! List) return -1;
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

  // ------------------------- إحصائيات -------------------------

  List<Subscription> get active =>
      _items.where((s) => !s.isPaused).toList();

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
