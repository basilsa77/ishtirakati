/// خدمة تسجيل الدخول: Google (يعمل مع التوقيع المجاني)
/// وApple (يتطلب حساب مطور مدفوع — جاهز للتفعيل).
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
  static final ValueNotifier<String?> appCheckWarning = ValueNotifier(null);

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
          providerApple: const AppleAppAttestProvider(),
        );
        appCheckWarning.value = null;
      } catch (error) {
        const message =
            'تعذر تفعيل App Check. المزامنة محمية بالمصادقة والقواعد، '
            'لكن يلزم مراجعة App Attest قبل النشر.';
        appCheckWarning.value = message;
        debugPrint(
          'App Check activation failed (${error.runtimeType}). '
          'Enable enforcement from Firebase Console after monitoring.',
        );
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
      final credential = await _googleCredential(account);
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
      final credential = await _appleCredential();
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
    } catch (_) {
      throw const AuthException(
        'تعذر تسجيل الخروج بأمان. تحقق من الاتصال وأعد المحاولة.',
      );
    }
  }

  static Future<void> reauthenticateCurrentUser() async {
    final user = currentUser;
    if (user == null) throw const AuthException('لا يوجد حساب مسجل لحذفه.');
    final providers = user.providerData.map((item) => item.providerId).toSet();
    try {
      if (providers.contains('google.com')) {
        if (!_googleInitialized) {
          throw const AuthException('تعذر تهيئة إعادة المصادقة بقوقل.');
        }
        await GoogleSignIn.instance.signOut();
        final account = await GoogleSignIn.instance.authenticate();
        await user.reauthenticateWithCredential(await _googleCredential(account));
        return;
      }
      if (providers.contains('apple.com')) {
        await user.reauthenticateWithCredential(await _appleCredential());
        return;
      }
      await user.reload();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException('تعذرت إعادة المصادقة: ${error.code}');
    } catch (_) {
      throw const AuthException('أُلغيت إعادة المصادقة أو تعذرت.');
    }
  }

  static Future<void> deleteCurrentUser() async {
    final user = currentUser;
    if (user == null) throw const AuthException('لا يوجد حساب مسجل لحذفه.');
    try {
      await user.delete();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const AuthException('يلزم تأكيد هويتك مجددًا قبل حذف الحساب.');
      }
      throw AuthException('تعذر حذف الحساب: ${error.code}');
    }
  }

  static Future<OAuthCredential> _googleCredential(
    GoogleSignInAccount account,
  ) async {
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('لم يصل رمز مصادقة صالح من Google.');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  static Future<OAuthCredential> _appleCredential() async {
    final rawNonce = _newNonce();
    final hashedNonce = await _sha256(rawNonce);
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final identityToken = apple.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const AuthException('لم يصل رمز مصادقة صالح من Apple.');
    }
    return OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
    );
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
