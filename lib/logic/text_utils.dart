import '../data/catalog.dart';
import '../models/invitation.dart';

/// Dile duyarlı büyük harf. Türkçede Dart'ın toUpperCase'i i→I yapar (yanlış);
/// burada i→İ ve ı→I doğru çevrilir.
String upperFor(String s, String lang) {
  if (lang == 'tr') {
    return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
  return s.toUpperCase();
}

/// Liste ve başlıkta görünen ad (önizlemedeki title()).
String invitationTitle(Invitation inv, String untitled) {
  final a = inv.n1.trim(), b = inv.n2.trim();
  if (kCoupleTypes.contains(inv.type)) {
    if (a.isEmpty && b.isEmpty) return untitled;
    return [a, b].where((x) => x.isNotEmpty).join(' & ');
  }
  return a.isEmpty ? untitled : a;
}

/// Hazır metin çipi etiketi: 48 karakterden uzunsa 46 + '…'.
String chipLabel(String m) => m.length > 48 ? '${m.substring(0, 46)}…' : m;
