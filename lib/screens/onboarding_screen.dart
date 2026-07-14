/// الصفحة الترحيبية: تظهر مرة واحدة عند أول تشغيل، ترحب بالمستخدم
/// وتشرح التطبيق كاملًا، ثم لا تظهر مجددًا بعد ضغط «ابدأ الآن».
library;

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
    body: tr('ui_1391ea89c15f') +
        tr('ui_c5535e167b21') +
        tr('ui_faa589fdb7c0') +
        tr('ui_07c0fd2dd582'),
  ),
  _OnboardPage(
    icon: Icons.playlist_add_rounded,
    title: tr('ui_364a0c218fdd'),
    body: tr('ui_03c08f7f11cb') +
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
    body: tr('ui_ccbfc799f013') +
        tr('ui_fed76af911d5') +
        tr('ui_c352aded5496') +
        tr('ui_b9b303aab429') +
        tr('ui_d9f5e0136586'),
  ),
  _OnboardPage(
    icon: Icons.psychology_rounded,
    title: tr('ui_acb69ef77e4d'),
    body: tr('ui_4ca646f6ae60') +
        tr('ui_c7db730a0bbf') +
        tr('ui_ffda05033b78') +
        tr('ui_773468bee4b3') +
        tr('ui_140f7764a295'),
  ),
  _OnboardPage(
    icon: Icons.verified_user_rounded,
    title: tr('ui_a0d4d92593e1'),
    body: tr('ui_5b1fe2b1e36e') +
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: isLast
                    ? const SizedBox(height: 40)
                    : TextButton(
                        onPressed: _finish,
                        child: Text(
                          tr('ui_98874a5521b6'),
                          style: TextStyle(color: palette.textMuted),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            gradient: AppColors.heroGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x5514B886),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Icon(
                            p.icon,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: V15Type.title,
                            fontWeight: FontWeight.w900,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: V15Type.bodySmall,
                            color: palette.textMuted,
                            height: 1.8,
                          ),
                        ),
                      ],
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
                    duration: const Duration(milliseconds: 250),
                    width: i == _index ? 26 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index
                           ? palette.accent
                           : palette.stroke,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: FilledButton(
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: Text(isLast ? tr('ui_95895f0a5f05') : tr('ui_5cf7af74fd3a')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
