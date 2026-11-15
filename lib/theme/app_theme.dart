import 'package:flutter/material.dart';

/// Onaylı görsel kimlik "Zümrüt Zarf" (web önizlemesindeki --a-* değişkenleri).
/// Altın (accent) yalnız simge, çizgi ve büyük yazıda kullanılır; küçük metinde kullanılmaz.
class AppColors {
  AppColors._();
  static const Color bg = Color(0xFFF7F1E8);
  static const Color surface = Color(0xFFFFFCF7);
  static const Color ink = Color(0xFF1D211F);
  static const Color muted = Color(0xFF5A5F58);
  static const Color primary = Color(0xFF1F3D36);
  static const Color onPrimary = Color(0xFFFFF8EC);
  static const Color line = Color(0xFFE6DDCC);
  static const Color field = Color(0xFF8A8372);
  static const Color accent = Color(0xFFAD7F2E);
  static const Color ok = Color(0xFF2F6B3B);
  static const Color err = Color(0xFFA8322B);
  static const Color tint = Color(0xFFE7EEEA);

  // Önizlemedeki yardımcı tonlar
  static const Color sand = Color(0xFFEFE7D9); // not kutusu, taslak rozeti, salt-okunur alan
  static const Color draftInk = Color(0xFF4F534D);
  static const Color crownBg = Color(0xFFF6EBD3);
  static const Color crownInk = Color(0xFF6E4E14);
  static const Color brandRing = Color(0xFFE3C58A);

  // Tasarım incelemesi 4.1: eksik roller (onaylı renkler değişmedi; oranlar WCAG ile hesaplandı).
  /// Açık zeminde altın renkli KÜÇÜK metin gerekirse (4.77:1 bg).
  static const Color accentText = Color(0xFF8A6420);
  /// Zümrüt zemin üstünde altın metin / ince çizgi (4.92:1 primary).
  static const Color accentOnDark = Color(0xFFC9A24E);
  /// Bir ton koyu alan kenarı / ikon (4.60:1 surface).
  static const Color fieldStrong = Color(0xFF7A7364);
  /// Not kutusu (sand) içinde ikincil metin (6.22:1).
  static const Color mutedOnSand = Color(0xFF50554E);
  /// Karo / kart kenarı (çizgiden bir ton koyu, 1.4:1 bg; dekoratif).
  static const Color lineStrong = Color(0xFFD9CDB6);
  /// Odak / seçili halka: rgba(31,61,54,.28).
  static const Color focusRing = Color(0x471F3D36);
  /// Hatalı alan halkası: rgba(168,50,43,.12).
  static const Color errRing = Color(0x1FA8322B);
  /// Alt sayfa / önizleme arkası: rgba(29,33,31,.55).
  static const Color scrim = Color(0x8C1D211F);
  /// Hata paneli zemini (err üzerinde metin 5.9:1+).
  static const Color errBg = Color(0xFFF8E9E6);
}

/// Aralık ölçeği (4.3): 4, 8, 12, 16, 24, 32, 48. Kenar boşluğu 16.
class AppSpace {
  AppSpace._();
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x12 = 48;
  static const double edge = 16;
}

/// Hareket jetonları (4.5): fast 120, base 220, slow 420 ms; giriş easeOutCubic, çıkış easeInCubic.
class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 280);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// Sistem "animasyonları kaldır" tercihi açıksa true (hareket azaltılır).
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Yarıçap ölçeği (4.4): xs 8 (çip içi), sm 10 (düğme, alan), md 14 (kart), lg 20 (alt sayfa, premium kart), pill.
class AppRadii {
  AppRadii._();
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();
  // 0 2px 8px rgba(31,61,54,.10)
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x1A1F3D36), blurRadius: 8, offset: Offset(0, 2)),
  ];
  // 0 8px 24px rgba(31,61,54,.12)
  static const List<BoxShadow> up = [
    BoxShadow(color: Color(0x1F1F3D36), blurRadius: 24, offset: Offset(0, 8)),
  ];
  // 0 16px 40px rgba(31,61,54,.18): yalnız paywall / önizleme kahramanı
  static const List<BoxShadow> hero = [
    BoxShadow(color: Color(0x2E1F3D36), blurRadius: 40, offset: Offset(0, 16)),
  ];
}

/// Tipografi ölçeği (4.2). Latin: Fraunces başlık + Manrope metin. Arapça: başlıkta Amiri, metinde
/// Noto Naskh; Arapça arayüzde metinler [kArabicTextScale] ile büyütülür (app.dart) ve harf aralığı 0.
class AppType {
  AppType._();
  static const double display = 40;
  static const double h1 = 26;
  static const double h2 = 20;
  static const double title = 16;
  static const double body = 15;
  static const double label = 13;
  static const double caption = 12;
  static const double overline = 11.5;
  /// En küçük izinli yazı boyutu.
  static const double min = 11.5;
}

/// Arapça arayüzde metin büyütme (gövde 15 → ~16.2; Naskh x-yüksekliği küçük).
const double kArabicTextScale = 1.08;

/// Arapça glifler için yedek yazı tipleri (Manrope ve Fraunces Arapça içermez).
const List<String> kFontFallback = ['NotoNaskhArabic', 'Amiri'];

/// Başlıklarda Arapça: Amiri (kalın kesimi paketli), sonra Noto Naskh.
const List<String> kHeadFallback = ['Amiri', 'NotoNaskhArabic'];

List<FontVariation> _wght(FontWeight w) => [FontVariation('wght', w.value.toDouble())];

/// Başlık yazısı: Fraunces (değişken yazı tipi; ağırlık ekseni açıkça verilir).
TextStyle headStyle(double size, {FontWeight weight = FontWeight.w600, Color color = AppColors.primary, FontStyle? fontStyle, double height = 1.2}) {
  return TextStyle(
    fontFamily: 'Fraunces',
    fontFamilyFallback: kHeadFallback,
    fontSize: size,
    fontWeight: weight,
    fontStyle: fontStyle,
    fontVariations: _wght(weight),
    color: color,
    height: height,
  );
}

/// Metin yazısı: Manrope.
TextStyle bodyStyle(double size, {FontWeight weight = FontWeight.w400, Color color = AppColors.ink, double? height, double? letterSpacing}) {
  return TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: kFontFallback,
    fontSize: size,
    fontWeight: weight,
    fontVariations: _wght(weight),
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle? _v(TextStyle? s) {
  if (s == null) return null;
  return s.copyWith(fontVariations: _wght(s.fontWeight ?? FontWeight.w400));
}

TextTheme _withVariations(TextTheme t) => t.copyWith(
      displayLarge: _v(t.displayLarge),
      displayMedium: _v(t.displayMedium),
      displaySmall: _v(t.displaySmall),
      headlineLarge: _v(t.headlineLarge),
      headlineMedium: _v(t.headlineMedium),
      headlineSmall: _v(t.headlineSmall),
      titleLarge: _v(t.titleLarge),
      titleMedium: _v(t.titleMedium),
      titleSmall: _v(t.titleSmall),
      bodyLarge: _v(t.bodyLarge),
      bodyMedium: _v(t.bodyMedium),
      bodySmall: _v(t.bodySmall),
      labelLarge: _v(t.labelLarge),
      labelMedium: _v(t.labelMedium),
      labelSmall: _v(t.labelSmall),
    );

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.err,
    outline: AppColors.field,
    outlineVariant: AppColors.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Manrope',
    fontFamilyFallback: kFontFallback,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  return base.copyWith(
    textTheme: _withVariations(base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primary,
      contentTextStyle: bodyStyle(14, color: AppColors.onPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
    ),
    // Sayfa geçişi: varsayılan Material yerine 280 ms solma + 4 px yukarı kayma (hareket azaltmada anlık).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZPageTransitions(),
      TargetPlatform.iOS: ZPageTransitions(),
      TargetPlatform.linux: ZPageTransitions(),
      TargetPlatform.macOS: ZPageTransitions(),
      TargetPlatform.windows: ZPageTransitions(),
      TargetPlatform.fuchsia: ZPageTransitions(),
    }),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
  );
}

/// Zarfla sayfa geçişi (tasarım incelemesi #20b).
class ZPageTransitions extends PageTransitionsBuilder {
  const ZPageTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (AppMotion.reduced(context)) return child;
    final a = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: AppMotion.exit);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.006), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}
