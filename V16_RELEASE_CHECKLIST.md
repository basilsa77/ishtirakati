# اشتراكاتي 16.0.0+44 — Release Checklist

لا يُعد الإصدار جاهزًا للتوزيع العام حتى تكتمل البنود الخارجية أدناه. لا تُسجل UID أو email أو token أو backup أو مفتاح في أي لقطة أو سجل.

## بوابة المصدر

- [x] `flutter pub get --enforce-lockfile`
- [x] `flutter analyze lib test`
- [x] `flutter test` — 154/154.
- [x] `npm ci --ignore-scripts` — نجح؛ 5 تنبيهات moderate في أدوات التطوير تحتاج ترقية مخططة دون كسر القفل.
- [x] `npm run test:rules`
- [ ] نجاح GitHub Actions وإنتاج `Ishtirakati-16.0.0-build44-<SHA>-unsigned.ipa`.
- [ ] تطابق SHA في About مع اسم artifact.

## مصفوفة الواجهة

- [ ] iPhone صغير + text scale 1.4: كل الشاشات دون overflow.
- [ ] iPhone حديث وiPad portrait/landscape.
- [ ] Arabic RTL وEnglish LTR.
- [ ] Light وDark وReduce Motion.
- [ ] VoiceOver يقرأ ملخص كل رسم وحالة فارغة وشارة تجديد.
- [ ] العملات لا تُجمع ولا تتحول ضمنيًا.

## المزامنة على الجهاز الحقيقي

- [ ] أول create يصل إلى revision 1 بتأكيد الخادم.
- [ ] update واحد يصل إلى stored+1 فقط.
- [ ] offline write يظهر queued ولا يظهر success.
- [ ] عودة الشبكة تؤكد المراجعة قبل حفظها محليًا كمؤكدة.
- [ ] conflict يبقى fail-closed ولا ينفذ pull/push أعمى.
- [ ] restore بالمفتاح نفسه ينجح، والمفتاح المختلف يفشل مغلقًا دون مسح المحلي.
- [ ] حذف الحساب: Firestore ثم Firebase user ثم local.

## Firebase Console

- [ ] القواعد المنشورة هي نسخة المستودع نفسها على `ishtirakati-260f7`.
- [ ] Auth providers وApple/Google clients وbundle ID صحيحة.
- [ ] App Check metrics نظيفة ثم enforcement مفعل في build التوزيع فقط.
- [ ] API key restrictions وFirestore budget alerts مفعلة.
- [ ] لا Storage/Functions/Remote Config/FCM مستخدمة ما لم يضفها إصدار موثق لاحقًا.

## TestFlight / App Store

- [ ] Archive موقّع من Xcode/CI محمي، وليس unsigned IPA.
- [ ] iOS deployment target = 15.0 وbundle ID = `com.basil.ishtirakati`.
- [ ] Sign in with Apple capability وFace ID usage description وURL schemes صحيحة.
- [ ] Privacy Manifest وApp Privacy answers وaccount deletion flow مراجعة.
- [ ] dSYM وsplit-debug-info محفوظان للوصول المقيد.
- [ ] Smoke test من TestFlight على iPhone وiPad قبل التوزيع.
