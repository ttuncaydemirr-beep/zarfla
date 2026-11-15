#!/usr/bin/env python3
"""flutter create çıktısına Zarfla ayarlarını uygular (idempotent).

- applicationId / namespace: com.demirgamesstudio.zarfla (flutter create --org ile gelir, burada doğrulanır)
- minSdk >= 23, targetSdk/compileSdk >= 35 (Flutter'ın varsayılanı daha yüksekse o kullanılır;
  Play'in güncel hedef API şartı ve eklentilerin compileSdk isteği bozulmasın diye)
- Uygulama adı: "Zarfla"
- AdMob: APPLICATION_ID meta-data (kaynak: lib/ads/ad_config.dart) + AD_ID izni (AndroidManifest)
- Firebase: com.google.gms.google-services Gradle eklentisi (Kotlin DSL ve Groovy şablonlarının ikisi de)
  android/app/google-services.json depoda durur; eklenti onu derlemede okur.
- Uygulama simgesi: assets/branding/android/res/ → android/app/src/main/res/ (Flutter varsayılanının üzerine)
- ZarflaApplication (Kotlin): yerel (Java/Kotlin) çökmeleri files/zarfla_last_crash.txt'e yazar; Dart tarafı bir sonraki
  açılışta okur, o açılışı "güvenli kip"te yapar (reklam/ödeme başlatılmaz) ve ayrıntıyı Hakkında'da gösterir.
- Yedekleme: yalnız uygulamanın kendi verisi (FlutterSharedPreferences.xml) yedeklenir/aktarılır. Reklam/WorkManager/
  Firebase/UMP gibi SDK durumları geri yüklenmez (eski, uyumsuz SDK verisinin yeni sürümde açılışı bozmasını önler).
"""
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
APP = ANDROID / "app"
APP_ID = "com.demirgamesstudio.zarfla"
GMS_ID = "com.google.gms.google-services"
GMS_VERSION = "4.4.2"
ICON_SRC = ROOT / "assets" / "branding" / "android" / "res"


def _app_gradle() -> pathlib.Path:
    kts = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"
    path = kts if kts.exists() else groovy
    if not path.exists():
        sys.exit("android/app/build.gradle(.kts) bulunamadı; önce flutter create çalıştırın.")
    return path


def patch_gradle() -> None:
    path = _app_gradle()
    s = path.read_text(encoding="utf-8")
    is_kts = path.suffix == ".kts"
    mx = (lambda a, b: f"maxOf({a}, {b})") if is_kts else (lambda a, b: f"Math.max({a}, {b})")

    rules = [
        (r"(minSdk(?:Version)?\s*=?\s*)flutter\.minSdkVersion", lambda m: m.group(1) + mx(23, "flutter.minSdkVersion")),
        (r"(targetSdk(?:Version)?\s*=?\s*)flutter\.targetSdkVersion", lambda m: m.group(1) + mx(35, "flutter.targetSdkVersion")),
        (r"(compileSdk(?:Version)?\s*=?\s*)flutter\.compileSdkVersion", lambda m: m.group(1) + mx(35, "flutter.compileSdkVersion")),
    ]
    for pat, rep in rules:
        s, n = re.subn(pat, rep, s)
        if n == 0 and "23, flutter.minSdkVersion" not in s and "minSdk" in pat:
            print(f"UYARI: {pat} bulunamadı; Flutter varsayılanı kullanılacak.")
    if APP_ID not in s:
        print(f"UYARI: {path.name} içinde {APP_ID} yok!")

    # Firebase google-services eklentisi (uygulama modülü)
    if GMS_ID not in s:
        line = f'    id("{GMS_ID}")' if is_kts else f'    id "{GMS_ID}"'
        # Bloğun SONUNA ekle (Android eklentisinden sonra uygulanması önerilir)
        s, n = re.subn(r"(^plugins\s*\{.*?)(\n\}\s*\n)", lambda m: m.group(1) + "\n" + line + m.group(2), s,
                       count=1, flags=re.S | re.M)
        if n == 0:
            # Çok eski şablon: plugins bloğu yok → dosya sonuna apply
            s += f'\napply plugin: "{GMS_ID}"\n' if not is_kts else f'\napply(plugin = "{GMS_ID}")\n'
    path.write_text(s, encoding="utf-8")
    print(f"{path.relative_to(ROOT)} güncellendi")


KEYPROPS_MARK = "zarflaKeyProps"


def patch_signing() -> None:
    """Release imzası: android/key.properties varsa signingConfigs.release, yoksa debug imza (idempotent).

    key.properties alanları: storeFile (android/app'e göre), storePassword, keyAlias, keyPassword.
    R8/küçültme patch_r8() ile açılır (android/app/proguard-rules.pro).
    """
    path = _app_gradle()
    s = path.read_text(encoding="utf-8")
    if KEYPROPS_MARK in s:
        print(f"{path.name}: imza yapılandırması zaten var")
        return
    is_kts = path.suffix == ".kts"

    if is_kts:
        props = (
            f"val {KEYPROPS_MARK} = Properties().also {{ p ->\n"
            '    val f = rootProject.file("key.properties")\n'
            "    if (f.exists()) f.inputStream().use { p.load(it) }\n"
            "}\n\n"
        )
        signing = (
            "    signingConfigs {\n"
            f"        if ({KEYPROPS_MARK}.isNotEmpty()) {{\n"
            '            create("release") {\n'
            f'                storeFile = file({KEYPROPS_MARK}.getProperty("storeFile"))\n'
            f'                storePassword = {KEYPROPS_MARK}.getProperty("storePassword")\n'
            f'                keyAlias = {KEYPROPS_MARK}.getProperty("keyAlias")\n'
            f'                keyPassword = {KEYPROPS_MARK}.getProperty("keyPassword")\n'
            "            }\n"
            "        }\n"
            "    }\n\n"
        )
        sign_ref = (f'signingConfig = if ({KEYPROPS_MARK}.isNotEmpty()) signingConfigs.getByName("release") '
                    'else signingConfigs.getByName("debug")')
    else:
        props = (
            f"def {KEYPROPS_MARK} = new Properties()\n"
            "def zarflaKeyFile = rootProject.file('key.properties')\n"
            f"if (zarflaKeyFile.exists()) {{ zarflaKeyFile.withInputStream {{ {KEYPROPS_MARK}.load(it) }} }}\n\n"
        )
        signing = (
            "    signingConfigs {\n"
            f"        if (!{KEYPROPS_MARK}.isEmpty()) {{\n"
            "            release {\n"
            f"                storeFile file({KEYPROPS_MARK}['storeFile'])\n"
            f"                storePassword {KEYPROPS_MARK}['storePassword']\n"
            f"                keyAlias {KEYPROPS_MARK}['keyAlias']\n"
            f"                keyPassword {KEYPROPS_MARK}['keyPassword']\n"
            "            }\n"
            "        }\n"
            "    }\n\n"
        )
        sign_ref = (f"signingConfig = {KEYPROPS_MARK}.isEmpty() ? signingConfigs.debug : signingConfigs.release")

    if is_kts and "import java.util.Properties" not in s:
        s = "import java.util.Properties\n\n" + s  # KTS'te `java` uzantısı paket adını gölgeler; import şart
    # 1) Properties okuyucu: android { bloğundan önce
    s, n1 = re.subn(r"^android\s*\{", lambda m: props + m.group(0), s, count=1, flags=re.M)
    # 2) signingConfigs: buildTypes'tan önce
    s, n2 = re.subn(r"^([ \t]*)buildTypes\s*\{", lambda m: signing + m.group(0), s, count=1, flags=re.M)
    # 3) release buildType'ı bağla
    s, n3 = re.subn(r"signingConfig\s*=?\s*signingConfigs\.(?:getByName\(\"debug\"\)|debug)", sign_ref, s, count=1)
    if n3 == 0:
        s, n3 = re.subn(r"(buildTypes\s*\{\s*\n\s*(?:getByName\(\"release\"\)|release)\s*\{\s*\n)",
                        lambda m: m.group(1) + "            " + sign_ref + "\n", s, count=1)
    if not (n1 and n2 and n3):
        sys.exit(f"{path.name}: imza yaması uygulanamadı (props={n1}, signingConfigs={n2}, release={n3}).")
    path.write_text(s, encoding="utf-8")
    print(f"{path.name}: signingConfigs.release + release bağlandı (key.properties yoksa debug imza)")


R8_MARK = "zarflaR8"


def patch_r8() -> None:
    """Release buildType'ında R8 küçültme/gizleme + kaynak küçültmeyi açar, proguard-rules.pro'yu bağlar (idempotent)."""
    rules = APP / "proguard-rules.pro"
    if not rules.exists():
        sys.exit("android/app/proguard-rules.pro yok (depoda durmalı).")
    path = _app_gradle()
    s = path.read_text(encoding="utf-8")
    if R8_MARK in s:
        print(f"{path.name}: R8 yapılandırması zaten var")
        return
    is_kts = path.suffix == ".kts"
    # Şablonun olası eski minify/shrink satırlarını temizle
    s = re.sub(r"^[ \t]*(?:isMinifyEnabled|minifyEnabled|isShrinkResources|shrinkResources)\b[^\n]*\n", "", s, flags=re.M)
    s = re.sub(r"^[ \t]*proguardFiles\b[^\n]*\n", "", s, flags=re.M)
    if is_kts:
        block = (f"            // {R8_MARK}\n"
                 "            isMinifyEnabled = true\n"
                 "            isShrinkResources = true\n"
                 '            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")\n')
    else:
        block = (f"            // {R8_MARK}\n"
                 "            minifyEnabled true\n"
                 "            shrinkResources true\n"
                 "            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'\n")
    s, n = re.subn(r"^([ \t]*signingConfig\s*=[^\n]*\n)", lambda m: m.group(1) + block, s, count=1, flags=re.M)
    if n == 0:
        sys.exit(f"{path.name}: R8 yaması uygulanamadı (release bloğunda signingConfig satırı yok).")
    path.write_text(s, encoding="utf-8")
    print(f"{path.name}: isMinifyEnabled/isShrinkResources=true + proguard-rules.pro bağlandı")


def patch_settings() -> None:
    """google-services eklentisinin sürümünü kök düzeyde bildirir (apply false)."""
    kts = ANDROID / "settings.gradle.kts"
    groovy = ANDROID / "settings.gradle"
    path = kts if kts.exists() else groovy
    if path.exists():
        s = path.read_text(encoding="utf-8")
        if GMS_ID in s:
            print(f"{path.name}: {GMS_ID} zaten var")
            return
        is_kts = path.suffix == ".kts"
        line = (f'    id("{GMS_ID}") version "{GMS_VERSION}" apply false' if is_kts
                else f'    id "{GMS_ID}" version "{GMS_VERSION}" apply false')
        # pluginManagement { plugins { ... } } değil, en üst düzey plugins { } bloğu
        m = re.search(r"^plugins\s*\{.*?(\n\}\s*\n)", s, flags=re.M | re.S)
        if m:
            at = m.start(1)
            s = s[:at] + "\n" + line + s[at:]
            path.write_text(s, encoding="utf-8")
            print(f"{path.name}: {GMS_ID} {GMS_VERSION} eklendi")
            return
    # Eski şablon: buildscript classpath (kök build.gradle)
    root = ANDROID / "build.gradle.kts"
    if not root.exists():
        root = ANDROID / "build.gradle"
    s = root.read_text(encoding="utf-8")
    if GMS_ID in s or "google-services:" in s:
        return
    dep = (f'        classpath("com.google.gms:google-services:{GMS_VERSION}")' if root.suffix == ".kts"
           else f'        classpath "com.google.gms:google-services:{GMS_VERSION}"')
    s2, n = re.subn(r"(dependencies\s*\{\s*\n)", lambda mm: mm.group(1) + dep + "\n", s, count=1)
    if n == 0:
        sys.exit("google-services eklentisi eklenemedi: settings.gradle plugins bloğu ve buildscript bulunamadı.")
    root.write_text(s2, encoding="utf-8")
    print(f"{root.name}: google-services classpath eklendi")


def check_google_services() -> None:
    gs = APP / "google-services.json"
    if not gs.exists():
        sys.exit("android/app/google-services.json yok (Firebase yapılandırması).")
    if APP_ID not in gs.read_text(encoding="utf-8"):
        sys.exit(f"google-services.json içinde {APP_ID} paketi yok.")


AD_ID_PERMISSION = "com.google.android.gms.permission.AD_ID"
AD_CONFIG = ROOT / "lib" / "ads" / "ad_config.dart"


def read_admob_app_id() -> str:
    """lib/ads/ad_config.dart içindeki kAdMobAndroidAppId değerini okur (ca-app-pub-XXXX~YYYY)."""
    text = AD_CONFIG.read_text(encoding="utf-8")
    m = re.search(r"kAdMobAndroidAppId\s*=\s*'(ca-app-pub-\d+~\d+)'", text)
    if not m:
        sys.exit("lib/ads/ad_config.dart: kAdMobAndroidAppId bulunamadı veya biçimi bozuk (ca-app-pub-XXXX~YYYY).")
    return m.group(1)


def patch_manifest() -> None:
    m = APP / "src" / "main" / "AndroidManifest.xml"
    s = m.read_text(encoding="utf-8")
    s = re.sub(r'android:label="[^"]*"', 'android:label="Zarfla"', s, count=1)
    s = re.sub(r'android:icon="[^"]*"', 'android:icon="@mipmap/ic_launcher"', s, count=1)
    if "android:roundIcon" not in s:
        s = s.replace('android:icon="@mipmap/ic_launcher"',
                      'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"', 1)
    # AdMob uygulama kimliği: tek kaynak lib/ads/ad_config.dart (gerçek kimliğe geçiş tek düzenleme).
    app_id = read_admob_app_id()
    if "com.google.android.gms.ads.APPLICATION_ID" not in s:
        meta = (f'    <meta-data\n            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
                f'            android:value="{app_id}"/>\n')
        s, n = re.subn(r"(</application>)", lambda mm: meta + "    " + mm.group(1), s, count=1)
        if n == 0:
            sys.exit("AndroidManifest.xml: </application> bulunamadı; AdMob meta-data eklenemedi.")
    else:
        s = re.sub(r'(com\.google\.android\.gms\.ads\.APPLICATION_ID"\s+android:value=")[^"]*(")',
                   lambda mm: mm.group(1) + app_id + mm.group(2), s, count=1)
    if AD_ID_PERMISSION not in s:
        perm = f'<uses-permission android:name="{AD_ID_PERMISSION}"/>\n    '
        s, n = re.subn(r"(<application\b)", lambda mm: perm + mm.group(1), s, count=1)
        if n == 0:
            sys.exit("AndroidManifest.xml: <application> bulunamadı; AD_ID izni eklenemedi.")
    s = patch_application_tag(s)
    m.write_text(s, encoding="utf-8")
    print(f"AndroidManifest.xml: name=.ZarflaApplication, yedekleme kuralları, label=Zarfla, icon/roundIcon, AdMob app id={app_id}, AD_ID izni")


KOTLIN_PKG_DIR = APP / "src" / "main" / "kotlin" / "com" / "demirgamesstudio" / "zarfla"
APPLICATION_KT = """package com.demirgamesstudio.zarfla

import android.app.Application
import android.content.Context
import android.os.Build
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

/**
 * Yerel çökme kaydedici: yakalanmamış Java/Kotlin istisnasını files/zarfla_last_crash.txt dosyasına yazar,
 * sonra önceki işleyiciye (sistem) devreder. Dart tarafı (lib/startup/startup_log.dart) bir sonraki açılışta
 * dosyayı okur. scripts/patch_android.py tarafından üretilir; elle düzenlemeyin.
 */
class ZarflaApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        installCrashRecorder(base)
    }

    private fun installCrashRecorder(ctx: Context) {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val sw = StringWriter()
                error.printStackTrace(PrintWriter(sw))
                val text = StringBuilder()
                    .append("time=").append(System.currentTimeMillis()).append('\\n')
                    .append("thread=").append(thread.name).append('\\n')
                    .append("device=").append(Build.MANUFACTURER).append(' ').append(Build.MODEL)
                    .append(" sdk=").append(Build.VERSION.SDK_INT).append('\\n')
                    .append("app=").append(versionOf(ctx)).append('\\n')
                    .append(sw.toString().take(16000))
                    .toString()
                File(ctx.filesDir, "zarfla_last_crash.txt").writeText(text)
            } catch (t: Throwable) {
            }
            previous?.uncaughtException(thread, error)
        }
    }

    @Suppress("DEPRECATION")
    private fun versionOf(ctx: Context): String = try {
        val pi = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else pi.versionCode.toLong()
        "${pi.versionName} ($code)"
    } catch (t: Throwable) {
        "?"
    }
}
"""

BACKUP_RULES = """<?xml version="1.0" encoding="utf-8"?>
<!-- Android 11 ve öncesi: yalnız uygulamanın kendi ayar/taslak dosyası yedeklenir (SDK durumları hariç). -->
<full-backup-content>
    <include domain="sharedpref" path="FlutterSharedPreferences.xml"/>
</full-backup-content>
"""

DATA_EXTRACTION_RULES = """<?xml version="1.0" encoding="utf-8"?>
<!-- Android 12+: bulut yedeği ve cihazdan cihaza aktarımda yalnız uygulamanın kendi ayar/taslak dosyası. -->
<data-extraction-rules>
    <cloud-backup>
        <include domain="sharedpref" path="FlutterSharedPreferences.xml"/>
    </cloud-backup>
    <device-transfer>
        <include domain="sharedpref" path="FlutterSharedPreferences.xml"/>
    </device-transfer>
</data-extraction-rules>
"""


def write_native_files() -> None:
    KOTLIN_PKG_DIR.mkdir(parents=True, exist_ok=True)
    (KOTLIN_PKG_DIR / "ZarflaApplication.kt").write_text(APPLICATION_KT, encoding="utf-8")
    xml = APP / "src" / "main" / "res" / "xml"
    xml.mkdir(parents=True, exist_ok=True)
    (xml / "zarfla_backup_rules.xml").write_text(BACKUP_RULES, encoding="utf-8")
    (xml / "zarfla_data_extraction_rules.xml").write_text(DATA_EXTRACTION_RULES, encoding="utf-8")
    print("ZarflaApplication.kt + yedekleme kuralları yazıldı")


def patch_application_tag(s: str) -> str:
    """<application>: android:name=.ZarflaApplication, yalnız kendi verimizi yedekleyen kurallar (idempotent)."""
    m = re.search(r"<application\b[^>]*>", s, flags=re.S)
    if not m:
        sys.exit("AndroidManifest.xml: <application> etiketi bulunamadı.")
    tag = m.group(0)
    new = tag
    if 'android:name="${applicationName}"' in new:
        new = new.replace('android:name="${applicationName}"', 'android:name=".ZarflaApplication"')
    elif ".ZarflaApplication" not in new:
        new2, n = re.subn(r'android:name="[^"]*"', 'android:name=".ZarflaApplication"', new, count=1)
        new = new2 if n else new.replace("<application", '<application\n        android:name=".ZarflaApplication"', 1)
    attrs = {
        "android:allowBackup": "true",
        "android:fullBackupContent": "@xml/zarfla_backup_rules",
        "android:dataExtractionRules": "@xml/zarfla_data_extraction_rules",
    }
    for k, v in attrs.items():
        if re.search(k + r'="[^"]*"', new):
            new = re.sub(k + r'="[^"]*"', f'{k}="{v}"', new)
        else:
            new = new.replace("<application", f'<application\n        {k}="{v}"', 1)
    return s.replace(tag, new, 1)


def copy_icons() -> None:
    if not ICON_SRC.exists():
        print("UYARI: assets/branding/android/res yok; Flutter varsayılan simgesi kalır.")
        return
    dst = APP / "src" / "main" / "res"
    n = 0
    for f in ICON_SRC.rglob("*"):
        if f.is_file():
            t = dst / f.relative_to(ICON_SRC)
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, t)
            n += 1
    print(f"Simge: {n} dosya kopyalandı")


if __name__ == "__main__":
    check_google_services()
    patch_gradle()
    patch_signing()
    patch_r8()
    patch_settings()
    write_native_files()
    patch_manifest()
    copy_icons()
