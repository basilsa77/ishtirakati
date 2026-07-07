/// المخزن المركزي للاشتراكات: حفظ محلي عبر SharedPreferences،
/// وإشعار كل الشاشات بالتغييرات عبر ChangeNotifier.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore._();

  static final SubscriptionStore instance = SubscriptionStore._();

  static const String _subsKey = 'ishtirakati_subs_v1';
  static const String _currencyKey = 'ishtirakati_default_currency';
  static const String _budgetKey = 'ishtirakati_monthly_budget';

  final List<Subscription> _items = [];
  String _defaultCurrency = 'SAR';
  double _monthlyBudget = 0; // 0 = غير مفعّلة
  bool _loaded = false;

  List<Subscription> get items => List.unmodifiable(_items);
  String get defaultCurrency => _defaultCurrency;
  double get monthlyBudget => _monthlyBudget;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultCurrency = prefs.getString(_currencyKey) ?? 'SAR';
    _monthlyBudget = prefs.getDouble(_budgetKey) ?? 0;
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
  }

  Future<void> upsert(Subscription sub) async {
    final index = _items.indexWhere((s) => s.id == sub.id);
    if (index >= 0) {
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
