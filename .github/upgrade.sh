#!/usr/bin/env bash
# Güncelleme yolu: app1..appN sırayla (adb install -r) kurulur, açılır; sonuncu hariç monkey ile kullanılır.
P=com.demirgamesstudio.zarfla
for k in $(seq 1 "$N"); do
  echo "===== app$k"
  adb install -r "app$k.apk"
  adb shell dumpsys package $P | grep -m2 -E "versionCode|versionName"
  adb logcat -c
  adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null
  sleep 20
  if [ "$k" -lt "$N" ]; then
    adb shell monkey -p $P --pct-syskeys 0 --pct-appswitch 0 --throttle 150 -s 7 400 >/dev/null 2>&1 || true
    sleep 3
    adb shell input keyevent KEYCODE_HOME
    sleep 2
  else
    adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null
    sleep 10
  fi
  if adb shell pidof $P >/dev/null; then echo "app$k CALISIYOR"; else echo "app$k CALISMIYOR (coktu?)"; fi
  adb logcat -d > "logcat$k.txt" || true
  grep -n -A40 -E "FATAL EXCEPTION|Fatal signal" "logcat$k.txt" | head -150 || true
  grep -E "zarfla|E/flutter|AndroidRuntime" "logcat$k.txt" | head -40 || true
done
adb exec-out screencap -p > shot_final.png || true
