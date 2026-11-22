#!/usr/bin/env python3
"""Arrowtile — Google Play mağaza görselleri (1.2.3).
Kullanım: python3 tools/android/make-store-assets.py [feature|shots]   (varsayılan: ikisi)
 - store/feature-graphic-<dil>.png : 1024x500 özellik grafiği (tr, en, de, ar; Arapça RTL).
   Güncel başlatıcı simgesi (game/assets/icon.svg = store/play-icon-512.png), güncel palet (design/colors.json),
   oyunun kendi ok çizicisi (window.drawArrow) ve oyun yazı tipi Readex Pro (flutter/arrowtile/assets/fonts).
   NOT: store/icon-candidates/ (simge adayı) KULLANILMAZ.
 - store/screenshots/<dil>/0N-*.png: 1080x1920 telefon ekran görüntüleri (oyun 360x640 css px, deviceScaleFactor 3)
Ekran görüntüleri GERÇEK web önizlemeden alınır: game/index.html ?debug OLMADAN açılır (hata ayıklama kancası yok).
İlerleme yalnızca localStorage'a önceden yazılan örnek kayıtla hazırlanır; reklam yer tutucusu "adFree" kaydıyla gizlenir
(oyun kodu değişmez). Tahtalar yarım çözülmüş görünür: hangi okların alınacağı ?debug=1 AYRI bir bağlamda planlanır,
sonra kancasız sayfada gerçek dokunuşlarla (fare tıklaması) uygulanır.
"""
import base64, json, os, random, sys, time
from playwright.sync_api import sync_playwright

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
STORE = os.path.join(ROOT, 'store')
GAME = 'file://' + os.path.join(ROOT, 'game', 'index.html')
FONTS = os.path.join(ROOT, 'flutter', 'arrowtile', 'assets', 'fonts')
LANGS = (os.environ.get('LANGS') or 'tr,en,de,ar').split(',')   # LANGS=ar ile tek dil yeniden üretilebilir
LOCALES = {'tr': 'tr-TR', 'en': 'en-US', 'de': 'de-DE', 'ar': 'ar-SA'}
SAVE_KEY = 'arrowtile.save.v1'
FEATURE_LEVEL = 20  # 9x13, uzun kıvrımlı 8 ok (Aşırı zor, bölüm 1)

TAGLINE = {
    'tr': 'Okları kaydır, tahtayı temizle',
    'en': 'Slide the arrows, clear the board',
    'de': 'Pfeile schieben, Brett leeren',
    'ar': 'حرّك الأسهم وأخلِ اللوحة',
}


def colors():
    """design/colors.json (renklerin tek kaynağı) — açık tema paleti ve Emaye ok renkleri."""
    src = json.load(open(os.path.join(ROOT, 'design', 'colors.json'), encoding='utf-8'))
    pal = {k: v['light'] for k, v in src['palette'].items() if isinstance(v['light'], str)}
    emaye = next(t for t in src['arrowThemes'] if t['id'] == 'emaye')
    return pal, emaye['colors'], emaye['chevron']


def b64(path):
    return base64.b64encode(open(path, 'rb').read()).decode()


def font_face():
    """Readex Pro (oyunla aynı, SIL OFL; Latin + Arapça) — Flutter varlıklarındaki statik TTF'ler data URI olarak gömülür."""
    out = ''
    for w, f in ((500, 'Medium'), (600, 'SemiBold'), (700, 'Bold')):
        out += (f'@font-face{{font-family:"Readex Pro";font-weight:{w};'
                f'src:url(data:font/ttf;base64,{b64(os.path.join(FONTS, f"ReadexPro-{f}.ttf"))}) format("truetype")}}')
    return out


def board_png(p):
    """Gerçek oyunun ok çizicisiyle (window.drawArrow) güncel paletle tahta çizer; PNG data URI döndürür."""
    pal, emaye, chev = colors()
    b = p.chromium.launch()
    pg = b.new_page(viewport={'width': 360, 'height': 640})
    url = GAME + '?debug=1'
    pg.goto(url); pg.evaluate('localStorage.clear()'); pg.goto(url)
    pg.wait_for_function("window.__ok && window.__ok.screen()=='menu'")
    pg.evaluate('window.__ok.debugPatch({unlocked:200})')
    pg.evaluate(f'window.__ok.startLevel({FEATURE_LEVEL})')
    time.sleep(0.5)
    lv = pg.evaluate('window.__ok.level()')
    data = pg.evaluate("""([lv, pal, emaye, chev]) => {
      const C = 56, PAD = 30, W = lv.w * C, H = lv.h * C, S = 2;   // 2x: küçültülünce yumuşak kenar
      const cv = document.createElement('canvas'); cv.width = (W + PAD * 2) * S; cv.height = (H + PAD * 2 + 14) * S;
      const x = cv.getContext('2d'); x.scale(S, S);
      const rr = (px, py, w, h, r) => { x.beginPath(); x.roundRect(px, py, w, h, r); };
      x.fillStyle = pal.boardEdge; rr(0, 14, W + PAD * 2, H + PAD * 2, 40); x.fill();      // alt kalınlık
      x.fillStyle = pal.board;     rr(0, 0, W + PAD * 2, H + PAD * 2, 40); x.fill();       // tahta yüzü
      x.fillStyle = pal.cellDot;
      for (let j = 0; j <= lv.h; j++) for (let i = 0; i <= lv.w; i++) { x.beginPath(); x.arc(PAD + i * C - (i === lv.w ? 0 : 0), PAD + j * C, 2.2, 0, 7); x.fill(); }
      lv.arrows.forEach((a, k) => {
        const cells = window.OkEngine.cellsOf(a);
        window.drawArrow(x, { ox: PAD, oy: PAD, cells, cell: C, dir: a.dir, color: emaye[k % emaye.length], chevron: chev });
      });
      return cv.toDataURL('image/png');
    }""", [lv, pal, emaye, chev])
    b.close()
    return data, (lv['w'] * 56 + 60, lv['h'] * 56 + 60 + 14)


def feature_html(lang, board, bsize):
    """1.2.3: güncel simge + güncel palet + oyunun gerçek ok çizimi. Metin güvenli alanda (kenarlardan ~%10)."""
    pal, emaye, _ = colors()
    rtl = lang == 'ar'
    icon = b64(os.path.join(ROOT, 'game', 'assets', 'icon.svg'))
    # arka plan: soluk küçük oklar (Emaye paleti), tahtanın ve metnin arkasında
    UP = 'M190 340 L190 236 L170 236 Q164 236 168 230 L201 186 Q206 180 211 186 L244 230 Q248 236 242 236 L222 236 L222 340 Q222 346 216 346 L196 346 Q190 346 190 340 Z'
    deco = ''
    k = 0
    for gy in range(-1, 6):
        for gx in range(-1, 12):
            k += 1
            if (gx * 7 + gy * 3) % 5 in (1, 3):
                continue
            rot = [0, 90, 180, 270][(gx * 3 + gy * 5) % 4]
            deco += (f'<svg class="deco" style="left:{gx * 96 + (gy % 2) * 40}px;top:{gy * 96 + 10}px;transform:rotate({rot}deg)" '
                     f'viewBox="160 170 100 190" width="30" height="57"><path d="{UP}" fill="{emaye[k % 5]}"/></svg>')
    bh = 372                      # tahta yüksekliği (y: 64..436)
    bw = round(bh * bsize[0] / bsize[1])
    side, other = ('right', 'left') if rtl else ('left', 'right')
    # güvenli alan: x 104..920. Tahta kenar tarafında 112 px içeride; metin ters tarafta.
    board_x = 112
    txt_a = board_x + bw + 56      # metin bloğunun tahtaya yakın kenarı
    txt_b = 104                    # metnin dış kenarı
    return f'''<!doctype html><html lang="{lang}" dir="{'rtl' if rtl else 'ltr'}"><head><meta charset="utf-8"><style>
{font_face()}
html,body{{margin:0;width:1024px;height:500px;overflow:hidden}}
body{{font-family:"Readex Pro",sans-serif;color:{pal['ink']};background:{pal['bg']};position:relative}}
.decos{{position:absolute;inset:0;overflow:hidden}}
.deco{{position:absolute;opacity:.13}}
.board{{position:absolute;top:56px;{other}:{board_x}px;width:{bw}px;height:{bh}px;filter:drop-shadow(0 16px 20px rgba(34,37,43,.20))}}
.txt{{position:absolute;top:0;bottom:0;{other}:{txt_a}px;{side}:{txt_b}px;display:flex;flex-direction:column;justify-content:center;align-items:flex-start}}
.brand{{display:flex;align-items:center;gap:22px;direction:ltr}}
.icon{{width:116px;height:116px;border-radius:27px;box-shadow:0 10px 0 #173D7A33,0 18px 26px rgba(23,61,122,.28);flex:none}}
h1{{margin:0;font-size:70px;line-height:1.05;font-weight:700;letter-spacing:-1.5px;direction:ltr}}
h2{{margin:28px 0 0;font-size:{40 if rtl else 36}px;font-weight:600;color:{pal['accent']};line-height:1.35;max-width:480px;text-wrap:balance}}
</style></head><body>
<div class="decos">{deco}</div>
<img class="board" src="{board}">
<div class="txt"><div class="brand"><img class="icon" src="data:image/svg+xml;base64,{icon}"><h1>Arrowtile</h1></div><h2>{TAGLINE[lang]}</h2></div>
</body></html>'''


def make_features(p):
    board, bsize = board_png(p)
    b = p.chromium.launch()
    page = b.new_page(viewport={'width': 1024, 'height': 500}, device_scale_factor=1)
    for lang in LANGS:
        page.set_content(feature_html(lang, board, bsize))
        page.evaluate('document.fonts.ready')
        time.sleep(0.3)
        out = os.path.join(STORE, f'feature-graphic-{lang}.png')
        page.screenshot(path=out, clip={'x': 0, 'y': 0, 'width': 1024, 'height': 500}, omit_background=False)
        print('özellik grafiği', out)
    b.close()


def seed_state(lang):
    # tarihler çekim gününe göre (sabit tarih ay değişince takvimi ve seriyi boş gösteriyordu)
    import datetime
    today = datetime.date.today()
    yday = today - datetime.timedelta(days=1)
    pat = [3, 2, 3, 3, 2, 1, 3, 3, 2, 3]       # "orta oyun" oyuncusu: 62 seviye bitti, çoğu 3 yıldız, birkaçı 1-2
    stars = {str(i): pat[i % 10] for i in range(1, 63)}
    done = {}
    for back in range(1, 41):  # son 40 gün; iki gün boş, son 12 gün kesintisiz (seri 12)
        d = today - datetime.timedelta(days=back)
        if back in (15, 27):
            continue
        done[d.isoformat()] = 3 if back % 4 else 2
    return {
        'lang': lang, 'sound': True, 'vibration': True, 'coins': 860, 'freeHints': 2,
        'stars': stars, 'unlocked': 63, 'themesOwned': ['emaye', 'lokum', 'cini'], 'theme': 'emaye',
        'daily': {'lastDate': yday.isoformat(), 'streakDay': 3},
        'tutorialDone': [1, 2, 3], 'chapterBonus': [1, 2, 3],
        # adFree: web önizlemenin kesikli "Reklam alanı" yer tutucusu (banner) görünmesin — oyun koduna dokunulmaz
        'ads': {'since': 0, 'lastAt': 0, 'adFree': True, 'test': False},
        'appearance': 'light', 'relaxed': False, 'aim': False,
        'tips': ['curve_tip', 'aim_suggest', 'zoom_tip'],
        'dp': {'done': done, 'streak': 12, 'best': 12, 'last': yday.isoformat(), 'trophies': 28},
    }


REMOVE_FRAC = 0.30   # tahtadaki okların yaklaşık bu kadarı alınmış (yarım çözülmüş) görünür


def plan_taps(browser, lang, kind, seed):
    """?debug=1 AYRI bağlamında (aynı görünüm alanı + dil) gerçek oyunu başlatıp serbest oklardan rastgele seçerek
    kuyruk hücresi ekran koordinatlarını döndürür. Çekim sayfası kancasızdır; dokunuşlar orada gerçek tıklamayla yapılır."""
    ctx = browser.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=1, is_mobile=True, has_touch=True,
                              locale=LOCALES[lang], color_scheme='light')
    pg = ctx.new_page()
    url = GAME + '?debug=1'
    pg.goto(url); pg.evaluate('localStorage.clear()'); pg.goto(url)
    pg.wait_for_function("window.__ok && window.__ok.screen()=='menu'")
    st = seed_state(lang)
    pg.evaluate('s => window.__ok.debugPatch(s)', st)
    pg.evaluate(f"window.__ok.setLang('{lang}')")
    pg.evaluate('window.__ok.startDaily()' if kind == 'daily' else f'window.__ok.startLevel({kind})')
    pg.evaluate('document.fonts.ready'); time.sleep(1.5)
    pg.evaluate("window.dispatchEvent(new Event('resize'))"); time.sleep(0.5)
    rect = pg.evaluate("(()=>{const r=document.getElementById('board').getBoundingClientRect();return [r.x,r.y,r.width,r.height].map(v=>Math.round(v*10)/10)})()")
    total = len(pg.evaluate('window.__ok.level()')['arrows'])
    assert not pg.evaluate('window.__ok.view().pannable'), 'planlanan tahta kaydırmasız sığmalı'
    rng = random.Random(seed)
    taps = []
    for _ in range(round(total * REMOVE_FRAC)):
        free = pg.evaluate('window.__ok.game().free')
        if not free:
            break
        i = rng.choice(free)
        t = pg.evaluate(f'window.__ok.cellCenter({i})')
        t0 = time.time()
        pg.evaluate(f'window.__ok.tapArrow({i})')
        while pg.evaluate('window.__ok.busy()') and time.time() - t0 < 8:
            time.sleep(0.02)
        t['wait'] = time.time() - t0 + 0.35   # gerçek hızda çıkış animasyonu süresi (+pay): kancasız sayfa bunu bekler
        taps.append(t)
    ctx.close()
    return {'taps': taps, 'rect': rect}


def make_shots(p):
    b = p.chromium.launch()
    for lang in LANGS:
        out = os.path.join(STORE, 'screenshots', lang)
        os.makedirs(out, exist_ok=True)
        plans = {'easy': plan_taps(b, lang, 5, 11), 'xhard': plan_taps(b, lang, 60, 7), 'daily': plan_taps(b, lang, 'daily', 3)}
        ctx = b.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=3, is_mobile=True, has_touch=True,
                            locale=LOCALES[lang], color_scheme='light')
        state = json.dumps(seed_state(lang))
        ctx.add_init_script(f'try{{ if(!sessionStorage.getItem("seeded")){{ localStorage.setItem({json.dumps(SAVE_KEY)}, {json.dumps(state)}); localStorage.setItem("arrowtile.lang", {json.dumps(lang)}); sessionStorage.setItem("seeded","1"); }} }}catch(e){{}}')
        page = ctx.new_page()
        page.goto(GAME)
        page.wait_for_selector('#scr-menu.active')
        page.evaluate('document.fonts.ready'); time.sleep(0.6)
        assert page.evaluate('typeof window.__ok') == 'undefined', 'hata ayıklama kancası açık olmamalı'

        def no_ads():
            # mağaza görüntüsünde reklam yer tutucusu/banner görünmemeli
            bad = page.evaluate("""() => [...document.querySelectorAll('.banner')].filter(e => {
                const r = e.getBoundingClientRect(), cs = getComputedStyle(e);
                return !e.hidden && cs.display !== 'none' && cs.visibility !== 'hidden' && r.width > 0 && r.height > 0; }).length""")
            assert bad == 0, 'reklam alanı görünüyor'

        def shot(name):
            time.sleep(0.5)
            no_ads()
            page.screenshot(path=os.path.join(out, name))
            print(lang, name)

        def play_taps(plan):
            page.evaluate('document.fonts.ready'); time.sleep(0.5)
            rect = page.evaluate("(()=>{const r=document.getElementById('board').getBoundingClientRect();return [r.x,r.y,r.width,r.height].map(v=>Math.round(v*10)/10)})()")
            assert rect == plan['rect'], f'tahta yerleşimi planla aynı değil: {rect} != {plan["rect"]}'
            taps = plan['taps']
            for n_, t in enumerate(taps):
                page.mouse.click(t['x'], t['y'])
                time.sleep(max(1.3, 3 * t.get('wait', 0)))
            time.sleep(0.4)
            page.evaluate("var t=document.getElementById('toast'); if(t) t.classList.remove('show')")

        def to_level(n):
            # harita sanal listelenir (yalnızca görünen bölümler çizilir) → düğüm görünene dek aşağı/yukarı kaydır
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

        def pause_to_map():
            page.click('#btn-pause'); page.wait_for_selector('#pause-map'); page.click('#pause-map')
            page.wait_for_selector('#scr-map.active'); time.sleep(0.5)

        shot('01-menu.png')
        # 2) kolay seviye (seviye 5), yarım çözülmüş
        page.click('#btn-map'); page.wait_for_selector('#scr-map.active'); time.sleep(0.5)
        to_level(5)
        page.click('#map-scroll .node[data-level="5"]'); page.wait_for_selector('#scr-game.active'); time.sleep(1.0)
        play_taps(plans['easy'])
        shot('02-kolay-seviye.png')
        # 3) aşırı zor seviye (seviye 60), yarım çözülmüş
        pause_to_map()
        to_level(60)
        page.click('#map-scroll .node[data-level="60"]'); page.wait_for_selector('#scr-game.active'); time.sleep(1.0)
        play_taps(plans['xhard'])
        shot('03-asiri-zor-seviye.png')
        # 4) seviye haritası (sıradaki seviye 63 görünür; yıldızlı düğümler)
        pause_to_map()
        page.evaluate("document.getElementById('map-scroll').scrollTop += 300"); time.sleep(0.6)
        shot('04-harita.png')
        # 5) günlük bulmaca takvimi
        page.click('#scr-map [data-nav="menu"]'); page.wait_for_selector('#scr-menu.active'); time.sleep(0.3)
        page.click('#btn-dp'); page.wait_for_selector('#dp-sheet'); time.sleep(0.6)
        shot('05-gunluk-bulmaca.png')
        # 6) günlük bulmaca tahtası, yarım çözülmüş
        page.click('#dp-play'); page.wait_for_selector('#scr-game.active'); time.sleep(1.0)
        play_taps(plans['daily'])
        shot('06-gunluk-tahta.png')
        ctx.close()
    b.close()


if __name__ == '__main__':
    what = sys.argv[1:] or ['feature', 'shots']
    with sync_playwright() as p:
        if 'feature' in what: make_features(p)
        if 'shots' in what: make_shots(p)
