/// جلب إيصالات الاشتراكات من البريد عبر IMAP:
/// يتصل بحساب المستخدم (بكلمة مرور خاصة بالتطبيقات)، يجلب أحدث الرسائل،
/// يصفّي رسائل الفواتير والإيصالات، ويعيد نصوصها لتحليلها محليًا.
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

/// كلمات تدل على أن الرسالة إيصال/فاتورة اشتراك.
const List<String> _billingHints = [
  'receipt',
  'invoice',
  'subscription',
  'renewal',
  'renew',
  'payment',
  'billing',
  'إيصال',
  'فاتورة',
  'اشتراك',
  'تجديد',
  'دفع',
  'خصم',
  'apple',
];

bool looksLikeBillingEmail(String subject, String from) {
  final s = subject.toLowerCase();
  final f = from.toLowerCase();
  return _billingHints.any((h) => s.contains(h) || f.contains(h));
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
  /// يتصل ويجلب نصوص رسائل الفواتير من آخر [maxMessages] رسالة.
  static Future<EmailFetchResult> fetchBillingText({
    required String host,
    required String email,
    required String password,
    int maxMessages = 60,
  }) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(host, 993, isSecure: true);
      await client.login(email, password);
      final mailbox = await client.selectInbox();

      final total = mailbox.messagesExists;
      if (total == 0) {
        return const EmailFetchResult(
          scanned: 0,
          matched: 0,
          combinedText: '',
        );
      }

      final start = total - maxMessages + 1 < 1 ? 1 : total - maxMessages + 1;
      final sequence = MessageSequence.fromRange(start, total);
      final fetch =
          await client.fetchMessages(sequence, 'BODY.PEEK[]');

      final buffer = StringBuffer();
      var matched = 0;
      for (final msg in fetch.messages) {
        final subject = msg.decodeSubject() ?? '';
        final from = msg.from?.map((a) => a.email).join(' ') ?? '';
        if (!looksLikeBillingEmail(subject, from)) continue;
        matched += 1;
        buffer.writeln(subject);
        buffer.writeln(from);
        final text = msg.decodeTextPlainPart() ??
            _stripHtml(msg.decodeTextHtmlPart() ?? '');
        // نكتفي بأول جزء من كل رسالة — يكفي للتعرف على الخدمة والسعر.
        buffer.writeln(
          text.length > 4000 ? text.substring(0, 4000) : text,
        );
        buffer.writeln('---');
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
