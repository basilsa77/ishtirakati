/// الصفحة الترحيبية: تظهر مرة واحدة عند أول تشغيل، ترحب بالمستخدم
/// وتشرح التطبيق كاملًا، ثم لا تظهر مجددًا بعد ضغط «ابدأ الآن».
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/subscription_store.dart';
import 'login_screen.dart';
import '../theme.dart';

class _OnboardPage {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });
}

List<_OnboardPage> get _pages => [
  _OnboardPage(
    icon: Icons.waving_hand_rounded,
    title: tr('ui_2b992a728cb2'),
    body:
        tr('ui_1391ea89c15f') +
        tr('ui_c5535e167b21') +
        tr('ui_faa589fdb7c0') +
        tr('ui_07c0fd2dd582'),
  ),
  _OnboardPage(
    icon: Icons.playlist_add_rounded,
    title: tr('ui_364a0c218fdd'),
    body:
        tr('ui_03c08f7f11cb') +
        tr('ui_1b8ae8c6c0b9') +
        tr('ui_70b4eebf6347') +
        tr('ui_5e07fa5502e0') +
        tr('ui_ee5f0ff55e85') +
        tr('ui_0b80d7c28a68') +
        tr('ui_75d1e9784dd5'),
  ),
  _OnboardPage(
    icon: Icons.notifications_active_rounded,
    title: tr('ui_e9495438033d'),
    body:
        tr('ui_ccbfc799f013') +
        tr('ui_fed76af911d5') +
        tr('ui_c352aded5496') +
        tr('ui_b9b303aab429') +
        tr('ui_d9f5e0136586'),
  ),
  _OnboardPage(
    icon: Icons.psychology_rounded,
    title: tr('ui_acb69ef77e4d'),
    body:
        tr('ui_4ca646f6ae60') +
        tr('ui_c7db730a0bbf') +
        tr('ui_ffda05033b78') +
        tr('ui_773468bee4b3') +
        tr('ui_140f7764a295'),
  ),
  _OnboardPage(
    icon: Icons.verified_user_rounded,
    title: tr('ui_a0d4d92593e1'),
    body:
        tr('ui_5b1fe2b1e36e') +
        tr('ui_a0713395ae4c') +
        tr('ui_48c70870999d') +
        tr('ui_0963e01daad5') +
        tr('ui_2b5149dc5bfc'),
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await SubscriptionStore.instance.setOnboarded();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(CupertinoPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: V16Space.md,
                  vertical: V16Space.xxs,
                ),
                child: isLast
                    ? const SizedBox(height: 40)
                    : TextButton(
                        onPressed: _finish,
                        child: Text(
                          tr('ui_98874a5521b6'),
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: V16Type.label,
                            fontWeight: V16Type.semibold,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(V16Space.lg),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: FadeSlideIn(
                          child: AppCard(
                            tone: AppCardTone.muted,
                            elevated: false,
                            padding: const EdgeInsets.all(V16Space.xl),
                            child: Column(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: palette.heroGradient,
                                    borderRadius: BorderRadius.circular(
                                      V16Radius.signature,
                                    ),
                                    boxShadow:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? V16Elevation.darkLow
                                        : V16Elevation.medium,
                                  ),
                                  child: Icon(
                                    p.icon,
                                    color: V16Colors.white,
                                    size: 44,
                                  ),
                                ),
                                const SizedBox(height: V16Space.xl),
                                AppPageIntro(
                                  title: p.title,
                                  description: p.body,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : V16Motion.quick,
                    width: i == _index ? 26 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(
                      horizontal: V16Space.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: i == _index ? palette.accent : palette.stroke,
                      borderRadius: BorderRadius.circular(V16Radius.pill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                V16Space.lg,
                V16Space.lg,
                V16Space.lg,
                V16Space.ml,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        if (reduceMotion(context)) {
                          _controller.jumpToPage(_index + 1);
                        } else {
                          _controller.nextPage(
                            duration: V16Motion.entrance,
                            curve: V16Motion.standardCurve,
                          );
                        }
                      }
                    },
                    child: Text(
                      isLast ? tr('ui_95895f0a5f05') : tr('ui_5cf7af74fd3a'),
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
