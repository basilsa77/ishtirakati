/// البحث الذكي عن التطبيقات: iTunes Search API المجاني (بدون مفتاح)
/// لجلب الاسم الرسمي والشعار الحقيقي لأي تطبيق أثناء الإضافة.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class AppSearchResult {
  final String name;
  final String iconUrl;
  final String seller;

  const AppSearchResult({
    required this.name,
    required this.iconUrl,
    required this.seller,
  });
}

/// يحلل رد iTunes — دالة نقية قابلة للاختبار.
List<AppSearchResult> parseItunesResults(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return const [];
    final list = data['results'];
    if (list is! List) return const [];
    final out = <AppSearchResult>[];
    final seen = <String>{};
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final name = ((e['trackName'] as String?) ?? '').trim();
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
      out.add(AppSearchResult(
        name: name,
        iconUrl: (e['artworkUrl100'] as String?) ??
            (e['artworkUrl60'] as String?) ??
            '',
        seller: (e['sellerName'] as String?) ?? '',
      ));
    }
    return out;
  } catch (_) {
    return const [];
  }
}

class ItunesSearch {
  static Future<List<AppSearchResult>> search(String term) async {
    final uri = Uri.parse(
      'https://itunes.apple.com/search'
      '?term=${Uri.encodeQueryComponent(term)}'
      '&entity=software&limit=6&country=sa',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return const [];
    return parseItunesResults(utf8.decode(res.bodyBytes));
  }
}
