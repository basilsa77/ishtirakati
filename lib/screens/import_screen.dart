/// شاشة «الاستيراد الذكي»: الصق نصًا وسنستخرج اشتراكاتك تلقائيًا.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
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
            ? tr('ui_dee07a5c1274')
            : tr('ui_229f0d67f339');
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
        _aiNote = tr('ui_b1cd86d7fe54', {'value0': ai.length});
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
        _aiNote = tr('ui_b36451274fbd', {'value0': e.message});
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
        _aiNote = tr('ui_c38305c72d90');
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
        title: Text(tr('ui_705db619b661')),
        content: Text(
          tr('ui_c11e01eb5eb6', {'value0': provider.localizedLabel}) +
          tr('ui_d230610f0657') +
          tr('ui_a4c994f880a4'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('ui_945994bd18bf')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('ui_77eea08e3919')),
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
              ? tr('ui_f0317810d9ff')
              : tr('ui_0eb9a89cc403', {'value0': count}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(tr('ui_c85bec9e0d7d'))),
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
                    tr('ui_3063ba1543bf'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: V15Type.bodySmall,
                      color: p.text,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    tr('ui_889c860bee20') +
                    tr('ui_cca10b08f6ad') +
                    tr('ui_5bacebf257d7') +
                    tr('ui_5d19772faebc') +
                    tr('ui_5540ca8f5c45') +
                    tr('ui_991025a8bff8') +
                    tr('ui_6b6a00386b15'),
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: V15Type.labelSmall,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EmailLinkScreen()),
              ),
              icon: Icon(Icons.alternate_email_rounded),
              label: Text(tr('ui_3caf822da7ef')),
            ),
            SizedBox(height: 10),
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
                    tr('ui_3702f9205260'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: V15Type.label,
                      color: p.text,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        tr('ui_a3ab239ebeb0') +
                        tr('ui_1ae11cf6e308') +
                        tr('ui_b812c49ac2ae') +
                        tr('ui_1d7a6a07268d') +
                        tr('ui_22518f807c6c'),
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V15Type.labelSmall,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14),
            TextField(
              controller: _text,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: tr('ui_f8a35a86c6f3') +
                    tr('ui_2a954cd4fda0'),
                alignLabelWithHint: true,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _pasteFromClipboard,
                    icon: Icon(Icons.content_paste_rounded, size: 20),
                    label: Text(tr('ui_91aa1adaf1ca')),
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
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(_aiBusy ? tr('ui_8c53372aebc9') : tr('ui_bcace51b5ecb')),
                  ),
                ),
              ],
            ),
            if (_aiNote != null) ...[
              SizedBox(height: 10),
              Text(
                _aiNote!,
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: V15Type.labelSmall,
                  height: 1.6,
                ),
              ),
            ],
            SizedBox(height: 18),
            if (_analyzed && !_aiBusy && _candidates.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.search_off_rounded, color: p.textMuted, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr('ui_fb5c2bdd515a') +
                        tr('ui_0b1c98ff466f'),
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
              SectionTitle(tr('ui_edd53f935323', {'value0': _candidates.length})),
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
              SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _addSelected,
                icon: Icon(Icons.playlist_add_check_rounded),
                label: Text(tr('ui_a0357a01193b', {'value0': _selected.length})),
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
        tr('ui_df146f594d3a'),
      localizedBillingCycle(c.cycle.name),
      if (c.anchor != null) tr('lastCharge', {'date': fmtDate(c.anchor!)}),
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
              child: Text(c.emoji, style: const TextStyle(fontSize: V15Type.title)),
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
                            fontSize: V15Type.bodySmall,
                            color: p.text,
                          ),
                        ),
                      ),
                      if (alreadyExists) ...[
                        SizedBox(width: 6),
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
                            tr('ui_6d86bf5cc6ce'),
                            style: TextStyle(
                              fontSize: V15Type.captionSmall,
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
                      fontSize: V15Type.caption,
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
