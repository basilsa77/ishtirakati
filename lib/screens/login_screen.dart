/// صفحة تسجيل الدخول: Google أو Apple — اختيارية تمامًا،
/// تظهر بعد الترحيب ويمكن فتحها من الإعدادات.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';

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
        _error = CloudSync.status.value.message ?? tr('ui_7eb5d2bf9dcd');
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
      CupertinoPageRoute(builder: (_) => const LockGate(child: RootShell())),
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
          _error = CloudSync.status.value.message ?? tr('ui_cffd5d591fa0');
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
        _error = tr('ui_77156fb0bf1f');
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
              padding: const EdgeInsets.symmetric(horizontal: V16Space.lg),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: V16Space.xxl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: p.heroGradient,
                              borderRadius: BorderRadius.circular(
                                V16Radius.signature,
                              ),
                              boxShadow:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? V16Elevation.darkLow
                                  : V16Elevation.medium,
                            ),
                            child: const Icon(
                              Icons.cloud_sync_rounded,
                              color: V16Colors.white,
                              size: 44,
                            ),
                          ),
                          const SizedBox(height: V16Space.xl),
                          if (configured)
                            AppCard(
                              tone: AppCardTone.muted,
                              elevated: false,
                              padding: const EdgeInsets.all(V16Space.lg),
                              child: AppPageIntro(
                                title: tr('ui_3502ec3b7f9b'),
                                description:
                                    tr('ui_4bffc5821b60') +
                                    tr('ui_097f251b4dfb') +
                                    tr('ui_3c23a47a16b1') +
                                    tr('ui_109c78d3b1e9') +
                                    tr('ui_2b0d41e83704'),
                              ),
                            )
                          else
                            AppEmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: tr('ui_3502ec3b7f9b'),
                              description:
                                  tr('ui_b5da29068d03') +
                                  tr('ui_a8b972961189') +
                                  tr('ui_fe70ed8741e8'),
                            ),
                          const SizedBox(height: V16Space.xl),
                          if (configured) ...[
                            _AuthButton(
                              backgroundColor: CupertinoColors.white,
                              foregroundColor: CupertinoColors.black,
                              onPressed: (_busy || signedIn)
                                  ? null
                                  : () => _signIn(AuthService.signInWithApple),
                              icon: const Icon(Icons.apple_rounded, size: 26),
                              label: Text(tr('ui_99e77aefca64')),
                            ),
                            const SizedBox(height: V16Space.sm),
                            _AuthButton(
                              backgroundColor: p.accentStrong,
                              foregroundColor: CupertinoColors.white,
                              onPressed: _busy
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
                                        fontSize: V16Type.title,
                                        fontWeight: V16Type.semibold,
                                      ),
                                    ),
                              label: Text(
                                signedIn
                                    ? tr('ui_eb496e41e621')
                                    : tr('ui_39553349fb40'),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: V16Space.md),
                            IosStatusNotice(
                              message: _error!,
                              tone:
                                  CloudSync.status.value.phase ==
                                      CloudSyncPhase.queued
                                  ? IosStatusTone.queued
                                  : IosStatusTone.error,
                              onRetry: signedIn && !_busy ? _retrySync : null,
                            ),
                          ],
                          const SizedBox(height: V16Space.xs),
                          CupertinoButton(
                            onPressed: _busy ? null : _continueToApp,
                            child: Text(
                              tr('ui_14cc566e3f90'),
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: V16Type.bodySmall,
                              ),
                            ),
                          ),
                          const SizedBox(height: V16Space.xl),
                          Text(
                            tr('ui_51c4df2de9fd') + tr('ui_712795b04159'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: p.textMuted,
                              fontSize: V16Type.caption,
                              height: V16Type.captionHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
      borderRadius: BorderRadius.circular(V16Radius.standard),
      padding: const EdgeInsets.symmetric(
        horizontal: V16Space.lg,
        vertical: V16Space.md,
      ),
      onPressed: onPressed,
      child: DefaultTextStyle(
        style: TextStyle(
          color: onPressed == null
              ? context.palette.textMuted
              : foregroundColor,
          fontFamily: V16Type.bodyFamily,
          fontSize: V16Type.body,
          fontWeight: V16Type.semibold,
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
              const SizedBox(width: V16Space.xs),
              Flexible(child: label),
            ],
          ),
        ),
      ),
    ),
  );
}
