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


def colors():
    """design/colors.json (renklerin tek kaynağı) — açık tema paleti ve Emaye ok renkleri."""
    src = json.load(open(os.path.join(ROOT, 'design', 'colors.json'), encoding='utf-8'))
    pal = {k: v['light'] for k, v in src['palette'].items() if isinstance(v['light'], str)}
    emaye = next(t for t in src['arrowThemes'] if t['id'] == 'emaye')['colors']
    return pal, emaye


def board_svg():
    """Kum ve Mürekkep simge adayındaki tahta + iki ok (store/icon-candidates/icon-512.svg, zemin olmadan)."""
    import re
    svg = open(os.path.join(STORE, 'icon-candidates', 'icon-512.svg'), encoding='utf-8').read()
    inner = svg[svg.index('>', svg.index('<svg')) + 1: svg.rindex('</svg>')]
    inner = re.sub(r'<!--.*?-->', '', inner, flags=re.S)
    inner = re.sub(r'<defs>.*?</defs>', '', inner, flags=re.S)
    inner = re.sub(r'<rect width="512" height="512"[^>]*/>', '', inner)
    return f'<svg class="board" viewBox="112 112 340 300" xmlns="http://www.w3.org/2000/svg">{inner}</svg>'


def font_face():
    """Readex Pro (oyunla aynı, SIL OFL) — Latin + Arapça; data URI olarak gömülür (ağ yok)."""
    ttf = base64.b64encode(open(os.path.join(ROOT, 'game', 'assets', 'fonts', 'ReadexPro-VF.ttf'), 'rb').read()).decode()
    return f'@font-face{{font-family:"Readex Pro";src:url(data:font/ttf;base64,{ttf}) format("truetype");font-weight:160 700}}'


def feature_html(lang):
    """1.2.2: "Kum ve Mürekkep" özellik grafiği — kum zemin, kâğıt tahta, Emaye okları, Readex Pro (docs/02 v2)."""
    sub, chips, tag = FG[lang]
    rtl = lang == 'ar'
    pal, emaye = colors()
    # arka plan: oyundaki gibi dik açılı küçük oklar (soluk, Emaye paleti)
    deco = ''
    k = 0
    for gy in range(-1, 6):
        for gx in range(-1, 12):
            k += 1
            if (gx * 7 + gy * 3) % 5 in (1, 3):
                continue
            rot = [0, 90, 180, 270][(gx * 3 + gy * 5) % 4]
            deco += (f'<svg class="deco" style="left:{gx * 96 + (gy % 2) * 40}px;top:{gy * 96 + 10}px;transform:rotate({rot}deg)" '
                     f'viewBox="160 170 100 190" width="34" height="64"><path d="{UP}" fill="{emaye[k % 5]}"/></svg>')
    chips_html = ''.join(f'<span class="chip">{c}</span>' for c in chips)
    side = 'right' if rtl else 'left'
    other = 'left' if rtl else 'right'
    return f'''<!doctype html><html lang="{lang}" dir="{'rtl' if rtl else 'ltr'}"><head><meta charset="utf-8"><style>
{font_face()}
html,body{{margin:0;width:1024px;height:500px;overflow:hidden}}
body{{font-family:"Readex Pro",sans-serif;color:{pal['ink']};background:{pal['bg']};position:relative}}
.decos{{position:absolute;inset:0;overflow:hidden}}
.deco{{position:absolute;opacity:.16}}
.board{{position:absolute;top:50px;{side}:36px;width:420px;height:371px;filter:drop-shadow(0 18px 22px rgba(34,37,43,.22))}}
.txt{{position:absolute;top:0;bottom:0;{side}:486px;{other}:48px;display:flex;flex-direction:column;justify-content:center}}
h1{{margin:0;font-size:92px;line-height:1;font-weight:700;letter-spacing:-1px;direction:ltr;text-align:{'right' if rtl else 'left'}}}
h2{{margin:14px 0 0;font-size:{44 if rtl else 40}px;font-weight:700;color:{pal['accent']};line-height:1.2}}
p{{margin:12px 0 0;font-size:22px;color:{pal['inkSoft']};line-height:1.4;font-weight:500}}
.chips{{margin-top:24px;display:flex;gap:12px;flex-wrap:wrap}}
.chip{{background:{pal['board']};box-shadow:0 3px 0 {pal['boardEdge']};border-radius:999px;padding:8px 18px;font-size:19px;font-weight:700;white-space:nowrap}}
</style></head><body>
<div class="decos">{deco}</div>
{board_svg()}
<div class="txt"><h1>Arrowtile</h1><h2>{sub}</h2><p>{tag}</p><div class="chips">{chips_html}</div></div>
</body></html>'''


def make_features(p):
    b = p.chromium.launch()
    page = b.new_page(viewport={'width': 1024, 'height': 500}, device_scale_factor=1)
    for lang in LANGS:
        page.set_content(feature_html(lang))
        page.evaluate('document.fonts.ready')
        time.sleep(0.2)
        out = os.path.join(STORE, f'feature-graphic-{lang}.png')
        page.screenshot(path=out, clip={'x': 0, 'y': 0, 'width': 1024, 'height': 500}, omit_background=False)
        print('özellik grafiği', out)
    b.close()


def seed_state(lang):
    # 1.2.2: tarihler çekim gününe göre (sabit tarih ay değişince takvimi ve seriyi boş gösteriyordu)
    import datetime
    today = datetime.date.today()
    yday = today - datetime.timedelta(days=1)
    stars = {}
    for i in range(1, 110):
        stars[str(i)] = 3 if i % 7 else 2
    done = {}
    for back in range(1, 41):  # son 40 gün; iki gün boş, son 12 gün kesintisiz (seri 12)
        d = today - datetime.timedelta(days=back)
        if back in (15, 27):
            continue
        done[d.isoformat()] = 3 if back % 4 else 2
    return {
        'lang': lang, 'sound': True, 'vibration': True, 'coins': 1240, 'freeHints': 2,
        'stars': stars, 'unlocked': 110, 'themesOwned': ['emaye', 'lokum', 'cini'], 'theme': 'emaye',
        'daily': {'lastDate': yday.isoformat(), 'streakDay': 3},
        'tutorialDone': [1, 2, 3], 'chapterBonus': list(range(1, 10)),
        # adFree: mağaza görsellerinde web önizlemenin kesikli "Reklam alanı" yer tutucusu görünmesin
        'ads': {'since': 0, 'lastAt': 0, 'adFree': True, 'test': False},
        'appearance': 'light', 'relaxed': False, 'aim': False,
        'tips': ['curve_tip', 'aim_suggest', 'zoom_tip'],
        'dp': {'done': done, 'streak': 12, 'best': 12, 'last': yday.isoformat(), 'trophies': 28},
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

        def to_level(n):
            # 1.2.2: harita sanal listelenir (yalnızca görünen bölümler çizilir) → düğüm görünene dek aşağı/yukarı kaydır
            sel = f'#map-scroll .node[data-level="{n}"]'
            for step in range(400):
                if page.locator(sel).count():
                    break
                page.evaluate("""([n, step]) => { const sc = document.getElementById('map-scroll');
                  const nodes = [...sc.querySelectorAll('.node[data-level]')].map(e => +e.dataset.level);
                  const lo = nodes.length ? Math.min(...nodes) : Infinity;
                  sc.scrollTop += (n < lo ? 1 : -1) * sc.clientHeight * 0.8; sc.dispatchEvent(new Event('scroll')); }""", [n, step])
                time.sleep(0.05)
            page.locator(sel).scroll_into_view_if_needed()

        shot('01-menu.png')
        # 2) kolay seviye (bölüm 1)
        page.click('#btn-map'); page.wait_for_selector('#scr-map.active'); time.sleep(0.5)
        to_level(5)
        page.click('#map-scroll .node[data-level="5"]'); page.wait_for_selector('#scr-game.active'); time.sleep(0.8)
        shot('02-kolay-seviye.png')
        # 3) aşırı zor seviye (bölüm 9, seviye 100)
        page.click('#btn-pause'); page.wait_for_selector('#pause-map'); page.click('#pause-map'); page.wait_for_selector('#scr-map.active')
        time.sleep(0.4)
        to_level(100)
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
