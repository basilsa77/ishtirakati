/// حذف الحساب بترتيب يمنع فقدان البيانات المحلية قبل نجاح العمليات البعيدة.
library;

import 'auth_service.dart';
import 'cloud_sync.dart';
import 'subscription_store.dart';

class AccountDeletionCoordinator {
  const AccountDeletionCoordinator._();

  static Future<void> run({
    required Future<void> Function() reauthenticate,
    required Future<void> Function() deleteCloud,
    required Future<void> Function() deleteAccount,
    required Future<void> Function() clearLocal,
  }) async {
    await reauthenticate();
    await deleteCloud();
    await deleteAccount();
    await clearLocal();
  }
}

class AccountDeletionService {
  const AccountDeletionService._();

  static Future<void> deleteEverything() => AccountDeletionCoordinator.run(
    reauthenticate: AuthService.reauthenticateCurrentUser,
    deleteCloud: CloudSync.deleteRemoteData,
    deleteAccount: AuthService.deleteCurrentUser,
    clearLocal: SubscriptionStore.instance.clearLocalForAccountDeletion,
  );
}
