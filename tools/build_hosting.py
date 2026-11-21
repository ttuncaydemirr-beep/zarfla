#!/usr/bin/env python3
"""Zarfla davetli sayfasını Firebase Hosting için üretir (çıktı: hosting/, depoya girmez).

Site: https://zarfla-37da9.web.app
  /davetiye/?id=<id>[&g=Ad]  davetli sayfası (motor: assets/invite/invite.html + hosting-src/loader.js)
  /music/<id>.mp3            Zarfla müzikleri — YALNIZ telif kaydı onaylı manifestteki parçalar (sha256 doğrulanır)
  /fonts/…                   OFL yazı tipleri (motorun ../fonts/ yolu birebir çalışır)
  /, /404.html, /robots.txt  sade kök sayfa (Play + stüdyo sitesi), 404

Girdiler:
  assets/invite/invite.html  motor (TEK KAYNAK; uygulama içi önizleme de bunu kullanır)
  hosting-src/               yükleyici, durum CSS'i, kök/404 sayfaları, OG görseli, simge
  --site <yol>               stüdyo sitesi deposunun kopyası (ttuncaydemirr-beep.github.io):
                               src/music/manifest.json + <id>.mp3 (fetch-music.yml ile getirilen lisanslı dosyalar)
                               src/fonts/ (fetch-fonts.yml ile getirilen OFL dosyaları)
Yeni parça EKLENMEZ: manifestteki kimlikler motorun MUSIC listesiyle birebir aynı olmalı, yoksa üretim durur.

Çalıştırma:  python3 tools/build_hosting.py --site ../ttuncaydemirr-beep.github.io
             (yerel deneme için dosyalar eksikse: --allow-missing)
             invite.html / loader.js değişince: --write-firebase-json ile CSP özetini firebase.json'a yazıp commit edin
             (CI: --check-csp, firebase.json eskiyse durur).
"""
import argparse
import base64
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / "assets" / "invite" / "invite.html"
HSRC = ROOT / "hosting-src"
HOST_URL = "https://zarfla-37da9.web.app"

# CSP (güvenlik denetimi M-1): betiklerde 'unsafe-inline' YOK. script-src yalnız sayfadaki satır içi <script> bloklarının
# sha256 özetleri; özetler her üretimde hesaplanır ve hem meta etikete hem firebase.json başlığına aynı değer yazılır.
# Satır içi olay işleyicisi (onclick= vb.) kullanılamaz: motor addEventListener kullanır (üretim bunu da denetler).
# style-src 'unsafe-inline' bilinçli olarak kalır: motor çok sayıda style="" özniteliği ve JS ile stil ataması kullanır
# (stil enjeksiyonu betik çalıştıramaz; tüm metin/öznitelik verisi zaten kaçışlı).
INVITE_CSP_TMPL = ("default-src 'none'; script-src {script}; style-src 'unsafe-inline'; "
                   "img-src 'self' data: https://firebasestorage.googleapis.com; font-src 'self'; media-src 'self'; "
                   "connect-src https://firestore.googleapis.com; base-uri 'none'; form-action 'none'; object-src 'none'")
CSP_PLACEHOLDER = "__ZARFLA_INVITE_CSP__"


def invite_csp(html):
    """Meta CSP ve başlık CSP'si (başlık = meta + frame-ancestors; meta etiketinde frame-ancestors çalışmaz)."""
    blocks = re.findall(r"<script>(.*?)</script>", html, re.S)
    if re.search(r"<script(?!>)[^>]*>", html):
        fail("davetiye sayfasında öznitelikli/harici <script> var — yalnız düz satır içi <script> desteklenir")
    if not blocks:
        fail("davetiye sayfasında satır içi betik bulunamadı")
    hashes = sorted({"'sha256-" + base64.b64encode(hashlib.sha256(b.encode("utf-8")).digest()).decode() + "'"
                     for b in blocks})
    meta = INVITE_CSP_TMPL.format(script=" ".join(hashes))
    return meta, meta + "; frame-ancestors 'none'"


INLINE_HANDLER = re.compile(r"""<[a-zA-Z][^<>]*?\son[a-z]+\s*=""")
INVITE_TITLE = "Davetiye · Zarfla"
INVITE_DESC = "Size özel bir davetiye var."

# Motorun ve durum sayfalarının kullandığı yazı tipleri + OFL lisansları (stüdyo sitesi src/fonts ile aynı dosyalar).
FONT_FILES = ["Fraunces.ttf", "Fraunces-Italic.ttf", "Manrope.ttf", "NotoNaskhArabic.ttf",
              "Fraunces-Soft-500-700.woff", "NotoSansArabic-400-700.woff"]
FONT_LICENSES = ["OFL-Fraunces.txt", "OFL-Manrope.txt", "OFL-NotoNaskhArabic.txt", "OFL-NotoSansArabic.txt"]


def fail(msg):
    print("HATA: " + msg, file=sys.stderr)
    sys.exit(1)


def build_invite(out):
    h = ENGINE.read_text(encoding="utf-8")

    def sub(old, new):
        nonlocal h
        if h.count(old) != 1:
            fail(f"invite.html'de beklenen parça bulunamadı: {old[:60]!r}")
        h = h.replace(old, new)

    sub('<meta name="robots" content="noindex">', '<meta name="robots" content="noindex,nofollow">')
    sub("<title>Zarfla</title>", f"<title>{INVITE_TITLE}</title>")
    head = f"""<meta http-equiv="Content-Security-Policy" content="{CSP_PLACEHOLDER}">
<meta name="referrer" content="no-referrer">
<meta name="theme-color" content="#F7F1E8">
<meta name="description" content="{INVITE_DESC}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Zarfla">
<meta property="og:title" content="{INVITE_TITLE}">
<meta property="og:description" content="{INVITE_DESC}">
<meta property="og:image" content="{HOST_URL}/davetiye/og.png">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="../assets/icons/zarfla-192.png" type="image/png">"""
    sub('<meta name="robots" content="noindex,nofollow">', '<meta name="robots" content="noindex,nofollow">\n' + head)
    # Yazı tipleri: motor ../fonts/ kullanır → /davetiye/ altından /fonts/ (yol değiştirilmez).
    if 'url("../fonts/' not in h:
        fail("invite.html'de ../fonts/ yazı tipi yolu bulunamadı")
    sub("</style>\n</head>", "</style>\n<style>\n" + (HSRC / "states.css").read_text(encoding="utf-8") + "</style>\n</head>")
    i = h.index("(function boot(){")
    j = h.index("</script>", i)
    h = h[:i] + (HSRC / "loader.js").read_text(encoding="utf-8") + h[j:]
    sub("<body>\n", "<body>\n<noscript><div class=\"zs-nojs\">JavaScript gerekli · JavaScript required</div></noscript>\n")
    # Statik işaretlemede satır içi olay işleyicisi olmamalı (CSP'de 'unsafe-inline' yok, çalışmaz).
    static = re.sub(r"<script>.*?</script>", "", h, flags=re.S)
    m = INLINE_HANDLER.search(static)
    if m:
        fail(f"satır içi olay işleyicisi bulundu (addEventListener kullanın): {m.group(0)[:80]!r}")
    meta_csp, header_csp = invite_csp(h)
    sub(CSP_PLACEHOLDER, meta_csp)
    if invite_csp(h) != (meta_csp, header_csp):
        fail("CSP özeti meta eklendikten sonra değişti")
    d = out / "davetiye"
    d.mkdir(parents=True, exist_ok=True)
    (d / "index.html").write_text(h, encoding="utf-8")
    shutil.copyfile(HSRC / "og.png", d / "og.png")
    return header_csp


def engine_music_ids():
    h = ENGINE.read_text(encoding="utf-8")
    a, b = h.index("/*MUSIC-BEGIN*/"), h.index("/*MUSIC-END*/")
    m = re.search(r"const MUSIC=\{(.*?)\n\};", h[a:b], re.S)
    if not m:
        fail("motorda MUSIC listesi bulunamadı")
    return re.findall(r'^"([a-z0-9-]+)":\{', m.group(1), re.M)


def sha256(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def build_music(out, site, allow_missing):
    src = site / "src" / "music"
    mf = src / "manifest.json"
    if not mf.is_file():
        fail(f"müzik manifesti yok: {mf}")
    manifest = json.loads(mf.read_text(encoding="utf-8"))
    tracks = manifest["tracks"]
    ids = [t["id"] for t in tracks]
    eng = engine_music_ids()
    if sorted(ids) != sorted(eng) or len(set(ids)) != len(ids):
        fail(f"manifest ({len(ids)}) ile motorun MUSIC listesi ({len(eng)}) aynı değil — yeni parça eklenemez: "
             f"fazla={sorted(set(ids) - set(eng))} eksik={sorted(set(eng) - set(ids))}")
    dst = out / "music"
    dst.mkdir(parents=True, exist_ok=True)
    n = 0
    for t in tracks:
        if t.get("file") != t["id"] + ".mp3":
            fail(f"beklenmeyen dosya adı: {t.get('file')}")
        f = src / t["file"]
        if not f.is_file():
            if allow_missing:
                continue
            fail(f"müzik dosyası yok: {f} (sitede fetch-music iş akışı çalıştırılmalı)")
        if sha256(f) != t["sha256"]:
            fail(f"sha256 uyuşmuyor: {t['file']} (telif kaydındaki dosya değil)")
        shutil.copyfile(f, dst / t["file"])
        n += 1
    credits = [{k: t[k] for k in ("id", "title", "composer", "performer", "credit", "license", "license_url", "source_page")}
               for t in tracks]
    (dst / "credits.json").write_text(json.dumps(credits, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return n, len(tracks)


def build_fonts(out, site, allow_missing):
    src = site / "src" / "fonts"
    dst = out / "fonts"
    dst.mkdir(parents=True, exist_ok=True)
    n = 0
    for name in FONT_FILES + FONT_LICENSES:
        f = src / name
        if not f.is_file():
            if allow_missing:
                continue
            fail(f"yazı tipi yok: {f} (sitede fetch-fonts iş akışı çalıştırılmalı)")
        if name.endswith(".ttf") and f.read_bytes()[:4] not in (b"\x00\x01\x00\x00", b"true"):
            fail(f"geçerli TTF değil: {f}")
        if name.endswith(".woff") and f.read_bytes()[:4] != b"wOFF":
            fail(f"geçerli WOFF değil: {f}")
        shutil.copyfile(f, dst / name)
        n += 1
    return n


def firebase_csp_values(cfg):
    vals = []
    for rule in cfg["hosting"].get("headers", []):
        if rule["source"].startswith("/davetiye"):
            for kv in rule["headers"]:
                if kv["key"] == "Content-Security-Policy":
                    vals.append(kv["value"])
    return vals


def check_firebase_json(header_csp, write):
    """firebase.json'daki /davetiye CSP başlıkları üretilen sayfanın özetleriyle aynı olmalı.
    write=True: farklıysa firebase.json'u yerinde günceller (biçim korunur; değişikliği commit edin)."""
    path = ROOT / "firebase.json"
    raw = path.read_text(encoding="utf-8")
    cfg = json.loads(raw)
    if cfg["hosting"].get("public") != "hosting":
        fail("firebase.json hosting.public 'hosting' olmalı")
    vals = firebase_csp_values(cfg)
    if not vals:
        fail("firebase.json'da /davetiye için CSP başlığı yok")
    if all(v == header_csp for v in vals):
        return False
    if not write:
        fail("firebase.json'daki davetiye CSP başlığı üretilen sayfanın betik özetleriyle aynı değil — "
             "python3 tools/build_hosting.py --write-firebase-json ... çalıştırıp firebase.json'u commit edin")
    for old in set(vals):
        raw = raw.replace('"value": ' + json.dumps(old, ensure_ascii=False), '"value": ' + json.dumps(header_csp, ensure_ascii=False))
    if firebase_csp_values(json.loads(raw)) != [header_csp] * len(vals):
        fail("firebase.json CSP güncellenemedi")
    path.write_text(raw, encoding="utf-8")
    print("firebase.json davetiye CSP başlığı güncellendi (commit edin)")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default=str(ROOT.parent / "ttuncaydemirr-beep.github.io"),
                    help="stüdyo sitesi deposu (müzik ve yazı tipi kaynağı)")
    ap.add_argument("--out", default=str(ROOT / "hosting"))
    ap.add_argument("--allow-missing", action="store_true", help="eksik müzik/yazı tipi dosyalarını atla (yalnız yerel deneme)")
    ap.add_argument("--write-firebase-json", action="store_true",
                    help="firebase.json'daki davetiye CSP başlığını betik özetleriyle güncelle")
    ap.add_argument("--check-csp", action="store_true",
                    help="yalnız davetiye sayfasını geçici klasörde üret ve firebase.json CSP'sini denetle (CI)")
    a = ap.parse_args()
    site, out = Path(a.site).resolve(), Path(a.out).resolve()
    if a.check_csp:
        import tempfile
        with tempfile.TemporaryDirectory() as t:
            header_csp = build_invite(Path(t))
        check_firebase_json(header_csp, a.write_firebase_json)
        print("CSP tamam: " + header_csp)
        return
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    header_csp = build_invite(out)
    check_firebase_json(header_csp, a.write_firebase_json)
    nm, tm = build_music(out, site, a.allow_missing)
    nf = build_fonts(out, site, a.allow_missing)
    (out / "assets" / "icons").mkdir(parents=True)
    shutil.copyfile(HSRC / "zarfla-192.png", out / "assets" / "icons" / "zarfla-192.png")
    for f in ("index.html", "404.html", "robots.txt"):
        shutil.copyfile(HSRC / f, out / f)
    print(f"hosting/ üretildi: davetiye, müzik {nm}/{tm}, yazı tipi+lisans {nf} dosya → {out}")


if __name__ == "__main__":
    main()
