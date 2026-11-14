#!/usr/bin/env bash
# Zarfla yazı tiplerini github.com/google/fonts deposundan indirir ve
# assets/fonts/ altına sabit adlarla koyar; OFL lisanslarını da kopyalar.
# Kullanım: bash scripts/fetch_fonts.sh   (proje kökünden ya da herhangi bir yerden)
# Aşama 2 notu: Davetli sayfası (assets/invite/invite.html) sitede yayınlanırken
# aynı dosyalar sitenin /fonts/ klasörüne kopyalanıp @font-face ile kullanılacak
# (Google Fonts CDN'i kullanılmayacak: izleme yok, gizlilik politikasıyla uyumlu).
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="https://raw.githubusercontent.com/google/fonts/main/ofl"
OUT="assets/fonts"
LIC="$OUT/licenses"
mkdir -p "$OUT" "$LIC"

fetch() { # $1 = depo yolu (URL kodlu), $2 = hedef dosya
  local url="$BASE/$1" dest="$2"
  if [ -s "$dest" ]; then echo "var: $dest"; return 0; fi
  echo "indiriliyor: $url"
  curl -fsSL --retry 4 --retry-delay 3 -o "$dest.tmp" "$url"
  mv "$dest.tmp" "$dest"
}

# Değişken yazı tipleri: köşeli parantez ve virgüller URL'de kodlanır.
fetch "fraunces/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf"        "$OUT/Fraunces.ttf"
fetch "fraunces/Fraunces-Italic%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf" "$OUT/Fraunces-Italic.ttf"
fetch "manrope/Manrope%5Bwght%5D.ttf"                               "$OUT/Manrope.ttf"
fetch "notonaskharabic/NotoNaskhArabic%5Bwght%5D.ttf"               "$OUT/NotoNaskhArabic.ttf"
fetch "amiri/Amiri-Regular.ttf"                                     "$OUT/Amiri-Regular.ttf"
fetch "amiri/Amiri-Bold.ttf"                                        "$OUT/Amiri-Bold.ttf"

fetch "fraunces/OFL.txt"        "$LIC/OFL-Fraunces.txt"
fetch "manrope/OFL.txt"         "$LIC/OFL-Manrope.txt"
fetch "notonaskharabic/OFL.txt" "$LIC/OFL-NotoNaskhArabic.txt"
fetch "amiri/OFL.txt"           "$LIC/OFL-Amiri.txt"

# Basit doğrulama: TrueType imzası (00 01 00 00) ya da 'true'
for f in "$OUT"/*.ttf; do
  sig=$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')
  if [ "$sig" != "00010000" ] && [ "$sig" != "74727565" ]; then
    echo "HATA: $f geçerli bir TTF değil (imza $sig)" >&2; exit 1
  fi
done
ls -l "$OUT" "$LIC"
