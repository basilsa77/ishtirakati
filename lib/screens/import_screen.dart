/// شاشة «الاستيراد الذكي»: الصق نصًا وسنستخرج اشتراكاتك تلقائيًا.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/subscription.dart';
import '../services/ai_extractor.dart';
import '../services/import_parser.dart';
import '../services/subscription_store.dart';
import '../theme.dart';
import 'email_link_screen.dart';

class ImportScreen extends StatefulWidget {
  /// نص مبدئي (مثلًا من ربط البريد) يُحلَّل تلقائيًا عند الفتح.
  final String? initialText;

  const ImportScreen({super.key, this.initialText});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _text = TextEditingController();
  List<ImportCandidate> _candidates = [];
  final Set<String> _selected = {};
  bool _analyzed = false;
  bool _aiBusy = false;
  String? _aiNote;

  @override
  void initState() {
    super.initState();
    final t = widget.initialText;
    if (t != null && t.trim().isNotEmpty) {
      _text.text = t;
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _analyze({bool useAi = false}) async {
    final apiKey = SubscriptionStore.instance.aiApiKey;
    final local = parseSubscriptionsText(_text.text);

    if (!useAi || apiKey.isEmpty || _text.text.trim().length < 4) {
      setState(() {
        _candidates = local;
        _selected
          ..clear()
          ..addAll(local.map((c) => c.name));
        _analyzed = true;
        _aiNote = apiKey.isEmpty
            ? 'تحليل محلي. أضف مفتاح Gemini من الإعدادات لتفعيل التحليل الاختياري.'
            : 'تحليل محلي: لا يُرسل النص إلى أي خدمة خارجية.';
      });
      return;
    }

    setState(() {
      _aiBusy = true;
      _aiNote = null;
    });
    try {
      final ai = await AiExtractor.extract(
        _text.text,
        apiKey,
        providerId: SubscriptionStore.instance.aiProvider,
      );
      // دمج: نتائج الذكاء الاصطناعي أولًا، ثم المحلي لما لم يذكره.
      final names = ai.map((c) => c.name).toSet();
      final merged = [
        ...ai,
        ...local.where((c) => !names.contains(c.name)),
      ];
      if (!mounted) return;
      setState(() {
        _aiBusy = false;
        _candidates = merged;
        _selected
          ..clear()
          ..addAll(merged.map((c) => c.name));
        _analyzed = true;
        _aiNote = 'حُلل بالذكاء الاصطناعي — ${ai.length} اشتراكًا مكتشفًا';
      });
    } on AiExtractionException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiBusy = false;
        _candidates = local;
        _selected
          ..clear()
          ..addAll(local.map((c) => c.name));
        _analyzed = true;
        _aiNote = '${e.message} — عرضنا نتائج التحليل المحلي بدلًا منه.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiBusy = false;
        _candidates = local;
        _selected
          ..clear()
          ..addAll(local.map((c) => c.name));
        _analyzed = true;
        _aiNote = 'تعذر الاتصال بالذكاء الاصطناعي — عرضنا التحليل المحلي.';
      });
    }
  }

  Future<void> _analyzeWithAi() async {
    if (_text.text.trim().length < 4) {
      await _analyze();
      return;
    }
    final provider = aiProviderById(SubscriptionStore.instance.aiProvider);
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرسال للتحليل بالذكاء الاصطناعي؟'),
        content: Text(
          'سيُرسل النص الذي ألصقته فقط إلى ${provider.label} لتحليله. '
          'لا تُرسل كلمة مرور البريد، '
          'لكن قد يحتوي النص على أسماء خدمات ومبالغ وتواريخ. يمكنك استخدام التحليل المحلي بدلًا من ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تحليل محلي'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('أوافق وأحلل'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await _analyze(useAi: approved == true);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final t = data?.text ?? '';
    if (t.isNotEmpty) {
      _text.text = t;
      _analyze();
    }
  }

  Future<void> _addSelected() async {
    final store = SubscriptionStore.instance;
    var count = 0;
    for (final c in _candidates) {
      if (!_selected.contains(c.name)) continue;
      final exists = store.items.any((s) => s.name == c.name);
      if (exists) continue;
      await store.upsert(
        c.toSubscription(fallbackCurrency: store.defaultCurrency),
      );
      count += 1;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'لم يُضف شيء — الاشتراكات المحددة موجودة مسبقًا'
              : 'تمت إضافة $count اشتراكًا — راجع الأسعار الناقصة',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('الاستيراد الذكي')),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            AppCard(
              color: p.accentSoft,
              borderColor: p.accentStrong,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كيف يعمل؟',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: p.text,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'الصق أي نص فيه اشتراكاتك وسنتعرف عليها تلقائيًا مع '
                    'أسعارها وتواريخ خصمها:\n'
                    '• رسائل البنك النصية (انسخ عدة رسائل دفعة واحدة)\n'
                    '• إيصالات Apple من بريدك «إيصالك من Apple»\n'
                    '• أو اكتب أسماء الخدمات ببساطة\n\n'
                    'التحليل المحلي لا يرسل النص خارج جهازك. تحليل Gemini اختياري '
                    'ويتطلب موافقتك قبل الإرسال.',
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmailLinkScreen()),
              ),
              icon: const Icon(Icons.alternate_email_rounded),
              label: const Text('ربط بريدي وجلب الاشتراكات تلقائيًا'),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  iconColor: p.accent,
                  collapsedIconColor: p.textMuted,
                  title: Text(
                    'أين أجد اشتراكات App Store؟',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: p.text,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '١. افتح الإعدادات ← اسمك ← الاشتراكات، وشاهد القائمة '
                        'ثم اكتب أسماءها هنا (أو صوّرها وانسخ النص من الصور).\n'
                        '٢. الأسهل: افتح بريدك وابحث عن «إيصالك من Apple»، '
                        'انسخ محتوى الإيصالات والصقها هنا — سنستخرج الخدمة '
                        'والسعر والتاريخ تلقائيًا.',
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: 13,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'الصق النص هنا...\n\n'
                    'مثال: شراء إنترنت NETFLIX.COM بمبلغ 55.99 ر.س',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 20),
                    label: const Text('لصق وتحليل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _aiBusy ? null : _analyzeWithAi,
                    icon: _aiBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(_aiBusy ? 'يحلل...' : 'تحليل AI'),
                  ),
                ),
              ],
            ),
            if (_aiNote != null) ...[
              const SizedBox(height: 10),
              Text(
                _aiNote!,
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (_analyzed && !_aiBusy && _candidates.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.search_off_rounded, color: p.textMuted, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لم نتعرف على اشتراكات في هذا النص. '
                        'جرّب لصق رسائل البنك أو إيصالات Apple كما هي.',
                        style: TextStyle(
                          color: p.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_candidates.isNotEmpty) ...[
              SectionTitle('اكتشفنا ${_candidates.length} اشتراكًا'),
              for (final c in _candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CandidateTile(
                    candidate: c,
                    selected: _selected.contains(c.name),
                    alreadyExists: SubscriptionStore.instance.items
                        .any((s) => s.name == c.name),
                    onToggle: () => setState(() {
                      if (_selected.contains(c.name)) {
                        _selected.remove(c.name);
                      } else {
                        _selected.add(c.name);
                      }
                    }),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _addSelected,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text('إضافة المحدد (${_selected.length})'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final ImportCandidate candidate;
  final bool selected;
  final bool alreadyExists;
  final VoidCallback onToggle;

  const _CandidateTile({
    required this.candidate,
    required this.selected,
    required this.alreadyExists,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = candidate;
    final catColor = categoryColor(c.category);
    final details = <String>[
      if (c.price != null)
        fmtMoney(c.price!, c.currency.isEmpty ? 'SAR' : c.currency)
      else
        'بدون سعر — عدّله لاحقًا',
      c.cycle.labelAr,
      if (c.anchor != null) 'آخر خصم ${fmtDate(c.anchor!)}',
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: selected ? p.accentStrong : null,
      child: InkWell(
        onTap: alreadyExists ? null : onToggle,
        child: Row(
          children: [
            Checkbox(
              value: selected && !alreadyExists,
              onChanged: alreadyExists ? null : (_) => onToggle(),
              activeColor: p.accent,
              checkColor: Colors.white,
            ),
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(c.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: p.text,
                          ),
                        ),
                      ),
                      if (alreadyExists) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.warningSoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            'موجود مسبقًا',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: p.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details.join(' • '),
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 12,
                    ),
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
