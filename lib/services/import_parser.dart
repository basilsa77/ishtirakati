/// محلل «الاستيراد الذكي»: يستخرج الاشتراكات من نصوص حرة
/// (رسائل البنوك، إيصالات Apple، قوائم مكتوبة) بدون إنترنت.
library;

import '../models/subscription.dart';

/// اشتراك مرشّح مكتشف من النص.
class ImportCandidate {
  final String name;
  final String emoji;
  final String category;
  final double? price;
  final String currency;
  final BillingCycle cycle;
  final DateTime? anchor;
  final String sourceLine;

  const ImportCandidate({
    required this.name,
    required this.emoji,
    required this.category,
    required this.price,
    required this.currency,
    required this.cycle,
    required this.anchor,
    required this.sourceLine,
  });

  Subscription toSubscription({required String fallbackCurrency}) {
    return Subscription(
      id: '${DateTime.now().microsecondsSinceEpoch}_${name.hashCode}',
      name: name,
      emoji: emoji,
      price: price ?? 0,
      currency: currency.isEmpty ? fallbackCurrency : currency,
      cycle: cycle,
      anchorDate: anchor ?? DateTime.now(),
      category: category,
      notes: 'أُضيف عبر الاستيراد الذكي',
    );
  }
}

class _Service {
  final String name;
  final String emoji;
  final String category;
  final List<String> keywords; // بحروف صغيرة

  const _Service(this.name, this.emoji, this.category, this.keywords);
}

const List<_Service> _services = [
  _Service('Netflix', '🍿', 'ترفيه ومشاهدة', ['netflix', 'نتفلكس', 'نتفليكس']),
  _Service('شاهد VIP', '🎬', 'ترفيه ومشاهدة', ['shahid', 'شاهد']),
  _Service('اشتراك Apple', '🍎', 'مالية وفواتير', [
    'apple.com/bill',
    'apple.com bill',
    'itunes.com',
    'إيصالك من apple',
  ]),
  _Service('Apple Music', '🎶', 'موسيقى وبودكاست', ['apple music']),
  _Service('Apple TV+', '🍏', 'ترفيه ومشاهدة', ['apple tv']),
  _Service('iCloud+', '☁️', 'تخزين سحابي', ['icloud']),
  _Service('Apple One', '🅰️', 'إنتاجية وذكاء اصطناعي', ['apple one']),
  _Service('Spotify Premium', '🎧', 'موسيقى وبودكاست', ['spotify', 'سبوتيفاي']),
  _Service('أنغامي بلس', '🎵', 'موسيقى وبودكاست', [
    'anghami',
    'أنغامي',
    'انغامي',
  ]),
  _Service('YouTube Premium', '▶️', 'ترفيه ومشاهدة', [
    'youtube premium',
    'youtube',
    'يوتيوب',
  ]),
  _Service('ChatGPT Plus', '🤖', 'إنتاجية وذكاء اصطناعي', [
    'chatgpt',
    'openai',
    'chatgpt plus',
  ]),
  _Service('Claude Pro', '✨', 'إنتاجية وذكاء اصطناعي', ['claude', 'anthropic']),
  _Service('Google Gemini', '💎', 'إنتاجية وذكاء اصطناعي', ['gemini']),
  _Service('Microsoft 365', '📊', 'إنتاجية وذكاء اصطناعي', [
    'microsoft 365',
    'office 365',
    'microsoft',
  ]),
  _Service('Canva Pro', '🎨', 'إنتاجية وذكاء اصطناعي', ['canva', 'كانفا']),
  _Service('Adobe Creative Cloud', '🖌️', 'إنتاجية وذكاء اصطناعي', ['adobe']),
  _Service('Notion', '🗒️', 'إنتاجية وذكاء اصطناعي', ['notion']),
  _Service('Dropbox', '📦', 'تخزين سحابي', ['dropbox']),
  _Service('Google One', '🗂️', 'تخزين سحابي', [
    'google one',
    'google storage',
  ]),
  _Service('LinkedIn Premium', '💼', 'إنتاجية وذكاء اصطناعي', ['linkedin']),
  _Service('PlayStation Plus', '🎮', 'ألعاب', [
    'playstation',
    'plusstation',
    'بلايستيشن',
    'sony interactive',
  ]),
  _Service('Xbox Game Pass', '🕹️', 'ألعاب', ['xbox', 'game pass']),
  _Service('Nintendo Switch Online', '🍄', 'ألعاب', ['nintendo']),
  _Service('Steam', '🎲', 'ألعاب', ['steam']),
  _Service('Disney+', '🏰', 'ترفيه ومشاهدة', ['disney', 'ديزني']),
  _Service('OSN+', '🎞️', 'ترفيه ومشاهدة', ['osn']),
  _Service('stc tv', '📺', 'ترفيه ومشاهدة', ['stc tv', 'stctv']),
  _Service('Jawwy TV', '📡', 'ترفيه ومشاهدة', ['jawwy', 'جوّي', 'جوي tv']),
  _Service('TOD', '⚽', 'ترفيه ومشاهدة', ['tod tv', ' tod ']),
  _Service('Yango Play', '🎥', 'ترفيه ومشاهدة', ['yango']),
  _Service('Snapchat+', '👻', 'ترفيه ومشاهدة', [
    'snapchat',
    'سناب شات',
    'سناب',
  ]),
  _Service('X Premium', '❌', 'أخبار ومجلات', ['x premium', 'twitter']),
  _Service('Telegram Premium', '✈️', 'إنتاجية وذكاء اصطناعي', [
    'telegram',
    'تيليجرام',
    'تلغرام',
  ]),
  _Service('Amazon Prime', '🛒', 'تسوق وتوصيل', [
    'amazon prime',
    'prime video',
    'امازون برايم',
    'أمازون',
  ]),
  _Service('Careem Plus', '🛵', 'تسوق وتوصيل', ['careem', 'كريم']),
  _Service('HungerStation Plus', '🍔', 'تسوق وتوصيل', [
    'hungerstation',
    'هنقرستيشن',
  ]),
  _Service('Duolingo Super', '🦉', 'تعليم', ['duolingo', 'دولينجو']),
  _Service('نادي رياضي', '🏋️', 'رياضة وصحة', [
    'fitness time',
    'وقت اللياقة',
    'gym',
    'نادي',
  ]),
  _Service('باقة الجوال', '📱', 'اتصالات وإنترنت', [
    'mobily',
    'موبايلي',
    'zain',
    'زين',
    'salam',
    'سلام موبايل',
  ]),
  _Service('إنترنت المنزل', '🌐', 'اتصالات وإنترنت', [
    'فايبر',
    'fiber',
    'انترنت المنزل',
    'إنترنت المنزل',
  ]),
];

const Map<String, String> _currencyTokens = {
  'ر.س': 'SAR',
  'ريال': 'SAR',
  'sar': 'SAR',
  ' sr': 'SAR',
  'د.إ': 'AED',
  'درهم': 'AED',
  'aed': 'AED',
  'د.ك': 'KWD',
  'kwd': 'KWD',
  'ر.ق': 'QAR',
  'qar': 'QAR',
  'د.ب': 'BHD',
  'bhd': 'BHD',
  'ر.ع': 'OMR',
  'omr': 'OMR',
  'usd': 'USD',
  r'$': 'USD',
  'eur': 'EUR',
  '€': 'EUR',
};

/// تحويل الأرقام العربية إلى لاتينية وتوحيد الفواصل.
String normalizeDigits(String input) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  const extended = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final i1 = eastern.indexOf(ch);
    final i2 = extended.indexOf(ch);
    if (i1 >= 0) {
      buffer.write(i1.toString());
    } else if (i2 >= 0) {
      buffer.write(i2.toString());
    } else if (ch == '٫') {
      buffer.write('.');
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

double? _findAmount(String line) {
  final matches = RegExp(
    r'(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:[.,]\d{1,2})?)',
  ).allMatches(line);
  double? best;
  for (final m in matches) {
    final original = m.group(1)!;
    final raw =
        original.contains(',') &&
                RegExp(r'^\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?$').hasMatch(original)
            ? original.replaceAll(',', '')
            : original.replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v <= 0 || v > 100000) continue;
    // تجاهل ما يبدو كسنة أو رقم بطاقة.
    if (v >= 1900 && v <= 2100 && !raw.contains('.')) continue;
    if (original.length >= 6 && !raw.contains('.')) continue;
    // فضّل المبالغ العشرية (أسعار غالبًا)، ثم الأصغر.
    if (best == null) {
      best = v;
    } else if (original.contains('.') && best == best.roundToDouble()) {
      best = v;
    }
  }
  return best;
}

String _findCurrency(String lowerLine) {
  for (final e in _currencyTokens.entries) {
    if (lowerLine.contains(e.key)) return e.value;
  }
  return '';
}

BillingCycle _findCycle(String lowerLine) {
  if (lowerLine.contains('سنوي') ||
      lowerLine.contains('سنة') ||
      lowerLine.contains('year') ||
      lowerLine.contains('annual')) {
    return BillingCycle.yearly;
  }
  if (lowerLine.contains('أسبوع') ||
      lowerLine.contains('اسبوع') ||
      lowerLine.contains('week')) {
    return BillingCycle.weekly;
  }
  if (lowerLine.contains('3 أشهر') ||
      lowerLine.contains('٣ أشهر') ||
      lowerLine.contains('quarter') ||
      lowerLine.contains('3 months')) {
    return BillingCycle.quarterly;
  }
  return BillingCycle.monthly;
}

DateTime? _findDate(String line) {
  DateTime? validDate(int y, int m, int d) {
    if (y < 2015 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
      return null;
    }
    final date = DateTime(y, m, d);
    return date.year == y && date.month == m && date.day == d ? date : null;
  }

  final iso = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(line);
  if (iso != null) {
    final y = int.parse(iso.group(1)!);
    final m = int.parse(iso.group(2)!);
    final d = int.parse(iso.group(3)!);
    return validDate(y, m, d);
  }
  final dmy = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(line);
  if (dmy != null) {
    final d = int.parse(dmy.group(1)!);
    final m = int.parse(dmy.group(2)!);
    var y = int.parse(dmy.group(3)!);
    if (y < 100) y += 2000;
    return validDate(y, m, d);
  }
  return null;
}

/// يحلل نصًا حرًا ويعيد الاشتراكات المكتشفة (بدون تكرار للخدمة الواحدة).
List<ImportCandidate> parseSubscriptionsText(String text) {
  final normalized = normalizeDigits(text);
  final lines =
      normalized
          .split(RegExp(r'[\n\r]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

  final found = <String, ImportCandidate>{};

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lower = ' ${line.toLowerCase()} ';

    for (final svc in _services) {
      if (found.containsKey(svc.name)) continue;
      final hit = svc.keywords.any((k) => lower.contains(k));
      if (!hit) continue;

      // ابحث عن السعر في نفس السطر ثم السطرين التاليين.
      double? price = _findAmount(line);
      var currency = _findCurrency(lower);
      var cycle = _findCycle(lower);
      var anchor = _findDate(line);
      for (var j = i + 1; j <= i + 2 && j < lines.length; j++) {
        final nextLower = lines[j].toLowerCase();
        price ??= _findAmount(lines[j]);
        if (currency.isEmpty) currency = _findCurrency(nextLower);
        anchor ??= _findDate(lines[j]);
        if (cycle == BillingCycle.monthly) {
          final c = _findCycle(nextLower);
          if (c != BillingCycle.monthly) cycle = c;
        }
      }

      found[svc.name] = ImportCandidate(
        name: svc.name,
        emoji: svc.emoji,
        category: svc.category,
        price: price,
        currency: currency,
        cycle: cycle,
        anchor: anchor,
        sourceLine: line.length > 80 ? '${line.substring(0, 80)}…' : line,
      );
    }
  }

  return found.values.toList();
}
