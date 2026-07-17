# تقرير تنفيذ اشتراكاتي v16.0.0

التاريخ: 2026-07-18
خط الأساس: `main` عند `a20e6d1`، الإصدار `15.3.1+43`
هدف الإصدار: `16.0.0+44`

## 1) نقاط التطوير الأعلى أثرًا

### (أ) ما يمنع الإطلاق

1. **التعارض السحابي لا يملك دلالة حذف أو دمج آمن — L**
   - **الأثر:** كان `syncNow()` ينفذ pull ثم push تلقائيًا عند تعارض revision. ولأن النسخة المشفرة لا تحمل tombstones أو `updatedAt` لكل سجل، فقد يعيد ذلك اشتراكًا حُذف على جهاز آخر أو يستبدل تعديلًا محليًا لنفس `id` بصمت.
   - **الملفات:** `lib/services/cloud_sync.dart`، `lib/services/subscription_store.dart`، `lib/models/subscription.dart`، `test/cloud_sync_revision_test.dart`.
   - **ما دُمج في v16:** أصبح التعارض fail-closed؛ لا يلمس النسخة المحلية أو السحابية ولا ينفذ دمجًا أعمى.
   - **المتبقي:** تصميم resolver صريح بعد اعتماد tombstones أو metadata لكل سجل داخل الحمولة المشفرة. لا يتطلب ذلك إرخاء قواعد Firestore، ولا يجوز إخفاؤه بإعادة المحاولة.

2. **الأقساط والسعر التاريخي غير صحيحين في التقويم والإجماليات — M**
   - **الأثر:** كان عدد الدفعات يستمر بعد آخر قسط، وكان الماضي يُعاد تسعيره بالسعر الحالي؛ لذلك تظهر أقساط مستقبلية وهمية وتتغير إجماليات الأشهر القديمة بعد تعديل السعر.
   - **الملفات:** `lib/models/subscription.dart`، `lib/services/subscription_store.dart`، `lib/screens/calendar_screen.dart`، `test/subscription_test.dart`، `test/v5_features_test.dart`.
   - **ما دُمج في v16:** سقف الأقساط، إيقاف التجديد بعد تاريخ القسط الأخير، `priceAt(date)`، `spendingInMonth()`، وإبقاء القسط المكتمل ظاهرًا في شهره التاريخي فقط.

3. **مسار مزامنة build 43 غير مثبت على جهاز حقيقي — M**
   - **الأثر:** الاختبارات تثبت القواعد والمنطق، لكنها لا تثبت REST-first/native transport وoffline queue وreauth على iPhone حقيقي.
   - **الملفات:** `V15_FIREBASE_SYNC_CHECKLIST.md`، `lib/services/cloud_sync.dart`، `lib/services/firestore_rest_fallback.dart`، `.github/workflows/build-ipa.yml`.
   - **المتبقي:** تنفيذ مصفوفة create/update/conflict/offline/delete على جهازين بالمفتاح نفسه حيث ينطبق، وتسجيل النتيجة دون UID أو token أو payload.

4. **لا يوجد artifact موقّع صالح لـTestFlight/App Store — L**
   - **الأثر:** CI ينتج IPA غير موقع فقط؛ لا يوجد Archive موقّع أو تحقق App Store نهائي من entitlements وPrivacy Manifest وApp Check enforcement.
   - **الملفات:** `.github/workflows/build-ipa.yml`، `FIREBASE_CI_SETUP.md`، `SECURITY_AUDIT.md`.
   - **المتبقي:** مسار توزيع محمي أو Archive يدوي موثق، App Attest/DeviceCheck في build التوزيع، capability لتسجيل Apple، وفحص TestFlight.

### (ب) ما يرفع قيمة المنتج

5. **هوية v16 موحدة لكل التدفقات — L**
   - **الأثر:** الأسماء والقيم كانت موزعة بين `V12*` و`V15Type` وأنصاف أقطار محلية، ما سبب اختلافًا بين البطاقات والحقول والتنقل والرسوم.
   - **الملفات:** `lib/design/design_tokens.dart`، `lib/theme.dart`، `lib/widgets/ios_controls.dart`، `lib/widgets/adaptive_cycle_shell.dart`، وشاشات `lib/screens/` النشطة.
   - **ما دُمج في v16:** مصدر واحد للألوان والنوع والمسافة والحواف والظل والحركة، مع طبقة توافق لا تكسر الاختبارات التاريخية، ومكوّنات موحدة وحالات فراغ وحركة تراعي Reduce Motion.

6. **النسخة المشفرة لا تُستعاد على جهاز جديد دون المفتاح الأصلي — L**
   - **الأثر:** Keychain-only يمنع رفع مفتاح AES بجانب ciphertext، وهذا صحيح أمنيًا، لكنه يعني أن Firebase وحده ليس استعادة عابرة للأجهزة.
   - **الملفات:** `lib/services/secure_data_codec.dart`، `lib/services/cloud_sync.dart`، `lib/screens/login_screen.dart`، `lib/screens/settings_screen.dart`.
   - **المتبقي:** إما ضبط الإفصاح بدقة، أو تصميم recovery phrase/passphrase مع KDF وwrapped key وتهديدات واختبارات مستقلة. لا يُرفع مفتاح AES الخام مطلقًا.

### (ج) صيانة وأداء

7. **ملفات كبيرة وشاشات تاريخية غير مستخدمة — M**
   - **الأثر:** `cloud_sync.dart` و`settings_screen.dart` نقطتا تغيير كبيرتان، بينما `command_center_screen.dart` و`dashboard_screen.dart` غير موصولتين بالتنقل الحالي.
   - **الملفات:** الملفات السابقة، `lib/services/financial_assistant.dart`، وشاشات النبض/التحليلات/المراجعة.
   - **المتبقي:** فصل transport/state/diagnostics، حذف الشاشات الميتة بعد تحقق المراجع، وكاش للتحليل مشتق من revision محلي.

8. **حدود الاستجابات واختبارات الإصدار والواجهة غير مكتملة — M**
   - **الأثر:** بعض HTTP responses ومدخلات اللصق لا تملك حد bytes مبكرًا، واختبار الإصدار القديم لا يحرس أسماء artifacts والوثائق.
   - **الملفات:** `lib/services/update_checker.dart`، `lib/services/itunes_search.dart`، `lib/services/ai_extractor.dart`، `lib/screens/import_screen.dart`، `test/version_sync_test.dart`.
   - **ما دُمج في v16:** حد 16KiB لملف الإصدار قبل فك ترميزه، وحارس يزامن pubspec والثوابت وREADME وCHANGELOG وworkflow ودليل IPA.
   - **المتبقي:** حدود مماثلة لكل endpoint ومدخل، واختبارات golden/semantics ومصفوفة RTL/LTR × light/dark × phone/iPad.

## 2) الاتجاهات البصرية

### الاتجاه الأول: «مرسى» — دفتر مالي خليجي هادئ

- **اللغة:** لؤلؤ دافئ، أخضر بحري، رمل محدود، أسطح واضحة وحدود دقيقة.
- **الإيقاع:** قاعدة 4pt، هوامش هاتف 16–20pt، وفواصل أقسام 24–32pt.
- **المزايا:** ثقة وخصوصية وراحة بصرية نهارًا، ارتباط خليجي معاصر دون زخرفة حرفية، واستمرار ناضج للأخضر الحالي.
- **العيوب:** يحتاج رسومًا وحركة دقيقة حتى لا يبدو محافظًا أكثر من اللازم.

### الاتجاه الثاني: «سدرة ليلية» — فخامة رقمية داكنة

- **اللغة:** كحلي شبه أسود، يشم مضيء، زعفران، وطبقات شبه زجاجية.
- **الإيقاع:** كثافة أعلى ومسافات 12–20pt ورسوم كبيرة.
- **المزايا:** حضور تسويقي قوي وشخصية تقنية واضحة.
- **العيوب:** قريب من تطبيقات التداول، أقل راحة تحت الضوء الخليجي، blur أكبر ومخاطر تباين وأداء أعلى.

### الاتجاه الثالث: «لؤلؤة رقمية» — iOS مضيء وتقني

- **اللغة:** أبيض لؤلؤي، كوبالت وفيروزي، مساحات واسعة ووحدات مسطحة.
- **الإيقاع:** قاعدة 8pt وبطاقات كبيرة قليلة.
- **المزايا:** ودود وحديث وممتاز للتعريف والتحليلات.
- **العيوب:** أقرب لهويات البنوك والاتصالات وأقل تميزًا ودفئًا.

### الاختيار: «مرسى / Gulf Aurora»

المنتج يبيع راحة البال وفهم الالتزامات، لا الاندفاع أو التداول. لذلك يجمع «مرسى» الثقة المالية والخصوصية مع حس خليجي معاصر، ويحافظ على فصل brand/success/warning/danger. الاسم الداخلي للتوكنز هو **Gulf Aurora**، بينما اللغة الموجهة للمنتج هي **مرسى**.

## 3) نظام التصميم v16

### Palette

| Token | Light | Dark | الاستخدام |
|---|---:|---:|---|
| canvas | `#F7F8F4` | `#071410` | خلفية التطبيق |
| surface | `#FFFFFF` | `#0E211B` | البطاقات والقوائم |
| surfaceMuted | `#EEF3EF` | `#162D26` | مجموعات وحقول هادئة |
| surfaceElevated | `#FBFCFA` | `#19352C` | sheets والعناصر المرتفعة |
| stroke | `#D9E3DD` | `#2B443B` | الحدود والفواصل |
| text | `#10231F` | `#F3F8F5` | النص الأساسي |
| textMuted | `#63736D` | `#A7BBB3` | النص الثانوي |
| brandBase | `#007F6D` | `#63DDBB` | العلامة والرسوم |
| brandText | `#00594D` | `#63DDBB` | التفاعل والنص فوق السطح الهادئ |
| brandStrong | `#00594D` | `#007F6D` | الأزرار والـhero |
| brandSoft | `#DDF5EC` | `#173E33` | خلفية اختيار |
| warning | `#76510D` | `#F0C76D` | تجديد قريب وqueued |
| danger | `#9F3044` | `#FF909B` | خطأ وحذف |
| info | `#2C6781` | `#81CAE7` | معلومة وتشخيص |

Hero light: `#004E44 → #007F6D → #0F806E`.
Hero dark: `#0A2A23 → #075E50 → #0B806B`.

### Type scale

العائلة الوحيدة `IBM Plex Sans Arabic` للعربية واللاتينية. الأصول المضمّنة 400 و600، لذلك التوكنز الرسمية `regular/semibold` فقط ولا تعتمد الهوية الجديدة على وزن مصطنع.

| Token | pt | height |
|---|---:|---:|
| display | 44 | 1.22 |
| displaySmall | 36 | 1.22 |
| headline | 28 | 1.30 |
| headlineSmall | 24 | 1.30 |
| title | 20 | 1.40 |
| titleSmall | 18 | 1.40 |
| body | 16 | 1.55 |
| bodySmall | 15 | 1.55 |
| label | 14 | 1.45 |
| labelSmall | 13 | 1.45 |
| caption | 12 | 1.45 |
| captionSmall | 10 | 1.45 |

كل `fontSize` في الشاشات يأتي من token؛ الاختبار يمنع الحجم الرقمي الحرفي.

### Spacing / radius / elevation

- Spacing: `4, 8, 12, 16, 20, 24, 32, 48, 64`.
- Radius: `8 compact`, `16 standard`, `24 signature`, `30 hero`, `999 pill`.
- Elevation: flat، low (`blur 18 / y 6`)، medium (`blur 30 / y 12`)؛ في dark يعتمد الفصل على السطح والحد أكثر من الظل.
- الحد الأدنى العملي للمس 44pt، والحواف الاتجاهية تستخدم `EdgeInsetsDirectional` عند اختلاف RTL/LTR.

### Motion

- instant 120ms، quick 220ms، entrance 420ms، money 760ms.
- المنحنى الأساسي `easeOutCubic`.
- `disableAnimations` يلغي count-up وslide ويعرض الحالة النهائية.
- haptic selection للتبويب والاختيار فقط؛ لا اهتزاز متكرر أثناء الرسم.

### المكونات

- `AppCard`: standard/muted/accent/warning/danger، حد وظل موحد، semantics وpressed opacity للنسخة التفاعلية.
- `RenewalBadge`: نص + نقطة دلالية، danger لليوم/المتأخر، warning للأسبوع، brand لما بعده.
- `AnimatedMoney`: صياغة محلية، semantics للقيمة النهائية، وفصل currency وعدم الحركة عند Reduce Motion.
- `AppChartSurface`: عنوان ووصف وملخص لقارئ الشاشة وlegend موحد، مع بقاء painter محليًا ودون package جديدة.
- `AppPageIntro`: header يعيد التدفق عند الهاتف الصغير أو النص الكبير.
- `AppEmptyState`: حالة فارغة موحدة مع CTA اختياري.
- `AppMetricTile`: قيمة ومؤشر بلون دلالي داخل بطاقة موحدة.
- `IosStatusNotice`: info/success/queued/error؛ queued لا يظهر كنجاح مؤكد.
- `AdaptiveCycleShell`: tab bar عائم لؤلؤي مع الحفاظ على `CupertinoTabBar` والمفاتيح، وrail بطبقة موحدة على iPad.

## 4) ضمانات لم تتغير

- AES-256-GCM والمفتاح ذو 32 بايت من Keychain فقط، nonce جديد، وفشل التخزين مغلق.
- مستند Firestore الواحد لا يزال ciphertext فقط بالحقول الخمسة، revision create=1 وupdate=stored+1.
- offline queue لا يساوي server-confirmed success.
- لا تسجيل UID أو tokens أو keys أو plaintext/ciphertext payload.
- حذف الحساب يبقى Firestore ثم Firebase user ثم local بعد إعادة المصادقة.
- BYOK consent وHTTPS-only والإشعارات الخاصة وفصل العملات وmonth-end باقية.
- لا تغيير native محلي؛ توليد iOS 15 وإعداداته ما زال داخل workflow.

## 5) حالة التحقق

نُفذت البوابة على Windows باستخدام Flutter `3.44.6` / Dart `3.12.2` الرسميين وحاصل SHA-256 المنشور للحزمة:

- `flutter pub get --enforce-lockfile`: ناجح؛ لم يتغير `pubspec.lock`.
- `flutter analyze lib test`: ناجح، `No issues found`.
- `flutter test`: ناجح، **154/154**.
- `npm ci --ignore-scripts`: ناجح؛ أبلغ npm عن 5 ثغرات متوسطة في شجرة أدوات التطوير ولم يُستخدم `audit fix --force` لأنه قد يكسر القفل.
- `npm run test:rules`: ناجح على Firestore Emulator؛ create revision 1، transaction update revision 2، ciphertext enforced، والكتابات المرفوضة لم تغيّر revision 2.
- `git diff --check`: ناجح، ولا توجد أحجام `fontSize` رقمية أو أوزان مصطنعة في الشاشات النشطة المهاجرة.

لم يُنفذ Archive/IPA محليًا لأن بناء iOS يتطلب macOS ويولّده workflow. ما زالت مصفوفة الجهاز الحقيقي وTestFlight وApp Check enforcement بنود إطلاق خارجية موثقة في `V16_RELEASE_CHECKLIST.md`.
