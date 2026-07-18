/// ربط البريد: جلب إيصالات الاشتراكات من الإيميل تلقائيًا عبر IMAP.
library;

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/email_identity_store.dart';
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

  static const String _hostKey = 'ishtirakati_linked_host';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final savedEmail = await EmailIdentityStore.instance.readAndMigrate();
      final prefs = await SharedPreferences.getInstance();
      final savedHost = prefs.getString(_hostKey) ?? '';
      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          _email.text = savedEmail;
          _provider = kEmailProviders.firstWhere(
            (p) => p.host == savedHost,
            orElse: () => kEmailProviders.first,
          );
        });
      }
    } on EmailIdentityStorageException {
      if (mounted) setState(() => _error = tr('secureStorageLocked'));
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
        await EmailIdentityStore.instance.remember(email);
        await prefs.setString(_hostKey, _provider.host);
      } else {
        await EmailIdentityStore.instance.forget();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_hostKey);
      }
      if (!mounted) return;
      if (result.matched == 0) {
        setState(() {
          _busy = false;
          _error =
              tr('ui_aad9d5636c67', {'value0': result.scanned}) +
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = tr('ui_e57ba96aea6c') + tr('ui_cd4f8be47460');
      });
    } finally {
      // لا تبقِ كلمة مرور التطبيقات في ذاكرة واجهة المستخدم.
      _password.clear();
    }
  }

  Future<void> _openProviderHelp() async {
    final uri = Uri.parse(_provider.helpUrl);
    if (uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.canvas.withValues(alpha: .92),
        border: Border(bottom: BorderSide(color: p.stroke)),
        middle: Text(
          tr('ui_61b676130c36'),
          style: TextStyle(
            color: p.text,
            fontSize: V16Type.body,
            fontWeight: V16Type.semibold,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            V16Space.ml,
            V16Space.lg,
            V16Space.ml,
            V16Space.xl,
          ),
          children: [
            AppPageIntro(
              title: tr('ui_21c32e81995c'),
              description: tr('ui_fb60e2c3e823'),
            ),
            const SizedBox(height: V16Space.lg),
            FadeSlideIn(
              child: AppCard(
                elevated: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        if (!mounted) return;
                        if (selected != null) {
                          setState(() => _provider = selected);
                        }
                      },
                    ),
                    const SizedBox(height: V16Space.md),
                    IosTextField(
                      controller: _email,
                      label: tr('ui_8a0b55ab8c62'),
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      placeholder: 'name@example.com',
                    ),
                    const SizedBox(height: V16Space.md),
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
                        padding: const EdgeInsets.symmetric(
                          vertical: V16Space.xs,
                        ),
                        onPressed: _openProviderHelp,
                        child: Text(
                          tr('ui_626c22ee912c', {
                            'value0': _localizedProvider(_provider),
                          }),
                          style: const TextStyle(
                            fontSize: V16Type.label,
                            fontWeight: V16Type.semibold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: V16Space.sm),
            AppCard(
              elevated: false,
              padding: const EdgeInsetsDirectional.fromSTEB(
                V16Space.md,
                V16Space.xs,
                V16Space.sm,
                V16Space.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('ui_ad702e6b4d70'),
                          style: TextStyle(
                            color: p.text,
                            fontSize: V16Type.bodySmall,
                            fontWeight: V16Type.semibold,
                          ),
                        ),
                        const SizedBox(height: V16Space.xxs),
                        Text(
                          tr('ui_15f4d9231b10'),
                          style: TextStyle(
                            color: p.textMuted,
                            fontSize: V16Type.caption,
                            height: V16Type.captionHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: V16Space.sm),
                  CupertinoSwitch(
                    value: _remember,
                    activeTrackColor: p.accent,
                    onChanged: (value) => setState(() => _remember = value),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: V16Space.sm),
              IosStatusNotice(message: _error!, error: true),
            ],
            const SizedBox(height: V16Space.md),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(V16Radius.standard),
                onPressed: _busy ? null : _fetch,
                child:
                    _busy
                        ? CupertinoActivityIndicator(
                          color:
                              p.isDark ? V16Colors.darkCanvas : V16Colors.white,
                        )
                        : Text(tr('ui_7c9841249f12')),
              ),
            ),
            const SizedBox(height: V16Space.sm),
            AppCard(
              tone: AppCardTone.muted,
              elevated: false,
              padding: const EdgeInsets.all(V16Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.lock_shield,
                    color: p.accent,
                    size: V16Space.ml,
                  ),
                  const SizedBox(width: V16Space.xs),
                  Expanded(
                    child: Text(
                      tr('ui_88d294591e54'),
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V16Type.caption,
                        height: V16Type.bodyHeight,
                      ),
                    ),
                  ),
                ],
              ),
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
