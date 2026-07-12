/// صفحة أدوات الذكاء الاصطناعي: المزود والمفتاح والتصنيف في مكان واحد.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_extractor.dart' show aiProviderById, kAiProviders;
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
          _aiKey.text.trim().isEmpty ? 'تم إيقاف الذكاء الاصطناعي.' : 'تم حفظ مفتاح الذكاء الاصطناعي.',
        ),
      ),
    );
  }

  Future<void> _classifyUnknowns() async {
    final store = SubscriptionStore.instance;
    if (store.aiApiKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مفتاح الذكاء الاصطناعي أولًا.')),
      );
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تصنيف الخدمات؟'),
        content: const Text(
          'سيُرسل اسم الخدمة غير المصنفة فقط إلى المزود الذي اخترته. لا تُرسل الأسعار أو الملاحظات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      final count = await store.reclassifyUnknownsWithAi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count == 0 ? 'لا توجد خدمات تحتاج تصنيفًا.' : 'تم تصنيف $count خدمات.')),
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
          'أدوات الذكاء الاصطناعي',
          style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w900),
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
                      const SizedBox(width: 9),
                      Text('استوديو الذكاء الاصطناعي', style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text('المفتاح يُحفظ على جهازك ويُستخدم فقط بعد موافقتك.', style: TextStyle(color: p.textMuted, fontSize: 12)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: store.aiProvider,
                    dropdownColor: p.surface,
                    decoration: const InputDecoration(labelText: 'المزود'),
                    items: [
                      for (final provider in kAiProviders)
                        DropdownMenuItem(value: provider.id, child: Text(provider.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) store.setAiProvider(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _aiKey,
                    obscureText: !_showKey,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'مفتاح API',
                      hintText: aiProviderById(store.aiProvider).hint,
                      suffixIcon: IconButton(
                        tooltip: _showKey ? 'إخفاء المفتاح' : 'إظهار المفتاح',
                        onPressed: () => setState(() => _showKey = !_showKey),
                        icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(aiProviderById(store.aiProvider).keyUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('إنشاء مفتاح'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        tooltip: 'حفظ المفتاح',
                        onPressed: _saveAiKey,
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: store.aiApiKey.trim().isEmpty ? null : _classifyUnknowns,
                    icon: const Icon(Icons.category_rounded, size: 18),
                    label: const Text('تصنيف الخدمات غير المعروفة'),
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
