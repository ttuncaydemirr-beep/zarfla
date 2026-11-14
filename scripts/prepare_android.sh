#!/usr/bin/env bash
# android/ klasörünü, kurulu Flutter sürümünün güncel şablonuyla üretir ve
# Zarfla ayarlarını uygular. Var olan dosyaların üzerine yazmaz (lib/, test/,
# pubspec.yaml korunur). İkinci kez çalıştırmak güvenlidir.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f android/app/build.gradle.kts ] && [ ! -f android/app/build.gradle ]; then
  flutter create --platforms=android --org com.demirgamesstudio --project-name zarfla .
fi
python3 scripts/patch_android.py
