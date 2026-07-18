import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Single source of truth for the production Firestore database target.
class FirestoreConfig {
  FirestoreConfig._();

  static const String databaseId = 'default';

  static FirebaseFirestore get instance => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: databaseId,
  );
}
