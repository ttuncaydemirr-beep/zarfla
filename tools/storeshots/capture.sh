#!/usr/bin/env bash
# Emülatörde (API 34, 1080x1920) Zarfla debug APK'sını açar; her dil için örnek davetiyelerle gerçek ekranları çeker.
# Çıktı: out/<dil>/<ad>.png  (+ .xml). Ağ KAPALI (uçak modu): reklam isteği/gösterimi olmaz.
set -u
PKG=com.demirgamesstudio.zarfla
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS="$ROOT/tools/storeshots"
OUT="$ROOT/out"
LANGS="${LANGS:-tr en de ar es pt id}"
mkdir -p "$OUT"

adb root >/dev/null 2>&1; sleep 3; adb wait-for-device
adb install -r -g app.apk >/dev/null && echo "APK kuruldu"
# Temiz durum çubuğu (demo modu) ve hareketli gezinme
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
adb shell cmd overlay enable com.android.internal.systemui.navbar.gestural >/dev/null 2>&1 || true
# Reklam güvenliği: ağı kapat (gerçek/test reklam isteği yapılmasın)
adb shell cmd connectivity airplane-mode enable >/dev/null 2>&1 || adb shell settings put global airplane_mode_on 1
adb shell wm size; adb shell wm density

shot() { # $1 dil, $2 ad
  adb exec-out screencap -p > "$OUT/$1/$2.png"
  python3 "$TOOLS/uia.py" dump "$OUT/$1/$2.xml" || true
}
swipe_up() { adb shell input swipe 540 1500 540 700 450; sleep 1; }
launch() {
  adb shell am force-stop $PKG
  adb shell am start -n $PKG/.MainActivity >/dev/null 2>&1 || adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep "${1:-7}"
}
lab() { python3 -c "import json,sys;print(json.load(open('$OUT/$1/meta.json'))['labels']['$2'])"; }
reseed() {
  adb shell pm clear $PKG >/dev/null
  adb push "$OUT/$1/prefs.xml" /data/local/tmp/fsp.xml >/dev/null
  adb shell chmod 644 /data/local/tmp/fsp.xml
  UID_=$(adb shell stat -c %u /data/data/$PKG | tr -d '\r')
  adb shell "mkdir -p /data/data/$PKG/shared_prefs && cp /data/local/tmp/fsp.xml /data/data/$PKG/shared_prefs/FlutterSharedPreferences.xml && chown -R $UID_:$UID_ /data/data/$PKG/shared_prefs && chmod 660 /data/data/$PKG/shared_prefs/*.xml && restorecon -R /data/data/$PKG/shared_prefs"
}

for L in $LANGS; do
  echo "################ DİL: $L"
  mkdir -p "$OUT/$L"
  python3 "$TOOLS/seed.py" $L "$OUT/$L/prefs.xml" "$ROOT"
  mv "$OUT/$L/prefs.xml.meta.json" "$OUT/$L/meta.json"
  reseed $L
  N1=$(python3 -c "import json;print(json.load(open('$OUT/$L/meta.json'))['n1'])")

  echo "--- 1) Ana ekran"
  launch 9
  shot $L 01_home

  echo "--- 2) Tasarım galerisi"
  python3 "$TOOLS/uia.py" tap "^\+ ?$(lab $L newInv)" first; sleep 2
  shot $L 02_type
  python3 "$TOOLS/uia.py" tap "^$(lab $L type_dugun)" first; sleep 3
  shot $L 03_gallery
  swipe_up; shot $L 03b_gallery
  swipe_up; shot $L 03c_gallery

  echo "--- 3) Düzenleyici"
  launch 7
  python3 "$TOOLS/uia.py" tap "$N1" first; sleep 3
  shot $L 04_editor
  swipe_up; shot $L 04b_editor
  swipe_up; shot $L 04c_editor
  swipe_up; shot $L 04d_editor

  echo "--- 4) Önizleme (açılış animasyonu)"
  python3 "$TOOLS/uia.py" tap "^$(lab $L preview)\$" first; sleep 1
  for k in 0 1 2 3 4 5 6 7 8 9; do
    adb exec-out screencap -p > "$OUT/$L/05_open_$k.png"; sleep 0.8
  done
  python3 "$TOOLS/uia.py" dump "$OUT/$L/05_after.xml" || true

  echo "--- 5) Yayın / ödeme"
  python3 "$TOOLS/uia.py" tap "^$(lab $L publish)\$" last; sleep 3
  shot $L 06_paywall
  swipe_up; shot $L 06b_paywall
  swipe_up; shot $L 06c_paywall
  echo "--- JPEG base64 ($L)"
  for f in ${EMIT:-01_home 03_gallery 03b_gallery 04_editor 04b_editor 04c_editor 05_open_2 05_open_4 05_open_6 06_paywall 06b_paywall}; do
    [ -f "$OUT/$L/$f.png" ] || continue
    python3 -c "from PIL import Image;Image.open('$OUT/$L/$f.png').convert('RGB').save('/tmp/e.jpg','JPEG',quality=93)"
    echo "=====B64 $L/$f"; base64 -w 3000 /tmp/e.jpg; echo "=====END"
  done
done
adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
adb logcat -d | grep -E "flutter|AndroidRuntime|FATAL" | tail -40 || true
