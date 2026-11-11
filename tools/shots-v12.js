// Arrowtile 1.2.0 "Aşama A" — web önizleme ekran görüntüleri (Playwright + Chromium).
// Kullanım: node tools/shots-v12.js [çıktı klasörü] [--quick]
// 390x844 ve 412x915; açık/koyu; tr ve ar: menü, harita, Kolay seviye, şekilli kaydırmalı Aşırı zor seviye (varsayılan + sığdırılmış),
// tek renk kipi, seviye sonu kutlaması (kusursuz Aşırı zor = altın alev + havai fişek; reklamla devam = küçük alev).
'use strict';
const path = require('path');
const fs = require('fs');
function loadPlaywright() {
  for (const t of ['playwright', '/opt/npm-tools/node_modules/playwright']) { try { return require(t); } catch (e) {} }
  throw new Error('Playwright bulunamadı');
}
const { chromium } = loadPlaywright();
const args = process.argv.slice(2), QUICK = args.includes('--quick');
const OUT = path.resolve(args.find(a => !a.startsWith('--')) || path.join(__dirname, 'shots', 'v12'));
fs.mkdirSync(OUT, { recursive: true });
const URL = 'file://' + path.join(__dirname, '..', 'game', 'index.html') + '?debug=1';
const wait = ms => new Promise(r => setTimeout(r, ms));
const EASY = 22, XHARD = 96, XHARD_BIG = 176; // bölüm 2 Kolay (11x17), bölüm 5 Aşırı zor (19x29, halka), bölüm 9 Aşırı zor (28x45)

(async () => {
  const browser = await chromium.launch();
  const sizes = QUICK ? [[390, 844]] : [[390, 844], [412, 915]];
  const langs = QUICK ? [['tr', 'tr-TR']] : [['tr', 'tr-TR'], ['ar', 'ar-SA']];
  const errors = [];
  for (const [W, H] of sizes) for (const dark of [false, true]) for (const [lang, locale] of langs) {
    const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale, colorScheme: dark ? 'dark' : 'light' });
    const page = await ctx.newPage();
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(URL);
    await page.evaluate(() => localStorage.clear());
    await page.goto(URL);
    await page.waitForFunction(() => window.__ok && window.__ok.screen() === 'menu');
    await page.evaluate((l) => { window.__ok.setLang(l); window.__ok.debugPatch({ unlocked: 181, tips: ['zoom_tip', 'curve_tip', 'aim_suggest'], tutorialDone: [1, 2, 3], coins: 480, stars: Object.fromEntries(Array.from({ length: 180 }, (_, i) => [i + 1, 3 - (i % 4 === 3 ? 1 : 0)])) }); window.__ok.show('menu'); }, lang);
    await wait(300);
    const tag = `${W}x${H}-${dark ? 'dark' : 'light'}-${lang}`;
    const shot = async (name) => { await page.screenshot({ path: path.join(OUT, `${tag}-${name}.png`) }); };
    await shot('01-menu');
    await page.evaluate(() => window.__ok.show('map')); await wait(400); await shot('02-map');
    await page.evaluate((id) => window.__ok.startLevel(id), EASY); await wait(500); await shot('03-easy');
    await page.evaluate((id) => window.__ok.startLevel(id), XHARD); await wait(900); await shot('04-xhard-shaped');
    await page.evaluate(() => window.__ok.fit()); await wait(500); await shot('05-xhard-fit');
    await page.evaluate((id) => window.__ok.startLevel(id), XHARD_BIG); await wait(900); await shot('06-xhard-28x45');
    await page.evaluate(() => window.__ok.fit()); await wait(500); await shot('07-xhard-28x45-fit');
    // tek renk
    await page.evaluate(() => { window.__ok.debugPatch({ arrowColor: 'mono' }); });
    await page.evaluate((id) => window.__ok.startLevel(id), XHARD); await wait(700); await shot('08-mono-xhard');
    await page.evaluate(() => window.__ok.fit()); await wait(500); await shot('09-mono-xhard-fit');
    await page.evaluate((id) => window.__ok.startLevel(id), EASY); await wait(500); await shot('10-mono-easy');
    await page.evaluate(() => window.__ok.show('settings')); await wait(300);
    await page.evaluate(() => { const e = document.getElementById('ac-label'); if (e) e.scrollIntoView({ block: 'center' }); }); await wait(200); await shot('11-settings-arrow-color');
    await page.evaluate(() => { window.__ok.debugPatch({ arrowColor: 'color' }); });
    // kutlama: Aşırı zor kusursuz (altın alev + havai fişek)
    const win = async (id, crashes) => {
      await page.evaluate((id) => { window.__ok.startLevel(id); window.__ok.fastAnim(true); }, id); await wait(300);
      await page.evaluate(async (crashes) => {
        const sleep = ms => new Promise(r => setTimeout(r, ms));
        let guard = 0;
        for (let c = 0; c < crashes; c++) { // önce çarpma
          const g = window.__ok.game(); const blocked = g.alive.map((v, i) => v && !g.free.includes(i) ? i : -1).filter(i => i >= 0)[0];
          if (blocked >= 0) { while (window.__ok.busy()) await sleep(10); window.__ok.tapArrow(blocked); await sleep(60); }
        }
        while (!window.__ok.game().won && guard++ < 3000) {
          const g = window.__ok.game(); if (!g.free.length) break;
          if (window.__ok.busy()) { await sleep(5); continue; }
          window.__ok.tapArrow(g.free[0]); await sleep(3);
        }
      }, crashes);
      await page.waitForSelector('#end-sheet', { timeout: 15000 }); await page.evaluate(() => window.__ok.fastAnim(false)); await wait(1300);
    };
    await win(XHARD, 0); await shot('12-celebration-xhard-flawless');
    await win(EASY, 0); await shot('13-celebration-easy-flawless');
    await win(47, 2); await shot('14-celebration-hard-2lives');
    await ctx.close();
    console.log(tag, 'tamam');
  }
  await browser.close();
  if (errors.length) { console.log('KONSOL HATALARI:\n' + [...new Set(errors)].join('\n')); process.exit(1); }
  console.log('görüntüler: ' + OUT);
})().catch(e => { console.error(e); process.exit(2); });
