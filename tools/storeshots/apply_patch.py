#!/usr/bin/env python3
"""Yalnız `storeshots` derlemesi için (main'e GİRMEZ): Play Faturalandırma'nın bulunmadığı emülatörde ödeme ekranı
gerçekçi görünsün diye fiyatları dil bazında --dart-define-from-file ile verir. Kaynak dosyayı yerinde değiştirir."""
import re, sys
p = sys.argv[1] if len(sys.argv) > 1 else "lib/state/app_state.dart"
s = open(p, encoding="utf-8").read()
if "ZARFLA_SHOT_PRICES" in s:
    sys.exit(0)
hook = '''
const String _kShotPrices = String.fromEnvironment('ZARFLA_SHOT_PRICES');

/// (yalnız mağaza görseli derlemesi) dil|tekFiyat|paketFiyat|tekHam|paketHam|paraBirimi
List<String>? _shotRow(String lang) {
  if (_kShotPrices.isEmpty) return null;
  for (final r in _kShotPrices.split(';')) {
    final c = r.split('|');
    if (c.length == 6 && c[0] == lang) return c;
  }
  return null;
}
'''
# import satırlarından sonra ekle
idx = [m.end() for m in re.finditer(r"^import .*;\n", s, re.M)][-1]
s = s[:idx] + hook + s[idx:]
s = s.replace("String? get playPrice => billing?.price;",
              "String? get playPrice => _shotRow(lang)?[1] ?? billing?.price;")
s = s.replace("String? get bundlePrice => billing?.bundlePrice;",
              "String? get bundlePrice => _shotRow(lang)?[2] ?? billing?.bundlePrice;")
s = s.replace("  int? get bundleSavePct {\n    final b = billing;",
              "  int? get bundleSavePct {\n    final sr = _shotRow(lang);\n"
              "    if (sr != null) {\n      return bundleSavingsPercent(single: double.parse(sr[3]), bundle: double.parse(sr[4]),\n"
              "          singleCurrency: sr[5], bundleCurrency: sr[5], rights: rightsFor(kBundleProductId));\n    }\n    final b = billing;")
s = s.replace("bool get billingReady => billing?.available ?? false;",
              "bool get billingReady => _kShotPrices.isNotEmpty || (billing?.available ?? false);")
assert s.count("_shotRow(") >= 4, "yama uygulanamadı"
open(p, "w", encoding="utf-8").write(s)
print("storeshot yaması uygulandı")
