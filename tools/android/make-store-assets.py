#!/usr/bin/env python3
"""Arrowtile — Google Play mağaza görselleri.
Kullanım: python3 tools/android/make-store-assets.py [feature|shots]   (varsayılan: ikisi)
 - store/feature-graphic-<dil>.png : 1024x500 özellik grafiği (tr, en, de, ar; Arapça RTL)
 - store/screenshots/<dil>/0N-*.png: 1080x1920 telefon ekran görüntüleri (oyun 360x640 css px, deviceScaleFactor 3)
Ekran görüntüleri GERÇEK oyundan alınır: game/index.html ?debug OLMADAN açılır (hata ayıklama kancası yok);
ilerleme yalnızca tarayıcının localStorage'ına önceden yazılan örnek kayıtla hazırlanır.
"""
import base64, json, os, sys, time
from playwright.sync_api import sync_playwright

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
STORE = os.path.join(ROOT, 'store')
GAME = 'file://' + os.path.join(ROOT, 'game', 'index.html')
LANGS = ['tr', 'en', 'de', 'ar']
LOCALES = {'tr': 'tr-TR', 'en': 'en-US', 'de': 'de-DE', 'ar': 'ar-SA'}
SAVE_KEY = 'arrowtile.save.v1'

FG = {
    'tr': ('Ok Bulmacası', ['Süre sınırı yok', 'İnternetsiz oyna', 'Sonsuz bölüm'], 'Oka dokun, yolu aç, tahtayı boşalt!'),
    'en': ('Arrow Puzzle', ['No timers', 'Play offline', 'Endless chapters'], 'Tap an arrow, clear the path, empty the board!'),
    'de': ('Pfeil-Rätsel', ['Kein Zeitlimit', 'Ohne Internet', 'Endlose Kapitel'], 'Pfeil antippen, Weg frei machen, Brett leeren!'),
    'ar': ('لغز الأسهم', ['بلا وقت محدد', 'بلا إنترنت', 'فصول لا تنتهي'], 'المس السهم، افتح الطريق، وأفرغ اللوحة!'),
}

UP = 'M190 340 L190 236 L170 236 Q164 236 168 230 L201 186 Q206 180 211 186 L244 230 Q248 236 242 236 L222 236 L222 340 Q222 346 216 346 L196 346 Q190 346 190 340 Z'


def board_svg():
    """game/assets/icon.svg'deki tahta + iki ok (mavi arka plan olmadan)."""
    import re
    svg = open(os.path.join(ROOT, 'game', 'assets', 'icon.svg'), encoding='utf-8').read()
    inner = svg[svg.index('>', svg.index('<svg')) + 1: svg.rindex('</svg>')]
    inner = re.sub(r'<!--.*?-->', '', inner, flags=re.S)
    inner = re.sub(r'^\s*<rect width="512" height="512"[^>]*/>\s*<circle cx="256" cy="256" r="300"[^>]*/>', '', inner, flags=re.S)
    return f'<svg class="board" viewBox="120 120 300 280" xmlns="http://www.w3.org/2000/svg">{inner}</svg>'


def feature_html(lang, icon_b64):
    sub, chips, tag = FG[lang]
    rtl = lang == 'ar'
    font = '"DejaVu Sans", sans-serif' if rtl else 'Poppins, "DejaVu Sans", sans-serif'
    # arka plan: oyundaki gibi dik açılı küçük oklar (soluk)
    cols = ['#C9372F', '#F2B632', '#3FA36B', '#7E57C2', '#E0E8F0']
    deco = ''
    k = 0
    for gy in range(-1, 6):
        for gx in range(-1, 12):
            k += 1
            if (gx * 7 + gy * 3) % 5 in (1, 3):
                continue
            rot = [0, 90, 180, 270][(gx * 3 + gy * 5) % 4]
            deco += (f'<svg class="deco" style="left:{gx * 96 + (gy % 2) * 40}px;top:{gy * 96 + 10}px;transform:rotate({rot}deg)" '
                     f'viewBox="160 170 100 190" width="34" height="64"><path d="{UP}" fill="{cols[k % 5]}"/></svg>')
    chips_html = ''.join(f'<span class="chip">{c}</span>' for c in chips)
    side = 'right' if rtl else 'left'
    other = 'left' if rtl else 'right'
    return f'''<!doctype html><html lang="{lang}" dir="{'rtl' if rtl else 'ltr'}"><head><meta charset="utf-8"><style>
html,body{{margin:0;width:1024px;height:500px;overflow:hidden}}
body{{font-family:{font};color:#fff;background:linear-gradient({'250deg' if rtl else '110deg'},#1D4A90 0%,#2456A6 45%,#2E66BF 100%);position:relative}}
.decos{{position:absolute;inset:0;overflow:hidden}}
.deco{{position:absolute;opacity:.13}}
.glow{{position:absolute;top:50px;{side}:30px;width:420px;height:420px;border-radius:50%;background:radial-gradient(circle,rgba(255,255,255,.28) 0,rgba(255,255,255,0) 68%)}}
.board{{position:absolute;top:58px;{side}:44px;width:400px;height:373px;filter:drop-shadow(0 22px 30px rgba(6,20,50,.45))}}
.txt{{position:absolute;top:0;bottom:0;{side}:478px;{other}:48px;display:flex;flex-direction:column;justify-content:center}}
h1{{margin:0;font-size:92px;line-height:1;font-weight:700;letter-spacing:-1px;font-family:Poppins,sans-serif;direction:ltr;text-align:{'right' if rtl else 'left'}}}
h2{{margin:12px 0 0;font-size:{46 if rtl else 42}px;font-weight:{700 if rtl else 600};color:#FFD978;line-height:1.15}}
p{{margin:14px 0 0;font-size:{23 if rtl else 22}px;color:#E2EBF8;line-height:1.35}}
.chips{{margin-top:24px;display:flex;gap:10px;flex-wrap:wrap}}
.chip{{background:rgba(255,255,255,.16);border:2px solid rgba(255,255,255,.4);border-radius:999px;padding:7px 16px;font-size:{20 if rtl else 19}px;font-weight:600;white-space:nowrap}}
</style></head><body>
<div class="decos">{deco}</div>
<div class="glow"></div>
{board_svg()}
<div class="txt"><h1>Arrowtile</h1><h2>{sub}</h2><p>{tag}</p><div class="chips">{chips_html}</div></div>
</body></html>'''


def make_features(p):
    icon_b64 = base64.b64encode(open(os.path.join(STORE, 'play-icon-512.png'), 'rb').read()).decode()
    b = p.chromium.launch()
    page = b.new_page(viewport={'width': 1024, 'height': 500}, device_scale_factor=1)
    for lang in LANGS:
        page.set_content(feature_html(lang, icon_b64))
        page.evaluate('document.fonts.ready')
        time.sleep(0.2)
        out = os.path.join(STORE, f'feature-graphic-{lang}.png')
        page.screenshot(path=out, clip={'x': 0, 'y': 0, 'width': 1024, 'height': 500}, omit_background=False)
        print('özellik grafiği', out)
    b.close()


def seed_state(lang):
    stars = {}
    for i in range(1, 110):
        stars[str(i)] = 3 if i % 7 else 2
    done = {}
    for d in range(1, 31):
        if d not in (6, 18):
            done[f'2026-10-{d:02d}'] = 3 if d % 4 else 2
    return {
        'lang': lang, 'sound': True, 'vibration': True, 'coins': 1240, 'freeHints': 2,
        'stars': stars, 'unlocked': 110, 'themesOwned': ['emaye', 'lokum', 'cini'], 'theme': 'emaye',
        'daily': {'lastDate': '2026-10-31', 'streakDay': 3},
        'tutorialDone': [1, 2, 3], 'chapterBonus': list(range(1, 10)),
        'ads': {'since': 0, 'lastAt': 0, 'adFree': False, 'test': False},
        'appearance': 'light', 'relaxed': False, 'aim': False,
        'tips': ['curve_tip', 'aim_suggest', 'zoom_tip'],
        'dp': {'done': done, 'streak': 12, 'best': 12, 'last': '2026-10-30', 'trophies': 28},
    }


def make_shots(p):
    b = p.chromium.launch()
    for lang in LANGS:
        out = os.path.join(STORE, 'screenshots', lang)
        os.makedirs(out, exist_ok=True)
        ctx = b.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=3, is_mobile=True, has_touch=True,
                            locale=LOCALES[lang], color_scheme='light')
        state = json.dumps(seed_state(lang))
        ctx.add_init_script(f'try{{ if(!sessionStorage.getItem("seeded")){{ localStorage.setItem({json.dumps(SAVE_KEY)}, {json.dumps(state)}); localStorage.setItem("arrowtile.lang", {json.dumps(lang)}); sessionStorage.setItem("seeded","1"); }} }}catch(e){{}}')
        page = ctx.new_page()
        page.goto(GAME)
        page.wait_for_selector('#scr-menu.active')
        page.evaluate('document.fonts.ready'); time.sleep(0.6)
        assert page.evaluate('typeof window.__ok') == 'undefined', 'hata ayıklama kancası açık olmamalı'

        def shot(name):
            time.sleep(0.5)
            page.screenshot(path=os.path.join(out, name))
            print(lang, name)

        shot('01-menu.png')
        # 2) kolay seviye (bölüm 1)
        page.click('#btn-map'); page.wait_for_selector('#scr-map.active'); time.sleep(0.5)
        page.locator('#map-scroll .node[data-level="5"]').scroll_into_view_if_needed()
        page.click('#map-scroll .node[data-level="5"]'); page.wait_for_selector('#scr-game.active'); time.sleep(0.8)
        shot('02-kolay-seviye.png')
        # 3) aşırı zor seviye (bölüm 9, seviye 100)
        page.click('#btn-pause'); page.wait_for_selector('#pause-map'); page.click('#pause-map'); page.wait_for_selector('#scr-map.active')
        time.sleep(0.4)
        page.locator('#map-scroll .node[data-level="100"]').scroll_into_view_if_needed()
        page.click('#map-scroll .node[data-level="100"]'); page.wait_for_selector('#scr-game.active'); time.sleep(1.0)
        page.evaluate("var t=document.getElementById('toast'); if(t) t.classList.remove('show')")
        shot('03-asiri-zor-seviye.png')
        # 4) seviye haritası (sıradaki seviye ortada)
        page.click('#btn-pause'); page.wait_for_selector('#pause-map'); page.click('#pause-map'); page.wait_for_selector('#scr-map.active')
        time.sleep(0.8)
        # bölüm başlığı ve tamamlanmış (yıldızlı) düğümler de görünsün
        page.evaluate("document.getElementById('map-scroll').scrollTop += 300"); time.sleep(0.4)
        shot('04-harita.png')
        # 5) günlük bulmaca takvimi
        page.click('#scr-map [data-nav="menu"]'); page.wait_for_selector('#scr-menu.active'); time.sleep(0.3)
        page.click('#btn-dp'); page.wait_for_selector('#dp-sheet'); time.sleep(0.6)
        shot('05-gunluk-bulmaca.png')
        # 6) günlük bulmaca tahtası
        page.click('#dp-play'); page.wait_for_selector('#scr-game.active'); time.sleep(0.9)
        page.evaluate("var t=document.getElementById('toast'); if(t) t.classList.remove('show')")
        shot('06-gunluk-tahta.png')
        ctx.close()
    b.close()


if __name__ == '__main__':
    what = sys.argv[1:] or ['feature', 'shots']
    with sync_playwright() as p:
        if 'feature' in what: make_features(p)
        if 'shots' in what: make_shots(p)
