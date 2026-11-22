import '../data/catalog.dart';

/// Etkinlik türü listesinin arayüz diline göre sırası.
///
/// Tüm türler her dilde seçilebilir kalır; yalnız sıra değişir. İspanyolca / Portekizce / Endonezce arayüzde
/// herkesin tanıdığı genel türler (düğün, nişan, doğum günü, baby shower, mezuniyet…) üstte, Türkiye'ye özgü
/// türler (kına, sünnet, mevlit, söz, diş buğdayı, asker uğurlama…) altta çıkar. Endonezce'de Müslüman çoğunluk
/// nedeniyle nikâh, iftar, sünnet, mevlit ve kına genel türlerden hemen sonra gelir. "diger" her zaman sonda.
/// Tanımsız dillerde (tr/en/de/ar) katalog sırası aynen korunur.
const List<String> _generic = [
  'dugun', 'nisan', 'dogum', 'baby', 'cinsiyet', 'mezuniyet', 'yildonumu', 'bekarliga', 'evacilisi', 'kurumsal',
];

const Map<String, List<String>> kTypeOrderByLang = {
  'es': [..._generic, 'kina', 'nikah', 'iftar', 'soz', 'sunnet', 'mevlit', 'disbugdayi', 'asker', 'diger'],
  'pt': [..._generic, 'kina', 'nikah', 'iftar', 'soz', 'sunnet', 'mevlit', 'disbugdayi', 'asker', 'diger'],
  'id': [..._generic, 'nikah', 'iftar', 'sunnet', 'mevlit', 'kina', 'soz', 'disbugdayi', 'asker', 'diger'],
};

/// [lang] için sıralı tür listesi; her zaman [kEventTypes] ile aynı küme (eksik kalan olursa sona eklenir).
List<String> eventTypesFor(String lang) {
  final order = kTypeOrderByLang[lang];
  if (order == null) return kEventTypes;
  final out = <String>[for (final t in order) if (kEventTypes.contains(t)) t];
  for (final t in kEventTypes) {
    if (!out.contains(t)) out.add(t);
  }
  return out;
}
