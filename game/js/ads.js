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
 *  - Banner (v1.1, docs/15 §3): yalnızca Ana menü ve Harita ekranlarında (BANNER_SCREENS); oyun, seviye sonu, mağaza, ayarlar ve
 *    günlük bulmacada yok; "Reklamları kaldır" alınmışsa yok. bannerVisible(ekran) kuralı burada; web önizlemede (köprü yok) ekranda
 *    kesikli çerçeveli "Reklam alanı" yer tutucusu gösterilir (main.js), içeriği örtmez (ekranın altında yer ayırır).
 *  - Önceden yükleme (docs/15 §4): ödüllü reklam oyun ekranı açılınca ve can 1'e düşünce (preloadRewarded), geçiş reklamı seviye
 *    bitmeden, son oklar çıkarken (preloadInterstitial) yüklenmeye başlar; zaten yükleniyor/hazırsa tekrar başlatılmaz.
 *  - Reklam gösterilirken oyun döngüsü ve ses duraklar (setAdListener(function (active) {...}): reklam açılınca true, kapanınca false).
 *  - 1.1.3 (docs/20): geçiş reklamı YALNIZCA etkin seviye sonu yerleştirmesinde (openLevelEnd belirteci), YALNIZCA hazırsa ve en çok
 *    BİR kez gösterilir; hazır değilse beklemeden atlanır. Ses YALNIZCA reklam gerçekten ekrandayken susar (setScreenListener).
 *  - 1.1.4 (docs/21) TUTMA: show çağrıldıysa cb (sonraki seviye) YALNIZCA 'closed'/'failed' olayıyla ya da uygulama reklamdan/arka
 *    plandan dönünce (appHidden + appResumed, RULES.returnGraceMs) çağrılır. Gösterimde süre sınırı YOK (eski 3 sn "bırak" sonraki
 *    seviyenin ortasında reklama yol açıyordu). RULES.holdMaxMs dolunca yalnızca setWaitListener('slow') bildirilir; bekleme sürer.
 *    Bekleme 300 ms'yi aşarsa setWaitListener('opening'), bitince ('none'). Ödüllü gösterim de aynı biçimde bekler.
 *
 * ANDROID KÖPRÜSÜ (window.AndroidBridge, @JavascriptInterface; yalnızca ilkel türler):
 *  isAdFree(): boolean                       — Play'den doğrulanmış "remove_ads" sahipliği
 *  isOnline(): boolean            (isteğe bağlı)
 *  isRewardedReady(): boolean     (isteğe bağlı)
 *  showInterstitial(id: number): boolean     — true = gösterim başladı; bitince native → onNative({id, event:'closed'})
 *  loadRewarded(id: number): boolean         (isteğe bağlı) — yükleme; sonuç {id, event:'loaded'} ya da {id, event:'failed', code}
 *  loadInterstitial(id: number): boolean     (isteğe bağlı) — önceden yükleme; sonuç {id, event:'loaded'} ya da {id, event:'failed', code}
 *  isInterstitialReady(): boolean            (isteğe bağlı)
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

  var RULES = { freeUntilLevel: 12, everyLevels: 3, minGapMs: 3 * 60 * 1000, nativeTimeoutMs: 90 * 1000, holdMaxMs: 20 * 1000, returnGraceMs: 1500, testRewardMs: 600, preloadRetryMs: 20 * 1000, loadingOverlayMs: 300 };
  var BANNER_SCREENS = ['menu', 'map']; // v1.1: banner yalnızca Ana menü ve Harita ekranlarında
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
    var adListener = null, adActive = 0;
    function adState(on) { // reklam gösterimi başladı/bitti → dinleyiciye (oyun döngüsü + ses duraklatma); iç içe çağrılara dayanıklı
      var was = adActive > 0; adActive = Math.max(0, adActive + (on ? 1 : -1));
      var now = adActive > 0; if (was !== now && adListener) { try { adListener(now); } catch (e) {} }
    }

    // 1.1.3: ses yalnızca reklam GERÇEKTEN ekrandayken ('shown' olayı) susar; show çağrısı/yükleme sesi susturmaz
    var screenListener = null, onScreen = false;
    function screenState(on) {
      if (onScreen === on) return; onScreen = on;
      if (screenListener) { try { screenListener(on); } catch (e) {} }
    }
    // 1.1.3: yerleştirme oturumu (seviye sonu ekranı etkinken geçerli belirteç)
    var placementSeq = 0, placementOpen = 0, placementLevel = 0, placementUsed = 0;
    var released = {}, lateBlocked = 0, lateUntil = 0, lateListener = null;
    // 1.1.4: bekleyen tam ekran gösterim (show çağrıldı, sonuç bekleniyor)
    var hold = null, waitListener = null, stuckCount = 0;
    function waitState(w) { if (waitListener) { try { waitListener(w); } catch (e) {} } }
    function startHold(id, onRelease) {
      var h = { id: id, showed: false, away: false, hard: false, grace: null, slow: null, opening: null, release: onRelease };
      h.opening = env.setTimeout(function () { if (hold === h) waitState('opening'); }, RULES.loadingOverlayMs);
      h.slow = env.setTimeout(function () { if (hold === h) { stuckCount++; waitState('slow'); } }, RULES.holdMaxMs);
      hold = h; return h;
    }
    function endHold(h) {
      if (!h || hold !== h) return;
      env.clearTimeout(h.opening); env.clearTimeout(h.slow); if (h.grace) env.clearTimeout(h.grace);
      hold = null; waitState('none');
    }
    /** Uygulama gizlendi (visibilitychange hidden / pagehide) [hard=true] ya da yalnızca odak kaybı [hard=false]. */
    function appHidden(hard) { if (!hold) return; hold.away = true; if (hard !== false) hold.hard = true; if (hold.grace) { env.clearTimeout(hold.grace); hold.grace = null; } }
    /** Uygulama öne döndü: gösterim sürüyorsa ve (gerçekten arka plana gidildiyse ya da reklam ekrana gelmişse) kısa bekleme sonra biter. */
    function appResumed() {
      var h = hold; if (!h) return;
      if (!(h.hard || (h.away && h.showed))) return;
      h.away = false; h.hard = false;
      if (h.grace) env.clearTimeout(h.grace);
      h.grace = env.setTimeout(function () {
        if (hold !== h) return;
        if (!finish(h.id)) return;
        released[h.id] = true; if (!h.showed) lateUntil = env.now() + 30000;
        try { h.release(h.showed); } catch (e) {}
      }, RULES.returnGraceMs);
    }
    function openLevelEnd(levelId) { placementOpen = ++placementSeq; placementLevel = levelId; return placementOpen; }
    function closeLevelEnd(token) { if (token == null || token === placementOpen) placementOpen = 0; }
    function placementValid(token, levelId) { return !!token && token === placementOpen && (levelId == null || levelId === placementLevel); }

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
    // noTimeout (1.1.4): tam ekran gösterimde süre sınırı yok (sonuç olay ya da uygulamadan dönüşle gelir)
    function request(method, args, handler, onTimeout, noTimeout) {
      var id = ++seq;
      var started = call.apply(null, [method, id].concat(args || []));
      if (started !== true) return false;
      var p = { handler: handler, timer: noTimeout ? null : env.setTimeout(function () {
        if (!pending[id]) return; delete pending[id]; if (onTimeout) onTimeout();
      }, RULES.nativeTimeoutMs) };
      pending[id] = p;
      return true;
    }
    function finish(id) { var p = pending[id]; if (!p) return null; delete pending[id]; if (p.timer) env.clearTimeout(p.timer); return p; }

    function onNative(msg) {
      try {
        var m = typeof msg === 'string' ? JSON.parse(msg) : msg;
        if (m && typeof m.id === 'number' && released[m.id] && !pending[m.id]) {
          // uygulamadan dönüşle bırakılmış gösterim sonradan belirdi: kalkan
          if (m.event === 'shown') { lateBlocked++; if (lateListener) { try { lateListener(); } catch (e) {} } }
          return false;
        }
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
    /** Seviye sonu ekranında oyuncu devam edince çağrılır. cb her durumda TAM BİR KEZ çağrılır.
     *  token: openLevelEnd(levelId) belirteci (zorunlu; geçersizse reklam GÖSTERİLMEZ). Reklam hazır değilse beklemeden atlanır. */
    function continueAfterLevel(levelId, cb, token) {
      var called = false;
      function go(shown) { if (called) return; called = true; try { cb && cb(!!shown); } catch (e) {} }
      if (!placementValid(token, levelId) || placementUsed === token) { go(false); return false; }
      if (!interstitialDue(levelId) || hold) { go(false); return false; }
      // yalnızca ZATEN yüklü reklam gösterilir. Köprü hazır bilgisi vermiyorsa (eski köprü) hazır sayılır.
      var rd = call('isInterstitialReady');
      if (rd === false || (rd === undefined && bridge() && typeof bridge().isInterstitialReady === 'function')) { go(false); return false; }
      var open = true, h = null;
      function end() { if (open) { open = false; adState(false); screenState(false); } endHold(h); }
      adState(true); // oyun döngüsü duraklatması (ses DEĞİL)
      placementUsed = token; // show en çok bir kez
      var ok = request('showInterstitial', [], function (m) {
        if (m.event === 'shown') { if (h) h.showed = true; screenState(true); return false; } // ekrana geldi: ses şimdi susar
        if (m.event === 'closed' || m.event === 'failed') { end(); iReady = false; go(m.event === 'closed'); return true; }
        return false;
      }, function () { end(); go(false); }, true);
      if (!ok) { end(); go(false); return false; }
      var rid = seq;
      if (pending[rid]) h = startHold(rid, function (showed) { call('releaseInterstitial', rid); end(); iReady = false; go(showed); });
      iReady = false; iLoading = false;
      var a = ads(); a.since = 0; a.lastAt = env.now(); persist();
      return true;
    }
    // ---- geçiş reklamı önceden yükleme (docs/15 §4) ----
    var iLoading = false, iReady = false, iFailAt = 0;
    /** Bu seviye bitince geçiş reklamı gösterilecek mi (sayaç + bölüm + reklamsızlık + bağlantı; 3 dk aralığı gösterim anında bakılır)? */
    function interstitialWillBeDue(levelId) {
      var a = ads();
      if (!(levelId > RULES.freeUntilLevel)) return false;
      if (isAdFree()) return false;
      if ((a.since | 0) + 1 < RULES.everyLevels) return false;
      if (!bridge() || !online()) return false;
      return true;
    }
    function interstitialReady() {
      if (!bridge()) return false;
      var r = call('isInterstitialReady');
      return r === undefined ? iReady : !!r;
    }
    /** Seviye bitmeden (son oklar çıkarken) çağrılır: reklam gerekecekse ve hazır/yükleniyor değilse yüklemeyi başlatır.
     *  Dönen: 'skip' (gerekmiyor/destek yok) | 'ready' | 'loading' | 'started' | 'wait' (yakın zamanda başarısız oldu). */
    function preloadInterstitial(levelId) {
      if (!interstitialWillBeDue(levelId)) return 'skip';
      var b = bridge(); if (!b || typeof b.loadInterstitial !== 'function') return 'skip';
      if (interstitialReady()) return 'ready';
      if (iLoading) return 'loading';
      if (iFailAt && env.now() - iFailAt < RULES.preloadRetryMs) return 'wait';
      var ok = request('loadInterstitial', [], function (m) {
        iLoading = false;
        if (m.event === 'loaded') { iReady = true; iFailAt = 0; } else { iReady = false; iFailAt = env.now(); }
        return true;
      }, function () { iLoading = false; iFailAt = env.now(); });
      if (!ok) { iFailAt = env.now(); return 'skip'; }
      iLoading = true; return 'started';
    }

    // ---- ödüllü reklam (isteğe bağlı; reklamsız sürümde de kullanılabilir) ----
    function rewardedAvailable() {
      if (!bridge() || !online()) return false;
      var r = call('isRewardedReady');
      return r === undefined ? typeof bridge().showRewarded === 'function' : !!r;
    }
    /** Ödüllü reklam düğmeleri GÖRÜNSÜN mü? Önceden yüklenmiş olmaya bağlı değildir (yükleme dokunuşta yapılır).
     *  Köprü yoksa (web önizleme) test modunda taklit edilir; köprü varsa showRewarded yöntemi yeterli. */
    function rewardedOffered() {
      var b = bridge();
      return b ? typeof b.showRewarded === 'function' : true;
    }
    /** Dokunuşta: reklam hazır değilse yüklemeyi başlatır; cb({ok, code?, test?}) her durumda TAM BİR KEZ çağrılır.
     *  Köprü 'loadRewarded' desteklemezse ve hazır değilse {ok:false, code:'unavailable'} döner. */
    function ensureRewardedLoaded(cb) {
      var called = false;
      function out(r) { if (called) return; called = true; try { cb && cb(r); } catch (e) {} }
      if (!bridge()) { out({ ok: true, test: true }); return; }
      if (rewardedAvailable()) { out({ ok: true }); return; }
      if (!loadRewardedShared(out)) out({ ok: false, code: online() ? 'unavailable' : 'offline' });
    }
    // Ödüllü yükleme tek yerde: önceden yükleme sürerken oyuncu reklam isterse AYNI yüklemeye katılır (ikinci yükleme başlatılmaz)
    var rLoading = null, rFailAt = 0;
    function loadRewardedShared(cb) {
      if (rLoading) { if (cb) rLoading.waiters.push(cb); return true; }
      var st = { waiters: cb ? [cb] : [] };
      function settle(r) { rLoading = null; if (!r.ok) rFailAt = env.now(); else rFailAt = 0; st.waiters.forEach(function (f) { f(r); }); }
      var ok = request('loadRewarded', [], function (m) {
        settle(m.event === 'loaded' ? { ok: true } : { ok: false, code: m.code === undefined ? 'failed' : String(m.code) });
        return true;
      }, function () { settle({ ok: false, code: 'timeout' }); });
      if (!ok) return false;
      rLoading = st; return true;
    }
    /** Oyun ekranı açılınca ve can 1'e düşünce çağrılır (docs/15 §4): hazır değilse ve yüklenmiyorsa yüklemeyi sessizce başlatır.
     *  Dönen: 'skip' (köprü/yükleme desteği yok ya da çevrimdışı) | 'ready' | 'loading' | 'started' | 'wait' (yakın zamanda başarısız). */
    function preloadRewarded() {
      var b = bridge(); if (!b || typeof b.loadRewarded !== 'function' || !online()) return 'skip';
      if (rewardedAvailable()) return 'ready';
      if (rLoading) return 'loading';
      if (rFailAt && env.now() - rFailAt < RULES.preloadRetryMs) return 'wait';
      return loadRewardedShared(null) ? 'started' : 'skip';
    }
    /** Ödüllü reklam şu an yükleniyor mu (önceden yükleme dahil)? "Reklam yükleniyor…" kaplaması yalnızca gerçekten bekleniyorsa gösterilir. */
    function rewardedLoading() { return !!rLoading; }
    /** onReward() ödül hak edilirse bir kez; onDone(rewarded) her durumda bir kez.
     *  Köprü yoksa (web önizleme test modu) kısa gecikmeyle ödül taklit edilir. */
    function showRewarded(placement, onReward, onDone) {
      var rewarded = false, closed = false, shown = false;
      function done() { if (closed) return; closed = true; screenState(false); if (shown) { shown = false; adState(false); } try { onDone && onDone(rewarded); } catch (e) {} }
      if (!bridge()) {
        shown = true; adState(true); screenState(true); // test modu: kısa süre "reklam gösteriliyor" (oyun döngüsü + ses duraklar)
        env.setTimeout(function () {
          if (!rewarded) { rewarded = true; try { onReward && onReward(); } catch (e) {} }
          done();
        }, RULES.testRewardMs);
        return true;
      }
      if (!rewardedAvailable()) { done(); return false; }
      if (hold) { done(); return false; } // başka tam ekran gösterim sürüyor
      shown = true; adState(true); // yerel çağrıdan önce duraklat
      var h = null;
      var ok = request('showRewarded', [String(placement || '')], function (m) {
        if (m.event === 'shown') { if (h) h.showed = true; screenState(true); return false; }
        if (m.event === 'rewarded' && !rewarded) { rewarded = true; try { onReward && onReward(); } catch (e) {} return false; }
        if (m.event === 'closed' || m.event === 'failed') { endHold(h); done(); return true; }
        return false;
      }, function () { endHold(h); done(); }, true);
      if (!ok) { done(); return false; }
      var rid = seq;
      if (pending[rid]) h = startHold(rid, function () { call('releaseRewarded', rid); endHold(h); done(); });
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
      RULES: RULES, PRODUCT_ID: PRODUCT_ID, BANNER_SCREENS: BANNER_SCREENS,
      /** Bu ekranda banner gösterilir mi? (yalnızca menu/map ve reklamsız satın alma yoksa) */
      bannerVisible: function (screen) { return BANNER_SCREENS.indexOf(screen) >= 0 && !isAdFree(); },
      openLevelEnd: openLevelEnd, closeLevelEnd: closeLevelEnd,
      setScreenListener: function (fn) { screenListener = typeof fn === 'function' ? fn : null; },
      setLateListener: function (fn) { lateListener = typeof fn === 'function' ? fn : null; },
      setWaitListener: function (fn) { waitListener = typeof fn === 'function' ? fn : null; },
      adHoldActive: function () { return !!hold; },
      stuckCount: function () { return stuckCount; },
      appHidden: appHidden, appResumed: appResumed,
      lateBlockedCount: function () { return lateBlocked; },
      lateWindowOpen: function () { return lateUntil !== 0 && env.now() < lateUntil; },
      isAdOnScreen: function () { return onScreen; },
      setAdListener: function (fn) { adListener = typeof fn === 'function' ? fn : null; },
      isAdShowing: function () { return adActive > 0; },
      preloadRewarded: preloadRewarded, rewardedLoading: rewardedLoading,
      preloadInterstitial: preloadInterstitial, interstitialWillBeDue: interstitialWillBeDue,
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
      rewardedOffered: rewardedOffered,
      ensureRewardedLoaded: ensureRewardedLoaded,
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
  if (typeof module !== 'undefined' && module.exports) module.exports = { create: create, RULES: RULES, BANNER_SCREENS: BANNER_SCREENS };
})(typeof window !== 'undefined' ? window : globalThis);
