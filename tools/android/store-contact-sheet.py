#!/usr/bin/env python3
"""store/ görsellerinin (4 dil x 6 ekran görüntüsü + 4 özellik grafiği) tek önizleme sayfası.
Kullanım: python3 tools/android/store-contact-sheet.py [çıktı.png]   (varsayılan /home/claude/arrowtile-reports/store-preview.png)"""
import os, sys
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/arrowtile-reports/store-preview.png'
LANGS = ['tr', 'en', 'de', 'ar']
SW, SH, GAP, PAD = 216, 384, 14, 24            # ekran görüntüsü küçültmesi (1080x1920 / 5)
names = ['01-menu', '02-kolay-seviye', '03-asiri-zor-seviye', '04-harita', '05-gunluk-bulmaca', '06-gunluk-tahta']
W = PAD * 2 + 6 * SW + 5 * GAP
FW, FH = (W - PAD * 2 - GAP) // 2, 0
FH = round((W - PAD * 2 - GAP) / 2 * 500 / 1024)
H = PAD + 2 * (FH + GAP) + 4 * (SH + GAP + 20) + PAD + 10
sheet = Image.new('RGB', (W, H), (236, 233, 227))
d = ImageDraw.Draw(sheet)
y = PAD
for i, l in enumerate(LANGS):
    im = Image.open(os.path.join(ROOT, 'store', f'feature-graphic-{l}.png')).convert('RGB').resize((FW, FH), Image.LANCZOS)
    sheet.paste(im, (PAD + (i % 2) * (FW + GAP), y + (i // 2) * (FH + GAP)))
y += 2 * (FH + GAP)
for l in LANGS:
    d.text((PAD, y), l.upper(), fill=(30, 30, 30))
    y += 16
    for k, n in enumerate(names):
        im = Image.open(os.path.join(ROOT, 'store', 'screenshots', l, n + '.png')).convert('RGB').resize((SW, SH), Image.LANCZOS)
        sheet.paste(im, (PAD + k * (SW + GAP), y))
    y += SH + GAP + 4
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.crop((0, 0, W, y + PAD - GAP)).save(OUT, optimize=True)
print(OUT, sheet.size)
