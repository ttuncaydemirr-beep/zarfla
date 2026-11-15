import '../data/catalog.dart';
import '../models/invitation.dart';
import 'iban.dart';
import 'lock_rules.dart';
import 'url_check.dart';

/// Yalnız rakamlar.
String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

/// WhatsApp numarası: ülke koduyla 10–15 rakam, 0 ile başlamaz (önizlemedeki kural).
bool isValidWhatsApp(String s) {
  final d = digitsOnly(s);
  return d.length >= 10 && d.length <= 15 && !d.startsWith('0');
}

/// Yayın öncesi doğrulama. Dönen harita: alan → metin anahtarı (ARB).
/// Alanlar: names, date, venue, wa, live, giftHolder, giftIban.
Map<String, String> validateInvitation(Invitation inv) {
  final e = <String, String>{};
  final couple = kCoupleTypes.contains(inv.type);
  final a = inv.n1.trim(), b = inv.n2.trim();
  if (couple ? (a.isEmpty || b.isEmpty) : a.isEmpty) {
    e['names'] = couple ? 'reqNames' : 'reqName';
  }
  if (inv.date.isEmpty || inv.time.isEmpty) e['date'] = 'reqDate';
  if (inv.venue.trim().isEmpty) e['venue'] = 'reqVenue';
  if (!isValidWhatsApp(inv.wa)) e['wa'] = 'reqWa';
  if (inv.liveUrl.trim().isNotEmpty && !isValidLiveUrl(inv.liveUrl)) e['live'] = 'streamErr';
  // Hediye IBAN'ı yalnız ücretli davetiyede; IBAN girildiyse sahibi adı zorunlu ve IBAN geçerli olmalı.
  if (isPaidInvite(inv) && inv.giftIban.trim().isNotEmpty) {
    if (cleanGiftText(inv.giftHolder, kGiftHolderMax).isEmpty) e['giftHolder'] = 'giftErrHolder';
    if (!isValidIban(inv.giftIban)) e['giftIban'] = 'giftErrIban';
  }
  return e;
}
