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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _aiKey.text.trim().isEmpty ? tr('ui_38317d82302b') : tr('ui_b50e4e22cdb6'),
        ),
      ),
    );
  }

  Future<void> _classifyUnknowns() async {
    final store = SubscriptionStore.instance;
    if (store.aiApiKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('ui_a4959fcedf25'))),
      );
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('ui_eef371eb1d45')),
        content: Text(
          tr('ui_082d038f71f9'),
        ),
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
        SnackBar(content: Text(count == 0 ? tr('ui_d1cd2db743db') : tr('ui_50ccfb7bccbb', {'value0': count}))),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
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
          style: TextStyle(color: p.text, fontSize: V15Type.titleSmall, fontWeight: FontWeight.w900),
        ),
        iconTheme: IconThemeData(color: p.text),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            AppCard(
              color: p.surfaceAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: p.accent),
                      SizedBox(width: 9),
                      Text(tr('ui_973e33017592'), style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: V15Type.bodySmall)),
                    ],
                  ),
                  SizedBox(height: 7),
                  Text(tr('ui_19cfaabab144'), style: TextStyle(color: p.textMuted, fontSize: V15Type.caption)),
                  SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: store.aiProvider,
                    dropdownColor: p.surface,
                    decoration: InputDecoration(labelText: tr('ui_cc2eabfd9f3a')),
                    items: [
                      for (final provider in kAiProviders)
                        DropdownMenuItem(value: provider.id, child: Text(provider.localizedLabel)),
                    ],
                    onChanged: (value) {
                      if (value != null) store.setAiProvider(value);
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _aiKey,
                    obscureText: !_showKey,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('ui_b0f1d5fd42e0'),
                      hintText: aiProviderById(store.aiProvider).hint,
                      suffixIcon: IconButton(
                        tooltip: _showKey ? tr('ui_a4d2edd73560') : tr('ui_1832fb9316dc'),
                        onPressed: () => setState(() => _showKey = !_showKey),
                        icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(aiProviderById(store.aiProvider).keyUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(tr('ui_7d7b50eb8777')),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton.filled(
                        tooltip: tr('ui_2157a38aeffc'),
                        onPressed: _saveAiKey,
                        icon: Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: store.aiApiKey.trim().isEmpty ? null : _classifyUnknowns,
                    icon: Icon(Icons.category_rounded, size: 18),
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
