/// نطاقات الخدمات المعروفة لجلب شعاراتها الرسمية (favicon).
library;

import '../services/remote_catalog.dart';

const Map<String, String> kServiceDomains = {
  'Netflix': 'netflix.com',
  'شاهد VIP': 'shahid.mbc.net',
  'MBC Shahid': 'shahid.mbc.net',
  'FaceApp: Perfect Face Editor': 'faceapp.com',
  'STC Bank': 'stcbank.com.sa',
  'Claude by Anthropic': 'claude.ai',
  '+Snapchat': 'snapchat.com',
  'HungerStation - Food Delivery': 'hungerstation.com',
  'stc tv': 'stctv.com',
  'Jawwy TV': 'jawwy.tv',
  'OSN+': 'osnplus.com',
  'YouTube Premium': 'youtube.com',
  'أنغامي بلس': 'anghami.com',
  'Spotify Premium': 'spotify.com',
  'Apple Music': 'music.apple.com',
  'Apple TV+': 'tv.apple.com',
  'اشتراك Apple': 'apple.com',
  'Apple One': 'apple.com',
  'iCloud+': 'icloud.com',
  'Google One': 'one.google.com',
  'ChatGPT Plus': 'openai.com',
  'Claude Pro': 'claude.ai',
  'Google Gemini': 'gemini.google.com',
  'Microsoft 365': 'microsoft.com',
  'Canva Pro': 'canva.com',
  'Adobe Creative Cloud': 'adobe.com',
  'Notion': 'notion.so',
  'Dropbox': 'dropbox.com',
  'LinkedIn Premium': 'linkedin.com',
  'PlayStation Plus': 'playstation.com',
  'Xbox Game Pass': 'xbox.com',
  'Nintendo Switch Online': 'nintendo.com',
  'Steam': 'store.steampowered.com',
  'Disney+': 'disneyplus.com',
  'TOD': 'tod.tv',
  'Yango Play': 'yangoplay.com',
  'Snapchat+': 'snapchat.com',
  'X Premium': 'x.com',
  'Telegram Premium': 'telegram.org',
  'Amazon Prime': 'amazon.sa',
  'Careem Plus': 'careem.com',
  'HungerStation Plus': 'hungerstation.com',
  'Duolingo Super': 'duolingo.com',
  'STARZPLAY': 'starzplay.com',
  'Crunchyroll': 'crunchyroll.com',
  'Apple Arcade': 'apple.com',
  'Discord Nitro': 'discord.com',
  'Twitch Turbo': 'twitch.tv',
  'طلبات برو': 'talabat.com',
  'نون VIP': 'noon.com',
  'وقت اللياقة': 'fitnesstime.com.sa',
  'Headspace': 'headspace.com',
  'Calm': 'calm.com',
  'Coursera Plus': 'coursera.org',
  'NordVPN': 'nordvpn.com',
  '1Password': '1password.com',
  'Notion Plus': 'notion.so',
  'Dropbox Plus': 'dropbox.com',
};

/// رابط شعار الخدمة، أو null إن لم نعرف نطاقها.
/// الترتيب: القائمة المدمجة ← القاعدة البعيدة ← نطاق رابط الإدارة.
String? logoUrlFor(String name, String manageUrl) {
  var domain = kServiceDomains[name] ?? '';
  if (domain.isEmpty) {
    domain = RemoteCatalog.instance.domainFor(name);
  }
  if (domain.isEmpty && manageUrl.trim().isNotEmpty) {
    var raw = manageUrl.trim();
    if (!raw.startsWith('http')) raw = 'https://$raw';
    domain = Uri.tryParse(raw)?.host ?? '';
  }
  if (domain.isEmpty) return null;
  return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
}
