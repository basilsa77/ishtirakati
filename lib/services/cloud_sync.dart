/// المزامنة السحابية: نسخة من بياناتك في مستند خاص بحسابك في Firestore،
/// محمي بقواعد أمان تمنع أي مستخدم آخر من قراءته.
/// محلي أولًا: التطبيق يعمل كاملًا بدون تسجيل دخول.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'subscription_store.dart';

enum CloudSyncPhase { idle, syncing, success, failure }

enum CloudSyncFailure {
  none,
  unauthenticated,
  storageLocked,
  payloadTooLarge,
  invalidBackup,
  timeout,
  offline,
  permissionDenied,
  unknown,
}

class CloudSyncStatus {
  final CloudSyncPhase phase;
  final DateTime? updatedAt;
  final CloudSyncFailure failure;
  final String? message;

  const CloudSyncStatus(
    this.phase, {
    this.updatedAt,
    this.failure = CloudSyncFailure.none,
    this.message,
  });
}

class CloudSyncResult {
  final bool success;
  final int imported;
  final CloudSyncFailure failure;

  const CloudSyncResult._({
    required this.success,
    this.imported = 0,
    this.failure = CloudSyncFailure.none,
  });

  const CloudSyncResult.success({int imported = 0})
      : this._(success: true, imported: imported);

  const CloudSyncResult.failed(CloudSyncFailure failure)
      : this._(success: false, failure: failure);
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

  static bool _fail(CloudSyncFailure failure, String message) {
    status.value = CloudSyncStatus(
      CloudSyncPhase.failure,
      failure: failure,
      message: message,
    );
    return false;
  }

  @visibleForTesting
  static String messageForFirebaseCode(String code) => switch (code) {
        'permission-denied' =>
          'رفضت Firebase المزامنة. تحقق من تسجيل App Check ونشر قواعد Firestore.',
        'unauthenticated' =>
          'انتهت جلسة الحساب. سجّل الدخول مجددًا ثم أعد المحاولة.',
        'unavailable' || 'network-request-failed' =>
          'لا يمكن الوصول إلى Firebase الآن. تحقق من الإنترنت وأعد المحاولة.',
        'deadline-exceeded' =>
          'استغرقت المزامنة وقتًا طويلًا. حاول مجددًا بعد لحظات.',
        _ => 'تعذرت المزامنة بسبب خطأ من Firebase ($code).',
      };

  static CloudSyncFailure _failureForFirebaseCode(String code) =>
      switch (code) {
        'permission-denied' => CloudSyncFailure.permissionDenied,
        'unauthenticated' => CloudSyncFailure.unauthenticated,
        'unavailable' || 'network-request-failed' => CloudSyncFailure.offline,
        'deadline-exceeded' => CloudSyncFailure.timeout,
        _ => CloudSyncFailure.unknown,
      };

  static bool _failFirebase(FirebaseException error) {
    debugPrint('Cloud sync failed with Firebase code: ${error.code}.');
    return _fail(
      _failureForFirebaseCode(error.code),
      messageForFirebaseCode(error.code),
    );
  }

  /// رفع نسخة كاملة من البيانات إلى حساب المستخدم.
  static Future<bool> push() async {
    final doc = _doc();
    if (doc == null) {
      return _fail(
        CloudSyncFailure.unauthenticated,
        'سجّل الدخول أولًا لتفعيل المزامنة.',
      );
    }
    if (!SubscriptionStore.instance.storageHealthy) {
      return _fail(
        CloudSyncFailure.storageLocked,
        'المزامنة متوقفة لحماية السجل المشفر حتى تنجح استعادته.',
      );
    }
    status.value = const CloudSyncStatus(CloudSyncPhase.syncing);
    try {
      final backup = SubscriptionStore.instance.exportJson();
      if (utf8.encode(backup).length > _maxBackupBytes) {
        return _fail(
          CloudSyncFailure.payloadTooLarge,
          'حجم البيانات أكبر من حد المزامنة السحابية.',
        );
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
    } on TimeoutException {
      return _fail(
        CloudSyncFailure.timeout,
        'استغرقت المزامنة وقتًا طويلًا. حاول مجددًا بعد لحظات.',
      );
    } on FirebaseException catch (error) {
      return _failFirebase(error);
    } catch (error) {
      debugPrint('Cloud push failed (${error.runtimeType}).');
      return _fail(
        CloudSyncFailure.unknown,
        'تعذرت مزامنة البيانات. أعد المحاولة بعد التحقق من الاتصال.',
      );
    }
  }

  /// جلب النسخة السحابية ودمجها مع المحلي.
  /// يعيد عدد العناصر المستوردة، -1 إن لم توجد نسخة أو فشل الجلب.
  static Future<int> pull() async {
    final doc = _doc();
    if (doc == null) {
      _fail(
        CloudSyncFailure.unauthenticated,
        'سجّل الدخول أولًا لاستعادة البيانات.',
      );
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
        _fail(
          CloudSyncFailure.invalidBackup,
          'النسخة السحابية غير صالحة أو من إصدار غير مدعوم، ولم تُستبدل بيانات جهازك.',
        );
        return -1;
      }
      final count = await SubscriptionStore.instance.importJson(raw);
      status.value = CloudSyncStatus(
        count >= 0 ? CloudSyncPhase.success : CloudSyncPhase.failure,
        updatedAt: count >= 0 ? DateTime.now() : null,
      );
      return count;
    } on TimeoutException {
      _fail(
        CloudSyncFailure.timeout,
        'استغرقت الاستعادة وقتًا طويلًا. حاول مجددًا بعد لحظات.',
      );
      return -1;
    } on FirebaseException catch (error) {
      _failFirebase(error);
      return -1;
    } catch (error) {
      debugPrint('Cloud pull failed (${error.runtimeType}).');
      _fail(
        CloudSyncFailure.unknown,
        'تعذرت استعادة النسخة السحابية، ولم تتغير بيانات جهازك.',
      );
      return -1;
    }
  }

  /// Restores a backup before uploading the latest local state.
  static Future<CloudSyncResult> restoreAndPush() async {
    final doc = _doc();
    if (doc == null) {
      _fail(
        CloudSyncFailure.unauthenticated,
        'سجّل الدخول أولًا لتفعيل المزامنة.',
      );
      return const CloudSyncResult.failed(CloudSyncFailure.unauthenticated);
    }
    try {
      final exists = (await doc.get().timeout(_networkTimeout)).exists;
      if (!exists) {
        final uploaded = await push();
        return uploaded
            ? const CloudSyncResult.success()
            : CloudSyncResult.failed(status.value.failure);
      }
      final restored = await pull();
      if (restored < 0) {
        return CloudSyncResult.failed(status.value.failure);
      }
      final uploaded = await push();
      return uploaded
          ? CloudSyncResult.success(imported: restored)
          : CloudSyncResult.failed(status.value.failure);
    } on TimeoutException {
      _fail(
        CloudSyncFailure.timeout,
        'استغرقت المزامنة وقتًا طويلًا. حاول مجددًا بعد لحظات.',
      );
      return const CloudSyncResult.failed(CloudSyncFailure.timeout);
    } on FirebaseException catch (error) {
      _failFirebase(error);
      return CloudSyncResult.failed(status.value.failure);
    } catch (error) {
      debugPrint('Cloud restore failed (${error.runtimeType}).');
      _fail(
        CloudSyncFailure.unknown,
        'تعذرت مزامنة الحساب، ولم تتغير بيانات جهازك.',
      );
      return const CloudSyncResult.failed(CloudSyncFailure.unknown);
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
