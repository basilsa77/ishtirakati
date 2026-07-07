/// خدمات شائعة في السعودية والخليج لتسريع الإضافة، مع التصنيفات.
library;

class ServicePreset {
  final String name;
  final String emoji;
  final String category;
  const ServicePreset(this.name, this.emoji, this.category);
}

const List<String> kCategories = [
  'ترفيه ومشاهدة',
  'موسيقى وبودكاست',
  'إنتاجية وذكاء اصطناعي',
  'ألعاب',
  'رياضة وصحة',
  'تعليم',
  'تسوق وتوصيل',
  'اتصالات وإنترنت',
  'تخزين سحابي',
  'أخرى',
];

const Map<String, String> kCategoryEmoji = {
  'ترفيه ومشاهدة': '🎬',
  'موسيقى وبودكاست': '🎧',
  'إنتاجية وذكاء اصطناعي': '🤖',
  'ألعاب': '🎮',
  'رياضة وصحة': '💪',
  'تعليم': '📚',
  'تسوق وتوصيل': '🛍️',
  'اتصالات وإنترنت': '📶',
  'تخزين سحابي': '☁️',
  'أخرى': '🔖',
};

/// الأسعار تُترك للمستخدم لأنها تتغير باستمرار وتختلف حسب الباقة.
const List<ServicePreset> kPresets = [
  ServicePreset('شاهد VIP', '🎬', 'ترفيه ومشاهدة'),
  ServicePreset('Netflix', '🍿', 'ترفيه ومشاهدة'),
  ServicePreset('stc tv', '📺', 'ترفيه ومشاهدة'),
  ServicePreset('Jawwy TV', '📡', 'ترفيه ومشاهدة'),
  ServicePreset('OSN+', '🎞️', 'ترفيه ومشاهدة'),
  ServicePreset('YouTube Premium', '▶️', 'ترفيه ومشاهدة'),
  ServicePreset('أنغامي بلس', '🎵', 'موسيقى وبودكاست'),
  ServicePreset('Spotify Premium', '🎧', 'موسيقى وبودكاست'),
  ServicePreset('Apple Music', '🎶', 'موسيقى وبودكاست'),
  ServicePreset('iCloud+', '☁️', 'تخزين سحابي'),
  ServicePreset('Google One', '🗂️', 'تخزين سحابي'),
  ServicePreset('ChatGPT Plus', '🤖', 'إنتاجية وذكاء اصطناعي'),
  ServicePreset('Claude Pro', '✨', 'إنتاجية وذكاء اصطناعي'),
  ServicePreset('Microsoft 365', '📊', 'إنتاجية وذكاء اصطناعي'),
  ServicePreset('Canva Pro', '🎨', 'إنتاجية وذكاء اصطناعي'),
  ServicePreset('PlayStation Plus', '🎮', 'ألعاب'),
  ServicePreset('Xbox Game Pass', '🕹️', 'ألعاب'),
  ServicePreset('نادي رياضي', '🏋️', 'رياضة وصحة'),
  ServicePreset('Careem Plus', '🛵', 'تسوق وتوصيل'),
  ServicePreset('Amazon Prime', '📦', 'تسوق وتوصيل'),
  ServicePreset('باقة الجوال', '📱', 'اتصالات وإنترنت'),
  ServicePreset('إنترنت المنزل', '🌐', 'اتصالات وإنترنت'),
];
