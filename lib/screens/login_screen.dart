/// صفحة تسجيل الدخول: Google أو Apple — اختيارية تمامًا،
/// تظهر بعد الترحيب ويمكن فتحها من الإعدادات.
library;

import 'dart:async';

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

  Future<void> _continueToApp() async {
    if (widget.fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
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
      // اجلب النسخة السحابية إن وجدت، ثم ارفع الحالة الحالية.
      unawaited(CloudSync.restoreAndPush());
      const imported = 0;
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            imported > 0
                ? 'تم تسجيل الدخول واستعادة $imported عنصرًا من حسابك'
                : 'تم تسجيل الدخول — بياناتك ستُزامَن تلقائيًا',
          ),
        ),
      );
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
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
              // زر Apple (أبيض بأيقونة سوداء كإرشادات Apple)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                       configured ? Colors.white : p.surfaceAlt,
                  foregroundColor:
                       configured ? Colors.black : p.textMuted,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: (!configured || _busy)
                    ? null
                    : () => _signIn(AuthService.signInWithApple),
                icon: const Icon(Icons.apple_rounded, size: 26),
                label: const Text(
                  'المتابعة بحساب Apple',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // زر Google
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                       configured ? p.accentStrong : p.surfaceAlt,
                  foregroundColor: configured
                      ? Colors.white
                       : p.textMuted,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: (!configured || _busy)
                    ? null
                    : () => _signIn(AuthService.signInWithGoogle),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.g_mobiledata_rounded, size: 30),
                label: const Text(
                  'المتابعة بحساب Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
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
              TextButton(
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
    );
  }
}
