// Arrowtile — bağımsız QA testi (Test Sorumlusu). Kullanım: node tools/qa.js
// Geliştiricinin e2e.js / solver.js'ine bağlı DEĞİL: kendi çözücüsü, kendi tahta-algılaması (canvas piksellerinden) var.
'use strict';
const path = require('path');
const fs = require('fs');
const vm = require('vm');

function loadPlaywright() {
  for (const t of ['playwright', '/opt/npm-tools/node_modules/playwright']) { try { return require(t); } catch (e) {} }
  throw new Error('Playwright bulunamadı');
}
const { chromium } = loadPlaywright();
const ROOT = path.join(__dirname, '..');
// v1.1: hata ayıklama kancası yalnızca ?debug=1 ile var; bu kipte kayıt kum havuzu anahtarına yazılır (Store.KEY).
const FILE = 'file://' + path.join(ROOT, 'game', 'index.html');
const URL = FILE + '?debug=1';
const sctx = { window: {}, location: { search: '?debug=1' }, navigator: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game/js/storage.js'), 'utf8'), sctx);
const KEY = sctx.window.Store.KEY;
const lctx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game/js/levels.js'), 'utf8'), lctx);
const LEVELS = lctx.window.LEVELS;
const ictx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game/js/i18n.js'), 'utf8'), ictx);
const I18N = ictx.window.I18N;
const LOCALES = { tr: 'tr-TR', en: 'en-US', de: 'de-DE', ar: 'ar-SA' };
const ovIssues = {};
const wait = ms => new Promise(r => setTimeout(r, ms));

// ---------------------------------------------------------------- sonuçlar
const results = [];
let group = '';
function G(name) { group = name; console.log('\n== ' + name); }
function check(name, cond, extra) {
  results.push({ group, name, ok: !!cond, extra: extra || '' });
  console.log((cond ? 'GEÇTİ ' : 'KALDI ') + name + (extra ? '  [' + extra + ']' : ''));
}

// ---------------------------------------------------------------- bağımsız kural modeli
const D = { U: [0, -1], D: [0, 1], L: [-1, 0], R: [1, 0] };
const cells = a => a.cells || Array.from({ length: a.len }, (_, i) => [a.x + D[a.dir][0] * i, a.y + D[a.dir][1] * i]); // v1.3: kıvrımlı biçim
const tailX = a => cells(a)[0][0], tailY = a => cells(a)[0][1], headC = a => cells(a)[cells(a).length - 1];
function grid(L, alive) { const g = new Array(L.w * L.h).fill(-1); L.arrows.forEach((a, k) => { if (alive[k]) cells(a).forEach(([x, y]) => g[y * L.w + x] = k); }); return g; }
function obstacle(L, alive, i) { // {free, blocker} | null
  const a = L.arrows[i], d = D[a.dir], c = cells(a), h = c[c.length - 1], g = grid(L, alive);
  let x = h[0] + d[0], y = h[1] + d[1], k = 0;
  while (x >= 0 && y >= 0 && x < L.w && y < L.h) { if (g[y * L.w + x] !== -1) return { free: k, blocker: g[y * L.w + x] }; x += d[0]; y += d[1]; k++; }
  return null;
}
const freeOf = (L, alive) => L.arrows.map((_, i) => i).filter(i => alive[i] && !obstacle(L, alive, i));
function solveOrder(L, alive) { alive = alive ? alive.slice() : L.arrows.map(() => true); const o = []; for (;;) { const f = freeOf(L, alive); if (!f.length) break; alive[f[0]] = false; o.push(f[0]); } return o; }

// ---------------------------------------------------------------- tarayıcı yardımcıları
const INIT = `(() => {
  try { const fk = sessionStorage.getItem('qa.fakeNow'); if (fk) { const R = Date, off = Number(fk) - R.now();
    class FD extends R { constructor(...a) { if (!a.length) super(R.now() + off); else super(...a); } static now() { return R.now() + off; } }
    window.Date = FD; } } catch (e) {}
  window.__qa = {
    // Tahta yerleşimini canvas PİKSELLERİNDEN bul (oyunun iç değişkenlerinden değil)
    layout(w, h) {
      const cv = document.getElementById('board'), r = cv.getBoundingClientRect(), dpr = cv.width / r.width;
      const im = cv.getContext('2d').getImageData(0, 0, cv.width, cv.height).data;
      const W = cv.width, H = cv.height, colC = new Array(W).fill(0), rowC = new Array(H).fill(0);
      for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const p = (y * W + x) * 4;
        if (Math.abs(im[p] - 246) <= 2 && Math.abs(im[p + 1] - 248) <= 2 && Math.abs(im[p + 2] - 250) <= 2 && im[p + 3] > 250) { colC[x]++; rowC[y]++; } }
      const xs = colC.map((c, i) => c > 6 ? i : -1).filter(i => i >= 0), ys = rowC.map((c, i) => c > 6 ? i : -1).filter(i => i >= 0);
      if (!xs.length) return null;
      const pd = w >= 21 ? 0.1 : 0.3; // v1.3: geniş tahtada tepsi dolgusu 0,1 hücre (theme.js boardPadFor)
      const bw = xs[xs.length - 1] - xs[0] + 1, cellD = bw / (w + 2 * pd);
      return { left: r.left, top: r.top, dpr, cell: cellD / dpr, ox: (xs[0] + pd * cellD) / dpr, oy: (ys[0] + pd * cellD) / dpr,
        trayL: xs[0] / dpr, trayR: (xs[xs.length - 1] + 1) / dpr, trayT: ys[0] / dpr, trayB: (ys[ys.length - 1] + 1) / dpr, cw: r.width, ch: r.height };
    },
    present(lay, cx, cy) { // hücre merkezinde hücre-çukuru rengi dışında bir şey var mı (ok gövdesi/şevron)
      const cv = document.getElementById('board'), ctx = cv.getContext('2d');
      const x = Math.round((lay.ox + (cx + 0.5) * lay.cell) * lay.dpr), y = Math.round((lay.oy + (cy + 0.5) * lay.cell) * lay.dpr);
      const p = ctx.getImageData(x, y, 1, 1).data;
      // v1.2: tahta tek düz yüzey (hücre çukuru yok); boş hücre merkezi tahta rengindedir (246,248,250)
      return Math.abs(p[0] - 246) + Math.abs(p[1] - 248) + Math.abs(p[2] - 250) > 30;
    },
    color(lay, cx, cy, dx) { const cv = document.getElementById('board');
      const x = Math.round((lay.ox + (cx + 0.5 + (dx || 0)) * lay.cell) * lay.dpr), y = Math.round((lay.oy + (cy + 0.5) * lay.cell) * lay.dpr);
      return Array.from(cv.getContext('2d').getImageData(x, y, 1, 1).data.slice(0, 3)); },
    snap() { const cv = document.getElementById('board'); return cv.getContext('2d').getImageData(0, 0, cv.width, cv.height).data; },
    // ms boyunca her karede verilen hücrelerin dolu olup olmadığını kaydet
    sample(lay, list, ms) { return new Promise(res => { const ever = list.map(() => false), t0 = performance.now();
      (function f() { list.forEach((c, i) => { if (__qa.present(lay, c[0], c[1])) ever[i] = true; });
        if (performance.now() - t0 < ms) requestAnimationFrame(f); else res(ever); })(); }); },
    toasts: [],
  };
  document.addEventListener('DOMContentLoaded', () => { try { new MutationObserver(() => { const t = document.getElementById('toast'); if (t && t.textContent) __qa.toasts.push(t.textContent); })
    .observe(document.getElementById('toast'), { childList: true, characterData: true, subtree: true }); } catch (e) {} });
})();`;

async function newPage(browser, o = {}) {
  const ctx = await browser.newContext({
    viewport: { width: o.width || 390, height: o.height || 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
    locale: o.locale || 'tr-TR', colorScheme: 'light', reducedMotion: 'no-preference'
  });
  const requests = [], errors = [];
  ctx.on('request', r => requests.push(r.url()));
  if (o.pre) await ctx.addInitScript(o.pre);
  await ctx.addInitScript(INIT);
  const page = await ctx.newPage();
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));
  if (o.seed !== undefined || o.fakeDate) {
    await page.goto(URL);
    await page.evaluate(([k, s, fd]) => { if (s !== undefined) localStorage.setItem(k, typeof s === 'string' ? s : JSON.stringify(s)); if (fd) sessionStorage.setItem('qa.fakeNow', String(new Date(fd).getTime())); }, [KEY, o.seed, o.fakeDate]);
  }
  await page.goto(URL);
  await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu', null, { timeout: 5000 }).catch(() => {});
  await wait(300);
  return { ctx, page, errors, requests };
}
async function setFakeDate(page, iso) {
  // v1.1 düzenek sağlamlaştırması: yeniden yüklemeden sonra sahte saatin gerçekten devrede olduğunu doğrula
  // (yük altında init betiği bazı yüklemelerde devreye girmiyordu; o durumda tekrar yükle)
  const target = new Date(iso).getTime();
  await page.evaluate(t => sessionStorage.setItem('qa.fakeNow', String(t)), target);
  for (let k = 0; k < 4; k++) {
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu'); await wait(250);
    const now = await page.evaluate(() => Date.now());
    if (Math.abs(now - target) < 120000) break;
  }
}
const base = (extra = {}) => Object.assign({ lang: 'tr', coins: 50, freeHints: 2, stars: {}, unlocked: 36, themesOwned: ['emaye'], theme: 'emaye', daily: { lastDate: null, streakDay: 0 }, tutorialDone: [1, 2, 3], chapterBonus: [] }, extra);

async function startLevel(page, id) { // haritadan dokunarak seviye başlat
  await page.evaluate(() => window.__ok.show('map')); await wait(350);
  await page.evaluate(id => document.querySelector('.node[data-level="' + id + '"]').scrollIntoView({ block: 'center' }), id);
  await wait(100);
  await page.tap('.node[data-level="' + id + '"]');
  await page.waitForFunction(id => window.__ok.screen() === 'game' && window.__ok.level().id === id, id);
  await wait(320);
  return lay(page, id);
}
async function lay(page, id) { const L = LEVELS[id - 1]; return page.evaluate(([w, h]) => __qa.layout(w, h), [L.w, L.h]); }
async function tapCell(page, ly, cx, cy) { await page.touchscreen.tap(ly.left + ly.ox + (cx + 0.5) * ly.cell, ly.top + ly.oy + (cy + 0.5) * ly.cell); }
async function tapArrow(page, ly, L, i) { const c = cells(L.arrows[i]); const m = c[Math.floor(c.length / 2)]; await tapCell(page, ly, m[0], m[1]); }
const gstate = page => page.evaluate(() => { const g = window.__ok.game(); return { alive: g.alive.slice(), lives: g.lives, coll: g.collisions, busy: window.__ok.busy() }; });
const sstate = page => page.evaluate(() => JSON.parse(JSON.stringify(window.__ok.state())));
async function idle(page, ms = 650) { await page.waitForFunction(() => !window.__ok.busy(), null, { timeout: 4000 }).catch(() => {}); await wait(ms); }
async function solveByTouch(page, ly, id) {
  const L = LEVELS[id - 1];
  for (let n = 0; n < 60; n++) {
    const st = await gstate(page); if (!st.alive.some(Boolean)) break;
    const f = freeOf(L, st.alive); if (!f.length) break;
    await tapArrow(page, ly, L, f[0]); await idle(page, 150);
  }
  await page.waitForSelector('#end-sheet', { timeout: 4000 }).catch(() => {});
  await wait(200);
}
function blockedArrow(L, minFree = 0) { const al = L.arrows.map(() => true); for (let i = 0; i < L.arrows.length; i++) { const o = obstacle(L, al, i); if (o && o.free >= minFree) return { i, ...o }; } return null; }

// ================================================================ TESTLER
(async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const allReq = [], allErr = [];
  const track = p => { allReq.push(p.requests); allErr.push(p.errors); return p; };

  for (const VP of [{ width: 390, height: 844 }, { width: 360, height: 740 }]) {
    const tag = VP.width + 'px';
    // ------------------------------------------------------------ 1. KURALLAR
    G('1. Kural doğruluğu ' + tag);
    {
      const P = track(await newPage(browser, { ...VP, seed: base({ freeHints: 99 }) })); const page = P.page;
      // açık ok çıkıyor mu (seviye 5)
      let id = 5, L = LEVELS[id - 1], ly = await startLevel(page, id);
      const hookC = await page.evaluate(() => window.__ok.cellCenter(0));
      check(`${tag}: piksellerden bulunan tahta yerleşimi oyunla tutarlı`, Math.abs(ly.left + ly.ox + (tailX(L.arrows[0]) + 0.5) * ly.cell - hookC.x) < 2 && Math.abs(ly.top + ly.oy + (tailY(L.arrows[0]) + 0.5) * ly.cell - hookC.y) < 2, `cell=${ly.cell.toFixed(1)}`);
      let all = L.arrows.map(() => true), fi = freeOf(L, all)[0];
      await tapArrow(page, ly, L, fi); await idle(page);
      let st = await gstate(page);
      const goneVis = await page.evaluate(([ly, cs]) => cs.every(c => !__qa.present(ly, c[0], c[1])), [ly, cells(L.arrows[fi])]);
      check(`${tag}: yolu açık ok tahtadan çıktı (mantık + ekran)`, !st.alive[fi] && goneVis && st.lives === 3);
      // v1.2 (docs/08): geri alma yok
      check(`${tag}: v1.2: geri alma düğmesi yok`, !(await page.$('#btn-undo')));

      // kapalı ok: engele kadar kayıp geri dönüyor mu
      const lvB = LEVELS.findIndex((Lx, k) => k >= 3 && blockedArrow(Lx, 1)) + 1;
      L = LEVELS[lvB - 1]; ly = await startLevel(page, lvB);
      const b = blockedArrow(L, 1), a = L.arrows[b.i], d = D[a.dir], hc = headC(a);
      const gap = [hc[0] + d[0] * b.free, hc[1] + d[1] * b.free];          // engelden hemen önceki boş hücre
      const beyondCells = []; { let x = gap[0] + d[0] * 2, y = gap[1] + d[1] * 2; const gg = grid(L, L.arrows.map(() => true)); while (x >= 0 && y >= 0 && x < L.w && y < L.h) { if (gg[y * L.w + x] === -1) beyondCells.push([x, y]); x += d[0]; y += d[1]; } }
      const samp = page.evaluate(([ly, list]) => __qa.sample(ly, list, 600), [ly, [gap, ...beyondCells]]);
      await tapArrow(page, ly, L, b.i);
      const ever = await samp; await idle(page);
      st = await gstate(page);
      const homeVis = await page.evaluate(([ly, cs, g]) => cs.every(c => __qa.present(ly, c[0], c[1])) && !__qa.present(ly, g[0], g[1]), [ly, cells(a), gap]);
      check(`${tag}: kapalı ok engelin önündeki hücreye kadar kaydı (lv${lvB} ok${b.i}, ${b.free} boş hücre)`, ever[0]);
      check(`${tag}: kapalı ok engelin ötesine geçmedi`, ever.slice(1).every(v => !v), beyondCells.length + ' hücre');
      check(`${tag}: kapalı ok eski yerine döndü, tahtada kaldı`, st.alive[b.i] && homeVis);
      const hearts = await page.evaluate(() => document.querySelectorAll('#hearts .lost').length);
      check(`${tag}: çarpışma 1 can düşürdü (motor + HUD)`, st.lives === 2 && st.coll === 1 && hearts === 1, JSON.stringify({ lives: st.lives, hearts }));
      // v1.2: çarpışma kalıcı; 2 çarpışma daha -> başarısız
      for (let k = 0; k < 2; k++) { await tapArrow(page, ly, L, b.i); await idle(page); }
      const dead = await page.isVisible('#dead-sheet');
      check(`${tag}: can bitince "Canın bitti" penceresi`, dead);
      await page.tap('#dead-retry'); await wait(300);
      st = await gstate(page);
      check(`${tag}: yeniden başla: 3 can, tüm oklar yerinde`, st.lives === 3 && st.alive.every(Boolean));

      // ipucu: 20 rastgele durum (canvas farkından vurgulanan oku bul)
      let hintOk = 0, hintBest = 0, hintFail = [];
      let seed = 7; const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
      for (let n = 0; n < 20; n++) {
        const hid = 4 + Math.floor(rnd() * 33); const HL = LEVELS[hid - 1];
        await page.evaluate(id => window.__ok.startLevel(id), hid); await wait(320);
        const hl = await lay(page, hid);
        const steps = Math.floor(rnd() * Math.max(1, HL.arrows.length - 2));
        let al = HL.arrows.map(() => true);
        for (let s = 0; s < steps; s++) { const f = freeOf(HL, al); const pick = f[Math.floor(rnd() * f.length)]; al[pick] = false; await idle(page, 0); await page.evaluate(i => window.__ok.tapArrow(i), pick); await wait(30); }
        await idle(page);
        al = (await gstate(page)).alive;
        await page.evaluate(() => { __qa.before = __qa.snap(); });
        await page.tap('#btn-hint'); await wait(120);
        const idx = await page.evaluate(([hl, w, h]) => { const before = __qa.before, now = __qa.snap(), cv = document.getElementById('board'); const W = cv.width;
          const cnt = new Array(w * h).fill(0);
          for (let p = 0; p < now.length; p += 4) if (Math.abs(now[p] - before[p]) + Math.abs(now[p + 1] - before[p + 1]) + Math.abs(now[p + 2] - before[p + 2]) > 40) {
            const x = (p / 4) % W / hl.dpr, y = Math.floor(p / 4 / W) / hl.dpr; const cx = Math.floor((x - hl.ox) / hl.cell), cy = Math.floor((y - hl.oy) / hl.cell);
            if (cx >= 0 && cy >= 0 && cx < w && cy < h) cnt[cy * w + cx]++; }
          return cnt; }, [hl, HL.w, HL.h]);
        const g2 = grid(HL, al), score = {};
        idx.forEach((c, k) => { if (c > 0 && g2[k] >= 0) score[g2[k]] = (score[g2[k]] || 0) + c; });
        const shown = Number(Object.keys(score).sort((x, y) => score[y] - score[x])[0]);
        const f = freeOf(HL, al);
        const gain = i => { const a2 = al.slice(); a2[i] = false; return freeOf(HL, a2).length - (f.length - 1); };
        const bestG = Math.max(...f.map(gain));
        if (f.includes(shown)) hintOk++; else hintFail.push(`lv${hid}/ok${shown}`);
        if (f.includes(shown) && gain(shown) === bestG) hintBest++;
      }
      check(`${tag}: ipucu 20 rastgele durumda çıkabilir oku gösterdi`, hintOk === 20, `${hintOk}/20 ${hintFail.join(',')}`);
      check(`${tag}: ipucu en çok oku serbest bırakanı seçti`, hintBest === 20, `${hintBest}/20`);
      await P.ctx.close();
    }
    // yıldız kuralı + tekrar oynama farkı
    {
      const P = track(await newPage(browser, { ...VP, seed: base({ coins: 0 }) })); const page = P.page;
      const id = LEVELS.findIndex((Lx, k) => k >= 3 && blockedArrow(Lx)) + 1, L = LEVELS[id - 1], b = blockedArrow(L);
      const runs = [[2, 1, 10], [1, 2, 5], [0, 3, 5]], got = [];
      for (const [coll, expStars, expCoins] of runs) {
        const c0 = (await sstate(page)).coins;
        const ly = await startLevel(page, id);
        for (let k = 0; k < coll; k++) { await tapArrow(page, ly, L, b.i); await idle(page); }
        await solveByTouch(page, ly, id);
        const ds = await page.getAttribute('#end-sheet', 'data-stars'); const s = await sstate(page);
        got.push(`${coll}çarp→${ds}★ +${s.coins - c0}`);
        check(`${tag}: ${coll} çarpışma → ${expStars} yıldız, +${expCoins} jeton (fark)`, Number(ds) === expStars && s.stars[id] === expStars && s.coins - c0 === expCoins, got[got.length - 1]);
        if (coll === 1) check(`${tag}: "Yeni rekor!" etiketi yıldız artınca görünür`, await page.isVisible('#end-sheet .tag'));
      }
      // daha kötü tekrar: yıldız düşmez, jeton yok
      const c0 = (await sstate(page)).coins; const ly = await startLevel(page, id);
      await tapArrow(page, ly, L, b.i); await idle(page); await solveByTouch(page, ly, id);
      const s = await sstate(page);
      check(`${tag}: kötü tekrar: yıldız 3'te kalır, jeton 0`, s.stars[id] === 3 && s.coins === c0);
      // 2 çarpışma (1 can kalır) ile bitirme → 1 yıldız; can iade yolu yok (v1.2)
      const id2 = LEVELS.findIndex((Lx, k) => k >= 3 && k !== id - 1 && blockedArrow(Lx)) + 1, L2 = LEVELS[id2 - 1], b2 = blockedArrow(L2);
      const ly2 = await startLevel(page, id2);
      await tapArrow(page, ly2, L2, b2.i); await idle(page); await tapArrow(page, ly2, L2, b2.i); await idle(page);
      const l2 = (await gstate(page)).lives;
      await solveByTouch(page, ly2, id2);
      check(`${tag}: 2 çarpışma (1 can kaldı) ile bitirme → 1 yıldız`, l2 === 1 && (await page.getAttribute('#end-sheet', 'data-stars')) === '1');
      await P.ctx.close();
    }
  }

  // ------------------------------------------------------------ 2. EKONOMİ
  G('2. Ekonomi');
  try {
    // ilk bitirme (öğretici seviye 1, temiz kayıt) → +20
    const P = track(await newPage(browser, {})); const page = P.page;
    let s = await sstate(page);
    check('başlangıç (v1.2): 50 jeton, 2 ücretsiz ipucu, geri alma yok', s.coins === 50 && s.freeHints === 2 && !('freeUndos' in s));
    await page.tap('#btn-play'); await page.waitForFunction(() => window.__ok.screen() === 'game'); await wait(320);
    await solveByTouch(page, await lay(page, 1), 1);
    s = await sstate(page);
    check('ilk bitirme ★★★ → +20 jeton', s.coins === 70 && s.stars[1] === 3 && s.unlocked === 2, String(s.coins));
    // ücretsiz hak önce, sonra jeton (ipucu 50, v1.2)
    await page.evaluate(() => window.__ok.debugPatch({ coins: 100, freeHints: 1, tutorialDone: [1, 2, 3], unlocked: 36 }));
    const id = 6, L = LEVELS[id - 1]; let ly = await startLevel(page, id);
    const hs = async () => page.evaluate(() => document.getElementById('hint-sub').textContent);
    check('ipucu düğmesinde ücretsiz hak yazıyor', /1/.test(await hs()), await hs());
    await page.tap('#btn-hint'); await wait(150); s = await sstate(page);
    check('ipucu: önce ücretsiz hak (1→0), jeton değişmez', s.freeHints === 0 && s.coins === 100);
    await page.tap('#btn-hint'); await wait(150); s = await sstate(page);
    check('ipucu: ücretsiz hak bitince 50 jeton düşer', s.coins === 50, String(s.coins));
    check('ipucu düğmesinde fiyat (50) yazıyor', /50/.test(await hs()), await hs());
    // yetersiz jeton
    await page.evaluate(() => { window.__ok.debugPatch({ coins: 49 }); __qa.toasts = []; });
    await page.tap('#btn-hint'); await wait(200); s = await sstate(page); let toasts = await page.evaluate(() => __qa.toasts);
    check('yetersiz jetonda ipucu verilmez, jeton düşmez, "Jetonun yetmiyor" penceresi', s.coins === 49 && (await page.isVisible('#lowcoins-sheet')));
    await page.tap('#lowcoins-close'); await wait(150);
    // öğretici seviye 2: muaf çarpışma can götürmez
    await page.evaluate(() => window.__ok.debugPatch({ tutorialDone: [1], coins: 100 }));
    ly = await startLevel(page, 2);
    const b2 = blockedArrow(LEVELS[1]);
    await tapArrow(page, ly, LEVELS[1], b2.i); await idle(page);
    const after2 = await gstate(page); s = await sstate(page);
    check('öğretici sv2: muaf çarpışma can götürmez, jeton değişmez', after2.lives === 3 && s.coins === 100);
    await P.ctx.close();
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  try {
    // bölüm bonusu
    const st11 = {}; for (let k = 1; k <= 11; k++) st11[k] = 1;
    const P = track(await newPage(browser, { seed: base({ coins: 0, stars: st11 }) })); const page = P.page;
    let ly = await startLevel(page, 12); await solveByTouch(page, ly, 12);
    let s = await sstate(page);
    check('bölüm bonusu: 12. seviye (son eksik) bitince +20 +50', s.coins === 70 && s.chapterBonus.includes(1), String(s.coins));
    check('bölüm sonu etiketi gösteriliyor', await page.isVisible('#end-sheet .tag'));
    await page.evaluate(() => { const st = Object.assign({}, window.__ok.state().stars); st[12] = 1; window.__ok.debugPatch({ stars: st }); }); // yıldız artırma tekrarında bonus tekrar verilmemeli
    ly = await startLevel(page, 12); await solveByTouch(page, ly, 12); s = await sstate(page);
    check('bölüm bonusu ikinci kez verilmez', s.coins === 70 + 10, String(s.coins));
    // bölüm tamamlanmadan bonus yok
    ly = await startLevel(page, 13); await solveByTouch(page, ly, 13); s = await sstate(page);
    check('bölüm eksikken bonus yok (sv13 → +20)', s.coins === 100, String(s.coins));
    await P.ctx.close();
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  try {
    // tema satın alma / seçme / kalıcılık
    const P = track(await newPage(browser, { seed: base({ coins: 299 }) })); const page = P.page;
    await page.tap('#btn-shop'); await wait(300);
    const prices = await page.$$eval('#shop-list .item', its => its.map(i => i.getAttribute('data-theme') + ':' + i.querySelector('.item-price').textContent));
    check('tema fiyatları belgeyle aynı (0/300/500/750/1000)', ['lokum:300', 'cini:500', 'bakir:750', 'gece:1000'].every(x => prices.some(p => p.replace(/[^a-z:0-9]/g, '').startsWith(x))), prices.join(' | '));
    await page.tap('.item[data-theme="lokum"] .btn'); await wait(250);
    let s = await sstate(page);
    check('yetersiz jetonla tema alınamaz', s.coins === 299 && !s.themesOwned.includes('lokum') && !(await page.isVisible('#confirm-yes')));
    await page.evaluate(() => { window.__ok.debugPatch({ coins: 300 }); }); await page.evaluate(() => window.__ok.show('shop')); await wait(250);
    await page.tap('.item[data-theme="lokum"] .btn'); await wait(250); await page.tap('#confirm-no'); await wait(200);
    s = await sstate(page); check('onay iptalinde jeton düşmez', s.coins === 300 && !s.themesOwned.includes('lokum'));
    await page.tap('.item[data-theme="lokum"] .btn'); await wait(250); await page.tap('#confirm-yes'); await wait(250);
    s = await sstate(page); check('tema satın alındı: −300, sahip, seçili', s.coins === 0 && s.themesOwned.includes('lokum') && s.theme === 'lokum');
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu'); await wait(250);
    s = await sstate(page); check('tema satın alma yenilemeden sonra kalıcı', s.themesOwned.includes('lokum') && s.theme === 'lokum' && s.coins === 0);
    // oyunda tema rengi
    const L = LEVELS[4]; let ly = await startLevel(page, 5);
    const col = await page.evaluate(([ly, a]) => __qa.color(ly, a.tx, a.ty, 0) /* v1.3: kuyruktan gövde yönünde 0,3 hücre (merkezdeki şevronun dışı; ince/kıvrımlı gövde buradan geçer) */, [ly, (() => { const c = cells(L.arrows[0]), d = c.length > 1 ? [c[1][0] - c[0][0], c[1][1] - c[0][1]] : D[L.arrows[0].dir]; return { tx: c[0][0] + d[0] * 0.3, ty: c[0][1] + d[1] * 0.3 }; })()]);
    check('oyunda seçili tema renkleri kullanılıyor (ok0 ≈ #E77FA0)', Math.abs(col[0] - 0xE7) + Math.abs(col[1] - 0x7F) + Math.abs(col[2] - 0xA0) < 60, col.join(','));
    await page.evaluate(() => window.__ok.show('shop')); await wait(250);
    await page.tap('.item[data-theme="emaye"] .btn'); await wait(200);
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    s = await sstate(page); check('başka temaya geçiş kalıcı', s.theme === 'emaye' && s.themesOwned.includes('lokum'));
    await P.ctx.close();
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  try {
    // günlük ödül: 7 gün döngüsü, gün atlama, aynı gün, saat geri
    const P = track(await newPage(browser, { seed: base({ coins: 0, freeHints: 0 }), fakeDate: '2026-03-01T10:00:00' })); const page = P.page;
    const claim = async () => { await page.tap('#btn-daily'); await wait(250); const can = await page.isVisible('#daily-claim'); if (can) { await page.tap('#daily-claim'); await wait(250); } await page.evaluate(() => { const m = document.getElementById('modal'); if (!m.hidden) m.click(); }); await wait(150); return can; };
    const exp = [20, 30, 40, 50, 60, 80, 150, 20], got = [];
    let ok = true;
    for (let d = 0; d < 8; d++) {
      await setFakeDate(page, `2026-03-${String(1 + d).padStart(2, '0')}T10:00:00`);
      const c0 = (await sstate(page)).coins, h0 = (await sstate(page)).freeHints;
      const badge = await page.evaluate(() => document.getElementById('btn-daily').classList.contains('ready'));
      await claim(); const s = await sstate(page);
      got.push(`${s.coins - c0}${s.freeHints - h0 ? '+ipucu' : ''}`);
      if (s.coins - c0 !== exp[d] || (d === 6) !== (s.freeHints - h0 === 1) || !badge) ok = false;
    }
    check('günlük ödül 7 gün döngüsü 20/30/40/50/60/80/150+1 ipucu, 8. gün yeniden 20', ok, got.join(' '));
    check('tek döngü toplamı 430 jeton', exp.slice(0, 7).reduce((a, b) => a + b) === 430);
    const c1 = (await sstate(page)).coins;
    const again = await claim();
    check('aynı gün ikinci kez alınamaz', !again && (await sstate(page)).coins === c1);
    // gece yarısı: 23:59 → 00:01
    await setFakeDate(page, '2026-03-09T23:59:00'); await claim();
    await setFakeDate(page, '2026-03-10T00:01:00');
    const c2 = (await sstate(page)).coins; await claim();
    check('gece yarısı geçince yeni gün sayılır (yerel tarih)', (await sstate(page)).coins - c2 === 40 && (await sstate(page)).daily.streakDay === 3, String((await sstate(page)).coins - c2));
    // gün atlama
    await setFakeDate(page, '2026-03-12T10:00:00');
    const c3 = (await sstate(page)).coins; await claim();
    check('bir gün atlanınca seri 1. güne döner (+20)', (await sstate(page)).coins - c3 === 20 && (await sstate(page)).daily.streakDay === 1);
    // saat geri
    await setFakeDate(page, '2026-03-13T10:00:00'); await claim();
    await setFakeDate(page, '2026-03-11T10:00:00');
    const c4 = (await sstate(page)).coins, can4 = await claim();
    check('saat geri alınınca ödül yok, seri korunur', !can4 && (await sstate(page)).coins === c4 && (await sstate(page)).daily.streakDay === 2);
    await setFakeDate(page, '2026-03-14T10:00:00'); const c5 = (await sstate(page)).coins; await claim();
    check('saat düzelince seri kaldığı yerden (3. gün, +40)', (await sstate(page)).coins - c5 === 40);
    // uygulama açıkken gün değişirse rozet
    await setFakeDate(page, '2026-03-15T23:59:50'); await claim();
    await wait(11000); await page.evaluate(() => window.__ok.show('menu')); await wait(200);
    check('uygulama açıkken gün dönünce (menüye dönüşte) rozet yeniden hazır', await page.evaluate(() => document.getElementById('btn-daily').classList.contains('ready')));
    await P.ctx.close();
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }

  // ------------------------------------------------------------ 3. KAYIT
  G('3. Kayıt');
  try {
    const P = track(await newPage(browser, {})); const page = P.page;
    await page.tap('#btn-play'); await page.waitForFunction(() => window.__ok.screen() === 'game'); await wait(320);
    await solveByTouch(page, await lay(page, 1), 1);
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu'); await wait(250);
    const s = await sstate(page);
    const playTxt = await page.textContent('#btn-play');
    check('yenilemeden sonra ilerleme (yıldız, jeton, kilit, öğretici) korunur', s.stars[1] === 3 && s.coins === 70 && s.unlocked === 2 && s.tutorialDone.includes(1), JSON.stringify({ c: s.coins, u: s.unlocked }));
    check('menüde "Devam: Seviye 2"', playTxt.includes('2'), playTxt);
    await P.ctx.close();
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  try {
  for (const [name, pre] of [
    ['localStorage erişimi SecurityError atıyor', `Object.defineProperty(window, 'localStorage', { get() { throw new DOMException('blocked', 'SecurityError'); } });`],
    ['localStorage null', `Object.defineProperty(window, 'localStorage', { get() { return null; } });`],
    ['setItem QuotaExceeded atıyor', `Storage.prototype.setItem = function () { throw new DOMException('full', 'QuotaExceededError'); };`],
    ['getItem atıyor', `Storage.prototype.getItem = function () { throw new Error('io'); };`],
  ]) {
    const P = track(await newPage(browser, { pre })); const page = P.page;
    const okMenu = await page.evaluate(() => !!window.__ok && window.__ok.screen() === 'menu').catch(() => false);
    let played = false;
    if (okMenu) { await page.tap('#btn-play'); await wait(350); await solveByTouch(page, await lay(page, 1), 1); played = await page.isVisible('#end-sheet'); }
    check(`${name}: oyun açılır ve seviye oynanır, konsol hatası yok`, okMenu && played && P.errors.length === 0, P.errors.join(' | ').slice(0, 200));
    await P.ctx.close();
  }
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  try {
  for (const [name, raw, test] of [
    ['bozuk JSON', '{"coins":', s => s.coins === 50],
    ['JSON null', 'null', s => s.coins === 50],
    ['JSON dizi', '[1,2,3]', s => s.coins === 50 && s.unlocked === 1],
    ['JSON sayı', '42', s => s.coins === 50],
    // v1.1: seviye sayısı levels.js'ten (36 → 120); sınır dışı yıldız anahtarı = son seviye + 1
    ['negatif/NaN/dev değerler', JSON.stringify({ coins: -50, freeHints: 'NaN', freeUndos: 1e12, unlocked: 1e9, stars: { 1: 99, 2: -1, 100000: 3, '__proto__': 3 }, daily: { lastDate: 'dün', streakDay: 99 }, themesOwned: 'gece', theme: 'gece' }), s => s.coins === 999 * 20 && s.unlocked === 99999 && s.stars[1] === 3 && !s.stars[2] && !s.stars[100000] /* v1.3: sonsuz devam, üst sınır 99999 */ && s.daily.lastDate === null && s.daily.streakDay <= 7 && s.theme === 'emaye'],
    ['yanlış tipte alanlar', JSON.stringify({ stars: 'x', themesOwned: [null, {}, 'lokum'], theme: 'lokum', tutorialDone: 'yes', chapterBonus: {}, daily: 5, sound: 'off' }), s => s.themesOwned.includes('lokum') && s.theme === 'lokum' && s.sound === true],
  ]) {
    const P = track(await newPage(browser, { seed: raw })); const page = P.page;
    const s = await sstate(page).catch(() => null);
    let ok = !!s && test(s);
    if (ok) { await page.tap('#btn-map'); await wait(300); await page.tap('#btn-settings').catch(() => {}); await page.evaluate(() => window.__ok.show('shop')); await wait(200); }
    check(`kayıt "${name}" → güvenli onarım, ekranlar açılıyor, hata yok`, ok && P.errors.length === 0, (s ? JSON.stringify({ c: s.coins, u: s.unlocked, t: s.theme }) : 'durum yok') + ' ' + P.errors.join('|').slice(0, 150));
    await P.ctx.close();
  }
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }

  // ------------------------------------------------------------ 4. DİLLER
  G('4. Diller');
  const dictVals = l => Object.values(I18N[l]).filter(v => typeof v === 'string' && v.length);
  function residue(str, l) {
    // sözlük değerlerini (yer tutucular serbest) metinden çıkar; kalan harfler = sabit metin
    let s = str;
    const vals = dictVals(l).concat(Object.values(I18N[l]).filter(() => false)).sort((a, b) => b.length - a.length);
    for (const v of vals) {
      const re = new RegExp(v.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\\\{[a-z]+\\\}/g, '[\\d\\/]+'), 'g');
      s = s.replace(re, ' ');
    }
    s = s.replace(/nilkaren\.tuncay\.demir@gmail\.com/g, '').replace(/[\d\s·:\/+\-−—–.,!()★%]/g, '');
    return s;
  }
  async function scan(page, l, where, bag) {
    const items = await page.evaluate(() => {
      const out = [], roots = [document.querySelector('.screen.active'), document.querySelector('#modal:not([hidden])'), document.getElementById('toast')].filter(Boolean);
      const vis = n => { const e = n.nodeType === 3 ? n.parentElement : n; if (!e) return false; const cs = getComputedStyle(e); if (e.closest('[hidden]')) return false; return cs.display !== 'none' && cs.visibility !== 'hidden'; };
      roots.forEach(r => {
        const w = document.createTreeWalker(r, NodeFilter.SHOW_TEXT); let n;
        while ((n = w.nextNode())) { const t = n.textContent.trim(); if (t && vis(n) && !n.parentElement.closest('svg')) out.push(t); }
        r.querySelectorAll('[aria-label],[title],[alt],[placeholder]').forEach(e => ['aria-label', 'title', 'alt', 'placeholder'].forEach(a => { const v = e.getAttribute(a); if (v && v.trim()) out.push(v.trim()); }));
      });
      out.push(document.title);
      return out;
    });
    for (const t of items) { const r = residue(t, l); if (r.length && !Object.keys(I18N).some(o => o !== l && false)) bag.push(`${where}: "${t}"`); }
  }
  try {
  for (const l of ['tr', 'en', 'de', 'ar']) {
    for (const VP of [{ width: 390, height: 844 }, { width: 360, height: 740 }]) {
      const P = track(await newPage(browser, { ...VP, locale: LOCALES[l], seed: base({ lang: l, tutorialDone: [], unlocked: 3, stars: { 1: 3, 2: 2 }, coins: 400, daily: { lastDate: null, streakDay: 0 } }) })); const page = P.page;
      const bag = [], tag = `${l}-${VP.width}`;
      const attr = await page.evaluate(() => [document.documentElement.lang, document.documentElement.dir]);
      if (VP.width === 390) check(`${l}: <html lang="${l}" dir="${l === 'ar' ? 'rtl' : 'ltr'}">`, attr[0] === l && attr[1] === (l === 'ar' ? 'rtl' : 'ltr'), attr.join('/'));
      const screens = [];
      const visit = async (where, fn) => { await fn(); await wait(330); await scan(page, l, where, bag); screens.push(where); await overflow(page, tag + ' ' + where); };
      await visit('menü', async () => {});
      await visit('günlük ödül', async () => page.tap('#btn-daily'));
      await visit('günlük ödül alındı', async () => { await page.tap('#daily-claim'); });
      await page.evaluate(() => document.getElementById('modal').click()); await wait(200);
      await visit('harita', async () => page.tap('#btn-map'));
      await visit('kilitli düğüm uyarısı', async () => { await page.evaluate(() => document.querySelector('.node.locked').scrollIntoView({ block: 'center' })); await wait(80); await page.tap('.node.locked'); await wait(60); });
      await visit('oyun + öğretici sv1', async () => { await page.evaluate(() => document.querySelector('.node[data-level="1"]').scrollIntoView({ block: 'center' })); await wait(80); await page.tap('.node[data-level="1"]'); });
      await visit('duraklat', async () => page.tap('#btn-pause'));
      await visit('oyun (devam)', async () => page.tap('#pause-resume'));
      await visit('ipucu', async () => page.tap('#btn-hint'));
      await page.evaluate(() => window.__ok.startLevel(2)); await wait(300);
      { const ly = await lay(page, 2); const b = blockedArrow(LEVELS[1]); await tapArrow(page, ly, LEVELS[1], b.i); await wait(450); }
      await visit('öğretici sv2 (çarpışma sonrası)', async () => {});
      await page.evaluate(() => window.__ok.startLevel(3)); await wait(300);
      await visit('öğretici sv3', async () => {});
      await visit('seviye sonu', async () => { await solveByTouch(page, await lay(page, 3), 3); await wait(1200); });
      await page.evaluate(() => window.__ok.startLevel(5)); await wait(300);
      { const ly = await lay(page, 5); const b = blockedArrow(LEVELS[4]); if (b) for (let k = 0; k < 3; k++) { await tapArrow(page, ly, LEVELS[4], b.i); await idle(page); } }
      await visit('can bitti', async () => {});
      await page.evaluate(() => window.__ok.show('shop')); await wait(200);
      await visit('mağaza temalar', async () => {});
      await visit('satın alma onayı', async () => page.tap('.item[data-theme="lokum"] .btn'));
      await visit('satın alındı', async () => page.tap('#confirm-yes'));
      await visit('mağaza yardımcılar', async () => page.tap('#tab-boosters'));
      await visit('ayarlar', async () => page.evaluate(() => window.__ok.show('settings')));
      await visit('sıfırla onayı', async () => page.tap('#btn-reset'));
      await visit('sıfırlandı', async () => page.tap('#confirm-yes'));
      const uniq = [...new Set(bag)];
      check(`${tag}: ${screens.length} ekran durumunda sözlük dışı sabit metin yok`, uniq.length === 0, uniq.slice(0, 8).join(' ; '));
      check(`${tag}: konsol hatası yok`, P.errors.length === 0, P.errors.join('|').slice(0, 200));
      await P.ctx.close();
    }
  }
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  // taşma/kırpma: buton, başlık, sekme; kelimenin ortadan bölünmesi; font < 14px
  async function overflow(page, where) {
    const r = await page.evaluate(() => {
      const out = [], vw = document.documentElement.clientWidth;
      const roots = [document.querySelector('.screen.active'), document.querySelector('#modal:not([hidden]) .sheet')].filter(Boolean);
      roots.forEach(root => root.querySelectorAll('.btn, .tab, .lang-btn, .tool, .bar-title, .item-name, .item-desc, .day, .bubble, .chapter-head, .pill, h1, h2, h3, p, small, .tag').forEach(n => {
        if (n.closest('[hidden]')) return;
        const b = n.getBoundingClientRect(); if (!b.width) return;
        const cs = getComputedStyle(n), label = (n.id || n.className || n.tagName) + ' "' + n.textContent.trim().slice(0, 30) + '"';
        if (b.right > vw + 1 || b.left < -1) out.push('ekran dışı ' + label);
        if (n.scrollWidth > n.clientWidth + 1 && cs.overflowX !== 'visible') out.push('yatay taşma ' + label);
        if (cs.textOverflow === 'ellipsis') out.push('ellipsis ' + label);
        if (n.matches('.btn, .tab, .lang-btn') && parseFloat(cs.fontSize) < 14 && !n.matches('.tiny')) out.push('font<14 ' + label + ' ' + cs.fontSize);
        // kelime ortadan bölünmüş mü (tek kelime iki satıra yayılmış)
        const w = document.createTreeWalker(n, NodeFilter.SHOW_TEXT); let tn;
        while ((tn = w.nextNode())) { if (tn.parentElement.closest('svg')) continue; const re = /\S+/g; let m;
          while ((m = re.exec(tn.textContent))) { if (m[0].length < 4) continue; const rg = document.createRange(); rg.setStart(tn, m.index); rg.setEnd(tn, m.index + m[0].length);
            const tops = new Set([...rg.getClientRects()].filter(x => x.width > 0.5).map(x => Math.round(x.top))); if (tops.size > 1) out.push('kelime bölündü "' + m[0] + '" in ' + (n.id || n.className)); } }
        // içerik kutudan dışarı (dikey) — üst üste binen satırlar
        [...n.children].forEach(c => { const cb = c.getBoundingClientRect(); if (cb.width && (cb.right > b.right + 2 || cb.left < b.left - 2) && !c.closest('svg') && n.matches('.btn,.tool,.tab')) out.push('çocuk taşıyor ' + label); });
      }));
      return [...new Set(out)];
    });
    if (r.length) (ovIssues[where.split(' ')[0]] = ovIssues[where.split(' ')[0]] || []).push(...r.map(x => where + ': ' + x));
  }
  for (const k of ['tr-390', 'tr-360', 'en-390', 'en-360', 'de-390', 'de-360', 'ar-390', 'ar-360']) {
    const iss = [...new Set(ovIssues[k] || [])];
    check(`${k}: taşma / kırpma / ellipsis / bölünmüş kelime yok`, iss.length === 0, iss.slice(0, 6).join(' ; ') + (iss.length > 6 ? ` …(+${iss.length - 6})` : ''));
  }
  try {
    // Arapça: tahta aynalanmaz; dokunma doğru oku hareket ettirir
    const id = 7, L = LEVELS[id - 1];
    const lays = {};
    for (const l of ['en', 'ar']) {
      const P = track(await newPage(browser, { locale: LOCALES[l], seed: base({ lang: l }) })); const page = P.page;
      const ly = await startLevel(page, id); lays[l] = ly;
      const free = freeOf(L, L.arrows.map(() => true));
      // her ok için: hücre dolu mu (aynalanmamış konumda)
      const pres = await page.evaluate(([ly, cs]) => cs.map(c => __qa.present(ly, c[0], c[1])), [ly, L.arrows.map(a => [tailX(a), tailY(a)])]);
      if (l === 'ar') {
        check('ar: okların kuyruk hücreleri aynalanmamış konumda çiziliyor', pres.every(Boolean));
        const mirrored = await page.evaluate(([ly, w, cs]) => cs.filter(c => __qa.present(ly, w - 1 - c[0], c[1])).length, [ly, L.w, L.arrows.map(a => [tailX(a), tailY(a)])]);
        // sağ/sol yönlü bir okun baş şeklini kontrol: başın ucu yön tarafında olmalı
        const hr = L.arrows.findIndex(a => a.dir === 'R' || a.dir === 'L');
        let dirOk = true;
        if (hr >= 0) { const a = L.arrows[hr], hc = headC(a), s = a.dir === 'R' ? 1 : -1;
          const tip = await page.evaluate(([ly, x, y, s]) => [__qa.color(ly, x, y, s * 0.30), __qa.color(ly, x, y, -s * 0.45)], [ly, hc[0], hc[1], s]);
          const isCell = c => Math.abs(c[0] - 246) + Math.abs(c[1] - 248) + Math.abs(c[2] - 250) < 30; dirOk = !isCell(tip[0]); }
        check('ar: ok başları gösterdiği yönde çiziliyor (R/L ters değil)', dirOk);
        check('ar: tahta yerleşimi İngilizce ile birebir aynı', Math.abs(lays.ar.ox - lays.en.ox) < 1 && Math.abs(lays.ar.cell - lays.en.cell) < 0.5);
        // Dokunuş: sağ yarıdaki ve sol yarıdaki birer açık oka dokun
        const fr = free.slice().sort((p, q) => tailX(L.arrows[q]) - tailX(L.arrows[p]));
        const target = fr[0];
        await tapArrow(page, ly, L, target); await idle(page);
        const st = await gstate(page);
        const moved = st.alive.map((v, k) => v ? null : k).filter(k => k !== null);
        check(`ar: ekranın sağındaki oka (ok${target}, x=${tailX(L.arrows[target])}) dokununca o ok hareket etti`, moved.length === 1 && moved[0] === target, 'çıkan: ' + moved.join(','));
        const blk = blockedArrow(L);
        await tapArrow(page, ly, L, blk.i); await idle(page);
        const st2 = await gstate(page);
        check('ar: kapalı oka dokununca çarpışma (yanlış ok değil)', st2.lives === 2 && st2.alive.filter(Boolean).length === st.alive.filter(Boolean).length);
        // Arapçada üst/alt çubuk ve geri ikonu aynalı
        const bar = await page.evaluate(() => { const p = document.getElementById('btn-pause').getBoundingClientRect(), c = document.querySelector('#scr-game .coin-pill').getBoundingClientRect(); const h = document.getElementById('btn-hint').getBoundingClientRect(), r = document.getElementById('btn-restart').getBoundingClientRect(); return [p.left > c.left, h.left > r.left]; });
        check('ar: üst çubuk ve araç çubuğu sırası aynalı', bar[0] && bar[1], bar.join(','));
        const ctxDir = await page.evaluate(() => document.getElementById('board').getContext('2d').direction);
        check('ar: canvas ctx.direction = rtl', ctxDir === 'rtl', ctxDir);
        const backT = await page.evaluate(() => { window.__ok.show('map'); return getComputedStyle(document.querySelector('#scr-map .back .ic')).transform; });
        check('ar: geri ikonu aynalı', /matrix\(-1/.test(backT), backT);
        const mapX = await page.evaluate(() => { const n1 = document.querySelector('.node[data-level="1"]'), n2 = document.querySelector('.node[data-level="2"]'); return [n1.style.left, n2.style.left]; });
        check('ar: harita patikası aynalı', parseFloat(mapX[1]) < 50, mapX.join(','));
        const nums = await page.evaluate(() => document.body.innerText);
        check('ar: rakamlar Batı rakamı', !/[٠-٩]/.test(nums));
      }
      await P.ctx.close();
    }
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }

  // ------------------------------------------------------------ 5. SAĞLAMLIK
  G('5. Sağlamlık');
  try {
  for (const VP of [{ width: 390, height: 844 }, { width: 360, height: 740 }]) {
    const tag = VP.width + 'px';
    const P = track(await newPage(browser, { ...VP, seed: base({ freeHints: 99 }) })); const page = P.page;
    // hücre boyu (belge: en az 40px), 8 sütunlu seviye
    // v1.2 (docs/08 §4): sığdırılmış hücre ≥ 22 px. Sağlamlık testleri ilk 36 seviyenin en büyüğünde; ayrıca en büyük seviye.
    let big = 1; LEVELS.slice(0, 36).forEach((Lx, k) => { if (Lx.w * Lx.h > LEVELS[big - 1].w * LEVELS[big - 1].h) big = k + 1; });
    { let huge = 1; LEVELS.forEach((Lx, k) => { if (Lx.w * Lx.h > LEVELS[huge - 1].w * LEVELS[huge - 1].h) huge = k + 1; });
      await page.evaluate(id => window.__ok.startLevel(id), huge); await wait(400);
      const lh = await lay(page, huge);
      check(`${tag}: en büyük tahtada (sv${huge}, ${LEVELS[huge - 1].w}x${LEVELS[huge - 1].h}) sığdırılmış hücre ≥ 16 px (v1.3, docs/09)`, lh && lh.cell >= 15.9 /* piksel ölçüm toleransı */ && lh.trayR <= lh.cw + 1 && lh.trayB <= lh.ch + 1, lh ? `hücre=${lh.cell.toFixed(1)}px` : 'tahta yok'); }
    let ly = await startLevel(page, big);
    check(`${tag}: büyük tahtada hücre ≥ 22 px (docs/08 §4)`, ly.cell >= 21.9, `sv${big} hücre=${ly.cell.toFixed(1)}px`);
    check(`${tag}: tahta canvas içinde ve yatayda ortalı`, ly.trayL >= 0 && ly.trayR <= ly.cw && ly.trayB <= ly.ch && Math.abs(ly.trayL - (ly.cw - ly.trayR)) < 2);
    // hızlı aynı oka 5 dokunuş (kapalı ok)
    const L = LEVELS[big - 1], b = blockedArrow(L);
    for (let k = 0; k < 5; k++) { await tapArrow(page, ly, L, b.i); await wait(25); }
    await idle(page);
    let st = await gstate(page);
    check(`${tag}: kapalı oka 25 ms arayla 5 dokunuş → yalnızca 1 can gider`, st.lives === 2 && st.coll === 1, `can=${st.lives}`);
    await page.tap('#btn-restart'); await wait(200);
    // çıkış animasyonu sürerken başka oka dokunuş (belge §2: yok sayılmalı)
    const al = L.arrows.map(() => true), f = freeOf(L, al);
    let ex = null;
    for (const i of f) { const a2 = al.slice(); a2[i] = false; const f2 = freeOf(L, a2).filter(k => k !== i); if (f2.length) { ex = [i, f2[0]]; break; } }
    if (ex) {
      await tapArrow(page, ly, L, ex[0]); await wait(40); await tapArrow(page, ly, L, ex[1]); await idle(page);
      st = await gstate(page);
      check(`${tag}: çıkış animasyonu sürerken (40 ms) ikinci dokunuş yok sayılır`, st.alive[ex[1]] === true, `ikinci ok${ex[1]} ${st.alive[ex[1]] ? 'yerinde' : 'de çıktı'}`);
      await page.tap('#btn-restart'); await wait(200);
      // ilk ok kayarken, onun boşalttığı yoldan geçen ok: görsel üst üste binme
      let cross = null;
      for (const i of f) { const a2 = al.slice(); a2[i] = false; const opened = freeOf(L, a2).filter(k => k !== i && obstacle(L, al, k) && obstacle(L, al, k).blocker === i); if (opened.length) { cross = [i, opened[0]]; break; } }
      if (cross) {
        await tapArrow(page, ly, L, cross[0]); await wait(30); await tapArrow(page, ly, L, cross[1]); await idle(page);
        st = await gstate(page);
        check(`${tag}: henüz kayan okun arkasındaki (yolunu o ok kapatan) ok aynı anda çıkamaz`, st.alive[cross[1]], `ok${cross[0]} kayarken ok${cross[1]} ${st.alive[cross[1]] ? 'bekledi' : 'içinden geçip çıktı'}`);
        await page.tap('#btn-restart'); await wait(200);
      }
    }
    // çarpışma animasyonu sırasında başka oka dokunuş
    await tapArrow(page, ly, L, b.i); await wait(60); await tapArrow(page, ly, L, f[0]); await idle(page);
    st = await gstate(page);
    check(`${tag}: çarpışma animasyonu sırasında dokunuş yok sayılır`, st.alive[f[0]] && st.lives === 2);
    await page.tap('#btn-restart'); await wait(200);
    // animasyon sırasında duraklat
    await tapArrow(page, ly, L, b.i); await wait(50); await page.tap('#btn-pause'); await wait(400);
    const pauseDuringBump = await page.isVisible('#pause-sheet');
    if (pauseDuringBump) await page.tap('#pause-resume');
    await idle(page);
    await tapArrow(page, ly, L, f[0]); await wait(50); await page.tap('#btn-pause'); await wait(500);
    const pausedExit = await page.isVisible('#pause-sheet');
    st = await gstate(page);
    check(`${tag}: çıkış animasyonu sırasında duraklat: pencere açılır, durum tutarlı, hata yok`, pausedExit && !st.alive[f[0]] && P.errors.length === 0);
    if (pausedExit) { await page.tap('#pause-map'); await wait(300); }
    check(`${tag}: duraklat → haritaya dön`, await page.evaluate(() => window.__ok.screen() === 'map'));
    // animasyon sırasında yeniden boyutlandırma
    ly = await startLevel(page, big);
    await tapArrow(page, ly, L, b.i); await wait(40);
    await page.setViewportSize({ width: VP.width === 390 ? 360 : 412, height: 780 }); await idle(page);
    const ly2 = await lay(page, big);
    const hook = await page.evaluate(() => window.__ok.cellCenter(0));
    check(`${tag}: animasyon sırasında boyut değişimi: tahta yeniden ölçeklendi ve ortalı`, Math.abs(ly2.left + ly2.ox + (tailX(L.arrows[0]) + 0.5) * ly2.cell - hook.x) < 2 && Math.abs(ly2.trayL - (ly2.cw - ly2.trayR)) < 2 && ly2.trayR <= ly2.cw, `hücre ${ly.cell.toFixed(1)}→${ly2.cell.toFixed(1)}`);
    const dpr2 = await page.evaluate(() => { const c = document.getElementById('board'); return c.width / c.getBoundingClientRect().width; });
    check(`${tag}: boyut değişimi sonrası canvas çözünürlüğü (DPR) korunur`, Math.abs(dpr2 - 2) < 0.02, String(dpr2));
    await tapArrow(page, ly2, L, f[0]); await idle(page); st = await gstate(page);
    check(`${tag}: yeni boyutta dokunma doğru oka gidiyor`, !st.alive[f[0]]);
    // yatay (döndürme)
    await page.setViewportSize({ width: 844, height: VP.width }); await wait(400);
    const ly3 = await lay(page, big);
    const rotateShown = await page.evaluate(() => { const r = document.getElementById('rotate'); return !!r && getComputedStyle(r).display !== 'none' && r.getBoundingClientRect().width > 0; });
    check(`${tag}: yatay ekranda "cihazı çevir" uyarısı ya da okunabilir tahta (hücre ≥ 24 px)`, rotateShown || (ly3 && ly3.trayB <= ly3.ch + 1 && ly3.trayR <= ly3.cw + 1 && ly3.cell >= 24), rotateShown ? 'uyarı görünür' : (ly3 ? `hücre=${ly3.cell.toFixed(1)}px` : 'tahta yok'));
    await page.setViewportSize(VP); await wait(400);
    const ly4 = await lay(page, big);
    check(`${tag}: dikeye dönüşte tahta eski ölçeğe döner`, Math.abs(ly4.cell - ly.cell) < 0.6, `${ly.cell.toFixed(1)} vs ${ly4.cell.toFixed(1)}`);
    // son ok çıkarken dokunuş / duraklat / geri al
    ly = await startLevel(page, 4); const L4 = LEVELS[3];
    const ord = solveOrder(L4);
    for (const i of ord.slice(0, -1)) { await tapArrow(page, ly, L4, i); await idle(page); }
    await tapArrow(page, ly, L4, ord[ord.length - 1]); await wait(30);
    await page.tap('#btn-pause'); await page.tap('#btn-restart');
    await page.waitForSelector('#end-sheet', { timeout: 3000 }).catch(() => {});
    check(`${tag}: son ok çıkarken duraklat/baştan yok sayılır, bitiş ekranı gelir`, await page.isVisible('#end-sheet') && !(await page.isVisible('#pause-sheet')));
    // bitiş ekranında hızlı çift dokunuş "Sonraki"
    await wait(300); await page.tap('#end-next'); await wait(20); await page.tap('#end-next').catch(() => {});
    await wait(400);
    check(`${tag}: "Sonraki seviye" sonrası seviye 5 temiz başlar`, await page.evaluate(() => window.__ok.level().id === 5 && window.__ok.game().alive.every(Boolean) && window.__ok.game().lives === 3));
    // duraklatma açıkken tahtaya dokunuş
    await page.tap('#btn-pause'); await wait(250);
    const L5 = LEVELS[4], ly5 = await lay(page, 5);
    st = await gstate(page);
    await page.evaluate(() => 0);
    check(`${tag}: konsol hatası yok (sağlamlık)`, P.errors.length === 0, P.errors.join('|').slice(0, 200));
    await P.ctx.close();
  }
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  try {
    // arka plana geçince otomatik duraklat
    const P = track(await newPage(browser, { seed: base() })); const page = P.page;
    await startLevel(page, 5);
    await page.evaluate(() => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => true }); document.dispatchEvent(new Event('visibilitychange')); });
    await wait(300);
    check('arka plana geçince oyun otomatik duraklar', await page.isVisible('#pause-sheet'));
    await P.ctx.close();
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }

  // ------------------------------------------------------------ 6. GÜVENLİK / GİZLİLİK
  G('6. Güvenlik/gizlilik');
  const flat = allReq.flat();
  const ext = flat.filter(u => !/^(file:|data:|blob:|about:)/.test(u));
  check(`tüm oturumlarda dış ağ isteği yok (${flat.length} istek izlendi)`, ext.length === 0, [...new Set(ext)].slice(0, 5).join(' '));
  try {
    const src = ['main.js', 'storage.js', 'engine.js', 'theme.js', 'audio.js', 'i18n.js', 'levels.js'].map(f => fs.readFileSync(path.join(ROOT, 'game/js', f), 'utf8')).join('\n');
    check('kaynakta eval / new Function / string setTimeout yok', !/\beval\s*\(|new\s+Function\s*\(|setTimeout\s*\(\s*['"]/.test(src));
    check('kaynakta fetch / XHR / WebSocket / sendBeacon yok', !/\bfetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon/.test(src));
    const html = fs.readFileSync(path.join(ROOT, 'game/index.html'), 'utf8');
    check('index.html içinde dış kaynak (http) yok', !/(src|href)=["']https?:/.test(html));
    check('Content-Security-Policy meta etiketi var', /Content-Security-Policy/i.test(html));
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  try {
    const P = track(await newPage(browser, { seed: base({ coins: 10 }) })); const page = P.page;
    const REAL = KEY.replace(/\.debug$/, '');
    await page.goto(FILE); await page.evaluate(k => localStorage.setItem(k, JSON.stringify({ coins: 10, lang: 'tr' })), REAL); await page.reload(); await wait(300);
    const hook = await page.evaluate(() => Object.keys(window.__ok || {}));
    check('window.__ok hata ayıklama kancası sürüm yapısında yok', hook.length === 0, 'mevcut: ' + hook.join(','));
    await page.goto(URL); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    // hile: kanca ile jeton yazılıp kalıcılaşıyor mu
    await page.evaluate(() => { try { window.__ok.state().coins = 999999; window.__ok.state().themesOwned.push('gece'); } catch (e) {} });
    await page.tap('#btn-settings'); await wait(200); await page.tap('#sw-sound'); await wait(100);
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    const s = await sstate(page);
    check('kanca üzerinden durum değiştirilemez (jeton/tema)', !(s.coins === 999999 && s.themesOwned.includes('gece')), `jeton=${s.coins}, temalar=${s.themesOwned}`);
    await page.evaluate(() => window.__ok.debugPatch({ coins: 999999 }));
    const realCoins = await page.evaluate(k => JSON.parse(localStorage.getItem(k) || '{}').coins, REAL);
    check('debug kipi (kum havuzu) oyuncunun gerçek kaydına yazmaz', realCoins === 10, String(realCoins));
    // kanca duraklatma penceresini atlayıp hamle yaptırabiliyor mu
    await startLevel(page, 5); await page.tap('#btn-pause'); await wait(200);
    const L = LEVELS[4], fi = freeOf(L, L.arrows.map(() => true))[0];
    await page.evaluate(i => window.__ok.tapArrow(i), fi);
    const st = await gstate(page);
    check('duraklatma açıkken __ok.tapArrow hamle yapamaz', st.alive[fi], st.alive[fi] ? '' : 'pencere açıkken ok çıktı');
    // innerHTML'e kullanıcı/kayıt verisi gidiyor mu: kayıttaki dizgi alanlarına HTML koy
    await page.evaluate(k => localStorage.setItem(k, JSON.stringify({ lang: '<img src=x onerror=window.__xss=1>', theme: '<b>x</b>', coins: '<i>5</i>', stars: { '1': '<svg onload=window.__xss=1>' }, daily: { lastDate: '<x>' } })), KEY);
    await page.reload(); await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    await page.tap('#btn-map'); await wait(300); await page.evaluate(() => window.__ok.show('shop')); await wait(200); await page.tap('#btn-daily').catch(() => {});
    await page.evaluate(() => window.__ok.show('menu')); await page.tap('#btn-daily'); await wait(200);
    check('kayıttaki HTML/JS enjeksiyonu çalışmaz', !(await page.evaluate(() => window.__xss)));
    await P.ctx.close();
  } catch (e) { check('TEST ÇALIŞTIRILAMADI ('+group+')', false, String(e).slice(0,160)); }
  const errs = allErr.flat();
  G('Genel');
  check(`tüm oturumlarda konsol/sayfa hatası yok`, errs.length === 0, [...new Set(errs)].slice(0, 5).join(' | '));

  await browser.close();
  const pass = results.filter(r => r.ok).length, fail = results.length - pass;
  console.log(`\nSONUÇ: ${pass} GEÇTİ, ${fail} KALDI (toplam ${results.length})`);
  fs.writeFileSync(path.join(__dirname, 'shots', 'qa-results.json'), JSON.stringify(results, null, 1));
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error('QA ÇÖKTÜ:', e); process.exit(2); });
