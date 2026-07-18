/// مصنف الخدمات: محلي أولًا، مع دعم نتائج الكتالوج البعيد.
/// لا يرسل أسماء الاشتراكات إلى أي خدمة خارجية إلا عند طلب AI صراحةً.
library;

import '../data/presets.dart';
import 'remote_catalog.dart';

class CategorySuggestion {
  final String category;
  final double confidence;
  final String source;

  const CategorySuggestion({
    required this.category,
    required this.confidence,
    required this.source,
  });
}

class CategoryClassifier {
  CategoryClassifier._();

  static String _normalize(String value) =>
      value
          .toLowerCase()
          .replaceAll(RegExp(r'[+_\-./]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  static const Map<String, String> _known = {
    'netflix': 'ترفيه ومشاهدة',
    'نتفلكس': 'ترفيه ومشاهدة',
    'نتفليكس': 'ترفيه ومشاهدة',
    'شاهد': 'ترفيه ومشاهدة',
    'shahid': 'ترفيه ومشاهدة',
    'osn': 'ترفيه ومشاهدة',
    'disney': 'ترفيه ومشاهدة',
    'youtube': 'ترفيه ومشاهدة',
    'tod': 'ترفيه ومشاهدة',
    'spotify': 'موسيقى وبودكاست',
    'سبوتيفاي': 'موسيقى وبودكاست',
    'anghami': 'موسيقى وبودكاست',
    'أنغامي': 'موسيقى وبودكاست',
    'apple music': 'موسيقى وبودكاست',
    'icloud': 'تخزين سحابي',
    'google one': 'تخزين سحابي',
    'dropbox': 'تخزين سحابي',
    'onedrive': 'تخزين سحابي',
    'chatgpt': 'إنتاجية وذكاء اصطناعي',
    'openai': 'إنتاجية وذكاء اصطناعي',
    'claude': 'إنتاجية وذكاء اصطناعي',
    'gemini': 'إنتاجية وذكاء اصطناعي',
    'canva': 'إنتاجية وذكاء اصطناعي',
    'adobe': 'إنتاجية وذكاء اصطناعي',
    'notion': 'إنتاجية وذكاء اصطناعي',
    'microsoft 365': 'إنتاجية وذكاء اصطناعي',
    'office 365': 'إنتاجية وذكاء اصطناعي',
    'playstation': 'ألعاب',
    'xbox': 'ألعاب',
    'nintendo': 'ألعاب',
    'steam': 'ألعاب',
    'careem': 'تسوق وتوصيل',
    'كريم': 'تسوق وتوصيل',
    'amazon': 'تسوق وتوصيل',
    'hungerstation': 'تسوق وتوصيل',
    'هنقرستيشن': 'تسوق وتوصيل',
    'duolingo': 'تعليم',
    'دولينجو': 'تعليم',
    'linkedin': 'إنتاجية وذكاء اصطناعي',
    'stc': 'اتصالات وإنترنت',
    'mobily': 'اتصالات وإنترنت',
    'موبايلي': 'اتصالات وإنترنت',
    'zain': 'اتصالات وإنترنت',
    'زين': 'اتصالات وإنترنت',
    'gym': 'رياضة وصحة',
    'fitness': 'رياضة وصحة',
    'نادي': 'رياضة وصحة',
    'حساب بنكي': 'مالية وفواتير',
    'فاتورة': 'مالية وفواتير',
    'تمارا': 'مالية وفواتير',
    'تابي': 'مالية وفواتير',
    'news': 'أخبار ومجلات',
    'صحيفة': 'أخبار ومجلات',
    'مجلة': 'أخبار ومجلات',
    'snapchat': 'ترفيه ومشاهدة',
    'سناب': 'ترفيه ومشاهدة',
    'telegram': 'إنتاجية وذكاء اصطناعي',
    'تيليجرام': 'إنتاجية وذكاء اصطناعي',
    'apple one': 'إنتاجية وذكاء اصطناعي',
    'apple.com bill': 'مالية وفواتير',
    'nordvpn': 'اتصالات وإنترنت',
    '1password': 'إنتاجية وذكاء اصطناعي',
    'discord': 'ألعاب',
  };

  static const Map<String, String> _keywords = {
    'مسلسل': 'ترفيه ومشاهدة',
    'فيلم': 'ترفيه ومشاهدة',
    'مشاهدة': 'ترفيه ومشاهدة',
    'موسيقى': 'موسيقى وبودكاست',
    'بودكاست': 'موسيقى وبودكاست',
    'سحابي': 'تخزين سحابي',
    'تخزين': 'تخزين سحابي',
    'ذكاء اصطناعي': 'إنتاجية وذكاء اصطناعي',
    'ألعاب': 'ألعاب',
    'لعبة': 'ألعاب',
    'توصيل': 'تسوق وتوصيل',
    'تسوق': 'تسوق وتوصيل',
    'توصيلات': 'تسوق وتوصيل',
    'إنترنت': 'اتصالات وإنترنت',
    'جوال': 'اتصالات وإنترنت',
    'اتصالات': 'اتصالات وإنترنت',
    'رياضة': 'رياضة وصحة',
    'تعليم': 'تعليم',
    'دورة': 'تعليم',
    'بنك': 'مالية وفواتير',
    'فاتورة': 'مالية وفواتير',
    'مجلة': 'أخبار ومجلات',
  };

  static CategorySuggestion suggest(
    String name, {
    List<RemoteService> remote = const [],
  }) {
    final value = _normalize(name);
    if (value.isEmpty) {
      return const CategorySuggestion(
        category: 'أخرى',
        confidence: 0,
        source: 'fallback',
      );
    }

    for (final service in remote) {
      if (_normalize(service.name) == value &&
          kCategories.contains(service.category)) {
        return CategorySuggestion(
          category: service.category,
          confidence: 1,
          source: 'catalog',
        );
      }
    }
    for (final entry in _known.entries) {
      if (value == entry.key || value.contains(entry.key)) {
        return CategorySuggestion(
          category: entry.value,
          confidence: 0.95,
          source: 'local',
        );
      }
    }
    for (final entry in _keywords.entries) {
      if (value.contains(entry.key)) {
        return CategorySuggestion(
          category: entry.value,
          confidence: 0.78,
          source: 'local',
        );
      }
    }
    return const CategorySuggestion(
      category: 'أخرى',
      confidence: 0.1,
      source: 'fallback',
    );
  }
}
