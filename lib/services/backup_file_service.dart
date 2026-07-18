/// Versioned encrypted file export/import and the platform file hand-off.
///
/// The file deliberately contains only the AES-256-GCM envelope produced by
/// [SubscriptionStore.exportEncryptedCloudBackup]. It never serializes the
/// Keychain key, cleartext subscriptions, or any other secret.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import 'subscription_store.dart';

enum BackupImportStatus {
  success,
  cancelled,
  invalidFile,
  unsupportedVersion,
  decryptionFailed,
}

class BackupImportResult {
  const BackupImportResult(this.status, {this.importedCount = 0});

  final BackupImportStatus status;
  final int importedCount;
}

enum BackupShareStatus { success, dismissed, unavailable }

abstract class BackupFileGateway {
  Future<BackupShareStatus> shareTextFile({
    required String contents,
    required String fileName,
    required String mimeType,
    required Rect sharePositionOrigin,
  });

  Future<String?> pickEncryptedBackup();
}

class SystemBackupFileGateway implements BackupFileGateway {
  const SystemBackupFileGateway();

  @override
  Future<BackupShareStatus> shareTextFile({
    required String contents,
    required String fileName,
    required String mimeType,
    required Rect sharePositionOrigin,
  }) async {
    // Writing the file ourselves lets us remove it as soon as the native share
    // sheet completes instead of leaving a generated XFile in the app cache.
    final directory = await Directory.systemTemp.createTemp(
      'ishtirakati-export-',
    );
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    try {
      await file.writeAsBytes(utf8.encode(contents), flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: mimeType)],
          fileNameOverrides: <String>[fileName],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => BackupShareStatus.success,
        ShareResultStatus.dismissed => BackupShareStatus.dismissed,
        ShareResultStatus.unavailable => BackupShareStatus.unavailable,
      };
    } finally {
      try {
        if (await directory.exists()) await directory.delete(recursive: true);
      } catch (_) {
        // Best-effort cleanup only. Never log the sensitive temporary path.
      }
    }
  }

  @override
  Future<String?> pickEncryptedBackup() async {
    final typeGroup = XTypeGroup(
      label: tr('backupFilePickerLabel'),
      extensions: const <String>['json'],
      uniformTypeIdentifiers: const <String>['public.json'],
    );
    final selected = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );
    if (selected == null) return null;
    if (await selected.length() > BackupFileService.maxFileBytes) {
      throw const BackupFileException(BackupImportStatus.invalidFile);
    }
    return selected.readAsString();
  }
}

class BackupFileException implements Exception {
  const BackupFileException(this.status);

  final BackupImportStatus status;
}

class BackupFileService {
  BackupFileService({
    SubscriptionStore? store,
    BackupFileGateway? gateway,
    DateTime Function()? now,
  }) : _store = store ?? SubscriptionStore.instance,
       _gateway = gateway ?? const SystemBackupFileGateway(),
       _now = now ?? DateTime.now;

  static const int fileVersion = 1;
  static const int payloadSchemaVersion = 2;
  // AES-GCM preserves plaintext length, while Base64 expands it to 4/3 before
  // the envelope is embedded in the outer JSON. Keep enough bounded headroom
  // for both JSON layers so every supported plaintext can round-trip.
  static const int maxFileBytes =
      ((SubscriptionStore.maxImportBytes + 2) ~/ 3) * 4 + 64 * 1024;
  static const String appIdentifier = 'ishtirakati';
  static const String fileType = 'encrypted-backup';
  static const String encryption = 'AES-256-GCM';

  final SubscriptionStore _store;
  final BackupFileGateway _gateway;
  final DateTime Function() _now;

  Future<String> createEncryptedBackupFile() async {
    final payload = await _store.exportEncryptedFileBackup();
    if (!_isValidCiphertextEnvelope(payload)) {
      throw const BackupFileException(BackupImportStatus.invalidFile);
    }
    final file = const JsonEncoder.withIndent('  ').convert(<String, Object>{
      'app': appIdentifier,
      'fileType': fileType,
      'fileVersion': fileVersion,
      'payloadSchemaVersion': payloadSchemaVersion,
      'encryption': encryption,
      'createdAt': _now().toUtc().toIso8601String(),
      'payload': payload,
    });
    if (utf8.encode(file).length > maxFileBytes) {
      throw const BackupFileException(BackupImportStatus.invalidFile);
    }
    return file;
  }

  Future<BackupImportResult> importEncryptedBackupFile(String raw) async {
    if (utf8.encode(raw).length > maxFileBytes) {
      return const BackupImportResult(BackupImportStatus.invalidFile);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 7 ||
          decoded.keys.toSet().difference(const <String>{
            'app',
            'fileType',
            'fileVersion',
            'payloadSchemaVersion',
            'encryption',
            'createdAt',
            'payload',
          }).isNotEmpty ||
          decoded['app'] != appIdentifier ||
          decoded['fileType'] != fileType) {
        return const BackupImportResult(BackupImportStatus.invalidFile);
      }
      if (decoded['fileVersion'] != fileVersion ||
          decoded['payloadSchemaVersion'] != payloadSchemaVersion) {
        return const BackupImportResult(BackupImportStatus.unsupportedVersion);
      }
      if (decoded['encryption'] != encryption ||
          DateTime.tryParse(decoded['createdAt'] as String? ?? '') == null) {
        return const BackupImportResult(BackupImportStatus.invalidFile);
      }
      final payload = decoded['payload'];
      if (payload is! String || !_isValidCiphertextEnvelope(payload)) {
        return const BackupImportResult(BackupImportStatus.invalidFile);
      }
      final result = await _store.importEncryptedFileBackup(
        payload,
        expectedApp: appIdentifier,
        expectedPayloadVersion: payloadSchemaVersion,
      );
      return switch (result.status) {
        EncryptedFileBackupImportStatus.success => BackupImportResult(
          BackupImportStatus.success,
          importedCount: result.importedCount,
        ),
        EncryptedFileBackupImportStatus.invalidPayload =>
          const BackupImportResult(BackupImportStatus.invalidFile),
        EncryptedFileBackupImportStatus.unsupportedVersion =>
          const BackupImportResult(BackupImportStatus.unsupportedVersion),
        EncryptedFileBackupImportStatus.decryptionFailed =>
          const BackupImportResult(BackupImportStatus.decryptionFailed),
      };
    } on FormatException {
      return const BackupImportResult(BackupImportStatus.invalidFile);
    } on TypeError {
      return const BackupImportResult(BackupImportStatus.invalidFile);
    }
  }

  Future<BackupImportResult> pickAndImportEncryptedBackup() async {
    try {
      final raw = await _gateway.pickEncryptedBackup();
      if (raw == null) {
        return const BackupImportResult(BackupImportStatus.cancelled);
      }
      return importEncryptedBackupFile(raw);
    } on BackupFileException catch (error) {
      return BackupImportResult(error.status);
    } on FileSystemException {
      return const BackupImportResult(BackupImportStatus.invalidFile);
    } on PlatformException {
      return const BackupImportResult(BackupImportStatus.invalidFile);
    } on FormatException {
      return const BackupImportResult(BackupImportStatus.invalidFile);
    }
  }

  Future<BackupShareStatus> shareEncryptedBackup(
    Rect sharePositionOrigin,
  ) async {
    final contents = await createEncryptedBackupFile();
    return _gateway.shareTextFile(
      contents: contents,
      fileName: _fileName('encrypted-backup', 'json'),
      mimeType: 'application/json',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<BackupShareStatus> shareCsv(Rect sharePositionOrigin) {
    return _gateway.shareTextFile(
      contents: createHumanReadableCsv(),
      fileName: _fileName('subscriptions', 'csv'),
      mimeType: 'text/csv',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Human-readable, intentionally plaintext and deliberately data-minimized.
  /// Notes, management URLs, usage history, and payment details are excluded.
  String createHumanReadableCsv() {
    // Quoting alone does not stop spreadsheet formula evaluation. Prefix any
    // user-controlled cell whose first non-space character is executable.
    String neutralizeFormula(String value) {
      final first = value.trimLeft();
      if (value.startsWith('\t') ||
          value.startsWith('\r') ||
          first.startsWith('=') ||
          first.startsWith('+') ||
          first.startsWith('-') ||
          first.startsWith('@')) {
        return "'$value";
      }
      return value;
    }

    String escape(String value) {
      final safe = neutralizeFormula(value);
      return '"${safe.replaceAll('"', '""')}"';
    }

    String isoDate(DateTime date) {
      final local = date.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
    }

    final output = StringBuffer('\ufeff');
    output.writeln(
      <String>[
        tr('backupCsvName'),
        tr('backupCsvAmount'),
        tr('backupCsvCurrency'),
        tr('backupCsvCycle'),
        tr('backupCsvCategory'),
        tr('backupCsvNextRenewal'),
        tr('backupCsvStatus'),
      ].map(escape).join(','),
    );
    for (final subscription in _store.items) {
      output.writeln(
        <String>[
          subscription.name,
          subscription.price.toStringAsFixed(2),
          subscription.currency,
          localizedBillingCycle(subscription.cycle.name),
          localizedCategory(subscription.category),
          isoDate(subscription.nextRenewal()),
          tr(subscription.isPaused ? 'backupCsvPaused' : 'backupCsvActive'),
        ].map(escape).join(','),
      );
    }
    return output.toString();
  }

  String _fileName(String kind, String extension) {
    final timestamp = _now().toUtc().toIso8601String().replaceAll(':', '-');
    return 'ishtirakati-$kind-$timestamp.$extension';
  }

  bool _isValidCiphertextEnvelope(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic> ||
          decoded.keys.toSet().difference(const {
            'v',
            'n',
            'c',
            'm',
          }).isNotEmpty ||
          decoded.length != 4 ||
          decoded['v'] != 1) {
        return false;
      }
      final nonce = base64Url.decode(decoded['n'] as String);
      final ciphertext = base64Url.decode(decoded['c'] as String);
      final mac = base64Url.decode(decoded['m'] as String);
      return nonce.length == 12 && ciphertext.isNotEmpty && mac.length == 16;
    } catch (_) {
      return false;
    }
  }
}
