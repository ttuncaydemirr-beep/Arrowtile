// Arrowtile — reklam/satın alma kuralları birim testi (sahte saat + sahte Android köprüsü).
// Kullanım: node tools/test-ads.js
'use strict';
const path = require('path');
const { create, RULES } = require(path.join(__dirname, '..', 'game', 'js', 'ads.js'));

let pass = 0, fail = 0;
function check(name, cond, extra) { if (cond) pass++; else fail++; console.log(`${cond ? 'GEÇTİ' : 'KALDI'}  ${name}${extra ? '  (' + extra + ')' : ''}`); }

// Sahte ortam: saat elle ilerler, zamanlayıcılar elle tetiklenir, köprü kayıt tutar
function harness(opts = {}) {
  let t = 1_000_000, timers = [], online = opts.online !== false;
  const calls = [];
  const bridge = opts.noBridge ? null : {
    adFree: !!opts.adFree, autoClose: opts.autoClose !== false, startOk: opts.startOk !== false,
    isAdFree() { return this.adFree; },
    isOnline() { return online; },
    isRewardedReady() { return opts.rewardedReady !== false; },
    showInterstitial(id) { calls.push(['interstitial', id]); if (!this.startOk) return false; if (this.autoClose) queue.push({ id, event: 'closed' }); return true; },
    showRewarded(id, pl) { calls.push(['rewarded', id, pl]); if (opts.rewardOutcome !== 'skip') queue.push({ id, event: 'rewarded' }); queue.push({ id, event: 'closed' }); return true; },
    purchaseRemoveAds(id) { calls.push(['purchase', id]); queue.push({ id, event: opts.purchase || 'purchased' }); return true; },
    restorePurchases(id) { calls.push(['restore', id]); queue.push({ id, event: 'restored', adFree: !!opts.owned }); return true; }
  };
  const queue = [];
  const env = {
    now: () => t, bridge: () => bridge, online: () => online,
    setTimeout: (f, ms) => { const h = { f, at: t + ms }; timers.push(h); return h; },
    clearTimeout: h => { timers = timers.filter(x => x !== h); }
  };
  const M = create(env);
  const state = { ads: undefined }; let saves = 0;
  M.attach(() => state, () => saves++);
  const flush = () => { while (queue.length) M.onNative(JSON.stringify(queue.shift())); };
  return { M, state, calls, bridge, flush, queue, advance: ms => { t += ms; const due = timers.filter(h => h.at <= t); timers = timers.filter(h => h.at > t); due.forEach(h => h.f()); }, setOnline: v => { online = v; }, saves: () => saves };
}
const MIN = 60 * 1000;

// 1) Bölüm 1 tamamen reklamsız
{
  const h = harness(); let shown = 0;
  for (let id = 1; id <= 12; id++) { h.M.onLevelComplete(id); h.M.continueAfterLevel(id, s => { if (s) shown++; }); h.flush(); h.advance(10 * MIN); }
  check('seviye 1-12: hiç geçiş reklamı yok, sayaç ilerlemez', shown === 0 && h.calls.length === 0 && (h.state.ads.since | 0) === 0);
}
// 2) En erken her 3 tamamlanan seviyede bir
{
  const h = harness(); const shownAt = [];
  for (let id = 13; id <= 24; id++) { h.M.onLevelComplete(id); h.M.continueAfterLevel(id, s => { if (s) shownAt.push(id); }); h.flush(); h.advance(5 * MIN); }
  check('13+ seviyelerde her 3 tamamlamada bir reklam (15, 18, 21, 24)', JSON.stringify(shownAt) === '[15,18,21,24]', shownAt.join(','));
}
// 3) İki reklam arası en az 3 dakika
{
  const h = harness(); const shownAt = [];
  for (let id = 13; id <= 30; id++) { h.M.onLevelComplete(id); h.M.continueAfterLevel(id, s => { if (s) shownAt.push(id); }); h.flush(); h.advance(30 * 1000); }
  // 3 seviye = 1,5 dk < 3 dk; 15'te ilk reklam, sonra 6 seviye (3 dk) beklenir
  check('reklamlar arası ≥ 3 dk (30 sn/seviye hızında 15, 21, 27)', JSON.stringify(shownAt) === '[15,21,27]', shownAt.join(','));
  h.advance(0);
}
// 4) Başarısız deneme sayılmaz (onLevelComplete yalnızca başarıda çağrılır) + sayaç kayıtta tutulur
{
  const h = harness();
  h.M.onLevelComplete(13); h.M.onLevelComplete(14);
  check('sayaç kayıtta (state.ads.since) tutulur ve kaydedilir', h.state.ads.since === 2 && h.saves() >= 2);
  let shown = null; h.M.continueAfterLevel(14, s => { shown = s; }); h.flush();
  check('2 tamamlama sonrası reklam yok', shown === false && h.calls.length === 0);
}
// 5) Çevrimdışı / köprü yok → reklam yok, oyun hemen devam eder
{
  const h = harness(); h.setOnline(false);
  for (let id = 13; id <= 15; id++) h.M.onLevelComplete(id);
  let cbs = 0; h.M.continueAfterLevel(15, () => cbs++);
  check('çevrimdışı: reklam çağrılmaz, devam geri çağrısı hemen ve bir kez', cbs === 1 && h.calls.length === 0);
  h.setOnline(true); h.M.continueAfterLevel(15, () => cbs++); h.flush();
  check('internet gelince (sayaç korunmuştu) reklam gösterilir', cbs === 2 && h.calls.filter(c => c[0] === 'interstitial').length === 1);
  const n = harness({ noBridge: true }); for (let id = 13; id <= 15; id++) n.M.onLevelComplete(id);
  let c2 = 0, sh = null; n.M.continueAfterLevel(15, s => { c2++; sh = s; });
  check('köprü yok (web önizleme): reklam gösterilmez, oyun devam eder', c2 === 1 && sh === false);
}
// 6) Reklamları kaldır → geçiş reklamı yok; ödüllü reklam isteğe bağlı kalır
{
  const h = harness();
  let r = null; h.M.purchaseRemoveAds(x => { r = x; }); h.flush();
  check('satın alma: köprü "purchased" → reklamsız, kalıcı alan (state.ads.adFree)', r && r.ok && h.state.ads.adFree === true && h.calls.some(c => c[0] === 'purchase'));
  for (let id = 13; id <= 20; id++) { h.M.onLevelComplete(id); h.M.continueAfterLevel(id, () => {}); h.flush(); h.advance(10 * MIN); }
  check('reklamsız: hiç geçiş reklamı yok', !h.calls.some(c => c[0] === 'interstitial'));
  let rew = 0, done = null; h.M.showRewarded('hint', () => rew++, x => { done = x; }); h.flush();
  check('reklamsız sürümde ödüllü reklam isteğe bağlı çalışır', rew === 1 && done === true);
  const h2 = harness({ adFree: true });
  for (let id = 13; id <= 16; id++) h2.M.onLevelComplete(id);
  check('köprü isAdFree()=true (yeniden kurulum) → reklam yok ve kayda işlenir', !h2.M.interstitialDue(16) && h2.state.ads.adFree === true);
}
// 7) Satın alma iptal / hata / zaman aşımı
{
  const h = harness({ purchase: 'cancelled' }); let r = null;
  h.M.purchaseRemoveAds(x => { r = x; }); h.flush();
  check('satın alma iptal: reklamsız olmaz', r && !r.ok && r.reason === 'cancelled' && !(h.state.ads && h.state.ads.adFree));
  const h2 = harness(); h2.bridge.purchaseRemoveAds = id => true; // yanıt hiç gelmez
  let r2 = null; h2.M.purchaseRemoveAds(x => { r2 = x; }); h2.advance(RULES.nativeTimeoutMs + 1);
  check('satın alma yanıtı gelmezse zaman aşımı, oyun takılmaz', r2 && !r2.ok && r2.reason === 'timeout' && h2.M._pending() === 0);
}
// 8) Geri yükleme
{
  const h = harness({ owned: true }); let r = null;
  h.M.restorePurchases(x => { r = x; }); h.flush();
  check('geri yükleme: Play sahipliği bildirirse reklamsız', r && r.ok && r.adFree && h.state.ads.adFree);
  const h2 = harness({ owned: false }); let r2 = null;
  h2.M.restorePurchases(x => { r2 = x; }); h2.flush();
  check('geri yükleme: sahiplik yoksa durum değişmez', r2 && r2.ok && !r2.adFree && !(h2.state.ads && h2.state.ads.adFree));
}
// 9) Test modu (köprü yok): satın alma taklit edilir
{
  const h = harness({ noBridge: true }); let r = null;
  h.M.purchaseRemoveAds(x => { r = x; });
  check('köprü yok: satın alma test modunda taklit edilir', r && r.ok && r.test && h.state.ads.adFree && h.state.ads.test);
  let rr = null; h.M.restorePurchases(x => { rr = x; });
  check('köprü yok: geri yükleme test durumunu döndürür', rr && rr.ok && rr.adFree && rr.test);
  check('köprü yok: ödüllü reklam sunulmaz', !h.M.rewardedAvailable());
}
// 9b) Web önizlemede test modunda "satın alınan" reklamsızlık gerçek köprü varken geçersiz
{
  const h = harness();
  h.state.ads = { since: 3, lastAt: 0, adFree: true, test: true };
  check('test modu reklamsızlığı gerçek köprüde geçerli sayılmaz (reklam gösterilir)', !h.M.isAdFree() && h.M.interstitialDue(15));
}
// 10) Geçiş reklamı kapanmazsa zaman aşımı; devam geri çağrısı tek sefer
{
  const h = harness({ autoClose: false }); for (let id = 13; id <= 15; id++) h.M.onLevelComplete(id);
  let cbs = 0; h.M.continueAfterLevel(15, () => cbs++);
  check('reklam açıkken oyun bekler (devam henüz çağrılmadı)', cbs === 0);
  h.advance(RULES.nativeTimeoutMs + 1);
  check('yerel taraf yanıt vermezse zaman aşımıyla devam (tek sefer)', cbs === 1);
  h.M.onNative({ id: 1, event: 'closed' });
  check('geç gelen "closed" ikinci kez devam ettirmez', cbs === 1);
  const h2 = harness({ startOk: false }); for (let id = 13; id <= 15; id++) h2.M.onLevelComplete(id);
  let c2 = 0; h2.M.continueAfterLevel(15, () => c2++);
  check('reklam başlatılamazsa (doldurulamadı) hemen devam, sayaç sıfırlanmaz', c2 === 1 && h2.state.ads.since === 3);
}
// 11) Ödüllü reklam: izlenmeden kapatılırsa ödül yok
{
  const h = harness({ rewardOutcome: 'skip' }); let rew = 0, done = null;
  h.M.showRewarded('life', () => rew++, x => { done = x; }); h.flush();
  check('ödüllü reklam yarıda kapatılırsa ödül verilmez', rew === 0 && done === false);
  const h2 = harness({ rewardedReady: false });
  check('ödüllü reklam hazır değilse sunulmaz', !h2.M.rewardedAvailable());
}
// 12) Bozuk/yabancı yerel mesajlar güvenle yok sayılır
{
  const h = harness();
  check('bozuk JSON / bilinmeyen kimlik yok sayılır', h.M.onNative('{bozuk') === false && h.M.onNative({ id: 999, event: 'closed' }) === false);
}
// 13) API: geçiş reklamı yalnızca seviye sonundan
{
  const h = harness();
  const keys = Object.keys(h.M).filter(k => /interstitial/i.test(k));
  check('geçiş reklamı gösteren tek genel yol continueAfterLevel', !keys.some(k => k !== 'interstitialDue') && typeof h.M.continueAfterLevel === 'function');
}

// 14) Bekleyen (pending) satın alma: reklamsızlık VERİLMEZ, neden 'pending'
{
  const h = harness({ purchase: 'pending' }); let r = null;
  h.M.purchaseRemoveAds(x => { r = x; }); h.flush();
  check('bekleyen satın alma: hak verilmez, neden pending', r && r.ok === false && r.reason === 'pending' && !h.state.ads.adFree);
}
// 15) Gizlilik seçenekleri (UMP): köprü yoksa ya da gerekmiyorsa gizli; varsa form açılır ve kapanınca cb
{
  const h0 = harness({ noBridge: true });
  check('gizlilik seçenekleri: köprü yoksa gerekli değil', h0.M.privacyOptionsRequired() === false);
  const h = harness();
  check('gizlilik seçenekleri: köprü privacyOptionsRequired sağlamıyorsa gizli', h.M.privacyOptionsRequired() === false);
  h.bridge.privacyOptionsRequired = () => true;
  h.bridge.showPrivacyOptions = id => { h.calls.push(['privacy', id]); h.queue.push({ id, event: 'closed' }); return true; };
  let closed = 0;
  const ok = h.M.showPrivacyOptions(() => closed++); h.flush();
  check('gizlilik seçenekleri: form açılır, kapanınca cb bir kez', ok === true && closed === 1 && h.calls.some(c => c[0] === 'privacy'));
}

// 16) v1.4 — ödüllü reklam dokunuşta yüklenir: düğme görünürlüğü önceden yüklenmeye bağlı değil
{
  const h = harness({ rewardedReady: false });
  check('ödüllü düğmeler görünür (rewardedOffered) — hazır olmasa da', h.M.rewardedAvailable() === false && h.M.rewardedOffered() === true);
  let r = null; h.M.ensureRewardedLoaded(x => { r = x; });
  check('hazır değil + köprü yüklemeyi desteklemiyor: ok=false, code=unavailable, cb bir kez', r && r.ok === false && r.code === 'unavailable');
  const h2 = harness({ rewardedReady: false }); h2.bridge.loadRewarded = id => { h2.calls.push(['load', id]); h2.queue.push({ id, event: 'loaded' }); return true; };
  let r2 = null; h2.M.ensureRewardedLoaded(x => { r2 = x; }); h2.flush();
  check('köprü loadRewarded: "loaded" → ok=true', r2 && r2.ok === true && h2.calls.some(c => c[0] === 'load'));
  const h3 = harness({ rewardedReady: false }); h3.bridge.loadRewarded = id => { h3.queue.push({ id, event: 'failed', code: 3 }); return true; };
  let r3 = null; h3.M.ensureRewardedLoaded(x => { r3 = x; }); h3.flush();
  check('köprü loadRewarded: "failed" kodu iletilir', r3 && r3.ok === false && r3.code === '3');
  const h4 = harness({ rewardedReady: false }); h4.bridge.loadRewarded = id => true; // yanıt gelmez
  let n4 = 0, r4 = null; h4.M.ensureRewardedLoaded(x => { n4++; r4 = x; }); h4.advance(RULES.nativeTimeoutMs + 1);
  check('yükleme yanıtı gelmezse zaman aşımı (code=timeout), cb tam bir kez, bekleyen yok', n4 === 1 && r4.code === 'timeout' && h4.M._pending() === 0);
  const h5 = harness({ rewardedReady: true }); let r5 = null; h5.M.ensureRewardedLoaded(x => { r5 = x; });
  check('hazırsa hemen ok', r5 && r5.ok === true && h5.calls.length === 0);
  const h6 = harness({ rewardedReady: false, online: false }); let r6 = null; h6.M.ensureRewardedLoaded(x => { r6 = x; });
  check('çevrimdışı + yükleme desteği yok: code=offline', r6 && r6.ok === false && r6.code === 'offline');
}
// 17) v1.4 — köprü yok (web önizleme test modu): ödüllü reklam taklit edilir, ödül bir kez, onDone bir kez
{
  const h = harness({ noBridge: true });
  check('test modunda düğmeler görünür', h.M.rewardedOffered() === true);
  let e = null; h.M.ensureRewardedLoaded(x => { e = x; });
  check('test modunda ensureRewardedLoaded hemen ok (test)', e && e.ok && e.test);
  let rew = 0, done = [], started = h.M.showRewarded('coins', () => rew++, x => done.push(x));
  check('taklit: gecikme dolmadan ödül yok', started === true && rew === 0 && done.length === 0);
  h.advance(RULES.testRewardMs + 1);
  check('taklit: gecikme sonrası ödül tam bir kez, onDone(true) tam bir kez', rew === 1 && done.length === 1 && done[0] === true);
}
// 18) v1.4 — jeton kuralı (storage.js): +50, günde 10, yerel gün, saat geri, sıfırlama hakkı yenilemez, kayıt onarımı
{
  const fs = require('fs'), vm = require('vm');
  const mem = {};
  const ls = { getItem: k => (k in mem ? mem[k] : null), setItem: (k, v) => { mem[k] = String(v); }, removeItem: k => { delete mem[k]; } };
  const ctx = { window: { LEVELS: [] }, localStorage: ls, location: { search: '' }, navigator: { languages: ['en-US'], language: 'en-US' }, console, JSON, Math, Date, Object, Array, Number, String, isFinite, TextEncoder, TextDecoder, btoa: x => Buffer.from(x, 'binary').toString('base64'), atob: x => Buffer.from(x, 'base64').toString('binary'), unescape, escape, encodeURIComponent, decodeURIComponent, parseInt, RegExp, Uint8Array };
  ctx.window.window = ctx.window; vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'game', 'js', 'storage.js'), 'utf8'), ctx);
  const S = ctx.window.Store; S.load();
  check('sabitler: +50 jeton (= ipucu fiyatı), günde 10', S.AD_COINS === 50 && S.AD_COINS === S.PRICES.hint && S.MAX_COIN_ADS === 10);
  check('yeni kayıt: hak 10', S.coinAdsLeft('2026-11-04') === 10 && S.get().ads.coinDate === null && S.get().ads.coinCount === 0);
  let total = 0; for (let i = 0; i < 10; i++) total += S.grantAdCoins('2026-11-04');
  check('10 izleme = +500 jeton, hak 0', total === 500 && S.get().coins === 550 && S.coinAdsLeft('2026-11-04') === 0);
  check('11. izleme jeton vermez', S.grantAdCoins('2026-11-04') === 0 && S.get().coins === 550);
  check('saat geri alınırsa hak yenilenmez', S.coinAdsLeft('2026-11-03') === 0 && S.grantAdCoins('2026-11-03') === 0);
  check('ertesi gün hak yenilenir (10), sayaç 1', S.coinAdsLeft('2026-11-05') === 10 && S.grantAdCoins('2026-11-05') === 50 && S.get().ads.coinDate === '2026-11-05' && S.get().ads.coinCount === 1 && S.coinAdsLeft('2026-11-05') === 9);
  S.resetProgress();
  check('ilerlemeyi sıfırlamak hakkı yenilemez (jeton 50\'ye döner)', S.get().coins === 50 && S.get().ads.coinDate === '2026-11-05' && S.get().ads.coinCount === 1);
  const sn = S.sanitize({ ads: { coinDate: '4.11.2026', coinCount: -3 } });
  check('sanitize: bozuk coinDate → null, negatif sayaç → 0', sn.ads.coinDate === null && sn.ads.coinCount === 0);
  const sn2 = S.sanitize({ ads: { coinDate: '2026-11-04', coinCount: 5000 } });
  check('sanitize: sayaç üst sınırı 1000, hak 0', sn2.ads.coinCount === 1000 && sn2.ads.coinDate === '2026-11-04');
  const sn3 = S.sanitize({ ads: { since: 1 } });
  check('sanitize: eski kayıt (alan yok) → coinDate null, coinCount 0', sn3.ads.coinDate === null && sn3.ads.coinCount === 0);
}

console.log(`\n${fail ? fail + ' KALDI, ' : ''}${pass} GEÇTİ (reklam/satın alma birim testi)`);
process.exit(fail ? 1 : 0);
