#!/usr/bin/env python3
"""Emulator duman testi yardımcısı (uiautomator dump + screencap çözümleme).

  ui.py find  <dump.xml> <regex>   -> eşleşen ilk düğmenin merkezi "x y" (yoksa çıkış kodu 1)
  ui.py has   <dump.xml> <regex>   -> eşleşme varsa 0, yoksa 1
  ui.py texts <dump.xml>           -> tüm etiketleri yazdırır (teşhis)
  ui.py colors <screen.raw>        -> orta bölgedeki ayrık renk sayısı (tahta çiziliyor mu)

Flutter anlamsal düğümleri etiketi `text` ya da `content-desc` içinde verir; birleşik etiketler satır sonuyla ayrılabilir,
bu yüzden regex satır başı/sonu (MULTILINE) ile aranır.
"""
import re
import struct
import sys
import xml.etree.ElementTree as ET


def labels(path):
    root = ET.parse(path).getroot()
    for n in root.iter("node"):
        for key in ("text", "content-desc"):
            v = (n.get(key) or "").strip()
            if v:
                yield v, n.get("bounds", "")


def center(bounds):
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    if x2 <= x1 or y2 <= y1:
        return None
    return (x1 + x2) // 2, (y1 + y2) // 2


def find(path, rx):
    r = re.compile(rx, re.M)
    for v, b in labels(path):
        if r.search(v):
            c = center(b)
            if c:
                return c
    return None


def colors(path):
    data = open(path, "rb").read()
    w, h, _fmt = struct.unpack("<III", data[:12])
    px = data[len(data) - w * h * 4:]
    seen = set()
    for y in range(int(h * 0.22), int(h * 0.78), 6):
        row = y * w * 4
        for x in range(int(w * 0.05), int(w * 0.95), 6):
            i = row + x * 4
            seen.add((px[i] >> 4, px[i + 1] >> 4, px[i + 2] >> 4))
    return len(seen)


def main():
    cmd = sys.argv[1]
    if cmd in ("find", "has"):
        c = find(sys.argv[2], sys.argv[3])
        if c is None:
            sys.exit(1)
        if cmd == "find":
            print(c[0], c[1])
    elif cmd == "texts":
        for v, b in labels(sys.argv[2]):
            print(repr(v), b)
    elif cmd == "colors":
        print(colors(sys.argv[2]))
    else:
        sys.exit(2)


if __name__ == "__main__":
    main()
