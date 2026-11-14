#!/usr/bin/env python3
"""flutter create çıktısına Zarfla ayarlarını uygular (idempotent).

- applicationId / namespace: com.demirgamesstudio.zarfla (flutter create --org ile gelir, burada doğrulanır)
- minSdk >= 23, targetSdk/compileSdk >= 35 (Flutter'ın varsayılanı daha yüksekse o kullanılır;
  Play'in güncel hedef API şartı ve eklentilerin compileSdk isteği bozulmasın diye)
- Uygulama adı: "Zarfla"
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "android" / "app"
APP_ID = "com.demirgamesstudio.zarfla"


def patch_gradle() -> None:
    kts = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"
    path = kts if kts.exists() else groovy
    if not path.exists():
        sys.exit("android/app/build.gradle(.kts) bulunamadı; önce flutter create çalıştırın.")
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
    path.write_text(s, encoding="utf-8")
    print(f"{path.relative_to(ROOT)} güncellendi")


def patch_manifest() -> None:
    m = APP / "src" / "main" / "AndroidManifest.xml"
    s = m.read_text(encoding="utf-8")
    s2 = re.sub(r'android:label="[^"]*"', 'android:label="Zarfla"', s, count=1)
    m.write_text(s2, encoding="utf-8")
    print("AndroidManifest.xml: android:label=Zarfla")


if __name__ == "__main__":
    patch_gradle()
    patch_manifest()
