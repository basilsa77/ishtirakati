/// ربط البريد: جلب إيصالات الاشتراكات من الإيميل تلقائيًا عبر IMAP.
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/email_import_service.dart';
import '../theme.dart';
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
        MaterialPageRoute(
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
    return Scaffold(
      appBar: AppBar(title: const Text('ربط البريد الإلكتروني')),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppCard(
              color: AppColors.primarySoft,
              borderColor: AppColors.primaryDeep,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'كيف يعمل؟',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'نتصل ببريدك مباشرة من جهازك، نفحص أحدث الرسائل بحثًا عن '
                    'إيصالات الاشتراكات (Apple، نتفلكس وغيرها)، ثم نستخرج '
                    'الاشتراكات تلقائيًا. كلمة المرور تبقى على جهازك '
                    'ولا تُخزّن أو تُرسل إلى الذكاء الاصطناعي.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<EmailProvider>(
              value: _provider,
              dropdownColor: AppColors.cardAlt,
              decoration: const InputDecoration(labelText: 'مزوّد البريد'),
              items: [
                for (final p in kEmailProviders)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) => setState(() => _provider = v ?? _provider),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                hintText: 'name@icloud.com',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'كلمة مرور خاصة بالتطبيقات',
                hintText: 'xxxx-xxxx-xxxx-xxxx',
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(_provider.helpUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: Text(
                'كيف أنشئ كلمة مرور للتطبيقات في ${_provider.label}؟',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            SwitchListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v),
              title: const Text(
                'تذكّر بريدي',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 14,
                ),
              ),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              AppCard(
                color: AppColors.dangerSoft,
                borderColor: AppColors.danger,
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _fetch,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF06231A),
                      ),
                    )
                  : const Icon(Icons.mark_email_read_rounded),
              label: Text(_busy ? 'نفحص بريدك...' : 'جلب الاشتراكات من بريدي'),
            ),
            const SizedBox(height: 10),
            const Text(
              'ملاحظة أمان: استخدم دائمًا «كلمة مرور خاصة بالتطبيقات» — '
              'وهي كلمة مرور محدودة يمكنك إلغاؤها في أي وقت، '
              'ولا تعطي وصولًا لحسابك الكامل.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
