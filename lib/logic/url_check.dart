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
