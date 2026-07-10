/// المزامنة السحابية: نسخة من بياناتك في مستند خاص بحسابك في Firestore،
/// محمي بقواعد أمان تمنع أي مستخدم آخر من قراءته.
/// محلي أولًا: التطبيق يعمل كاملًا بدون تسجيل دخول.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'subscription_store.dart';

class CloudSync {
  CloudSync._();

  static bool _pushQueued = false;
  static const _schemaVersion = 1;
  static const _maxBackupBytes = 850000;
  static const _networkTimeout = Duration(seconds: 10);

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  /// رفع نسخة كاملة من البيانات إلى حساب المستخدم.
  static Future<bool> push() async {
    final doc = _doc();
    if (doc == null) return false;
    try {
      final backup = SubscriptionStore.instance.exportJson();
      if (utf8.encode(backup).length > _maxBackupBytes) return false;
      await doc
          .set({
            'backup': backup,
            'updatedAt': FieldValue.serverTimestamp(),
            'schemaVersion': _schemaVersion,
          })
          .timeout(_networkTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// جلب النسخة السحابية ودمجها مع المحلي.
  /// يعيد عدد العناصر المستوردة، -1 إن لم توجد نسخة أو فشل الجلب.
  static Future<int> pull() async {
    final doc = _doc();
    if (doc == null) return -1;
    try {
      final snap = await doc.get().timeout(_networkTimeout);
      final data = snap.data();
      final raw = data?['backup'] as String?;
      final schemaVersion = data?['schemaVersion'];
      if (raw == null || raw.isEmpty ||
          (schemaVersion != null && schemaVersion != _schemaVersion) ||
          utf8.encode(raw).length > _maxBackupBytes) {
        return -1;
      }
      return await SubscriptionStore.instance.importJson(raw);
    } catch (_) {
      return -1;
    }
  }

  /// Restores a backup before uploading the latest local state.
  static Future<void> restoreAndPush() async {
    await pull();
    await push();
  }

  /// رفع مؤجل بعد كل تعديل (يجمع التعديلات المتتابعة في رفعة واحدة).
  static void schedulePush() {
    if (!AuthService.isSignedIn || _pushQueued) return;
    _pushQueued = true;
    Future.delayed(const Duration(seconds: 4), () async {
      _pushQueued = false;
      await push();
    });
  }
}
