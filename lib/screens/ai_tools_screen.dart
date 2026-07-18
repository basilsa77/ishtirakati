/// صفحة أدوات الذكاء الاصطناعي: المزود والمفتاح والتصنيف في مكان واحد.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/ai_extractor.dart'
    show LocalizedAiProviderInfo, aiProviderById, kAiProviders;
import '../services/subscription_store.dart';
import '../theme.dart';

class AiToolsScreen extends StatefulWidget {
  const AiToolsScreen({super.key});

  @override
  State<AiToolsScreen> createState() => _AiToolsScreenState();
}

class _AiToolsScreenState extends State<AiToolsScreen> {
  late final TextEditingController _aiKey;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _aiKey = TextEditingController(text: SubscriptionStore.instance.aiApiKey);
  }

  @override
  void dispose() {
    _aiKey.dispose();
    super.dispose();
  }

  Future<void> _saveAiKey() async {
    try {
      await SubscriptionStore.instance.setAiApiKey(_aiKey.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('ui_c38305c72d90'))));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _aiKey.text.trim().isEmpty
              ? tr('ui_38317d82302b')
              : tr('ui_b50e4e22cdb6'),
        ),
      ),
    );
  }

  Future<void> _classifyUnknowns() async {
    final store = SubscriptionStore.instance;
    if (store.aiApiKey.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('ui_a4959fcedf25'))));
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(tr('ui_eef371eb1d45')),
            content: Text(tr('ui_082d038f71f9')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('ui_9a30dc2a96b8')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('ui_322b7b613468')),
              ),
            ],
          ),
    );
    if (approved != true) return;
    try {
      final count = await store.reclassifyUnknownsWithAi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? tr('ui_d1cd2db743db')
                : tr('ui_50ccfb7bccbb', {'value0': count}),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('ui_c38305c72d90'))));
    }
  }

  Future<void> _openProviderKeyPage(String providerId) async {
    final uri = Uri.parse(aiProviderById(providerId).keyUrl);
    if (uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = SubscriptionStore.instance;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: p.canvas,
        elevation: 0,
        centerTitle: true,
        title: Text(
          tr('ui_6ec927377748'),
          style: TextStyle(
            color: p.text,
            fontSize: V16Type.body,
            fontWeight: V16Type.semibold,
          ),
        ),
        iconTheme: IconThemeData(color: p.text),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder:
            (context, _) => ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                V16Space.ml,
                V16Space.md,
                V16Space.ml,
                V16Space.xxl,
              ),
              children: [
                AppPageIntro(
                  title: tr('ui_973e33017592'),
                  description: tr('ui_19cfaabab144'),
                ),
                const SizedBox(height: V16Space.lg),
                FadeSlideIn(
                  child: AppCard(
                    tone: AppCardTone.accent,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: V16Space.xxl,
                          height: V16Space.xxl,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: V16Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(
                              V16Radius.standard,
                            ),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: V16Colors.white,
                          ),
                        ),
                        const SizedBox(width: V16Space.sm),
                        Expanded(
                          child: Text(
                            tr('ui_082d038f71f9'),
                            style: const TextStyle(
                              color: V16Colors.white,
                              fontSize: V16Type.labelSmall,
                              height: V16Type.bodyHeight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: V16Space.sm),
                AppCard(
                  elevated: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: store.aiProvider,
                        dropdownColor: p.surface,
                        decoration: InputDecoration(
                          labelText: tr('ui_cc2eabfd9f3a'),
                        ),
                        items: [
                          for (final provider in kAiProviders)
                            DropdownMenuItem(
                              value: provider.id,
                              child: Text(provider.localizedLabel),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) store.setAiProvider(value);
                        },
                      ),
                      const SizedBox(height: V16Space.sm),
                      TextField(
                        controller: _aiKey,
                        obscureText: !_showKey,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: tr('ui_b0f1d5fd42e0'),
                          hintText: aiProviderById(store.aiProvider).hint,
                          suffixIcon: IconButton(
                            tooltip:
                                _showKey
                                    ? tr('ui_a4d2edd73560')
                                    : tr('ui_1832fb9316dc'),
                            onPressed:
                                () => setState(() => _showKey = !_showKey),
                            icon: Icon(
                              _showKey
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: V16Space.sm),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stackActions =
                              constraints.maxWidth < 340 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.2;
                          final keyButton = OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(V16Space.xxl),
                            ),
                            onPressed:
                                () => _openProviderKeyPage(store.aiProvider),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: V16Space.ml,
                            ),
                            label: Text(tr('ui_7d7b50eb8777')),
                          );
                          final saveButton = FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(V16Space.xxl),
                            ),
                            onPressed: _saveAiKey,
                            icon: const Icon(Icons.check_rounded),
                            label: Text(tr('ui_2157a38aeffc')),
                          );
                          if (stackActions) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                keyButton,
                                const SizedBox(height: V16Space.xs),
                                saveButton,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: keyButton),
                              const SizedBox(width: V16Space.xs),
                              Expanded(child: saveButton),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: V16Space.sm),
                AppCard(
                  tone: AppCardTone.muted,
                  elevated: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: V16Space.xl,
                            height: V16Space.xl,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              borderRadius: BorderRadius.circular(
                                V16Radius.compact,
                              ),
                            ),
                            child: Icon(
                              Icons.category_outlined,
                              color: p.accent,
                              size: V16Space.ml,
                            ),
                          ),
                          const SizedBox(width: V16Space.sm),
                          Expanded(
                            child: Text(
                              tr('ui_6e9a9b882540'),
                              style: TextStyle(
                                color: p.text,
                                fontSize: V16Type.bodySmall,
                                fontWeight: V16Type.semibold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: V16Space.sm),
                      Text(
                        tr('ui_082d038f71f9'),
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.labelSmall,
                          height: V16Type.bodyHeight,
                        ),
                      ),
                      const SizedBox(height: V16Space.md),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(V16Space.xxl),
                        ),
                        onPressed:
                            store.aiApiKey.trim().isEmpty
                                ? null
                                : _classifyUnknowns,
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          size: V16Space.ml,
                        ),
                        label: Text(tr('ui_6e9a9b882540')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
