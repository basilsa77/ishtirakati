/// الصفحة الترحيبية: تظهر مرة واحدة عند أول تشغيل، ترحب بالمستخدم
/// وتشرح التطبيق كاملًا، ثم لا تظهر مجددًا بعد ضغط «ابدأ الآن».
library;

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/subscription_store.dart';
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

const List<_OnboardPage> _pages = [
  _OnboardPage(
    icon: Icons.waving_hand_rounded,
    title: 'أهلًا بك في «اشتراكاتي»',
    body: 'يسعدنا انضمامك! معظمنا يدفع لاشتراكات نسيها منذ شهور — '
        'من اليوم، كل ريال يخرج من جيبك سيمر من أمام عينيك أولًا.\n\n'
        'هذا تطبيقك أنت: بيانات اشتراكاتك مشفّرة على جهازك، بدون إعلانات، '
        'وبدون حسابات إجبارية.',
  ),
  _OnboardPage(
    icon: Icons.playlist_add_rounded,
    title: 'أضف اشتراكاتك في ثوانٍ',
    body: 'ثلاث طرق، اختر أسهلها:\n\n'
        '١. يدويًا — اختر من قائمة تضم أكثر من ٥٠ خدمة بأسعارها '
        'وشعاراتها الرسمية.\n\n'
        '٢. الاستيراد الذكي — الصق رسائل البنك أو إيصالات Apple '
        'وسيستخرجها التطبيق تلقائيًا.\n\n'
        '٣. ربط البريد — يفحص إيصالاتك في آخر ٦ أشهر ويجلب '
        'كل اشتراكاتك دفعة واحدة.',
  ),
  _OnboardPage(
    icon: Icons.notifications_active_rounded,
    title: 'لا مفاجآت في الفاتورة بعد اليوم',
    body: 'إشعار قبل كل خصم بالمدة التي تحددها، وتحذير خاص قبل '
        'تحول التجارب المجانية إلى مدفوعة.\n\n'
        'حدد ميزانية شهرية وسيظهر شريط يتابعها معك، '
        'ويحذرك عند الاقتراب من تجاوزها.\n\n'
        'وتقويم شهري يعرض أيام الخصم القادمة يومًا بيوم.',
  ),
  _OnboardPage(
    icon: Icons.psychology_rounded,
    title: 'ذكاء اصطناعي يعمل لمصلحتك',
    body: 'فعّل مفتاح Gemini المجاني من الإعدادات (دقيقتان فقط) '
        'وستحصل على:\n\n'
        '• استيراد يلتقط أي اشتراك حتى لو لم نسمع به.\n\n'
        '• مستشار ذكي يحلل اشتراكاتك ويقترح عليك أين توفر: '
        'خدمات مكررة، بدائل أرخص، وتحويلات سنوية موفرة.',
  ),
  _OnboardPage(
    icon: Icons.verified_user_rounded,
    title: 'خصوصيتك خط أحمر',
    body: 'بيانات اشتراكاتك مشفّرة محليًا. البريد والذكاء الاصطناعي '
        'اختياريان ولا يرسلان محتوى إلا بعد موافقتك.\n\n'
        'يمكنك قفل التطبيق ببصمة الوجه، وأخذ نسخة احتياطية '
        'تحفظها في مكان خاص.\n\n'
        'كل شيء جاهز الآن — لنبدأ بإضافة أول اشتراك!',
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
      MaterialPageRoute(builder: (_) => const LockGate(child: RootShell())),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        child: const Text(
                          'تخطي',
                          style: TextStyle(color: AppColors.muted),
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
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: AppColors.muted,
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
                          ? AppColors.primary
                          : AppColors.border,
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
                child: Text(isLast ? 'ابدأ الآن' : 'التالي'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
