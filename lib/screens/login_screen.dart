/// صفحة تسجيل الدخول: Google أو Apple — اختيارية تمامًا،
/// تظهر بعد الترحيب ويمكن فتحها من الإعدادات.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  /// true عند فتحها من الإعدادات (تُغلق بدل الانتقال للرئيسية).
  final bool fromSettings;

  const LoginScreen({super.key, this.fromSettings = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _retrySync() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final sync = await CloudSync.restoreAndPush();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!sync.success) {
        _error = CloudSync.status.value.message ??
            'تعذرت المزامنة. أعد المحاولة من الإعدادات.';
      }
    });
    if (sync.success) await _continueToApp();
  }

  Future<void> _continueToApp() async {
    if (widget.fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (_) => const LockGate(child: RootShell()),
      ),
    );
  }

  Future<void> _signIn(Future<dynamic> Function() method) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await method();
      if (!mounted) return;
      if (user == null) {
        setState(() => _busy = false); // ألغى المستخدم
        return;
      }
      // لا نغادر شاشة الدخول قبل معرفة أن Firestore قبل النسخة فعلًا.
      final sync = await CloudSync.restoreAndPush();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!sync.success) {
        setState(() {
          _error = CloudSync.status.value.message ??
              'تم تسجيل الدخول، لكن تعذرت المزامنة. أعد المحاولة من الإعدادات.';
        });
        return;
      }
      await _continueToApp();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'حدث خطأ غير متوقع — أعد المحاولة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = AuthService.isAvailable;
    final p = context.palette;
    final signedIn = AuthService.isSignedIn;
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      child: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x5514B886), blurRadius: 30),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'احفظ بياناتك مع حسابك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                configured
                    ? 'سجّل دخولك لتُحفظ اشتراكاتك بأمان مع حسابك، '
                        'وتستعيدها تلقائيًا على أي جهاز جديد.\n'
                        'اختياري تمامًا — التطبيق يعمل كاملًا بدونه.\n'
                        'النسخة محمية لدى Firebase لكنها ليست مشفرة طرفيًا E2E.'
                    : 'المزامنة السحابية قيد التجهيز وستتوفر في تحديث '
                        'قريب — يمكنك استخدام التطبيق كاملًا الآن، '
                        'وبياناتك محفوظة مشفّرة على جهازك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: p.textMuted,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 32),
              _AuthButton(
                backgroundColor: CupertinoColors.white,
                foregroundColor: CupertinoColors.black,
                onPressed: (!configured || _busy || signedIn)
                    ? null
                    : () => _signIn(AuthService.signInWithApple),
                icon: const Icon(Icons.apple_rounded, size: 26),
                label: const Text(
                  'المتابعة بحساب Apple',
                ),
              ),
              const SizedBox(height: 12),
              _AuthButton(
                backgroundColor: p.accentStrong,
                foregroundColor: CupertinoColors.white,
                onPressed: (!configured || _busy)
                    ? null
                    : signedIn
                        ? _retrySync
                        : () => _signIn(AuthService.signInWithGoogle),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        ),
                      )
                    : const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                label: Text(
                  signedIn
                      ? 'إعادة محاولة المزامنة'
                      : 'المتابعة بحساب Google',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              CupertinoButton(
                onPressed: _busy ? null : _continueToApp,
                child: Text(
                  'المتابعة بدون حساب',
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'بياناتك تُحفظ في مساحة خاصة بحسابك فقط، '
                  'ولا نستخدمها لأي غرض آخر.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 11.5,
                    height: 1.6,
                  ),
                ),
              ),
            ],
                ),
              ),
            ),
          ],
          ),
        ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;

  const _AuthButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          color: backgroundColor,
          disabledColor: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          onPressed: onPressed,
          child: DefaultTextStyle(
            style: TextStyle(
              color: onPressed == null
                  ? context.palette.textMuted
                  : foregroundColor,
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: onPressed == null
                    ? context.palette.textMuted
                    : foregroundColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Flexible(child: label),
                ],
              ),
            ),
          ),
        ),
      );
}
