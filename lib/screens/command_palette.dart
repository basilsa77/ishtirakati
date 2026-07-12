import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../theme.dart';
import 'edit_subscription_screen.dart';
import 'import_screen.dart';

enum V12Destination { home, subscriptions, insights, calendar, settings }

extension V12DestinationX on V12Destination {
  String get label => switch (this) {
        V12Destination.home => 'الرئيسية',
        V12Destination.subscriptions => 'مكتبة الاشتراكات',
        V12Destination.insights => 'التحليلات',
        V12Destination.calendar => 'جدول التجديدات',
        V12Destination.settings => 'الإعدادات',
      };

  String get shortLabel => switch (this) {
        V12Destination.home => 'الرئيسية',
        V12Destination.subscriptions => 'اشتراكاتي',
        V12Destination.insights => 'التحليلات',
        V12Destination.calendar => 'التجديدات',
        V12Destination.settings => 'الإعدادات',
      };

  IconData get icon => switch (this) {
        V12Destination.home => Icons.home_outlined,
        V12Destination.subscriptions => Icons.view_agenda_outlined,
        V12Destination.insights => Icons.query_stats_rounded,
        V12Destination.calendar => Icons.calendar_today_outlined,
        V12Destination.settings => Icons.settings_outlined,
      };
}

Future<void> showV12CommandPalette(
  BuildContext context, {
  required ValueChanged<V12Destination> onDestination,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: V12Colors.transparent,
    builder: (context) => _CommandPalette(onDestination: onDestination),
  );
}

class _CommandPalette extends StatefulWidget {
  final ValueChanged<V12Destination> onDestination;

  const _CommandPalette({required this.onDestination});

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commands = <_Command>[
      for (final destination in V12Destination.values)
        _Command(
          label: destination.label,
          detail: 'انتقال',
          icon: destination.icon,
          onTap: () {
            Navigator.pop(context);
            widget.onDestination(destination);
          },
        ),
      _Command(
        label: 'إضافة اشتراك جديد',
        detail: 'إجراء',
        icon: Icons.add_circle_outline_rounded,
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditSubscriptionScreen()),
          );
        },
      ),
      _Command(
        label: 'استيراد فواتير أو نص',
        detail: 'إجراء',
        icon: Icons.file_download_outlined,
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ImportScreen()),
          );
        },
      ),
    ];
    final normalized = _query.trim().toLowerCase();
    final visible = normalized.isEmpty
        ? commands
        : commands
            .where((item) => item.label.toLowerCase().contains(normalized))
            .toList();

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(V12Radius.signature),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: V12Space.md,
            right: V12Space.md,
            top: V12Space.md,
            bottom: MediaQuery.viewInsetsOf(context).bottom + V12Space.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.stroke,
                    borderRadius: BorderRadius.circular(V12Radius.compact),
                  ),
                ),
              ),
              const SizedBox(height: V12Space.lg),
              Text(
                'اذهب أو نفّذ',
                style: TextStyle(
                  color: context.palette.text,
                  fontSize: V12Type.title,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: V12Space.sm),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن شاشة أو إجراء…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: V12Space.md),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          'لا يوجد أمر مطابق',
                          style: TextStyle(color: context.palette.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: context.palette.stroke,
                        ),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return ListTile(
                            minTileHeight: 56,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: V12Space.xs,
                            ),
                            leading: Icon(item.icon,
                                color: context.palette.accent),
                            title: Text(item.label),
                            subtitle: Text(item.detail),
                            trailing: const Icon(Icons.arrow_back_rounded),
                            onTap: item.onTap,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Command {
  final String label;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  const _Command({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onTap,
  });
}
