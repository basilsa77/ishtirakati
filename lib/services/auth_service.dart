/// خدمة تسجيل الدخول: Google (يعمل مع التوقيع المجاني)
/// وApple (يتطلب حساب مطور مدفوع — جاهز للتفعيل).
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
  static bool _googleInitialized = false;

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
      try {
        await FirebaseAppCheck.instance.activate(
          appleProvider: AppleProvider.appAttest,
        );
      } catch (_) {
        // App Check enforcement is enabled from Firebase Console after monitoring.
      }
      try {
        await GoogleSignIn.instance.initialize();
        _googleInitialized = true;
      } catch (_) {
        _googleInitialized = false;
      }
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<User?> signInWithGoogle() async {
    if (!isAvailable) {
      throw const AuthException('المزامنة السحابية غير مفعّلة بعد.');
    }
    if (!_googleInitialized) {
      throw const AuthException('تعذر تهيئة تسجيل الدخول بقوقل على هذا الجهاز.');
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      if (account == null) return null; // ألغى المستخدم
      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      return result.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null; // ألغى المستخدم
      }
      throw AuthException(
        'تعذر تسجيل الدخول بقوقل (${e.code.name}). '
        '${e.description ?? 'تحقق من إعدادات المشروع في Firebase.'}',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException('تعذر تسجيل الدخول: ${e.code}');
    } catch (error) {
      throw AuthException('تعذر تسجيل الدخول بقوقل: $error');
    }
  }

  static Future<User?> signInWithApple() async {
    if (!isAvailable) {
      throw const AuthException('المزامنة السحابية غير مفعّلة بعد.');
    }
    try {
      final rawNonce = _newNonce();
      final hashedNonce = await _sha256(rawNonce);
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      if (apple.identityToken == null || apple.identityToken!.isEmpty) {
        throw const AuthException('لم يصل رمز مصادقة صالح من Apple.');
      }
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
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
  }

  static String _newNonce([int length = 32]) {
    const alphabet =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  static Future<String> _sha256(String value) async {
    final digest = await Sha256().hash(utf8.encode(value));
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
