# Security Audit - Ishtirakati 11.0.0+24

تاريخ المراجعة: 2026-07-11

الالتزام المراجع: `37eb019`

النطاق: مراجعة ساكنة وتصميمية دفاعية لتطبيق Flutter/iOS وقواعد Firestore ومسار GitHub Actions. لم تُنفذ اختبارات اختراق أو محاولات تجاوز أو استغلال.

> طلب التدقيق أشار إلى v10، لكن النسخة الفعلية في `pubspec.yaml` بعد المعالجة هي `11.0.0+24`. النتائج أدناه تخص الكود الفعلي الحالي.

## 1. الملخص التنفيذي

الوضع العام: **نُفذت معالجة البنود البرمجية العالية والمتوسطة في +24. يبقى اعتماد نتائج CI وفحوص Firebase/App Store الخارجية قبل النشر العام.**

نقاط القوة الأهم:

- AES-256-GCM مستخدم عبر مكتبة `cryptography` مع nonce يولده المزود وتحقق MAC عند الفك.
- قفل التطبيق الحيوي يفشل مغلقًا، ويعاد تفعيله عند انتقال التطبيق للخلفية.
- Apple Sign-In يستخدم nonce عشوائيًا من `Random.secure()` ثم SHA-256.
- قواعد Firestore تقيد المستند بالمستخدم المالك وتتحقق من الحقول والحجم وإصدار المخطط.
- اتصالات التطبيق المملوكة له تستخدم HTTPS، وIMAP يعمل على TLS والمنفذ 993 مع تعطيل سجلات العميل.
- لا توجد كلمات مرور بريد محفوظة، ولا توجد مفاتيح خاصة أو رموز وصول متتبعة في الحالة الحالية للمستودع.
- GitHub Actions يستخدم `contents: read` ولا يحتفظ ببيانات اعتماد checkout، وبناء Release يستخدم تعمية Dart ويفصل الرموز.

أبرز ثلاث مخاطر أصلية وحالة معالجتها:

1. **AUD-01 - عالٍ:** عولج بسياسة Keychain-first ومرآة توافق اختيارية تُقرأ فقط بعد فشل Keychain، مع تحقق MAC قبل تعطيلها.
2. **AUD-02 - عالٍ/امتثال:** عولج بمسار إعادة مصادقة ثم حذف Firestore وحساب Firebase ثم تصفير المحلي.
3. **AUD-03 وAUD-04 - متوسطان:** أضيفت موافقة AI مرتبطة بالمزود، ووُثق حد Firestore غير E2E داخل التطبيق وسياسة الخصوصية.

لا توجد نتيجة حرجة مؤكدة في هذه المراجعة. غياب نتيجة حرجة لا يعني غياب المخاطر التشغيلية أو مخاطر الأجهزة المكسورة الحماية.

## 2. جدول النتائج

| المعرّف | المحور | الخطورة | الملف:السطر | الوصف | الإصلاح المقترح | الحالة |
|---|---|---:|---|---|---|---|
| AUD-01 | التخزين/الأسرار | عالية (CVSS تقريبي 7.1) | `lib/services/secure_data_codec.dart`; `lib/services/subscription_store.dart` | كانت مفاتيح AES وAI تُمرآ دائمًا. | Keychain-first؛ fallback توافق اختياري؛ تحقق MAC قبل حذف المرآة؛ المستخدم الجديد Keychain-only. | عولج في +24 |
| AUD-02 | الخصوصية/الحساب | عالية - عائق إصدار | `lib/services/account_deletion_service.dart`; `lib/screens/settings_screen.dart` | لم يكن حذف الحساب والسحابة متاحًا. | إعادة مصادقة، حذف Firestore، حذف Firebase Auth، ثم المحلي مع شاشة عربية واضحة. | عولج في +24 |
| AUD-03 | الخصوصية/AI | متوسطة (CVSS تقريبي 5.7) | `lib/services/ai_consent_service.dart`; `lib/screens/insights_screen.dart` | كان المستشار يرسل البيانات دون موافقة فورية. | موافقة مرتبطة بالمزود والحقول وخيار إلغاء وتذكّر القرار. | عولج في +24 |
| AUD-04 | السحابة/الخصوصية | متوسطة (CVSS تقريبي 5.5) | `lib/services/cloud_sync.dart`; `lib/screens/login_screen.dart`; `PRIVACY_POLICY.md` | النسخة السحابية ليست E2E. | اختير المسار (أ): إفصاح واضح داخل الدخول والإعدادات والسياسة، مع إبقاء Auth/Rules/TLS. | عولج توثيقيًا في +24 |
| AUD-05 | سلامة البيانات | متوسطة (CVSS تقريبي 5.5) | `lib/services/subscription_store.dart`; `lib/main.dart` | كان فشل الفك يسمح بحالة قابلة للكتابة. | حفظ الأصل والنسخة، قفل الكتابة والمزامنة، وبوابة استرداد واضحة. | عولج في +24 |
| AUD-06 | Firebase/App Check | متوسطة مشروطة (CVSS 6.5 عند عدم الفرض) | `lib/services/auth_service.dart`; `lib/screens/settings_screen.dart` | كان فشل App Check يُبتلع. | سجل آمن وتحذير للمستخدم؛ الفرض يبقى من Firebase Console. | الكود عولج؛ اللوحة معلقة |
| AUD-07 | سلسلة التوريد البعيدة | متوسطة (CVSS تقريبي 5.4) | `lib/services/remote_catalog.dart` | كان الكتالوج من `main` المتحرك. | تثبيت commit SHA، كاش جديد، وحد 512 KiB. | عولج في +24 |
| AUD-08 | الروابط/الشبكة | متوسطة (CVSS تقريبي 4.7) | `lib/services/safe_url.dart`; `lib/screens/subscriptions_screen.dart` | كانت سجلات `http://` القديمة تُفتح. | سياسة مركزية لا تقبل إلا HTTPS دون userinfo أو محارف تحكم. | عولج في +24 |
| AUD-09 | CI/CD والاعتماديات | متوسطة (CVSS تقريبي 5.3) | `pubspec.lock`; `.github/workflows/build-ipa.yml` | عولج نقص قابلية التكرار: أُلزم lockfile، وثُبّت Flutter 3.44.6، وثُبّتت جميع Actions على full commit SHA رسمي. يبقى فحص OSV/Dependabot تصلّبًا دوريًا. | أبقِ Dependabot والتنبيهات الأمنية مفعّلة وراجع تحديثات SHA المقصودة دوريًا. | مُعالج في v11.0.0+24 |
| AUD-10 | سلامة الإصدار | متوسطة | `.github/workflows/build-ipa.yml:109-176` | المسار ينتج IPA غير موقع ويعتمد توقيعًا يدويًا؛ مناسب للاختبار وليس سلسلة إصدار App Store ذات provenance. | workflow إصدار منفصل ببيئة محمية، توقيع Apple، checksums، artifact attestation وSBOM. | مؤكّد |
| AUD-11 | المدخلات/التوافر | متوسطة (CVSS تقريبي 4.3) | `lib/screens/import_screen.dart:48-50,146-151`; `lib/services/import_parser.dart:233-281` | نص اللصق يمر للمحلل المحلي بلا حد bytes/lines قبل split والمسح المتكرر. | حد 2 MiB و5000 سطر قبل تعيين controller أو التحليل، وحدود لاستجابات الشبكة. | مؤكّد |
| AUD-12 | الخصوصية/الإشعارات | منخفضة (CVSS تقريبي 3.3) | `lib/services/notification_service.dart:109-139,156-169` | اسم الخدمة والمبلغ قد يظهران على شاشة القفل وفق إعدادات iOS. | خيار "إشعارات خاصة" بنص عام، وتوثيق أن iOS يتحكم بالمعاينات. | مؤكّد |
| AUD-13 | الخصوصية/طلبات الصور | منخفضة (CVSS تقريبي 3.1) | `lib/data/service_domains.dart:69-80`; `lib/theme.dart:565-590` | جلب favicon من Google وصور iTunes/روابط مخصصة يكشف IP وتوقيت العرض ونطاق الخدمة لطرف ثالث. | أصول محلية للخدمات الشائعة، تعطيل الشبكة اختياريًا، وتقييد المضيف والحجم والنوع. | مؤكّد |
| AUD-14 | الجلسات | منخفضة (CVSS تقريبي 3.1) | `lib/services/auth_service.dart:139-144` | فشل تسجيل الخروج يُبتلع ولا تعاد نتيجة؛ ولا تُنهى جلسة Google SDK صراحة. | أعد نتيجة واضحة، تحقق من `currentUser == null`، وامسح/افصل جلسة المزود حسب اختيار المستخدم. | مؤكّد |
| AUD-15 | الاعتماديات | منخفضة/معلومة | `pubspec.yaml:12-31` | حل CI وجد 22 حزمة أحدث غير متوافقة مع القيود، ومنها إصدارات رئيسية لـlocal_auth والإشعارات؛ لا يمكن إثبات الشجرة التعدية دون lockfile. | lockfile ثم `dart pub outdated` وOSV/Dependabot في كل PR؛ ترقية رئيسية مجدولة مع اختبارات iOS. | مؤكّد جزئيًا |
| AUD-16 | الأسرار/Firebase config | معلومة | `.gitignore:21-23`; سجل Git للمسارين | إعدادات Firebase أزيلت من التتبع، لكن المساران ظهرا في تاريخ Git. مفتاح Firebase إعداد عميل عام وليس سر تفويض. | راجع القيود والاستخدام، دوّر القيمة التاريخية إن لم تُدوّر، وأغلق تنبيه GitHub بعد التحقق لا قبله. | يحتاج فحصًا يدويًا |
| AUD-17 | التوثيق/الخصوصية | متوسطة - امتثال | `lib/main.dart:1-3`; `README.md:24-31` | تعليق main يدعي أن كل البيانات على الجهاز، بينما توجد مزامنة وAI وصور شبكية؛ لم يُعثر على سياسة خصوصية داخل المشروع. | سياسة خصوصية منشورة وداخل التطبيق، خريطة بيانات، تحديث النصوص وApp Privacy Labels. | مؤكّد |
| AUD-18 | الاختبارات الأمنية | منخفضة | `test/`؛ `firestore.rules` | توجد اختبارات منطق جيدة، لكن لا توجد اختبارات emulator للقواعد ولا اختبارات codec/فشل Keychain وحدود المدخلات. | Firebase Rules Unit Testing واختبارات tamper/MAC/migration/fail-closed/limits. | مؤكّد |

## 3. تفصيل البنود العالية

### AUD-01 - مرآة المفاتيح خارج Keychain

**سبب الخطورة**

- `SecureDataCodec` يولد مفتاح AES-256 جيدًا، لكن `_mirrorKey()` يضع المفتاح نفسه في `SharedPreferences`.
- `SubscriptionStore` يضع مفتاح AI كاملاً في الموضع نفسه بعد Base64.
- من يحصل على حاوية Preferences يحصل على النص المشفر ومفتاح فكّه معًا، كما يمكنه استخدام مفتاح AI على حساب المستخدم.
- تشفير قرص iOS والسandbox يظلان طبقتين مفيدتين، لذلك لا يعني هذا أن أي تطبيق عادي يستطيع القراءة، لكنه يلغي الفصل الذي يفترضه تصميم Keychain.

**الإصلاح الآمن دون فقدان البيانات**

1. لا تحذف المرآة مباشرة في تحديث واحد.
2. أنشئ مفتاح Keychain بإصدار جديد و`ThisDeviceOnly`، ويفضل `WhenPasscodeSetThisDeviceOnly` عندما تسمح تجربة المستخدم بذلك.
3. في الترحيل: اقرأ المفتاح القديم، فك السجل وتحقق MAC، أعد تشفيره بالمفتاح الجديد، ثم اقرأه مرة ثانية للتحقق.
4. بعد نجاح المعاملة فقط احذف مرآة AES ومرآة API من Preferences.
5. إذا تعذر Keychain، افشل مغلقًا إلى شاشة استرداد؛ لا تنشئ مفتاحًا جديدًا ولا تحفظ فوق السجل.
6. وفر تصدير استرداد مشفرًا بعبارة يختارها المستخدم لمن يحتاج النقل بين الأجهزة أو إعادة التوقيع.
7. أضف اختبارات انقطاع Keychain، مفتاح خاطئ، payload معدل، وترحيل من كل موضع قديم.

### AUD-02 - غياب حذف الحساب والبيانات السحابية

**سبب الخطورة**

- Google/Apple Sign-In ينشئان مستخدم Firebase ومستند `/users/{uid}`.
- تسجيل الخروج لا يحذف الحساب ولا المستند السحابي.
- Apple تشترط أن يسمح التطبيق الذي يدعم إنشاء الحساب ببدء حذف الحساب من داخله، بما في ذلك البيانات المرتبطة غير المطلوبة قانونيًا.

**الإصلاح المقترح**

1. أضف "حذف الحساب والنسخة السحابية" في إعدادات الحساب، منفصلًا عن حذف البيانات المحلية.
2. اطلب تأكيدًا واضحًا ثم إعادة مصادقة حديثة مع Google/Apple.
3. احذف `/users/{uid}` أولًا، ثم نفذ `FirebaseAuth.currentUser.delete()`.
4. عند Apple، نفذ مسار إلغاء token وفق متطلبات Sign in with Apple.
5. لا تمسح المحلي قبل نجاح السحابة والحساب إلا إذا اختار المستخدم ذلك صراحة.
6. اعرض نتيجة قابلة للفهم وتعامل مع `requires-recent-login` بإعادة المصادقة بدل الفشل الصامت.

## 4. ملاحظات تفصيلية حسب MASVS

### التخزين والتعمية

- **إيجابي:** AES-GCM 256 يوفر السرية والسلامة، والمكتبة تولد nonce عند كل تشفير (`secure_data_codec.dart:97-107`).
- **إيجابي:** فك التشفير لا يقبل plaintext عند فشل MAC (`secure_data_codec.dart:130-143`).
- **فجوة:** لا توجد دورة تدوير مفاتيح أو AAD يربط envelope بالغرض/الإصدار. أضف `purpose`, `createdAt`, `keyId` كـAAD في envelope v2.
- **فجوة:** إعدادات غير حساسة مثل العملة والثيم والميزانية وحالة القفل في Preferences مقبول وظيفيًا، لكن حالة القفل قابلة للتعديل لمن يملك حاوية التطبيق؛ لا تعامل القفل الحيوي كبديل لتشفير البيانات.
- **إيجابي:** لم تُرصد طباعة للبيانات أو كلمات المرور عبر `print/debugPrint/log`.

### المصادقة والجلسات

- **إيجابي:** `currentUser` يعيد null عند فشل Firebase، ولا يوجد تجاوز مصادقة fail-open.
- **إيجابي:** LockGate لا يفتح عند exception أو نتيجة false (`main.dart:165-190`).
- **إيجابي:** nonce الخاص بـApple عشوائي ومجزأ SHA-256 (`auth_service.dart:107-121,146-160`).
- **تحسين:** لا توجد مهلة جلسة تطبيقية. هذا مقبول لـFirebase، لكن يوصى بالقفل الحيوي افتراضيًا للمستخدم الذي يفعل المزامنة أو يحتفظ ببيانات مالية حساسة.

### الشبكة

- جميع endpoints الثابتة في الخدمات تستخدم HTTPS، وIMAP يستخدم TLS (`email_import_service.dart:123-126`).
- لا يوجد certificate pinning. هذا ليس عيبًا افتراضيًا لخدمات Firebase/Google/Apple ذات الشهادات المتغيرة؛ ATS والثقة النظامية أنسب. إذا أضيف backend مملوك للتطبيق، قيّم pinning مع خطة rotation وbackup pins.
- لا توجد استثناءات ATS في الكود أو workflow، لكن مجلد iOS يولد وقت CI؛ افحص `Info.plist` النهائي في Archive قبل App Store للتأكد من غياب `NSAllowsArbitraryLoads`.
- يجب وضع حدود bytes لاستجابات الكتالوج والذكاء الاصطناعي قبل `jsonDecode`.

### Firebase وFirestore

- قواعد المصدر جيدة: owner-only، `hasOnly`، حجم 850000، schemaVersion 1، وserver timestamp.
- القواعد الافتراضية تمنع المسارات الأخرى لعدم وجود allow أوسع.
- لا يمكن للمراجعة الساكنة إثبات أن هذه القواعد هي المنشورة فعليًا أو أن App Check مفروض.
- Firebase API key ليس كلمة مرور ولا يمنح قراءة Firestore وحده؛ الأمان يعتمد على Auth + Rules + App Check + API restrictions.

### الأسرار والإعدادات

- فحص الملفات المتتبعة لم يجد Google/GitHub/OpenAI/Groq private tokens أو private keys.
- `firebase_options.dart` و`GoogleService-Info.plist` متجاهلان حاليًا ويعادان من Actions Secrets، لكن إعداد Firebase سيظل داخل IPA وهذا طبيعي.
- مفتاح AI الخاص بالمستخدم سر فعلي ويجب أن يبقى في Keychain فقط؛ لا تخلطه بمفتاح Firebase العام.

### المدخلات والبريد

- مزود IMAP مختار من قائمة ثابتة، وليس host حرًا من المستخدم، وسجلات IMAP معطلة.
- كلمة مرور التطبيق لا تحفظ، وcontroller يمسح في `finally` (`email_link_screen.dart:79-140`). لا يمكن ضمان تصفير String من ذاكرة Dart، لذلك الأفضل إبقاء عمرها قصيرًا كما هو.
- كل رسالة تقص إلى 3000 حرف وعدد الرسائل الافتراضي 80، وهذا حد جيد.
- تحليل AI للاستيراد يقص إلى 60000 حرف ويطلب موافقة، لكن النص المحلي/clipboard غير محدود قبل التحليل.
- مخرجات AI تتحقق من النوع والتصنيف والعملات والسعر، وهو دفاع جيد ضد مخرجات نموذج غير منضبطة.

### الاعتماديات

- `http ^1.2.0` ليس ضمن ثغرة header injection القديمة التي أثرت على إصدارات قبل 0.13.3.
- OSV أظهر advisory منخفضًا لـ`shared_preferences_android` 2.3.3 وقد أصلح في 2.3.4؛ التطبيق iOS أساسًا، والحل الحالي في CI يبدو أحدث، لكن lockfile مطلوب لإثبات النسخة التعدية.
- وقت بناء CI حُل `flutter_local_notifications` إلى 19.5.0، و`local_auth` إلى 2.3.0، و`timezone` إلى 0.10.1؛ توجد إصدارات رئيسية أحدث لكنها تتطلب Dart/Flutter أحدث. القِدم وحده ليس ثغرة مثبتة.
- لم تظهر في OSV مطابقة مؤكدة لحزم التطبيق المباشرة الحالية بتاريخ المراجعة؛ هذه ليست ضمانًا دون SBOM وlockfile وفحص دوري.

### سلسلة البناء

- الصلاحيات read-only و`persist-credentials: false` جيدان.
- لا تمرر الأسرار داخل shell interpolation؛ ضع Base64 secrets في `env` ثم اقرأ المتغير، وفق إرشادات GitHub.
- ثبّت `actions/checkout`, `upload-artifact`, و`subosito/flutter-action` على SHA كامل، مع Dependabot لتحديثها.
- اجعل workflow الاختبارات منفصلًا عن workflow توقيع App Store المحمي بمراجعين وبيئة Release.
- التعمية ليست آلية حماية أسرار؛ كل إعداد مطلوب للتشغيل يمكن استخراجه من العميل.

### الخصوصية والامتثال

- يلزم Privacy Policy قبل النشر، مع جدول: محلي، Firestore، مزود AI المختار، IMAP، Apple iTunes، Google favicon، والإشعارات.
- يلزم تحديث App Store Privacy Labels وفق التدفقات الفعلية.
- الاستيراد بالذكاء الاصطناعي لديه موافقة فورية جيدة، لكن النص يقول Gemini حتى عند اختيار Groq/OpenAI/DeepSeek؛ اعرض المزود الفعلي.
- المستشار الذكي يحتاج موافقة مماثلة؛ الضغط على أيقونة "تحليل" وحده لا يشرح الحقول المرسلة.

## 5. فحوص لوحة التحكم المطلوبة

هذه البنود لا يمكن إثباتها من الكود:

1. **Firebase App Check**
   - تأكد من تسجيل تطبيق iOS ذي bundle `com.basil.ishtirakati` مع App Attest.
   - راقب valid/invalid/missing tokens بعد توزيع نسخة TestFlight.
   - افرض App Check على Cloud Firestore وFirebase Authentication بعد التأكد من عدم حجب المستخدمين الشرعيين.
   - راجع TTL؛ القيمة الافتراضية مناسبة غالبًا، ولا تقللها دون قياس أثر الأداء والحصة.

2. **Google Cloud API key**
   - Application restriction: iOS app وباندل `com.basil.ishtirakati`.
   - API restrictions: Firebase APIs اللازمة فقط.
   - لا تسمح لـGenerative Language API على مفتاح Firebase؛ مفاتيح AI تخص المستخدم ومزوده.
   - راجع Metrics/Quotas والطلبات منذ ظهور القيمة تاريخيًا، ودوّرها إذا لم تُدوّر أو ظهر استخدام غير مبرر.

3. **Firestore Rules**
   - انشر الملف الحالي نفسه وتحقق من Rules timestamp/version في اللوحة.
   - اختبر emulator: owner read/write/delete، منع مستخدم آخر، حقول زائدة، حجم زائد، schema خاطئ، وtimestamp عميل.
   - راجع IAM؛ Admin SDK يتجاوز Rules، لذلك قلل حسابات الخدمة والصلاحيات.

4. **Firebase Authentication**
   - فعّل Google وApple فقط إذا كانا مستخدمين.
   - راجع Authorized domains وOAuth clients، واحذف العملاء القديمة.
   - تحقق من Apple key/service ID/redirect configuration وخطة token revocation عند حذف الحساب.

5. **GitHub**
   - أغلق secret scanning alert فقط بعد التحقق من القيود/التدوير.
   - فعّل branch protection، مراجعة workflow، Dependabot، code scanning، وfull-SHA action policy إن أمكن.
   - اجعل Release environment محميًا ولا تمنح أسرار توقيع Apple لمسار push عادي.

6. **App Store Connect**
   - Privacy Policy URL، App Privacy Labels، خيار حذف الحساب، ووصف استخدام Face ID.
   - اختبر Archive النهائي وتوقيعه وentitlements وPrivacyInfo.xcprivacy، لا IPA غير الموقع فقط.

## 6. خطة التصلّب مرتبة بالأولوية

### يجب قبل الإصدار العام

1. إصلاح AUD-01 بترحيل Keychain آمن واختبارات منع فقدان البيانات.
2. إضافة حذف الحساب والسحابة وإعادة المصادقة وإلغاء Apple token.
3. نشر سياسة الخصوصية وإضافة موافقة AI للمستشار وتحديث الإفصاحات.
4. معالجة AUD-05 حتى لا تكتب الحالة الفارغة فوق سجل تعذر فكّه.
5. إثبات App Check/API restrictions/Firestore Rules من اللوحات.
6. ✅ التزم `pubspec.lock` وثبّت Flutter وGitHub Actions؛ يبقى مسار App Store الموقع فحص إطلاق تشغيليًا.

### ينبغي في أول تحديث أمني

1. توقيع الكتالوج البعيد وفصل allowlist النطاقات عنه.
2. فرض HTTPS مركزيًا لكل `manageUrl` وقت الاستيراد والفتح.
3. حدود bytes/records لكل مدخل واستجابة شبكة.
4. ✅ ثُبّت Flutter وActions بـSHA؛ أضف SBOM وartifact attestation كتصلّب لاحق.
5. اختبارات Firestore emulator واختبارات codec/Keychain/fail-closed.

### تحسين دفاعي مستقبلي

1. مزامنة E2E اختيارية بعبارة استرداد وKDF قوي وenvelope versioned.
2. نمط إشعارات خاص لا يعرض الخدمة أو المبلغ على شاشة القفل.
3. شعارات محلية وخيار منع جلب الصور الخارجية.
4. تليمترية أخطاء اختيارية، قليلة البيانات، بلا مفاتيح أو محتوى اشتراكات.
5. مراجعة MASVS دورية لكل إصدار رئيسي مع فحص Archive النهائي على جهاز غير مكسور الحماية.

## 7. حدود المراجعة

- لم تُراجع حالة Firebase/Google/Apple/GitHub Consoles مباشرة.
- لم يُجر اختبار runtime على جهاز فعلي أو جهاز مكسور الحماية.
- لم يُجر اعتراض حركة أو certificate testing أو fuzzing أو استغلال.
- مجلد iOS مولد في CI وغير متتبع، لذلك يلزم فحص Archive النهائي للـATS وentitlements وprivacy manifest والتوقيع.
- لا يمكن ضمان عدم وجود ثغرة في اعتماديات تعدية مستقبلية دون lockfile وSBOM وفحص مستمر.

## 8. مراجع موثوقة

- Firebase App Check for Flutter: https://firebase.google.com/docs/app-check/flutter/default-providers
- Firebase API keys: https://firebase.google.com/docs/projects/api-keys
- Firestore Rules conditions: https://firebase.google.com/docs/firestore/security/rules-conditions
- Apple Keychain accessibility: https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility
- Apple account deletion: https://developer.apple.com/support/offering-account-deletion-in-your-app
- GitHub Actions SHA pinning: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
- GitHub artifact attestations: https://docs.github.com/en/actions/concepts/security/artifact-attestations
- OSV Pub advisories: https://osv.dev/list?ecosystem=Pub

## 9. قرار التدقيق

**القرار: مشروط قبل الإنتاج العام.** البنية الأساسية للمصادقة والقواعد والتعمية جيدة، ولا يوجد fail-open معروف في قفل التطبيق أو Firebase Auth. لكن لا ينبغي وصف التشفير المحلي بأنه Keychain-only ما دامت المرايا موجودة، ولا ينبغي تقديم النسخة إلى App Store قبل حذف الحساب، إفصاحات الخصوصية، معالجة سلامة التخزين، وفحوص اللوحات وسلسلة الإصدار.
