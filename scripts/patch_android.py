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
    R8/küçültme bilerek kapalı tutulur (bkz. README \"İmzalı sürüm\"): Firebase/Flutter için keep kuralı
    gerektirmeyen güvenli yol; AAB boyutu Play'in kendi sıkıştırmasıyla yine küçülür.
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
        minify = "            isMinifyEnabled = false\n            isShrinkResources = false\n"
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
        minify = "            minifyEnabled false\n            shrinkResources false\n"

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
    # 4) R8 kapalı
    if "isMinifyEnabled" not in s and "minifyEnabled" not in s:
        s = re.sub(r"(signingConfig\s*=[^\n]*\n)", lambda m: m.group(1) + minify, s, count=1)
    if not (n1 and n2 and n3):
        sys.exit(f"{path.name}: imza yaması uygulanamadı (props={n1}, signingConfigs={n2}, release={n3}).")
    path.write_text(s, encoding="utf-8")
    print(f"{path.name}: signingConfigs.release + release bağlandı (key.properties yoksa debug imza)")


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
    m.write_text(s, encoding="utf-8")
    print(f"AndroidManifest.xml: label=Zarfla, icon/roundIcon, AdMob app id={app_id}, AD_ID izni")


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
    patch_settings()
    patch_manifest()
    copy_icons()
