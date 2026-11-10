// Java AndroidBridge'in ürettiği betikleri GERÇEK game/js/ads.js'e verir ve sonuçları denetler.
'use strict';
const fs = require('fs'), vm = require('vm');
const { create } = require(require('path').join(__dirname, '..', '..', '..', 'game', 'js', 'ads.js'));
const scripts = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n');
const bridge = { // ads.js çağrılarını kaydeden ve Java ile aynı kimlik sırasını üreten sahte köprü
  calls: [], isAdFree() { return false; }, isOnline() { return true; }, isRewardedReady() { return true; },
  showInterstitial(id) { this.calls.push(['i', id]); return true; }, showRewarded(id, p) { this.calls.push(['r', id, p]); return true; },
  purchaseRemoveAds(id) { this.calls.push(['p', id]); return true; }, restorePurchases(id) { this.calls.push(['rs', id]); return true; },
  privacyOptionsRequired() { return true; }, showPrivacyOptions(id) { this.calls.push(['po', id]); return true; }
};
const env = { now: () => 1e9, bridge: () => bridge, online: () => true, setTimeout: () => 0, clearTimeout: () => {} };
const M = create(env); const state = { ads: { since: 3, lastAt: 0, adFree: false, test: false } }; M.attach(() => state, () => {});
const R = {};
M.continueAfterLevel(20, s => { R.inter = s; }, M.openLevelEnd(20));                       // id 1
M.showRewarded('life', () => { R.reward = (R.reward || 0) + 1; }, d => { R.rdone = d; }); // id 2
M.purchaseRemoveAds(r => { R.p3 = r; });                                // id 3
M.showPrivacyOptions(() => { R.po = (R.po || 0) + 1; });                 // id 4
M.purchaseRemoveAds(r => { R.p5 = r; });                                // id 5
M.purchaseRemoveAds(r => { R.p6 = r; });                                // id 6
M.restorePurchases(r => { R.r7 = r; });                                 // id 7
const ctx = { window: { Monetization: M } }; vm.createContext(ctx);
for (const s of scripts) vm.runInContext(s, ctx);
let fail = 0; const ck = (n, c) => { console.log((c ? 'GEÇTİ  ' : 'KALDI  ') + n); if (!c) fail++; };
ck('köprü kimlik sırası 1..7', JSON.stringify(bridge.calls.map(c => c[1])) === '[1,2,3,4,5,6,7]');
ck('geçiş reklamı kapandı → oyun devam (shown=true)', R.inter === true);
ck('ödüllü: ödül 1 kez, kapanış rewarded=true', R.reward === 1 && R.rdone === true);
ck('pending → {ok:false, reason:pending}', R.p3 && R.p3.ok === false && R.p3.reason === 'pending');
ck('gizlilik seçenekleri kapanınca cb 1 kez', R.po === 1);
ck('bilinmeyen olay → failed', R.p5 && R.p5.reason === 'failed');
ck('purchased → ok + adFree', R.p6 && R.p6.ok === true && state.ads.adFree === true);
ck('restored adFree:true', R.r7 && R.r7.ok === true && R.r7.adFree === true);
ck('bekleyen istek kalmadı', M._pending() === 0);
console.log(fail ? fail + ' KALDI' : 'Java→JS köprü uyumluluk testi: hepsi geçti'); process.exit(fail ? 1 : 0);
