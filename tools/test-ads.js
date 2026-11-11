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
    ...(opts.preload ? {
      loadRewarded(id) { calls.push(['loadRewarded', id]); if (opts.loadHold) held.push(id); else queue.push({ id, event: opts.loadFail ? 'failed' : 'loaded', code: 3 }); return true; },
      loadInterstitial(id) { calls.push(['loadInterstitial', id]); if (opts.loadHold) held.push(id); else queue.push({ id, event: opts.loadFail ? 'failed' : 'loaded', code: 3 }); return true; },
      isInterstitialReady() { return !!opts.interstitialReady; }
    } : {}),
    releaseInterstitial(id) { calls.push(['release', id]); },
    releaseRewarded(id) { calls.push(['releaseR', id]); },
    showInterstitial(id) { calls.push(['interstitial', id]); if (!this.startOk) return false; if (this.autoClose) queue.push({ id, event: 'closed' }); return true; },
    showRewarded(id, pl) { calls.push(['rewarded', id, pl]); if (opts.rewardOutcome !== 'skip') queue.push({ id, event: 'rewarded' }); queue.push({ id, event: 'closed' }); return true; },
    purchaseRemoveAds(id) { calls.push(['purchase', id]); queue.push({ id, event: opts.purchase || 'purchased' }); return true; },
    restorePurchases(id) { calls.push(['restore', id]); queue.push({ id, event: 'restored', adFree: !!opts.owned }); return true; }
  };
  const queue = [], held = [];
  const env = {
    now: () => t, bridge: () => bridge, online: () => online,
    setTimeout: (f, ms) => { const h = { f, at: t + ms }; timers.push(h); return h; },
    clearTimeout: h => { timers = timers.filter(x => x !== h); }
  };
  const M = create(env);
  const state = { ads: undefined }; let saves = 0;
  M.attach(() => state, () => saves++);
  const flush = () => { while (queue.length) M.onNative(JSON.stringify(queue.shift())); };
  return { M, state, calls, bridge, flush, queue, held, advance: ms => { t += ms; const due = timers.filter(h => h.at <= t); timers = timers.filter(h => h.at > t); due.forEach(h => h.f()); }, setOnline: v => { online = v; }, saves: () => saves };
}
const MIN = 60 * 1000;
// seviye sonu yerleştirmesini açıp devam eder (1.1.3: belirteç zorunlu)
const CL = (h, id, cb) => h.M.continueAfterLevel(id, cb, h.M.openLevelEnd(id));

// 1) Bölüm 1 tamamen reklamsız
{
  const h = harness(); let shown = 0;
  for (let id = 1; id <= 12; id++) { h.M.onLevelComplete(id); CL(h, id, s => { if (s) shown++; }); h.flush(); h.advance(10 * MIN); }
  check('seviye 1-12: hiç geçiş reklamı yok, sayaç ilerlemez', shown === 0 && h.calls.length === 0 && (h.state.ads.since | 0) === 0);
}
// 2) En erken her 3 tamamlanan seviyede bir
{
  const h = harness(); const shownAt = [];
  for (let id = 13; id <= 24; id++) { h.M.onLevelComplete(id); CL(h, id, s => { if (s) shownAt.push(id); }); h.flush(); h.advance(5 * MIN); }
  check('13+ seviyelerde her 3 tamamlamada bir reklam (15, 18, 21, 24)', JSON.stringify(shownAt) === '[15,18,21,24]', shownAt.join(','));
}
// 3) İki reklam arası en az 3 dakika
{
  const h = harness(); const shownAt = [];
  for (let id = 13; id <= 30; id++) { h.M.onLevelComplete(id); CL(h, id, s => { if (s) shownAt.push(id); }); h.flush(); h.advance(30 * 1000); }
  // 3 seviye = 1,5 dk < 3 dk; 15'te ilk reklam, sonra 6 seviye (3 dk) beklenir
  check('reklamlar arası ≥ 3 dk (30 sn/seviye hızında 15, 21, 27)', JSON.stringify(shownAt) === '[15,21,27]', shownAt.join(','));
  h.advance(0);
}
// 4) Başarısız deneme sayılmaz (onLevelComplete yalnızca başarıda çağrılır) + sayaç kayıtta tutulur
{
  const h = harness();
  h.M.onLevelComplete(13); h.M.onLevelComplete(14);
  check('sayaç kayıtta (state.ads.since) tutulur ve kaydedilir', h.state.ads.since === 2 && h.saves() >= 2);
  let shown = null; CL(h, 14, s => { shown = s; }); h.flush();
  check('2 tamamlama sonrası reklam yok', shown === false && h.calls.length === 0);
}
// 5) Çevrimdışı / köprü yok → reklam yok, oyun hemen devam eder
{
  const h = harness(); h.setOnline(false);
  for (let id = 13; id <= 15; id++) h.M.onLevelComplete(id);
  let cbs = 0; CL(h, 15, () => cbs++);
  check('çevrimdışı: reklam çağrılmaz, devam geri çağrısı hemen ve bir kez', cbs === 1 && h.calls.length === 0);
  h.setOnline(true); CL(h, 15, () => cbs++); h.flush();
  check('internet gelince (sayaç korunmuştu) reklam gösterilir', cbs === 2 && h.calls.filter(c => c[0] === 'interstitial').length === 1);
  const n = harness({ noBridge: true }); for (let id = 13; id <= 15; id++) n.M.onLevelComplete(id);
  let c2 = 0, sh = null; CL(n, 15, s => { c2++; sh = s; });
  check('köprü yok (web önizleme): reklam gösterilmez, oyun devam eder', c2 === 1 && sh === false);
}
// 6) Reklamları kaldır → geçiş reklamı yok; ödüllü reklam isteğe bağlı kalır
{
  const h = harness();
  let r = null; h.M.purchaseRemoveAds(x => { r = x; }); h.flush();
  check('satın alma: köprü "purchased" → reklamsız, kalıcı alan (state.ads.adFree)', r && r.ok && h.state.ads.adFree === true && h.calls.some(c => c[0] === 'purchase'));
  for (let id = 13; id <= 20; id++) { h.M.onLevelComplete(id); CL(h, id, () => {}); h.flush(); h.advance(10 * MIN); }
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
  let cbs = 0; CL(h, 15, () => cbs++);
  check('reklam açıkken oyun bekler (devam henüz çağrılmadı)', cbs === 0);
  h.advance(RULES.nativeTimeoutMs + 1);
  check('1.1.4: yerel taraf yanıt vermezse süre sınırıyla DEVAM EDİLMEZ (sonraki seviye reklam bitmeden başlamaz)', cbs === 0 && h.M.adHoldActive());
  h.M.appHidden(); h.M.appResumed(); h.advance(RULES.returnGraceMs + 1);
  check('1.1.4: uygulamadan çıkıp dönünce devam (tek sefer), köprüye releaseInterstitial', cbs === 1 && !h.M.adHoldActive() && h.calls.some(c => c[0] === 'release'));
  h.M.onNative({ id: 1, event: 'closed' });
  check('geç gelen "closed" ikinci kez devam ettirmez', cbs === 1);
  const h2 = harness({ startOk: false }); for (let id = 13; id <= 15; id++) h2.M.onLevelComplete(id);
  let c2 = 0; CL(h2, 15, () => c2++);
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
  check('geçiş reklamı gösteren tek genel yol continueAfterLevel', !keys.some(k => !['interstitialDue', 'preloadInterstitial', 'interstitialWillBeDue'].includes(k)) && typeof h.M.continueAfterLevel === 'function');
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


// 16) Banner (docs/15 §3): yalnızca Ana menü ve Harita; oyun, seviye sonu, mağaza, ayarlar, günlük bulmaca ve gizlilikte yok; reklamsızda hiç yok
{
  const h = harness();
  const vis = ['menu', 'map', 'game', 'end', 'shop', 'settings', 'daily', 'privacy', 'dp'].filter(n => h.M.bannerVisible(n));
  check('banner yalnızca menu + map ekranlarında', JSON.stringify(vis) === '["menu","map"]', vis.join(','));
  check('banner ekran listesi sabit: menu, map', JSON.stringify(h.M.BANNER_SCREENS) === '["menu","map"]');
  // "Reklamları kaldır" (web test modu): banner kapanır
  const t = harness({ noBridge: true });
  check('web test modunda banner menu/map görünür (reklamsız değil)', t.M.bannerVisible('menu') && t.M.bannerVisible('map') && t.M.isTestMode());
  let r = null; t.M.purchaseRemoveAds(x => { r = x; });
  check('reklamsız satın alma sonrası banner hiçbir ekranda yok', r && r.ok && !t.M.bannerVisible('menu') && !t.M.bannerVisible('map'));
  const owned = harness({ adFree: true });
  check('Play sahipliği (isAdFree) varsa banner yok', !owned.M.bannerVisible('menu') && !owned.M.bannerVisible('map'));
}
// 17) Önceden yükleme — ödüllü (docs/15 §4)
{
  const h = harness({ preload: true, rewardedReady: false });
  check('ödüllü: oyun açılınca yükleme başlar', h.M.preloadRewarded() === 'started' && h.calls.filter(c => c[0] === 'loadRewarded').length === 1);
  check('ödüllü: zaten yükleniyorsa tekrar başlatılmaz', h.M.preloadRewarded() === 'loading' && h.calls.filter(c => c[0] === 'loadRewarded').length === 1 && h.M.rewardedLoading());
  // oyuncu yükleme sürerken reklam isterse AYNI yüklemeye katılır (ikinci yükleme yok)
  let res = null; h.M.ensureRewardedLoaded(r => { res = r; });
  check('ödüllü: bekleyen önceden yükleme paylaşılır (ikinci loadRewarded yok)', h.calls.filter(c => c[0] === 'loadRewarded').length === 1 && res === null);
  h.flush();
  check('ödüllü: yükleme bitince bekleyen cb çağrılır, yükleniyor değil', res && res.ok === true && !h.M.rewardedLoading());
  const r = harness({ preload: true, rewardedReady: true });
  check('ödüllü: zaten hazırsa yükleme başlatılmaz', r.M.preloadRewarded() === 'ready' && r.calls.length === 0);
  const f = harness({ preload: true, rewardedReady: false, loadFail: true });
  f.M.preloadRewarded(); f.flush();
  check('ödüllü: başarısız yükleme sonrası 20 sn içinde tekrar denenmez', f.M.preloadRewarded() === 'wait' && f.calls.length === 1);
  f.advance(21 * 1000);
  check('ödüllü: 20 sn sonra yeniden denenir', f.M.preloadRewarded() === 'started' && f.calls.length === 2);
  const o = harness({ preload: true, rewardedReady: false, online: false });
  check('ödüllü: çevrimdışıyken yükleme denenmez', o.M.preloadRewarded() === 'skip' && o.calls.length === 0);
  const nb = harness({ noBridge: true });
  check('ödüllü: köprü yoksa (web test modu) yükleme yok', nb.M.preloadRewarded() === 'skip');
  const hold = harness({ preload: true, rewardedReady: false, loadHold: true });
  hold.M.preloadRewarded(); hold.advance(RULES.nativeTimeoutMs + 1);
  check('ödüllü: yanıt gelmezse zaman aşımı sonrası yükleniyor durumu temizlenir', !hold.M.rewardedLoading());
  check('"Reklam yükleniyor…" eşiği 300 ms', RULES.loadingOverlayMs === 300);
}
// 18) Önceden yükleme — geçiş reklamı: seviye bitmeden, yalnızca gerekecekse; hazır/yükleniyorsa tekrar yok
{
  const h = harness({ preload: true });
  for (let id = 13; id <= 14; id++) h.M.onLevelComplete(id);
  check('geçiş: 3. tamamlamadan önceki seviyede (sayaç 2) yükleme gerekir', h.M.interstitialWillBeDue(15) === true);
  check('geçiş: seviye 15 son oklar çıkarken yükleme başlar', h.M.preloadInterstitial(15) === 'started' && h.calls.filter(c => c[0] === 'loadInterstitial').length === 1);
  check('geçiş: yüklenirken tekrar başlatılmaz', h.M.preloadInterstitial(15) === 'loading' && h.calls.filter(c => c[0] === 'loadInterstitial').length === 1);
  h.flush();
  const none = harness({ preload: true });
  check('geçiş: sayaç yetersizken (1. seviye sonrası) yükleme yok', none.M.preloadInterstitial(13) === 'skip' && none.calls.length === 0);
  const free = harness({ preload: true });
  for (let id = 1; id <= 12; id++) free.M.onLevelComplete(id);
  check('geçiş: seviye 1-12 için yükleme yok', free.M.preloadInterstitial(12) === 'skip' && free.calls.length === 0);
  const af = harness({ preload: true, adFree: true });
  for (let id = 13; id <= 14; id++) af.M.onLevelComplete(id);
  check('geçiş: reklamsızda yükleme yok', af.M.preloadInterstitial(15) === 'skip' && af.calls.length === 0);
  const rdy = harness({ preload: true, interstitialReady: true });
  for (let id = 13; id <= 14; id++) rdy.M.onLevelComplete(id);
  check('geçiş: zaten hazırsa yükleme yok', rdy.M.preloadInterstitial(15) === 'ready' && rdy.calls.length === 0);
  const nb = harness({ noBridge: true });
  check('geçiş: köprü yoksa yükleme yok', nb.M.preloadInterstitial(15) === 'skip');
  // kural değişmedi: önceden yükleme sayaç/aralık durumunu etkilemez
  const cnt = harness({ preload: true }); cnt.M.onLevelComplete(13); cnt.M.onLevelComplete(14);
  const before = JSON.stringify(cnt.state.ads); cnt.M.preloadInterstitial(15); cnt.flush();
  check('geçiş: önceden yükleme sayaç/son gösterim zamanını değiştirmez', JSON.stringify(cnt.state.ads) === before);
}
// 19) Reklam gösterilirken oyun ve ses duraklar (dinleyici): geçiş + ödüllü (köprülü ve test modu)
{
  const h = harness(); const ev = [];
  h.M.setAdListener(a => ev.push(a));
  for (let id = 13; id <= 15; id++) h.M.onLevelComplete(id);
  CL(h, 15, () => {});
  check('geçiş reklamı açılınca dinleyici true', JSON.stringify(ev) === '[true]' && h.M.isAdShowing());
  h.flush();
  check('geçiş reklamı kapanınca dinleyici false', JSON.stringify(ev) === '[true,false]' && !h.M.isAdShowing());
  const t = harness({ noBridge: true }); const ev2 = [];
  t.M.setAdListener(a => ev2.push(a));
  t.M.showRewarded('hint', () => {}, () => {});
  check('test modu ödüllü: reklam süresince duraklatma', JSON.stringify(ev2) === '[true]');
  t.advance(RULES.testRewardMs + 1);
  check('test modu ödüllü: bitince devam', JSON.stringify(ev2) === '[true,false]' && !t.M.isAdShowing());
  const w = harness(); const ev3 = [];
  w.M.setAdListener(a => ev3.push(a));
  w.M.showRewarded('life', () => {}, () => {}); w.flush();
  check('köprülü ödüllü: açılış true, kapanış false (tam bir kez)', JSON.stringify(ev3) === '[true,false]');
  const to = harness({ autoClose: false }); const ev4 = [];
  to.M.setAdListener(a => ev4.push(a));
  for (let id = 13; id <= 15; id++) to.M.onLevelComplete(id);
  CL(to, 15, () => {}); to.advance(RULES.nativeTimeoutMs + 1); to.M.appHidden(); to.M.appResumed(); to.advance(RULES.returnGraceMs + 1);
  check('yerel taraf yanıt vermezse uygulamadan dönüşte duraklatma kalkar', JSON.stringify(ev4) === '[true,false]' && !to.M.isAdShowing());
}
// 19b) docs/18 (1.1.1): geçiş reklamı denemesi ASLA oyunu tutmaz (seviye 15/16 → 17 donma raporu)
{
  const arm = o => { const x = harness(o); for (let id = 13; id <= 15; id++) x.M.onLevelComplete(id); return x; };
  // 1.1.4: geri çağrı hiç gelmez: bekleme sürer; 300 ms'de 'opening', holdMaxMs'de 'slow'; yalnızca bildirim perdesi (yumuşak) bitirmez
  const a = arm({ autoClose: false }); const ev = [], waits = []; let n = 0, last = null;
  a.M.setAdListener(x => ev.push(x)); a.M.setWaitListener(w => waits.push(w));
  CL(a, 15, s => { n++; last = s; });
  a.advance(RULES.loadingOverlayMs + 1);
  check('bekleme 300 ms\'yi aşınca "opening" bildirilir', waits.join() === 'opening' && n === 0);
  a.advance(RULES.holdMaxMs);
  check('holdMaxMs dolunca "slow" bildirilir, cb HÂLÂ çağrılmaz', waits.join() === 'opening,slow' && n === 0 && a.M.stuckCount() === 1 && a.M.isAdShowing());
  a.M.appHidden(false); a.M.appResumed(); a.advance(RULES.returnGraceMs + 1);
  check('yalnızca odak kaybı (reklam ekrana gelmemiş) beklemeyi bitirmez', n === 0);
  a.M.appHidden(); a.M.appResumed(); a.advance(RULES.returnGraceMs + 1);
  check('arka plandan dönüş: cb bir kez false, duraklatma kalkar, bekleyen yok, "none"', n === 1 && last === false && JSON.stringify(ev) === '[true,false]' && !a.M.isAdShowing() && a.M._pending() === 0 && waits[waits.length - 1] === 'none');
  a.M.onNative(JSON.stringify({ id: 1, event: 'closed' })); a.advance(RULES.nativeTimeoutMs);
  check('bırakıldıktan sonra gelen geç olay ikinci cb ya da duraklatma üretmez', n === 1 && JSON.stringify(ev) === '[true,false]');
  // gösterildi olayı gelirse oyuncu izliyor: kısa süre dolunca kesilmez, kapanışı bekler
  const b = arm({ autoClose: false }); const evb = []; let nb = 0, lb = null;
  b.M.setAdListener(x => evb.push(x));
  CL(b, 15, s => { nb++; lb = s; });
  b.M.onNative(JSON.stringify({ id: 1, event: 'shown' }));
  b.advance(RULES.holdMaxMs + 1000);
  check('"shown" geldi: izlenen reklam kesilmez', nb === 0 && b.M.isAdShowing());
  b.M.onNative(JSON.stringify({ id: 1, event: 'closed' }));
  check('"shown" sonrası "closed": cb true, duraklatma kalkar', nb === 1 && lb === true && JSON.stringify(evb) === '[true,false]');
  // "shown" geldi ama "closed" hiç gelmez: uygulama reklamdan dönünce (odak kaybı yeterli) biter, cb true
  const c = arm({ autoClose: false }); const evc = []; let nc = 0, lc = null;
  c.M.setAdListener(x => evc.push(x));
  CL(c, 15, s => { nc++; lc = s; });
  c.M.onNative(JSON.stringify({ id: 1, event: 'shown' })); c.advance(RULES.nativeTimeoutMs + 1);
  check('"shown" geldi, "closed" gelmedi: süreyle bitmez', nc === 0);
  c.M.appHidden(false); c.M.appResumed(); c.advance(RULES.returnGraceMs + 1);
  check('"shown" sonrası reklamdan dönüş: cb true, duraklatma kalkar, bekleyen yok', nc === 1 && lc === true && JSON.stringify(evc) === '[true,false]' && c.M._pending() === 0);
  // gösterilemedi
  const d = arm({ autoClose: false }); let nd = 0, ld = null;
  CL(d, 15, s => { nd++; ld = s; }); d.M.onNative(JSON.stringify({ id: 1, event: 'failed' })); d.advance(RULES.nativeTimeoutMs);
  check('gösterilemedi (failed): cb bir kez false', nd === 1 && ld === false && !d.M.isAdShowing());
  // köprü başlatamadı
  const e = arm({ startOk: false }); let ne = 0;
  CL(e, 15, () => { ne++; }); e.advance(RULES.nativeTimeoutMs);
  check('köprü başlatamadı: cb bir kez, duraklatma kalkar', ne === 1 && !e.M.isAdShowing());
}
// 20) Ekonomi (docs/15 §5): seviye çarpanları seviye bazında (1-3 ×1, 4-6 ×1,5, 7-8 ×2, 9-10 ×3), bölüm = 10 seviye, tek bölüm bonusu 150
{
  const fs = require('fs'), vm = require('vm');
  const store = {}; const ls = { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); }, removeItem: k => { delete store[k]; } };
  const ctx = { window: { LEVELS: [] }, localStorage: ls, location: { search: '' }, navigator: { languages: ['en-US'], language: 'en-US' }, console, JSON, Math, Date, Object, Array, Number, String, isFinite, TextEncoder, TextDecoder, btoa: x => Buffer.from(x, 'binary').toString('base64'), atob: x => Buffer.from(x, 'base64').toString('binary'), unescape, escape, encodeURIComponent, decodeURIComponent, parseInt, RegExp, Uint8Array };
  ctx.window.window = ctx.window; vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'game', 'js', 'storage.js'), 'utf8'), ctx);
  const S = ctx.window.Store; S.load();
  const LG = require(path.join(__dirname, '..', 'game', 'js', 'levelgen.js'));
  const mult = id => S.levelReward(id, 3) / 20;
  // 1.2.0 (docs/24): bölüm = 20 seviye; 5 Kolay (×1), 5 Orta (×1,5), 5 Zor (×2), 5 Aşırı zor (×3)
  const expect = [1, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5, 1.5, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3];
  check('seviye çarpanı bölüm içinde 5×1, 5×1.5, 5×2, 5×3 (1., 2., 50. bölüm)', [0, 20, 980].every(b => expect.every((m, k) => mult(b + k + 1) === m)));
  check('★/★★/★★★ taban 10/15/20 × çarpan (seviye 16: 30/45/60)', [1, 2, 3].map(st => S.levelReward(16, st)).join() === '30,45,60' && [1, 2, 3].map(st => S.levelReward(6, st)).join() === '15,23,30');
  check('Store.tierOfLevel == LevelGen.tierOf (ilk 600 seviye)', Array.from({ length: 600 }, (_, i) => i + 1).every(id => S.tierOfLevel(id) === LG.tierOf(id)));
  check('bölüm bonusu tek: 150 (tüm bölümler), bölüm = 20 seviye', S.CHAPTER_BONUS === 150 && S.chapterBonusFor(1) === 150 && S.chapterBonusFor(7) === 150 && S.chapterBonusFor(250) === 150 && S.PER_CHAPTER === 20);
  // bölüm 1: 19 seviye bitince bonus yok, 20. seviyede 150
  let bonuses = [];
  for (let id = 1; id <= 20; id++) { const r = S.completeLevel(id, 3, false); bonuses.push(r.bonus); }
  check('bölüm 1 bonusu yalnızca 20. seviyenin tamamlanmasında (+150), bir kez', bonuses.slice(0, 19).every(b => b === 0) && bonuses[19] === 150 && S.get().chapterBonus.join() === '1');
  const coins0 = S.get().coins; S.completeLevel(20, 3, false);
  check('aynı bölümün bonusu tekrar verilmez', S.get().coins === coins0 && S.get().chapterBonus.length === 1);
  // toplam kazanç bölüm 1 (tüm ★★★): 5×20 + 5×30 + 5×40 + 5×60 = 750 + 150 bonus; başlangıç 50
  check('bölüm 1 tüm ★★★: 50 + 750 + 150 = 950 jeton', coins0 === 50 + (5 * 20 + 5 * 30 + 5 * 40 + 5 * 60) + 150, String(coins0));
  S.completeLevel(21, 3, false);
  for (let id = 22; id <= 40; id++) S.completeLevel(id, 1, false);
  check('bölüm 2 bonusu da 150 (kademe fark etmez), 21. seviye 3 yıldız sonrası', S.get().chapterBonus.join() === '1,2' && S.get().unlocked === 41);
}

// 21) docs/20 (1.1.3): geç gelen reklam yok — yerleştirme belirteci, hazır değilse atla, bir kez göster, bırak, ses yalnızca ekrandayken
{
  const arm = o => { const x = harness(o); for (let id = 13; id <= 15; id++) x.M.onLevelComplete(id); return x; };
  const count = (h, n) => h.calls.filter(c => c[0] === n).length;
  // belirteç yok / geçersiz / kapalı → show çağrılmaz
  const a = arm(); let na = 0;
  a.M.continueAfterLevel(15, () => na++);
  a.M.continueAfterLevel(15, () => na++, 999);
  const tk = a.M.openLevelEnd(15); a.M.closeLevelEnd(tk); a.M.continueAfterLevel(15, () => na++, tk);
  check('belirteç yok/yanlış/kapanmış: cb false, show() HİÇ çağrılmaz', na === 3 && count(a, 'interstitial') === 0 && a.state.ads.since === 3);
  const a2 = arm(); const t2 = a2.M.openLevelEnd(15); let r2 = null;
  a2.M.continueAfterLevel(16, s => { r2 = s; }, t2);
  check('belirteç başka seviyeye aitse show() çağrılmaz', r2 === false && count(a2, 'interstitial') === 0);
  // hazır değil → beklemeden atla, sayaç korunur, sonra hazır olunca ancak SEVİYE SONUNDA gösterilir
  const b = arm({ preload: true, interstitialReady: false, autoClose: true }); let nb = 0, lb = null;
  CL(b, 15, s => { nb++; lb = s; });
  check('hazır değil: anında cb(false), show() yok, bekleyen yok, sayaç korunur', nb === 1 && lb === false && count(b, 'interstitial') === 0 && b._pending === undefined && b.M._pending() === 0 && b.state.ads.since === 3);
  b.advance(10 * 1000);
  check('hazır değil sonrası zaman geçince (seviye ortası) show() çağrılmaz', count(b, 'interstitial') === 0);
  // seviye ortasında yükleme tamamlanır (hazır olur): yine show yok; sonraki seviye sonu: gösterilir (tek kez)
  b.M.onLevelComplete(16); b.advance(60 * 1000); b.flush();
  check('yükleme seviye ortasında tamamlandı: show() hâlâ yok', count(b, 'interstitial') === 0);
  b.bridge.isInterstitialReady = () => true;
  let sb = null; CL(b, 16, s => { sb = s; }); b.flush();
  check('sonraki uygun seviye sonunda hazır reklam tam bir kez gösterilir', sb === true && count(b, 'interstitial') === 1);
  // aynı belirteçle ikinci deneme: show() ikinci kez çağrılmaz
  const c = arm({ autoClose: false }); const tc = c.M.openLevelEnd(15); let nc = 0;
  c.M.continueAfterLevel(15, () => nc++, tc); c.M.onNative(JSON.stringify({ id: 1, event: 'closed' }));
  c.M.continueAfterLevel(15, () => nc++, tc);
  check('bir yerleştirmede show() en çok bir kez', nc === 2 && count(c, 'interstitial') === 1);
  // 1.1.4: show çağrıldı, reklam 8 sn sonra belirir: cb (sonraki seviye) ancak reklam kapanınca; ses ekrana gelene dek susmaz
  const d = arm({ autoClose: false }); const scr = []; let nd = 0, ld = null;
  d.M.setScreenListener(x => scr.push(x));
  CL(d, 15, s => { nd++; ld = s; });
  check('show çağrısı sesi susturmaz (ekrana gelmedi)', scr.length === 0);
  d.advance(8000);
  check('8 sn: reklam henüz belirmedi, sonraki seviye BAŞLAMADI (cb yok), bırakma yok', nd === 0 && count(d, 'release') === 0 && d.M.adHoldActive());
  d.M.onNative(JSON.stringify({ id: 1, event: 'shown' }));
  check('geç belirdi: ses şimdi susar, cb yok', JSON.stringify(scr) === '[true]' && nd === 0);
  d.advance(5000); d.M.onNative(JSON.stringify({ id: 1, event: 'closed' }));
  check('kapandı: cb tam bir kez true, ses geri, bekleme bitti, geç engel sayısı 0', nd === 1 && ld === true && JSON.stringify(scr) === '[true,false]' && !d.M.adHoldActive() && d.M.lateBlockedCount() === 0);
  // ödüllü: süre sınırıyla bırakılmaz
  const r = harness(); let rdone = null; const rw = [];
  r.bridge.showRewarded = function (id, pl) { r.calls.push(['rewarded', id, pl]); return true; };
  r.M.setWaitListener(w => rw.push(w));
  r.M.showRewarded('life', () => {}, x => { rdone = x; });
  r.advance(RULES.nativeTimeoutMs + 1);
  check('ödüllü: yanıt yoksa süreyle bitmez ("slow" bildirilir)', rdone === null && rw.includes('slow'));
  r.M.onNative({ id: 1, event: 'rewarded' }); r.M.onNative({ id: 1, event: 'closed' });
  check('ödüllü: ödül + kapanış → onDone(true) bir kez', rdone === true && !r.M.adHoldActive());
  // ses yalnızca ekrandayken: shown → true, closed → false
  const e = arm({ autoClose: false }); const se = [];
  e.M.setScreenListener(x => se.push(x));
  CL(e, 15, () => {});
  e.M.onNative(JSON.stringify({ id: 1, event: 'shown' }));
  const mid = JSON.stringify(se);
  e.M.onNative(JSON.stringify({ id: 1, event: 'closed' }));
  check('ses yalnızca reklam ekrandayken susar: shown → [true], closed → [true,false]', mid === '[true]' && JSON.stringify(se) === '[true,false]' && !e.M.isAdOnScreen());
  // gösterilemedi / köprü başlatamadı: ses hiç susmaz
  const f = arm({ startOk: false }); const sf = [];
  f.M.setScreenListener(x => sf.push(x)); CL(f, 15, () => {});
  check('köprü başlatamadı: ses durumu değişmez', sf.length === 0 && !f.M.isAdOnScreen());
}

console.log(`\n${fail ? fail + ' KALDI, ' : ''}${pass} GEÇTİ (reklam/satın alma birim testi)`);
process.exit(fail ? 1 : 0);
