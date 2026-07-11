/// سياسة موحدة لكل رابط يفتحه التطبيق خارج الصندوق الرملي.
library;

Uri? normalizedHttpsUri(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
    return null;
  }
  final candidate = value.contains('://') ? value : 'https://$value';
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.replace(scheme: 'https');
}
