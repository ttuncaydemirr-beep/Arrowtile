/* Arrowtile — ads.js: reklam ve satın alma katmanı (window.Monetization)
 *
 * Oyun kodu reklam/satın alma SDK'sını DOĞRUDAN çağırmaz; yalnızca bu katmanı çağırır. Kurallar burada
 * uygulanır ve tools/test-ads.js ile (sahte saat + sahte köprü) test edilir. Kaynak: docs/00 "Reklam ve satın alma".
 *
 * KURALLAR
 *  - Yalnızca geçiş reklamı (interstitial), yalnızca seviye SONU ekranından oyuncu devam edince
 *    (continueAfterLevel). Seviye ortası, duraklatma, öğretici, günlük bulmaca: reklam yok (bu yollar API'yi çağırmaz).
 *  - Bölüm 1 (seviye 1-12) tamamen reklamsız; sayaç da yalnızca 13+ seviyelerde ilerler.
 *  - En erken her 3 tamamlanan seviyede bir (başarısız deneme sayılmaz), iki reklam arası en az 3 dakika.
 *  - İnternet yoksa ya da köprü yoksa (web önizleme) reklam gösterilmez, oyun normal devam eder.
 *  - "Reklamları kaldır" (Google Play, tüketilmeyen ürün `remove_ads`): geçiş reklamları kalıcı kapanır,
 *    ödüllü reklamlar isteğe bağlı kalır. Köprü yoksa satın alma TEST MODUNDA taklit edilir.
 *  - Süre sınırı yoktur; bu katman hiçbir zaman oyunu bekletmez: yerel tarafın yanıt vermemesi durumunda
 *    NATIVE_TIMEOUT sonra oyun kendiliğinden devam eder.
 *
 * ANDROID KÖPRÜSÜ (window.AndroidBridge, @JavascriptInterface; yalnızca ilkel türler):
 *  isAdFree(): boolean                       — Play'den doğrulanmış "remove_ads" sahipliği
 *  isOnline(): boolean            (isteğe bağlı)
 *  isRewardedReady(): boolean     (isteğe bağlı)
 *  showInterstitial(id: number): boolean     — true = gösterim başladı; bitince native → onNative({id, event:'closed'})
 *  showRewarded(id: number, placement: string): boolean
 *                                             — ödül hak edilince {id, event:'rewarded'}, kapanınca {id, event:'closed'}
 *  purchaseRemoveAds(id: number): boolean    — sonuç {id, event:'purchased'|'pending'|'cancelled'|'failed'}
 *                                              ('pending': ödeme bekleniyor; hak tamamlanınca isAdFree() true olur)
 *  restorePurchases(id: number): boolean     — sonuç {id, event:'restored', adFree: boolean}
 *  privacyOptionsRequired(): boolean (isteğe bağlı) — UMP: Ayarlar'da "Gizlilik seçenekleri" gösterilmeli mi
 *  showPrivacyOptions(id: number): boolean   (isteğe bağlı) — form kapanınca {id, event:'closed'}
 * Yerel taraf sonuçları şu çağrıyla iletir: window.Monetization.onNative('{"id":3,"event":"closed"}')
 */
(function (root) {
  'use strict';

  var RULES = { freeUntilLevel: 12, everyLevels: 3, minGapMs: 3 * 60 * 1000, nativeTimeoutMs: 90 * 1000 };
  var PRODUCT_ID = 'remove_ads';

  function defaultEnv() {
    return {
      now: function () { return Date.now(); },
      bridge: function () { try { return root.AndroidBridge || null; } catch (e) { return null; } },
      online: function () { try { return root.navigator ? root.navigator.onLine !== false : true; } catch (e) { return true; } },
      setTimeout: function (f, ms) { return setTimeout(f, ms); },
      clearTimeout: function (h) { clearTimeout(h); }
    };
  }

  function create(env) {
    env = env || defaultEnv();
    var getState = function () { return null; }, persist = function () {};
    var seq = 0, pending = {};

    function ads() {
      var s = getState();
      if (!s) return { since: 0, lastAt: 0, adFree: false, test: false };
      if (!s.ads || typeof s.ads !== 'object') s.ads = { since: 0, lastAt: 0, adFree: false, test: false };
      return s.ads;
    }
    function bridge() { var b = env.bridge(); return b && typeof b === 'object' ? b : null; }
    function call(name) {
      var b = bridge(); if (!b || typeof b[name] !== 'function') return undefined;
      try { return b[name].apply(b, Array.prototype.slice.call(arguments, 1)); } catch (e) { return undefined; }
    }
    function online() {
      if (!env.online()) return false;
      var r = call('isOnline');
      return r === undefined ? true : !!r;
    }
    function isAdFree() {
      var a = ads();
      // Web önizlemede test modunda "satın alınan" reklamsızlık, gerçek köprü varken geçerli sayılmaz
      if (a.adFree && !(a.test && bridge())) return true;
      var r = call('isAdFree');
      if (r === true) { a.adFree = true; a.test = false; persist(); return true; }
      return false;
    }

    // Yerel çağrı + yanıt bekleme (tek seferlik geri çağrı, zaman aşımı korumalı)
    function request(method, args, handler, onTimeout) {
      var id = ++seq;
      var started = call.apply(null, [method, id].concat(args || []));
      if (started !== true) return false;
      var p = { handler: handler, timer: env.setTimeout(function () {
        if (!pending[id]) return; delete pending[id]; if (onTimeout) onTimeout();
      }, RULES.nativeTimeoutMs) };
      pending[id] = p;
      return true;
    }
    function finish(id) { var p = pending[id]; if (!p) return null; delete pending[id]; env.clearTimeout(p.timer); return p; }

    function onNative(msg) {
      try {
        var m = typeof msg === 'string' ? JSON.parse(msg) : msg;
        if (!m || typeof m.id !== 'number' || !pending[m.id]) return false;
        var p = pending[m.id];
        var done = p.handler(m) !== false; // handler false dönerse istek açık kalır (ör. 'rewarded' sonrası 'closed' beklenir)
        if (done) finish(m.id);
        return true;
      } catch (e) { return false; }
    }

    // ---- geçiş reklamı ----
    function onLevelComplete(levelId) {
      if (!(levelId > RULES.freeUntilLevel)) return;
      ads().since = (ads().since | 0) + 1; persist();
    }
    function interstitialDue(levelId) {
      var a = ads();
      if (!(levelId > RULES.freeUntilLevel)) return false;
      if (isAdFree()) return false;
      if ((a.since | 0) < RULES.everyLevels) return false;
      if (a.lastAt && env.now() - a.lastAt < RULES.minGapMs) return false;
      if (!bridge() || !online()) return false;
      return true;
    }
    /** Seviye sonu ekranında oyuncu devam edince çağrılır. cb her durumda TAM BİR KEZ çağrılır. */
    function continueAfterLevel(levelId, cb) {
      var called = false;
      function go(shown) { if (called) return; called = true; try { cb && cb(!!shown); } catch (e) {} }
      if (!interstitialDue(levelId)) { go(false); return false; }
      var ok = request('showInterstitial', [], function (m) {
        if (m.event === 'closed' || m.event === 'failed') { go(m.event === 'closed'); return true; }
        return false;
      }, function () { go(false); });
      if (!ok) { go(false); return false; }
      var a = ads(); a.since = 0; a.lastAt = env.now(); persist();
      return true;
    }

    // ---- ödüllü reklam (isteğe bağlı; reklamsız sürümde de kullanılabilir) ----
    function rewardedAvailable() {
      if (!bridge() || !online()) return false;
      var r = call('isRewardedReady');
      return r === undefined ? typeof bridge().showRewarded === 'function' : !!r;
    }
    /** onReward() ödül hak edilirse bir kez; onDone(rewarded) her durumda bir kez. */
    function showRewarded(placement, onReward, onDone) {
      var rewarded = false, closed = false;
      function done() { if (closed) return; closed = true; try { onDone && onDone(rewarded); } catch (e) {} }
      if (!rewardedAvailable()) { done(); return false; }
      var ok = request('showRewarded', [String(placement || '')], function (m) {
        if (m.event === 'rewarded' && !rewarded) { rewarded = true; try { onReward && onReward(); } catch (e) {} return false; }
        if (m.event === 'closed' || m.event === 'failed') { done(); return true; }
        return false;
      }, done);
      if (!ok) done();
      return ok;
    }

    // ---- satın alma ----
    function purchaseRemoveAds(cb) {
      var called = false;
      function out(r) { if (called) return; called = true; try { cb && cb(r); } catch (e) {} }
      if (isAdFree()) { out({ ok: true, already: true }); return; }
      if (!bridge()) { // web önizleme: test modu
        var a = ads(); a.adFree = true; a.test = true; persist();
        out({ ok: true, test: true }); return;
      }
      var ok = request('purchaseRemoveAds', [], function (m) {
        if (m.event === 'purchased') { var a = ads(); a.adFree = true; a.test = false; persist(); out({ ok: true }); }
        else out({ ok: false, reason: m.event === 'cancelled' ? 'cancelled' : m.event === 'pending' ? 'pending' : 'failed' });
        return true;
      }, function () { out({ ok: false, reason: 'timeout' }); });
      if (!ok) out({ ok: false, reason: online() ? 'failed' : 'offline' });
    }
    function restorePurchases(cb) {
      var called = false;
      function out(r) { if (called) return; called = true; try { cb && cb(r); } catch (e) {} }
      if (!bridge()) { out({ ok: true, adFree: !!ads().adFree, test: true }); return; }
      var ok = request('restorePurchases', [], function (m) {
        if (m.event === 'restored') {
          var a = ads(); if (m.adFree) { a.adFree = true; a.test = false; } persist();
          out({ ok: true, adFree: !!m.adFree });
        } else out({ ok: false, reason: 'failed' });
        return true;
      }, function () { out({ ok: false, reason: 'timeout' }); });
      if (!ok) out({ ok: false, reason: online() ? 'failed' : 'offline' });
    }

    // ---- gizlilik seçenekleri (UMP; yalnızca Android köprüsü varsa ve bölge gerektiriyorsa) ----
    function privacyOptionsRequired() { return call('privacyOptionsRequired') === true; }
    /** cb() form kapanınca (ya da gösterilemezse) tam bir kez çağrılır. */
    function showPrivacyOptions(cb) {
      var called = false;
      function out() { if (called) return; called = true; try { cb && cb(); } catch (e) {} }
      if (!privacyOptionsRequired()) { out(); return false; }
      var ok = request('showPrivacyOptions', [], function () { out(); return true; }, out);
      if (!ok) out();
      return ok;
    }

    return {
      RULES: RULES, PRODUCT_ID: PRODUCT_ID,
      privacyOptionsRequired: privacyOptionsRequired,
      showPrivacyOptions: showPrivacyOptions,
      attach: function (get, save) { getState = get || getState; persist = save || persist; },
      hasBridge: function () { return !!bridge(); },
      isTestMode: function () { return !bridge(); },
      isAdFree: isAdFree,
      onLevelComplete: onLevelComplete,
      interstitialDue: interstitialDue,
      continueAfterLevel: continueAfterLevel,
      rewardedAvailable: rewardedAvailable,
      showRewarded: showRewarded,
      purchaseRemoveAds: purchaseRemoveAds,
      restorePurchases: restorePurchases,
      onNative: onNative,
      _pending: function () { return Object.keys(pending).length; }
    };
  }

  var M = create();
  M.create = create;
  root.Monetization = M;
  if (typeof module !== 'undefined' && module.exports) module.exports = { create: create, RULES: RULES };
})(typeof window !== 'undefined' ? window : globalThis);
