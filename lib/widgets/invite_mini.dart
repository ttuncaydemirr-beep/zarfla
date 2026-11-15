import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/date_utils.dart';
import '../logic/text_utils.dart';
import '../models/invitation.dart';
import '../theme/app_theme.dart';
import 'ornament.dart';

/// Davetiyenin canlı minik önizlemesi (galeri kartı, yayınla kahramanı, tamamlandı ekranı).
/// Gerçek davetiye sayfasının "kapak" kompozisyonu: tema zemini, kağıt kart, süs, üst etiket, isimler
/// (Fraunces italik, ayraç altın), tarih ve ince altın çizgi. Ölçüler genişliğe göre ölçeklenir.
class InviteMini extends StatelessWidget {
  const InviteMini({
    super.key,
    required this.theme,
    required this.names,
    required this.eyebrow,
    required this.lang,
    this.amp = '&',
    this.date = '',
    this.aspect = 3 / 4,
    this.radius = AppRadii.md,
  });

  final InviteTheme theme;
  /// 1 (tek isim) ya da 2 (çift) isim.
  final List<String> names;
  final String eyebrow;
  final String lang;
  final String amp;
  final String date;
  /// Genişlik / yükseklik.
  final double aspect;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    final ar = lang == 'ar';
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final k = (w / 160).clamp(0.6, 2.4).toDouble(); // 160 px genişlik referansı
        final couple = names.length > 1;
        final nameSize = (couple ? 19.0 : 22.0) * k;
        TextStyle nameStyle() => headStyle(nameSize, weight: FontWeight.w400, color: c.accent, fontStyle: ar ? FontStyle.normal : FontStyle.italic, height: 1.05);
        // Metin ölçeği Arapça büyütmesinden etkilenmesin; küçük resim kendi ölçeğini taşır.
        return MediaQuery.withNoTextScaling(
          child: Container(
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(radius)),
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.all(9 * k),
            child: Container(
              decoration: BoxDecoration(
                color: c.paper,
                borderRadius: BorderRadius.circular(radius * 0.7),
                border: Border.all(color: c.line, width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 14 * k, offset: Offset(0, 6 * k))],
              ),
              padding: EdgeInsets.symmetric(horizontal: 8 * k, vertical: 10 * k),
              child: Stack(
                children: [
                  // Köşe süsleri (soluk), davetiye kartındaki .mini gibi
                  PositionedDirectional(top: -8 * k, start: -8 * k, child: Opacity(opacity: 0.55, child: Ornament(theme.fall, size: 26 * k))),
                  PositionedDirectional(bottom: -8 * k, end: -8 * k, child: Opacity(opacity: 0.55, child: Ornament(theme.fall, size: 26 * k))),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Süsün arkasında yumuşak hale (açık süsler, ör. beyaz papatya, kağıtta kaybolmasın).
                        Container(
                          width: (h * 0.27).clamp(30.0, 160.0).toDouble(),
                          height: (h * 0.27).clamp(30.0, 160.0).toDouble(),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [c.leaf.withValues(alpha: 0.30), c.leaf.withValues(alpha: 0.10), c.leaf.withValues(alpha: 0)], stops: const [0, 0.65, 1]),
                          ),
                          child: Ornament(theme.orn, size: (h * 0.2).clamp(22.0, 120.0).toDouble()),
                        ),
                        SizedBox(height: 2 * k),
                        Text(
                          eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: bodyStyle(7.2 * k, weight: FontWeight.w700, color: c.muted, letterSpacing: ar ? 0 : 1.3 * k, height: 1.2),
                        ),
                        SizedBox(height: 5 * k),
                        for (var i = 0; i < names.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 1 * k),
                              child: Text(amp, style: headStyle(nameSize * 0.55, weight: FontWeight.w400, color: c.gold, fontStyle: ar ? FontStyle.normal : FontStyle.italic, height: 1.1)),
                            ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(names[i], maxLines: 1, textAlign: TextAlign.center, style: nameStyle()),
                          ),
                        ],
                        SizedBox(height: 7 * k),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 14 * k, height: 1, color: c.gold.withValues(alpha: 0.7)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4 * k),
                              child: Container(width: 3.5 * k, height: 3.5 * k, decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle)),
                            ),
                            Container(width: 14 * k, height: 1, color: c.gold.withValues(alpha: 0.7)),
                          ],
                        ),
                        if (date.isNotEmpty) ...[
                          SizedBox(height: 5 * k),
                          Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(8 * k, weight: FontWeight.w600, color: c.ink, height: 1.2)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Küçük resimde gösterilecek isimler: kullanıcının yazdıkları; hiç isim yoksa kişi adı OLMAYAN
/// zarif yer tutucular (Gelin & Damat, Anne & Baba, İsminiz — dile göre ARB'den).
List<String> miniNames(BuildContext context, Invitation inv) {
  final a = inv.n1.trim(), b = inv.n2.trim();
  if (inv.isCouple) {
    if (a.isEmpty && b.isEmpty) {
      return inv.type == 'cinsiyet' ? [context.tIn(inv.lang, 'sampleParentA'), context.tIn(inv.lang, 'sampleParentB')] : [context.tIn(inv.lang, 'sampleA'), context.tIn(inv.lang, 'sampleB')];
    }
    return [a, b].where((x) => x.isNotEmpty).toList();
  }
  return [a.isEmpty ? context.tIn(inv.lang, 'sampleOne') : a];
}

/// Davetiyenin kendisi için hazır küçük resim (davetiye dilinde üst etiket ve tarih).
class InviteMiniFor extends StatelessWidget {
  const InviteMiniFor({super.key, required this.inv, this.themeId, this.aspect = 3 / 4, this.radius = AppRadii.md});

  final Invitation inv;
  /// Verilirse davetiyenin kendi tasarımı yerine bu tasarımla çizilir (galeri).
  final String? themeId;
  final double aspect;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final th = kThemes[themeId ?? inv.theme] ?? kThemes['papatya']!;
    final lang = inv.lang;
    return InviteMini(
      theme: th,
      names: miniNames(context, inv),
      eyebrow: upperFor(context.tIn(lang, 'eyebrow_${inv.type}'), lang),
      lang: lang,
      amp: context.tIn(lang, 'amp'),
      date: formatShortDate(inv.date, lang),
      aspect: aspect,
      radius: radius,
    );
  }
}
