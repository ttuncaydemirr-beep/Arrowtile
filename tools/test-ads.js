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

console.log(`\n${fail ? fail + ' KALDI, ' : ''}${pass} GEÇTİ (reklam/satın alma birim testi)`);
process.exit(fail ? 1 : 0);
