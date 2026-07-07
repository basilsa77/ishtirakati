/// نموذج بيانات الاشتراك وحسابات التجديد والتكاليف.
library;

/// دورة الفوترة.
enum BillingCycle { weekly, monthly, quarterly, yearly }

extension BillingCycleX on BillingCycle {
  String get labelAr => switch (this) {
        BillingCycle.weekly => 'أسبوعي',
        BillingCycle.monthly => 'شهري',
        BillingCycle.quarterly => 'كل ٣ أشهر',
        BillingCycle.yearly => 'سنوي',
      };

  int get cyclesPerYear => switch (this) {
        BillingCycle.weekly => 52,
        BillingCycle.monthly => 12,
        BillingCycle.quarterly => 4,
        BillingCycle.yearly => 1,
      };
}

/// طرق الدفع الشائعة.
const List<String> kPaymentMethods = [
  'غير محدد',
  'بطاقة مدى',
  'بطاقة ائتمانية',
  'Apple Pay',
  'STC Pay',
  'PayPal',
  'رصيد المتجر',
  'أخرى',
];

/// رموز العملات المدعومة وعرضها بالعربية.
const Map<String, String> currencySymbols = {
  'SAR': 'ر.س',
  'AED': 'د.إ',
  'KWD': 'د.ك',
  'QAR': 'ر.ق',
  'BHD': 'د.ب',
  'OMR': 'ر.ع',
  'USD': r'$',
  'EUR': '€',
};

String fmtMoney(double v, String currency) {
  final rounded = double.parse(v.toStringAsFixed(2));
  final s = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2);
  return '$s ${currencySymbols[currency] ?? currency}';
}

class Subscription {
  final String id;
  String name;
  String emoji;
  double price;
  String currency;
  BillingCycle cycle;

  /// تاريخ بداية الاشتراك (أو أي تجديد سابق معروف).
  DateTime anchorDate;
  String category;
  String notes;
  bool isPaused;

  /// طريقة الدفع (اختياري).
  String paymentMethod;

  /// رابط إدارة/إلغاء الاشتراك (اختياري).
  String manageUrl;

  Subscription({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.currency,
    required this.cycle,
    required this.anchorDate,
    required this.category,
    this.notes = '',
    this.isPaused = false,
    this.paymentMethod = 'غير محدد',
    this.manageUrl = '',
  });

  double get yearlyCost => price * cycle.cyclesPerYear;

  double get monthlyCost => yearlyCost / 12;

  /// موعد التجديد القادم اعتبارًا من [from] (افتراضيًا: اليوم).
  ///
  /// يحافظ على "يوم الشهر" الأصلي قدر الإمكان: اشتراك بدأ يوم 31
  /// يتجدد في 28/29 فبراير ثم يعود إلى 31 مارس.
  DateTime nextRenewal([DateTime? from]) {
    final ref = from ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final start =
        DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    if (!start.isBefore(today)) return start;

    if (cycle == BillingCycle.weekly) {
      final days = today.difference(start).inDays;
      var k = days ~/ 7;
      var d = start.add(Duration(days: 7 * k));
      while (d.isBefore(today)) {
        k += 1;
        d = start.add(Duration(days: 7 * k));
      }
      return d;
    }

    final step = switch (cycle) {
      BillingCycle.monthly => 1,
      BillingCycle.quarterly => 3,
      BillingCycle.yearly => 12,
      BillingCycle.weekly => 1, // لا يصل هنا
    };
    final diffMonths =
        (today.year - start.year) * 12 + (today.month - start.month);
    var k = (diffMonths ~/ step) * step;
    if (k < 0) k = 0;
    var d = addMonths(start, k);
    var guard = 0;
    while (d.isBefore(today) && guard++ < 1200) {
      k += step;
      d = addMonths(start, k);
    }
    return d;
  }

  int daysUntilRenewal([DateTime? from]) {
    final ref = from ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    return nextRenewal(ref).difference(today).inDays;
  }

  /// عدد الدفعات التي حدثت منذ البداية حتى [from] (تشمل دفعة البداية).
  int paymentsMade([DateTime? from]) {
    final ref = from ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final start =
        DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    if (start.isAfter(today)) return 0;

    if (cycle == BillingCycle.weekly) {
      return today.difference(start).inDays ~/ 7 + 1;
    }

    final step = switch (cycle) {
      BillingCycle.monthly => 1,
      BillingCycle.quarterly => 3,
      BillingCycle.yearly => 12,
      BillingCycle.weekly => 1,
    };
    var count = 0;
    var k = 0;
    var d = start;
    while (!d.isAfter(today) && count < 1200) {
      count += 1;
      k += step;
      d = addMonths(start, k);
    }
    return count;
  }

  /// إجمالي ما دُفع على هذا الاشتراك منذ البداية (تقديري).
  double totalSpent([DateTime? from]) => paymentsMade(from) * price;

  /// إضافة أشهر مع تثبيت يوم الشهر الأصلي (مع القصّ لنهاية الشهر).
  static DateTime addMonths(DateTime d, int n) {
    final totalMonths = d.year * 12 + (d.month - 1) + n;
    final y = totalMonths ~/ 12;
    final m = (totalMonths % 12) + 1;
    final lastDay = daysInMonth(y, m);
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(y, m, day);
  }

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'price': price,
        'currency': currency,
        'cycle': cycle.index,
        'anchor': anchorDate.toIso8601String(),
        'category': category,
        'notes': notes,
        'paused': isPaused,
        'payMethod': paymentMethod,
        'manageUrl': manageUrl,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final cycleIndex = (json['cycle'] as num?)?.toInt() ?? 1;
    return Subscription(
      id: (json['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'اشتراك',
      emoji: (json['emoji'] as String?) ?? '🔖',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'SAR',
      cycle: BillingCycle
          .values[cycleIndex.clamp(0, BillingCycle.values.length - 1)],
      anchorDate: DateTime.tryParse((json['anchor'] as String?) ?? '') ??
          DateTime.now(),
      category: (json['category'] as String?) ?? 'أخرى',
      notes: (json['notes'] as String?) ?? '',
      isPaused: (json['paused'] as bool?) ?? false,
      paymentMethod: (json['payMethod'] as String?) ?? 'غير محدد',
      manageUrl: (json['manageUrl'] as String?) ?? '',
    );
  }
}
