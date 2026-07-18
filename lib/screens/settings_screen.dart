/// إعدادات الإصدار 16: مجموعات قصيرة واضحة من دون صفحات متراكبة.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart' show currencySymbols;
import '../l10n/app_localizations.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../services/backup_file_service.dart';
import '../services/cloud_sync.dart';
import '../services/firebase_build_config.dart';
import '../services/firestore_connection_diagnostics.dart';
import '../services/firestore_config.dart';
import '../services/firestore_rest_fallback.dart';
import '../services/notification_service.dart';
import '../services/subscription_store.dart';
import '../services/update_checker.dart';
import '../theme.dart';
import '../widgets/ios_controls.dart';
import 'ai_tools_screen.dart';
import 'email_link_screen.dart';
import 'import_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

const Key v17DataDeleteButtonKey = Key('v17-data-delete');
const Key v17DeleteEncryptedBackupKey = Key('v17-delete-encrypted-backup');
const Key v17DeleteCsvKey = Key('v17-delete-csv');
const Key v17DeleteWithoutExportKey = Key('v17-delete-without-export');
const Key v17DeleteFinalConfirmKey = Key('v17-delete-final-confirm');
const Key v17DeleteCancelKey = Key('v17-delete-cancel');

enum _PreDeleteChoice { encryptedBackup, csv, withoutExport }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.store, this.backupFileService});

  /// Test seams only; production always uses the singleton and system gateway.
  final SubscriptionStore? store;
  final BackupFileService? backupFileService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _budget;
  late final SubscriptionStore _store;
  late final BackupFileService _backupFiles;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SubscriptionStore.instance;
    _backupFiles = widget.backupFileService ?? BackupFileService(store: _store);
    final budget = _store.monthlyBudget;
    _budget = TextEditingController(
      text:
          budget <= 0
              ? ''
              : budget == budget.roundToDouble()
              ? budget.toStringAsFixed(0)
              : budget.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return ListenableBuilder(
      listenable: store,
      builder:
          (context, _) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              V16Space.ml,
              V16Space.md,
              V16Space.ml,
              V16Space.xl,
            ),
            children: [
              const _SettingsIntro(),
              if (!store.storageHealthy) ...[
                const SizedBox(height: V16Space.md),
                IosStatusNotice(
                  message: store.storageError ?? tr('ui_8fb06d4b1479'),
                  tone: IosStatusTone.error,
                ),
              ],
              const SizedBox(height: V16Space.lg),
              _AccountCard(
                onChanged: () => setState(() {}),
                onDeleteAccount: _confirmDeleteAccount,
              ),
              const SizedBox(height: 26),
              _SettingsLabel(context.l10n.text('settingsAppearance')),
              const SizedBox(height: 10),
              const _ThemeModeCard(),
              const SizedBox(height: 26),
              _SettingsLabel(context.l10n.text('language')),
              const SizedBox(height: 10),
              const _LanguageModeCard(),
              const SizedBox(height: 26),
              _SettingsLabel(tr('ui_f3e1723cfe33')),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsSwitch(
                      icon: Icons.notifications_none_rounded,
                      title: tr('ui_551e77811caa'),
                      detail: tr('ui_0354b6cd5038'),
                      value: store.notificationsEnabled,
                      onChanged: (value) async {
                        if (value) {
                          final permitted =
                              await NotificationService.instance
                                  .requestPermission();
                          if (!permitted && context.mounted) {
                            await showCupertinoDialog<void>(
                              context: context,
                              builder:
                                  (dialogContext) => CupertinoAlertDialog(
                                    title: Text(tr('ui_b6d4d093c09d')),
                                    content: Text(tr('ui_7459d276bf09')),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed:
                                            () => Navigator.pop(dialogContext),
                                        child: Text(tr('ui_a64b3d93816b')),
                                      ),
                                    ],
                                  ),
                            );
                          }
                        }
                        await store.setNotificationsEnabled(value);
                      },
                    ),
                    Divider(height: 1, color: context.palette.stroke),
                    _SettingsSwitch(
                      icon: CupertinoIcons.lock_shield,
                      title: tr('ui_d1161e76379a'),
                      detail: tr('ui_77cd4e71bca6'),
                      value: store.privateNotifications,
                      onChanged: store.setPrivateNotifications,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _SettingsLabel(tr('ui_976adf68f49a')),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsSwitch(
                      icon: Icons.face_retouching_natural_rounded,
                      title: tr('ui_b2eb28c06d2a'),
                      detail: tr('ui_5acd34c06919'),
                      value: store.appLockEnabled,
                      onChanged: store.setAppLockEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _SettingsLabel(tr('ui_2c0c0a6a3389')),
              const SizedBox(height: 10),
              _BudgetCard(controller: _budget, onSave: _saveBudget),
              const SizedBox(height: 26),
              _SettingsLabel(tr('ui_70f79cf39f31')),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsAction(
                      icon: Icons.document_scanner_rounded,
                      title: tr('ui_4d5bbc8f3ce7'),
                      detail: tr('ui_3ad982d68db0'),
                      onTap:
                          () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const ImportScreen(),
                            ),
                          ),
                    ),
                    Divider(height: 1, color: context.palette.stroke),
                    _SettingsAction(
                      icon: Icons.alternate_email_rounded,
                      title: tr('ui_c4d54697418a'),
                      detail: tr('ui_05c130b7df4a'),
                      onTap:
                          () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const EmailLinkScreen(),
                            ),
                          ),
                    ),
                    Divider(height: 1, color: context.palette.stroke),
                    _SettingsAction(
                      icon: Icons.auto_awesome_rounded,
                      title: tr('ui_6ec927377748'),
                      detail: tr('ui_6e55c742696f'),
                      onTap:
                          () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const AiToolsScreen(),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _SettingsLabel(tr('ui_b4fba865ed46')),
              const SizedBox(height: 10),
              _DataCard(
                onExportEncrypted: _exportEncryptedBackup,
                onImportEncrypted: _importEncryptedBackup,
                onExportCsv: _exportCsv,
                onDelete: _confirmWipe,
              ),
              const SizedBox(height: 26),
              _SettingsLabel(tr('ui_db69cd4d6275')),
              const SizedBox(height: 10),
              const _AboutCard(),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  tr('ui_ed185d7957db'),
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: V16Type.labelSmall,
                    fontWeight: V16Type.semibold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _saveBudget() async {
    final value =
        double.tryParse(
          _budget.text
              .trim()
              .replaceAll(tr('ui_bc4d631526af'), '.')
              .replaceAll(',', '.'),
        ) ??
        0;
    await _store.setMonthlyBudget(value);
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            content: Text(
              value <= 0 ? tr('ui_46e83de05124') : tr('ui_e7311dcecd04'),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('ui_3ef541b90a31')),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmWipe() async {
    final choice = await showCupertinoModalPopup<_PreDeleteChoice>(
      context: context,
      builder:
          (sheetContext) => CupertinoActionSheet(
            title: Text(tr('backupBeforeDeleteTitle')),
            message: Text(tr('backupBeforeDeleteMessage')),
            actions: [
              CupertinoActionSheetAction(
                key: v17DeleteEncryptedBackupKey,
                onPressed:
                    () => Navigator.pop(
                      sheetContext,
                      _PreDeleteChoice.encryptedBackup,
                    ),
                child: Text(tr('backupExportEncrypted')),
              ),
              CupertinoActionSheetAction(
                key: v17DeleteCsvKey,
                onPressed:
                    () => Navigator.pop(sheetContext, _PreDeleteChoice.csv),
                child: Text(tr('backupExportCsv')),
              ),
              CupertinoActionSheetAction(
                key: v17DeleteWithoutExportKey,
                onPressed:
                    () => Navigator.pop(
                      sheetContext,
                      _PreDeleteChoice.withoutExport,
                    ),
                child: Text(tr('backupContinueWithoutExport')),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              key: v17DeleteCancelKey,
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(tr('ui_9a30dc2a96b8')),
            ),
          ),
    );
    if (!mounted || choice == null) return;

    final exportCompleted = switch (choice) {
      _PreDeleteChoice.encryptedBackup => await _exportEncryptedBackup(
        showSuccess: false,
      ),
      _PreDeleteChoice.csv => await _exportCsv(showSuccess: false),
      _PreDeleteChoice.withoutExport => true,
    };
    if (!mounted || !exportCompleted) return;
    await _confirmFinalWipe();
  }

  Future<void> _confirmFinalWipe() async {
    final count = _store.items.length;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: Text(tr('ui_6d5931ec133b')),
            content: Text(localizedPlural('backupDeleteFinalMessage', count)),
            actions: [
              CupertinoDialogAction(
                key: v17DeleteCancelKey,
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('ui_9a30dc2a96b8')),
              ),
              CupertinoDialogAction(
                key: v17DeleteFinalConfirmKey,
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('ui_cd6f896cc0ee')),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    // If synchronization changed the list while the dialog was open, repeat
    // the confirmation so the displayed count always equals the actual count.
    if (_store.items.length != count) {
      await _confirmFinalWipe();
      return;
    }
    try {
      await _store.clearAll();
      if (!mounted) return;
      await _showDataMessage(tr('backupDeleteCompleted'));
    } catch (_) {
      if (!mounted) return;
      await _showDataMessage(tr('backupDeleteFailed'));
    }
  }

  Future<bool> _exportEncryptedBackup({bool showSuccess = true}) async {
    try {
      final status = await _backupFiles.shareEncryptedBackup(_shareOrigin());
      if (!mounted || status == BackupShareStatus.dismissed) return false;
      if (status == BackupShareStatus.success) {
        if (showSuccess) {
          await _showDataMessage(tr('backupExportCompleted'));
        }
        return true;
      }
      await _showDataMessage(tr('backupShareUnavailable'));
      return false;
    } catch (_) {
      if (mounted) await _showDataMessage(tr('backupExportFailed'));
      return false;
    }
  }

  Future<bool> _exportCsv({bool showSuccess = true}) async {
    final accepted = await showIosConfirmation(
      context: context,
      title: tr('backupCsvWarningTitle'),
      message: tr('backupCsvWarningMessage'),
      confirmLabel: tr('backupCsvConfirm'),
    );
    if (!accepted || !mounted) return false;
    try {
      final status = await _backupFiles.shareCsv(_shareOrigin());
      if (!mounted || status == BackupShareStatus.dismissed) return false;
      if (status == BackupShareStatus.success) {
        if (showSuccess) {
          await _showDataMessage(tr('backupExportCompleted'));
        }
        return true;
      }
      await _showDataMessage(tr('backupShareUnavailable'));
      return false;
    } catch (_) {
      if (mounted) await _showDataMessage(tr('backupExportFailed'));
      return false;
    }
  }

  Future<void> _importEncryptedBackup() async {
    BackupImportResult result;
    try {
      result = await _backupFiles.pickAndImportEncryptedBackup();
    } catch (_) {
      if (mounted) await _showDataMessage(tr('backupInvalidFile'));
      return;
    }
    if (!mounted || result.status == BackupImportStatus.cancelled) return;
    final message = switch (result.status) {
      BackupImportStatus.success => localizedPlural(
        'backupImportCompleted',
        result.importedCount,
      ),
      BackupImportStatus.unsupportedVersion => tr('backupUnsupportedVersion'),
      BackupImportStatus.decryptionFailed => tr('backupDecryptFailed'),
      BackupImportStatus.invalidFile => tr('backupInvalidFile'),
      BackupImportStatus.cancelled => '',
    };
    await _showDataMessage(message);
  }

  Rect _shareOrigin() {
    final renderBox = context.findRenderObject();
    if (renderBox is RenderBox && renderBox.hasSize) {
      return renderBox.localToGlobal(Offset.zero) & renderBox.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }

  Future<void> _showDataMessage(String message) => showCupertinoDialog<void>(
    context: context,
    builder:
        (dialogContext) => CupertinoAlertDialog(
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('ui_3ef541b90a31')),
            ),
          ],
        ),
  );

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showIosConfirmation(
      context: context,
      title: tr('ui_1ab7cb67413b'),
      message: tr('ui_a69b6d3b9499'),
      confirmLabel: tr('ui_d7939def6a41'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => PopScope(
            canPop: false,
            child: CupertinoAlertDialog(
              content: Row(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tr('ui_2bdda9dc2f90'))),
                ],
              ),
            ),
          ),
    );
    try {
      await AccountDeletionService.deleteEverything();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message =
          error is AuthException ? error.message : tr('ui_1b4978e420cd');
      await showCupertinoDialog<void>(
        context: context,
        builder:
            (dialogContext) => CupertinoAlertDialog(
              title: Text(tr('ui_c9f721ee4fd2')),
              content: Text(message),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(tr('ui_a64b3d93816b')),
                ),
              ],
            ),
      );
    }
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro();

  @override
  Widget build(BuildContext context) => AppPageIntro(
    title: tr('ui_5fd9563e6846'),
    description: tr('ui_58d077f29d61'),
  );
}

class _AccountCard extends StatelessWidget {
  final VoidCallback onChanged;
  final Future<void> Function() onDeleteAccount;

  const _AccountCard({required this.onChanged, required this.onDeleteAccount});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final signedIn = AuthService.isSignedIn;
    return AppCard(
      padding: const EdgeInsets.all(V16Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(CupertinoIcons.cloud, color: p.accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('ui_0458a671e96c'),
                      style: TextStyle(
                        color: p.text,
                        fontWeight: V16Type.semibold,
                        fontSize: V16Type.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      !AuthService.isAvailable
                          ? tr('ui_0380d88f6407')
                          : signedIn
                          ? AuthService.userEmail
                          : tr('ui_02776b074d68'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V16Type.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!signedIn)
            CupertinoButton.filled(
              onPressed:
                  !AuthService.isAvailable
                      ? null
                      : () async {
                        await Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder:
                                (_) => const LoginScreen(fromSettings: true),
                          ),
                        );
                        onChanged();
                      },
              child: Text(tr('ui_beb869eecc12')),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: () async {
                          await CloudSync.syncNow();
                        },
                        child: Text(tr('ui_1c9524c2caca')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: const EdgeInsets.all(11),
                      color: p.dangerSoft,
                      onPressed: () async {
                        try {
                          await AuthService.signOut();
                          onChanged();
                        } on AuthException catch (error) {
                          if (!context.mounted) return;
                          await showCupertinoDialog<void>(
                            context: context,
                            builder:
                                (dialogContext) => CupertinoAlertDialog(
                                  content: Text(error.message),
                                  actions: [
                                    CupertinoDialogAction(
                                      onPressed:
                                          () => Navigator.pop(dialogContext),
                                      child: Text(tr('ui_a64b3d93816b')),
                                    ),
                                  ],
                                ),
                          );
                        }
                      },
                      child: Icon(
                        CupertinoIcons.square_arrow_right,
                        color: p.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<CloudSyncStatus>(
                  valueListenable: CloudSync.status,
                  builder: (context, status, _) {
                    final (text, tone) = switch (status.phase) {
                      CloudSyncPhase.syncing => (
                        tr('ui_990fa33ab762'),
                        IosStatusTone.info,
                      ),
                      CloudSyncPhase.success => (
                        status.message ?? _syncSuccessText(status.updatedAt),
                        IosStatusTone.success,
                      ),
                      CloudSyncPhase.queued => (
                        status.message ?? tr('cloudQueuedLocally'),
                        IosStatusTone.queued,
                      ),
                      CloudSyncPhase.failure => (
                        status.message ?? tr('ui_9326a71f2574'),
                        IosStatusTone.error,
                      ),
                      CloudSyncPhase.idle => (
                        tr('ui_72bd581dc069'),
                        IosStatusTone.info,
                      ),
                    };
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IosStatusNotice(message: text, tone: tone),
                        if (CloudSync.internalDiagnosticsEnabled &&
                            status.operation != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            tr('cloudSyncDiagnostic', {
                              'operation': status.operation ?? '-',
                              'code': status.firebaseCode ?? '-',
                              'exists':
                                  status.documentExisted?.toString() ?? '-',
                              'revision': status.revision?.toString() ?? '-',
                              'commit': kGitCommitShort,
                            }),
                            style: TextStyle(
                              color: p.textMuted,
                              fontSize: V16Type.caption,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (FirestoreConnectionDiagnostics.enabled) ...[
                          const SizedBox(height: 10),
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                FirestoreConnectionDiagnostics.running,
                            builder:
                                (context, running, _) => CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  color: p.accentSoft,
                                  onPressed:
                                      running
                                          ? null
                                          : FirestoreConnectionDiagnostics.run,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (running)
                                        const CupertinoActivityIndicator()
                                      else
                                        Icon(
                                          CupertinoIcons
                                              .antenna_radiowaves_left_right,
                                          color: p.accent,
                                          size: 18,
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        running
                                            ? tr('firestoreDiagnosticRunning')
                                            : tr('firestoreDiagnosticButton'),
                                        style: TextStyle(
                                          color: p.accent,
                                          fontSize: V16Type.caption,
                                          fontWeight: V16Type.semibold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                          ValueListenableBuilder<
                            FirestoreConnectionDiagnostic?
                          >(
                            valueListenable:
                                FirestoreConnectionDiagnostics.lastResult,
                            builder: (context, result, _) {
                              if (result == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _FirestoreDiagnosticPanel(
                                  result: result,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  onPressed: onDeleteAccount,
                  child: Text(
                    tr('ui_70f341498d46'),
                    style: TextStyle(color: p.danger),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            tr('ui_87621ec0d18d'),
            style: TextStyle(
              color: p.textMuted,
              fontSize: V16Type.caption,
              height: V16Type.captionHeight,
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: AuthService.appCheckWarning,
            builder: (context, warning, _) {
              if (warning == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: IosStatusNotice(
                  message: warning,
                  tone: IosStatusTone.error,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _syncSuccessText(DateTime? at) {
    if (at == null) return tr('syncCompleted');
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return tr('ui_1e0af0b94ec1', {'value0': hour, 'value1': minute});
  }
}

class _FirestoreDiagnosticPanel extends StatelessWidget {
  final FirestoreConnectionDiagnostic result;

  const _FirestoreDiagnosticPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rest = result.rest;
    final native = result.native;
    final sync = CloudSync.status.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('firestoreDiagnosticEnvironmentTitle'),
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.bodySmall,
              fontWeight: V16Type.semibold,
            ),
          ),
          const SizedBox(height: 6),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticAppVersion'),
            value: '$kAppVersion ($kAppBuildNumber)',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticCommit'),
            value: kGitCommitShort,
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticProject'),
            value: FirestoreRestFallback.projectId,
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDatabase'),
            value: FirestoreConfig.databaseId,
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticSdkVersions'),
            value:
                'core $firebaseCoreVersion | auth $firebaseAuthVersion | '
                'firestore $cloudFirestoreVersion | '
                'app-check $firebaseAppCheckVersion | iOS $firebaseIosSdkVersion',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDependencyManager'),
            value: iosDependencyManager,
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticFeatureFlags'),
            value: tr('firestoreDiagnosticFeatureFlagsValue', {
              'offline': _yesNo(FirebaseBuildConfig.offlineQueueEnabled),
              'rest': _yesNo(FirebaseBuildConfig.restFallbackEnabled),
              'firstCreate': _yesNo(FirebaseBuildConfig.restFirstCreateEnabled),
              'restUpdate': _yesNo(
                FirebaseBuildConfig.restUpdateFallbackEnabled,
              ),
              'appCheckDebug': _yesNo(FirebaseBuildConfig.appCheckDebugEnabled),
            }),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticAppCheck'),
            value: tr('firestoreDiagnosticAppCheckValue', {
              'enabled': _yesNo(AuthService.appCheckEnabled),
              'provider': AuthService.appCheckProviderName,
              'token':
                  AuthService.appCheckTokenObtained.value == null
                      ? tr('firestoreDiagnosticNotRequired')
                      : _yesNo(AuthService.appCheckTokenObtained.value!),
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: p.stroke),
          ),
          Text(
            tr('firestoreDiagnosticRestTitle'),
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.bodySmall,
              fontWeight: V16Type.semibold,
            ),
          ),
          const SizedBox(height: 6),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticHttpStatus'),
            value:
                rest.commitHttpStatus == null
                    ? rest.httpStatus?.toString() ?? '-'
                    : 'GET ${rest.httpStatus} | commit ${rest.commitHttpStatus}',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDns'),
            value: _yesNo(rest.dnsSucceeded),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticHttps'),
            value: _yesNo(rest.connectionSucceeded),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDuration'),
            value: '${localizedInteger(rest.elapsed.inMilliseconds)} ms',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticResult'),
            value: _restOutcomeText(rest.outcome),
          ),
          if (rest.exceptionType != null)
            _DiagnosticLine(
              label: tr('firestoreDiagnosticException'),
              value: rest.exceptionType!,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: p.stroke),
          ),
          Text(
            tr('firestoreDiagnosticNativeTitle'),
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.bodySmall,
              fontWeight: V16Type.semibold,
            ),
          ),
          const SizedBox(height: 6),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticSucceeded'),
            value: _yesNo(native.succeeded),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDocumentExists'),
            value:
                native.documentExists == null
                    ? '-'
                    : _yesNo(native.documentExists!),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticFirebaseCode'),
            value: native.firebaseCode ?? '-',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticPlugin'),
            value: native.firebasePlugin ?? sync.firebasePlugin ?? '-',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticRuntimeType'),
            value: native.exceptionType ?? sync.exceptionType ?? '-',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticNativeOperation'),
            value: sync.operation ?? 'diagnostic-native-read',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticAttempts'),
            value: localizedInteger(native.attemptCount),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticNativeResult'),
            value:
                native.succeeded
                    ? tr('firestoreDiagnosticServerConfirmed')
                    : sync.delivery == CloudSyncDelivery.queuedLocally
                    ? tr('firestoreDiagnosticQueuedLocally')
                    : tr('firestoreDiagnosticFailed'),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticPendingWrites'),
            value:
                sync.hasPendingWrites == null
                    ? '-'
                    : _yesNo(sync.hasPendingWrites!),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDuration'),
            value: '${localizedInteger(native.elapsed.inMilliseconds)} ms',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticSyncRestStatus'),
            value: sync.restHttpStatus?.toString() ?? '-',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticSyncRestResult'),
            value: sync.restOutcome ?? tr('firestoreDiagnosticNotUsed'),
          ),
          if (native.safeMessage != null) ...[
            const SizedBox(height: 5),
            Text(
              native.safeMessage!,
              style: TextStyle(
                color: p.textMuted,
                fontSize: V16Type.caption,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _diagnosticConclusion(result),
            style: TextStyle(
              color: p.accent,
              fontSize: V16Type.caption,
              fontWeight: V16Type.semibold,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _yesNo(bool value) =>
      value ? tr('firestoreDiagnosticYes') : tr('firestoreDiagnosticNo');

  String _restOutcomeText(FirestoreRestOutcome outcome) => switch (outcome) {
    FirestoreRestOutcome.success => tr('firestoreDiagnosticRest200'),
    FirestoreRestOutcome.missingDocument => tr('firestoreDiagnosticRest404'),
    FirestoreRestOutcome.unauthenticated => tr('firestoreDiagnosticRest401'),
    FirestoreRestOutcome.permissionDenied => tr('firestoreDiagnosticRest403'),
    FirestoreRestOutcome.invalidTarget => tr('firestoreDiagnosticRest400'),
    FirestoreRestOutcome.rateLimited => tr('firestoreDiagnosticRest429'),
    FirestoreRestOutcome.serviceFailure => tr('firestoreDiagnosticRest5xx'),
    FirestoreRestOutcome.dnsFailure => tr('firestoreDiagnosticDnsFailed'),
    FirestoreRestOutcome.socketFailure => tr('firestoreDiagnosticSocketFailed'),
    FirestoreRestOutcome.tlsFailure => tr('firestoreDiagnosticTlsFailed'),
    FirestoreRestOutcome.timeout => tr('firestoreDiagnosticTimedOut'),
    FirestoreRestOutcome.clientFailure => tr('firestoreDiagnosticClientFailed'),
    FirestoreRestOutcome.noUser => tr('firestoreDiagnosticNoUser'),
    FirestoreRestOutcome.tokenFailure => tr('firestoreDiagnosticTokenFailed'),
    FirestoreRestOutcome.unexpectedFailure => tr(
      'firestoreDiagnosticUnexpected',
    ),
  };

  String _diagnosticConclusion(FirestoreConnectionDiagnostic result) {
    final restReachedFirestore = result.rest.httpStatus != null;
    if (restReachedFirestore && !result.native.succeeded) {
      return tr('firestoreDiagnosticNativeTransportConclusion');
    }
    if (result.rest.outcome == FirestoreRestOutcome.dnsFailure ||
        result.rest.outcome == FirestoreRestOutcome.socketFailure ||
        result.rest.outcome == FirestoreRestOutcome.tlsFailure ||
        result.rest.outcome == FirestoreRestOutcome.timeout) {
      return tr('firestoreDiagnosticNetworkConclusion');
    }
    if (result.rest.outcome == FirestoreRestOutcome.unauthenticated) {
      return tr('firestoreDiagnosticAuthConclusion');
    }
    if (result.rest.outcome == FirestoreRestOutcome.permissionDenied) {
      return tr('firestoreDiagnosticRulesConclusion');
    }
    if (restReachedFirestore && result.native.succeeded) {
      return tr('firestoreDiagnosticBothReachedConclusion');
    }
    return tr('firestoreDiagnosticNeedsReviewConclusion');
  }
}

class _DiagnosticLine extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: p.textMuted, fontSize: V16Type.caption),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: p.text,
                fontSize: V16Type.caption,
                fontWeight: V16Type.semibold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  final String text;

  const _SettingsLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.palette.textMuted,
      fontSize: V16Type.caption,
      fontWeight: V16Type.semibold,
    ),
  );
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: p.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.text,
                    fontWeight: V16Type.semibold,
                    fontSize: V16Type.label,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: V16Type.caption,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: p.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: p.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: p.text,
                      fontWeight: V16Type.semibold,
                      fontSize: V16Type.label,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: V16Type.caption,
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_left, color: p.textMuted, size: 17),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;

  const _BudgetCard({required this.controller, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currency = SubscriptionStore.instance.defaultCurrency;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: p.accent),
              const SizedBox(width: 9),
              Text(
                tr('ui_b6775a5543d9'),
                style: TextStyle(
                  color: p.text,
                  fontSize: V16Type.bodySmall,
                  fontWeight: V16Type.semibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            tr('ui_bf208c21fb03'),
            style: TextStyle(color: p.textMuted, fontSize: V16Type.caption),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  placeholder: '0',
                  suffix: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Text(
                      currencySymbols[currency] ?? currency,
                      style: TextStyle(color: p.textMuted),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: p.stroke),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.all(11),
                color: p.accentStrong,
                onPressed: onSave,
                child: const Icon(
                  CupertinoIcons.check_mark,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _AboutLine(
            label: tr('ui_d83483faf7f9'),
            value: tr('ui_64e2da14cf04'),
          ),
          Divider(height: 1, color: p.stroke),
          _AboutLine(label: tr('ui_f14158b9c061'), value: kAppVersion),
          Divider(height: 1, color: p.stroke),
          _AboutLine(label: tr('appBuildNumber'), value: kAppBuildNumber),
          Divider(height: 1, color: p.stroke),
          _AboutLine(label: tr('appCommit'), value: kGitCommitShort),
          Divider(height: 1, color: p.stroke),
          _AboutLine(label: tr('ui_edcad556ffd0'), value: kAppBuildMode),
          Divider(height: 1, color: p.stroke),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed:
                () => launchUrl(
                  Uri.parse(
                    'https://github.com/basilsa77/ishtirakati/blob/main/PRIVACY_POLICY.md',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('ui_23a13bc51d58'),
                      style: TextStyle(
                        color: p.text,
                        fontWeight: V16Type.semibold,
                        fontSize: V16Type.labelSmall,
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.arrow_up_right_square,
                    color: p.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutLine extends StatelessWidget {
  final String label;
  final String value;

  const _AboutLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: p.textMuted, fontSize: V16Type.caption),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: p.text,
              fontWeight: V16Type.semibold,
              fontSize: V16Type.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// اختيار مظهر التطبيق: داكن (الافتراضي) أو فاتح أو حسب النظام.
class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.text('settingsAppearanceTitle'),
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.label,
              fontWeight: V16Type.semibold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.text('settingsAppearanceDescription'),
            style: TextStyle(color: p.textMuted, fontSize: V16Type.caption),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: store.themeMode,
              backgroundColor: p.surfaceAlt,
              thumbColor: p.accentStrong,
              children: {
                'system': _ThemeModeOption(
                  label: context.l10n.text('themeSystem'),
                  icon: CupertinoIcons.device_phone_portrait,
                  selected: store.themeMode == 'system',
                ),
                'dark': _ThemeModeOption(
                  label: context.l10n.text('themeDark'),
                  icon: CupertinoIcons.moon_fill,
                  selected: store.themeMode == 'dark',
                ),
                'light': _ThemeModeOption(
                  label: context.l10n.text('themeLight'),
                  icon: CupertinoIcons.sun_max_fill,
                  selected: store.themeMode == 'light',
                ),
              },
              onValueChanged: (value) {
                if (value != null) store.setThemeMode(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageModeCard extends StatelessWidget {
  const _LanguageModeCard();

  @override
  Widget build(BuildContext context) {
    final store = SubscriptionStore.instance;
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.text('language'),
            style: TextStyle(
              color: p.text,
              fontSize: V16Type.label,
              fontWeight: V16Type.semibold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.text('languageDescription'),
            style: TextStyle(color: p.textMuted, fontSize: V16Type.caption),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: store.languageMode,
              backgroundColor: p.surfaceAlt,
              thumbColor: p.accentStrong,
              children: {
                'system': _LanguageModeOption(
                  label: context.l10n.text('languageSystem'),
                  selected: store.languageMode == 'system',
                ),
                'ar': _LanguageModeOption(
                  label: context.l10n.text('languageArabic'),
                  selected: store.languageMode == 'ar',
                ),
                'en': _LanguageModeOption(
                  label: context.l10n.text('languageEnglish'),
                  selected: store.languageMode == 'en',
                ),
              },
              onValueChanged: (value) {
                if (value != null) store.setLanguageMode(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageModeOption extends StatelessWidget {
  const _LanguageModeOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: selected ? CupertinoColors.white : context.palette.text,
          fontSize: V16Type.caption,
          fontWeight: V16Type.semibold,
        ),
      ),
    ),
  );
}

class _ThemeModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _ThemeModeOption({
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: selected ? CupertinoColors.white : context.palette.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? CupertinoColors.white : context.palette.text,
              fontSize: V16Type.caption,
              fontWeight: V16Type.semibold,
            ),
          ),
        ],
      ),
    ),
  );
}

/// إدارة البيانات: حذف السجل من الجهاز.
class _DataCard extends StatelessWidget {
  final Future<bool> Function({bool showSuccess}) onExportEncrypted;
  final Future<void> Function() onImportEncrypted;
  final Future<bool> Function({bool showSuccess}) onExportCsv;
  final Future<void> Function() onDelete;

  const _DataCard({
    required this.onExportEncrypted,
    required this.onImportEncrypted,
    required this.onExportCsv,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DataAction(
            icon: CupertinoIcons.lock_shield,
            title: tr('backupExportEncrypted'),
            detail: tr('backupEncryptedSameDeviceDetail'),
            onTap: () async {
              await onExportEncrypted(showSuccess: true);
            },
          ),
          Divider(height: 1, color: p.stroke),
          _DataAction(
            icon: CupertinoIcons.arrow_down_doc,
            title: tr('backupImportEncrypted'),
            detail: tr('backupImportEncryptedDetail'),
            onTap: onImportEncrypted,
          ),
          Divider(height: 1, color: p.stroke),
          _DataAction(
            icon: CupertinoIcons.table,
            title: tr('backupExportCsv'),
            detail: tr('backupCsvPlaintextDetail'),
            onTap: () async {
              await onExportCsv(showSuccess: true);
            },
          ),
          Divider(height: 1, color: p.stroke),
          _DataAction(
            buttonKey: v17DataDeleteButtonKey,
            icon: CupertinoIcons.delete,
            title: tr('ui_e70886198cca'),
            detail: tr('backupDeleteDeviceCloudDetail'),
            tone: p.danger,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _DataAction extends StatelessWidget {
  const _DataAction({
    this.buttonKey,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final Key? buttonKey;
  final String title;
  final String detail;
  final Future<void> Function() onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = tone ?? palette.accent;
    return CupertinoButton(
      key: buttonKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: V16Type.semibold,
                    fontSize: V16Type.label,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color:
                        tone == null
                            ? palette.textMuted
                            : color.withValues(alpha: .78),
                    fontSize: V16Type.caption,
                  ),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_left, color: color, size: 17),
        ],
      ),
    );
  }
}
