/* Arrowtile — storage.js
 * localStorage kaydı (anahtar: arrowtile.save.v1; eski "okKacis.save.v1" ilk açılışta taşınır).
 * Her erişim try/catch; bozuk veride güvenli varsayılan.
 * Ekonomi: docs/01-oyun-tasarim-belgesi.md §6.
 */
(function () {
  'use strict';

  // ?debug=1 ile açılan oturum ayrı bir "kum havuzu" anahtarı kullanır: hata ayıklama kancası
  // (main.js window.__ok) hiçbir zaman oyuncunun gerçek kaydına yazamaz (test raporu H2).
  var DEBUG = false;
  try { DEBUG = /(^|[?&])debug=1(&|$)/.test(String(location.search).slice(1)); } catch (e) {}
  var SUFFIX = DEBUG ? '.debug' : '';
  var KEY = 'arrowtile.save.v1' + SUFFIX;
  var LANG_KEY = 'arrowtile.lang' + SUFFIX;
  // Çalışma adı "Ok Kaçış" döneminden kalan anahtarlar (v1.0): ilk açılışta yeni anahtara taşınır
  var OLD_KEY = 'okKacis.save.v1' + SUFFIX;
  var OLD_LANG_KEY = 'okKacis.lang' + SUFFIX;
  var LANGS = ['tr', 'en', 'de', 'ar'];
  var THEME_IDS = ['emaye', 'lokum', 'cini', 'bakir', 'gece'];
  var DAILY = [20, 30, 40, 50, 60, 80, 150];
  var PRICES = { hint: 50 };       // v1.2 (docs/08): geri alma kaldırıldı, ipucu pahalandı
  var AD_COINS = 50;               // v1.4: ödüllü reklam başına jeton (= bir ipucu fiyatı)
  var MAX_COIN_ADS = 10;           // v1.4: takvim günü başına en çok reklam-jeton hakkı
  var UNDO_REFUND = 20;            // eski ücretsiz geri alma hakkı başına jeton (kayıt göçü)
  // v1.3 (docs/09): ödüller bölüm kademesine göre. Seviye jetonu taban 10/15/20 (1/2/3 yıldız) × kademe çarpanı;
  // bölüm bonusu kademeye göre. Döngü levelgen.js ile aynı (K-K-K-O-O-O-Z-Z-A).
  var CYCLE = ['easy', 'easy', 'easy', 'medium', 'medium', 'medium', 'hard', 'hard', 'extreme'];
  var TIER_MULT = { easy: 1, medium: 1.5, hard: 2, extreme: 3 };
  var TIER_BONUS = { easy: 50, medium: 75, hard: 100, extreme: 200 };
  var CHAPTER_BONUS = 50; // eski ad (kolay bölüm bonusu)
  var TOTAL_LEVELS = (window.LEVELS && window.LEVELS.length) || 36; // hazır seviyeler; sonrası sonsuz
  var MAX_LEVEL = 99999;  // sonsuz devam: kayıtta kabul edilen en büyük seviye no
  var MAX_CHAPTERS = Math.ceil(MAX_LEVEL / 12);
  function tierOfChapter(ch) { return CYCLE[(ch - 1) % CYCLE.length]; }
  function tierOfLevel(id) { return tierOfChapter(Math.ceil(id / 12)); }
  function chapterBonusFor(ch) { return TIER_BONUS[tierOfChapter(ch)]; }
  function levelReward(id, stars) { return Math.round([0, 10, 15, 20][stars] * TIER_MULT[tierOfLevel(id)]); }

  function detectLang() {
    try {
      var nl = String((navigator.languages && navigator.languages[0]) || navigator.language || '').slice(0, 2).toLowerCase();
      return LANGS.indexOf(nl) >= 0 ? nl : 'en';
    } catch (e) { return 'en'; }
  }

  function defaults(lang) {
    return {
      lang: lang || detectLang(), sound: true, vibration: true,
      coins: 50, freeHints: 2,
      stars: {}, unlocked: 1, themesOwned: ['emaye'], theme: 'emaye',
      daily: { lastDate: null, streakDay: 0 },
      tutorialDone: [], chapterBonus: [],
      ads: { since: 0, lastAt: 0, adFree: false, test: false, coinDate: null, coinCount: 0 }, // reklam sayacı + "reklamları kaldır" (ads.js) + günlük reklam-jeton hakkı
      appearance: 'auto',   // G7: auto | light | dark
      relaxed: false,       // G3: rahat mod
      aim: false,           // G1: önce seç, sonra fırlat
      tips: [],             // tek seferlik ipuçları (aim_suggest, zoom_tip …)
      dp: { done: {}, streak: 0, best: 0, last: null, trophies: 0 } // G5: günlük bulmaca
    };
  }

  function int(v, d, min, max) {
    v = Math.floor(Number(v));
    if (!isFinite(v)) return d;
    if (min != null && v < min) return min;
    if (max != null && v > max) return max;
    return v;
  }

  // Bozuk/eksik alanları tek tek onarır
  function sanitize(raw) {
    var d = defaults();
    if (!raw || typeof raw !== 'object') return d;
    var s = d;
    if (LANGS.indexOf(raw.lang) >= 0) s.lang = raw.lang;
    if (typeof raw.sound === 'boolean') s.sound = raw.sound;
    if (typeof raw.vibration === 'boolean') s.vibration = raw.vibration;
    s.coins = int(raw.coins, d.coins, 0, 1e9);
    s.freeHints = int(raw.freeHints, d.freeHints, 0, 999);
    // v1.2 göçü: geri alma kaldırıldı; kalan ücretsiz geri alma hakları jetona çevrilir (hak başı 20). Alan kayıttan silinir.
    if (raw.freeUndos !== undefined) s.coins = Math.min(1e9, s.coins + int(raw.freeUndos, 0, 0, 999) * UNDO_REFUND);
    if (raw.stars && typeof raw.stars === 'object') {
      Object.keys(raw.stars).forEach(function (k) {
        var id = int(k, 0, 0, MAX_LEVEL), v = int(raw.stars[k], 0, 0, 3);
        if (id >= 1 && v >= 1) s.stars[id] = v;
      });
    }
    s.unlocked = int(raw.unlocked, 1, 1, MAX_LEVEL);
    if (Array.isArray(raw.themesOwned)) {
      s.themesOwned = raw.themesOwned.filter(function (t) { return THEME_IDS.indexOf(t) >= 0; });
      if (s.themesOwned.indexOf('emaye') < 0) s.themesOwned.unshift('emaye');
    }
    if (s.themesOwned.indexOf(raw.theme) >= 0) s.theme = raw.theme;
    if (raw.daily && typeof raw.daily === 'object') {
      s.daily.lastDate = /^\d{4}-\d{2}-\d{2}$/.test(raw.daily.lastDate) ? raw.daily.lastDate : null;
      s.daily.streakDay = int(raw.daily.streakDay, 0, 0, 7);
    }
    if (Array.isArray(raw.tutorialDone)) s.tutorialDone = raw.tutorialDone.map(Number).filter(function (n) { return n >= 1 && n <= 3; });
    else if (raw.tutorialDone === true) s.tutorialDone = [1, 2, 3];
    if (Array.isArray(raw.chapterBonus)) s.chapterBonus = raw.chapterBonus.map(Number).filter(function (n) { return n >= 1 && n <= MAX_CHAPTERS; });
    if (raw.ads && typeof raw.ads === 'object') {
      s.ads.since = int(raw.ads.since, 0, 0, 1000);
      s.ads.lastAt = int(raw.ads.lastAt, 0, 0, 8.64e15);
      s.ads.adFree = raw.ads.adFree === true;
      s.ads.test = raw.ads.test === true;
      // v1.4: reklam izleyerek jeton — son kullanım günü (yerel yyyy-aa-gg) ve o günkü sayı
      s.ads.coinDate = /^\d{4}-\d{2}-\d{2}$/.test(raw.ads.coinDate) ? raw.ads.coinDate : null;
      s.ads.coinCount = int(raw.ads.coinCount, 0, 0, 1000);
    }
    if (['auto', 'light', 'dark'].indexOf(raw.appearance) >= 0) s.appearance = raw.appearance;
    if (typeof raw.relaxed === 'boolean') s.relaxed = raw.relaxed;
    if (typeof raw.aim === 'boolean') s.aim = raw.aim;
    if (raw.dp && typeof raw.dp === 'object') {
      var D = /^\d{4}-\d{2}-\d{2}$/;
      if (raw.dp.done && typeof raw.dp.done === 'object' && !Array.isArray(raw.dp.done)) Object.keys(raw.dp.done).slice(-400).forEach(function (k) {
        var v = int(raw.dp.done[k], 0, 0, 3); if (D.test(k) && v >= 1) s.dp.done[k] = v;
      });
      s.dp.streak = int(raw.dp.streak, 0, 0, 100000); s.dp.best = int(raw.dp.best, 0, 0, 100000);
      s.dp.trophies = int(raw.dp.trophies, 0, 0, 100000); s.dp.last = D.test(raw.dp.last) ? raw.dp.last : null;
    }
    if (Array.isArray(raw.tips)) s.tips = raw.tips.filter(function (x) { return typeof x === 'string' && /^[a-z_]{1,24}$/.test(x); }).slice(0, 20);
    return s;
  }

  var state = null;

  // Eski kaydı taşı: yeni anahtar boşsa eski anahtardaki veri okunur, yeni anahtara yazılır, eskisi silinir.
  // Yeni anahtarda zaten veri varsa eski veri dokunulmadan bırakılır (üzerine yazma yok).
  function migrate() {
    try {
      if (localStorage.getItem(KEY) !== null) return false;
      var old = localStorage.getItem(OLD_KEY), oldLang = localStorage.getItem(OLD_LANG_KEY);
      if (old === null && oldLang === null) return false;
      if (old !== null) {
        var parsed = null; try { parsed = JSON.parse(old); } catch (e) { parsed = null; }
        localStorage.setItem(KEY, JSON.stringify(sanitize(parsed)));
      }
      if (oldLang !== null && localStorage.getItem(LANG_KEY) === null) localStorage.setItem(LANG_KEY, oldLang);
      if (localStorage.getItem(KEY) !== null || old === null) { localStorage.removeItem(OLD_KEY); localStorage.removeItem(OLD_LANG_KEY); }
      return true;
    } catch (e) { return false; }
  }
  function load() {
    var raw = null, lang = null;
    migrate();
    try { var txt = localStorage.getItem(KEY); if (txt) raw = JSON.parse(txt); } catch (e) { raw = null; }
    try { lang = localStorage.getItem(LANG_KEY); } catch (e) { lang = null; }
    state = sanitize(raw);
    if (!raw && LANGS.indexOf(lang) >= 0) state.lang = lang; // sıfırlamadan sonra dil korunur
    if (raw && typeof raw === 'object' && raw.freeUndos !== undefined) save(); // v1.2 göçünü hemen kalıcı yap
    return state;
  }
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {}
    try { localStorage.setItem(LANG_KEY, state.lang); } catch (e) {}
  }
  // Dışarıdan gelen bir durumu doğrulayıp geçerli kayıt yapar (hata ayıklama kum havuzu, içe aktarma)
  function adopt(obj) {
    var keepLang = state ? state.lang : null;
    state = sanitize(JSON.parse(JSON.stringify(obj || {})));
    if (!obj || !obj.lang) state.lang = keepLang || state.lang;
    save();
    return state;
  }
  function resetProgress() {
    var lang = state ? state.lang : detectLang();
    var keepAds = state && state.ads ? { adFree: !!state.ads.adFree, test: !!state.ads.test, coinDate: state.ads.coinDate || null, coinCount: state.ads.coinCount | 0 } : null;
    try { localStorage.removeItem(KEY); } catch (e) {}
    state = defaults(lang);
    // satın alma ve günlük reklam-jeton hakkı ilerlemeye bağlı değildir (sıfırlamayla hak yenilenmez)
    if (keepAds) { state.ads.adFree = keepAds.adFree; state.ads.test = keepAds.test; state.ads.coinDate = keepAds.coinDate; state.ads.coinCount = keepAds.coinCount; }
    save();
    return state;
  }

  // ---- tarih yardımcıları (cihazın yerel tarihi) ----
  function ymd(d) {
    d = d || new Date();
    var m = d.getMonth() + 1, day = d.getDate();
    return d.getFullYear() + '-' + (m < 10 ? '0' : '') + m + '-' + (day < 10 ? '0' : '') + day;
  }
  function dayDiff(a, b) { // b - a gün
    var pa = a.split('-').map(Number), pb = b.split('-').map(Number);
    return Math.round((Date.UTC(pb[0], pb[1] - 1, pb[2]) - Date.UTC(pa[0], pa[1] - 1, pa[2])) / 864e5);
  }

  /** Bugün kalan reklam-jeton hakkı (0..MAX_COIN_ADS). Saat geri alınırsa (kayıtlı gün bugünden sonra) sayaç sıfırlanmaz. */
  function coinAdsLeft(today) {
    today = today || ymd();
    var a = (state || load()).ads;
    if (a.coinDate && dayDiff(a.coinDate, today) <= 0) return Math.max(0, MAX_COIN_ADS - (a.coinCount | 0));
    return MAX_COIN_ADS;
  }
  /** Ödüllü reklam izlendi: hak varsa +AD_COINS jeton ekler, sayacı işler, kaydeder; eklenen jetonu döndürür (hak yoksa 0). */
  function grantAdCoins(today) {
    today = today || ymd();
    if (coinAdsLeft(today) <= 0) return 0;
    var a = state.ads;
    if (a.coinDate && dayDiff(a.coinDate, today) <= 0) a.coinCount = (a.coinCount | 0) + 1;
    else { a.coinDate = today; a.coinCount = 1; }
    state.coins = Math.min(1000000000, state.coins + AD_COINS);
    save();
    return AD_COINS;
  }

  /** Günlük ödül durumu: { canClaim, day (1..7), claimedToday, streakLost, clockBack } */
  function dailyStatus(today) {
    today = today || ymd();
    var d = state.daily;
    if (!d.lastDate) return { canClaim: true, day: 1, claimedToday: false, streakLost: false };
    var diff = dayDiff(d.lastDate, today);
    if (diff < 0) return { canClaim: false, day: d.streakDay || 1, claimedToday: false, clockBack: true };
    if (diff === 0) return { canClaim: false, day: d.streakDay || 1, claimedToday: true };
    if (diff === 1) return { canClaim: true, day: (d.streakDay % 7) + 1, claimedToday: false, streakLost: false };
    return { canClaim: true, day: 1, claimedToday: false, streakLost: d.streakDay > 0 };
  }
  function claimDaily(today) {
    today = today || ymd();
    var st = dailyStatus(today);
    if (!st.canClaim) return null;
    var coins = DAILY[st.day - 1];
    state.coins += coins;
    var hint = st.day === 7 ? 1 : 0;
    state.freeHints += hint;
    state.daily = { lastDate: today, streakDay: st.day };
    save();
    return { day: st.day, coins: coins, hint: hint };
  }

  /** Seviye bitirme: yıldız + jeton (ilk kez tam ödül, sonra yalnızca fark) + bölüm bonusu */
  function completeLevel(id, stars, relaxed) {
    var prev = state.stars[id] || 0;
    var coins = stars > prev ? levelReward(id, stars) - levelReward(id, prev) : 0;
    if (relaxed) coins = Math.floor(coins / 2); // G3: rahat modda jeton yarı
    var best = stars > prev;
    if (best) state.stars[id] = stars;
    state.coins += coins;
    if (id >= state.unlocked && id < MAX_LEVEL) state.unlocked = id + 1;
    var ch = Math.ceil(id / 12), bonus = 0, chapterDone = false;
    if (state.chapterBonus.indexOf(ch) < 0) {
      var all = true;
      for (var k = (ch - 1) * 12 + 1; k <= ch * 12; k++) if (!state.stars[k]) { all = false; break; }
      if (all) { chapterDone = true; bonus = chapterBonusFor(ch); state.coins += bonus; state.chapterBonus.push(ch); }
    }
    save();
    return { coins: coins, newBest: best && prev > 0, firstClear: prev === 0, bonus: bonus, chapterDone: chapterDone };
  }

  function totalStars() {
    var n = 0; Object.keys(state.stars).forEach(function (k) { n += state.stars[k]; }); return n;
  }

  /** Yardımcı harca: önce ücretsiz hak, sonra jeton. Döner: true/false */
  function spendBooster(kind) {
    var f = 'freeHints';
    if (state[f] > 0) { state[f]--; save(); return true; }
    if (state.coins >= PRICES[kind]) { state.coins -= PRICES[kind]; save(); return true; }
    return false;
  }
  function refundBooster(kind, wasFree) {
    if (wasFree) state.freeHints++; else state.coins += PRICES[kind];
    save();
  }

  // ---- Yedek kodu (G6): "ARROWTILE1-<base64(JSON)>-<sağlama>" ----
  // Dil ve satın alma durumu (ads) koda girmez: satın alma Play hesabına bağlıdır, kodla taşınamaz.
  function b64enc(str) {
    try { if (typeof TextEncoder !== 'undefined') { var u = new TextEncoder().encode(str), bin = ''; for (var i = 0; i < u.length; i++) bin += String.fromCharCode(u[i]); return btoa(bin); } } catch (e) {}
    return btoa(unescape(encodeURIComponent(str)));
  }
  function b64dec(b) {
    var bin = atob(b);
    try { if (typeof TextDecoder !== 'undefined') { var u = new Uint8Array(bin.length); for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return new TextDecoder().decode(u); } } catch (e) {}
    return decodeURIComponent(escape(bin));
  }
  function fnv(str) { var h = 0x811c9dc5; for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193); } return ('0000000' + (h >>> 0).toString(16)).slice(-8); }
  var CODE_PREFIX = 'ARROWTILE1';
  function exportCode() {
    var o = JSON.parse(JSON.stringify(state)); delete o.lang; delete o.ads;
    var body = b64enc(JSON.stringify(o));
    return CODE_PREFIX + '-' + body + '-' + fnv(body);
  }
  /** Kodu çözer ve doğrular; geçersizse null. Geçerliyse onarılmış durum (henüz uygulanmamış). */
  function parseCode(code) {
    try {
      var m = /^ARROWTILE1-([A-Za-z0-9+\/=]+)-([0-9a-f]{8})$/.exec(String(code || '').replace(/\s+/g, ''));
      if (!m || fnv(m[1]) !== m[2]) return null;
      var o = JSON.parse(b64dec(m[1]));
      if (!o || typeof o !== 'object' || Array.isArray(o)) return null;
      return sanitize(o);
    } catch (e) { return null; }
  }
  function importCode(code) {
    var o = parseCode(code); if (!o) return null;
    o.lang = state.lang; o.ads = JSON.parse(JSON.stringify(state.ads));
    state = o; save(); return state;
  }

  window.Store = {
    KEY: KEY, OLD_KEY: OLD_KEY, DEBUG: DEBUG, LANGS: LANGS, THEME_IDS: THEME_IDS, DAILY: DAILY, PRICES: PRICES, TOTAL_LEVELS: TOTAL_LEVELS,
    CHAPTER_BONUS: CHAPTER_BONUS, MAX_LEVEL: MAX_LEVEL, TIER_MULT: TIER_MULT, TIER_BONUS: TIER_BONUS,
    tierOfChapter: tierOfChapter, tierOfLevel: tierOfLevel, chapterBonusFor: chapterBonusFor, levelReward: levelReward,
    load: load, save: save, adopt: adopt, resetProgress: resetProgress, sanitize: sanitize, defaults: defaults,
    get: function () { return state || load(); },
    AD_COINS: AD_COINS, MAX_COIN_ADS: MAX_COIN_ADS, coinAdsLeft: coinAdsLeft, grantAdCoins: grantAdCoins,
    ymd: ymd, dailyStatus: dailyStatus, claimDaily: claimDaily,
    completeLevel: completeLevel, exportCode: exportCode, parseCode: parseCode, importCode: importCode, totalStars: totalStars, spendBooster: spendBooster, refundBooster: refundBooster
  };
})();
