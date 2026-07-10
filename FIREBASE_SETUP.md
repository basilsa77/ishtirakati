# Firebase And Google Sign-In

تم ربط التطبيق بمشروع Firebase على iOS. قبل أن يعمل الدخول بحساب Google، أكمل هذه الخطوات مرة واحدة من Firebase Console:

1. افتح Authentication ثم Sign-in method وفعّل Google.
2. تأكد أن تطبيق iOS في Project settings يحمل Bundle ID التالي: `com.basil.ishtirakati`.
3. نزّل ملف `GoogleService-Info.plist` من جديد واستبدل الملف الموجود في جذر المشروع. يجب أن يحتوي الملف الجديد على المفتاحين `CLIENT_ID` و`REVERSED_CLIENT_ID`.
4. افتح Firestore Database ثم Rules، والصق محتوى `firestore.rules` وانشره.
5. من Google Cloud Console، قيّد مفتاح API لتطبيق iOS هذا فقط باستخدام Bundle ID أعلاه. فعّل Firebase App Check قبل النشر العام.

البناء في GitHub Actions ينسخ ملف الإعداد إلى تطبيق iOS ويقرأ منه إعدادات OAuth تلقائيا. لا تحفظ كلمات مرور العملاء في Firestore؛ تسجيل الدخول يتم عبر Firebase Auth فقط.
