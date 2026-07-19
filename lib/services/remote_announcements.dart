/// إعلانات المشرف داخل التطبيق: يجلب التطبيق `catalog/announcements.json`
/// من مستودع GitHub — بنفس آلية كتالوج الخدمات وفاحص التحديثات — فتصل
/// رسائل المشرف لكل المستخدمين دون خادم إشعارات ولا رموز أجهزة ولا تتبّع.
/// تُحفظ نسخة محلية للعمل دون اتصال، وتُسجَّل الإعلانات المقروءة محليًا فقط.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminAnnouncement {
  final String id;
  final String title;
  final String body;
  final String? link;
  final String publishedAt;

  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.link,
    required this.publishedAt,
  });
}

/// يحلل JSON الإعلانات — دالة نقية قابلة للاختبار.
List<AdminAnnouncement> parseAnnouncements(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return const [];
    final list = data['announcements'];
    if (list is! List) return const [];
    final out = <AdminAnnouncement>[];
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final id = e['id'], title = e['title'], body = e['body'];
      if (id is! String || id.isEmpty) continue;
      if (title is! String || title.trim().isEmpty) continue;
      if (body is! String || body.trim().isEmpty) continue;
      final link = e['link'];
      // روابط https فقط — نفس سياسة safe_url في بقية التطبيق.
      final safeLink =
          link is String && link.startsWith('https://') ? link : null;
      out.add(
        AdminAnnouncement(
          id: id,
          title: title.trim(),
          body: body.trim(),
          link: safeLink,
          publishedAt: e['publishedAt'] is String ? e['publishedAt'] : '',
        ),
      );
      if (out.length >= 20) break;
    }
    return out;
  } catch (_) {
    return const [];
  }
}

class RemoteAnnouncements {
  RemoteAnnouncements._();

  static final RemoteAnnouncements instance = RemoteAnnouncements._();

  static const String _url =
      'https://raw.githubusercontent.com/basilsa77/ishtirakati/main/catalog/announcements.json';
  static const String _cacheKey = 'admin_announcements_cache_v1';
  static const String _seenKey = 'admin_announcements_seen_v1';

  /// يجلب الإعلانات من GitHub ويحدّث النسخة المحلية؛
  /// وعند الفشل يعيد النسخة المحفوظة.
  Future<List<AdminAnnouncement>> fetch() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final parsed = parseAnnouncements(res.body);
        if (parsed.isNotEmpty) {
          await prefs.setString(_cacheKey, res.body);
        }
        return parsed;
      }
    } catch (e) {
      debugPrint('RemoteAnnouncements: fetch failed: $e');
    }
    return parseAnnouncements(prefs.getString(_cacheKey) ?? '');
  }

  /// الإعلانات غير المقروءة بعد.
  Future<List<AdminAnnouncement>> unread() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey)?.toSet() ?? <String>{};
    final all = await fetch();
    return all.where((a) => !seen.contains(a.id)).toList(growable: false);
  }

  /// تعليم إعلان كمقروء (محليًا فقط — لا يُرسل شيء للخادم).
  Future<void> markSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? <String>[];
    if (!seen.contains(id)) {
      seen.add(id);
      await prefs.setStringList(_seenKey, seen.take(100).toList());
    }
  }
}
