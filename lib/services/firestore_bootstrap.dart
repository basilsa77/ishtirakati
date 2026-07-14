import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_build_config.dart';

/// Applies Firestore settings once, immediately after Firebase initialization.
class FirestoreBootstrap {
  FirestoreBootstrap._();

  static bool _configured = false;

  static bool get configured => _configured;

  static void configure() {
    if (_configured) return;
    if (FirebaseBuildConfig.offlineQueueEnabled) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
    _configured = true;
  }
}
