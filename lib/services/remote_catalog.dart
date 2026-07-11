/// قاعدة الخدمات المحدّثة عن بُعد: يجلب التطبيق قائمة خدمات إضافية
/// (بأسعارها التقريبية وروابط الإلغاء ونطاقات الشعارات) من مستودع GitHub —
/// فتتحدث القائمة بدون إعادة بناء التطبيق. تُحفظ نسخة محلية للعمل بدون نت.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/presets.dart';

class RemoteService {
  final String name;
  final String emoji;
  final String category;
  final String domain;
  final String manageUrl;
  final double? priceHint;

  const RemoteService({
    required this.name,
    required this.emoji,
    required this.category,
    required this.domain,
    required this.manageUrl,
    required this.priceHint,
  });
}

/// يحلل JSON القاعدة — دالة نقية قابلة للاختبار.
List<RemoteService> parseCatalog(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return const [];
    final list = data['services'];
    if (list is! List) return const [];
    final out = <RemoteService>[];
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final name = (e['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final category = (e['category'] as String?) ?? 'أخرى';
      final domain = (e['domain'] as String?) ?? '';
      final manageUrl = _validatedManageUrl(
        (e['manageUrl'] as String?) ?? '',
        domain,
      );
      out.add(RemoteService(
        name: name,
        emoji: (e['emoji'] as String?) ?? '🔖',
        category: kCategories.contains(category) ? category : 'أخرى',
        domain: domain,
        manageUrl: manageUrl,
        priceHint: (e['priceHint'] as num?)?.toDouble(),
      ));
    }
    return out;
  } catch (_) {
    return const [];
  }
}

String _validatedManageUrl(String raw, String domain) {
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return '';
  final allowed = domain.toLowerCase().trim();
  final host = uri.host.toLowerCase();
  if (allowed.isEmpty || host == allowed || host.endsWith('.$allowed')) {
    return uri.toString();
  }
  return '';
}

class RemoteCatalog extends ChangeNotifier {
  RemoteCatalog._();

  static final RemoteCatalog instance = RemoteCatalog._();

  static const String _cacheKey = 'ishtirakati_remote_catalog_v3_pinned';
  static const int _maxCatalogBytes = 512 * 1024;
  static const String catalogRevision =
      '37eb0198a6b76e65c32d70d641581b91fe7f591a';
  static const String catalogUrl =
      'https://raw.githubusercontent.com/basilsa77/ishtirakati/'
      '$catalogRevision/catalog/services.json';

  List<RemoteService> _services = [];

  List<RemoteService> get services => List.unmodifiable(_services);

  RemoteService? byName(String name) {
    final normalized = name.toLowerCase().trim();
    for (final s in _services) {
      if (s.name.toLowerCase().trim() == normalized) return s;
    }
    return null;
  }

  /// نطاق الشعار لخدمة معيّنة (من القاعدة البعيدة).
  String domainFor(String name) => byName(name)?.domain ?? '';

  /// يُحمّل من الذاكرة المحلية فورًا ثم يحدّث من الإنترنت في الخلفية.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _services = parseCatalog(cached);
        notifyListeners();
      }
      final res = await http
          .get(Uri.parse(catalogUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 &&
          res.bodyBytes.isNotEmpty &&
          res.bodyBytes.length <= _maxCatalogBytes) {
        final parsed = parseCatalog(res.body);
        if (parsed.isNotEmpty) {
          _services = parsed;
          await prefs.setString(_cacheKey, res.body);
          notifyListeners();
        }
      }
    } catch (_) {
      // بدون إنترنت: نكمل بالنسخة المحلية أو بالقائمة المدمجة.
    }
  }
}
