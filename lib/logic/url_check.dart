/// Canlı yayın bağlantısı denetimi (saf Dart): yalnız https, en çok 300 karakter, javascript:/data: ve benzerleri yok.
/// Davetli sayfasındaki (assets/invite/invite.html) liveUrlOk ile aynı kurallar.

const int kLiveUrlMax = 300;
const int kLiveNoteMax = 100;

final RegExp _liveUrlChars = RegExp(r'''^https://[^\s<>"'`\\\x00-\x1f\x7f]+$''', caseSensitive: false);

/// Geçerliyse kırpılmış bağlantıyı, değilse '' döndürür.
String cleanLiveUrl(String input) {
  final u = input.trim();
  if (u.isEmpty || u.length > kLiveUrlMax || !_liveUrlChars.hasMatch(u)) return '';
  final p = Uri.tryParse(u);
  if (p == null || p.scheme.toLowerCase() != 'https' || !p.hasAuthority) return '';
  if (p.userInfo.isNotEmpty || p.host.isEmpty || !p.host.contains('.')) return '';
  return u;
}

bool isValidLiveUrl(String input) => cleanLiveUrl(input) != '';

/// Alan bırakılınca: "youtube.com/…" gibi şemasız bağlantının başına https:// ekler, http:// ise https:// yapar.
/// Başka şemalı (javascript:, data: …) ya da alan adına benzemeyen metne dokunmaz (doğrulama reddeder).
String withHttps(String input) {
  final u = input.trim();
  if (u.isEmpty) return u;
  if (u.toLowerCase().startsWith('http://')) return 'https://${u.substring(7)}';
  if (u.contains('://')) return u;
  if (u.startsWith('//')) return 'https:$u';
  final host = u.split(RegExp(r'[/?#]')).first;
  if (RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+(:\d{1,5})?$').hasMatch(host)) return 'https://$u';
  return u;
}
