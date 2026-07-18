import 'dart:async';
import 'dart:io';

typedef FirebaseTokenProvider = Future<String?> Function(bool forceRefresh);

enum FirebaseRestAppCheckFailure {
  providerUnavailable,
  emptyToken,
  tokenAcquisitionFailed,
}

/// Safe, non-secret-bearing error returned before a REST request is sent.
class FirebaseRestAppCheckException implements Exception {
  final FirebaseRestAppCheckFailure failure;
  final String? causeType;

  const FirebaseRestAppCheckException(this.failure, {this.causeType});

  String get safeType => switch (failure) {
        FirebaseRestAppCheckFailure.providerUnavailable =>
          'MissingFirebaseAppCheckTokenProvider',
        FirebaseRestAppCheckFailure.emptyToken => 'EmptyFirebaseAppCheckToken',
        FirebaseRestAppCheckFailure.tokenAcquisitionFailed =>
          causeType == null
              ? 'FirebaseAppCheckTokenFailure'
              : 'FirebaseAppCheckTokenFailure($causeType)',
      };

  @override
  String toString() => safeType;
}

/// Builds Firebase REST headers and acquires App Check tokens fail-closed.
///
/// The helper deliberately performs no logging and its exceptions contain only
/// failure categories/runtime types, never an ID token or App Check token.
class FirebaseRestAuthHeaders {
  FirebaseRestAuthHeaders._();

  static const appCheckHeader = 'X-Firebase-AppCheck';

  static Future<Map<String, String>> build({
    required String idToken,
    required bool appCheckEnabled,
    FirebaseTokenProvider? appCheckTokenProvider,
    bool includeJsonContentType = false,
    bool forceRefreshAppCheck = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final headers = <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $idToken',
      if (includeJsonContentType)
        HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (!appCheckEnabled) return headers;

    final provider = appCheckTokenProvider;
    if (provider == null) {
      headers.clear();
      throw const FirebaseRestAppCheckException(
        FirebaseRestAppCheckFailure.providerUnavailable,
      );
    }

    String? appCheckToken;
    try {
      appCheckToken =
          await provider(forceRefreshAppCheck).timeout(timeout);
    } catch (error) {
      headers.clear();
      throw FirebaseRestAppCheckException(
        FirebaseRestAppCheckFailure.tokenAcquisitionFailed,
        causeType: error.runtimeType.toString(),
      );
    }
    if (appCheckToken == null || appCheckToken.trim().isEmpty) {
      appCheckToken = null;
      headers.clear();
      throw const FirebaseRestAppCheckException(
        FirebaseRestAppCheckFailure.emptyToken,
      );
    }

    headers[appCheckHeader] = appCheckToken;
    appCheckToken = null;
    return headers;
  }
}
