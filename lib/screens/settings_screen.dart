/// إعدادات الإصدار 8: مجموعات قصيرة واضحة من دون صفحات متراكبة.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart' show currencySymbols;
import '../l10n/app_localizations.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../services/firestore_connection_diagnostics.dart';
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _budget;

  @override
  void initState() {
    super.initState();
    final store = SubscriptionStore.instance;
    final budget = store.monthlyBudget;
    _budget = TextEditingController(
      text: budget <= 0
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
    final store = SubscriptionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _SettingsIntro(),
          if (!store.storageHealthy) ...[
            const SizedBox(height: 14),
            AppCard(
              color: context.palette.dangerSoft,
              borderColor: context.palette.danger,
              child: Text(
                store.storageError ?? tr('ui_8fb06d4b1479'),
                style: TextStyle(
                  color: context.palette.danger,
                  fontWeight: FontWeight.w800,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
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
                      final permitted = await NotificationService.instance.requestPermission();
                      if (!permitted && context.mounted) {
                        await showCupertinoDialog<void>(
                          context: context,
                          builder: (dialogContext) => CupertinoAlertDialog(
                            title: Text(tr('ui_b6d4d093c09d')),
                            content: Text(tr('ui_7459d276bf09')),
                            actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('ui_a64b3d93816b')))],
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
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const ImportScreen()),
                  ),
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsAction(
                  icon: Icons.alternate_email_rounded,
                  title: tr('ui_c4d54697418a'),
                  detail: tr('ui_05c130b7df4a'),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const EmailLinkScreen()),
                  ),
                ),
                Divider(height: 1, color: context.palette.stroke),
                _SettingsAction(
                  icon: Icons.auto_awesome_rounded,
                  title: tr('ui_6ec927377748'),
                  detail: tr('ui_6e55c742696f'),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const AiToolsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _SettingsLabel(tr('ui_b4fba865ed46')),
          const SizedBox(height: 10),
          _DataCard(onDelete: _confirmWipe),
          const SizedBox(height: 26),
          _SettingsLabel(tr('ui_db69cd4d6275')),
          const SizedBox(height: 10),
          const _AboutCard(),
          const SizedBox(height: 30),
          Center(
            child: Text(
              tr('ui_ed185d7957db'),
              style: TextStyle(color: context.palette.textMuted, fontSize: V15Type.labelSmall, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBudget() async {
    final value = double.tryParse(
          _budget.text.trim().replaceAll(tr('ui_bc4d631526af'), '.').replaceAll(',', '.'),
        ) ??
        0;
    await SubscriptionStore.instance.setMonthlyBudget(value);
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(value <= 0 ? tr('ui_46e83de05124') : tr('ui_e7311dcecd04')),
        actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('ui_3ef541b90a31')))],
      ),
    );
  }

  Future<void> _confirmWipe() async {
    final confirmed = await showIosConfirmation(
      context: context,
      title: tr('ui_6d5931ec133b'),
      message: tr('ui_5e32a3fb9f4d'),
      confirmLabel: tr('ui_cd6f896cc0ee'),
      destructive: true,
    );
    if (!confirmed) return;
    await SubscriptionStore.instance.clearAll();
    if (mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          content: Text(tr('ui_2753acf39a49')),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('ui_3ef541b90a31')))],
        ),
      );
    }
  }

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
      builder: (_) => PopScope(
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
      final message = error is AuthException
          ? error.message
          : tr('ui_1b4978e420cd');
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(tr('ui_c9f721ee4fd2')),
          content: Text(message),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('ui_a64b3d93816b')))],
        ),
      );
    }
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('ui_5fd9563e6846'), style: TextStyle(color: p.text, fontSize: V15Type.headline, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(tr('ui_58d077f29d61'), style: TextStyle(color: p.textMuted, fontSize: V15Type.labelSmall)),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final VoidCallback onChanged;
  final Future<void> Function() onDeleteAccount;

  const _AccountCard({
    required this.onChanged,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final signedIn = AuthService.isSignedIn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(CupertinoIcons.cloud, color: p.accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('ui_0458a671e96c'), style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: V15Type.bodySmall)),
                    const SizedBox(height: 3),
                    Text(
                      !AuthService.isAvailable
                          ? tr('ui_0380d88f6407')
                          : signedIn
                              ? AuthService.userEmail
                              : tr('ui_02776b074d68'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textMuted, fontSize: V15Type.caption),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!signedIn)
            CupertinoButton.filled(
              onPressed: !AuthService.isAvailable
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const LoginScreen(fromSettings: true)),
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
                            builder: (dialogContext) => CupertinoAlertDialog(
                              content: Text(error.message),
                              actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('ui_a64b3d93816b')))],
                            ),
                          );
                        }
                      },
                      child: Icon(CupertinoIcons.square_arrow_right, color: p.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<CloudSyncStatus>(
                  valueListenable: CloudSync.status,
                  builder: (context, status, _) {
                    final (icon, text, color) = switch (status.phase) {
                      CloudSyncPhase.syncing => (
                           CupertinoIcons.arrow_2_circlepath,
                           tr('ui_990fa33ab762'),
                          p.accent,
                        ),
                      CloudSyncPhase.success => (
                           CupertinoIcons.check_mark_circled,
                          status.message ?? _syncSuccessText(status.updatedAt),
                          p.accent,
                        ),
                      CloudSyncPhase.failure => (
                           CupertinoIcons.exclamationmark_circle,
                           status.message ??
                               tr('ui_9326a71f2574'),
                          p.danger,
                        ),
                      CloudSyncPhase.idle => (
                           CupertinoIcons.cloud,
                           tr('ui_72bd581dc069'),
                          p.textMuted,
                        ),
                    };
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, color: color, size: 17),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: color,
                                  fontSize: V15Type.caption,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (CloudSync.internalDiagnosticsEnabled &&
                            status.operation != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            tr('cloudSyncDiagnostic', {
                              'operation': status.operation ?? '-',
                              'code': status.firebaseCode ?? '-',
                              'exists': status.documentExisted?.toString() ?? '-',
                              'revision': status.revision?.toString() ?? '-',
                              'commit': kGitCommitShort,
                            }),
                            style: TextStyle(
                              color: p.textMuted,
                              fontSize: V15Type.caption,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (FirestoreConnectionDiagnostics.enabled) ...[
                          const SizedBox(height: 10),
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                FirestoreConnectionDiagnostics.running,
                            builder: (context, running, _) =>
                                CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              color: p.accentSoft,
                              onPressed: running
                                  ? null
                                  : FirestoreConnectionDiagnostics.run,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (running)
                                    const CupertinoActivityIndicator()
                                  else
                                    Icon(
                                      CupertinoIcons.antenna_radiowaves_left_right,
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
                                      fontSize: V15Type.caption,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ValueListenableBuilder<
                              FirestoreConnectionDiagnostic?>(
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
                  child: Text(tr('ui_70f341498d46'), style: TextStyle(color: p.danger)),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            tr('ui_87621ec0d18d'),
            style: TextStyle(color: p.textMuted, fontSize: V15Type.caption, height: 1.6),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: AuthService.appCheckWarning,
            builder: (context, warning, _) {
              if (warning == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gpp_maybe_rounded, color: p.danger, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: p.danger,
                          fontSize: V15Type.caption,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('firestoreDiagnosticRestTitle'),
            style: TextStyle(
              color: p.text,
              fontSize: V15Type.bodySmall,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticHttpStatus'),
            value: rest.httpStatus?.toString() ?? '-',
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
            value: '${rest.elapsed.inMilliseconds} ms',
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
              fontSize: V15Type.bodySmall,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticSucceeded'),
            value: _yesNo(native.succeeded),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDocumentExists'),
            value: native.documentExists == null
                ? '-'
                : _yesNo(native.documentExists!),
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticFirebaseCode'),
            value: native.firebaseCode ?? '-',
          ),
          _DiagnosticLine(
            label: tr('firestoreDiagnosticDuration'),
            value: '${native.elapsed.inMilliseconds} ms',
          ),
          if (native.safeMessage != null) ...[
            const SizedBox(height: 5),
            Text(
              native.safeMessage!,
              style: TextStyle(
                color: p.textMuted,
                fontSize: V15Type.caption,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _diagnosticConclusion(result),
            style: TextStyle(
              color: p.accent,
              fontSize: V15Type.caption,
              fontWeight: FontWeight.w700,
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
        FirestoreRestOutcome.missingDocument =>
          tr('firestoreDiagnosticRest404'),
        FirestoreRestOutcome.unauthenticated =>
          tr('firestoreDiagnosticRest401'),
        FirestoreRestOutcome.permissionDenied =>
          tr('firestoreDiagnosticRest403'),
        FirestoreRestOutcome.invalidTarget =>
          tr('firestoreDiagnosticRest400'),
        FirestoreRestOutcome.rateLimited =>
          tr('firestoreDiagnosticRest429'),
        FirestoreRestOutcome.serviceFailure =>
          tr('firestoreDiagnosticRest5xx'),
        FirestoreRestOutcome.dnsFailure => tr('firestoreDiagnosticDnsFailed'),
        FirestoreRestOutcome.socketFailure =>
          tr('firestoreDiagnosticSocketFailed'),
        FirestoreRestOutcome.tlsFailure => tr('firestoreDiagnosticTlsFailed'),
        FirestoreRestOutcome.timeout => tr('firestoreDiagnosticTimedOut'),
        FirestoreRestOutcome.clientFailure =>
          tr('firestoreDiagnosticClientFailed'),
        FirestoreRestOutcome.noUser => tr('firestoreDiagnosticNoUser'),
        FirestoreRestOutcome.tokenFailure =>
          tr('firestoreDiagnosticTokenFailed'),
        FirestoreRestOutcome.unexpectedFailure =>
          tr('firestoreDiagnosticUnexpected'),
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
              style: TextStyle(
                color: p.textMuted,
                fontSize: V15Type.caption,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: p.text,
                fontSize: V15Type.caption,
                fontWeight: FontWeight.w700,
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
        style: TextStyle(color: context.palette.textMuted, fontSize: V15Type.caption, fontWeight: FontWeight.w900),
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
                Text(title, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: V15Type.label)),
                const SizedBox(height: 3),
                Text(detail, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
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
                  Text(title, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: V15Type.label)),
                  const SizedBox(height: 3),
                  Text(detail, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
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
              Text(tr('ui_b6775a5543d9'), style: TextStyle(color: p.text, fontSize: V15Type.bodySmall, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 7),
          Text(tr('ui_bf208c21fb03'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  placeholder: '0',
                  suffix: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Text(currencySymbols[currency] ?? currency, style: TextStyle(color: p.textMuted)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(11), border: Border.all(color: p.stroke)),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.all(11),
                color: p.accent,
                onPressed: onSave,
                child: const Icon(CupertinoIcons.check_mark, color: CupertinoColors.white),
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
          _AboutLine(label: tr('ui_d83483faf7f9'), value: tr('ui_64e2da14cf04')),
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
            onPressed: () => launchUrl(
              Uri.parse(
                'https://github.com/basilsa77/ishtirakati/blob/main/PRIVACY_POLICY.md',
              ),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(tr('ui_23a13bc51d58'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: V15Type.labelSmall))),
                  Icon(CupertinoIcons.arrow_up_right_square, color: p.textMuted, size: 18),
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
          Text(label, style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
          const Spacer(),
          Text(value, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: V15Type.labelSmall)),
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
          Text(context.l10n.text('settingsAppearanceTitle'), style: TextStyle(color: p.text, fontSize: V15Type.label, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(context.l10n.text('settingsAppearanceDescription'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: store.themeMode,
              backgroundColor: p.surfaceAlt,
              thumbColor: p.accent,
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
              fontSize: V15Type.label,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.text('languageDescription'),
            style: TextStyle(
              color: p.textMuted,
              fontSize: V15Type.caption,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: store.languageMode,
              backgroundColor: p.surfaceAlt,
              thumbColor: p.accent,
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
              fontSize: V15Type.caption,
              fontWeight: FontWeight.w800,
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
                color: selected
                    ? CupertinoColors.white
                    : context.palette.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? CupertinoColors.white
                      : context.palette.text,
                  fontSize: V15Type.caption,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

/// إدارة البيانات: حذف السجل من الجهاز.
class _DataCard extends StatelessWidget {
  final Future<void> Function() onDelete;

  const _DataCard({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        onPressed: onDelete,
        child: Row(
          children: [
            Icon(CupertinoIcons.delete, color: p.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('ui_e70886198cca'), style: TextStyle(color: p.danger, fontWeight: FontWeight.w800, fontSize: V15Type.label)),
                  const SizedBox(height: 3),
                  Text(tr('ui_a5571e3ecfb5'), style: TextStyle(color: p.danger.withValues(alpha: .75), fontSize: V15Type.caption)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_left, color: p.danger, size: 17),
          ],
        ),
      ),
    );
  }
}
