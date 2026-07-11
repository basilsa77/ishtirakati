/// المزامنة السحابية: نسخة من بياناتك في مستند خاص بحسابك في Firestore،
/// محمي بقواعد أمان تمنع أي مستخدم آخر من قراءته.
/// محلي أولًا: التطبيق يعمل كاملًا بدون تسجيل دخول.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'subscription_store.dart';

enum CloudSyncPhase { idle, syncing, success, failure }

class CloudSyncStatus {
  final CloudSyncPhase phase;
  final DateTime? updatedAt;

  const CloudSyncStatus(this.phase, {this.updatedAt});
}

class CloudSync {
  CloudSync._();

  static bool _pushQueued = false;
  static const _schemaVersion = 1;
  static const _maxBackupBytes = 850000;
  static const _networkTimeout = Duration(seconds: 10);
  static final ValueNotifier<CloudSyncStatus> status =
      ValueNotifier(const CloudSyncStatus(CloudSyncPhase.idle));

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  /// رفع نسخة كاملة من البيانات إلى حساب المستخدم.
  static Future<bool> push() async {
    final doc = _doc();
    if (doc == null || !SubscriptionStore.instance.storageHealthy) {
      status.value = const CloudSyncStatus(CloudSyncPhase.failure);
      return false;
    }
    status.value = const CloudSyncStatus(CloudSyncPhase.syncing);
    try {
      final backup = SubscriptionStore.instance.exportJson();
      if (utf8.encode(backup).length > _maxBackupBytes) {
        status.value = const CloudSyncStatus(CloudSyncPhase.failure);
        return false;
      }
      await doc
          .set({
            'backup': backup,
            'updatedAt': FieldValue.serverTimestamp(),
            'schemaVersion': _schemaVersion,
          })
          .timeout(_networkTimeout);
      status.value = CloudSyncStatus(
        CloudSyncPhase.success,
        updatedAt: DateTime.now(),
      );
      return true;
    } catch (_) {
      status.value = const CloudSyncStatus(CloudSyncPhase.failure);
      return false;
    }
  }

  /// جلب النسخة السحابية ودمجها مع المحلي.
  /// يعيد عدد العناصر المستوردة، -1 إن لم توجد نسخة أو فشل الجلب.
  static Future<int> pull() async {
    final doc = _doc();
    if (doc == null) {
      status.value = const CloudSyncStatus(CloudSyncPhase.failure);
      return -1;
    }
    status.value = const CloudSyncStatus(CloudSyncPhase.syncing);
    try {
      final snap = await doc.get().timeout(_networkTimeout);
      final data = snap.data();
      final raw = data?['backup'] as String?;
      final schemaVersion = data?['schemaVersion'];
      if (raw == null || raw.isEmpty ||
          (schemaVersion != null && schemaVersion != _schemaVersion) ||
          utf8.encode(raw).length > _maxBackupBytes) {
        status.value = const CloudSyncStatus(CloudSyncPhase.failure);
        return -1;
      }
      final count = await SubscriptionStore.instance.importJson(raw);
      status.value = CloudSyncStatus(
        count >= 0 ? CloudSyncPhase.success : CloudSyncPhase.failure,
        updatedAt: count >= 0 ? DateTime.now() : null,
      );
      return count;
    } catch (_) {
      status.value = const CloudSyncStatus(CloudSyncPhase.failure);
      return -1;
    }
  }

  /// Restores a backup before uploading the latest local state.
  static Future<void> restoreAndPush() async {
    final doc = _doc();
    if (doc == null) return;
    try {
      final exists = (await doc.get().timeout(_networkTimeout)).exists;
      if (!exists) {
        await push();
        return;
      }
      final restored = await pull();
      if (restored >= 0) await push();
    } catch (_) {
      status.value = const CloudSyncStatus(CloudSyncPhase.failure);
    }
  }

  /// حذف النسخة الخاصة بالمستخدم قبل حذف حساب المصادقة.
  static Future<void> deleteRemoteData() async {
    final doc = _doc();
    if (doc == null) throw StateError('No authenticated cloud document.');
    await doc.delete().timeout(_networkTimeout);
    status.value = const CloudSyncStatus(CloudSyncPhase.idle);
  }

  /// رفع مؤجل بعد كل تعديل (يجمع التعديلات المتتابعة في رفعة واحدة).
  static void schedulePush() {
    if (!AuthService.isSignedIn ||
        !SubscriptionStore.instance.storageHealthy ||
        _pushQueued) {
      return;
    }
    _pushQueued = true;
    Future.delayed(const Duration(seconds: 4), () async {
      _pushQueued = false;
      await push();
    });
  }
}
