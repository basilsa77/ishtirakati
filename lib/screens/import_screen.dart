/// شاشة «الاستيراد الذكي»: الصق نصًا وسنستخرج اشتراكاتك تلقائيًا.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/subscription.dart';
import '../services/import_parser.dart';
import '../services/subscription_store.dart';
import '../theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _text = TextEditingController();
  List<ImportCandidate> _candidates = [];
  final Set<String> _selected = {};
  bool _analyzed = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _analyze() {
    final results = parseSubscriptionsText(_text.text);
    setState(() {
      _candidates = results;
      _selected
        ..clear()
        ..addAll(results.map((c) => c.name));
      _analyzed = true;
    });
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
              : 'تمت إضافة $count اشتراكًا 🎉 — راجع الأسعار الناقصة',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاستيراد الذكي ✨')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppCard(
              color: AppColors.primarySoft,
              borderColor: AppColors.primaryDeep,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'كيف يعمل؟',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'الصق أي نص فيه اشتراكاتك وسنتعرف عليها تلقائيًا مع '
                    'أسعارها وتواريخ خصمها:\n'
                    '• رسائل البنك النصية (انسخ عدة رسائل دفعة واحدة)\n'
                    '• إيصالات Apple من بريدك «إيصالك من Apple»\n'
                    '• أو اكتب أسماء الخدمات ببساطة',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
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
                child: const ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  iconColor: AppColors.primary,
                  collapsedIconColor: AppColors.muted,
                  title: Text(
                    '🍎 أين أجد اشتراكات App Store؟',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.ink,
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
                          color: AppColors.muted,
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
                    onPressed: _analyze,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: const Text('تحليل النص'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_analyzed && _candidates.isEmpty)
              const AppCard(
                child: Row(
                  children: [
                    Text('🔍', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لم نتعرف على اشتراكات في هذا النص. '
                        'جرّب لصق رسائل البنك أو إيصالات Apple كما هي.',
                        style: TextStyle(
                          color: AppColors.muted,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_candidates.isNotEmpty) ...[
              SectionTitle(
                'اكتشفنا ${_candidates.length} اشتراكًا',
                emoji: '🎯',
              ),
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
      borderColor: selected ? AppColors.primaryDeep : null,
      child: InkWell(
        onTap: alreadyExists ? null : onToggle,
        child: Row(
          children: [
            Checkbox(
              value: selected && !alreadyExists,
              onChanged: alreadyExists ? null : (_) => onToggle(),
              activeColor: AppColors.primary,
              checkColor: const Color(0xFF06231A),
            ),
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.15),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: AppColors.ink,
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
                            color: AppColors.goldSoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            'موجود مسبقًا',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details.join(' • '),
                    style: const TextStyle(
                      color: AppColors.muted,
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
