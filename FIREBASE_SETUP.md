# Firebase And Google Sign-In

تم ربط التطبيق بمشروع Firebase على iOS. قبل أن يعمل الدخول بحساب Google، أكمل هذه الخطوات مرة واحدة من Firebase Console:

1. افتح Authentication ثم Sign-in method وفعّل Google.
2. تأكد أن تطبيق iOS في Project settings يحمل Bundle ID التالي: `com.basil.ishtirakati`.
3. نزّل ملف `GoogleService-Info.plist` من جديد واستبدل الملف الموجود في جذر المشروع. يجب أن يحتوي الملف الجديد على المفتاحين `CLIENT_ID` و`REVERSED_CLIENT_ID`.
4. افتح Firestore Database ثم Rules، والصق محتوى `firestore.rules` وانشره.
5. من Google Cloud Console، قيّد مفتاح API لتطبيق iOS هذا فقط باستخدام Bundle ID أعلاه.
6. من Firebase Console افتح Security ثم App Check، وسجّل تطبيق iOS باستخدام App Attest. وزّع الإصدار 7.2.0، راقب الطلبات الصحيحة، ثم فعّل Enforcement لخدمتي Firestore وAuthentication.

## App Check والحساب المجاني

بناء التوقيع الجانبي الحالي يستخدم
`--dart-define=ENABLE_FIREBASE_APP_CHECK=false` لأن Apple App Attest وDeviceCheck
لا يصدران إثباتات إنتاجية قابلة للتسجيل لتطبيق موقع بفريق Apple مجاني. محاولة
تفعيل المزوّد قبل تسجيله في Firebase كانت تعيد خطأ `not-found` وتمنع المزامنة.

هذا الوضع لا يلغي مصادقة Firebase أو قواعد Firestore: كل مستند يظل محصورًا بصاحب
الحساب، مع التحقق من الحقول والحجم ورقم المراجعة. عند توفر عضوية Apple Developer
مدفوعة، سجّل App ID وApp Attest في Apple وFirebase أولًا، ثم ابنِ باستخدام
`--dart-define=ENABLE_FIREBASE_APP_CHECK=true`. راقب الطلبات الموثقة قبل تفعيل
Enforcement من Firebase Console.

البناء في GitHub Actions ينسخ ملف الإعداد إلى تطبيق iOS ويقرأ منه إعدادات OAuth تلقائيا. لا تحفظ كلمات مرور العملاء في Firestore؛ تسجيل الدخول يتم عبر Firebase Auth فقط.
