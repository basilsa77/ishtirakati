/// نموذج بيانات الاشتراك وحسابات التجديد والتكاليف.
library;

/// دورة الفوترة.
enum BillingCycle { weekly, monthly, quarterly, yearly }

/// تغيير سعر سابق: السعر القديم وتاريخ استبداله.
class PriceChange {
  final double oldPrice;
  final DateTime changedAt;

  const PriceChange({required this.oldPrice, required this.changedAt});

  Map<String, dynamic> toJson() => {
        'p': oldPrice,
        'd': changedAt.toIso8601String(),
      };

  static PriceChange? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final p = (json['p'] as num?)?.toDouble();
    final d = DateTime.tryParse((json['d'] as String?) ?? '');
    if (p == null || d == null) return null;
    return PriceChange(oldPrice: p, changedAt: d);
  }
}

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

/// يبني ملف CSV من قائمة اشتراكات (للتصدير إلى Excel/Numbers).
String buildCsv(List<Subscription> subs) {
  String esc(String s) => '"${s.replaceAll('"', '""')}"';
  final b = StringBuffer(
    'الاسم,السعر,العملة,الدورة,التصنيف,التجديد القادم,'
    'إجمالي المدفوع,طريقة الدفع,ملاحظات\n',
  );
  for (final s in subs) {
    final d = s.nextRenewal();
    b.writeln([
      esc(s.name),
      s.price.toStringAsFixed(2),
      s.currency,
      esc(s.cycle.labelAr),
      esc(s.category),
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      s.totalSpent().toStringAsFixed(2),
      esc(s.paymentMethod),
      esc(s.notes),
    ].join(','));
  }
  return b.toString();
}

String fmtMoney(double v, String currency) {
  // بطلب المستخدم: المبلغ فقط بدون اسم/رمز العملة.
  final rounded = double.parse(v.toStringAsFixed(2));
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2);
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

  /// التذكير قبل التجديد بهذا العدد من الأيام (0 = بدون تذكير).
  int reminderDays;

  /// تاريخ انتهاء التجربة المجانية (null = ليست تجربة).
  DateTime? trialEndDate;

  /// سجل تغيّرات السعر: كل عنصر سعر قديم وتاريخ استبداله.
  List<PriceChange> priceHistory;

  /// رابط شعار مخصص (من البحث الذكي في iTunes مثلًا).
  String iconUrl;

  /// اشتراك عائلي/مشترك مع آخرين.
  bool isFamily;

  /// عدد الأفراد المشاركين في الاشتراك العائلي (أنت منهم).
  int familyMembers;

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
    this.reminderDays = 3,
    this.trialEndDate,
    List<PriceChange>? priceHistory,
    this.iconUrl = '',
    this.isFamily = false,
    this.familyMembers = 2,
  }) : priceHistory = priceHistory ?? [];

  /// نصيب الفرد الواحد من الاشتراك العائلي.
  double get pricePerMember =>
      isFamily && familyMembers > 1 ? price / familyMembers : price;

  /// هل هو تجربة مجانية لم تنتهِ بعد؟
  bool isTrialActive([DateTime? from]) {
    final t = trialEndDate;
    if (t == null) return false;
    final ref = from ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    return !DateTime(t.year, t.month, t.day).isBefore(today);
  }

  /// عدد الدفعات التي وقعت داخل شهر معيّن.
  int paymentsInMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final before = start.subtract(const Duration(days: 1));
    return paymentsMade(end) - paymentsMade(before);
  }

  /// تواريخ التجديد الواقعة داخل شهر معيّن (لعرض التقويم).
  List<DateTime> renewalsInMonth(int year, int month) {
    final start =
        DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    if (start.isAfter(monthEnd)) return const [];

    final out = <DateTime>[];
    if (cycle == BillingCycle.weekly) {
      var days = monthStart.difference(start).inDays;
      var k = days <= 0 ? 0 : days ~/ 7;
      var d = start.add(Duration(days: 7 * k));
      var guard = 0;
      while (!d.isAfter(monthEnd) && guard++ < 10) {
        if (!d.isBefore(monthStart)) out.add(d);
        k += 1;
        d = start.add(Duration(days: 7 * k));
      }
      return out;
    }

    final step = switch (cycle) {
      BillingCycle.monthly => 1,
      BillingCycle.quarterly => 3,
      BillingCycle.yearly => 12,
      BillingCycle.weekly => 1,
    };
    final diffMonths =
        (monthStart.year - start.year) * 12 + (monthStart.month - start.month);
    var k = (diffMonths ~/ step) * step;
    if (k < 0) k = 0;
    var d = addMonths(start, k);
    var guard = 0;
    while (!d.isAfter(monthEnd) && guard++ < 30) {
      if (!d.isBefore(monthStart)) out.add(d);
      k += step;
      d = addMonths(start, k);
    }
    return out;
  }

  /// نسبة تغيّر السعر منذ أول سعر معروف (null إن لم يتغير).
  double? get priceChangePercent {
    if (priceHistory.isEmpty) return null;
    final first = priceHistory.first.oldPrice;
    if (first <= 0) return null;
    return (price - first) / first * 100;
  }

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
        'reminderDays': reminderDays,
        'trialEnd': trialEndDate?.toIso8601String(),
        'priceHistory': priceHistory.map((e) => e.toJson()).toList(),
        'isFamily': isFamily,
        'familyMembers': familyMembers,
        'iconUrl': iconUrl,
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
      reminderDays: (json['reminderDays'] as num?)?.toInt() ?? 3,
      trialEndDate:
          DateTime.tryParse((json['trialEnd'] as String?) ?? ''),
      priceHistory: [
        if (json['priceHistory'] is List)
          for (final e in json['priceHistory'] as List)
            if (PriceChange.fromJson(e) != null) PriceChange.fromJson(e)!,
      ],
      isFamily: (json['isFamily'] as bool?) ?? false,
      familyMembers:
          ((json['familyMembers'] as num?)?.toInt() ?? 2).clamp(1, 20),
      iconUrl: (json['iconUrl'] as String?) ?? '',
    );
  }
}
