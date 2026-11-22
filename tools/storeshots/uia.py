#!/usr/bin/env python3
"""uiautomator yardımcı: uia.py dump <dosya.xml> | tap <regex> [first|last|<n>] | texts
Flutter anlamsal düğümleri text ya da content-desc olarak görünür."""
import re, subprocess, sys, time
import xml.etree.ElementTree as ET


def adb(*a, check=False):
    try:
        return subprocess.run(["adb", *a], capture_output=True, text=True, check=check, timeout=45).stdout
    except subprocess.TimeoutExpired:
        return ""


def nodes():
    for _ in range(3):
        adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
        x = adb("exec-out", "cat", "/sdcard/ui.xml")
        try:
            root = ET.fromstring(x[x.index("<"):])
        except Exception:
            time.sleep(1)
            continue
        out = []
        for n in root.iter("node"):
            t = (n.get("text") or "").strip()
            c = (n.get("content-desc") or "").strip()
            m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds") or "")
            if not m or not (t or c):
                continue
            x1, y1, x2, y2 = map(int, m.groups())
            out.append((t or c, (x1 + x2) // 2, (y1 + y2) // 2, (x1, y1, x2, y2), n.get("clickable")))
        return x, out
    return "", []


def main():
    cmd = sys.argv[1]
    if cmd == "dump":
        x, ns = nodes()
        open(sys.argv[2], "w", encoding="utf-8").write(x)
        print("  UI düğümleri (%d):" % len(ns))
        for t, cx, cy, b, cl in ns[:24]:
            print("   ", repr(t[:60].replace("\n", " ")), b)
        return 0
    if cmd == "tap":
        pat, which = sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else "first")
        _, ns = nodes()
        hit = [n for n in ns if re.search(pat, n[0], re.I)]
        if not hit:
            print("  TAP BULUNAMADI:", pat, "| mevcut:", [n[0][:30] for n in ns[:25]])
            return 1
        n = hit[-1] if which == "last" else hit[int(which)] if which.isdigit() else hit[0]
        print("  TAP", repr(n[0][:50]), n[1], n[2])
        adb("shell", "input", "tap", str(n[1]), str(n[2]))
        return 0
    return 2

sys.exit(main())
