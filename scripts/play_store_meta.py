#!/usr/bin/env python3
"""Play Store meta: mağaza girişleri (listings), tek seferlik ürün çevirileri ve bölgesel fiyatlar.
SA JSON yalnızca PLAY_SERVICE_ACCOUNT_JSON ortam değişkeninden okunur, asla yazdırılmaz.
Kullanım: play_store_meta.py [--apply]"""
import json, os, sys, copy
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

PKG = "com.demirgamesstudio.zarfla"
BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + PKG
APPLY = "--apply" in sys.argv
DATA = json.load(open(os.path.join(os.path.dirname(__file__), "..", "play-meta", "data.json"), encoding="utf-8"))
LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}
PRODUCT_LIMITS = {"title": 55, "description": 200}
eur_regions_seen = {}
failures = []
perm_denied = []

cr = service_account.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
    scopes=["https://www.googleapis.com/auth/androidpublisher"])
S = AuthorizedSession(cr)


def call(method, path, **kw):
    r = S.request(method, BASE + path, timeout=60, **kw)
    if r.status_code >= 400:
        try:
            msg = r.json().get("error", {}).get("message", r.text[:300])
        except Exception:
            msg = r.text[:300]
        raise RuntimeError("%d|%s %s -> %s" % (r.status_code, method, path.split("?")[0], msg))
    return r.json() if r.content else {}


def money(v):
    units = int(v)
    nanos = int(round((v - units) * 1e9))
    return units, nanos


def fmt_money(m):
    return "%s %s.%09d" % (m.get("currencyCode"), m.get("units", "0"), int(m.get("nanos", 0)))


def handle(step, e):
    s = str(e)
    code = s.split("|")[0]
    print("::error::[%s] %s" % (step, s))
    failures.append(step)
    if code == "403":
        perm_denied.append(step)


# ---------------------------------------------------------------- 1. Listings
def step_listings():
    print("=== 1. MAGAZA GIRISLERI (edits.listings) ===")
    for loc, l in DATA["listings"].items():
        for f, mx in LIMITS.items():
            assert len(l[f]) <= mx, (loc, f, len(l[f]), mx)
    print("Yerel dosya dogrulama (title<=30, short<=80, full<=4000): OK")
    edit = call("POST", "/edits", json={})
    eid = edit["id"]
    committed = False
    try:
        cur = call("GET", "/edits/%s/listings" % eid).get("listings", [])
        print("Mevcut listing dilleri:", sorted(x["language"] for x in cur))
        curmap = {x["language"]: x for x in cur}
        for loc, l in DATA["listings"].items():
            body = {"language": loc, "title": l["title"], "shortDescription": l["shortDescription"],
                    "fullDescription": l["fullDescription"]}
            state = "VAR (guncellenecek)" if loc in curmap else "YENI"
            same = loc in curmap and all(curmap[loc].get(k) == body[k] for k in LIMITS)
            print("  %s: %s%s title=%r short=%d full=%d" % (loc, state, " [ZATEN AYNI]" if same else "", l["title"], len(l["shortDescription"]), len(l["fullDescription"])))
            call("PUT", "/edits/%s/listings/%s" % (eid, loc), json=body)
        try:
            v = call("POST", "/edits/%s:validate" % eid)
            print("edits.validate: OK", v.get("id"))
        except Exception as e:
            print("UYARI validate basarisiz:", str(e)[:200])
            raise
        if APPLY:
            c = call("POST", "/edits/%s:commit" % eid)
            committed = True
            print("edits.commit: OK, edit", c.get("id"))
    finally:
        if not committed:
            try:
                call("DELETE", "/edits/%s" % eid)
                print("Edit silindi (commit yok).")
            except Exception as e:
                print("Edit silinemedi:", str(e)[:200])
    # okuma-dogrulama (yeni edit, sonra sil)
    e2 = call("POST", "/edits", json={})["id"]
    try:
        now = {x["language"]: x for x in call("GET", "/edits/%s/listings" % e2).get("listings", [])}
        print("Son durum listing dilleri:", sorted(now))
        for loc, l in DATA["listings"].items():
            ok = loc in now and all(now[loc].get(k) == l[k] for k in LIMITS)
            print("VERIFY listing %s: %s" % (loc, "CANLI/ESLESIYOR" if ok else "ESLESMIYOR (henuz uygulanmadi)"))
    finally:
        call("DELETE", "/edits/%s" % e2)


# ---------------------------------------------------------------- 2. Products
def regions_version():
    r = call("POST", "/pricing:convertRegionPrices", json={"price": {"currencyCode": "EUR", "units": "9", "nanos": 990000000}})
    return r["regionVersion"]["version"], r


def build_product(cur, pid):
    new = copy.deepcopy(cur)
    # listings
    lst = {x["languageCode"]: x for x in new.get("listings", [])}
    for loc, t in DATA["products"][pid].items():
        assert len(t["title"]) <= PRODUCT_LIMITS["title"] and len(t["description"]) <= PRODUCT_LIMITS["description"]
        lst[loc] = {"languageCode": loc, "title": t["title"], "description": t["description"]}
    new["listings"] = list(lst.values())
    # prices
    pos = [p for p in new.get("purchaseOptions", []) if p.get("purchaseOptionId") == "buy"]
    if len(pos) != 1:
        raise RuntimeError("purchaseOption 'buy' bulunamadi: %s" % [p.get("purchaseOptionId") for p in new.get("purchaseOptions", [])])
    po = pos[0]
    cfgs = {c["regionCode"]: c for c in po.get("regionalPricingAndAvailabilityConfigs", [])}
    for region, pr in DATA["prices"].items():
        u, n = money(pr[pid])
        c = cfgs.get(region, {"regionCode": region, "availability": "AVAILABLE"})
        c["price"] = {"currencyCode": pr["currency"], "units": str(u), "nanos": n}
        c.setdefault("availability", "AVAILABLE")
        cfgs[region] = c
    # eurozone: every region whose CURRENT currency is EUR (derived from GET)
    eur_regions = sorted(r for r, c in cfgs.items() if c.get("price", {}).get("currencyCode") == "EUR")
    u, n = money(DATA["eur"][pid])
    for r in eur_regions:
        cfgs[r]["price"] = {"currencyCode": "EUR", "units": str(u), "nanos": n}
    po["regionalPricingAndAvailabilityConfigs"] = list(cfgs.values())
    # before -> after table
    old = {c["regionCode"]: c.get("price") for po0 in cur.get("purchaseOptions", []) if po0.get("purchaseOptionId") == "buy" for c in po0.get("regionalPricingAndAvailabilityConfigs", [])}
    print("ONCE -> SONRA fiyat tablosu (%s), EUR bolgeleri: %s" % (pid, eur_regions))
    changed = 0
    for r in sorted(cfgs):
        a, b = old.get(r), cfgs[r].get("price")
        if a != b:
            changed += 1
            print("  %-3s %-24s -> %s" % (r, fmt_money(a) if a else "-", fmt_money(b) if b else "-"))
    print("  degisen bolge: %d, degismeyen: %d" % (changed, len(cfgs) - changed))
    return new, po


def summarize(p, pid):
    print("  listings:", [(x["languageCode"], x["title"]) for x in p.get("listings", [])])
    for po in p.get("purchaseOptions", []):
        rc = {c["regionCode"]: c for c in po.get("regionalPricingAndAvailabilityConfigs", [])}
        print("  option", po.get("purchaseOptionId"), "bolge sayisi:", len(rc),
              {r: (fmt_money(rc[r]["price"]) if "price" in rc[r] else rc[r].get("availability")) for r in ("ID", "BR", "MX", "ES", "TR", "US") if r in rc})


def step_products():
    print("=== 2. TEK SEFERLIK URUNLER (monetization.onetimeproducts) ===")
    try:
        ver, conv = regions_version()
        print("regionsVersion:", ver)
    except Exception as e:
        if APPLY:
            raise
        ver = None
        print("UYARI regionsVersion alinamadi (dry-run devam):", str(e)[:200])
    for pid in ("zarfla_invite_1", "zarfla_invite_3"):
        print("--- %s ---" % pid)
        try:
            cur = call("GET", "/oneTimeProducts/%s" % pid)
        except Exception as e:
            print("UYARI GET basarisiz:", str(e)[:200])
            handle("products-get-" + pid, e)
            continue
        print("GET (mevcut):")
        print(json.dumps(cur, ensure_ascii=False, indent=1)[:6000])
        new, po = build_product(cur, pid)
        eur_regions_seen[pid] = sorted(c["regionCode"] for c in po["regionalPricingAndAvailabilityConfigs"] if c.get("price", {}).get("currencyCode") == "EUR")
        print("Planlanan durum:")
        summarize(new, pid)
        if not APPLY:
            print("apply=false: PATCH atlandi.")
        else:
            q = "?updateMask=listings,purchaseOptions&regionsVersion.version=%s&latencyTolerance=PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_SENSITIVE" % ver
            out = call("PATCH", "/oneTimeProducts/%s%s" % (pid, q), json=new)
            print("PATCH: OK")
        chk = call("GET", "/oneTimeProducts/%s" % pid)
        got = {x["languageCode"]: x for x in chk.get("listings", [])}
        ok_l = all(loc in got and got[loc]["title"] == t["title"] and got[loc]["description"] == t["description"] for loc, t in DATA["products"][pid].items())
        rc = {}
        for po2 in chk.get("purchaseOptions", []):
            if po2.get("purchaseOptionId") == "buy":
                rc = {c["regionCode"]: c for c in po2.get("regionalPricingAndAvailabilityConfigs", [])}
        ok_p = True
        for region, pr in list(DATA["prices"].items()) + [(r, DATA["eur"]) for r in eur_regions_seen.get(pid, [])]:
            u, n = money(pr[pid])
            m = rc.get(region, {}).get("price", {})
            good = m.get("currencyCode") == pr["currency"] and int(m.get("units", 0)) == u and int(m.get("nanos", 0)) == n
            print("VERIFY %s %s %s: %s" % (pid, region, fmt_money(m) if m else "-", "CANLI/ESLESIYOR" if good else "ESLESMIYOR"))
            ok_p &= good
        print("VERIFY %s listings es-419/pt-BR/id: %s" % (pid, "CANLI/ESLESIYOR" if ok_l else "ESLESMIYOR"))
        es = rc.get("ES", {}).get("price")
        print("Kontrol ES fiyati (degismemeli):", fmt_money(es) if es else "-")


for name, fn in (("listings", step_listings), ("products", step_products)):
    try:
        fn()
    except Exception as e:
        handle(name, e)

if perm_denied:
    print("::error::IZIN HATASI (403): %s. Hizmet hesabina Play Console'da yetki verilmeli." % perm_denied)
if failures:
    sys.exit(3 if perm_denied else 1)
print("TAMAM (apply=%s)" % APPLY)
