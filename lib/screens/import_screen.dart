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
      final merged = [...ai, ...local.where((c) => !names.contains(c.name))];
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
      backgroundColor: p.canvas,
      appBar: AppBar(title: Text(tr('ui_c85bec9e0d7d'))),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            V16Space.ml,
            V16Space.md,
            V16Space.ml,
            V16Space.xl,
          ),
          children: [
            AppPageIntro(
              title: tr('ui_c85bec9e0d7d'),
              description: tr('ui_889c860bee20') + tr('ui_cca10b08f6ad'),
            ),
            const SizedBox(height: V16Space.lg),
            FadeSlideIn(
              child: AppCard(
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
                            Icons.auto_awesome_rounded,
                            color: p.accent,
                            size: V16Space.ml,
                          ),
                        ),
                        const SizedBox(width: V16Space.sm),
                        Expanded(
                          child: Text(
                            tr('ui_3063ba1543bf'),
                            style: TextStyle(
                              fontWeight: V16Type.semibold,
                              fontSize: V16Type.bodySmall,
                              color: p.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: V16Space.sm),
                    Text(
                      tr('ui_5bacebf257d7') +
                          tr('ui_5d19772faebc') +
                          tr('ui_5540ca8f5c45') +
                          tr('ui_991025a8bff8') +
                          tr('ui_6b6a00386b15'),
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: V16Type.labelSmall,
                        height: V16Type.bodyHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: V16Space.sm),
            AppCard(
              tone: AppCardTone.accent,
              semanticsLabel: tr('ui_3caf822da7ef'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmailLinkScreen()),
              ),
              child: Row(
                children: [
                  Container(
                    width: V16Space.xxl,
                    height: V16Space.xxl,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: V16Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(V16Radius.standard),
                    ),
                    child: const Icon(
                      Icons.alternate_email_rounded,
                      color: V16Colors.white,
                    ),
                  ),
                  const SizedBox(width: V16Space.sm),
                  Expanded(
                    child: Text(
                      tr('ui_3caf822da7ef'),
                      style: const TextStyle(
                        color: V16Colors.white,
                        fontSize: V16Type.bodySmall,
                        fontWeight: V16Type.semibold,
                        height: V16Type.bodyHeight,
                      ),
                    ),
                  ),
                  const SizedBox(width: V16Space.xs),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: V16Colors.white,
                    size: V16Space.md,
                  ),
                ],
              ),
            ),
            const SizedBox(height: V16Space.sm),
            AppCard(
              tone: AppCardTone.muted,
              elevated: false,
              padding: const EdgeInsets.symmetric(horizontal: V16Space.md),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  iconColor: p.accent,
                  collapsedIconColor: p.textMuted,
                  title: Text(
                    tr('ui_3702f9205260'),
                    style: TextStyle(
                      fontWeight: V16Type.semibold,
                      fontSize: V16Type.label,
                      color: p.text,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: V16Space.sm),
                      child: Text(
                        tr('ui_a3ab239ebeb0') +
                            tr('ui_1ae11cf6e308') +
                            tr('ui_b812c49ac2ae') +
                            tr('ui_1d7a6a07268d') +
                            tr('ui_22518f807c6c'),
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.labelSmall,
                          height: V16Type.bodyHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: V16Space.md),
            AppCard(
              elevated: false,
              padding: const EdgeInsets.all(V16Space.xs),
              child: TextField(
                controller: _text,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: tr('ui_f8a35a86c6f3') + tr('ui_2a954cd4fda0'),
                  alignLabelWithHint: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: V16Space.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackActions =
                    constraints.maxWidth < 390 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.15;
                final pasteButton = OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(V16Space.xxl),
                  ),
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(
                    Icons.content_paste_rounded,
                    size: V16Space.ml,
                  ),
                  label: Text(tr('ui_91aa1adaf1ca')),
                );
                final analyzeButton = FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(V16Space.xxl),
                  ),
                  onPressed: _aiBusy ? null : _analyzeWithAi,
                  icon: _aiBusy
                      ? const SizedBox.square(
                          dimension: V16Space.ml,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: V16Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome_rounded,
                          size: V16Space.ml,
                        ),
                  label: Text(
                    _aiBusy ? tr('ui_8c53372aebc9') : tr('ui_bcace51b5ecb'),
                  ),
                );
                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      pasteButton,
                      const SizedBox(height: V16Space.xs),
                      analyzeButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: pasteButton),
                    const SizedBox(width: V16Space.xs),
                    Expanded(child: analyzeButton),
                  ],
                );
              },
            ),
            if (_aiNote != null) ...[
              const SizedBox(height: V16Space.sm),
              AppCard(
                tone: AppCardTone.muted,
                elevated: false,
                padding: const EdgeInsets.all(V16Space.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: p.accent,
                      size: V16Space.ml,
                    ),
                    const SizedBox(width: V16Space.xs),
                    Expanded(
                      child: Text(
                        _aiNote!,
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: V16Type.labelSmall,
                          height: V16Type.bodyHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: V16Space.lg),
            if (_analyzed && !_aiBusy && _candidates.isEmpty)
              AppEmptyState(
                icon: Icons.search_off_rounded,
                title: tr('ui_fb5c2bdd515a'),
                description: tr('ui_0b1c98ff466f'),
              ),
            if (_candidates.isNotEmpty) ...[
              SectionTitle(
                tr('ui_edd53f935323', {'value0': _candidates.length}),
              ),
              for (final c in _candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: V16Space.sm),
                  child: _CandidateTile(
                    candidate: c,
                    selected: _selected.contains(c.name),
                    alreadyExists: SubscriptionStore.instance.items.any(
                      (s) => s.name == c.name,
                    ),
                    onToggle: () => setState(() {
                      if (_selected.contains(c.name)) {
                        _selected.remove(c.name);
                      } else {
                        _selected.add(c.name);
                      }
                    }),
                  ),
                ),
              const SizedBox(height: V16Space.xs),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(V16Space.xxl),
                ),
                onPressed: _selected.isEmpty ? null : _addSelected,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text(
                  tr('ui_a0357a01193b', {'value0': _selected.length}),
                ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: V16Space.sm,
        vertical: V16Space.xs,
      ),
      borderColor: selected ? p.accentStrong : null,
      elevated: false,
      onTap: alreadyExists ? null : onToggle,
      semanticsLabel: c.name,
      child: Row(
        children: [
          Checkbox(
            value: selected && !alreadyExists,
            onChanged: alreadyExists ? null : (_) => onToggle(),
            activeColor: p.accentStrong,
            checkColor: Colors.white,
          ),
          Container(
            width: V16Space.xxl,
            height: V16Space.xxl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(V16Radius.standard),
            ),
            child: Text(
              c.emoji,
              style: const TextStyle(fontSize: V16Type.title),
            ),
          ),
          const SizedBox(width: V16Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: V16Space.xs,
                  runSpacing: V16Space.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: V16Type.semibold,
                        fontSize: V16Type.bodySmall,
                        color: p.text,
                      ),
                    ),
                    if (alreadyExists)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V16Space.xs,
                          vertical: V16Space.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: p.warningSoft,
                          borderRadius: BorderRadius.circular(V16Radius.pill),
                        ),
                        child: Text(
                          tr('ui_6d86bf5cc6ce'),
                          style: TextStyle(
                            fontSize: V16Type.captionSmall,
                            fontWeight: V16Type.semibold,
                            color: p.warning,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: V16Space.xxs),
                Text(
                  details.join(' • '),
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: V16Type.caption,
                    height: V16Type.captionHeight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
