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
}

class AppRadii {
  AppRadii._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
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
}

/// Arapça glifler için yedek yazı tipleri (Manrope ve Fraunces Arapça içermez).
const List<String> kFontFallback = ['NotoNaskhArabic', 'Amiri'];

List<FontVariation> _wght(FontWeight w) => [FontVariation('wght', w.value.toDouble())];

/// Başlık yazısı: Fraunces (değişken yazı tipi; ağırlık ekseni açıkça verilir).
TextStyle headStyle(double size, {FontWeight weight = FontWeight.w600, Color color = AppColors.primary, FontStyle? fontStyle, double height = 1.2}) {
  return TextStyle(
    fontFamily: 'Fraunces',
    fontFamilyFallback: kFontFallback,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
