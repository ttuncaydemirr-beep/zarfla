#!/usr/bin/env python3
"""Mağaza görselleri için örnek davetiyeler: FlutterSharedPreferences.xml üretir (yalnız emülatör, depoya veri girmez).
Kullanım: seed.py <dil> <çıktı.xml> [repo_kökü]"""
import json, re, sys, time, datetime
from xml.sax.saxutils import escape

lang, out = sys.argv[1], sys.argv[2]
root = sys.argv[3] if len(sys.argv) > 3 else "."
arb = json.load(open(f"{root}/assets/l10n/app_{lang}.arb", encoding="utf-8"))
s = open(f"{root}/lib/data/catalog.dart", encoding="utf-8").read()
i = s.index("kMessages = {") + len("kMessages = ")
msgs = json.loads(re.sub(r",(\s*[}\]])", r"\1", s[i:s.index("\n};", i) + 2]))

NAMES = {  # (hero çift, ikinci çift, üçüncü çift)
    "tr": (("Elif", "Kerem"), ("Zeynep", "Can"), ("Selin", "Mert")),
    "en": (("Emma", "James"), ("Olivia", "Noah"), ("Grace", "Lucas")),
    "de": (("Lena", "Jonas"), ("Marie", "Felix"), ("Clara", "Paul")),
    "ar": (("ليلى", "عمر"), ("مريم", "يوسف"), ("سلمى", "خالد")),
    "es": (("Sofía", "Mateo"), ("Valentina", "Diego"), ("Lucía", "Andrés")),
    "pt": (("Beatriz", "Rafael"), ("Helena", "Lucas"), ("Laura", "Pedro")),
    "id": (("Putri", "Raka"), ("Sekar", "Arya"), ("Dewi", "Bayu")),
}
VENUE = {
    "tr": ("Zümrüt Bahçe Köşkü", "Boğaz yolu, Sarıyer / İstanbul", "905321234567"),
    "en": ("The Rosewood Garden", "12 Orchard Lane, Hudson Valley, New York", "442079460123"),
    "de": ("Gartenpavillon am See", "Seestraße 12, 22559 Hamburg", "4915123456789"),
    "ar": ("قاعة الياسمين", "شارع الورد، الرياض", "966501234567"),
    "es": ("Hacienda Los Jazmines", "Calle del Huerto 12, Ciudad de México", "525512345678"),
    "pt": ("Villa dos Jardins", "Rua das Flores 120, São Paulo", "5511912345678"),
    "id": ("Taman Anggrek", "Jl. Melati No. 12, Ubud, Bali", "6281234567890"),
}
d = datetime.date.today() + datetime.timedelta(days=74)
now = int(time.time() * 1000)


def inv(id_, typ, theme, names, created, live, hero=False):
    v = VENUE[lang]
    steps = [
        {"t": "18:30", "x": arb["progExWelcome"]},
        {"t": "19:30", "x": arb["progExDinner"]},
        {"t": "21:30", "x": arb["progExCake"]},
    ] if hero else []
    return {
        "id": id_, "type": typ, "theme": theme, "lang": lang,
        "layout": "kemer" if hero else "klasik",
        "opening": "zarfacil" if hero else "door",
        "n1": names[0], "n2": names[1], "host": "",
        "msg": msgs[lang][typ][0],
        "date": (d if hero else d + datetime.timedelta(days=20)).isoformat(),
        "time": "18:30", "end": "23:30", "venue": v[0], "address": v[1], "wa": v[2],
        "program": steps, "notes": [], "liveUrl": "", "liveNote": "",
        "giftHolder": "", "giftIban": "", "giftBank": "",
        "music": "dugun-handel" if hero else "", "cover": "", "photos": [],
        "status": "live" if live else "draft", "plan": "premium" if live else None,
        "nameEditsLeft": 3, "dateEditsLeft": 2,
        "originalDate": (d + datetime.timedelta(days=20)).isoformat() if live else None,
        "created": created,
        "cloudId": ("demo_" + id_) if live else None,
        "expiresAt": (now + 200 * 86400000) if live else None,
        "cloudFiles": {},
    }

n = NAMES[lang]
invs = [
    inv("c3", "dugun", "okaliptus", n[2], now - 5000, True),
    inv("b2", "nisan", "gul", n[1], now - 3000, True),
    inv("a1", "dugun", "altin", n[0], now, False, hero=True),
]
prefs = {
    "flutter.zarfla_invs_v1": ("string", json.dumps(invs, ensure_ascii=False)),
    "flutter.zarfla_lang": ("string", lang),
    "flutter.zarfla_sample_names_cleared_v1": ("boolean", "true"),
}
lines = ["<?xml version='1.0' encoding='utf-8' standalone='yes' ?>", "<map>"]
for k, (t, v) in prefs.items():
    if t == "boolean":
        lines.append(f'    <boolean name="{k}" value="{v}" />')
    else:
        lines.append(f'    <string name="{k}">{escape(v)}</string>')
lines.append("</map>")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
json.dump({"n1": n[0][0], "n2": n[0][1], "labels": {k: arb[k] for k in ("newInv", "type_dugun", "details", "preview", "publish", "edit", "useThisDesign", "myInv")}},
          open(out + ".meta.json", "w", encoding="utf-8"), ensure_ascii=False)
