/// ربط البريد: جلب إيصالات الاشتراكات من الإيميل تلقائيًا عبر IMAP.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/email_import_service.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
import 'import_screen.dart';

class EmailLinkScreen extends StatefulWidget {
  const EmailLinkScreen({super.key});

  @override
  State<EmailLinkScreen> createState() => _EmailLinkScreenState();
}

class _EmailLinkScreenState extends State<EmailLinkScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  EmailProvider _provider = kEmailProviders.first;
  bool _busy = false;
  bool _remember = true;
  String? _error;

  static const String _emailKey = 'ishtirakati_linked_email_v2';
  static const String _legacyEmailKey = 'ishtirakati_linked_email';
  static const String _hostKey = 'ishtirakati_linked_host';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );
    var savedEmail = await secure.read(key: _emailKey) ?? '';
    if (savedEmail.isEmpty) {
      const legacySecure = FlutterSecureStorage();
      final legacyKeychain = await legacySecure.read(key: _emailKey) ?? '';
      if (legacyKeychain.isNotEmpty) {
        savedEmail = legacyKeychain;
        await secure.write(key: _emailKey, value: legacyKeychain);
      }
    }
    final legacyEmail = prefs.getString(_legacyEmailKey) ?? '';
    if (savedEmail.isEmpty && legacyEmail.isNotEmpty) {
      await secure.write(key: _emailKey, value: legacyEmail);
      await prefs.remove(_legacyEmailKey);
      savedEmail = legacyEmail;
    }
    final savedHost = prefs.getString(_hostKey) ?? '';
    if (savedEmail.isNotEmpty && mounted) {
      setState(() {
        _email.text = savedEmail;
        _provider = kEmailProviders.firstWhere(
          (p) => p.host == savedHost,
          orElse: () => kEmailProviders.first,
        );
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل البريد وكلمة مرور التطبيقات');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await EmailImportService.fetchBillingText(
        host: _provider.host,
        email: email,
        password: password,
      );
      if (_remember) {
        final prefs = await SharedPreferences.getInstance();
        const secure = FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.unlocked_this_device,
          ),
        );
        await secure.write(key: _emailKey, value: email);
        await prefs.setString(_hostKey, _provider.host);
      } else {
        const secure = FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.unlocked_this_device,
          ),
        );
        await secure.delete(key: _emailKey);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_hostKey);
      }
      if (!mounted) return;
      if (result.matched == 0) {
        setState(() {
          _busy = false;
          _error = 'اتصلنا بنجاح وفحصنا ${result.scanned} رسالة، '
              'لكن لم نجد إيصالات اشتراكات حديثة.';
        });
        return;
      }
      setState(() => _busy = false);
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (_) => ImportScreen(initialText: result.combinedText),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'فشل الاتصال: تأكد من البريد وكلمة مرور التطبيقات '
            '(وليست كلمة مرورك العادية).';
      });
    } finally {
      // لا تبقِ كلمة مرور التطبيقات في ذاكرة واجهة المستخدم.
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.canvas.withValues(alpha: .92),
        border: Border(bottom: BorderSide(color: p.stroke)),
        middle: const Text('استيراد من البريد'),
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          children: [
            Text('فحص إيصالات الاشتراكات', style: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(
              'يفحص التطبيق أحدث رسائل الفوترة على جهازك. لا تُحفظ كلمة مرور التطبيقات ولا تُرسل إلى الذكاء الاصطناعي.',
              style: TextStyle(color: p.textMuted, fontSize: 13.5, height: 1.55),
            ),
            const SizedBox(height: 20),
            IosPickerRow(
              label: 'مزود البريد',
              value: _localizedProvider(_provider),
              icon: CupertinoIcons.mail,
              onPressed: () async {
                final selected = await showIosPicker<EmailProvider>(
                  context: context,
                  title: 'اختر مزود البريد',
                  selected: _provider,
                  values: kEmailProviders,
                  label: _localizedProvider,
                );
                if (selected != null) setState(() => _provider = selected);
              },
            ),
            const SizedBox(height: 14),
            IosTextField(
              controller: _email,
              label: 'عنوان البريد الإلكتروني',
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              placeholder: 'name@example.com',
            ),
            const SizedBox(height: 14),
            IosTextField(
              controller: _password,
              label: 'كلمة مرور التطبيقات',
              obscureText: true,
              textDirection: TextDirection.ltr,
              placeholder: 'xxxx-xxxx-xxxx-xxxx',
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 9),
              onPressed: () => launchUrl(
                Uri.parse(_provider.helpUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                'إنشاء كلمة مرور للتطبيقات في ${_localizedProvider(_provider)}',
                style: const TextStyle(fontSize: 13.5),
              ),
            )),
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.stroke)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('حفظ عنوان البريد', style: TextStyle(color: p.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('يُحفظ في Keychain على هذا الجهاز فقط.', style: TextStyle(color: p.textMuted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _remember,
                    activeTrackColor: p.accent,
                    onChanged: (value) => setState(() => _remember = value),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              IosStatusNotice(message: _error!, error: true),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _busy ? null : _fetch,
                child: _busy
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Text('فحص البريد واستيراد الاشتراكات'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.lock_shield, color: p.textMuted, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'استخدم كلمة مرور للتطبيقات، وليس كلمة مرور حسابك. يمكنك إلغاؤها من إعدادات مزود البريد في أي وقت.',
                    style: TextStyle(color: p.textMuted, fontSize: 12, height: 1.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _localizedProvider(EmailProvider provider) => switch (provider.label) {
        'iCloud Mail' => 'بريد iCloud',
        'Gmail' => 'Gmail من Google',
        'Outlook / Hotmail' => 'Outlook وHotmail',
        _ => provider.label,
      };
}
