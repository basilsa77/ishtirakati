import 'package:flutter/foundation.dart';

/// Compile-time switches for Firebase diagnostics and reversible fallbacks.
class FirebaseBuildConfig {
  FirebaseBuildConfig._();

  static const internalBuild = bool.fromEnvironment(
    'INTERNAL_BUILD',
    defaultValue: kDebugMode,
  );

  static const _offlineQueueRequested = bool.fromEnvironment(
    'ENABLE_FIRESTORE_OFFLINE_QUEUE',
    defaultValue: false,
  );

  static const _restFallbackRequested = bool.fromEnvironment(
    'ENABLE_REST_FALLBACK',
    defaultValue: false,
  );

  static const _restFirstCreateRequested = bool.fromEnvironment(
    'ENABLE_REST_FIRST_CREATE',
    defaultValue: false,
  );

  static const _restUpdateFallbackRequested = bool.fromEnvironment(
    'ENABLE_REST_UPDATE_FALLBACK',
    defaultValue: false,
  );

  static const appCheckEnabled = bool.fromEnvironment(
    'ENABLE_FIREBASE_APP_CHECK',
    defaultValue: false,
  );

  static const _appCheckDebugRequested = bool.fromEnvironment(
    'ENABLE_FIREBASE_APP_CHECK_DEBUG',
    defaultValue: false,
  );

  static bool get offlineQueueEnabled =>
      internalBuild && _offlineQueueRequested;

  static bool get restFallbackEnabled =>
      internalBuild && _restFallbackRequested;

  static bool get restFirstCreateEnabled =>
      internalBuild && _restFirstCreateRequested;

  static bool get restUpdateFallbackEnabled =>
      internalBuild && _restUpdateFallbackRequested;

  static bool get appCheckDebugEnabled =>
      internalBuild && appCheckEnabled && _appCheckDebugRequested;

  @visibleForTesting
  static bool debugProviderAllowed({
    required bool internal,
    required bool appCheck,
    required bool requested,
  }) =>
      internal && appCheck && requested;
}
