/// خدمة تسجيل الدخول: Google (يعمل مع التوقيع المجاني)
/// وApple (يتطلب حساب مطور مدفوع — جاهز للتفعيل).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static bool _initialized = false;

  /// هل المزامنة السحابية متاحة (الإعداد مكتمل والتهيئة نجحت)؟
  static bool get isAvailable =>
      DefaultFirebaseOptions.isConfigured && _initialized;

  static User? get currentUser =>
      isAvailable ? FirebaseAuth.instance.currentUser : null;

  static bool get isSignedIn => currentUser != null;

  static String get userEmail => currentUser?.email ?? '';

  /// تُستدعى عند الإقلاع — آمنة تمامًا إن لم يكتمل الإعداد.
  static Future<void> init() async {
    if (_initialized || !DefaultFirebaseOptions.isConfigured) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<User?> signInWithGoogle() async {
    if (!isAvailable) {
      throw const AuthException('المزامنة السحابية غير مفعّلة بعد.');
    }
    try {
      // The native GoogleService-Info.plist provides the OAuth client on iOS.
      final google = GoogleSignIn();
      final account = await google.signIn();
      if (account == null) return null; // ألغى المستخدم
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException('تعذر تسجيل الدخول: ${e.code}');
    } catch (_) {
      throw const AuthException(
        'تعذر تسجيل الدخول بقوقل. فعّل موفر Google في Firebase، ثم نزّل '
        'ملف GoogleService-Info.plist المحدّث وأعد بناء التطبيق.',
      );
    }
  }

  static Future<User?> signInWithApple() async {
    if (!isAvailable) {
      throw const AuthException('المزامنة السحابية غير مفعّلة بعد.');
    }
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      return result.user;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw const AuthException(
        'دخول Apple يتطلب نشر التطبيق بحساب مطور — '
        'استخدم Google حاليًا.',
      );
    } catch (_) {
      throw const AuthException(
        'دخول Apple غير متاح في النسخة الحالية — استخدم Google.',
      );
    }
  }

  static Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
