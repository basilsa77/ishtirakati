/// جلب إيصالات الاشتراكات من البريد عبر IMAP — بحث مستهدف:
/// بدل جلب أحدث الرسائل عشوائيًا، نطلب من خادم البريد نفسه البحث عن
/// رسائل المرسلين المعروفين (Apple، Google، نتفلكس...) وكلمات الفواتير
/// في آخر ٦ أشهر، ثم نمرر النتائج للذكاء الاصطناعي ليحللها.
/// كلمة المرور تُستخدم للاتصال فقط ولا تغادر الجهاز.
library;

import 'package:enough_mail/enough_mail.dart';

class EmailProvider {
  final String label;
  final String host;
  final String helpUrl;

  const EmailProvider({
    required this.label,
    required this.host,
    required this.helpUrl,
  });
}

const List<EmailProvider> kEmailProviders = [
  EmailProvider(
    label: 'iCloud Mail',
    host: 'imap.mail.me.com',
    helpUrl: 'https://support.apple.com/102654',
  ),
  EmailProvider(
    label: 'Gmail',
    host: 'imap.gmail.com',
    helpUrl: 'https://myaccount.google.com/apppasswords',
  ),
  EmailProvider(
    label: 'Outlook / Hotmail',
    host: 'outlook.office365.com',
    helpUrl: 'https://account.live.com/proofs/AppPassword',
  ),
];

/// مرسلون معروفون نبحث عنهم مباشرة على الخادم.
const List<String> kKnownSenders = [
  'apple.com',
  'google.com',
  'netflix.com',
  'spotify.com',
  'anghami.com',
  'mbc.net',
  'shahid',
  'osn',
  'microsoft.com',
  'openai.com',
  'anthropic.com',
  'amazon',
  'playstation',
  'nintendo',
  'discord.com',
  'telegram.org',
  'canva.com',
  'adobe.com',
  'careem',
  'hungerstation',
  'talabat',
  'noon.com',
  'stc',
  'duolingo',
  'disney',
  'tod.tv',
  'starzplay',
];

/// كلمات في العنوان نبحث عنها أيضًا.
const List<String> kBillingSubjects = [
  'receipt',
  'invoice',
  'subscription',
  'renewal',
  'payment',
  'إيصال',
  'فاتورة',
  'اشتراك',
  'تجديد',
];

/// كلمات تدل على أن الرسالة إيصال/فاتورة (للفرز الاحتياطي المحلي).
bool looksLikeBillingEmail(String subject, String from) {
  final s = subject.toLowerCase();
  final f = from.toLowerCase();
  return kBillingSubjects.any((h) => s.contains(h)) ||
      kKnownSenders.any((h) => f.contains(h)) ||
      s.contains('apple');
}

class EmailFetchResult {
  final int scanned;
  final int matched;
  final String combinedText;

  const EmailFetchResult({
    required this.scanned,
    required this.matched,
    required this.combinedText,
  });
}

class EmailImportService {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _imapDate(DateTime d) =>
      '${d.day}-${_months[d.month - 1]}-${d.year}';

  /// يبحث على الخادم عن رسائل الفواتير في آخر [sinceDays] يومًا
  /// ويعيد نصوصها مجمّعة للتحليل.
  static Future<EmailFetchResult> fetchBillingText({
    required String host,
    required String email,
    required String password,
    int sinceDays = 180,
    int maxMessages = 80,
  }) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(host, 993, isSecure: true);
      await client.login(email, password);
      final mailbox = await client.selectInbox();

      final since = _imapDate(
        DateTime.now().subtract(Duration(days: sinceDays)),
      );

      // بحث مستهدف على الخادم: مرسلون معروفون + كلمات فواتير.
      final ids = <int>{};
      Future<void> search(String criteria) async {
        try {
          final result =
              await client.searchMessages(searchCriteria: criteria);
          final seq = result.matchingSequence;
          if (seq != null) {
            ids.addAll(seq.toList());
          }
        } catch (_) {
          // بعض الخوادم لا تدعم كل الصيغ — نتجاهل ونكمل.
        }
      }

      for (final sender in kKnownSenders) {
        await search('SINCE $since FROM "$sender"');
      }
      for (final word in kBillingSubjects) {
        await search('SINCE $since SUBJECT "$word"');
      }

      // احتياط: لو لم يدعم الخادم البحث إطلاقًا، خذ أحدث الرسائل.
      var fallbackFilter = false;
      if (ids.isEmpty) {
        final total = mailbox.messagesExists;
        if (total == 0) {
          return const EmailFetchResult(
            scanned: 0,
            matched: 0,
            combinedText: '',
          );
        }
        final start =
            total - maxMessages + 1 < 1 ? 1 : total - maxMessages + 1;
        for (var i = start; i <= total; i++) {
          ids.add(i);
        }
        fallbackFilter = true;
      }

      // الأحدث أولًا وبحد أقصى.
      final sorted = ids.toList()..sort((a, b) => b.compareTo(a));
      final picked = sorted.take(maxMessages).toList();
      final sequence = MessageSequence.fromIds(picked);
      final fetch = await client.fetchMessages(sequence, 'BODY.PEEK[]');

      final buffer = StringBuffer();
      var matched = 0;
      for (final msg in fetch.messages) {
        final subject = msg.decodeSubject() ?? '';
        final from = msg.from?.map((a) => a.email).join(' ') ?? '';
        if (fallbackFilter && !looksLikeBillingEmail(subject, from)) {
          continue;
        }
        matched += 1;
        final date = msg.decodeDate();
        buffer.writeln('=== رسالة ===');
        buffer.writeln('من: $from');
        buffer.writeln('العنوان: $subject');
        if (date != null) {
          buffer.writeln(
            'التاريخ: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          );
        }
        final text = msg.decodeTextPlainPart() ??
            _stripHtml(msg.decodeTextHtmlPart() ?? '');
        buffer.writeln(
          text.length > 3000 ? text.substring(0, 3000) : text,
        );
      }
      return EmailFetchResult(
        scanned: fetch.messages.length,
        matched: matched,
        combinedText: buffer.toString(),
      );
    } finally {
      try {
        await client.logout();
      } catch (_) {}
    }
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>',
            dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>',
            dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
  }
}
