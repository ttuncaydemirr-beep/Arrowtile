#!/usr/bin/env python3
"""Arrowtile — game/assets/icon.svg'den Android ikonları üretir (Playwright/Chromium + Pillow).
Kullanım: python3 tools/android/make-icons.py
Çıktı: flutter/arrowtile/android/app/src/main/res/mipmap-*/ (adaptive foreground/background/monochrome + eski tip ikonlar)
       store/play-icon-512.png (Play Store ikonu: 512x512, 32-bit PNG)
"""
import io, os, re, sys
from playwright.sync_api import sync_playwright
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SVG = open(os.path.join(ROOT, 'game', 'assets', 'icon.svg'), encoding='utf-8').read()
RES = os.path.join(ROOT, 'flutter', 'arrowtile', 'android', 'app', 'src', 'main', 'res')  # 02.11.2026: Flutter projesi (eski: legacy/android-native)
STORE = os.path.join(ROOT, 'store')

inner = SVG[SVG.index('>', SVG.index('<svg')) + 1: SVG.rindex('</svg>')]
inner = re.sub(r'<!--.*?-->', '', inner, flags=re.S)
# Arka plan katmanı = ilk iki öğe (dolu kare + açık daire); geri kalanı ön plan.
m = re.match(r'\s*(<rect width="512" height="512"[^>]*/>)\s*(<circle cx="256" cy="256" r="300"[^>]*/>)(.*)$', inner, flags=re.S)
if not m: sys.exit('icon.svg beklenen yapıda değil')
BG = m.group(1) + m.group(2)
FG = m.group(3)
# Adaptive ikon: 108dp tuval, güvenli bölge 66dp çaplı daire. SVG'deki önemli öğeler r=169 dairede;
# 512 → 108dp eşlemesinde güvenli yarıçap 0.611*256 ≈ 156 → ön planı 0.90 ölçekle küçült.
K = 0.90
def svg(body, scale=1.0):
    t = 256 * (1 - scale)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">'
            f'<g transform="translate({t:.2f},{t:.2f}) scale({scale})">{body}</g></svg>')
# Tek renkli (Android 13+ temalı ikon): tahta çerçevesi + iki ok, yalnızca alfa kullanılır
_UP = 'M190 340 L190 236 L170 236 Q164 236 168 230 L201 186 Q206 180 211 186 L244 230 Q248 236 242 236 L222 236 L222 340 Q222 346 216 346 L196 346 Q190 346 190 340 Z'
_RIGHT = 'M312 290 L362 290 L362 266 Q362 259 368 263 L414 302 Q419 308 414 314 L368 353 Q362 357 362 350 L362 326 L312 326 Q306 326 306 320 L306 296 Q306 290 312 290 Z'
MONO = ('<defs><mask id="gap"><rect width="512" height="512" fill="#fff"/>'
        f'<path transform="translate(-14,0)" d="{_RIGHT}" fill="#000" stroke="#000" stroke-width="28" stroke-linejoin="round"/></mask></defs>'
        '<rect x="148" y="148" width="216" height="216" rx="40" fill="none" stroke="#000" stroke-width="16" mask="url(#gap)"/>'
        f'<path fill="#000" d="{_UP}"/>'
        f'<path transform="translate(-14,0)" fill="#000" d="{_RIGHT}"/>')

DENS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

def render(page, markup, px):
    html = ('<!doctype html><html><head><style>html,body{margin:0;background:transparent}'
            f'svg{{display:block;width:{px}px;height:{px}px}}</style></head><body>{markup}</body></html>')
    page.set_viewport_size({'width': px, 'height': px})
    page.set_content(html)
    return Image.open(io.BytesIO(page.screenshot(omit_background=True, clip={'x': 0, 'y': 0, 'width': px, 'height': px}))).convert('RGBA')

def mask(img, kind):
    w = img.size[0]; big = w * 4
    mk = Image.new('L', (big, big), 0); d = ImageDraw.Draw(mk)
    if kind == 'circle': d.ellipse((0, 0, big - 1, big - 1), fill=255)
    else: d.rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * 0.18), fill=255)
    mk = mk.resize((w, w), Image.LANCZOS)
    out = img.copy(); out.putalpha(Image.composite(img.getchannel('A'), Image.new('L', img.size, 0), mk))
    return out

with sync_playwright() as p:
    b = p.chromium.launch()
    page = b.new_page()
    for d, f in DENS.items():
        out = os.path.join(RES, 'mipmap-' + d); os.makedirs(out, exist_ok=True)
        a = int(round(108 * f))
        render(page, svg(FG, K), a).save(os.path.join(out, 'ic_launcher_foreground.png'), optimize=True)
        render(page, svg(BG), a).save(os.path.join(out, 'ic_launcher_background.png'), optimize=True)
        mono = render(page, svg(MONO, K), a)
        white = Image.new('RGBA', mono.size, (255, 255, 255, 0)); white.putalpha(mono.getchannel('A'))
        white.save(os.path.join(out, 'ic_launcher_monochrome.png'), optimize=True)
        # Android 7.x (API 24-25) için eski tip ikonlar: 48dp
        l = int(round(48 * f))
        full = render(page, svg(BG + f'<g transform="translate({256*(1-1.18):.2f},{256*(1-1.18):.2f}) scale(1.18)">{FG}</g>'), l)
        mask(full, 'square').save(os.path.join(out, 'ic_launcher.png'), optimize=True)
        mask(full, 'circle').save(os.path.join(out, 'ic_launcher_round.png'), optimize=True)
    # Play Store ikonu: 512x512, 32-bit PNG (RGBA), tam kare (Play köşe yuvarlamayı kendisi uygular)
    os.makedirs(STORE, exist_ok=True)
    icon = render(page, SVG.replace('width="512" height="512"', 'width="512" height="512"', 1), 512)
    icon.save(os.path.join(STORE, 'play-icon-512.png'), optimize=True)
    b.close()
print('ikonlar hazır')
