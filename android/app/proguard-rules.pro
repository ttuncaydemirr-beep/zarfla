# Zarfla R8/ProGuard kuralları (release: küçültme + gizleme açık).
# Bu dosya depoda durur; scripts/patch_android.py release buildType'ına bağlar.
# Prensip: yalnızca belgelenmiş, gerekli kurallar. Flutter gömme (embedding), Firebase, Google Mobile Ads
# ve Play Billing AAR'ları kendi consumer kurallarını getirir; onları ayrıca -keep ile şişirmiyoruz.

# --- Hata ayıklama: Play Console'daki çökme raporları mapping.txt ile çözülsün ---
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# --- Firebase / Gson tarzı yansıma için öznitelikler (Firebase AAR'ları kendi kurallarını taşır) ---
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses

# --- WebView JS köprüsü (webview_flutter 'ZarflaApp' kanalı) ---
# Android belgelerindeki standart kural: @JavascriptInterface metotları yeniden adlandırılmamalı/silinmemeli.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# --- Play Core (ertelenmiş bileşenler): Flutter motoru referans verir, Zarfla kullanmaz ---
-dontwarn com.google.android.play.core.**

# --- Google Mobile Ads ve Play Billing ---
# Her ikisinin AAR'ı consumer kuralı taşır; ek -keep gerekmez. Yalnızca eksik-sınıf uyarıları için:
-dontwarn com.google.android.gms.ads.**
-dontwarn com.android.billingclient.**
