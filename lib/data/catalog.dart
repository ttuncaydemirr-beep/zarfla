// OTOMATİK ÜRETİLDİ: onaylı web önizlemesindeki (davetiye/index.html) THEMES, REC,
// TYPES, COUPLE ve MSGS sabitlerinden birebir aktarıldı. Değiştirirseniz
// assets/invite/invite.html içindeki THEMES ile aynı tutun.
import 'dart:ui' show Color;

/// Etkinlik türleri (önizlemedeki TYPES sırası).
const List<String> kEventTypes = ["nisan", "dugun", "kina", "soz", "sunnet", "dogum", "baby", "diger"];

/// İki isimli (çift) etkinlik türleri.
const Set<String> kCoupleTypes = {"nisan", "dugun", "kina", "soz"};

const List<String> kLayouts = ['klasik', 'kemer', 'monogram', 'editoryal', 'kartpostal', 'zamancizelgesi', 'bilet'];
const List<String> kOpenings = ['door', 'env', 'perde', 'kitap', 'muhur', 'isik'];
const List<String> kLangs = ['tr', 'en', 'de', 'ar'];
const Map<String, String> kLangNames = {'tr': 'Türkçe', 'en': 'English', 'de': 'Deutsch', 'ar': 'العربية'};
const int kMaxGallery = 6;
const int kMaxSteps = 6;

class InviteColors {
  const InviteColors({required this.bg, required this.paper, required this.ink, required this.muted, required this.accent, required this.onAccent, required this.gold, required this.line, required this.ring, required this.err, required this.door1, required this.door2, required this.doorLine, required this.leaf});
  final Color bg, paper, ink, muted, accent, onAccent, gold, line, ring, err, door1, door2, doorLine, leaf;
}

class InviteTheme {
  const InviteTheme({required this.id, required this.name, required this.premium, required this.orn, required this.fall, required this.colors, required this.css});
  final String id;
  final Map<String, String> name;
  final bool premium;
  /// Süs sembolü: assets/ornaments/<orn>.svg
  final String orn;
  final String fall;
  final InviteColors colors;
  /// Özgün CSS renk dizeleri (SVG küçük resimleri için).
  final Map<String, String> css;
  String nameIn(String lang) => name[lang] ?? name['en'] ?? id;
}

const Map<String, InviteTheme> kThemes = {
  "papatya": InviteTheme(id: "papatya", name: {"tr": "Papatya", "en": "Daisy", "de": "Gänseblümchen", "ar": "الأقحوان"}, premium: false, orn: "o-papatya", fall: "o-papatya", colors: InviteColors(bg: Color(0xFFFBF8F1), paper: Color(0xFFFFFDF8), ink: Color(0xFF3B3A33), muted: Color(0xFF66634F), accent: Color(0xFF3F5A40), onAccent: Color(0xFFFFFFFF), gold: Color(0xFFB7860F), line: Color(0xFFE6DFCD), ring: Color(0x2E3F5A40), err: Color(0xFFA2543A), door1: Color(0xFF9DB398), door2: Color(0xFF7A9475), doorLine: Color(0x80FFFFFF), leaf: Color(0xFF8FA58A)), css: {"bg": "#fbf8f1", "paper": "#fffdf8", "ink": "#3b3a33", "muted": "#66634f", "accent": "#3f5a40", "onAccent": "#ffffff", "gold": "#b7860f", "line": "#e6dfcd", "ring": "rgba(63,90,64,.18)", "err": "#a2543a", "door1": "#9db398", "door2": "#7a9475", "doorLine": "rgba(255,255,255,.5)", "leaf": "#8fa58a"}),
  "altin": InviteTheme(id: "altin", name: {"tr": "Altın Gece", "en": "Golden Night", "de": "Goldene Nacht", "ar": "الليلة الذهبية"}, premium: true, orn: "o-yildiz", fall: "o-yildiz", colors: InviteColors(bg: Color(0xFF121829), paper: Color(0xFF1B2238), ink: Color(0xFFF3EAD8), muted: Color(0xFFCBBFA5), accent: Color(0xFFE0BD6A), onAccent: Color(0xFF121829), gold: Color(0xFFE0BD6A), line: Color(0x52E0BD6A), ring: Color(0x40E0BD6A), err: Color(0xFFF0A58F), door1: Color(0xFF26304F), door2: Color(0xFF141A2E), doorLine: Color(0x8CE0BD6A), leaf: Color(0xFFC9A24A)), css: {"bg": "#121829", "paper": "#1b2238", "ink": "#f3ead8", "muted": "#cbbfa5", "accent": "#e0bd6a", "onAccent": "#121829", "gold": "#e0bd6a", "line": "rgba(224,189,106,.32)", "ring": "rgba(224,189,106,.25)", "err": "#f0a58f", "door1": "#26304f", "door2": "#141a2e", "doorLine": "rgba(224,189,106,.55)", "leaf": "#c9a24a"}),
  "kina": InviteTheme(id: "kina", name: {"tr": "Kına Kırmızısı", "en": "Henna Red", "de": "Henna-Rot", "ar": "أحمر الحناء"}, premium: true, orn: "o-lale", fall: "o-lale", colors: InviteColors(bg: Color(0xFFF8EFE6), paper: Color(0xFFFFFAF4), ink: Color(0xFF3A1D1F), muted: Color(0xFF6B4A45), accent: Color(0xFF8A1C2B), onAccent: Color(0xFFFFFFFF), gold: Color(0xFFA87B22), line: Color(0xFFEAD7C4), ring: Color(0x268A1C2B), err: Color(0xFF8A1C2B), door1: Color(0xFF9A2333), door2: Color(0xFF6E1320), doorLine: Color(0x99F0D296), leaf: Color(0xFF6D8A45)), css: {"bg": "#f8efe6", "paper": "#fffaf4", "ink": "#3a1d1f", "muted": "#6b4a45", "accent": "#8a1c2b", "onAccent": "#ffffff", "gold": "#a87b22", "line": "#ead7c4", "ring": "rgba(138,28,43,.15)", "err": "#8a1c2b", "door1": "#9a2333", "door2": "#6e1320", "doorLine": "rgba(240,210,150,.6)", "leaf": "#6d8a45"}),
  "nazar": InviteTheme(id: "nazar", name: {"tr": "Lacivert Nazar", "en": "Navy Evil Eye", "de": "Nazar in Marineblau", "ar": "عين زرقاء"}, premium: true, orn: "o-nazar", fall: "o-yildiz", colors: InviteColors(bg: Color(0xFF14284B), paper: Color(0xFF1B3360), ink: Color(0xFFF5F1E6), muted: Color(0xFFCDD6E6), accent: Color(0xFFE4B95F), onAccent: Color(0xFF14284B), gold: Color(0xFFE4B95F), line: Color(0x59E4B95F), ring: Color(0x40E4B95F), err: Color(0xFFF3A28F), door1: Color(0xFF24447A), door2: Color(0xFF122444), doorLine: Color(0x99E4B95F), leaf: Color(0xFFE4B95F)), css: {"bg": "#14284b", "paper": "#1b3360", "ink": "#f5f1e6", "muted": "#cdd6e6", "accent": "#e4b95f", "onAccent": "#14284b", "gold": "#e4b95f", "line": "rgba(228,185,95,.35)", "ring": "rgba(228,185,95,.25)", "err": "#f3a28f", "door1": "#24447a", "door2": "#122444", "doorLine": "rgba(228,185,95,.6)", "leaf": "#e4b95f"}),
  "kemer": InviteTheme(id: "kemer", name: {"tr": "Altın Kemer", "en": "Golden Arch", "de": "Goldener Bogen", "ar": "القوس الذهبي"}, premium: true, orn: "o-kemer", fall: "o-yildiz", colors: InviteColors(bg: Color(0xFF0F2E2B), paper: Color(0xFF143A36), ink: Color(0xFFF7EDD2), muted: Color(0xFFD3CBAE), accent: Color(0xFFE2BE63), onAccent: Color(0xFF0F2E2B), gold: Color(0xFFE2BE63), line: Color(0x52E2BE63), ring: Color(0x40E2BE63), err: Color(0xFFF0A58F), door1: Color(0xFF1B4A44), door2: Color(0xFF0A201E), doorLine: Color(0x8CE2BE63), leaf: Color(0xFFC9A24A)), css: {"bg": "#0F2E2B", "paper": "#143A36", "ink": "#F7EDD2", "muted": "#D3CBAE", "accent": "#E2BE63", "onAccent": "#0F2E2B", "gold": "#E2BE63", "line": "rgba(226,190,99,.32)", "ring": "rgba(226,190,99,.25)", "err": "#F0A58F", "door1": "#1B4A44", "door2": "#0A201E", "doorLine": "rgba(226,190,99,.55)", "leaf": "#C9A24A"}),
  "yildiz8": InviteTheme(id: "yildiz8", name: {"tr": "Sekiz Köşeli Yıldız", "en": "Eight-Point Star", "de": "Achtzackiger Stern", "ar": "النجمة الثمانية"}, premium: true, orn: "o-yildiz8", fall: "o-yildiz8", colors: InviteColors(bg: Color(0xFFFBF6EA), paper: Color(0xFFFFFCF4), ink: Color(0xFF1B2B3F), muted: Color(0xFF4E5A6A), accent: Color(0xFF0F6B66), onAccent: Color(0xFFFFFFFF), gold: Color(0xFFB8922F), line: Color(0xFFE6DCC2), ring: Color(0x290F6B66), err: Color(0xFFA2433A), door1: Color(0xFF2C8B85), door2: Color(0xFF0F5551), doorLine: Color(0x99F7ECC8), leaf: Color(0xFF5E9C94)), css: {"bg": "#FBF6EA", "paper": "#FFFCF4", "ink": "#1B2B3F", "muted": "#4E5A6A", "accent": "#0F6B66", "onAccent": "#FFFFFF", "gold": "#B8922F", "line": "#E6DCC2", "ring": "rgba(15,107,102,.16)", "err": "#A2433A", "door1": "#2C8B85", "door2": "#0F5551", "doorLine": "rgba(247,236,200,.6)", "leaf": "#5E9C94"}),
  "bordo": InviteTheme(id: "bordo", name: {"tr": "Bordo Kına", "en": "Burgundy Henna", "de": "Bordeaux-Henna", "ar": "حناء عنابية"}, premium: true, orn: "o-bordo", fall: "o-bordo", colors: InviteColors(bg: Color(0xFF5C1020), paper: Color(0xFF6B1A2D), ink: Color(0xFFFBEBD6), muted: Color(0xFFE6CDB8), accent: Color(0xFFEBC174), onAccent: Color(0xFF5C1020), gold: Color(0xFFEBC174), line: Color(0x57EBC174), ring: Color(0x40EBC174), err: Color(0xFFF5A6A0), door1: Color(0xFF7A1830), door2: Color(0xFF45091A), doorLine: Color(0x8CEBC174), leaf: Color(0xFFD9A95A)), css: {"bg": "#5C1020", "paper": "#6B1A2D", "ink": "#FBEBD6", "muted": "#E6CDB8", "accent": "#EBC174", "onAccent": "#5C1020", "gold": "#EBC174", "line": "rgba(235,193,116,.34)", "ring": "rgba(235,193,116,.25)", "err": "#F5A6A0", "door1": "#7A1830", "door2": "#45091A", "doorLine": "rgba(235,193,116,.55)", "leaf": "#D9A95A"}),
  "bulut": InviteTheme(id: "bulut", name: {"tr": "Tereyağı Bulut", "en": "Buttercream Cloud", "de": "Buttercreme-Wolke", "ar": "سحابة الزبدة"}, premium: true, orn: "o-bulut", fall: "o-bulut", colors: InviteColors(bg: Color(0xFFFFF6D9), paper: Color(0xFFFFFBEC), ink: Color(0xFF3D3A52), muted: Color(0xFF5C5872), accent: Color(0xFF6B4F8F), onAccent: Color(0xFFFFFFFF), gold: Color(0xFF9A7414), line: Color(0xFFEADFB8), ring: Color(0x296B4F8F), err: Color(0xFFA2443A), door1: Color(0xFF9F8AC4), door2: Color(0xFF6B4F8F), doorLine: Color(0x99FFFBEC), leaf: Color(0xFFB7A6D6)), css: {"bg": "#FFF6D9", "paper": "#FFFBEC", "ink": "#3D3A52", "muted": "#5C5872", "accent": "#6B4F8F", "onAccent": "#FFFFFF", "gold": "#9A7414", "line": "#EADFB8", "ring": "rgba(107,79,143,.16)", "err": "#A2443A", "door1": "#9F8AC4", "door2": "#6B4F8F", "doorLine": "rgba(255,251,236,.6)", "leaf": "#B7A6D6"}),
  "adacayi": InviteTheme(id: "adacayi", name: {"tr": "Adaçayı Dalı", "en": "Sage Branch", "de": "Salbeizweig", "ar": "غصن المريمية"}, premium: true, orn: "o-adacayi", fall: "o-adacayi", colors: InviteColors(bg: Color(0xFFF5F3EA), paper: Color(0xFFFBFAF4), ink: Color(0xFF2A3A31), muted: Color(0xFF526055), accent: Color(0xFF4F6F5B), onAccent: Color(0xFFFFFFFF), gold: Color(0xFF9A7C2E), line: Color(0xFFDFDCCB), ring: Color(0x294F6F5B), err: Color(0xFFA2543A), door1: Color(0xFF4B6B57), door2: Color(0xFF2A4234), doorLine: Color(0x80F5F3EA), leaf: Color(0xFF8FAE98)), css: {"bg": "#F5F3EA", "paper": "#FBFAF4", "ink": "#2A3A31", "muted": "#526055", "accent": "#4F6F5B", "onAccent": "#FFFFFF", "gold": "#9A7C2E", "line": "#DFDCCB", "ring": "rgba(79,111,91,.16)", "err": "#A2543A", "door1": "#4B6B57", "door2": "#2A4234", "doorLine": "rgba(245,243,234,.5)", "leaf": "#8FAE98"}),
  "gul": InviteTheme(id: "gul", name: {"tr": "Pudra Gül", "en": "Powder Rose", "de": "Puderrose", "ar": "الورد البودري"}, premium: true, orn: "o-gul", fall: "o-gulyaprak", colors: InviteColors(bg: Color(0xFFFBEFEC), paper: Color(0xFFFFF8F5), ink: Color(0xFF4A2B33), muted: Color(0xFF7A4D5A), accent: Color(0xFFA8405C), onAccent: Color(0xFFFFFFFF), gold: Color(0xFFA06A3C), line: Color(0xFFF0D6D3), ring: Color(0x29A8405C), err: Color(0xFFA63A32), door1: Color(0xFFD98A9B), door2: Color(0xFFB2566C), doorLine: Color(0xA6FFF8F5), leaf: Color(0xFF8FAE8A)), css: {"bg": "#FBEFEC", "paper": "#FFF8F5", "ink": "#4A2B33", "muted": "#7A4D5A", "accent": "#A8405C", "onAccent": "#FFFFFF", "gold": "#A06A3C", "line": "#F0D6D3", "ring": "rgba(168,64,92,.16)", "err": "#A63A32", "door1": "#D98A9B", "door2": "#B2566C", "doorLine": "rgba(255,248,245,.65)", "leaf": "#8FAE8A"}),
  "okaliptus": InviteTheme(id: "okaliptus", name: {"tr": "Okaliptüs", "en": "Eucalyptus", "de": "Eukalyptus", "ar": "الأوكالبتوس"}, premium: true, orn: "o-okaliptus", fall: "o-okaliptusyaprak", colors: InviteColors(bg: Color(0xFFFFFFFF), paper: Color(0xFFF7F9F7), ink: Color(0xFF24312C), muted: Color(0xFF50605A), accent: Color(0xFF4B6E64), onAccent: Color(0xFFFFFFFF), gold: Color(0xFF7D6B3A), line: Color(0xFFDEE6E1), ring: Color(0x294B6E64), err: Color(0xFFA5402F), door1: Color(0xFFDCE9E3), door2: Color(0xFFAEC8BE), doorLine: Color(0x8C4B6E64), leaf: Color(0xFF9DB8AC)), css: {"bg": "#FFFFFF", "paper": "#F7F9F7", "ink": "#24312C", "muted": "#50605A", "accent": "#4B6E64", "onAccent": "#FFFFFF", "gold": "#7D6B3A", "line": "#DEE6E1", "ring": "rgba(75,110,100,.16)", "err": "#A5402F", "door1": "#DCE9E3", "door2": "#AEC8BE", "doorLine": "rgba(75,110,100,.55)", "leaf": "#9DB8AC"}),
  "deco": InviteTheme(id: "deco", name: {"tr": "Art Deco Gece", "en": "Art Deco Night", "de": "Art-Déco-Nacht", "ar": "ليلة الآرت ديكو"}, premium: true, orn: "o-deco", fall: "o-decoelmas", colors: InviteColors(bg: Color(0xFF0E0E11), paper: Color(0xFF1A1A1F), ink: Color(0xFFF4ECD8), muted: Color(0xFFC9BFA6), accent: Color(0xFFD9B965), onAccent: Color(0xFF0E0E11), gold: Color(0xFFD9B965), line: Color(0x57D9B965), ring: Color(0x40D9B965), err: Color(0xFFF2A794), door1: Color(0xFF2A2A31), door2: Color(0xFF0B0B0D), doorLine: Color(0x99D9B965), leaf: Color(0xFFC9A24A)), css: {"bg": "#0E0E11", "paper": "#1A1A1F", "ink": "#F4ECD8", "muted": "#C9BFA6", "accent": "#D9B965", "onAccent": "#0E0E11", "gold": "#D9B965", "line": "rgba(217,185,101,.34)", "ring": "rgba(217,185,101,.25)", "err": "#F2A794", "door1": "#2A2A31", "door2": "#0B0B0D", "doorLine": "rgba(217,185,101,.6)", "leaf": "#C9A24A"}),
  "tezhip": InviteTheme(id: "tezhip", name: {"tr": "Tezhip", "en": "Ottoman Illumination", "de": "Osmanische Buchmalerei", "ar": "التذهيب العثماني"}, premium: true, orn: "o-tezhip", fall: "o-hatayi", colors: InviteColors(bg: Color(0xFFF8F0DB), paper: Color(0xFFFFFAEB), ink: Color(0xFF16284A), muted: Color(0xFF475572), accent: Color(0xFF1D3A6E), onAccent: Color(0xFFFFFFFF), gold: Color(0xFF8A6616), line: Color(0xFFE7D8AE), ring: Color(0x291D3A6E), err: Color(0xFFA23A32), door1: Color(0xFF2B4C88), door2: Color(0xFF13294F), doorLine: Color(0xB2E8C673), leaf: Color(0xFFB08D3A)), css: {"bg": "#F8F0DB", "paper": "#FFFAEB", "ink": "#16284A", "muted": "#475572", "accent": "#1D3A6E", "onAccent": "#FFFFFF", "gold": "#8A6616", "line": "#E7D8AE", "ring": "rgba(29,58,110,.16)", "err": "#A23A32", "door1": "#2B4C88", "door2": "#13294F", "doorLine": "rgba(232,198,115,.7)", "leaf": "#B08D3A"}),
  "lavanta": InviteTheme(id: "lavanta", name: {"tr": "Lavanta", "en": "Lavender", "de": "Lavendel", "ar": "اللافندر"}, premium: true, orn: "o-lavanta", fall: "o-lavantatane", colors: InviteColors(bg: Color(0xFFF3EDF9), paper: Color(0xFFFBF8FE), ink: Color(0xFF31264A), muted: Color(0xFF5B5072), accent: Color(0xFF5E4194), onAccent: Color(0xFFFFFFFF), gold: Color(0xFF8A6D2A), line: Color(0xFFE1D6EF), ring: Color(0x295E4194), err: Color(0xFFA63A3A), door1: Color(0xFFDCCFF0), door2: Color(0xFFBBA6DE), doorLine: Color(0x805E4194), leaf: Color(0xFF8DA878)), css: {"bg": "#F3EDF9", "paper": "#FBF8FE", "ink": "#31264A", "muted": "#5B5072", "accent": "#5E4194", "onAccent": "#FFFFFF", "gold": "#8A6D2A", "line": "#E1D6EF", "ring": "rgba(94,65,148,.16)", "err": "#A63A3A", "door1": "#DCCFF0", "door2": "#BBA6DE", "doorLine": "rgba(94,65,148,.5)", "leaf": "#8DA878"}),
  "zeytin": InviteTheme(id: "zeytin", name: {"tr": "Zeytin Dalı", "en": "Olive Branch", "de": "Olivenzweig", "ar": "غصن الزيتون"}, premium: true, orn: "o-zeytin", fall: "o-zeytinyaprak", colors: InviteColors(bg: Color(0xFFF5EFE0), paper: Color(0xFFFCF8EE), ink: Color(0xFF312E1E), muted: Color(0xFF585433), accent: Color(0xFF58692A), onAccent: Color(0xFFFFFFFF), gold: Color(0xFF86661C), line: Color(0xFFE4DBC0), ring: Color(0x2958692A), err: Color(0xFFA23F2C), door1: Color(0xFFE0E4C2), door2: Color(0xFFBAC38C), doorLine: Color(0x8C58692A), leaf: Color(0xFF9AAA6A)), css: {"bg": "#F5EFE0", "paper": "#FCF8EE", "ink": "#312E1E", "muted": "#585433", "accent": "#58692A", "onAccent": "#FFFFFF", "gold": "#86661C", "line": "#E4DBC0", "ring": "rgba(88,105,42,.16)", "err": "#A23F2C", "door1": "#E0E4C2", "door2": "#BAC38C", "doorLine": "rgba(88,105,42,.55)", "leaf": "#9AAA6A"}),
  "balon": InviteTheme(id: "balon", name: {"tr": "Balon Şenliği", "en": "Balloon Party", "de": "Ballonfest", "ar": "حفلة البالونات"}, premium: true, orn: "o-balon", fall: "o-konfeti", colors: InviteColors(bg: Color(0xFFFFF8EA), paper: Color(0xFFFFFDF6), ink: Color(0xFF2B2A4A), muted: Color(0xFF555377), accent: Color(0xFFC22F54), onAccent: Color(0xFFFFFFFF), gold: Color(0xFF946A00), line: Color(0xFFF1E3C4), ring: Color(0x29C22F54), err: Color(0xFFB02E2E), door1: Color(0xFF7F6DDB), door2: Color(0xFF5646B3), doorLine: Color(0xA6FFFFFF), leaf: Color(0xFF3FBF8A)), css: {"bg": "#FFF8EA", "paper": "#FFFDF6", "ink": "#2B2A4A", "muted": "#555377", "accent": "#C22F54", "onAccent": "#FFFFFF", "gold": "#946A00", "line": "#F1E3C4", "ring": "rgba(194,47,84,.16)", "err": "#B02E2E", "door1": "#7F6DDB", "door2": "#5646B3", "doorLine": "rgba(255,255,255,.65)", "leaf": "#3FBF8A"}),
  "mehtap": InviteTheme(id: "mehtap", name: {"tr": "Mehtap", "en": "Moonlight", "de": "Mondschein", "ar": "ضوء القمر"}, premium: true, orn: "o-mehtap", fall: "o-mehtapyildiz", colors: InviteColors(bg: Color(0xFF131B47), paper: Color(0xFF1D2759), ink: Color(0xFFF2EDFB), muted: Color(0xFFC6C3E4), accent: Color(0xFFCDBBF2), onAccent: Color(0xFF131B47), gold: Color(0xFFE8D49E), line: Color(0x52CDBBF2), ring: Color(0x40CDBBF2), err: Color(0xFFF4A6A0), door1: Color(0xFF34418F), door2: Color(0xFF0F1640), doorLine: Color(0x8CCDBBF2), leaf: Color(0xFFBBA6E8)), css: {"bg": "#131B47", "paper": "#1D2759", "ink": "#F2EDFB", "muted": "#C6C3E4", "accent": "#CDBBF2", "onAccent": "#131B47", "gold": "#E8D49E", "line": "rgba(205,187,242,.32)", "ring": "rgba(205,187,242,.25)", "err": "#F4A6A0", "door1": "#34418F", "door2": "#0F1640", "doorLine": "rgba(205,187,242,.55)", "leaf": "#BBA6E8"}),
};

/// Etkinlik türüne göre önerilen tasarım sırası (REC).
const Map<String, List<String>> kRecommended = {
  "nisan": ["gul", "okaliptus", "papatya", "lavanta", "adacayi", "yildiz8", "zeytin", "kemer", "tezhip", "kina", "altin", "deco", "mehtap", "bulut", "nazar", "bordo", "balon"],
  "dugun": ["kemer", "gul", "okaliptus", "papatya", "deco", "zeytin", "adacayi", "altin", "yildiz8", "tezhip", "mehtap", "kina", "nazar", "bordo", "lavanta", "bulut", "balon"],
  "kina": ["bordo", "kina", "mehtap", "papatya", "tezhip", "altin", "kemer", "yildiz8", "gul", "deco", "adacayi", "nazar", "zeytin", "lavanta", "okaliptus", "bulut", "balon"],
  "soz": ["tezhip", "gul", "papatya", "zeytin", "yildiz8", "okaliptus", "adacayi", "kemer", "kina", "lavanta", "altin", "deco", "mehtap", "nazar", "bordo", "bulut", "balon"],
  "sunnet": ["balon", "nazar", "papatya", "tezhip", "bulut", "altin", "yildiz8", "mehtap", "kemer", "adacayi", "okaliptus", "lavanta", "zeytin", "deco", "kina", "gul", "bordo"],
  "dogum": ["balon", "bulut", "papatya", "deco", "lavanta", "nazar", "altin", "gul", "adacayi", "okaliptus", "mehtap", "yildiz8", "kemer", "zeytin", "tezhip", "kina", "bordo"],
  "baby": ["gul", "lavanta", "bulut", "papatya", "balon", "adacayi", "okaliptus", "nazar", "zeytin", "altin", "mehtap", "kina", "yildiz8", "kemer", "tezhip", "deco", "bordo"],
  "diger": ["papatya", "tezhip", "mehtap", "altin", "deco", "adacayi", "yildiz8", "okaliptus", "kemer", "bulut", "zeytin", "lavanta", "gul", "nazar", "kina", "bordo", "balon"],
};

/// Hazır davet mesajları (MSGS): dil → tür → metinler.
const Map<String, Map<String, List<String>>> kMessages = {
  "tr": {
    "nisan": ["Hayatımızın en güzel gününde sizleri de aramızda görmekten mutluluk duyarız.", "Bir ömre ilk adımı atarken sevdiklerimizin yanımızda olmasını istiyoruz."],
    "dugun": ["Birlikte çıktığımız bu yolun ilk gününde sizleri de yanımızda görmek isteriz.", "Mutluluğumuzu paylaşmak için sizleri düğünümüze bekliyoruz."],
    "kina": ["Kına gecemizde neşemize ortak olmanızı dileriz.", "Gelinimizin kınasında sizleri de aramızda görmek isteriz."],
    "soz": ["Söz merasimimizde sizleri de aramızda görmekten mutluluk duyarız."],
    "sunnet": ["Oğlumuzun sünnet düğününde sizleri de aramızda görmekten onur duyarız.", "Delikanlımızın bu özel gününde sevincimize ortak olun."],
    "dogum": ["Yeni yaşımı sevdiklerimle kutlamak istiyorum. Sen de gel!", "Pastalar hazır, mumlar yanmak üzere. Seni de bekliyoruz!"],
    "baby": ["Minik mucizemizi beklerken bu sevinci sizinle paylaşmak istiyoruz."],
    "diger": ["Bu özel günümüzde sizleri de aramızda görmekten mutluluk duyarız."],
  },
  "en": {
    "nisan": ["We would be delighted to have you with us as we celebrate our engagement.", "As we take our first step toward forever, we'd love you by our side."],
    "dugun": ["Together with our families, we invite you to celebrate our wedding day.", "We would be honoured by your presence on the first day of our journey together."],
    "kina": ["Join us for an evening of henna, music and joy."],
    "soz": ["We would be delighted to see you at our promise ceremony."],
    "sunnet": ["We would be honoured to have you celebrate our son's special day with us."],
    "dogum": ["I'm celebrating another year with the people I love. Come join me!"],
    "baby": ["Our little miracle is on the way, and we'd love to celebrate with you."],
    "diger": ["We would be delighted to have you with us on this special day."],
  },
  "de": {
    "nisan": ["Wir freuen uns sehr, unsere Verlobung mit euch zu feiern.", "Auf unserem ersten Schritt in eine gemeinsame Zukunft möchten wir euch an unserer Seite haben."],
    "dugun": ["Wir trauen uns! Feiert mit uns den schönsten Tag unseres Lebens.", "Gemeinsam mit unseren Familien laden wir euch herzlich zu unserer Hochzeit ein."],
    "kina": ["Feiert mit uns einen Abend voller Henna, Musik und Freude."],
    "soz": ["Wir freuen uns, euch bei unserer Versprechensfeier zu sehen."],
    "sunnet": ["Wir würden uns freuen, den besonderen Tag unseres Sohnes mit euch zu feiern."],
    "dogum": ["Ich feiere mein neues Lebensjahr mit lieben Menschen. Sei dabei!"],
    "baby": ["Unser kleines Wunder ist unterwegs – feiert mit uns!"],
    "diger": ["Wir freuen uns sehr, diesen besonderen Tag mit euch zu teilen."],
  },
  "ar": {
    "nisan": ["يسعدنا حضوركم ومشاركتنا فرحة خطوبتنا.", "ونحن نخطو أولى خطواتنا معًا، يسعدنا أن تكونوا إلى جانبنا."],
    "dugun": ["بكل الحب والفرح، ندعوكم لمشاركتنا حفل زفافنا.", "يتشرف أهلنا بدعوتكم لحضور حفل زفافنا، وحضوركم يتمم فرحتنا."],
    "kina": ["ندعوكم لمشاركتنا ليلة الحناء بأجوائها المبهجة."],
    "soz": ["يسعدنا حضوركم حفل الوعد."],
    "sunnet": ["يتشرف أهلنا بدعوتكم لمشاركتنا فرحة حفل ختان ابننا."],
    "dogum": ["أحتفل بعامي الجديد مع أحبائي، وحضورك يسعدني!"],
    "baby": ["ننتظر مولودنا الصغير، ويسعدنا أن نشارككم هذه الفرحة."],
    "diger": ["يسعدنا حضوركم ومشاركتنا هذا اليوم المميز."],
  },
};

/// Tür simgesi olarak kullanılan süs (önizlemedeki typeIcon).
const Map<String, String> kTypeIcon = {'nisan': 'o-papatya', 'dugun': 'o-yildiz', 'kina': 'o-lale', 'soz': 'o-papatya', 'sunnet': 'o-yildiz', 'dogum': 'o-papatya', 'baby': 'o-papatya', 'diger': 'o-yildiz'};

/// Fiyat etiketleri (Aşama 3'te Google Play fiyatıyla değişecek).
const Map<String, String> kPriceLabel = {"tr": "399 TL", "en": "€9.99", "de": "9,99 €", "ar": "39,99 ر.س"};
