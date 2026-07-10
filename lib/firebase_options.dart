/// إعدادات Firebase لتطبيق iOS.
/// إعدادات Google Sign-In الأصلية تُقرأ من GoogleService-Info.plist عند البناء.
library;

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const String _apiKey = 'AIzaSyCWNBF8qpubKZuztexWSxc8JW2ewUWAt60';
  static const String _appId = '1:49076094328:ios:5d299c3b8960ef52fc748d';
  static const String _messagingSenderId = '49076094328';
  static const String _projectId = 'ishtirakati-260f7';
  static const String _iosBundleId = 'com.basil.ishtirakati';

  /// هل أُكمل الإعداد؟
  static bool get isConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform => ios;

  static FirebaseOptions get ios => const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: 'ishtirakati-260f7.firebasestorage.app',
        iosBundleId: _iosBundleId,
      );
}
