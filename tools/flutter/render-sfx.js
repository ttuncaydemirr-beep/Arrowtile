// Arrowtile -> Flutter: game/js/audio.js sentezini Chromium OfflineAudioContext ile WAV'a render eder.
// Çıktı: flutter/arrowtile/assets/sfx/*.wav (mono, 44,1 kHz, 16 bit). Math.random sabit tohumlu -> yeniden üretilebilir.
// Kullanım: node tools/flutter/render-sfx.js   (Playwright: /opt/npm-tools/node_modules/playwright, tarayıcı: /opt/pw-browsers)
'use strict';
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..', '..');
process.env.PLAYWRIGHT_BROWSERS_PATH = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/opt/npm-tools/node_modules/playwright');
const AUDIO_JS = fs.readFileSync(path.join(ROOT, 'game', 'js', 'audio.js'), 'utf8');
const OUT = path.join(ROOT, 'flutter', 'arrowtile', 'assets', 'sfx');
const SR = 44100, SECONDS = 1.6;
// [dosya adı, SFX çağrısı] — slide_out_N: ardışık çıkış perdesi 0 / 0,5 / 1 (main.js: Math.min(1, exitStreak / 6))
const JOBS = [
  ['tap', 'SFX.tap()'], ['slide_out_0', 'SFX.slideOut(0)'], ['slide_out_1', 'SFX.slideOut(0.5)'], ['slide_out_2', 'SFX.slideOut(1)'],
  ['bump', 'SFX.bump()'], ['level_win', 'SFX.levelWin()'], ['star_0', 'SFX.star(0)'], ['star_1', 'SFX.star(1)'], ['star_2', 'SFX.star(2)'],
  ['coin', 'SFX.coin()'], ['button', 'SFX.button()'], ['error', 'SFX.error()'], ['hint', 'SFX.hint()']
];
function wav(samples) {
  const n = samples.length, buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8); buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22); buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2);
  return buf;
}
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
  let total = 0;
  for (const [name, call] of JOBS) {
    const page = await browser.newPage();
    await page.setContent('<!doctype html><html><body></body></html>');
    const data = await page.evaluate(async ({ audioJs, call, SR, SECONDS }) => {
      // belirlenimci gürültü: Math.random yerine sabit tohumlu LCG
      let s = 123456789; Math.random = function () { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; };
      const off = new OfflineAudioContext(1, Math.ceil(SR * SECONDS), SR);
      off.resume = function () { return Promise.resolve(); };
      window.AudioContext = function () { return off; };
      (0, eval)(audioJs); // window.SFX tanımlanır
      if (!window.SFX.init()) throw new Error('SFX.init başarısız');
      (0, eval)(call);
      const buf = await off.startRendering();
      return Array.from(buf.getChannelData(0));
    }, { audioJs: AUDIO_JS, call, SR, SECONDS });
    await page.close();
    // sondaki sessizliği kırp (eşik 0,0008), 15 ms sönüm payı bırak
    let end = data.length; while (end > 0 && Math.abs(data[end - 1]) < 0.0008) end--;
    end = Math.min(data.length, end + Math.round(SR * 0.015));
    const peak = data.slice(0, end).reduce((m, v) => Math.max(m, Math.abs(v)), 0);
    if (!(peak > 0.02) || end < SR * 0.03) throw new Error(`${name}: sessiz çıktı (tepe ${peak}, ${end} örnek)`);
    const file = path.join(OUT, name + '.wav'); fs.writeFileSync(file, wav(data.slice(0, end)));
    total += fs.statSync(file).size;
    console.log(`${name}.wav  ${(end / SR * 1000).toFixed(0)} ms  tepe ${peak.toFixed(3)}  ${fs.statSync(file).size} bayt`);
  }
  await browser.close();
  console.log(`toplam ${JOBS.length} dosya, ${(total / 1024).toFixed(0)} KB -> ${path.relative(ROOT, OUT)}`);
})().catch(e => { console.error(e); process.exit(1); });
