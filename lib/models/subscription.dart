/// نموذج بيانات الاشتراك وحسابات التجديد والتكاليف.
library;

import '../l10n/app_localizations.dart' show isEnglishLocale, localizedNumber;
import 'subscription_schema.dart';

/// دورة الفوترة.
enum BillingCycle { weekly, monthly, quarterly, yearly }

/// نوع الدفعة: اشتراك متجدد، قسط ينتهي، أو فاتورة شهرية.
enum PaymentKind { subscription, installment, bill }

extension PaymentKindX on PaymentKind {
  String get labelAr => switch (this) {
    PaymentKind.subscription => 'اشتراك',
    PaymentKind.installment => 'قسط',
    PaymentKind.bill => 'فاتورة',
  };
}

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
    b.writeln(
      [
        esc(s.name),
        s.price.toStringAsFixed(2),
        s.currency,
        esc(s.cycle.labelAr),
        esc(s.category),
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        s.totalSpent().toStringAsFixed(2),
        esc(s.paymentMethod),
        esc(s.notes),
      ].join(','),
    );
  }
  return b.toString();
}

String fmtMoney(double v, String currency) {
  // بطلب المستخدم: المبلغ فقط بدون اسم/رمز العملة.
  final rounded = double.parse(v.toStringAsFixed(2));
  final digits = rounded == rounded.roundToDouble() ? 0 : 2;
  return localizedNumber(rounded, decimalDigits: digits);
}

/// صياغة واضحة للقوائم التي يجب أن تبيّن العملة بجانب المبلغ.
String fmtMoneyWithCurrency(double value, String currency) {
  final symbol =
      isEnglishLocale && currency == 'SAR'
          ? 'SAR'
          : currencySymbols[currency] ?? currency;
  final amount = fmtMoney(value, currency);
  return (isEnglishLocale ? '$symbol $amount' : '$amount $symbol').trim();
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

  /// نوع الدفعة: اشتراك / قسط / فاتورة.
  PaymentKind kind;

  /// لأقساط محددة المدة: العدد الكلي للأقساط (null = مفتوح).
  int? totalInstallments;

  /// اشتراك عائلي/مشترك مع آخرين.
  bool isFamily;

  /// عدد الأفراد المشاركين في الاشتراك العائلي (أنت منهم).
  int familyMembers;

  /// إحصائية استخدام محلية تساعد على تقييم قيمة الاشتراك.
  int usageCount;
  DateTime? lastUsedAt;

  /// هل تتجدد الخدمة تلقائيًا دون إجراء يدوي من المستخدم؟
  bool autoRenews;

  /// خدمة أساسية لا ينبغي اقتراح إلغائها لمجرد انخفاض الاستخدام.
  bool isEssential;

  /// اسم الخطة الحالية كما يظهر في فاتورة المزود، إن كان معروفًا.
  String planName;

  /// آخر مرة راجع فيها المستخدم جدوى الاشتراك أو خطته.
  DateTime? lastReviewedAt;

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
    this.usageCount = 0,
    this.lastUsedAt,
    this.autoRenews = true,
    this.isEssential = false,
    this.planName = '',
    this.lastReviewedAt,
    this.kind = PaymentKind.subscription,
    this.totalInstallments,
  }) : priceHistory = priceHistory ?? [];

  /// هل اكتمل سداد القسط؟
  bool isCompleted([DateTime? from]) {
    final total = totalInstallments;
    if (kind != PaymentKind.installment || total == null || total <= 0) {
      return false;
    }
    return paymentsMade(from) >= total;
  }

  /// عدد الأقساط المتبقية (null إن لم يكن قسطًا محدد المدة).
  int? remainingInstallments([DateTime? from]) {
    final total = totalInstallments;
    if (kind != PaymentKind.installment || total == null || total <= 0) {
      return null;
    }
    final left = total - paymentsMade(from);
    return left < 0 ? 0 : left;
  }

  /// تاريخ آخر قسط (لأقساط محددة المدة).
  DateTime? get lastInstallmentDate {
    final total = totalInstallments;
    if (kind != PaymentKind.installment || total == null || total <= 0) {
      return null;
    }
    if (cycle == BillingCycle.weekly) {
      return anchorDate.add(Duration(days: 7 * (total - 1)));
    }
    final step = switch (cycle) {
      BillingCycle.monthly => 1,
      BillingCycle.quarterly => 3,
      BillingCycle.yearly => 12,
      BillingCycle.weekly => 1,
    };
    return addMonths(anchorDate, (total - 1) * step);
  }

  /// نصيب الفرد الواحد من الاشتراك العائلي.
  double get pricePerMember =>
      isFamily && familyMembers > 1 ? price / familyMembers : price;

  double? get costPerUse => usageCount > 0 ? price / usageCount : null;

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
    final start = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    if (start.isAfter(monthEnd)) return const [];
    final installmentEnd = lastInstallmentDate;
    if (installmentEnd != null && monthStart.isAfter(installmentEnd)) {
      return const [];
    }

    final out = <DateTime>[];
    if (cycle == BillingCycle.weekly) {
      var days = monthStart.difference(start).inDays;
      var k = days <= 0 ? 0 : days ~/ 7;
      var d = start.add(Duration(days: 7 * k));
      var guard = 0;
      while (!d.isAfter(monthEnd) && guard++ < 10) {
        if (!d.isBefore(monthStart) &&
            (installmentEnd == null || !d.isAfter(installmentEnd))) {
          out.add(d);
        }
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
      if (!d.isBefore(monthStart) &&
          (installmentEnd == null || !d.isAfter(installmentEnd))) {
        out.add(d);
      }
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

  /// The price that applied on [date]. Each history entry stores the previous
  /// price and the instant at which it was replaced. Sorting defensively keeps
  /// imported records deterministic even if their history order was changed.
  double priceAt(DateTime date) {
    if (priceHistory.isEmpty) return price;
    final target = DateTime(date.year, date.month, date.day);
    final changes = [...priceHistory]
      ..sort((a, b) => a.changedAt.compareTo(b.changedAt));
    for (final change in changes) {
      final changed = DateTime(
        change.changedAt.year,
        change.changedAt.month,
        change.changedAt.day,
      );
      if (target.isBefore(changed)) return change.oldPrice;
    }
    return price;
  }

  /// Actual amount charged in a calendar month using the historical price for
  /// every occurrence and respecting a finite installment plan.
  double spendingInMonth(int year, int month) => renewalsInMonth(
    year,
    month,
  ).fold<double>(0, (sum, date) => sum + priceAt(date));

  double get yearlyCost => price * cycle.cyclesPerYear;

  double get monthlyCost => yearlyCost / 12;

  /// وصف موجز يميّز السجلات المتشابهة الاسم دون تغيير بياناتها المخزنة.
  String get displayQualifier {
    final renewal = nextRenewal();
    final parts = <String>[
      if (planName.trim().isNotEmpty) planName.trim(),
      '${kind.labelAr} ${cycle.labelAr}',
      if (paymentMethod != 'غير محدد' && paymentMethod.trim().isNotEmpty)
        paymentMethod.trim(),
      'التجديد ${renewal.day}/${renewal.month}',
    ];
    return parts.join(' · ');
  }

  /// موعد التجديد القادم اعتبارًا من [from] (افتراضيًا: اليوم).
  ///
  /// يحافظ على "يوم الشهر" الأصلي قدر الإمكان: اشتراك بدأ يوم 31
  /// يتجدد في 28/29 فبراير ثم يعود إلى 31 مارس.
  DateTime nextRenewal([DateTime? from]) {
    final ref = from ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final start = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
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
    final start = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    if (start.isAfter(today)) return 0;

    if (cycle == BillingCycle.weekly) {
      return _capInstallmentCount(today.difference(start).inDays ~/ 7 + 1);
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
    return _capInstallmentCount(count);
  }

  int _capInstallmentCount(int count) {
    final total = totalInstallments;
    if (kind != PaymentKind.installment || total == null || total <= 0) {
      return count;
    }
    return count > total ? total : count;
  }

  /// إجمالي ما دُفع منذ البداية وفق السعر الذي كان نافذًا عند كل دفعة.
  double totalSpent([DateTime? from]) {
    final count = paymentsMade(from);
    if (count == 0) return 0;
    final start = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    var total = 0.0;
    if (cycle == BillingCycle.weekly) {
      for (var index = 0; index < count; index++) {
        total += priceAt(start.add(Duration(days: index * 7)));
      }
      return total;
    }
    final step = switch (cycle) {
      BillingCycle.monthly => 1,
      BillingCycle.quarterly => 3,
      BillingCycle.yearly => 12,
      BillingCycle.weekly => 1,
    };
    for (var index = 0; index < count; index++) {
      total += priceAt(addMonths(start, index * step));
    }
    return total;
  }

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
    'schemaVersion': SubscriptionSchema.currentVersion,
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
    'usageCount': usageCount,
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'autoRenews': autoRenews,
    'isEssential': isEssential,
    'planName': planName,
    'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    'iconUrl': iconUrl,
    'kind': kind.index,
    'totalInstallments': totalInstallments,
  };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final data = SubscriptionSchema.migrateToV13(json);
    final cycleIndex = (data['cycle'] as num?)?.toInt() ?? 1;
    return Subscription(
      id:
          (data['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: (data['name'] as String?) ?? 'اشتراك',
      emoji: (data['emoji'] as String?) ?? '🔖',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      currency: (data['currency'] as String?) ?? 'SAR',
      cycle:
          BillingCycle.values[cycleIndex.clamp(
            0,
            BillingCycle.values.length - 1,
          )],
      anchorDate:
          DateTime.tryParse((data['anchor'] as String?) ?? '') ??
          DateTime.now(),
      category: (data['category'] as String?) ?? 'أخرى',
      notes: (data['notes'] as String?) ?? '',
      isPaused: (data['paused'] as bool?) ?? false,
      paymentMethod: (data['payMethod'] as String?) ?? 'غير محدد',
      manageUrl: (data['manageUrl'] as String?) ?? '',
      reminderDays: (data['reminderDays'] as num?)?.toInt() ?? 3,
      trialEndDate: DateTime.tryParse((data['trialEnd'] as String?) ?? ''),
      priceHistory: [
        if (data['priceHistory'] is List)
          for (final e in data['priceHistory'] as List)
            if (PriceChange.fromJson(e) case final change?) change,
      ],
      isFamily: (data['isFamily'] as bool?) ?? false,
      familyMembers:
          (((data['familyMembers'] as num?)?.toInt() ?? 2).clamp(
            1,
            20,
          )).toInt(),
      usageCount:
          (((data['usageCount'] as num?)?.toInt() ?? 0).clamp(
            0,
            100000,
          )).toInt(),
      lastUsedAt: DateTime.tryParse((data['lastUsedAt'] as String?) ?? ''),
      autoRenews: (data['autoRenews'] as bool?) ?? true,
      isEssential: (data['isEssential'] as bool?) ?? false,
      planName: (data['planName'] as String?) ?? '',
      lastReviewedAt: DateTime.tryParse(
        (data['lastReviewedAt'] as String?) ?? '',
      ),
      iconUrl: (data['iconUrl'] as String?) ?? '',
      kind:
          PaymentKind.values[((data['kind'] as num?)?.toInt() ?? 0).clamp(
            0,
            PaymentKind.values.length - 1,
          )],
      totalInstallments: (data['totalInstallments'] as num?)?.toInt(),
    );
  }
}
