/// ربط البريد: جلب إيصالات الاشتراكات من الإيميل تلقائيًا عبر IMAP.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
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
      setState(() => _error = tr('ui_ca78e717a0a1'));
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
          _error = tr('ui_aad9d5636c67', {'value0': result.scanned}) +
              tr('ui_24cd4330e1b3');
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
        _error = tr('ui_e57ba96aea6c') +
            tr('ui_cd4f8be47460');
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
        middle: Text(tr('ui_61b676130c36')),
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          children: [
            Text(tr('ui_21c32e81995c'), style: TextStyle(color: p.text, fontSize: V15Type.headlineSmall, fontWeight: FontWeight.w800)),
            SizedBox(height: 7),
            Text(
              tr('ui_fb60e2c3e823'),
              style: TextStyle(color: p.textMuted, fontSize: V15Type.label, height: 1.55),
            ),
            SizedBox(height: 20),
            IosPickerRow(
              label: tr('ui_ca2b10b75a55'),
              value: _localizedProvider(_provider),
              icon: CupertinoIcons.mail,
              onPressed: () async {
                final selected = await showIosPicker<EmailProvider>(
                  context: context,
                  title: tr('ui_5faa00acc81d'),
                  selected: _provider,
                  values: kEmailProviders,
                  label: _localizedProvider,
                );
                if (selected != null) setState(() => _provider = selected);
              },
            ),
            SizedBox(height: 14),
            IosTextField(
              controller: _email,
              label: tr('ui_8a0b55ab8c62'),
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              placeholder: 'name@example.com',
            ),
            SizedBox(height: 14),
            IosTextField(
              controller: _password,
              label: tr('ui_20046a1fc591'),
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
                tr('ui_626c22ee912c', {'value0': _localizedProvider(_provider)}),
                style: TextStyle(fontSize: V15Type.label),
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
                        Text(tr('ui_ad702e6b4d70'), style: TextStyle(color: p.text, fontSize: V15Type.bodySmall, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text(tr('ui_15f4d9231b10'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
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
              SizedBox(height: 12),
              IosStatusNotice(message: _error!, error: true),
            ],
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _busy ? null : _fetch,
                child: _busy
                    ? CupertinoActivityIndicator(color: CupertinoColors.white)
                    : Text(tr('ui_7c9841249f12')),
              ),
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.lock_shield, color: p.textMuted, size: 17),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('ui_88d294591e54'),
                    style: TextStyle(color: p.textMuted, fontSize: V15Type.caption, height: 1.55),
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
        'iCloud Mail' => tr('ui_ef748ad7f4c6'),
        'Gmail' => tr('ui_78dda4e041a7'),
        'Outlook / Hotmail' => tr('ui_8a15a0d445de'),
        _ => provider.label,
      };
}
