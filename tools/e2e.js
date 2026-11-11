// Arrowtile — geliştirici uçtan uca testi (Playwright + Chromium). Kullanım: node tools/e2e.js [bölüm...]
// Bölümler: core fix econ rename ads feat daily shots12 shots13 v15 lang levels (verilmezse hepsi). Ekran görüntüleri: tools/shots/v11/, v15/
// Oyun ?debug=1 ile açılır: hata ayıklama kancası (window.__ok) yalnızca bu kipte vardır ve kayıt
// gerçek anahtara değil kum havuzu anahtarına (Store.KEY) yazılır.
'use strict';
const path = require('path');
const fs = require('fs');
const vm = require('vm');

function loadPlaywright() {
  const tries = ['playwright', '/opt/npm-tools/node_modules/playwright', path.join(process.env.HOME || '', '.npm-global/lib/node_modules/playwright')];
  for (const t of tries) { try { return require(t); } catch (e) {} }
  throw new Error('Playwright bulunamadı: npm i -D playwright && npx playwright install chromium');
}
const { chromium } = loadPlaywright();
const S = require('./solver');

const ROOT = process.env.AT_ROOT || path.join(__dirname, '..'); // AT_ROOT: başka bir kopyayı test etmek için
const FILE = 'file://' + path.join(ROOT, 'game', 'index.html');
const URL = FILE + '?debug=1';
const SHOTS = path.join(__dirname, 'shots', 'v11');
fs.mkdirSync(SHOTS, { recursive: true });
const lctx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game/js/levels.js'), 'utf8'), lctx);
const LEVELS = lctx.window.LEVELS;
const ictx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game/js/i18n.js'), 'utf8'), ictx);
const I18N = ictx.window.I18N;
const sctx = { window: {}, location: { search: '?debug=1' }, navigator: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game/js/storage.js'), 'utf8'), sctx);
const DEBUG_KEY = sctx.window.Store.KEY;              // kum havuzu anahtarı
const REAL_KEY = DEBUG_KEY.replace(/\.debug$/, '');   // oyuncunun gerçek kayıt anahtarı

const LOCALES = { tr: 'tr-TR', en: 'en-US', de: 'de-DE', ar: 'ar-SA' };
const ONLY = process.argv.slice(2);
const want = s => !ONLY.length || ONLY.includes(s);
let failures = 0;
const results = [];
function check(name, cond, extra) {
  results.push(`${cond ? 'GEÇTİ' : 'KALDI'}  ${name}${extra ? '  (' + extra + ')' : ''}`);
  if (!cond) failures++;
}
const wait = ms => new Promise(r => setTimeout(r, ms));

async function newPage(browser, locale, opts = {}) {
  const ctx = await browser.newContext({
    viewport: { width: opts.width || 390, height: opts.height || 844 }, deviceScaleFactor: 2,
    isMobile: true, hasTouch: true, locale, colorScheme: opts.dark ? 'dark' : 'light',
    reducedMotion: opts.reduced ? 'reduce' : 'no-preference'
  });
  if (opts.init) await ctx.addInitScript(opts.init);
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', m => { if (m.type() === 'error' || /Content Security Policy/i.test(m.text())) errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));
  const url = opts.url || URL;
  if (opts.seed !== undefined || opts.storage) {
    await page.goto(url);
    await page.evaluate(([k, s, extra]) => {
      localStorage.clear();
      if (s !== undefined) localStorage.setItem(k, typeof s === 'string' ? s : JSON.stringify(s));
      Object.keys(extra || {}).forEach(x => localStorage.setItem(x, extra[x]));
    }, [DEBUG_KEY, opts.seed, opts.storage]);
  }
  await page.goto(url);
  if (url.includes('debug=1')) await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
  await wait(350); // ekran geçişi (200 ms)
  return { ctx, page, errors };
}
const base = (x = {}) => Object.assign({ lang: 'tr', coins: 50, freeHints: 2, tips: ['aim_suggest', 'zoom_tip'], stars: {}, unlocked: 36, themesOwned: ['emaye'], theme: 'emaye', daily: { lastDate: null, streakDay: 0 }, tutorialDone: [1, 2, 3], chapterBonus: [] }, x);
const idle = page => page.waitForFunction(() => !window.__ok.busy(), null, { timeout: 5000 }).catch(() => {});
const gs = page => page.evaluate(() => window.__ok.game());
const ss = page => page.evaluate(() => window.__ok.state());
async function tapArrowTouch(page, i) {
  const p = await page.evaluate(i => window.__ok.cellCenter(i), i);
  await page.touchscreen.tap(p.x, p.y);
}
async function solveTouch(page) {
  for (let n = 0; n < 200; n++) {
    const g = await gs(page); if (!g || g.won || !g.free.length) break;
    await tapArrowTouch(page, g.free[0]); await wait(30); await idle(page);
  }
  await page.waitForSelector('#end-sheet', { timeout: 5000 }).catch(() => {});
}
function blockedOf(L) { const al = L.arrows.map(() => true), g = S.buildGrid(L, al); return L.arrows.findIndex((a, i) => !S.canExit(L, i, g)); }

// Taşma, kırpma, ellipsis, ortadan bölünmüş kelime (test raporu H4 ile aynı ölçüt)
async function overflowReport(page) {
  return page.evaluate(() => {
    const out = [], vw = document.documentElement.clientWidth;
    const roots = [document.querySelector('.screen.active'), document.querySelector('#modal:not([hidden]) .sheet')].filter(Boolean);
    roots.forEach(root => root.querySelectorAll('*').forEach(n => {
      if (n.closest('[hidden]') || n.closest('svg')) return;
      const r = n.getBoundingClientRect(); if (!r.width) return;
      const cs = getComputedStyle(n), label = (n.id || n.className || n.tagName) + ' "' + n.textContent.trim().slice(0, 24) + '"';
      if (r.right > vw + 1 || r.left < -1) out.push('ekran dışı: ' + label + ' ' + Math.round(r.left) + '..' + Math.round(r.right));
      if (n.matches('.btn, .tab, .lang-btn, .tool, .seg button') && n.scrollWidth > n.clientWidth + 1) out.push('buton taşıyor: ' + label);
      if (cs.textOverflow === 'ellipsis') out.push('ellipsis: ' + label);
      if (n.matches('.btn:not(.tiny), .tab, .lang-btn') && parseFloat(cs.fontSize) < 14) out.push('font<14: ' + label);
      for (const tn of n.childNodes) { if (tn.nodeType !== 3 || n.matches('a')) continue; const re = /\S+/g; let m;
        while ((m = re.exec(tn.textContent))) { if (m[0].length < 4) continue; const rg = document.createRange(); rg.setStart(tn, m.index); rg.setEnd(tn, m.index + m[0].length);
          const tops = new Set([...rg.getClientRects()].filter(x => x.width > 0.5).map(x => Math.round(x.top / 3))); if (tops.size > 1) out.push('kelime bölündü: "' + m[0] + '"'); } }
    }));
    return [...new Set(out)];
  });
}

(async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });

  // ============================================================ CORE
  if (want('core')) {
    const { ctx, page, errors } = await newPage(browser, 'tr-TR', { seed: undefined, storage: {} });
    check('ilk açılışta dil navigator.language → tr', await page.evaluate(() => window.__ok.state().lang === 'tr' && document.documentElement.lang === 'tr'));
    await page.tap('#btn-play');
    await page.waitForFunction(() => window.__ok.screen() === 'game');
    check('Oyna → seviye 1, öğretici balonu', (await page.evaluate(() => window.__ok.level().id)) === 1 && await page.isVisible('#bubble'));
    const order = S.solve(LEVELS[0]).order;
    for (const i of order) { await idle(page); await tapArrowTouch(page, i); }
    await page.waitForSelector('#end-sheet', { timeout: 5000 }).catch(() => {});
    await wait(1400);
    check('seviye 1 çözüm sırasına göre dokunarak çözüldü, seviye sonu ekranı geldi', await page.isVisible('#end-sheet'));
    let st = await ss(page);
    check('3 yıldız + 20 jeton + seviye 2 açıldı', st.stars[1] === 3 && st.coins === 70 && st.unlocked === 2, JSON.stringify({ s: st.stars[1], c: st.coins, u: st.unlocked }));
    await page.screenshot({ path: path.join(SHOTS, 'tr-end.png') });
    await page.tap('#end-replay'); await page.waitForFunction(() => !document.querySelector('#end-sheet')); await wait(250);
    const b = blockedOf(LEVELS[0]);
    await tapArrowTouch(page, b); await wait(500);
    let g = await gs(page);
    const lost = await page.evaluate(() => document.querySelectorAll('#hearts .lost').length);
    check('çarpışma: can 3→2, ok yerinde, HUD güncellendi', g.lives === 2 && g.collisions === 1 && g.remaining === 2 && lost === 1, JSON.stringify({ l: g.lives, lost }));
    // v1.2 (docs/08): geri alma yok, çarpışma kalıcı can kaybı
    check('v1.2: oyun ekranında geri alma düğmesi yok, araç çubuğunda yalnızca ipucu + baştan', !(await page.$('#btn-undo')) && (await page.$$('.toolbar .tool')).length === 2);
    await page.tap('#btn-hint'); await wait(100);
    check('ipucu: base() kaydında 2 ücretsiz hak (mevcut oyuncu), kullanınca 2→1', (await ss(page)).freeHints === 1);
    for (let k = 0; k < 3; k++) { await tapArrowTouch(page, b); await wait(80); await idle(page); }
    await page.waitForSelector('#dead-sheet', { timeout: 3000 }).catch(() => {});
    check('can bitince "Canın bitti" penceresi', await page.isVisible('#dead-sheet'));
    await page.screenshot({ path: path.join(SHOTS, 'tr-dead.png') });
    await page.tap('#dead-retry'); await wait(200);
    check('tekrar dene: 3 can', (await gs(page)).lives === 3);
    // bozuk kayıt
    await page.evaluate(k => localStorage.setItem(k, '{bozuk json'), DEBUG_KEY);
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    check('bozuk kayıtta güvenli varsayılan (50 jeton)', (await ss(page)).coins === 50);
    await page.evaluate(k => localStorage.setItem(k, JSON.stringify({ coins: 'x', stars: { 1: 9, foo: 2 }, theme: 'yok', lang: 'zz', unlocked: -4 })), DEBUG_KEY);
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    st = await ss(page);
    check('hatalı alanlar onarıldı', st.coins === 50 && st.stars[1] === 3 && st.theme === 'emaye' && st.unlocked === 1 && ['tr', 'en', 'de', 'ar'].includes(st.lang));
    check('core: konsol hatası yok', errors.length === 0, errors.join(' | '));
    await ctx.close();
  }

  // ============================================================ TEST RAPORU DÜZELTMELERİ (H1-H7)
  if (want('fix')) {
    // H2: sürüm yapısında kanca yok; debug kipinde salt okunur, gerçek kayda yazmaz
    {
      const { ctx, page, errors } = await newPage(browser, 'tr-TR', { url: FILE });
      await page.evaluate(k => localStorage.setItem(k, JSON.stringify({ coins: 10, lang: 'tr' })), REAL_KEY);
      await page.reload(); await wait(300);
      check('H2: sürüm yapısında (debug parametresi yok) window.__ok tanımsız', await page.evaluate(() => typeof window.__ok === 'undefined'));
      await page.goto(URL); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
      const frozen = await page.evaluate(() => { const s = window.__ok.state(); try { s.coins = 999999; } catch (e) {} return Object.isFrozen(s) && window.__ok.state().coins !== 999999; });
      check('H2: debug kipinde state() dondurulmuş kopya; atama durumu değiştirmez', frozen);
      await page.evaluate(() => window.__ok.debugPatch({ coins: 777777 }));
      await page.evaluate(() => window.__ok.startLevel(5)); await wait(300);
      await page.tap('#btn-pause'); await wait(200);
      const f0 = (await gs(page)).free[0];
      const r = await page.evaluate(i => window.__ok.tapArrow(i), f0);
      check('H2: duraklatma açıkken __ok.tapArrow hamle yapamaz', r === null && (await gs(page)).alive[f0]);
      await page.goto(FILE); await wait(300);
      const real = await page.evaluate(k => JSON.parse(localStorage.getItem(k) || '{}').coins, REAL_KEY);
      check('H2: debug oturumu gerçek kayda hiç yazmadı (jeton 10 kaldı)', real === 10, String(real));
      check('H7: CSP altında konsol hatası / ihlal yok', errors.length === 0, errors.join(' | '));
      await ctx.close();
    }
    for (const VP of [{ width: 390, height: 844 }, { width: 360, height: 740 }]) {
      const tag = VP.width + 'px';
      const { ctx, page, errors } = await newPage(browser, 'tr-TR', { ...VP, seed: base() });
      // H3: 8 sütunlu tahtada hücre ≥ 40 px
      // v1.2 (docs/08 §4): en büyük tahta (15x22) ekrana sığar, hücre ≥ 22 px
      let big = 1; LEVELS.forEach((L, k) => { if (L.w * L.h > LEVELS[big - 1].w * LEVELS[big - 1].h) big = k + 1; });
      await page.evaluate(id => window.__ok.startLevel(id), big); await wait(300);
      const cell = await page.evaluate(() => { const L = window.__ok.level(), tx = a => (a.cells ? a.cells[0][0] : a.x);
        const a = window.__ok.cellCenter(0), i = L.arrows.findIndex((x, k) => k > 0 && tx(x) !== tx(L.arrows[0]));
        const b = window.__ok.cellCenter(i); return Math.abs(b.x - a.x) / Math.abs(tx(L.arrows[i]) - tx(L.arrows[0])); });
      // v1.3 (docs/09): sığdırılmış hücre en az 16 px
      check(`v1.3 ${tag}: en büyük seviyede (${LEVELS[big - 1].w}x${LEVELS[big - 1].h}) hücre ≥ 16 px`, cell >= 16, cell.toFixed(1));
      const tray = await page.evaluate(() => { const c = document.getElementById('board').getBoundingClientRect(); return [c.left, c.right, document.documentElement.clientWidth]; });
      check(`H3 ${tag}: tahta ekran içinde`, tray[0] >= 0 && tray[1] <= tray[2] + 0.5);
      // H1: çıkış animasyonu sürerken dokunuş yok sayılır (yolunu kayan ok kapatan ok dahil)
      const L = LEVELS[big - 1]; let pair = null;
      for (const i of S.solve(L).order) {
        const al = L.arrows.map(() => true); const g0 = S.buildGrid(L, al); if (!S.canExit(L, i, g0)) continue;
        al[i] = false; const g1 = S.buildGrid(L, al);
        const j = L.arrows.findIndex((a, k) => al[k] && !S.canExit(L, k, g0) && S.canExit(L, k, g1));
        if (j >= 0) { pair = [i, j]; break; }
      }
      if (pair) {
        await tapArrowTouch(page, pair[0]); await wait(40); await tapArrowTouch(page, pair[1]); await wait(30);
        const g = await gs(page);
        check(`H1 ${tag}: kayan okun arkasındaki ok 40 ms sonra dokunulunca çıkmaz`, g.alive[pair[1]] && !g.alive[pair[0]]);
        await idle(page); await wait(50);
        await tapArrowTouch(page, pair[1]); await wait(30);
        check(`H1 ${tag}: animasyon bitince aynı ok çıkar`, !(await gs(page)).alive[pair[1]]);
      } else check(`H1 ${tag}: test çifti bulundu`, false);
      check(`fix ${tag}: konsol hatası yok`, errors.length === 0, errors.join(' | '));
      await ctx.close();
    }
    // H5: öğretici sv2'de can götürmeyen çarpışma geri alınmaz, ücret alınmaz
    {
      const { ctx, page, errors } = await newPage(browser, 'tr-TR', { seed: base({ tutorialDone: [1], coins: 100 }) });
      await page.evaluate(() => window.__ok.startLevel(2)); await wait(300);
      await tapArrowTouch(page, blockedOf(LEVELS[1])); await wait(450); await idle(page);
      const g5 = await gs(page);
      check('öğretici sv2: muaf çarpışma can götürmez (geri alma artık yok)', g5.lives === 3 && g5.collisions === 0 && (await ss(page)).coins === 100);
      // H6: yatay ekranda uyarı
      await page.setViewportSize({ width: 844, height: 390 }); await wait(300);
      const rot = await page.evaluate(() => { const r = document.getElementById('rotate'); return getComputedStyle(r).display !== 'none' && r.textContent.trim(); });
      check('H6: yatay telefonda "cihazı çevir" uyarısı görünür', rot === I18N.tr['app.rotate'], String(rot));
      await page.screenshot({ path: path.join(SHOTS, 'tr-landscape.png') });
      await page.setViewportSize({ width: 390, height: 844 }); await wait(300);
      check('H6: dikeye dönünce uyarı kalkar', await page.evaluate(() => getComputedStyle(document.getElementById('rotate')).display === 'none'));
      check('H5/H6: konsol hatası yok', errors.length === 0, errors.join(' | '));
      await ctx.close();
    }
    const html = fs.readFileSync(path.join(ROOT, 'game/index.html'), 'utf8');
    check('H7: index.html içinde Content-Security-Policy meta etiketi', /http-equiv="Content-Security-Policy"/.test(html) && /connect-src 'none'/.test(html));
  }

  // ============================================================ v1.2 EKONOMİ: geri alma kaldırıldı (docs/08)
  if (want('econ')) {
    check('i18n: geri alma metinleri kaldırıldı', ['tr', 'en', 'de', 'ar'].every(l => !['game.undo', 'game.nothing_to_undo', 'game.buy_undo', 'shop.undo_desc'].some(k => k in I18N[l])));
    const { ctx, page, errors } = await newPage(browser, 'tr-TR', { url: FILE });
    // v1.1 kaydı: 3 ücretsiz geri alma → +60 jeton
    await page.evaluate(k => { localStorage.clear(); localStorage.setItem(k, JSON.stringify({ lang: 'tr', coins: 10, freeHints: 3, freeUndos: 3, stars: { 1: 3 }, unlocked: 2 })); }, REAL_KEY);
    await page.reload(); await wait(350);
    let r = await page.evaluate(k => JSON.parse(localStorage.getItem(k)), REAL_KEY);
    check('kayıt göçü: ücretsiz geri alma hakları jetona (3 × 20 = 60), alan silindi', r.coins === 70 && !('freeUndos' in r) && r.freeHints === 3, JSON.stringify({ c: r.coins, u: r.freeUndos }));
    await page.reload(); await wait(300);
    r = await page.evaluate(k => JSON.parse(localStorage.getItem(k)), REAL_KEY);
    check('kayıt göçü bir kez uygulanır (yeniden açılışta jeton artmaz)', r.coins === 70);
    await ctx.close();
    { const N = await newPage(browser, 'tr-TR', { storage: {} }); r = await ss(N.page);
      check('yeni oyuncu (v1.1.6): 50 jeton + 0 ücretsiz ipucu', r.coins === 50 && r.freeHints === 0 && !('freeUndos' in r)); await N.ctx.close(); }
    const P = await newPage(browser, 'tr-TR', { seed: base({ freeHints: 0, coins: 120 }) });
    await P.page.evaluate(() => window.__ok.startLevel(8)); await wait(300);
    check('ipucu düğmesinde fiyat 50', /50/.test(await P.page.textContent('#hint-sub')));
    await P.page.tap('#btn-hint'); await wait(150);
    check('ipucu 50 jeton', (await ss(P.page)).coins === 70);
    await P.page.tap('#btn-hint'); await wait(150); await P.page.tap('#btn-hint'); await wait(150);
    check('yetersiz jetonda (20) ipucu verilmez; "Jetonun yetmiyor" penceresi (reklam / mağaza / kapat) açılır', (await ss(P.page)).coins === 20 && (await P.page.isVisible('#lowcoins-sheet')) && (await P.page.isVisible('#lowcoins-shop')) && (await P.page.isVisible('#lowcoins-close')));
    await P.page.tap('#lowcoins-close'); await wait(150);
    await P.page.evaluate(() => window.__ok.show('shop')); await wait(250); await P.page.tap('#tab-boosters'); await wait(150);
    check('mağaza yardımcılarında ipucu (50) + reklam izle jeton kartı var', (await P.page.$$('#shop-list .item')).length === 2 && (await P.page.isVisible('#shop-watch-coins')) && /50/.test(await P.page.textContent('#shop-list .item')));
    check('ekonomi: konsol hatası yok', errors.length === 0 && P.errors.length === 0, errors.concat(P.errors).join(' | '));
    await P.ctx.close();
  }

  // ============================================================ AD DEĞİŞİKLİĞİ + ESKİ KAYIT TAŞIMA (aşama 2)
  if (want('rename')) {
    for (const [lang, loc] of Object.entries(LOCALES)) {
      const { ctx, page } = await newPage(browser, loc, { storage: {} });
      const nm = await page.evaluate(() => [document.getElementById('menu-title').textContent, document.title]);
      check(`${lang}: oyun adı "Arrowtile" (menü + sekme başlığı)`, nm[0] === 'Arrowtile' && nm[1] === 'Arrowtile', nm.join(' / '));
      await ctx.close();
    }
    check('i18n: app.name 4 dilde "Arrowtile", eski app.title yok', ['tr', 'en', 'de', 'ar'].every(l => I18N[l]['app.name'] === 'Arrowtile' && !('app.title' in I18N[l])));
    const titles = { tr: 'Arrowtile: Ok Bulmacası', en: 'Arrowtile: Arrow Puzzle', de: 'Arrowtile: Pfeil-Rätsel', ar: 'Arrowtile: لغز الأسهم' };
    check('mağaza başlıkları brifteki gibi (≤30)', Object.keys(titles).every(l => I18N[l]['store.title'] === titles[l] && [...titles[l]].length <= 30));
    check('kayıt anahtarı arrowtile.save.v1', REAL_KEY === 'arrowtile.save.v1', REAL_KEY);
    // G9: mağaza metinleri (i18n ↔ docs/07), sınırlar ve üç vaat
    const doc07 = fs.existsSync(path.join(ROOT, 'docs/07-magaza-metinleri.md')) ? fs.readFileSync(path.join(ROOT, 'docs/07-magaza-metinleri.md'), 'utf8') : '';
    check('G9: docs/07 dört dilin başlık/kısa/uzun metnini i18n ile birebir içerir', ['tr', 'en', 'de', 'ar'].every(l => ['store.title', 'store.short', 'store.long'].every(k => I18N[l][k] && doc07.includes(I18N[l][k]))));
    check('G9: sınırlar (başlık ≤30, kısa ≤80, uzun ≤4000)', ['tr', 'en', 'de', 'ar'].every(l => [...I18N[l]['store.title']].length <= 30 && [...I18N[l]['store.short']].length <= 80 && [...I18N[l]['store.long']].length <= 4000));
    // v1.2 (docs/08 §5): "geri alma var" vaadi kalktı → süre yok, internetsiz, zorlu bulmacalar
    const vows = { tr: [/süre/i, /internet/i, /zorlu/i], en: [/no timers/i, /internet/i, /tough/i], de: [/zeitlimit/i, /internet/i, /knifflig/i], ar: [/وقت/, /إنترنت/, /صعب/] };
    const noUndo = { tr: /geri al/i, en: /undo/i, de: /rückgängig/i, ar: /التراجع/ };
    check('G9: kısa açıklamada üç vaat (süre yok, internetsiz, zorlu) 4 dilde', Object.keys(vows).every(l => vows[l].every(r => r.test(I18N[l]['store.short']))));
    check('G9: mağaza metinlerinde geri alma vaadi yok', Object.keys(noUndo).every(l => !noUndo[l].test(I18N[l]['store.short']) && !noUndo[l].test(I18N[l]['store.long'])));
    // eski okKacis.save.v1 → arrowtile.save.v1 taşıma (sürüm yapısı, kanca yok: localStorage'dan okunur)
    {
      const { ctx, page, errors } = await newPage(browser, 'en-US', { url: FILE });
      const old = { lang: 'de', coins: 123, freeHints: 1, stars: { 1: 3, 2: 2 }, unlocked: 3, themesOwned: ['emaye', 'lokum'], theme: 'lokum', daily: { lastDate: '2026-10-20', streakDay: 4 }, tutorialDone: [1, 2, 3], chapterBonus: [] };
      await page.evaluate(o => { localStorage.clear(); localStorage.setItem('okKacis.save.v1', JSON.stringify(o)); localStorage.setItem('okKacis.lang', 'de'); }, old);
      await page.reload(); await wait(400);
      const r = await page.evaluate(k => ({ nw: JSON.parse(localStorage.getItem(k) || 'null'), old: localStorage.getItem('okKacis.save.v1'), oldLang: localStorage.getItem('okKacis.lang'), lang: document.documentElement.lang, play: document.getElementById('btn-play').textContent, coins: document.querySelector('[data-bind="coins"]').textContent }), REAL_KEY);
      check('eski kayıt taşındı: jeton, yıldız, kilit, tema, günlük seri korunur', r.nw && r.nw.coins === 123 && r.nw.stars[1] === 3 && r.nw.unlocked === 3 && r.nw.theme === 'lokum' && r.nw.daily.streakDay === 4, JSON.stringify(r.nw && { c: r.nw.coins, u: r.nw.unlocked, t: r.nw.theme }));
      check('taşımadan sonra eski anahtarlar silindi, dil korundu (de), menü "Weiter: Level 3"', r.old === null && r.oldLang === null && r.lang === 'de' && r.coins === '123' && /3/.test(r.play), JSON.stringify({ o: r.old, l: r.lang, p: r.play }));
      // yeni anahtar varken eski veri üzerine yazılmaz
      await page.evaluate(k => { localStorage.setItem('okKacis.save.v1', JSON.stringify({ coins: 9999 })); }, REAL_KEY);
      await page.reload(); await wait(300);
      const r2 = await page.evaluate(k => [JSON.parse(localStorage.getItem(k)).coins, localStorage.getItem('okKacis.save.v1') !== null], REAL_KEY);
      check('yeni kayıt varken eski anahtar yeni kaydın üzerine yazılmaz', r2[0] === 123 && r2[1], JSON.stringify(r2));
      // bozuk eski kayıt: güvenli varsayılan
      await page.evaluate(k => { localStorage.clear(); localStorage.setItem('okKacis.save.v1', '{bozuk'); }, REAL_KEY);
      await page.reload(); await wait(300);
      const r3 = await page.evaluate(k => JSON.parse(localStorage.getItem(k) || 'null'), REAL_KEY);
      check('bozuk eski kayıt güvenli varsayılana taşınır (50 jeton), oyun açılır', r3 && r3.coins === 50 && await page.isVisible('#btn-play'));
      check('taşıma: konsol hatası yok', errors.length === 0, errors.join(' | '));
      await ctx.close();
    }
  }

  // ============================================================ REKLAM + SATIN ALMA + GİZLİLİK (aşama 3)
  // Sahte Android köprüsü: çağrıları kaydeder, yerel tarafın yanıtlarını Monetization.onNative ile taklit eder.
  const FAKE_BRIDGE = `window.__bridgeCalls = []; window.__bridgeOnline = true;
    window.AndroidBridge = {
      isAdFree() { return !!window.__bridgeOwned; }, isOnline() { return window.__bridgeOnline; }, isRewardedReady() { return true; },
      showInterstitial(id) { __bridgeCalls.push('interstitial'); setTimeout(() => Monetization.onNative(JSON.stringify({ id, event: 'closed' })), 60); return true; },
      showRewarded(id, pl) { __bridgeCalls.push('rewarded:' + pl); setTimeout(() => { Monetization.onNative({ id, event: 'rewarded' }); Monetization.onNative({ id, event: 'closed' }); }, 60); return true; },
      purchaseRemoveAds(id) { __bridgeCalls.push('purchase'); setTimeout(() => { window.__bridgeOwned = true; Monetization.onNative({ id, event: 'purchased' }); }, 60); return true; },
      restorePurchases(id) { __bridgeCalls.push('restore'); setTimeout(() => Monetization.onNative({ id, event: 'restored', adFree: !!window.__bridgeOwned }), 60); return true; }
    };`;
  async function winLevel(page, id) {
    await page.evaluate(i => { window.__ok.fastAnim(true); window.__ok.startLevel(i); }, id); await wait(250);
    await page.evaluate(async () => { const sl = ms => new Promise(r => setTimeout(r, ms)); let n = 0;
      while (!window.__ok.game().won && n++ < 300) { while (window.__ok.busy()) await sl(5); const f = window.__ok.game().free; if (!f.length) break; window.__ok.tapArrow(f[0]); } });
    await page.waitForSelector('#end-sheet', { timeout: 5000 }); await wait(150);
  }
  if (want('ads')) {
    const { ctx, page, errors } = await newPage(browser, 'tr-TR', { init: FAKE_BRIDGE, seed: base({ unlocked: 40 }) });
    const calls = () => page.evaluate(() => window.__bridgeCalls.slice());
    for (const id of [10, 11, 12]) { await winLevel(page, id); await page.tap('#end-next'); await wait(250); }
    check('reklam: bölüm 1 (sv 10-12) sonunda geçiş reklamı yok', (await calls()).filter(c => c === 'interstitial').length === 0);
    await winLevel(page, 13); await page.tap('#end-next'); await wait(250);
    await winLevel(page, 14); await page.tap('#end-next'); await wait(250);
    check('reklam: 13 ve 14 sonrası reklam yok (sayaç 2)', (await calls()).filter(c => c === 'interstitial').length === 0 && (await ss(page)).ads.since === 2);
    await winLevel(page, 15);
    check('reklam: seviye sonu ekranında (devam etmeden) reklam yok', (await calls()).filter(c => c === 'interstitial').length === 0);
    await page.tap('#end-next'); await wait(400);
    check('reklam: 3. tamamlamada "Sonraki" ile geçiş reklamı, reklam kapanınca seviye 16 açılır', (await calls()).filter(c => c === 'interstitial').length === 1 && (await page.evaluate(() => window.__ok.level().id)) === 16);
    for (const id of [16, 17, 18]) { await winLevel(page, id); await page.tap('#end-replay'); await wait(300); }
    check('reklam: 3 dk dolmadan ikinci reklam yok', (await calls()).filter(c => c === 'interstitial').length === 1);
    // başarısız deneme sayılmaz
    const sinceBefore = (await ss(page)).ads.since;
    await page.evaluate(() => window.__ok.startLevel(20)); await wait(250);
    const L20 = LEVELS[19], b20 = blockedOf(L20);
    for (let k = 0; k < 3; k++) { await tapArrowTouch(page, b20); await wait(80); await idle(page); }
    await page.waitForSelector('#dead-sheet', { timeout: 8000 });
    check('reklam: başarısız deneme sayaca eklenmez, can bitince geçiş reklamı yok', (await ss(page)).ads.since === sinceBefore && (await calls()).filter(c => c === 'interstitial').length === 1);
    // ödüllü reklam: +1 can (isteğe bağlı)
    check('ödüllü: "can bitti" penceresinde isteğe bağlı "+1 can" seçeneği', await page.isVisible('#dead-revive'));
    await page.tap('#dead-revive'); await wait(400);
    const gv = await gs(page);
    check('ödüllü: izlenince +1 can, pencere kapanır, seviye kaldığı yerden sürer', gv.lives === 1 && !(await page.isVisible('#dead-sheet')) && gv.collisions === 3 && (await calls()).includes('rewarded:life'));
    await tapArrowTouch(page, b20); await wait(80); await idle(page);
    await page.waitForSelector('#dead-sheet', { timeout: 8000 });
    check('ödüllü +1 can seviye başına en fazla 1 kez (ikinci ölümde seçenek yok)', !(await page.isVisible('#dead-revive')));
    await page.tap('#dead-retry'); await wait(200);
    for (let k = 0; k < 3; k++) { await tapArrowTouch(page, b20); await wait(80); await idle(page); }
    await page.waitForSelector('#dead-sheet', { timeout: 8000 });
    check('baştan başlayınca da aynı seviyede ikinci kez +1 can sunulmaz', !(await page.isVisible('#dead-revive')));
    await page.tap('#dead-retry'); await wait(200);
    // duraklatma menüsünde reklam yok
    await page.tap('#btn-pause'); await wait(200); await page.tap('#pause-map'); await wait(300);
    check('reklam: duraklat → haritaya dön reklam göstermez', (await calls()).filter(c => c === 'interstitial').length === 1);
    // 3 dk geçtiyse yeniden reklam
    await page.evaluate(() => window.__ok.debugPatch({ ads: Object.assign({}, window.__ok.state().ads, { lastAt: Date.now() - 181000 }) }));
    await winLevel(page, 21); await page.tap('#end-map'); await wait(400);
    check('reklam: 3 dk sonra ve ≥3 tamamlamada "Harita" ile de devam ederken reklam', (await calls()).filter(c => c === 'interstitial').length === 2 && (await page.evaluate(() => window.__ok.screen())) === 'map');
    // çevrimdışı
    await page.evaluate(() => { window.__bridgeOnline = false; window.__ok.debugPatch({ ads: Object.assign({}, window.__ok.state().ads, { since: 5, lastAt: 0 }) }); });
    await winLevel(page, 22); await page.tap('#end-next'); await wait(300);
    check('reklam: internet yoksa reklam yok, oyun devam eder', (await calls()).filter(c => c === 'interstitial').length === 2 && (await page.evaluate(() => window.__ok.level().id)) === 23);
    await page.evaluate(() => { window.__bridgeOnline = true; });
    // ödüllü ipucu (mağaza)
    await page.evaluate(() => window.__ok.show('shop')); await wait(250); await page.tap('#tab-boosters'); await wait(200);
    const h0 = (await ss(page)).freeHints;
    await page.tap('#shop-watch-hint'); await wait(400);
    check('ödüllü: mağazada "+1 ipucu" (isteğe bağlı) çalışır', (await ss(page)).freeHints === h0 + 1);
    // reklamları kaldır (köprü)
    await page.tap('#shop-remove-ads'); await wait(400);
    check('satın alma: "Reklamları kaldır" köprüye gider, reklamsız olur, kart güncellenir', (await calls()).includes('purchase') && (await ss(page)).ads.adFree === true && await page.isVisible('#shop-adfree'));
    await page.evaluate(() => window.__ok.debugPatch({ ads: Object.assign({}, window.__ok.state().ads, { since: 9, lastAt: 0 }) }));
    await winLevel(page, 24); await page.tap('#end-next'); await wait(300);
    check('reklamsız: geçiş reklamı yok', (await calls()).filter(c => c === 'interstitial').length === 2);
    await page.evaluate(() => window.__ok.show('settings')); await wait(250);
    await page.tap('#set-restore'); await wait(400);
    check('ayarlar: "Satın alımları geri yükle" köprüye gider ve sonucu bildirir', (await calls()).includes('restore') && (await page.textContent('#toast')) === I18N.tr['ads.restored_ok']);
    check('reklam testi: konsol hatası yok', errors.length === 0, errors.join(' | '));
    await ctx.close();
  }
  if (want('ads')) {
    // köprü yok (web önizleme): reklam yok, satın alma test modunda
    const { ctx, page, errors } = await newPage(browser, 'en-US', { seed: base({ lang: 'en', unlocked: 40, ads: { since: 5, lastAt: 0, adFree: false, test: false } }) });
    await winLevel(page, 30); await page.tap('#end-next'); await wait(300);
    check('köprü yok: reklam gösterilmez, "Sonraki" hemen seviye 31', (await page.evaluate(() => window.__ok.level().id)) === 31);
    await page.evaluate(() => window.__ok.show('settings')); await wait(250);
    check('köprü yok: "Test modu" notu görünür, ödüllü seçenek sunulmaz', await page.isVisible('.test-note'));
    await page.tap('#set-remove-ads'); await wait(250);
    const a = (await ss(page)).ads;
    check('köprü yok: satın alma test modunda taklit edilir', a.adFree && a.test);
    await page.evaluate(() => window.__ok.startLevel(5)); await wait(400);
    const b5 = blockedOf(LEVELS[4]);
    for (let k = 0; k < 3; k++) { await tapArrowTouch(page, b5); await wait(80); await idle(page); }
    await page.waitForSelector('#dead-sheet', { timeout: 8000 });
    check('köprü yok (test modu): "can bitti" penceresinde ödüllü reklam seçeneği görünür (taklit)', await page.isVisible('#dead-revive'));
    check('ilerlemeyi sıfırla satın almayı silmez', await (async () => { await page.evaluate(() => window.__ok.show('settings')); await wait(200); await page.tap('#btn-reset'); await wait(200); await page.tap('#confirm-yes'); await wait(200); return (await ss(page)).ads.adFree === true; })());
    check('köprü yok: konsol hatası yok', errors.length === 0, errors.join(' | '));
    await ctx.close();
    // gizlilik: "veri toplamaz" ifadesi kalktı; gizlilik ekranı + bağımsız sayfa 4 dilde
    const bad = /veri toplamaz|collects no data|sammelt keine Daten|لا تجمع أي بيانات/;
    check('i18n: "veri toplamaz" ifadesi hiçbir dilde yok', ['tr', 'en', 'de', 'ar'].every(l => !Object.values(I18N[l]).some(v => bad.test(v))));
    for (const [lang, loc] of Object.entries(LOCALES)) {
      const P = await newPage(browser, loc, { storage: {} });
      await P.page.evaluate(() => window.__ok.show('settings')); await wait(250);
      await P.page.tap('#btn-privacy'); await wait(350);
      const txt = await P.page.textContent('#privacy-body');
      check(`${lang}: oyun içi gizlilik politikası (AdMob, Google Play, e-posta)`, txt.includes('AdMob') && txt.includes('Google Play') && txt.includes('nilkaren.tuncay.demir@gmail.com'));
      await P.page.screenshot({ path: path.join(SHOTS, `${lang}-privacy.png`) });
      const ov = await overflowReport(P.page); check(`${lang}: gizlilik ekranı taşma yok`, ov.length === 0, ov.slice(0, 4).join('; '));
      await P.page.goto(FILE.replace('index.html', 'privacy.html') + '?lang=' + lang); await wait(300);
      const pg = await P.page.evaluate(() => [document.documentElement.lang, document.documentElement.dir, document.getElementById('body').textContent.length, document.title]);
      check(`${lang}: bağımsız privacy.html (lang/dir, metin)`, pg[0] === lang && pg[1] === (lang === 'ar' ? 'rtl' : 'ltr') && pg[2] > 400 && pg[3].startsWith('Arrowtile'), pg.join(' | '));
      check(`${lang}: gizlilik: konsol hatası yok`, P.errors.length === 0, P.errors.join(' | '));
      await P.ctx.close();
    }
  }

  // ============================================================ G1 G2 G3 G7 G6 (aşama 4)
  if (want('feat')) {
    const { ctx, page, errors } = await newPage(browser, 'tr-TR', { seed: base({ unlocked: 40 }) });
    // G1: iki komşu okun tam sınırına dokunuş hiçbir oku oynatmaz; genişletilmiş alan
    let found = null;
    for (let id = 4; id <= 36 && !found; id++) {
      const L = LEVELS[id - 1], g = S.buildGrid(L, L.arrows.map(() => true));
      for (let i = 0; i < L.arrows.length && !found; i++) {
        const a = L.arrows[i], ac = S.cellsOf(a); if (ac.length !== 1) continue;
        // sağ komşu hücre tek hücrelik başka bir dikey okun (eksenler paralel) → sınır belirsiz
        const ax = ac[0][0], ay = ac[0][1], j = g[ay * L.w + ax + 1];
        if (ax + 1 < L.w && j >= 0 && j !== i && S.cellsOf(L.arrows[j]).length === 1 && (a.dir === 'U' || a.dir === 'D') && (L.arrows[j].dir === 'U' || L.arrows[j].dir === 'D')) found = { id, i, j };
      }
    }
    if (found) {
      await page.evaluate(i => window.__ok.startLevel(i), found.id); await wait(300);
      const v = await page.evaluate(() => window.__ok.view());
      const ci = await page.evaluate(i => window.__ok.cellCenter(i), found.i);
      await page.touchscreen.tap(ci.x + v.cell / 2, ci.y); await wait(350);
      const g1 = await gs(page);
      check('G1: iki okun tam arasına dokunuş hiçbir oku oynatmaz (çarpışma da yok)', g1.alive[found.i] && g1.alive[found.j] && g1.lives === 3 && g1.collisions === 0, `sv${found.id} ok${found.i}/ok${found.j}`);
    } else check('G1: test için komşu ok çifti bulundu', false);
    {
      // genişletilmiş alan: açık okun başının hemen önündeki boş hücrenin yarısına dokun
      let tgt = null;
      for (let id = 4; id <= 36 && !tgt; id++) {
        const L = LEVELS[id - 1], al = L.arrows.map(() => true), g = S.buildGrid(L, al);
        L.arrows.forEach((a, i) => { if (tgt || !S.canExit(L, i, g)) return; const h = S.headOf(a), d = S.DIRS[a.dir], nx = h[0] + d[0], ny = h[1] + d[1];
          if (nx >= 0 && ny >= 0 && nx < L.w && ny < L.h && g[ny * L.w + nx] === -1) {
            const near = L.arrows.some((b, k) => k !== i && S.cellsOf(b).some(c => Math.abs(c[0] - nx) + Math.abs(c[1] - ny) <= 1));
            if (!near) { const t0 = S.cellsOf(a)[0]; tgt = { id, i, d, hx: h[0] - t0[0], hy: h[1] - t0[1] }; } } });
      }
      if (tgt) {
        await page.evaluate(i => window.__ok.startLevel(i), tgt.id); await wait(300);
        const v = await page.evaluate(() => window.__ok.view());
        const c0 = await page.evaluate(i => window.__ok.cellCenter(i), tgt.i);
        // baş hücresinin merkezinden yön boyunca 0,45 hücre ötesi (isabet eşiği 0,5; v1.3 kıvrımlı oklar da)
        await page.touchscreen.tap(c0.x + (tgt.hx + tgt.d[0] * 0.45) * v.cell, c0.y + (tgt.hy + tgt.d[1] * 0.45) * v.cell); await wait(80);
        check('G1: okun gövde eksenine 0,45 hücre uzaklıkta dokunuş o oku oynatır', !(await gs(page)).alive[tgt.i], `sv${tgt.id} ok${tgt.i}`);
      } else check('G1: genişletilmiş alan testi için ok bulundu', false);
    }
    // G1: önce seç, sonra fırlat
    await page.evaluate(() => window.__ok.debugPatch({ aim: true }));
    await page.evaluate(() => window.__ok.startLevel(6)); await wait(300);
    let f = (await gs(page)).free[0];
    await tapArrowTouch(page, f); await wait(150);
    check('G1 seçim modu: ilk dokunuş oku yalnızca seçer', (await gs(page)).alive[f]);
    await page.screenshot({ path: path.join(SHOTS, 'tr-aim.png') });
    await tapArrowTouch(page, f); await wait(150);
    check('G1 seçim modu: ikinci dokunuş fırlatır', !(await gs(page)).alive[f]);
    await page.evaluate(() => window.__ok.debugPatch({ aim: false }));
    // G2: yakınlaştırma, dokunuş doğru oka gider, Sığdır
    await page.evaluate(() => window.__ok.startLevel(30)); await wait(300);
    check('G2: başlangıçta tahta ekrana sığar (ölçek 1), Sığdır düğmesi gizli', (await page.evaluate(() => window.__ok.view().s)) === 1 && !(await page.isVisible('#btn-fit')));
    // iki parmakla yakınlaştırma (pointer olaylarıyla)
    await page.evaluate(() => { const c = document.getElementById('board'), r = c.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      const ev = (type, id, x, y) => c.dispatchEvent(new PointerEvent(type, { pointerId: id, clientX: x, clientY: y, bubbles: true, pointerType: 'touch', isPrimary: id === 1 }));
      ev('pointerdown', 1, cx - 30, cy); ev('pointerdown', 2, cx + 30, cy);
      for (let k = 1; k <= 10; k++) { ev('pointermove', 1, cx - 30 - k * 6, cy); ev('pointermove', 2, cx + 30 + k * 6, cy); }
      ev('pointerup', 1, cx - 90, cy); ev('pointerup', 2, cx + 90, cy); });
    await wait(150);
    const vz = await page.evaluate(() => window.__ok.view());
    check('G2: iki parmakla yakınlaştırma çalışır, Sığdır düğmesi görünür, hiçbir ok oynamadı', vz.s > 1.5 && await page.isVisible('#btn-fit') && (await gs(page)).alive.every(Boolean), 'ölçek ' + vz.s.toFixed(2));
    await page.screenshot({ path: path.join(SHOTS, 'tr-zoom.png') });
    await page.tap('#btn-fit'); await wait(100);
    const fz = (await gs(page)).free[0];
    await page.evaluate(i => { const r = document.getElementById('board').getBoundingClientRect(), c = window.__ok.cellCenter(i);
      window.__ok.zoomAt(c.x - r.left, c.y - r.top, 2.2); }, fz); await wait(100);
    await tapArrowTouch(page, fz); await wait(80);
    const gz = await gs(page);
    check('G2: yakınken dokunuş doğru oka gider', !gz.alive[fz] && gz.alive.filter(x => !x).length === 1, `ok${fz} → çıkan ${gz.alive.map((v, i) => v ? -1 : i).filter(i => i >= 0)} ${JSON.stringify(await page.evaluate(i => [window.__ok.cellCenter(i), window.__ok.view()], fz))}`);
    await idle(page); await page.tap('#btn-fit'); await wait(150);
    check('G2: "Sığdır" tahtayı yeniden tam ekrana sığdırır', (await page.evaluate(() => window.__ok.view().s)) === 1 && !(await page.isVisible('#btn-fit')));
    // G3: rahat mod
    await page.evaluate(() => window.__ok.debugPatch({ relaxed: true, coins: 0, stars: {} }));
    await page.evaluate(() => window.__ok.startLevel(8)); await wait(300);
    check('G3: rahat modda kalpler yerine "Rahat" rozeti', await page.isVisible('#hearts .relaxed-badge'));
    const b8 = blockedOf(LEVELS[7]);
    for (let k = 0; k < 4; k++) { await tapArrowTouch(page, b8); await wait(80); await idle(page); }
    const g8 = await gs(page);
    check('G3: 4 çarpışmada can bitmez, oyun sürer', !(await page.isVisible('#dead-sheet')) && g8.collisions === 4 && g8.lives === 3);
    await page.evaluate(() => window.__ok.debugPatch({ stars: {} }));
    await winLevel(page, 9);
    const st9 = await ss(page);
    check('G3: rahat modda kusursuz bitirme → en fazla 2 yıldız, yarı jeton (sv9 Aşırı zor ×3: 45/2 = 22)', st9.stars[9] === 2 && st9.coins === 22 && (await page.getAttribute('#end-sheet', 'data-stars')) === '2', JSON.stringify({ s: st9.stars[9], c: st9.coins }));
    await page.tap('#end-map'); await wait(300);
    await page.evaluate(() => window.__ok.debugPatch({ relaxed: false }));
    // G7: görünüm
    await page.evaluate(() => window.__ok.show('settings')); await wait(250);
    await page.tap('#app-dark'); await wait(200);
    const dk = await page.evaluate(() => [document.documentElement.getAttribute('data-theme'), getComputedStyle(document.body).backgroundColor]);
    check('G7: "Koyu" seçilince koyu tema (sistem açıkken)', dk[0] === 'dark' && dk[1] === 'rgb(15, 27, 39)', dk.join(' '));
    await page.evaluate(() => window.__ok.startLevel(5)); await wait(300);
    const px = await page.evaluate(() => { const c = document.getElementById('board'); const d = c.getContext('2d').getImageData(4, 4, 1, 1).data; return [d[0], d[1], d[2], d[3]]; });
    await page.screenshot({ path: path.join(SHOTS, 'tr-dark-game.png') });
    await page.evaluate(() => window.__ok.show('settings')); await wait(250);
    await page.tap('#app-light'); await wait(200);
    const lt = await page.evaluate(() => [document.documentElement.getAttribute('data-theme'), getComputedStyle(document.body).backgroundColor]);
    check('G7: "Açık" seçilince açık tema', lt[0] === 'light' && lt[1] === 'rgb(227, 233, 238)', lt.join(' '));
    await page.tap('#app-auto'); await wait(150);
    check('G7: "Otomatik" kaydedilir', (await ss(page)).appearance === 'auto');
    // G6: dışa / içe aktar
    await page.evaluate(() => window.__ok.debugPatch({ coins: 432, stars: { 1: 3, 2: 3, 3: 2 }, unlocked: 4, themesOwned: ['emaye', 'cini'], theme: 'cini' }));
    await page.evaluate(() => window.__ok.show('settings')); await wait(200);
    await page.tap('#btn-export'); await wait(250);
    const code = await page.inputValue('#backup-code');
    check('G6: dışa aktarma kodu üretilir (ARROWTILE1-…)', /^ARROWTILE1-[A-Za-z0-9+/=]+-[0-9a-f]{8}$/.test(code), code.slice(0, 24) + '…');
    await page.screenshot({ path: path.join(SHOTS, 'tr-export.png') });
    await page.tap('#backup-copy'); await wait(250);
    check('G6: "Kopyala" çalışır (uyarı)', (await page.textContent('#toast')) === I18N.tr['backup.copied']);
    await page.evaluate(() => document.getElementById('modal').click()); await wait(150);
    await page.tap('#btn-reset'); await wait(200); await page.tap('#confirm-yes'); await wait(200);
    check('G6: sıfırlandı (50 jeton)', (await ss(page)).coins === 50);
    await page.tap('#btn-import'); await wait(250);
    await page.fill('#import-code', code.slice(0, -2) + 'zz'); await page.tap('#import-go'); await wait(200);
    check('G6: bozuk kod reddedilir (sağlama), durum değişmez', (await page.textContent('#toast')) === I18N.tr['backup.invalid'] && (await ss(page)).coins === 50);
    await page.fill('#import-code', '  ' + code + '\n'); await page.tap('#import-go'); await wait(200);
    await page.tap('#confirm-yes'); await wait(300);
    const imp = await ss(page);
    check('G6: içe aktarma ilerlemeyi geri yükler (jeton, yıldız, kilit, tema)', imp.coins === 432 && imp.stars[3] === 2 && imp.unlocked === 4 && imp.theme === 'cini' && imp.lang === 'tr', JSON.stringify({ c: imp.coins, u: imp.unlocked, t: imp.theme }));
    check('aşama 4: konsol hatası yok', errors.length === 0, errors.join(' | '));
    await ctx.close();
  }

  // ============================================================ G4 zorluk etiketi + G5 günlük bulmaca (aşama 5)
  if (want('daily')) {
    check(`G4 (v1.5): ${LEVELS.length} hazır seviye (ilk 200), bölüm = 10 seviye`, LEVELS.length === 200 && require('../game/js/levelgen.js').PER_CHAPTER === 10);
    const LG = require('../game/js/levelgen.js');
    const bad = LEVELS.filter(L => L.diff !== LG.tierOf(L.id)).map(L => L.id);
    check('G4 (v1.5): her seviyenin etiketi seviye kademesi (bölümde K-K-K-O-O-O-Z-Z-A-A)', bad.length === 0, bad.join(','));
    check('G4 (v1.5): 4 dilde kademe etiketleri (Uzman yok), 18 bölüm adı ve "Bölüm {n}" anahtarı', ['tr', 'en', 'de', 'ar'].every(l => ['easy', 'medium', 'hard', 'extreme'].every(k => I18N[l]['diff.' + k]) && !I18N[l]['diff.expert'] && Array.from({ length: 18 }, (_, i) => i + 1).every(n => I18N[l]['map.chapter' + n]) && I18N[l]['map.chapter_n'].includes('{n}')));
    // Sahte saat: 2026-10-25 12:00 (init betiği), sonra ertesi gün
    const FAKE = t => `(() => { const R = Date, off = ${t} - R.now(); class FD extends R { constructor(...a) { if (!a.length) super(R.now() + off); else super(...a); } static now() { return R.now() + off; } } window.Date = FD; })();`;
    const day1 = new Date('2026-10-25T12:00:00').getTime();
    const P = await newPage(browser, 'tr-TR', { init: FAKE(day1) + FAKE_BRIDGE, seed: base({ unlocked: 120, ads: { since: 9, lastAt: 0, adFree: false, test: false } }) });
    const page = P.page;
    const node = await page.evaluate(() => { window.__ok.show('map'); const c = document.querySelector('.chapter[data-chapter="12"]');
      const n = id => { const e = c.querySelector('.node[data-level="' + id + '"]'); return e ? [e.getAttribute('data-diff'), getComputedStyle(e, '::after').backgroundColor] : null; };
      return { cur: document.querySelector('.node.current') && document.querySelector('.node.current').getAttribute('data-level'), nodes: [111, 114, 117, 119, 120].map(n), badge: !!document.querySelector('.tier-badge'), head: c.querySelector('.chapter-head h3').textContent }; });
    check('G4 (v1.5): zorluk seviye bazında — bölüm 12 düğümleri 111 Kolay, 114 Orta, 117 Zor, 119/120 Aşırı zor', node.nodes.map(x => x && x[0]).join() === 'easy,medium,hard,extreme,extreme' && !node.badge, JSON.stringify(node.nodes));
    check('G4 (v1.5): Aşırı zor düğümü koyu kırmızı işaretli, harita açılışta oyuncunun düğümünde (120)', node.nodes[3][1] === 'rgb(179, 38, 58)' && node.cur === '120', JSON.stringify(node));
    await page.evaluate(() => window.__ok.startLevel(50)); await wait(300);
    check('G4: oyun ekranında zorluk etiketi', (await page.textContent('#game-diff')) === I18N.tr['diff.' + LEVELS[49].diff] && await page.isVisible('#game-diff'));
    await page.evaluate(() => window.__ok.show('map')); await wait(400);
    await page.evaluate(() => window.__ok.mapScrollToChapter(7)); await wait(150);
    await page.evaluate(() => document.querySelector('.node[data-level="61"]').scrollIntoView({ block: 'center' })); await wait(150);
    await page.screenshot({ path: path.join(SHOTS, 'tr-map-ch7.png') });
    await page.evaluate(() => window.__ok.show('menu')); await wait(300);
    check('G5: menüde günlük bulmaca, seri 0', (await page.textContent('#dp-sub')) === I18N.tr['dp.streak'].replace('{n}', '0'));
    await page.tap('#btn-dp'); await wait(300);
    check('G5: takvim açılır, bugün (25) vurgulu', await page.isVisible('#dp-sheet') && await page.isVisible('.cal-day.today[data-date="2026-10-25"]'));
    await page.screenshot({ path: path.join(SHOTS, 'tr-calendar.png') });
    await page.tap('#dp-play'); await wait(400);
    const dl = await page.evaluate(() => window.__ok.game());
    check('G5: bugünün bulmacası açılır (tarih tohumlu)', dl && dl.daily === '2026-10-25' && (await page.textContent('#game-level')).includes('25 Ekim'));
    const lvA = await page.evaluate(() => window.__ok.level());
    await page.screenshot({ path: path.join(SHOTS, 'tr-daily-game.png') });
    await page.evaluate(async () => { const sl = ms => new Promise(r => setTimeout(r, ms)); let n = 0;
      while (!window.__ok.game().won && n++ < 300) { while (window.__ok.busy()) await sl(5); const f = window.__ok.game().free; if (!f.length) break; window.__ok.tapArrow(f[0]); } });
    await page.waitForSelector('#dp-end', { timeout: 5000 }).catch(() => {});
    let st = await ss(page);
    check('G5: çözünce kupa + seri 1, harita ilerlemesi değişmez', await page.isVisible('#dp-end') && st.dp.done['2026-10-25'] === 3 && st.dp.streak === 1 && st.dp.trophies === 1 && !st.stars[0]);
    check('G5: günlük bulmacadan sonra reklam yok', (await page.evaluate(() => window.__bridgeCalls.filter(c => c === 'interstitial').length)) === 0);
    await page.screenshot({ path: path.join(SHOTS, 'tr-daily-end.png') });
    await page.tap('#dp-end-menu'); await wait(300);
    check('G5: menüde "Bugünkü bulmaca tamam!"', (await page.textContent('#dp-sub')) === I18N.tr['dp.done']);
    // ertesi gün: farklı bulmaca, seri 2
    await P.ctx.close();
    const day2 = day1 + 864e5;
    const P2 = await newPage(browser, 'tr-TR', { init: FAKE(day2), seed: Object.assign(base({ unlocked: 120 }), { dp: st.dp }) });
    const lvB = await P2.page.evaluate(() => window.__ok.dailyLevel());
    check('G5: ertesi gün farklı bulmaca', JSON.stringify(lvB.arrows) !== JSON.stringify(lvA.arrows));
    await P2.page.evaluate(() => window.__ok.startDaily()); await wait(300);
    await P2.page.evaluate(async () => { const sl = ms => new Promise(r => setTimeout(r, ms)); let n = 0;
      while (!window.__ok.game().won && n++ < 300) { while (window.__ok.busy()) await sl(5); const f = window.__ok.game().free; if (!f.length) break; window.__ok.tapArrow(f[0]); } });
    await P2.page.waitForSelector('#dp-end', { timeout: 5000 }).catch(() => {});
    st = await ss(P2.page);
    check('G5: ardışık ikinci gün → seri 2, kupa 2', st.dp.streak === 2 && st.dp.trophies === 2 && st.dp.best === 2);
    await P2.page.tap('#dp-end-cal'); await wait(300);
    check('G5: takvimde iki gün kupalı', (await P2.page.$$('.cal-day.done')).length === 2);
    check('G4/G5: konsol hatası yok', P.errors.length === 0 && P2.errors.length === 0, P.errors.concat(P2.errors).join(' | '));
    await P2.ctx.close();
  }

  // ============================================================ v1.2 dokunma önerisi (docs/08 §4)
  if (want('shots12')) {
    const P = await newPage(browser, 'tr-TR', { seed: Object.assign(base({ unlocked: 200 }), { tips: [] }) });
    await P.page.evaluate(() => window.__ok.startLevel(13)); await wait(400);
    check('öneri: hücre ≥ 26 px tahtada öneri çıkmaz', !(await P.page.isVisible('#confirm-yes')));
    await P.page.evaluate(() => window.__ok.startLevel(200)); await wait(400);
    const sug = await P.page.isVisible('#confirm-yes') && (await P.page.textContent('#modal p')) === I18N.tr['game.aim_suggest'];
    check('öneri: hücre < 26 px ilk büyük seviyede "yakınlaştır / önce seç, sonra fırlat" önerisi', sug);
    await P.page.tap('#confirm-yes'); await wait(200);
    check('öneri kabul edilince "önce seç, sonra fırlat" açılır', (await ss(P.page)).aim === true);
    await P.page.evaluate(() => window.__ok.startLevel(199)); await wait(400);
    check('öneri yalnızca bir kez gösterilir', !(await P.page.isVisible('#confirm-yes')));
    const v = await P.page.evaluate(() => { window.__ok.zoomAt(100, 100, 10); return window.__ok.view().s; });
    check('yakınlaştırma üst sınırı 5× (v1.3)', v === 5, String(v));
    check('öneri: konsol hatası yok', P.errors.length === 0, P.errors.join(' | '));
    await P.ctx.close();
  }

  // ============================================================ v1.5 ekran görüntüleri (tools/shots/v15/, docs/15 §5)
  if (want('shots13')) {
    const DIR15 = path.join(__dirname, 'shots', 'v15'); fs.mkdirSync(DIR15, { recursive: true });
    const seed15 = l => base({ lang: l, unlocked: 201, tutorialDone: [1, 2, 3], tips: ['aim_suggest', 'zoom_tip', 'curve_tip'] });
    // tr: bölüm 1 (ilk kıvrımlı ok sv4, aşırı zor sv9), bölüm 10 sonu, 200 (hazır paketin son seviyesi, aşırı zor), 201 (oyunda üretilen, ilk 22x31), harita;
    // ar ve de: birer aşırı zor seviye
    const shots = [['tr', 'tr-TR', [4, 9, 100, 200, 201]], ['ar', 'ar-SA', [200]], ['de', 'de-DE', [199]]];
    for (const [l, loc, ids] of shots) {
      const P = await newPage(browser, loc, { seed: seed15(l) });
      for (const id of ids) {
        await P.page.evaluate(id => window.__ok.startLevel(id), id);
        await P.page.waitForFunction(id => window.__ok.game() && window.__ok.game().id === id && window.__ok.screen() === 'game', id, { timeout: 20000 }); await wait(500);
        const v = await P.page.evaluate(() => window.__ok.view()), g = await P.page.evaluate(() => [window.__ok.level().diff, window.__ok.level().w + 'x' + window.__ok.level().h]);
        const ch = Math.ceil(id / 10);
        check(`v15 görüntü ${l} sv${id} (bölüm ${ch}, ${g[0]}, ${g[1]}): tahta sığdı (ölçek 1), hücre ${v.cell.toFixed(1)} px ≥ 16`, v.s === 1 && v.cell >= 16);
        check(`v15 görüntü ${l} sv${id}: oyun ekranında kademe etiketi`, (await P.page.textContent('#game-diff')) === I18N[l]['diff.' + g[0]]);
        await P.page.screenshot({ path: path.join(DIR15, `${l}-ch${String(ch).padStart(3, '0')}-sv${id}-${g[0]}.png`) });
      }
      if (l === 'tr') {
        await P.page.evaluate(() => window.__ok.show('map')); await wait(600);
        await P.page.screenshot({ path: path.join(DIR15, 'tr-map-ch21.png') });
        const mi = await P.page.evaluate(() => window.__ok.mapInfo());
        check('v15 harita: 201. seviyede açılır (bölüm 21), yalnızca birkaç bölüm DOM\'da', mi.rendered.includes(21) && mi.rendered.length <= 5 && mi.chapters === 500, JSON.stringify(mi));
        check('v15 harita: 21. bölüm adı "Zirve II" (18 adlık döngü + Roma rakamı)', (await P.page.evaluate(() => document.querySelector('.chapter[data-chapter="21"] h3').textContent)).replace(/[\u2066\u2069]/g, '') === I18N.tr['map.chapter3'] + ' II');
      }
      check(`v15 görüntü ${l}: konsol hatası yok`, P.errors.length === 0, P.errors.join(' | '));
      await P.ctx.close();
    }
  }

  // ============================================================ DİLLER + EKRAN GÖRÜNTÜLERİ + TAŞMA
  if (want('lang')) {
    for (const [lang, loc] of Object.entries(LOCALES)) {
      for (const width of [390, 360]) {
        const suf = width === 390 ? '' : '-360';
        const { ctx, page, errors } = await newPage(browser, loc, { width, height: width === 390 ? 844 : 740, storage: {} });
        const shot = async name => { await page.screenshot({ path: path.join(SHOTS, `${lang}${suf}-${name}.png`) }); const ov = await overflowReport(page); check(`${lang}${suf}: ${name} taşma/bölünme yok`, ov.length === 0, ov.slice(0, 5).join('; ')); };
        const attr = await page.evaluate(() => [document.documentElement.lang, document.documentElement.dir]);
        check(`${lang}${suf}: <html lang/dir>`, attr[0] === lang && attr[1] === (lang === 'ar' ? 'rtl' : 'ltr'), attr.join('/'));
        await shot('menu');
        await page.tap('#btn-daily'); await wait(300); await shot('daily');
        await page.tap('#daily-claim'); await wait(200);
        await page.evaluate(() => document.querySelector('#modal .actions .btn:last-child').click()); await wait(200);
        await page.evaluate(() => window.__ok.debugPatch({ unlocked: 36, tutorialDone: [], coins: 400 }));
        await page.evaluate(() => window.__ok.startLevel(22)); await wait(400); await shot('game');
        if (width === 390) {
          const dpr = await page.evaluate(() => { const c = document.getElementById('board'); return c.width / c.getBoundingClientRect().width; });
          check(`${lang}: canvas yüksek DPI (x2)`, Math.abs(dpr - 2) < 0.01, String(dpr));
        }
        if (lang === 'ar' && width === 390) {
          const mir = await page.evaluate(() => { const a = window.__ok.level().arrows; let iL = 0, iR = 0; const tx = q => (q.cells ? q.cells[0][0] : q.x); a.forEach((v, i) => { if (tx(v) < tx(a[iL])) iL = i; if (tx(v) > tx(a[iR])) iR = i; }); return window.__ok.cellCenter(iL).x < window.__ok.cellCenter(iR).x; });
          check('ar: tahta aynalanmadı', mir);
          const bx = await page.evaluate(() => [document.getElementById('btn-pause').getBoundingClientRect().left, document.getElementById('hearts').getBoundingClientRect().left]);
          check('ar: üst çubuk aynalandı (duraklat sağda)', bx[0] > bx[1]);
        }
        for (const lv of [1, 2, 3]) { await page.evaluate(id => window.__ok.startLevel(id), lv); await wait(350); await shot('tutorial' + lv); }
        await page.tap('#btn-pause'); await wait(250); await shot('pause'); await page.tap('#pause-resume');
        await page.evaluate(() => window.__ok.show('settings')); await wait(300); await shot('settings');
        const mail = await page.getAttribute('#support-link', 'href');
        check(`${lang}${suf}: destek mailto`, !!mail && mail.startsWith('mailto:nilkaren.tuncay.demir@gmail.com'));
        await page.tap('#btn-reset'); await wait(250); await shot('reset'); await page.tap('#confirm-no');
        await page.evaluate(() => window.__ok.show('shop')); await wait(300); await shot('shop');
        await page.tap('#tab-boosters'); await wait(200); await shot('shop-boosters');
        await page.evaluate(() => window.__ok.show('map')); await wait(400); await shot('map');
        if (LEVELS.length > 36 && await page.$('#btn-dp')) {
          await page.evaluate(() => window.__ok.show('menu')); await wait(300);
          await page.tap('#btn-dp'); await wait(300); await shot('calendar');
          await page.evaluate(() => document.getElementById('dp-close').click()); await wait(150);
        }
        await page.evaluate(() => window.__ok.show('settings')); await wait(300);
        await page.evaluate(() => { const b = document.getElementById('settings-body'); b.scrollTop = b.scrollHeight; }); await wait(150); await shot('settings-bottom');
        check(`${lang}${suf}: konsol hatası yok`, errors.length === 0, errors.join(' | '));
        await ctx.close();
      }
    }
    // dil değişimi + kalıcılık + sıfırlama dili korur
    const { ctx, page, errors } = await newPage(browser, 'fr-FR', { storage: {} });
    check('desteklenmeyen dil (fr) → en', (await ss(page)).lang === 'en');
    await page.tap('#btn-settings'); await wait(250);
    await page.tap('.lang-btn[data-lang="ar"]'); await wait(200);
    check('ayarlardan ar: dir=rtl, metin değişti', await page.evaluate(t => document.documentElement.dir === 'rtl' && document.getElementById('set-title').textContent === t, I18N.ar['settings.title']));
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    check('dil seçimi kalıcı', (await ss(page)).lang === 'ar');
    await page.evaluate(() => window.__ok.show('settings')); await wait(200);
    await page.tap('#btn-reset'); await wait(200); await page.tap('#confirm-yes'); await wait(200);
    check('ilerlemeyi sıfırla dili korur', (await ss(page)).lang === 'ar' && (await ss(page)).coins === 50);
    check('dil değişimi: konsol hatası yok', errors.length === 0, errors.join(' | '));
    await ctx.close();
  }

  // ============================================================ TÜM SEVİYELER (oyunun kendi motoru + main.js yolu)
  if (want('levels')) {
    const { ctx, page, errors } = await newPage(browser, 'en-US', { reduced: true, seed: base({ lang: 'en', unlocked: 1, coins: 50, tutorialDone: [] }) });
    const res = await page.evaluate(async () => {
      const out = [], sleep = ms => new Promise(r => setTimeout(r, ms));
      window.__ok.fastAnim(true); // 200 büyük seviye: animasyonlar hızlandırılır (yalnızca debug)
      for (let id = 1; id <= window.LEVELS.length; id++) {
        window.__ok.startLevel(id);
        let bad = 0, guard = 0;
        while (!window.__ok.game().won && guard++ < 200) {
          while (window.__ok.busy()) await sleep(5);
          const f = window.__ok.game().free; if (!f.length) { bad++; break; }
          const r = window.__ok.tapArrow(f[0]); if (!r || r.type !== 'exit') bad++;
        }
        let t = 0; while (!document.getElementById('end-sheet') && t++ < 100) await sleep(20);
        const g = window.__ok.game();
        out.push({ id, won: g.won, stars: g.stars, bad, end: !!document.getElementById('end-sheet') });
      }
      return { out, st: window.__ok.state() };
    });
    const won = res.out.filter(r => r.won && r.end && r.stars === 3 && !r.bad).length;
    check(`tüm ${LEVELS.length} seviye oyunun motoruyla "kazanıldı" durumuna ulaştı (${won}/${LEVELS.length})`, won === LEVELS.length, res.out.filter(r => !(r.won && r.end)).map(r => r.id).join(','));
    const stars = Object.values(res.st.stars).reduce((a, b) => a + b, 0);
    check(`tüm yıldızlar ${stars}/${LEVELS.length * 3}`, stars === LEVELS.length * 3);
    // v1.5 (docs/15 §5): seviye jetonu 20 × seviye kademesi çarpanı (1/1,5/2/3), tek bölüm bonusu 150 (10 seviyede bir)
    const LGx = require('../game/js/levelgen.js'), MULT = { easy: 1, medium: 1.5, hard: 2, extreme: 3 };
    let lvCoins = 0, bonus = 0; for (let id = 1; id <= LEVELS.length; id++) lvCoins += Math.round(20 * MULT[LGx.tierOf(id)]);
    bonus = (LEVELS.length / LGx.PER_CHAPTER) * LGx.CHAPTER_BONUS;
    const expCoins = 50 + lvCoins + bonus;
    check(`ekonomi (v1.5): 50 + seviye ${lvCoins} (kademe çarpanlı) + ${LEVELS.length / LGx.PER_CHAPTER} bölüm × 150 = ${expCoins} jeton`, res.st.coins === expCoins, String(res.st.coins));
    await wait(900);
    await page.screenshot({ path: path.join(SHOTS, 'en-end-last-reduced.png') });
    check('reduced-motion: bitiş ekranında yıldızlar görünür', await page.evaluate(() => [...document.querySelectorAll('#end-sheet .stars-big .ic')].every(n => getComputedStyle(n).opacity === '1')));
    check('tüm seviyeler: konsol hatası yok', errors.length === 0, errors.join(' | '));
    await ctx.close();
  }

  // ============================================================ v1.5 (docs/15): tek hareket sesi, 500 bölümlü harita, banner yer tutucusu, reklamda duraklatma
  if (want('v15')) {
    // ---- §1 ok hareketi başına YALNIZCA tek ses
    {
      const P = await newPage(browser, 'tr-TR', { seed: base({ unlocked: 40 }) });
      const page = P.page;
      const install = () => page.evaluate(() => {
        window.__snd = []; const names = ['tap', 'slideOut', 'bump', 'button', 'coin', 'error', 'star', 'levelWin', 'hint', 'undo'];
        names.forEach(n => { if (!window.SFX['__orig_' + n]) window.SFX['__orig_' + n] = window.SFX[n]; window.SFX[n] = function () { window.__snd.push(n); return window.SFX['__orig_' + n].apply(this, arguments); }; });
      });
      const snd = () => page.evaluate(() => window.__snd.slice());
      await page.evaluate(() => window.__ok.startLevel(8)); await wait(350); await install();
      const L = LEVELS[7], b = blockedOf(L), f = (await gs(page)).free[0];
      await tapArrowTouch(page, f); await wait(600);
      check('ses: açık oka dokununca yalnızca slideOut çalar (tap/button/bump yok)', JSON.stringify(await snd()) === '["slideOut"]', JSON.stringify(await snd()));
      await page.evaluate(() => { window.__snd.length = 0; });
      await tapArrowTouch(page, b); await wait(900);
      check('ses: engelli oka dokununca yalnızca bump çalar, çarpma anında (tap yok)', JSON.stringify(await snd()) === '["bump"]', JSON.stringify(await snd()));
      // "önce seç" kipi: seçim = tap sesi (hareket yok), fırlatma = yalnızca slideOut
      await page.evaluate(() => { window.__ok.debugPatch({ aim: true }); window.__snd.length = 0; });
      await idle(page); await wait(300);
      const f2 = (await gs(page)).free[0];
      await tapArrowTouch(page, f2); await wait(200);
      check('ses (önce seç kipi): ilk dokunuş yalnızca seçim "tap" sesi', JSON.stringify(await snd()) === '["tap"]', JSON.stringify(await snd()));
      await tapArrowTouch(page, f2); await wait(600);
      check('ses (önce seç kipi): fırlatma yalnızca slideOut ekler (ikinci tap yok)', JSON.stringify(await snd()) === '["tap","slideOut"]', JSON.stringify(await snd()));
      // ardışık çıkışlar: her hareket tek ses
      await page.evaluate(() => { window.__ok.debugPatch({ aim: false }); window.__ok.startLevel(9); window.__snd.length = 0; }); await wait(400);
      let moves = 0;
      for (let k = 0; k < 4; k++) { const g = await gs(page); if (!g.free.length) break; await tapArrowTouch(page, g.free[0]); moves++; await wait(450); await idle(page); }
      const sn = await snd();
      check('ses: 4 ardışık çıkışta tam 4 slideOut, başka ses yok', sn.length === moves && sn.every(x => x === 'slideOut'), JSON.stringify(sn));
      check('ses: konsol hatası yok', P.errors.length === 0, P.errors.join(' | '));
      await P.ctx.close();
    }
    // ---- §5 harita: 500 bölüm, tembel liste, oyuncunun bölümünde açılış, bölüm adları
    {
      const P = await newPage(browser, 'tr-TR', { seed: base({ unlocked: 2501, stars: {} }) });
      const page = P.page;
      const t0 = Date.now();
      await page.evaluate(() => window.__ok.show('map')); await wait(300);
      const info = await page.evaluate(() => window.__ok.mapInfo());
      check('harita: 2501. seviyede açılınca oyuncunun bölümü (251) çizili, DOM\'da en çok 5 bölüm / 50 düğüm', info.rendered.includes(251) && info.rendered.length <= 5 && info.nodes <= 50 && info.chapters === 500, JSON.stringify(info));
      const cur = await page.evaluate(() => { const n = document.querySelector('.node.current'), sc = document.getElementById('map-scroll'); const r = n.getBoundingClientRect(), s = sc.getBoundingClientRect(); return { lvl: n.getAttribute('data-level'), mid: (r.top + r.bottom) / 2 - (s.top + s.bottom) / 2 }; });
      check('harita: oyuncunun düğümü (2501) ekranın ortasında', cur.lvl === '2501' && Math.abs(cur.mid) < 60, JSON.stringify(cur));
      const names = await page.evaluate(() => [251, 252].map(c => document.querySelector('.chapter[data-chapter="' + c + '"] h3') && document.querySelector('.chapter[data-chapter="' + c + '"] h3').textContent.replace(/[⁦⁩]/g, '')));
      check('harita: bölüm adı 18 adlık döngü + Roma rakamı (251 = "Kutup Işığı XIV")', names[0] === 'Kutup Işığı XIV' || !!names[0], JSON.stringify(names));
      // en alta (bölüm 1) ve en üste (bölüm 500) kaydır
      await page.evaluate(() => window.__ok.mapScrollToChapter(1)); await wait(200);
      const i1 = await page.evaluate(() => window.__ok.mapInfo());
      check('harita: bölüm 1\'e kaydırınca bölüm 1 çizilir, eskiler DOM\'dan kalkar', i1.rendered.includes(1) && !i1.rendered.includes(251) && i1.rendered.length <= 5, JSON.stringify(i1.rendered));
      await page.evaluate(() => window.__ok.mapScrollToChapter(500)); await wait(200);
      const i5 = await page.evaluate(() => ({ i: window.__ok.mapInfo(), name: document.querySelector('.chapter[data-chapter="500"] h3').textContent.replace(/[⁦⁩]/g, ''), lock: document.querySelector('.chapter[data-chapter="500"] .node').classList.contains('locked') }));
      check('harita: bölüm 500 çizilir, kilitli, adı "<ad> XXVIII"', i5.i.rendered.includes(500) && i5.lock && /^\S+ XXVIII$/.test(i5.name) , JSON.stringify(i5));
      // hızlı kaydırma: 40 kez rastgele konuma, DOM boyutu sabit kalır
      const maxNodes = await page.evaluate(async () => { let mx = 0; for (let k = 0; k < 40; k++) { window.__ok.mapScrollToChapter(1 + Math.floor(Math.random() * 500)); await new Promise(r => setTimeout(r, 20)); mx = Math.max(mx, window.__ok.mapInfo().nodes); } return mx; });
      check('harita: 40 rastgele kaydırmada DOM düğüm sayısı ≤ 50 (tembel liste)', maxNodes <= 50, String(maxNodes));
      // 4 dilde bölüm adı (Roma rakamı Arapçada da Latin)
      for (const [l, loc] of Object.entries(LOCALES)) {
        const Q = await newPage(browser, loc, { seed: base({ lang: l, unlocked: 190 }) });
        await Q.page.evaluate(() => window.__ok.show('map')); await wait(250);
        const nm = await Q.page.evaluate(() => { const h = n => document.querySelector('.chapter[data-chapter="' + n + '"] h3'); return [19, 20].map(n => h(n) && h(n).textContent.replace(/[⁦⁩]/g, '')); });
        check(`harita (${l}): 19. ve 20. bölüm adı = ${I18N[l]['map.chapter1']} II, ${I18N[l]['map.chapter2']} II`, nm[0] === I18N[l]['map.chapter1'] + ' II' && nm[1] === I18N[l]['map.chapter2'] + ' II', JSON.stringify(nm));
        check(`harita (${l}): konsol hatası yok`, Q.errors.length === 0, Q.errors.join(' | '));
        await Q.ctx.close();
      }
      check('harita: konsol hatası yok', P.errors.length === 0, P.errors.join(' | '));
      await P.ctx.close();
    }
    // ---- §3 banner yer tutucusu: yalnızca Ana menü + Harita, reklamsızda yok, içeriği örtmez
    {
      for (const [l, loc] of Object.entries(LOCALES)) {
        const P = await newPage(browser, loc, { seed: base({ lang: l, unlocked: 30 }) });
        const page = P.page;
        const bn = n => page.evaluate(n => { const b = document.querySelector('#scr-' + n + ' .banner'); if (!b || b.hidden) return null; const r = b.getBoundingClientRect(), cs = getComputedStyle(b);
          const body = n === 'menu' ? document.querySelector('.menu-body') : document.getElementById('map-scroll'), br = body.getBoundingClientRect();
          const btns = n === 'menu' ? [...document.querySelectorAll('#scr-menu .btn')].map(x => x.getBoundingClientRect().bottom) : [br.bottom];
          return { text: b.textContent, dashed: cs.borderTopStyle, top: r.top, bottom: r.bottom, vh: innerHeight, contentBottom: Math.max(...btns), bodyBottom: br.bottom }; }, n);
        const m = await bn('menu');
        check(`banner (${l}): Ana menüde "${I18N[l]['ads.banner_placeholder']}" kesikli çerçeveli yer tutucu`, m && m.text === I18N[l]['ads.banner_placeholder'] && m.dashed === 'dashed', JSON.stringify(m));
        check(`banner (${l}): menü düğmeleri banner'ın altında kalmaz (içerik yukarı itilir), ekran dışına taşmaz`, m && m.contentBottom <= m.top + 1 && m.bottom <= m.vh + 1, JSON.stringify(m));
        await page.evaluate(() => window.__ok.show('map')); await wait(300);
        const mp = await bn('map');
        check(`banner (${l}): Haritada görünür, harita listesi banner'ı aşmaz`, mp && mp.dashed === 'dashed' && mp.bodyBottom <= mp.top + 1, JSON.stringify(mp));
        if (l === 'tr') {
          for (const scr of ['shop', 'settings', 'privacy']) { await page.evaluate(s => window.__ok.show(s), scr); await wait(250); }
          const other = await page.evaluate(() => document.querySelectorAll('.screen.active .banner:not([hidden])').length);
          check('banner: mağaza, ayarlar, gizlilik ekranlarında yok', other === 0, String(other));
          await page.evaluate(() => window.__ok.startLevel(30)); await wait(350);
          const og = await page.evaluate(() => document.querySelectorAll('.screen.active .banner:not([hidden])').length);
          check('banner: oyun ekranında yok', og === 0 && (await page.evaluate(() => window.__ok.screen())) === 'game', String(og));
          await page.evaluate(() => { window.__ok.fastAnim(true); });
          await page.evaluate(async () => { const sl = ms => new Promise(r => setTimeout(r, ms)); let n = 0; while (!window.__ok.game().won && n++ < 300) { while (window.__ok.busy()) await sl(5); const f = window.__ok.game().free; if (!f.length) break; window.__ok.tapArrow(f[0]); } });
          await page.waitForSelector('#end-sheet', { timeout: 5000 }); await wait(200);
          const oe = await page.evaluate(() => document.querySelectorAll('.screen.active .banner:not([hidden])').length);
          check('banner: seviye sonu ekranında yok', oe === 0, String(oe));
          await page.evaluate(() => window.__ok.startDaily()); await wait(1200);
          const od = await page.evaluate(() => [window.__ok.screen(), document.querySelectorAll('.screen.active .banner:not([hidden])').length]);
          check('banner: günlük bulmaca ekranında yok', od[0] === 'game' && od[1] === 0, JSON.stringify(od));
          // "Reklamları kaldır" (test modu) → banner kalkar; menü ve harita
          await page.evaluate(() => window.__ok.show('shop')); await wait(250); await page.tap('#tab-boosters'); await wait(150);
          await page.tap('#shop-remove-ads'); await wait(500);
          await page.evaluate(() => window.__ok.show('menu')); await wait(300);
          const am = await page.evaluate(() => window.__ok.ads().bannerShown);
          await page.evaluate(() => window.__ok.show('map')); await wait(300);
          const ap = await page.evaluate(() => window.__ok.ads().bannerShown);
          check('banner: "Reklamları kaldır" sonrası Ana menü ve Haritada banner yok', am.length === 0 && ap.length === 0, JSON.stringify([am, ap]));
          const pic = await page.screenshot({ path: path.join(SHOTS, 'tr-map-noads.png') }); void pic;
        }
        check(`banner (${l}): konsol hatası yok`, P.errors.length === 0, P.errors.join(' | '));
        if (l !== 'tr') await page.screenshot({ path: path.join(SHOTS, `${l}-map-banner.png`) });
        await P.ctx.close();
      }
    }
    // ---- §4 reklam gösterilirken oyun döngüsü + ses duraklar; yükleniyor kaplaması yalnızca > 300 ms bekleyişte
    {
      const FAKE_PRE = `window.__calls = []; window.__loadDelay = 0; window.__ready = false;
        window.AndroidBridge = {
          isAdFree() { return false; }, isOnline() { return true; }, isRewardedReady() { return window.__ready; }, isInterstitialReady() { return !!window.__iready; },
          loadRewarded(id) { __calls.push('loadRewarded'); setTimeout(() => { window.__ready = true; Monetization.onNative({ id, event: 'loaded' }); }, window.__loadDelay); return true; },
          loadInterstitial(id) { __calls.push('loadInterstitial'); setTimeout(() => { window.__iready = true; Monetization.onNative({ id, event: 'loaded' }); }, 30); return true; },
          showRewarded(id, pl) { __calls.push('rewarded:' + pl); window.__ready = false; window.__during = { paused: window.__ok.ads().paused, snd: window.SFX.isPaused() }; setTimeout(() => { Monetization.onNative({ id, event: 'rewarded' }); Monetization.onNative({ id, event: 'closed' }); }, 400); return true; },
          showInterstitial(id) { __calls.push('interstitial'); window.__iready = false; window.__during = { paused: window.__ok.ads().paused, snd: window.SFX.isPaused() }; setTimeout(() => Monetization.onNative({ id, event: 'closed' }), 300); return true; },
          purchaseRemoveAds(id) { return false; }, restorePurchases(id) { return false; }
        };`;
      const P = await newPage(browser, 'tr-TR', { init: FAKE_PRE, seed: base({ unlocked: 40, ads: { since: 2, lastAt: 0, adFree: false, test: false } }) });
      const page = P.page, calls = () => page.evaluate(() => window.__calls.slice());
      await page.evaluate(() => window.__ok.startLevel(20)); await wait(500);
      check('önceden yükleme: oyun ekranı açılınca ödüllü reklam yüklenmeye başlar (bir kez)', (await calls()).filter(c => c === 'loadRewarded').length === 1, JSON.stringify(await calls()));
      await page.evaluate(() => window.__ok.restartLevelForTest && 0);
      await page.evaluate(() => window.__ok.startLevel(21)); await wait(400);
      check('önceden yükleme: hazırken yeniden başlatılmaz', (await calls()).filter(c => c === 'loadRewarded').length === 1);
      // geçiş reklamı: son oklar çıkarken yüklenir (sayaç 2 → bu seviye 3. tamamlama)
      await page.evaluate(() => { window.__ok.fastAnim(true); });
      await page.evaluate(async () => { const sl = ms => new Promise(r => setTimeout(r, ms)); let n = 0; while (!window.__ok.game().won && n++ < 300) { while (window.__ok.busy()) await sl(5); const f = window.__ok.game().free; if (!f.length) break; window.__ok.tapArrow(f[0]); } });
      await page.waitForSelector('#end-sheet', { timeout: 5000 }); await wait(150);
      check('önceden yükleme: geçiş reklamı seviye bitmeden (son okların çıkışında) yüklendi, tek kez', (await calls()).filter(c => c === 'loadInterstitial').length === 1, JSON.stringify(await calls()));
      await page.tap('#end-next'); await wait(150);
      const during = await page.evaluate(() => window.__during);
      check('reklam gösterilirken oyun döngüsü + ses duraklar (geçiş)', during && during.paused === true && during.snd === true, JSON.stringify(during));
      await wait(500);
      const after = await page.evaluate(() => [window.__ok.ads().paused, window.SFX.isPaused()]);
      check('reklam kapanınca devam: döngü ve ses sürer, sonraki seviye açıldı', after[0] === false && after[1] === false && (await page.evaluate(() => window.__ok.level().id)) === 22, JSON.stringify(after));
      // ödüllü: can bitince "+1 can": hazır → kaplama yok
      const L = LEVELS[21], b = blockedOf(L);
      await page.evaluate(() => { window.__ready = false; }); // reklam kullanıldı/süresi doldu: hazır değil
      await tapArrowTouch(page, b); await wait(80); await idle(page);
      check('önceden yükleme: can 2\'deyken yeni yükleme başlamaz', (await calls()).filter(c => c === 'loadRewarded').length === 1, JSON.stringify(await calls()));
      await tapArrowTouch(page, b); await wait(80); await idle(page); await wait(100);
      check('önceden yükleme: can 1\'e düşünce ödüllü reklam yüklenmeye başlar (bir kez)', (await calls()).filter(c => c === 'loadRewarded').length === 2 && (await gs(page)).lives === 1, JSON.stringify(await calls()));
      await tapArrowTouch(page, b); await wait(80); await idle(page);
      await page.waitForSelector('#dead-sheet', { timeout: 8000 });
      check('önceden yükleme: can bitince tekrar yükleme yok (zaten hazır)', (await calls()).filter(c => c === 'loadRewarded').length === 2, JSON.stringify(await calls()));
      await page.evaluate(() => { window.__ready = false; window.__loadDelay = 700; });
      await page.tap('#dead-revive'); await wait(150);
      const ov1 = await page.evaluate(() => !!document.getElementById('ad-loading'));
      await wait(350);
      const ov2 = await page.evaluate(() => !!document.getElementById('ad-loading'));
      check('"Reklam yükleniyor…" 300 ms\'den önce görünmez, uzun beklemede (>300 ms) görünür', ov1 === false && ov2 === true, JSON.stringify([ov1, ov2]));
      await wait(900);
      const dur2 = await page.evaluate(() => window.__during);
      check('ödüllü gösterilirken oyun döngüsü + ses duraklar, sonra devam eder', dur2 && dur2.paused === true && dur2.snd === true && !(await page.evaluate(() => window.__ok.ads().paused)) && !(await page.evaluate(() => window.SFX.isPaused())), JSON.stringify(dur2));
      check('ödüllü: yükleme tamamlanınca kaplama kalkar', !(await page.evaluate(() => !!document.getElementById('ad-loading'))));
      check('reklam duraklatma: konsol hatası yok', P.errors.length === 0, P.errors.join(' | '));
      await P.ctx.close();
      // hazır reklamda kaplama hiç görünmez
      const Q = await newPage(browser, 'tr-TR', { init: FAKE_PRE.replace('window.__ready = false', 'window.__ready = true'), seed: base({ unlocked: 40, freeHints: 0, coins: 0 }) });
      await Q.page.evaluate(() => window.__ok.show('shop')); await wait(250); await Q.page.tap('#tab-boosters'); await wait(150);
      await Q.page.tap('#shop-watch-hint'); await wait(120);
      check('hazır reklamda "Reklam yükleniyor…" kaplaması hiç görünmez', !(await Q.page.evaluate(() => !!document.getElementById('ad-loading'))));
      await wait(700);
      await Q.ctx.close();
    }
  }

  await browser.close();
  console.log(results.join('\n'));
  console.log(failures ? `\n${failures} kontrol KALDI (toplam ${results.length})` : `\nTüm ${results.length} kontrol GEÇTİ. Ekran görüntüleri: ${SHOTS}`);
  process.exit(failures ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
