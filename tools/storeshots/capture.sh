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
alive() { [ "$(adb get-state 2>/dev/null | tr -d '\r')" = device ] || { echo "!!! EMULATOR OLU"; return 1; }; }

shot() { # $1 dil, $2 ad
  adb exec-out screencap -p > "$OUT/$1/$2.png"
  python3 "$TOOLS/uia.py" dump "$OUT/$1/$2.xml" || true
}
swipe_up() { adb shell input swipe 540 1250 540 450 500; sleep 1.2; }
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


tapx() { python3 "$TOOLS/uia.py" tap "$@"; }
emit() { # $1 dil
  echo "--- JPEG base64 ($1)"
  for f in ${EMIT:-01_home 03_gallery 03b_gallery 04_editor 04b_editor 06_paywall 06b_paywall 06c_paywall 06d_paywall}; do
    [ -f "$OUT/$1/$f.png" ] || continue
    python3 -c "from PIL import Image;Image.open('$OUT/$1/$f.png').convert('RGB').save('/tmp/e.jpg','JPEG',quality=93)" || continue
    echo "=====B64 $1/$f"; base64 -w 3000 /tmp/e.jpg; echo "=====END"
  done
}
step_home()    { alive || return 1; launch 9; shot $L 01_home; }
step_gallery() { alive || return 1
  tapx "^\+ ?$(lab $L newInv)" first; sleep 2; shot $L 02_type
  tapx "^$(lab $L type_dugun)" first; sleep 4; shot $L 03_gallery
  swipe_up; shot $L 03b_gallery; swipe_up; shot $L 03c_gallery; }
step_editor()  { alive || return 1
  launch 7; tapx "$N1" first; sleep 3; shot $L 04_editor
  swipe_up; shot $L 04b_editor; swipe_up; shot $L 04c_editor; swipe_up; shot $L 04d_editor; }
step_preview() { alive || return 1
  tapx ":\s*$(lab $L preview)\$" first; sleep 1
  for k in 0 1 2 3 4 5 6 7; do adb exec-out screencap -p > "$OUT/$L/05_open_$k.png"; sleep 0.9; done; }
step_paywall() { alive || return 1
  tapx "^$(lab $L publish)\$" last; sleep 4; shot $L 06_paywall
  swipe_up; shot $L 06b_paywall; swipe_up; shot $L 06c_paywall; swipe_up; shot $L 06d_paywall; }

step_paywallv() { alive || return 1
  tapx "^$(lab $L publish)\$" last; sleep 4
  adb shell input swipe 540 1250 540 550 1000; sleep 1.5; shot $L 06v_a
  for k in b c d e; do adb shell input swipe 540 1250 540 1170 900; sleep 1.5; shot $L 06v_$k; done; }

for L in $LANGS; do
  echo "################ DİL: $L"
  alive || break
  mkdir -p "$OUT/$L"
  python3 "$TOOLS/seed.py" $L "$OUT/$L/prefs.xml" "$ROOT"
  mv "$OUT/$L/prefs.xml.meta.json" "$OUT/$L/meta.json"
  reseed $L
  N1=$(python3 -c "import json;print(json.load(open('$OUT/$L/meta.json'))['n1'])")
  for st in ${STEPS:-home gallery editor paywall}; do echo "--- $st"; step_$st || break; emit_now=1; done
  emit $L
done
adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1
adb logcat -d 2>/dev/null | grep -E "flutter|AndroidRuntime|FATAL" | tail -30 || true
