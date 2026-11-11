/* Arrowtile — main.js
 * Ekranlar, girdi, Canvas çizimi, animasyon, öğretici. Bağımlılıklar (sıralı script):
 * i18n.js, levels.js, theme.js, audio.js, engine.js, storage.js, ads.js, privacy.js, daily.js
 * Reklam/satın alma yalnızca window.Monetization (ads.js) üzerinden; kurallar orada.
 */
(function () {
  'use strict';

  var VERSION = '1.0.0'; // Google Play versionName ile aynı (android/app/build.gradle.kts)
  var SUPPORT_EMAIL = 'nilkaren.tuncay.demir@gmail.com';
  var LEVELS = window.LEVELS || [];
  var I18N = window.I18N || {};
  var T = window.THEME, SFX = window.SFX, E = window.OkEngine, Store = window.Store;
  var S = Store.load();
  var M = window.Monetization;
  M.attach(function () { return S; }, function () { Store.save(); });
  // v1.1 (docs/15 §4): reklam gösterilirken oyun animasyon döngüsü ve ses duraklar, reklam kapanınca devam eder
  var adPause = false;
  M.setAdListener(function (active) {
    adPause = !!active;
    try { if (!active) kick(); } catch (e) {}
  });
  // 1.1.3: ses YALNIZCA reklam gerçekten ekrandayken susar (show çağrısı / yükleme sesi susturmaz)
  M.setScreenListener(function (on) { try { if (on) SFX.pause(); else SFX.resume(); } catch (e) {} });

  function $(id) { return document.getElementById(id); }
  function el(tag, cls, html) { var e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }

  var reduced = false;
  try { reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) {}

  // ---------------------------------------------------------------- i18n
  function t(key, vars) {
    var d = I18N[S.lang] || I18N.en || {};
    var s = d[key];
    if (s == null) s = (I18N.en && I18N.en[key]) || key;
    if (vars) Object.keys(vars).forEach(function (k) { s = s.split('{' + k + '}').join(String(vars[k])); });
    return s;
  }
  function isRTL() { return T.isRTL(S.lang); }

  // ---------------------------------------------------------------- ikonlar (satır içi SVG)
  var ICONS = {
    coin: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="var(--coin)"/><circle cx="12" cy="12" r="6.6" fill="none" stroke="#fff" stroke-opacity=".55" stroke-width="1.6"/><path d="M12 8.2v7.6" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></svg>',
    star: '<svg viewBox="0 0 24 24"><path d="M12 2.6l2.9 5.9 6.5.9-4.7 4.6 1.1 6.5L12 17.4l-5.8 3.1 1.1-6.5L2.6 9.4l6.5-.9z" fill="var(--star)" stroke="var(--star)" stroke-width="1.4" stroke-linejoin="round"/></svg>',
    starEmpty: '<svg viewBox="0 0 24 24"><path d="M12 2.6l2.9 5.9 6.5.9-4.7 4.6 1.1 6.5L12 17.4l-5.8 3.1 1.1-6.5L2.6 9.4l6.5-.9z" fill="var(--star-empty)" stroke="var(--star-empty)" stroke-width="1.4" stroke-linejoin="round"/></svg>',
    heart: '<svg viewBox="0 0 24 24"><path d="M12 21s-7.6-4.6-9.5-9.3C1.2 8.4 3.2 4.6 6.9 4.6c2.1 0 3.6 1.2 5.1 3 1.5-1.8 3-3 5.1-3 3.7 0 5.7 3.8 4.4 7.1C19.6 16.4 12 21 12 21z" fill="var(--danger)"/><path d="M7 8.2c-.9.3-1.6 1.1-1.7 2.1" stroke="#fff" stroke-opacity=".6" stroke-width="1.6" fill="none" stroke-linecap="round"/></svg>',
    map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"><path d="M3 6l6-2.5 6 2.5 6-2.5v14.5L15 20.5 9 18l-6 2.5z"/><path d="M9 3.5V18M15 6v14.5"/></svg>',
    shop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"><path d="M4.5 8h15l-1.2 12.5H5.7z"/><path d="M8.5 10V6.5a3.5 3.5 0 0 1 7 0V10"/></svg>',
    gift: '<svg viewBox="0 0 24 24"><rect x="3" y="9" width="18" height="12" rx="2.5" fill="var(--danger)"/><rect x="2" y="7" width="20" height="4.5" rx="1.8" fill="var(--danger)"/><path d="M12 7v14" stroke="var(--star)" stroke-width="3"/><path d="M2 9.2h20" stroke="#000" stroke-opacity=".12" stroke-width="1"/><path d="M12 7c-1.5-3.5-5.5-4-5.5-1.5S10 7 12 7zm0 0c1.5-3.5 5.5-4 5.5-1.5S14 7 12 7z" fill="none" stroke="var(--star)" stroke-width="2"/></svg>',
    gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linejoin="round"><circle cx="12" cy="12" r="3.2"/><path d="M12 2.5l1.6 2.6 3-.6.7 3 2.6 1.6-1.4 2.9 1.4 2.9-2.6 1.6-.7 3-3-.6L12 21.5l-1.6-2.6-3 .6-.7-3-2.6-1.6L5.5 12 4.1 9.1l2.6-1.6.7-3 3 .6z"/></svg>',
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>',
    pause: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="5" width="4" height="14" rx="1.5"/><rect x="14" y="5" width="4" height="14" rx="1.5"/></svg>',
    bulb: '<svg viewBox="0 0 24 24"><path d="M12 2.5a6.8 6.8 0 0 0-4 12.3c.7.5 1 1.2 1 2V18h6v-1.2c0-.8.4-1.5 1-2A6.8 6.8 0 0 0 12 2.5z" fill="var(--star)"/><rect x="9" y="19" width="6" height="2.6" rx="1.2" fill="var(--ink-soft)"/><path d="M10 9.5a2.4 2.4 0 0 1 2-2" stroke="#fff" stroke-width="1.6" fill="none" stroke-linecap="round"/></svg>',
    restart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.6-5.9"/><path d="M20 3.5v5h-5"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" fill="none" stroke="currentColor" stroke-width="2.4"/></svg>',
    hand: '<svg viewBox="0 0 24 24"><path d="M9.2 3.2c.9 0 1.6.7 1.6 1.6v6.4l.9-.2c.9-.1 1.7.4 1.9 1.3l.1.2.6-.1c.8-.1 1.6.4 1.8 1.2l.7-.1c.8-.1 1.6.5 1.7 1.3l.5 3.3c.3 2.6-1.6 4.9-4.2 4.9h-2.9c-1.6 0-3-.8-3.9-2.1l-3.1-4.6c-.5-.7-.3-1.6.4-2.1.6-.4 1.4-.3 1.9.2l1.6 1.7V4.8c0-.9.7-1.6 1.6-1.6z" fill="#fff" stroke="#1D2C3B" stroke-width="1.5" stroke-linejoin="round"/></svg>',
    noads: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="3"/><path d="M8 15l2-6 2 6M8.7 13h2.6M14.5 9v6h1.2a2.3 2.3 0 0 0 0-6z"/><path d="M3.5 3.5l17 17" stroke="var(--danger)"/></svg>',
    trophy: '<svg viewBox="0 0 24 24"><path d="M7 3h10v5a5 5 0 0 1-10 0z" fill="var(--star)"/><path d="M7 5H4a3 3 0 0 0 3 4M17 5h3a3 3 0 0 1-3 4" fill="none" stroke="var(--star)" stroke-width="2"/><path d="M10.5 13h3l.5 4h-4z" fill="var(--star)"/><rect x="7.5" y="17" width="9" height="3.5" rx="1.2" fill="var(--coin)"/></svg>',
    calendar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4" stroke-linecap="round"/><circle cx="12" cy="15" r="2" fill="currentColor" stroke="none"/></svg>',
    leaf: '<svg viewBox="0 0 24 24"><path d="M5 19c0-8 5-13 15-14-1 10-6 15-14 15" fill="var(--success)"/><path d="M5 19c3-4 6-7 10-9" stroke="#fff" stroke-width="1.6" fill="none" stroke-linecap="round"/></svg>',
    fit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg>',
    zoomin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L20.5 20.5M10.5 7.8v5.4M7.8 10.5h5.4"/></svg>',
    rotate: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="7" y="2.5" width="10" height="19" rx="2.2"/><path d="M11 18.5h2"/><path d="M2.5 9a8 8 0 0 1 3-4.5M5.5 4.5v2.6H2.9"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
  };
  function icon(name, cls) { return '<span class="ic' + (cls ? ' ' + cls : '') + '">' + ICONS[name] + '</span>'; }
  function fillIcons(root) {
    (root || document).querySelectorAll('[data-icon]').forEach(function (n) {
      if (!n.firstChild) n.innerHTML = ICONS[n.getAttribute('data-icon')] || '';
    });
  }

  // ---------------------------------------------------------------- genel UI
  // Metin sığdırma (test raporu H4): önce satır kaydır (kelime arasından), sonra yazıyı küçült;
  // kelime asla ortadan bölünmez. En küçük boyutta hâlâ sığmıyorsa son çare olarak heceleme (hyphens:auto + lang).
  var FIT = [
    ['.btn:not(.tiny), .tab, .lang-btn', 14, 2],
    ['.btn.tiny', 12, 2],
    ['.bar-title, .title, .sheet h2, .chapter-head h3', 15, 2],
    ['.item-name, .tool-label, .bubble-text, .day > span, .tag, .set-name, .seg-btn', 12, 3]
  ];
  function fitAll(root) {
    root = root || document;
    FIT.forEach(function (f) {
      root.querySelectorAll(f[0]).forEach(function (b) {
        if (b.closest('[hidden]') || !b.getClientRects().length) return;
        T.fitButton(b, { minFont: f[1], maxLines: f[2] });
      });
    });
  }
  function applyI18n() {
    T.applyLang(S.lang);
    document.querySelectorAll('[data-i18n]').forEach(function (n) { n.textContent = t(n.getAttribute('data-i18n')); });
    document.querySelectorAll('[data-i18n-aria]').forEach(function (n) { n.setAttribute('aria-label', t(n.getAttribute('data-i18n-aria'))); });
    document.title = t('app.name');
  }
  function updateCoins() {
    document.querySelectorAll('[data-bind="coins"]').forEach(function (n) { n.textContent = S.coins; });
  }
  var toastTimer = null;
  // 1.2.0 (docs/17): bildirim süresi parametreli; yalnızca çarpma uyarısı 2,5 sn, diğerleri 1,6 sn
  var TOAST_MS = 1600, CRASH_TOAST_MS = 2500;
  function toast(msg, ms) {
    var n = $('toast'); n.textContent = msg; n.classList.add('show');
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { n.classList.remove('show'); }, ms || TOAST_MS);
  }
  function buzz(name) { if (S.vibration) SFX.vibrate(name); }

  // Modal
  var modalOnClose = null;
  function openModal(build, onClose) {
    var m = $('modal'), sh = m.firstElementChild;
    sh.innerHTML = ''; sh.id = ''; sh.removeAttribute('data-stars');
    build(sh);
    fillIcons(sh);
    m.hidden = false;
    modalOnClose = onClose || null;
    fitAll(sh);
  }
  function closeModal() {
    var m = $('modal'); if (m.hidden) return;
    m.hidden = true; m.firstElementChild.innerHTML = ''; m.firstElementChild.id = '';
    var cb = modalOnClose; modalOnClose = null; if (cb) cb();
  }
  function modalOpen() { return !$('modal').hidden; }
  function btn(label, cls, onClick, id) {
    var b = el('button', 'btn ' + (cls || 'secondary'));
    b.type = 'button'; b.innerHTML = label; if (id) b.id = id;
    b.addEventListener('click', function () { SFX.button(); buzz('button'); onClick(); });
    return b;
  }
  function confirmBox(text, onYes, yesLabel, danger) {
    openModal(function (sh) {
      sh.appendChild(el('p', null, '')).textContent = text;
      var a = el('div', 'actions row');
      a.appendChild(btn(t('common.cancel'), 'secondary', closeModal, 'confirm-no'));
      a.appendChild(btn(yesLabel || t('common.yes'), danger ? 'danger' : 'primary', function () { closeModal(); onYes(); }, 'confirm-yes'));
      sh.appendChild(a);
    });
  }

  // Ekranlar
  var current = null;
  var renderers = {};
  var mapShown = false; // harita zaten açıksa yeniden çizimde kaydırma konumu korunur
  function show(name) {
    if (name !== 'map') mapShown = false;
    if (modalOpen()) closeModal();
    if (current === 'game' && name !== 'game') stopGame();
    current = name;
    $('toast').classList.remove('show');
    document.querySelectorAll('.screen').forEach(function (s) { s.classList.toggle('active', s.id === 'scr-' + name); });
    if (renderers[name]) renderers[name]();
    updateBanners();
    updateCoins();
    requestAnimationFrame(function () { fitAll($('scr-' + name)); });
  }
  // v1.1 (docs/15 §3): banner yalnızca Ana menü ve Harita'da; web önizlemede kesikli çerçeveli "Reklam alanı" yer tutucusu.
  // Yer tutucu ekranın altında yer ayırır (içerik banner yüksekliği kadar yukarı itilir); reklamsız satın almada gizlenir.
  function updateBanners() {
    var test = M.isTestMode();
    M.BANNER_SCREENS.forEach(function (n) {
      var b = document.querySelector('#scr-' + n + ' .banner');
      if (b) b.hidden = !(test && M.bannerVisible(n));
    });
  }

  // ---------------------------------------------------------------- Ana menü
  renderers.menu = function () {
    var anyProgress = Object.keys(S.stars).length > 0;
    var n = S.unlocked;
    $('btn-play').innerHTML = '<span>' + (anyProgress ? t('menu.continue', { n: n }) : t('menu.play')) + '</span>';
    var st = Store.dailyStatus();
    $('btn-daily').classList.toggle('ready', st.canClaim);
    $('daily-ready').hidden = !st.canClaim;
    // G5: günlük bulmaca durumu (seri / bugün çözüldü)
    var info = window.Daily.streakInfo(S.dp, Store.ymd());
    $('dp-sub').textContent = info.doneToday ? t('dp.done') : t('dp.streak', { n: info.current });
    $('btn-dp').classList.toggle('done', info.doneToday);
    if (S.unlocked > PREBUILT) ensureLevel(S.unlocked); // "Devam" anında açılsın: sonsuz seviyeyi önceden üret
  };
  $('btn-dp').addEventListener('click', function () { SFX.button(); openCalendar(); });
  $('btn-play').addEventListener('click', function () { SFX.button(); startLevel(S.unlocked); });
  $('btn-map').addEventListener('click', function () { SFX.button(); show('map'); });
  $('btn-shop').addEventListener('click', function () { SFX.button(); show('shop'); });
  $('btn-settings').addEventListener('click', function () { SFX.button(); show('settings'); });
  $('btn-daily').addEventListener('click', function () { SFX.button(); openDaily(); });
  document.querySelectorAll('[data-nav]').forEach(function (b) {
    b.addEventListener('click', function () { SFX.button(); show(b.getAttribute('data-nav')); });
  });

  // ---------------------------------------------------------------- Günlük ödül
  function openDaily() {
    openModal(function (sh) {
      var st = Store.dailyStatus();
      sh.appendChild(el('h2', null)).textContent = t('daily.title');
      if (st.streakLost) sh.appendChild(el('p')).textContent = t('daily.streak_lost');
      var days = el('div', 'days');
      var activeDay = st.canClaim ? st.day : (S.daily.streakDay || 1);
      for (var d = 1; d <= 7; d++) {
        var past = st.canClaim ? d < st.day : d < activeDay || (st.claimedToday && d === activeDay);
        var box = el('div', 'day' + (d === 7 ? ' d7' : '') + (d === activeDay ? ' today' : '') + (past && d !== activeDay ? ' past' : ''));
        box.setAttribute('data-day', d);
        box.innerHTML = '<span>' + esc(t('daily.day', { n: d })) + '</span>' + icon('coin') + '<span class="num">' + Store.DAILY[d - 1] + '</span>' +
          (d === 7 ? '<small>' + esc(t('daily.bonus_hint')) + '</small>' : '') +
          (past ? icon('check') : '');
        days.appendChild(box);
      }
      sh.appendChild(days);
      var a = el('div', 'actions');
      if (st.canClaim) {
        a.appendChild(btn(t('daily.claim'), 'primary', function () {
          var r = Store.claimDaily();
          if (r) {
            SFX.coin(); buzz('levelWin'); updateCoins(); renderers.menu();
            toast(t('end.reward', { n: r.coins }) + (r.hint ? ' · ' + t('daily.bonus_hint') : ''));
          }
          openDaily();
        }, 'daily-claim'));
      } else {
        var p = el('p'); p.textContent = st.claimedToday ? t('daily.claimed') + ' · ' + t('daily.come_back') : t('daily.come_back');
        sh.appendChild(p);
      }
      a.appendChild(btn(t('common.close'), 'secondary', closeModal));
      sh.appendChild(a);
    }, function () { if (current === 'menu') renderers.menu(); });
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

  // ---------------------------------------------------------------- Harita
  // v1.5 (docs/15 §5): 500 bölüm (sonrası oyuncuyla birlikte uzar). Tembel liste: yalnızca görünür bölümler (± 1) DOM'da; her bölümün
  // yüksekliği sabit olduğundan konum hesapla bulunur, bölüm sayısı ne olursa olsun çizim maliyeti sabittir. Açılışta oyuncunun
  // bölümüne kaydırılır. Zorluk seviye bazında döner: düğümün köşe noktası kademesini gösterir (Aşırı zor: koyu kırmızı halka).
  var MAP = { STEP: 96, PADB: 48, PADT: 40, TOP: 12, HEAD: 64, GAP: 6, BOT: 18 };
  MAP.PATH_H = MAP.PADB + MAP.PADT + (Store.PER_CHAPTER - 1) * MAP.STEP;
  MAP.CH_H = MAP.TOP + MAP.HEAD + MAP.GAP + MAP.PATH_H + MAP.BOT;
  var mapSt = null; // { chapters, rendered: { c: element }, spacer }
  function roman(n) {
    var m = [[1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'], [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'], [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']], r = '';
    m.forEach(function (p) { while (n >= p[0]) { r += p[1]; n -= p[0]; } });
    return r;
  }
  /** Bölüm adı: mevcut 18 ad döngüyle; tekrarlarda Roma rakamı ("Mağara II"). Rakam Arapçada da Latin harfle, sola-sağa yalıtılır. */
  function chapterName(c) {
    var name = t('map.chapter' + ((c - 1) % 18 + 1)), cyc = Math.floor((c - 1) / 18) + 1;
    return cyc > 1 ? name + ' ⁦' + roman(cyc) + '⁩' : name;
  }
  function mapChapters() { return Math.max(LG.CHAPTERS, Math.ceil(S.unlocked / Store.PER_CHAPTER) + 1); }
  function mapNodeY(i) { return MAP.TOP + MAP.HEAD + MAP.GAP + MAP.PATH_H - MAP.PADB - i * MAP.STEP; }
  function buildChapter(c, chapters) {
    var PER = Store.PER_CHAPTER, first = (c - 1) * PER + 1, last = c * PER, cs = 0, k;
    for (k = first; k <= last; k++) cs += S.stars[k] || 0;
    var ch = el('section', 'chapter'); ch.setAttribute('data-chapter', c);
    ch.style.top = ((chapters - c) * MAP.CH_H) + 'px'; ch.style.height = MAP.CH_H + 'px';
    var head = el('div', 'chapter-head');
    head.innerHTML = '<h3></h3><div class="sub"><div class="pill-in">' + icon('star', 'star-ic') + ' <span class="num">' + cs + '/' + (PER * 3) + '</span></div><div class="bonus"></div></div>';
    head.querySelector('h3').textContent = chapterName(c);
    head.querySelector('.bonus').textContent = S.chapterBonus.indexOf(c) >= 0 ? t('end.chapter_done') : t('map.chapter_bonus', { n: Store.CHAPTER_BONUS });
    var H = MAP.PATH_H, path = el('div', 'path'); path.style.height = H + 'px';
    var pts = [];
    for (var i = 0; i < PER; i++) {
      var x = 50 + 30 * Math.sin(i * Math.PI / 3);
      if (isRTL()) x = 100 - x; // harita yönü aynalanır
      pts.push([x, H - MAP.PADB - i * MAP.STEP]);
    }
    var d = pts.map(function (p, j) { return (j ? 'L' : 'M') + p[0].toFixed(2) + ' ' + p[1]; }).join(' ');
    path.innerHTML = '<svg class="trail" viewBox="0 0 100 ' + H + '" preserveAspectRatio="none" aria-hidden="true">' +
      '<path d="' + d + '" fill="none" stroke="var(--edge)" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/>' +
      '<path d="' + d + '" fill="none" stroke="var(--board)" stroke-width="4" stroke-dasharray="2 12" stroke-linecap="round" vector-effect="non-scaling-stroke"/></svg>';
    for (i = 0; i < PER; i++) {
      var id = first + i, stars = S.stars[id] || 0, locked = id > S.unlocked, tier = Store.tierOfLevel(id);
      var nb = el('button', 'node tier-' + tier + (locked ? ' locked' : stars ? ' done' : '') + (id === S.unlocked ? ' current' : ''));
      nb.type = 'button';
      nb.style.left = pts[i][0] + '%'; nb.style.top = pts[i][1] + 'px';
      nb.setAttribute('data-level', id); nb.setAttribute('data-diff', tier);
      nb.setAttribute('aria-label', t('map.level', { n: id }) + ' · ' + t('diff.' + tier) + (locked ? ' — ' + t('map.locked') : ''));
      nb.innerHTML = (locked ? icon('lock') : '<span>' + id + '</span>') +
        (!locked && stars ? '<span class="node-stars">' + [1, 2, 3].map(function (s) { return icon(s <= stars ? 'star' : 'starEmpty'); }).join('') + '</span>' : '');
      (function (id, locked) {
        nb.addEventListener('click', function () {
          if (locked) { SFX.error(); toast(t('map.locked_hint')); return; }
          SFX.button(); startLevel(id);
        });
      })(id, locked);
      path.appendChild(nb);
      if (i % 5 === 0) { // 1.2.0: her kademe diliminin başında küçük etiket (Kolay / Orta / Zor / Aşırı zor)
        var tl = el('span', 'tier-label d-' + tier); tl.textContent = t('diff.' + tier);
        tl.style.left = (pts[i][0] + (pts[i][0] > 50 ? -30 : 30)) + '%'; tl.style.top = pts[i][1] + 'px';
        path.appendChild(tl);
      }
    }
    var wrap = el('div', 'chapter-in'); wrap.appendChild(head); wrap.appendChild(path); ch.appendChild(wrap);
    return ch;
  }
  /** Görünen bölüm aralığını (± 1) çizer, dışındakileri DOM'dan kaldırır. */
  function updateMapWindow() {
    if (!mapSt) return;
    var sc = $('map-scroll'), top = sc.scrollTop, vh = sc.clientHeight || 600, n = mapSt.chapters;
    var i0 = Math.max(0, Math.floor(top / MAP.CH_H) - 1), i1 = Math.min(n - 1, Math.floor((top + vh) / MAP.CH_H) + 1);
    var want = {}, added = false;
    for (var i = i0; i <= i1; i++) want[n - i] = true; // üstten i. satır = bölüm n - i
    Object.keys(mapSt.rendered).forEach(function (c) { if (!want[c]) { mapSt.rendered[c].remove(); delete mapSt.rendered[c]; } });
    Object.keys(want).forEach(function (c) {
      if (!mapSt.rendered[c]) { var e = buildChapter(Number(c), n); mapSt.spacer.appendChild(e); mapSt.rendered[c] = e; added = true; }
    });
    if (added) fitAll(sc);
  }
  var mapRaf = 0;
  $('map-scroll').addEventListener('scroll', function () {
    if (mapRaf) return;
    mapRaf = requestAnimationFrame(function () { mapRaf = 0; updateMapWindow(); });
  }, { passive: true });
  renderers.map = function () {
    var keep = mapShown; mapShown = true;
    var chapters = mapChapters(), PER = Store.PER_CHAPTER;
    var total = Store.totalStars(), max = chapters * PER * 3;
    $('map-stars').textContent = total + '/' + max;
    $('map-stars').parentNode.setAttribute('aria-label', t('map.stars_total', { n: total, max: max }));
    var sc = $('map-scroll'), prevTop = sc.scrollTop;
    sc.innerHTML = '';
    var spacer = el('div', 'map-spacer'); spacer.style.height = (chapters * MAP.CH_H) + 'px';
    sc.appendChild(spacer);
    mapSt = { chapters: chapters, rendered: {}, spacer: spacer };
    if (keep && prevTop > 0) sc.scrollTop = prevTop;
    else { // oyuncunun düğümünü ekranın ortasına getir
      var cur = Math.min(S.unlocked, Math.max(1, mapChapters() * PER)), cc = Math.floor((cur - 1) / PER) + 1;
      var y = (chapters - cc) * MAP.CH_H + mapNodeY((cur - 1) % PER);
      sc.scrollTop = Math.max(0, y - (sc.clientHeight || 600) / 2);
    }
    updateMapWindow();
  };

  // ---------------------------------------------------------------- Mağaza
  var shopTab = 'themes';
  document.querySelectorAll('.tab').forEach(function (b) {
    b.addEventListener('click', function () { SFX.button(); shopTab = b.getAttribute('data-tab'); renderers.shop(); fitAll($('scr-shop')); });
  });
  function themePreview(cv, themeIdx) {
    var dpr = Math.min(3, window.devicePixelRatio || 1), W = 88, H = 64;
    cv.width = W * dpr; cv.height = H * dpr;
    var ctx = cv.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    var th = T.arrowThemes[themeIdx], c = 20;
    window.drawArrow(ctx, { x: 6, y: 4, cell: c, dir: 'R', len: 3, color: th.colors[0], chevron: th.chevron });
    window.drawArrow(ctx, { x: 66, y: 4, cell: c, dir: 'D', len: 2, color: th.colors[1], chevron: th.chevron });
    window.drawArrow(ctx, { x: 6, y: 26, cell: c, dir: 'U', len: 2, color: th.colors[2], chevron: th.chevron });
    window.drawArrow(ctx, { x: 26, y: 40, cell: c, dir: 'L', len: 2, color: th.colors[3], chevron: th.chevron });
    window.drawArrow(ctx, { x: 46, y: 24, cell: c, dir: 'R', len: 1, color: th.colors[4], chevron: th.chevron });
  }
  renderers.shop = function () {
    $('shop-balance').textContent = t('shop.balance', { n: S.coins });
    document.querySelectorAll('.tab').forEach(function (b) {
      var on = b.getAttribute('data-tab') === shopTab;
      b.classList.toggle('on', on); b.setAttribute('aria-selected', on ? 'true' : 'false');
    });
    var list = $('shop-list'); list.innerHTML = '';
    if (shopTab === 'themes') {
      T.arrowThemes.forEach(function (th, idx) {
        var owned = S.themesOwned.indexOf(th.id) >= 0, inUse = S.theme === th.id;
        var it = el('div', 'item'); it.setAttribute('data-theme', th.id);
        var cv = el('canvas'); cv.setAttribute('aria-hidden', 'true'); it.appendChild(cv);
        var main = el('div', 'item-main');
        main.appendChild(el('div', 'item-name')).textContent = t('theme.' + th.id);
        var pr = el('div', 'item-price');
        if (th.price === 0) pr.textContent = t('shop.free');
        else if (owned) pr.textContent = t('shop.owned');
        else pr.innerHTML = icon('coin') + '<span>' + esc(t('shop.price', { n: th.price })) + '</span>';
        main.appendChild(pr);
        it.appendChild(main);
        var b;
        if (inUse) { b = btn(icon('check') + '<span>' + esc(t('shop.equipped')) + '</span>', 'equipped', function () {}); b.disabled = false; }
        else if (owned) b = btn(t('shop.equip'), 'secondary', function () { S.theme = th.id; Store.save(); renderers.shop(); fitAll(list); });
        else b = btn(t('shop.buy'), 'primary', function () {
          if (S.coins < th.price) { SFX.error(); buzz('error'); toast(t('game.not_enough_coins')); return; }
          confirmBox(t('shop.confirm', { n: th.price }), function () {
            if (S.coins < th.price) return;
            S.coins -= th.price; S.themesOwned.push(th.id); S.theme = th.id; Store.save();
            SFX.coin(); toast(t('shop.bought')); updateCoins(); renderers.shop(); fitAll(list);
          }, t('shop.buy'));
        });
        it.appendChild(b);
        list.appendChild(it);
        themePreview(cv, idx);
      });
    } else {
      [['hint', 'bulb', 'game.hint', 'shop.hint_desc', S.freeHints]].forEach(function (r) {
        var it = el('div', 'item');
        it.innerHTML = icon(r[1], 'big');
        var main = el('div', 'item-main');
        main.appendChild(el('div', 'item-name')).textContent = t(r[2]);
        main.appendChild(el('div', 'item-desc')).textContent = t(r[3]);
        var pr = el('div', 'item-price');
        pr.innerHTML = icon('coin') + '<span>' + esc(t('shop.price', { n: Store.PRICES[r[0]] })) + '</span>' +
          (r[4] > 0 ? '<span class="tool-sub free"> · ' + esc(t('game.free_left', { n: r[4] })) + '</span>' : '');
        main.appendChild(pr);
        it.appendChild(main);
        if (r[0] === 'hint' && M.rewardedOffered()) {
          it.appendChild(btn(t('ads.watch_hint'), 'secondary', function () { watchForHint(); }, 'shop-watch-hint'));
        }
        list.appendChild(it);
      });
      list.appendChild(buildCoinAdItem());
    }
    var ra = $('shop-ads'); ra.innerHTML = ''; buildAdsCard(ra, 'shop');
    updateCoins();
  };

  // ---------------------------------------------------------------- Reklamları kaldır / geri yükle (Mağaza + Ayarlar)
  function buildAdsCard(box, where) {
    var it = el('div', 'item ads-card');
    it.innerHTML = icon('noads', 'big');
    var main = el('div', 'item-main');
    main.appendChild(el('div', 'item-name')).textContent = t('ads.remove_title');
    if (!M.isAdFree()) main.appendChild(el('div', 'item-desc')).textContent = t('ads.remove_desc');
    if (M.isTestMode()) main.appendChild(el('div', 'item-desc test-note')).textContent = t('ads.test_mode');
    it.appendChild(main);
    var col = el('div', 'ads-actions');
    if (M.isAdFree()) {
      var ok = btn(icon('check') + '<span>' + esc(t('ads.ad_free')) + '</span>', 'equipped', function () {}, where + '-adfree');
      col.appendChild(ok);
    } else {
      col.appendChild(btn(t('ads.remove_title'), 'primary', function () { buyRemoveAds(); }, where + '-remove-ads'));
    }
    col.appendChild(btn(t('ads.restore'), 'ghost', function () { restorePurchases(); }, where + '-restore'));
    it.appendChild(col);
    box.appendChild(it);
  }
  var purchaseBusy = false;
  function refreshAfterPurchase() { if (renderers[current]) renderers[current](); updateBanners(); fitAll($('scr-' + current)); }
  function buyRemoveAds() {
    if (purchaseBusy) return; purchaseBusy = true;
    M.purchaseRemoveAds(function (r) {
      purchaseBusy = false;
      if (r.ok) { SFX.coin(); toast(t('ads.purchased') + (r.test ? ' · ' + t('ads.test_mode') : '')); }
      else if (r.reason === 'pending') toast(t('ads.pending'));
      else { SFX.error(); toast(t(r.reason === 'cancelled' ? 'ads.cancelled' : r.reason === 'offline' ? 'ads.offline' : 'ads.failed')); }
      refreshAfterPurchase();
    });
  }
  function restorePurchases() {
    if (purchaseBusy) return; purchaseBusy = true;
    M.restorePurchases(function (r) {
      purchaseBusy = false;
      if (!r.ok) { SFX.error(); toast(t(r.reason === 'offline' ? 'ads.offline' : 'ads.failed')); }
      else toast(r.adFree ? t('ads.restored_ok') : t('ads.restored_none'));
      refreshAfterPurchase();
    });
  }
  function refreshAfterReward() {
    updateCoins();
    if (current === 'game') updateHUD(); else if (renderers[current]) { renderers[current](); fitAll($('scr-' + current)); }
  }
  function watchForHint() {
    playRewarded('hint', function () { S.freeHints++; Store.save(); }, function (rewarded) {
      if (rewarded) { SFX.coin(); toast(t('ads.reward_hint')); }
      refreshAfterReward();
    });
  }
  // Ödüllü reklamdan jeton (+50, günde en çok 10; kural: Store.grantAdCoins)
  function watchForCoins(after) {
    if (Store.coinAdsLeft() <= 0) { SFX.error(); toast(t('ads.coins_limit')); if (after) after(false); return; }
    playRewarded('coins', function () { Store.grantAdCoins(); }, function (rewarded) {
      if (rewarded) { SFX.coin(); toast(t('ads.reward_coins', { n: Store.AD_COINS })); }
      refreshAfterReward();
      if (after) after(rewarded);
    });
  }
  function buildCoinAdItem() {
    var left = Store.coinAdsLeft();
    var it = el('div', 'item'); it.id = 'shop-coin-ad';
    it.innerHTML = icon('coin', 'big');
    var main = el('div', 'item-main');
    main.appendChild(el('div', 'item-name')).textContent = t('ads.watch_coins', { n: Store.AD_COINS });
    main.appendChild(el('div', 'item-desc')).textContent = t('ads.coins_desc', { max: Store.MAX_COIN_ADS });
    main.appendChild(el('div', 'item-price')).textContent = left > 0 ? t('ads.coins_left', { n: left, max: Store.MAX_COIN_ADS }) : t('ads.coins_limit');
    it.appendChild(main);
    if (left > 0 && M.rewardedOffered()) it.appendChild(btn(t('ads.watch_coins', { n: Store.AD_COINS }), 'secondary', function () { watchForCoins(); }, 'shop-watch-coins'));
    return it;
  }
  // Ödüllü reklamı DOKUNUŞTA yükleyip gösterir (önceden yüklenmiş olmasına bağlı değil).
  // onReward(): ödül hak edilince en çok bir kez; onDone(rewarded): her durumda bir kez. Reklam yoksa yerelleştirilmiş toast.
  var rewardBusy = false;
  function showAdLoading(on) {
    var n = $('ad-loading');
    if (!on) { if (n) n.remove(); return; }
    if (n) return;
    n = el('div', 'ad-loading'); n.id = 'ad-loading'; n.setAttribute('role', 'status');
    var box = el('div', 'ad-loading-box');
    box.appendChild(el('div', 'ad-spinner'));
    box.appendChild(el('div', 'ad-loading-text')).textContent = t('ads.loading');
    n.appendChild(box);
    document.body.appendChild(n);
  }
  function playRewarded(placement, onReward, onDone) {
    if (rewardBusy) return;
    rewardBusy = true;
    var finished = false;
    function finish(rewarded) { if (finished) return; finished = true; rewardBusy = false; showAdLoading(false); try { onDone && onDone(rewarded); } catch (e) {} }
    function unavailable(code) {
      SFX.error();
      toast(t('ads.unavailable') + (Store.DEBUG && code ? ' (' + code + ')' : ''));
      finish(false);
    }
    // "Reklam yükleniyor…" kaplaması yalnızca gerçekten bekleniyorsa ve 300 ms'den uzun sürerse görünür (docs/15 §4)
    var ready = !M.hasBridge() || M.rewardedAvailable(), loaded = false, loadTimer = 0;
    if (!ready) loadTimer = setTimeout(function () { loadTimer = 0; if (!loaded && !finished) showAdLoading(true); }, M.RULES.loadingOverlayMs);
    M.ensureRewardedLoaded(function (r) {
      loaded = true; if (loadTimer) { clearTimeout(loadTimer); loadTimer = 0; }
      showAdLoading(false);
      if (!r.ok) { unavailable(r.code); return; }
      M.showRewarded(placement, onReward, function (rewarded) {
        if (!rewarded) toast(t('ads.no_reward'));
        finish(rewarded);
      });
    });
  }

  // ---------------------------------------------------------------- Ayarlar
  function sw(on, onToggle, id) {
    var b = el('button', 'switch'); b.type = 'button'; b.id = id;
    b.setAttribute('role', 'switch'); b.setAttribute('aria-checked', on ? 'true' : 'false');
    b.addEventListener('click', function () { var v = b.getAttribute('aria-checked') !== 'true'; b.setAttribute('aria-checked', v ? 'true' : 'false'); onToggle(v); });
    return b;
  }
  function switchRow(labelKey, descKey, on, onToggle, id) {
    var row = el('div', 'set-row');
    var txt = el('div', 'set-txt'), lb = el('span', 'set-name'); lb.textContent = t(labelKey); lb.id = id + '-l'; txt.appendChild(lb);
    if (descKey) txt.appendChild(el('small', 'set-desc')).textContent = t(descKey);
    var b = sw(on, onToggle, id); b.setAttribute('aria-labelledby', lb.id);
    row.appendChild(txt); row.appendChild(b);
    return row;
  }
  function group(labelKey, cls) {
    var g = el('div', 'set-group' + (cls ? ' ' + cls : ''));
    if (labelKey) g.appendChild(el('div', 'set-label')).textContent = t(labelKey);
    return g;
  }
  renderers.settings = function () {
    var body = $('settings-body'); body.innerHTML = '';
    var g1 = group(null);
    g1.appendChild(switchRow('settings.sound', null, S.sound, function (v) { S.sound = v; SFX.setEnabled(v); Store.save(); if (v) SFX.button(); }, 'sw-sound'));
    g1.appendChild(switchRow('settings.vibration', null, S.vibration, function (v) { S.vibration = v; SFX.setVibration(v); Store.save(); if (v) buzz('button'); }, 'sw-vib'));
    body.appendChild(g1);

    // G3 rahat mod + G1 önce seç, sonra fırlat
    var gp = group('settings.gameplay');
    gp.appendChild(switchRow('settings.relaxed', 'settings.relaxed_desc', S.relaxed, function (v) { S.relaxed = v; Store.save(); }, 'sw-relaxed'));
    gp.appendChild(switchRow('settings.aim', 'settings.aim_desc', S.aim, function (v) { S.aim = v; aimSel = -1; Store.save(); }, 'sw-aim'));
    body.appendChild(gp);

    // G7 görünüm: Otomatik / Açık / Koyu
    var ga = group('settings.appearance');
    var seg = el('div', 'seg'); seg.setAttribute('role', 'radiogroup');
    ['auto', 'light', 'dark'].forEach(function (m) {
      var b = el('button', 'seg-btn' + (S.appearance === m ? ' on' : '')); b.type = 'button'; b.id = 'app-' + m;
      b.setAttribute('role', 'radio'); b.setAttribute('aria-checked', S.appearance === m ? 'true' : 'false');
      b.textContent = t('settings.app_' + m);
      b.addEventListener('click', function () { SFX.button(); S.appearance = m; Store.save(); applyAppearance(); renderers.settings(); fitAll(body); });
      seg.appendChild(b);
    });
    ga.appendChild(seg);
    // 1.2.0 (docs/17 §13): ok rengi — Renkli / Tek renk (ince çizgi; açık temada koyu, koyu temada açık)
    var acl = el('div', 'set-sub'); acl.id = 'ac-label'; acl.textContent = t('settings.arrow_color'); ga.appendChild(acl);
    var seg2 = el('div', 'seg seg2'); seg2.setAttribute('role', 'radiogroup'); seg2.setAttribute('aria-labelledby', 'ac-label');
    ['color', 'mono'].forEach(function (m) {
      var on = (S.arrowColor || 'color') === m;
      var b = el('button', 'seg-btn' + (on ? ' on' : '')); b.type = 'button'; b.id = 'ac-' + m;
      b.setAttribute('role', 'radio'); b.setAttribute('aria-checked', on ? 'true' : 'false');
      b.innerHTML = '<span class="ac-prev ac-' + m + '" aria-hidden="true"><i></i><i></i><i></i></span><span></span>';
      b.lastChild.textContent = t('settings.ac_' + m);
      b.addEventListener('click', function () { SFX.button(); S.arrowColor = m; Store.save(); renderers.settings(); fitAll(body); });
      seg2.appendChild(b);
    });
    ga.appendChild(seg2);
    ga.appendChild(el('small', 'set-desc ac-desc')).textContent = t('settings.arrow_color_desc');
    body.appendChild(ga);

    var g2 = group('settings.language');
    var langs = el('div', 'langs');
    Store.LANGS.forEach(function (l) {
      var b = el('button', 'lang-btn' + (S.lang === l ? ' on' : '')); b.type = 'button';
      b.setAttribute('lang', l); b.setAttribute('dir', T.isRTL(l) ? 'rtl' : 'ltr'); b.setAttribute('data-lang', l);
      b.setAttribute('aria-pressed', S.lang === l ? 'true' : 'false');
      b.textContent = t('lang.' + l);
      b.addEventListener('click', function () { SFX.button(); setLang(l); });
      langs.appendChild(b);
    });
    g2.appendChild(langs);
    body.appendChild(g2);

    var g3 = group('settings.support', 'support');
    g3.appendChild(el('p')).textContent = t('settings.support_text');
    var a = el('a'); a.href = 'mailto:' + SUPPORT_EMAIL + '?subject=' + encodeURIComponent(t('app.name') + ' ' + VERSION);
    a.textContent = SUPPORT_EMAIL; a.id = 'support-link'; g3.appendChild(a);
    body.appendChild(g3);

    // G6 yedekleme
    var gb = group('settings.backup');
    var row = el('div', 'btn-row');
    row.appendChild(btn(t('settings.export'), 'secondary', openExport, 'btn-export'));
    row.appendChild(btn(t('settings.import'), 'secondary', openImport, 'btn-import'));
    gb.appendChild(row);
    body.appendChild(gb);

    var g4 = group('ads.section', 'ads-group');
    buildAdsCard(g4, 'set');
    // UMP "Gizlilik seçenekleri": yalnızca Android köprüsü varsa ve bölge gerektiriyorsa (AEA/BK/İsviçre …) görünür
    if (M.privacyOptionsRequired()) {
      g4.appendChild(btn(t('ads.privacy_options'), 'secondary block', function () {
        M.showPrivacyOptions(function () { if (current === 'settings') { renderers.settings(); fitAll(body); } });
      }, 'btn-privacy-options'));
    }
    body.appendChild(g4);

    body.appendChild(btn(t('privacy.title'), 'secondary block', function () { show('privacy'); }, 'btn-privacy'));
    body.appendChild(btn(t('settings.reset'), 'danger block', function () {
      confirmBox(t('settings.reset_confirm'), function () {
        S = Store.resetProgress(); SFX.setEnabled(S.sound); SFX.setVibration(S.vibration); applyAppearance();
        updateCoins(); toast(t('settings.reset_done')); renderers.settings(); fitAll(body);
      }, t('settings.reset'), true);
    }, 'btn-reset'));
    body.appendChild(el('p', 'privacy')).textContent = t('settings.privacy');
    body.appendChild(el('p', 'version')).textContent = t('settings.version', { v: VERSION });
  };

  // ---- G6: ilerlemeyi dışa / içe aktar
  function copyText(ta) {
    var done = function () { SFX.button(); toast(t('backup.copied')); };
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(ta.value).then(done, function () { legacy(); }); return; }
    } catch (e) {}
    legacy();
    function legacy() { try { ta.removeAttribute('readonly'); ta.select(); ta.setSelectionRange(0, ta.value.length); document.execCommand('copy'); ta.setAttribute('readonly', ''); done(); } catch (e) {} }
  }
  function openExport() {
    openModal(function (sh) {
      sh.id = 'export-sheet';
      sh.appendChild(el('h2')).textContent = t('settings.export');
      sh.appendChild(el('p')).textContent = t('backup.export_text');
      var ta = el('textarea', 'code-box'); ta.id = 'backup-code'; ta.readOnly = true; ta.rows = 4; ta.value = Store.exportCode();
      ta.setAttribute('aria-label', t('settings.backup')); ta.setAttribute('dir', 'ltr'); ta.spellcheck = false;
      sh.appendChild(ta);
      var a = el('div', 'actions row');
      a.appendChild(btn(t('common.close'), 'secondary', closeModal));
      a.appendChild(btn(t('backup.copy'), 'primary', function () { copyText(ta); }, 'backup-copy'));
      sh.appendChild(a);
    });
  }
  function openImport() {
    openModal(function (sh) {
      sh.id = 'import-sheet';
      sh.appendChild(el('h2')).textContent = t('settings.import');
      sh.appendChild(el('p')).textContent = t('backup.import_text');
      var ta = el('textarea', 'code-box'); ta.id = 'import-code'; ta.rows = 4; ta.setAttribute('dir', 'ltr'); ta.spellcheck = false;
      ta.setAttribute('aria-label', t('settings.import')); ta.autocomplete = 'off';
      sh.appendChild(ta);
      var a = el('div', 'actions row');
      a.appendChild(btn(t('common.cancel'), 'secondary', closeModal));
      a.appendChild(btn(t('settings.import'), 'primary', function () {
        var code = ta.value;
        if (!Store.parseCode(code)) { SFX.error(); buzz('error'); toast(t('backup.invalid')); return; }
        confirmBox(t('backup.import_confirm'), function () {
          var ns = Store.importCode(code);
          if (!ns) { toast(t('backup.invalid')); return; }
          S = ns; SFX.setEnabled(S.sound); SFX.setVibration(S.vibration); applyAppearance();
          SFX.coin(); toast(t('backup.imported')); updateCoins(); show('settings');
        }, t('settings.import'));
      }, 'import-go'));
      sh.appendChild(a);
    });
  }

  // ---- G7: görünüm (DOM + canvas paleti)
  var mqDark = null;
  try { mqDark = window.matchMedia('(prefers-color-scheme: dark)'); } catch (e) {}
  function applyAppearance() {
    var m = S.appearance || 'auto';
    document.documentElement.setAttribute('data-theme', m);
    T.forceMode = m === 'auto' ? null : m;
    var dark = m === 'dark' || (m === 'auto' && mqDark && mqDark.matches);
    document.querySelectorAll('meta[name="theme-color"]').forEach(function (n) { n.setAttribute('content', dark ? '#0F1B27' : '#E3E9EE'); });
    try { if (window.AndroidBridge && typeof window.AndroidBridge.setSystemBarsDark === 'function') window.AndroidBridge.setSystemBarsDark(!!dark); } catch (e) {}
    if (typeof draw === 'function' && LV) draw();
  }
  if (mqDark && mqDark.addEventListener) mqDark.addEventListener('change', function () { if ((S.appearance || 'auto') === 'auto') applyAppearance(); });

  // ---------------------------------------------------------------- Gizlilik politikası
  renderers.privacy = function () { window.renderPrivacy($('privacy-body'), t); };

  function setLang(l) {
    if (Store.LANGS.indexOf(l) < 0) return;
    S.lang = l; Store.save();
    applyI18n();
    if (renderers[current]) renderers[current]();
    if (current === 'game') { updateHUD(); refreshTutorial(); resize(); }
    fitAll();
  }

  // ================================================================= OYUN
  var cv = $('board'), ctx = cv.getContext('2d');
  var G = null;            // OkEngine.Game
  var LV = null;           // seviye
  var lay = { cell: 40, ox: 0, oy: 0, w: 0, h: 0, dpr: 1 };
  var anims = {};          // i -> {kind, t0, dur, ...}
  var colorMap = null;     // v1.3: {lv, k, c[]} komşu oklar farklı renk
  var shake = null;        // {t0, dur, ax, ay}
  var hintIdx = -1, hintUntil = 0;
  var rafId = 0, busy = false, exitStreak = 0;
  var tut = null;          // öğretici durumu
  var session = 0, winDone = false; // eski zamanlayıcıların yeni seviyeye sızmasını engeller
  var view = { s: 1, x: 0, y: 0 };  // G2: yakınlaştırma/kaydırma (tahta koordinatı → ekran)
  var aimSel = -1;                  // G1: "önce seç, sonra fırlat" seçili ok
  var flash = null;                 // G1: belirsiz dokunuşta kısa vurgu {ids, t0}
  var tipShown = {};                // oturum içi tek seferlik uyarılar
  var playMs = 0, lastTapAt = 0;    // 1.2.0: hız rozeti için etkin oyun süresi

  function themeIndex() { var i = Store.THEME_IDS.indexOf(S.theme); return i < 0 ? 0 : i; }

  // ---- v1.3 sonsuz devam (docs/09): hazır 216 seviyeden sonrası oyunda, seviye numarasından türetilen sabit
  // tohumla üretilir (LevelGen.levelJob — herkes için aynı). Üretim arka planda adım adım (tek build) yapılır;
  // sıradaki seviye oyuncu oynarken önceden üretilir ve küçük bir önbellekte (kayıt anahtarı + '.endless') tutulur.
  var LG = window.LevelGen, PREBUILT = LEVELS.length;
  var ENDLESS_KEY = Store.KEY + '.endless', endless = {}, genQueue = [], genJob = null, genWait = {}, lastInput = 0, genStats = [];
  try { var ec = JSON.parse(localStorage.getItem(ENDLESS_KEY) || 'null'); if (ec && ec.v === LG.VERSION && ec.levels) endless = ec.levels; } catch (e) {}
  function saveEndless() {
    var keep = {}, ids = Object.keys(endless).map(Number).sort(function (a, b) { return b - a; }).slice(0, 4); // en yeni 4 seviye
    ids.forEach(function (k) { keep[k] = endless[k]; }); endless = keep;
    try { localStorage.setItem(ENDLESS_KEY, JSON.stringify({ v: LG.VERSION, levels: keep })); } catch (e) {}
  }
  function getLevel(id) { return id <= PREBUILT ? LEVELS[id - 1] || null : endless[id] || null; }
  function ensureLevel(id, cb) {
    if (id < 1 || id > Store.MAX_LEVEL) return;
    var lv = getLevel(id); if (lv) { if (cb) cb(lv); return; }
    if (cb) (genWait[id] = genWait[id] || []).push(cb);
    if (genQueue.indexOf(id) < 0 && !(genJob && genJob.id === id)) { if (cb) genQueue.unshift(id); else genQueue.push(id); }
    genTick();
  }
  var genTimer = 0;
  function genTick() {
    if (genTimer) return;
    genTimer = setTimeout(function () {
      genTimer = 0;
      if (!genJob) { var id = genQueue.shift(); if (!id) return; genJob = LG.levelJob(id); genJob.t0 = performance.now(); genJob.work = 0; }
      // önceden üretim: animasyon ya da yeni dokunuş varken bekle (oyuncu beklemiyorsa)
      var urgent = !!(genWait[genJob.id] && genWait[genJob.id].length);
      if (!urgent && (Object.keys(anims).length || performance.now() - lastInput < 700)) { genTick(); return; }
      var s0 = performance.now(), done = genJob.step(); genJob.work += performance.now() - s0;
      if (done) {
        var r = genJob.result(), lv = { id: r.id, w: r.w, h: r.h, par: r.par, diff: r.diff, arrows: r.arrows };
        if (r.mask) lv.mask = r.mask; // şekilli tahta
        genStats.push({ id: r.id, ms: Math.round(genJob.work), wall: Math.round(performance.now() - genJob.t0), rounds: r.rounds, ok: r.ok });
        endless[r.id] = lv; saveEndless();
        var w = genWait[r.id] || []; delete genWait[r.id]; genJob = null;
        w.forEach(function (f) { f(lv); });
      }
      genTick();
    }, 16);
  }
  function prefetchNext(id) { if (id + 1 > PREBUILT) ensureLevel(id + 1); }
  var pendingStart = 0;
  function startLevel(id) {
    M.closeLevelEnd(); // 1.1.3: yeni seviye başladı: önceki seviye sonu yerleştirmesi geçersiz
    var lv = getLevel(id);
    if (lv) { pendingStart = 0; playLevel(lv); return; }
    if (id <= PREBUILT || id > Store.MAX_LEVEL) return;
    pendingStart = id;
    openModal(function (sh) { sh.appendChild(el('p', 'preparing')).textContent = t('game.preparing'); });
    ensureLevel(id, function (l) {
      if (pendingStart !== id) return;
      pendingStart = 0; closeModal(); playLevel(l);
    });
  }
  // G5: günlük bulmaca (id 0, lv.daily = 'YYYY-MM-DD'). Reklam, harita ilerlemesi ve bölüm bonusu yok.
  var dpCache = {};
  function dailyLevel(ymd) { if (!dpCache[ymd]) dpCache[ymd] = window.Daily.puzzleFor(ymd); return dpCache[ymd]; }
  function startDaily() { var lv = dailyLevel(Store.ymd()); if (lv) playLevel(lv); }
  function isDaily() { return !!(LV && LV.daily); }
  var revivedFor = null; // ödüllü +1 can kullanılan seviye (baştan başlayınca sıfırlanmaz)
  function levelKey() { return LV ? (LV.daily || String(LV.id)) : null; }
  function playLevel(lv) {
    if (!LV || (lv.daily || String(lv.id)) !== levelKey()) revivedFor = null;
    LV = lv; var id = lv.id;
    var tutorial = !lv.daily && id <= 3 && S.tutorialDone.indexOf(id) < 0;
    G = new E.Game(LV, { noLifeLoss: tutorial && id === 2, relaxed: !!S.relaxed });
    anims = {}; shake = null; hintIdx = -1; busy = false; lockUntil = 0; exitStreak = 0; session++; winDone = false;
    view = { s: 1, x: 0, y: 0 }; aimSel = -1; flash = null; viewAnim = null; fling = null; tray = null; playMs = 0; lastTapAt = 0;
    tut = tutorial ? { id: id, step: 0 } : null;
    if (!lv.daily) prefetchNext(id);
    show('game');
    M.preloadRewarded(); // oyun ekranı açılınca ödüllü reklam önceden yüklenir (docs/15 §4)
    resize();
    updateHUD();
    refreshTutorial();
    curveTip = false;
    // v1.3 (docs/09): ilk kıvrımlı ok (seviye 4) tek cümlelik baloncukla tanıtılır; bir kez
    if (!tut && !lv.daily && !hasTip('curve_tip') && lv.arrows.some(function (a) { return LG.isCurved(a); })) {
      curveTip = true; $('bubble-text').textContent = t('tut.curve'); $('bubble').hidden = false; $('bubble').classList.add('pass');
    }
    draw();
    oneTimeTips();
  }
  function hasTip(k) { return S.tips.indexOf(k) >= 0; }
  function markTip(k) { if (!hasTip(k)) { S.tips.push(k); Store.save(); } }
  function oneTimeTips() {
    // 1.2.0: tahta ekrana sığmıyorsa bir kez kaydırma/yakınlaştırma ipucu (isabet hücre bazlı olduğundan "önce seç" önerisi kalktı)
    if (pannable() && !hasTip('zoom_tip') && !tut) { markTip('zoom_tip'); toast(t('game.pan_tip'), 2600); }
  }
  function stopGame() { cancelAnimationFrame(rafId); rafId = 0; hideTutorial(); }
  renderers.game = function () { if (LV) updateHUD(); };

  function updateHUD() {
    if (!G) return;
    $('game-level').textContent = isDaily() ? t('dp.level', { v: dayLabel(LV.daily) }) : t('game.level', { n: LV.id });
    $('game-left').textContent = t('game.arrows_left', { n: G.remaining() });
    var gd = $('game-diff'); gd.hidden = !LV.diff;
    if (LV.diff) { gd.className = 'diff-tag game-diff d-' + LV.diff; gd.textContent = t('diff.' + LV.diff); }
    var h = $('hearts'); h.innerHTML = '';
    if (G.opts.relaxed) { // G3: rahat modda can yok
      h.innerHTML = '<span class="relaxed-badge">' + icon('leaf') + '<span></span></span>';
      h.querySelector('.relaxed-badge > span:last-child').textContent = t('game.relaxed_badge');
      h.setAttribute('aria-label', t('settings.relaxed'));
    } else {
      for (var i = 0; i < E.MAX_LIVES; i++) h.insertAdjacentHTML('beforeend', icon('heart', i < G.lives ? '' : 'lost'));
      h.setAttribute('aria-label', t('game.lives') + ': ' + G.lives);
    }
    var hs = $('hint-sub');
    hs.textContent = S.freeHints > 0 ? t('game.free_left', { n: S.freeHints }) : t('shop.price', { n: Store.PRICES.hint });
    hs.classList.toggle('free', S.freeHints > 0);
    updateCoins();
  }

  // 1.2.0 (docs/17 §14): tahta ekrana sığmak zorunda değil. Varsayılan yakınlıkta (s = 1) hücre en az MIN_CELL px;
  // tahta bundan büyükse tek parmakla kaydırılır, iki parmakla yakınlaştırılır. s = sMin: tüm tahta görünür ("Sığdır").
  var MIN_CELL = 20, FIT_OK = 18, MAX_CELL = 72, ZOOM_CELL = 64; // AYAR: varsayılan en küçük hücre, kaydırmasız kabul edilen en küçük hücre, en büyük hücre, en yakın hücre (px)
  var TOP_BAND = 36; // tahta alanının üstünde zorluk etiketi için ayrılan şerit (px)
  var tray = null, boxes = null, viewAnim = null, fling = null;
  function resize() {
    if (!LV) return;
    var wrap = $('board-wrap'), W = wrap.clientWidth, H = wrap.clientHeight;
    if (!W || !H) return;
    var dpr = Math.min(3, window.devicePixelRatio || 1);
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    var padF = T.boardPadFor(LV.w) * 2;
    var fit = Math.min((W - 4) / (LV.w + padF), (H - 12 - TOP_BAND) / (LV.h + padF + 0.1), MAX_CELL);
    // sığan hücre FIT_OK px'ten küçük değilse tahta tam sığar (kaydırma yok); daha küçükse varsayılan hücre MIN_CELL olur ve tahta kaydırılır
    var cell = fit >= FIT_OK ? Math.floor(fit) : MIN_CELL;
    lay = { cell: cell, dpr: dpr, W: W, H: H, fit: fit, sMin: Math.min(1, fit / cell), sMax: Math.max(2.5, ZOOM_CELL / cell),
      ox: Math.round((W - LV.w * cell) / 2), oy: TOP_BAND + Math.round((H - TOP_BAND - LV.h * cell) / 2) };
    clampView(); updateFitBtn();
    draw();
    positionTutorial();
  }

  // ---- yakınlaştırma / kaydırma (görünüm: tahta koordinatı → ekran = p·s + (x, y))
  function trayBox() { var p = T.boardPadFor(LV.w) * lay.cell; return [lay.ox - p, lay.oy - p, lay.ox + LV.w * lay.cell + p, lay.oy + LV.h * lay.cell + p]; }
  function clampV(v) {
    if (!LV) return v;
    v.s = Math.max(lay.sMin || 1, Math.min(lay.sMax || 5, v.s));
    var b = trayBox();
    [[0, lay.W, 2, 2], [1, lay.H, TOP_BAND, 8]].forEach(function (ax) { // [eksen, boyut, baş payı, son payı]
      var lo = b[ax[0]] * v.s, hi = b[ax[0] + 2] * v.s, size = ax[1], key = ax[0] ? 'y' : 'x', m0 = ax[2], m1 = ax[3];
      if (hi - lo <= size - m0 - m1 + 0.5) v[key] = m0 + (size - m0 - m1 - (hi - lo)) / 2 - lo;
      else v[key] = Math.min(m0 - lo, Math.max(size - m1 - hi, v[key]));
    });
    return v;
  }
  function clampView() { clampV(view); }
  function toBoard(px, py) { return [(px - view.x) / view.s, (py - view.y) / view.s]; }
  function pannable() { var b = trayBox(); return (b[2] - b[0]) * view.s > lay.W - 3.5 || (b[3] - b[1]) * view.s > lay.H - TOP_BAND - 7.5; }
  function overview() { return lay.sMin < 0.999 && view.s <= lay.sMin + 0.005; }
  function zoomAt(px, py, ns) {
    var bp = toBoard(px, py);
    viewAnim = null; fling = null;
    view.s = Math.max(lay.sMin, Math.min(lay.sMax, ns));
    view.x = px - bp[0] * view.s; view.y = py - bp[1] * view.s;
    clampView(); updateFitBtn(); draw(); positionTutorial();
  }
  /** Görünümü yumuşak geçişle (bx, by) tahta noktası ekran ortasına gelecek şekilde s yakınlığına götürür. */
  function animateView(ns, bx, by) {
    var to = { s: ns, x: 0, y: 0 };
    to.s = Math.max(lay.sMin, Math.min(lay.sMax, ns));
    to.x = lay.W / 2 - bx * to.s; to.y = lay.H / 2 - by * to.s; clampV(to);
    fling = null;
    if (reduced) { view = to; viewAnim = null; updateFitBtn(); draw(); positionTutorial(); return; }
    viewAnim = { from: { s: view.s, x: view.x, y: view.y }, to: to, t0: performance.now(), dur: 280 * animScale + 1 };
    kick();
  }
  // "Sığdır": tüm tahtayı göster; tahta zaten sığdırılmışsa varsayılan yakınlığa (hücre ≥ MIN_CELL) döner
  function fitView() {
    var c = toBoard(lay.W / 2, lay.H / 2);
    animateView(overview() ? 1 : (lay.sMin < 0.999 ? lay.sMin : 1), c[0], c[1]);
  }
  function updateFitBtn() {
    var b = $('btn-fit'); if (!LV) return;
    b.hidden = !(lay.sMin < 0.999 || view.s > 1.01);
    var key = overview() ? 'game.zoom_default' : 'game.fit';
    if (b.getAttribute('data-k') !== key + S.lang) {
      b.setAttribute('data-k', key + S.lang); b.setAttribute('aria-label', t(key)); b.title = t(key);
      b.firstElementChild.innerHTML = ICONS[overview() ? 'zoomin' : 'fit'];
    }
    $('scr-game').classList.toggle('has-fit', !b.hidden);
  }
  /** Ok görünür alanda değilse görünümü oka kaydırır (ipucu, öğretici). */
  function focusArrow(i) {
    var hd = E.headOf(LV.arrows[i]), c = lay.cell, bx = lay.ox + (hd[0] + 0.5) * c, by = lay.oy + (hd[1] + 0.5) * c;
    var sx = bx * view.s + view.x, sy = by * view.s + view.y, m = 2.5 * c * view.s;
    if (sx > m && sy > m + 30 && sx < lay.W - m && sy < lay.H - m) return;
    animateView(Math.max(view.s, Math.min(1, lay.sMax)), bx, by);
  }
  $('btn-fit').addEventListener('click', function () { SFX.button(); fitView(); });
  window.addEventListener('resize', function () { if (current === 'game') resize(); fitAll(); });

  // cubic-bezier easing (CSS ile aynı)
  function bezier(x1, y1, x2, y2) {
    function a(p1, p2) { return 1 - 3 * p2 + 3 * p1; }
    function b(p1, p2) { return 3 * p2 - 6 * p1; }
    function c(p1) { return 3 * p1; }
    function calc(t, p1, p2) { return ((a(p1, p2) * t + b(p1, p2)) * t + c(p1)) * t; }
    function slope(t, p1, p2) { return 3 * a(p1, p2) * t * t + 2 * b(p1, p2) * t + c(p1); }
    return function (x) {
      if (x <= 0) return 0; if (x >= 1) return 1;
      var tt = x;
      for (var i = 0; i < 8; i++) { var s = slope(tt, x1, x2); if (Math.abs(s) < 1e-6) break; tt -= (calc(tt, x1, x2) - x) / s; }
      return calc(Math.max(0, Math.min(1, tt)), y1, y2);
    };
  }
  var easeSlide = bezier(0.45, 0, 0.85, 0.35), easeBack = bezier(0.34, 1.56, 0.64, 1);
  function easeIn(x) { return x * x; }

  function loop() {
    rafId = 0;
    if (adPause) return; // reklam gösteriliyor: animasyon döngüsü duraklar, reklam kapanınca kick() sürdürür
    var now = performance.now(), active = false;
    Object.keys(anims).forEach(function (k) {
      var an = anims[k];
      if (now - an.t0 >= an.dur) { delete anims[k]; if (an.done) an.done(); }
      else active = true;
    });
    if (shake && now - shake.t0 >= shake.dur) shake = null;
    if (shake) active = true;
    if (hintIdx >= 0) { if (now > hintUntil || !G.alive[hintIdx]) hintIdx = -1; else active = true; }
    if (flash) { if (now - flash.t0 > 320) flash = null; else active = true; }
    if (viewAnim) { // yumuşak görünüm geçişi (sığdır / oka odaklan)
      var qv = Math.min(1, (now - viewAnim.t0) / viewAnim.dur), ev = 1 - (1 - qv) * (1 - qv) * (1 - qv), vf = viewAnim.from, vt = viewAnim.to;
      view.s = vf.s + (vt.s - vf.s) * ev; view.x = vf.x + (vt.x - vf.x) * ev; view.y = vf.y + (vt.y - vf.y) * ev;
      if (qv >= 1) viewAnim = null; else active = true;
      updateFitBtn(); positionTutorial();
    }
    if (fling) { // kaydırma ataleti
      var dtf = Math.min(40, now - fling.t), kf = Math.exp(-dtf / 300); fling.t = now;
      view.x += fling.vx * dtf; view.y += fling.vy * dtf; fling.vx *= kf; fling.vy *= kf;
      var fx0 = view.x, fy0 = view.y; clampView();
      if (view.x !== fx0) fling.vx = 0; if (view.y !== fy0) fling.vy = 0;
      if (Math.abs(fling.vx) + Math.abs(fling.vy) < 0.03) fling = null; else active = true;
    }
    draw(now);
    if (active) rafId = requestAnimationFrame(loop);
  }
  function kick() { if (!rafId && !adPause) rafId = requestAnimationFrame(loop); }

  // Tahta tepsisi: maske varsa (şekilli tahta) hücrelerin birleşimi, yuvarlak köşeli; yoksa dikdörtgen. Path2D önbelleği (hücre birimi).
  function inMask(x, y) { return x >= 0 && y >= 0 && x < LV.w && y < LV.h && (!LV.mask || LV.mask[y].charCodeAt(x) === 49); }
  function buildTray() {
    var w = LV.w, h = LV.h, p = new Path2D(), dots = new Path2D(), x, y, dr = T.shape.gridDot;
    if (!LV.mask) p.rect(0, 0, w, h);
    else for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
      if (!inMask(x, y)) continue;
      var x0 = x; while (x < w && inMask(x, y)) x++;
      p.rect(x0, y, x - x0, 1);
    }
    for (y = 0; y <= h; y++) for (x = 0; x <= w; x++) {
      if (inMask(x, y) || inMask(x - 1, y) || inMask(x, y - 1) || inMask(x - 1, y - 1)) { dots.moveTo(x + dr, y); dots.arc(x, y, dr, 0, Math.PI * 2); }
    }
    boxes = LV.arrows.map(function (a) {
      var b = [1e9, 1e9, -1e9, -1e9];
      E.cellsOf(a).forEach(function (q) { if (q[0] < b[0]) b[0] = q[0]; if (q[1] < b[1]) b[1] = q[1]; if (q[0] > b[2]) b[2] = q[0]; if (q[1] > b[3]) b[3] = q[1]; });
      return b;
    });
    tray = { lv: LV, p: p, dots: dots };
  }
  function drawTray(pal, c) {
    if (!tray || tray.lv !== LV) buildTray();
    var pad = T.boardPadFor(LV.w), dark = pal === T.colors.dark;
    ctx.save();
    ctx.translate(lay.ox, lay.oy); ctx.scale(c, c);
    ctx.lineJoin = 'round'; ctx.lineWidth = pad * 2;
    ctx.save(); ctx.translate(0, 0.1); ctx.fillStyle = pal.boardEdge; ctx.strokeStyle = pal.boardEdge; ctx.fill(tray.p); ctx.stroke(tray.p); ctx.restore();
    ctx.fillStyle = pal.board; ctx.strokeStyle = pal.board; ctx.fill(tray.p); ctx.stroke(tray.p);
    if (c * view.s >= 9) { ctx.fillStyle = pal.cellDot; ctx.globalAlpha = dark ? 0.55 : 0.75; ctx.fill(tray.dots); }
    ctx.restore();
  }
  function isMono() { return S.arrowColor === 'mono'; }
  function draw(now) {
    if (!LV || !ctx) return;
    now = now || performance.now();
    var c = lay.cell, dpr = lay.dpr, pal = T.palette();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, cv.width, cv.height);
    ctx.setTransform(dpr * view.s, 0, 0, dpr * view.s, dpr * view.x, dpr * view.y);
    ctx.direction = isRTL() ? 'rtl' : 'ltr';
    var sx = 0, sy = 0;
    if (shake) {
      var p = (now - shake.t0) / shake.dur, amp = T.anim.shakeAmp * c * Math.sin(p * Math.PI * 2 * T.anim.shakeCycles) * (1 - p);
      sx = shake.ax * amp; sy = shake.ay * amp;
    }
    ctx.translate(sx, sy);
    drawTray(pal, c);
    var th = T.arrowThemes[themeIndex()], mono = isMono();
    if (!colorMap || colorMap.lv !== LV || colorMap.k !== th.colors.length) colorMap = { lv: LV, k: th.colors.length, c: E.colorize(LV, th.colors.length) };
    var pulse = 0.5 + 0.5 * Math.sin(now / T.anim.hintPulse * Math.PI * 2);
    // görünür hücre penceresi (ekran dışındaki oklar çizilmez)
    var b0 = toBoard(0, 0), b1 = toBoard(lay.W, lay.H);
    var vx0 = (b0[0] - lay.ox) / c - 1.5, vy0 = (b0[1] - lay.oy) / c - 1.5, vx1 = (b1[0] - lay.ox) / c + 0.5, vy1 = (b1[1] - lay.oy) / c + 0.5;
    function one(i, an) {
      var a = LV.arrows[i], off = 0, alpha = 1;
      if (an) {
        var q = Math.min(1, (now - an.t0) / an.dur);
        if (an.kind === 'exit') off = an.dist * q; // sabit hız: ok kendi yolunu izleyerek tahta kenarına dek gider (kenarda kırpılır)
        else if (an.kind === 'bump') {
          var tf = an.fwd / an.dur;
          if (q < tf) off = an.dist * easeIn(q / tf);
          else off = an.dist * (1 - easeBack((q - tf) / (1 - tf)));
        } else if (an.kind === 'appear') alpha = q;
      }
      var hl = i === hintIdx, col = mono ? pal.ink : th.colors[colorMap.c[i]], cl = E.cellsOf(a);
      if (hl) {
        ctx.save(); ctx.globalAlpha = 0.5 + 0.5 * pulse;
        window.drawArrow(ctx, { ox: lay.ox, oy: lay.oy, cells: cl, off: off, cell: c, dir: a.dir, color: col, highlight: true, chevron: th.chevron, mono: mono });
        ctx.restore();
      }
      var sel = i === aimSel || (flash && flash.ids.indexOf(i) >= 0);
      window.drawArrow(ctx, { ox: lay.ox, oy: lay.oy, cells: cl, off: off, cell: c, dir: a.dir,
        color: col, alpha: alpha, chevron: th.chevron, highlight: sel, mono: mono });
    }
    var exits = null;
    for (var i = 0; i < LV.arrows.length; i++) {
      var an = anims[i];
      if (an && an.kind === 'exit') { (exits = exits || []).push(i); continue; }
      if (!G.alive[i]) continue;
      var bb = boxes[i];
      if (!an && (bb[2] < vx0 || bb[0] > vx1 || bb[3] < vy0 || bb[1] > vy1)) continue;
      one(i, an);
    }
    if (exits) { // çıkan oklar tahta kenarında kaybolur
      var tb = trayBox();
      ctx.save(); ctx.beginPath(); ctx.rect(tb[0], tb[1], tb[2] - tb[0], tb[3] - tb[1] + c * 0.12); ctx.clip();
      for (var e = 0; e < exits.length; e++) one(exits[e], anims[exits[e]]);
      ctx.restore();
    }
    if (aimSel >= 0 && G.alive[aimSel] && !anims[aimSel]) drawAimPath(aimSel, c);
    if (pannable() && !winDone) drawMinimap(th, mono, pal);
  }
  // G1: seçili okun yolu (engel ya da tahta kenarına kadar) noktalarla gösterilir
  function drawAimPath(i, c) {
    var a = LV.arrows[i], p = E.pathOf(a, LV.w, LV.h), g = G.grid(), pal = T.palette();
    ctx.save();
    for (var k = 0; k < p.length; k++) {
      var occ = g[p[k][1] * LV.w + p[k][0]] !== -1;
      var cx = lay.ox + (p[k][0] + 0.5) * c, cy = lay.oy + (p[k][1] + 0.5) * c;
      ctx.beginPath();
      if (occ) { ctx.lineWidth = c * 0.08; ctx.strokeStyle = pal.danger; ctx.arc(cx, cy, c * 0.36, 0, Math.PI * 2); ctx.stroke(); break; }
      ctx.fillStyle = pal.highlightRing; ctx.arc(cx, cy, c * 0.09, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();
  }
  // G2: yakınken küçük harita (ekran koordinatında, üst köşe; RTL'de karşı köşe)
  function drawMinimap(th, mono, pal) {
    var mw = 64, cs = mw / (LV.w + 0.6), mh = cs * (LV.h + 0.6), m = 8;
    var mx = isRTL() ? lay.W - mw - m : m, my = 6;
    ctx.setTransform(lay.dpr, 0, 0, lay.dpr, 0, 0);
    ctx.save();
    ctx.globalAlpha = 0.92; ctx.fillStyle = pal.board; ctx.strokeStyle = pal.boardEdge; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.rect(mx, my, mw, mh); ctx.fill(); ctx.stroke();
    var ox = mx + cs * 0.3, oy = my + cs * 0.3;
    LV.arrows.forEach(function (a, i) {
      if (!G.alive[i]) return;
      ctx.fillStyle = mono ? pal.inkSoft : th.colors[colorMap ? colorMap.c[i] : i % th.colors.length];
      E.cellsOf(a).forEach(function (q) { ctx.fillRect(ox + q[0] * cs + 0.3, oy + q[1] * cs + 0.3, cs - 0.6, cs - 0.6); });
    });
    // görünen alan
    var b0 = toBoard(0, 0), b1 = toBoard(lay.W, lay.H);
    var rx = ox + (b0[0] - lay.ox) / lay.cell * cs, ry = oy + (b0[1] - lay.oy) / lay.cell * cs;
    var rw = (b1[0] - b0[0]) / lay.cell * cs, rh = (b1[1] - b0[1]) / lay.cell * cs;
    ctx.globalAlpha = 1; ctx.strokeStyle = pal.accent; ctx.lineWidth = 2;
    ctx.save(); ctx.beginPath(); ctx.rect(mx, my, mw, mh); ctx.clip();
    ctx.strokeRect(rx, ry, rw, rh); ctx.restore();
    ctx.restore();
  }

  // ---- girdi
  // G1 dokunma koruması: isabet, okun gövde eksenine uzaklıkla belirlenir (gövdenin çevresi genişletilmiş alan).
  // En yakın iki ok neredeyse eşit uzaklıktaysa (iki okun arası) hiçbir ok oynamaz: kısa titreşim + vurgu.
  // 1.2.0 (docs/17 §9): isabet HÜCRE bazlıdır — okun kapladığı hücrenin herhangi bir yerine dokunmak yeter (ince çizgiye değil).
  // Boş hücreye dokunulduysa en yakın dolu hücre (HIT_NEAR hücre içinde) seçilir; iki farklı ok neredeyse eşit uzaklıktaysa belirsiz.
  var HIT_NEAR = 0.45, AMBIG = 0.12; // hücre birimi
  function hitTest(px, py) {
    var b = toBoard(px, py), u = (b[0] - lay.ox) / lay.cell, v = (b[1] - lay.oy) / lay.cell;
    var w = LV.w, h = LV.h, fx = Math.floor(u), fy = Math.floor(v), g = G.grid();
    if (fx >= 0 && fy >= 0 && fx < w && fy < h && g[fy * w + fx] >= 0) return { i: g[fy * w + fx] };
    var best = -1, bd = 1e9, second = -1, sd = 1e9;
    for (var ny = fy - 1; ny <= fy + 1; ny++) for (var nx = fx - 1; nx <= fx + 1; nx++) {
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      var k = g[ny * w + nx]; if (k < 0) continue;
      var dx = u < nx ? nx - u : u > nx + 1 ? u - nx - 1 : 0, dy = v < ny ? ny - v : v > ny + 1 ? v - ny - 1 : 0, d = Math.sqrt(dx * dx + dy * dy);
      if (k === best) { if (d < bd) bd = d; }
      else if (d < bd) { second = best; sd = bd; best = k; bd = d; }
      else if (k === second) { if (d < sd) sd = d; }
      else if (d < sd) { second = k; sd = d; }
    }
    if (best < 0 || bd > HIT_NEAR) return { i: -1 };
    if (second >= 0 && sd <= HIT_NEAR && sd - bd < AMBIG) return { i: -1, amb: [best, second] };
    return { i: best };
  }
  function onBoardTap(px, py) {
    if (!G || locked() || modalOpen()) return;
    var h = hitTest(px, py);
    if (h.amb) {
      buzz('error'); flash = { ids: h.amb, t0: performance.now() }; kick();
      if (!tipShown.amb) { tipShown.amb = 1; toast(t('game.ambiguous')); }
      return;
    }
    if (h.i < 0) { if (aimSel >= 0) { aimSel = -1; draw(); } return; }
    if (S.aim && aimSel !== h.i) { // G1: önce seç
      aimSel = h.i; SFX.tap(); buzz('tap'); draw();
      if (!tipShown.aim) { tipShown.aim = 1; toast(t('game.tap_again')); }
      return;
    }
    tapArrow(h.i);
  }
  // Dokunma hareketleri (G2): tek parmak dokunuş = oka dokun; sürükleme (yakınken) = kaydır; iki parmak = yakınlaştır.
  // Kaydırma eşiği PAN_SLOP px: bu kadar hareket eden parmak artık dokunuş değildir (kaydırma asla ok oynatmaz).
  var ptrs = {}, gest = null, PAN_SLOP = 10;
  function ptrList() { return Object.keys(ptrs).map(function (k) { return ptrs[k]; }); }
  function local(ev) { var r = cv.getBoundingClientRect(); return [ev.clientX - r.left, ev.clientY - r.top]; }
  cv.addEventListener('pointerdown', function (ev) {
    lastInput = performance.now();
    ev.preventDefault();
    try { cv.setPointerCapture(ev.pointerId); } catch (e) {}
    var p = local(ev); ptrs[ev.pointerId] = { x: p[0], y: p[1] };
    var list = ptrList();
    fling = null; viewAnim = null;
    if (list.length === 1) gest = { type: 'tap', x0: p[0], y0: p[1], vx: view.x, vy: view.y, moved: false, lx: p[0], ly: p[1], lt: lastInput, sx: 0, sy: 0 };
    else if (list.length === 2) {
      var a = list[0], b = list[1];
      gest = { type: 'pinch', d0: Math.hypot(a.x - b.x, a.y - b.y) || 1, s0: view.s, mx: (a.x + b.x) / 2, my: (a.y + b.y) / 2, vx: view.x, vy: view.y };
    } else gest = { type: 'none' };
  });
  cv.addEventListener('pointermove', function (ev) {
    if (!ptrs[ev.pointerId] || !gest) return;
    var p = local(ev); ptrs[ev.pointerId] = { x: p[0], y: p[1] };
    if (gest.type === 'pinch') {
      var list = ptrList(); if (list.length < 2) return;
      var a = list[0], b = list[1], d = Math.hypot(a.x - b.x, a.y - b.y), mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
      var bx = (gest.mx - gest.vx) / gest.s0, by = (gest.my - gest.vy) / gest.s0;
      view.s = Math.max(lay.sMin, Math.min(lay.sMax, gest.s0 * d / gest.d0));
      view.x = mx - bx * view.s; view.y = my - by * view.s;
      clampView(); updateFitBtn(); draw(); positionTutorial();
    } else if (gest.type === 'tap' || gest.type === 'pan') {
      var dx = p[0] - gest.x0, dy = p[1] - gest.y0;
      if (gest.type === 'tap' && Math.hypot(dx, dy) > PAN_SLOP) { gest.type = pannable() ? 'pan' : 'none'; }
      if (gest.type === 'pan') {
        var nowm = performance.now(), dtm = Math.max(1, nowm - gest.lt);
        gest.sx = 0.6 * gest.sx + 0.4 * (p[0] - gest.lx) / dtm; gest.sy = 0.6 * gest.sy + 0.4 * (p[1] - gest.ly) / dtm; // yumuşatılmış hız (px/ms)
        gest.lx = p[0]; gest.ly = p[1]; gest.lt = nowm;
        view.x = gest.vx + dx; view.y = gest.vy + dy; clampView(); draw(); positionTutorial();
      }
    }
  });
  function endPtr(ev, cancel) {
    if (!ptrs[ev.pointerId]) return;
    delete ptrs[ev.pointerId];
    if (!cancel && gest && gest.type === 'tap' && !ptrList().length) onBoardTap(gest.x0, gest.y0);
    if (!cancel && gest && gest.type === 'pan' && !ptrList().length && !reduced && performance.now() - gest.lt < 80 && Math.hypot(gest.sx, gest.sy) > 0.25) {
      fling = { vx: gest.sx, vy: gest.sy, t: performance.now() }; kick();
    }
    if (!ptrList().length) gest = null; else if (gest && gest.type === 'pinch') gest = { type: 'none' };
  }
  cv.addEventListener('pointerup', function (ev) { endPtr(ev, false); });
  cv.addEventListener('pointercancel', function (ev) { endPtr(ev, true); });
  cv.addEventListener('wheel', function (ev) { // masaüstü / emülatör: tekerlek = kaydırma, Ctrl/Alt + tekerlek = yakınlaştırma
    if (!LV) return; ev.preventDefault();
    var p = local(ev);
    if (ev.ctrlKey || ev.altKey || ev.metaKey || !pannable()) { zoomAt(p[0], p[1], view.s * (ev.deltaY < 0 ? 1.15 : 1 / 1.15)); return; }
    view.x -= ev.deltaX; view.y -= ev.deltaY; clampView(); draw(); positionTutorial();
  }, { passive: false });
  cv.addEventListener('contextmenu', function (e) { e.preventDefault(); });

  // Çıkış animasyonu: ok tahtanın dışına çıkana kadar yeni dokunuşlar yok sayılır (01 §2, test raporu H1).
  // Ok tahtayı terk ettikten sonra ekran kenarına uçarken oyuncu bir sonraki oka dokunabilir.
  var lockUntil = 0;
  var animScale = 1; // yalnızca test (?debug=1): __ok.fastAnim(true) animasyonları hızlandırır
  function locked() { return busy || performance.now() < lockUntil; }
  function boardLeaveCells(a) {
    var pad = T.boardPadFor(LV.w), hd = E.headOf(a), extra = E.cellsOf(a).length - 1;
    if (a.dir === 'R') return extra + LV.w - hd[0] + pad;
    if (a.dir === 'L') return extra + hd[0] + 1 + pad;
    if (a.dir === 'D') return extra + LV.h - hd[1] + pad;
    return extra + hd[1] + 1 + pad;
  }
  function tapArrow(i) {
    if (!G || locked() || modalOpen() || current !== 'game') return null;
    var r = G.tap(i);
    if (!r) return null;
    aimSel = -1;
    // v1.1 (docs/15 §1): ok hareketi başına YALNIZCA tek ses (çıkışta slideOut, çarpmada bump) — ayrıca "tık" (tap) çalmaz.
    // "tap" sesi/titreşimi yalnızca "önce seç" kipinde ok seçilirken çalar (hareket yok).
    // 1.1.5 (docs/22): ok hareketi başına TEK titreşim (çıkışta slideOut, çarpmada bump).
    hintIdx = -1;
    var a = LV.arrows[i], now = performance.now();
    if (lastTapAt) playMs += Math.min(8000, now - lastTapAt); lastTapAt = now; // hız rozeti: etkin oyun süresi (bekleme sayılmaz)
    if (r.type === 'exit') {
      // 1.2.0 (docs/17 §11): ok kendi yolunu izleyerek SABİT hızla tahta kenarına dek gider ve kenardan çıkıp kaybolur
      // (gövdenin tamamı, kuyruk dahil, yol boyunca akar; yarıda solma yok). Mesafe = kuyruğun tahtayı terk etmesi.
      var dist = boardLeaveCells(a) + 0.6;
      var dur = Math.min(T.anim.exitMax, Math.max(T.anim.exitMin, dist * T.anim.exitPerCell));
      if (reduced) dur = Math.min(dur, 180);
      dur *= animScale;
      anims[i] = { kind: 'exit', t0: now, dur: dur, dist: dist, done: function () {
        if (G.isWon() && !Object.keys(anims).some(function (k) { return anims[k].kind === 'exit'; })) onWin();
      } };
      // Ok yola çıktıktan kısa süre sonra (tapGap) sıradaki oka dokunulabilir; oyun durumu dokunuş anında güncellenmiştir.
      lockUntil = now + Math.min(dur, T.anim.tapGap * animScale);
      SFX.slideOut(Math.min(1, exitStreak / 6)); exitStreak++;
      buzz('slideOut');
      if (!isDaily() && G.remaining() <= 2) M.preloadInterstitial(LV.id); // geçiş reklamı seviye bitmeden hazır olsun (docs/15 §4)
      busy = G.isWon(); // son ok: kazanma ekranına kadar girdi kapalı
    } else {
      exitStreak = 0;
      if (r.lifeLost && G.lives <= 1) M.preloadRewarded(); // can 1'e düştü: "+1 can" reklamı önceden yüklensin (docs/15 §4)
      var fwd = (reduced ? 60 : T.anim.bumpForward) * animScale, back = (reduced ? 120 : T.anim.bumpBack) * animScale;
      busy = true;
      var my = session;
      anims[i] = { kind: 'bump', t0: now, dur: fwd + back, fwd: fwd, dist: r.free + 0.2, done: function () {
        busy = false;
        if (r.dead) onDead();
      } };
      setTimeout(function () {
        if (my !== session) return;
        SFX.bump(); buzz('bump');
        if (!reduced) { var d = E.DIRS[a.dir]; shake = { t0: performance.now(), dur: T.anim.shake, ax: d[0], ay: d[1] }; }
        if (r.lifeLost) { toast(t('game.crash'), CRASH_TOAST_MS); var h = $('hearts'); h.classList.remove('shake'); void h.offsetWidth; h.classList.add('shake'); }
        updateHUD(); kick();
      }, fwd);
    }
    updateHUD();
    onTutorialTap(r);
    kick();
    return r;
  }

  function onWin() {
    if (winDone) return;
    winDone = true; busy = true;
    var my = session;
    var stars = G.stars(), id = LV.id;
    if (isDaily()) {
      var dr = window.Daily.recordSolve(S.dp, LV.daily, stars); Store.save();
      hideTutorial(); tut = null; SFX.levelWin(); buzz('levelWin');
      setTimeout(function () { if (my === session) showDailyEnd(stars, dr); }, (reduced ? 50 : 250) * animScale);
      return;
    }
    var res = Store.completeLevel(id, stars, !!G.opts.relaxed);
    M.onLevelComplete(id); // reklam sayacı: yalnızca başarıyla tamamlanan seviyeler (13+) sayılır
    if (id <= 3 && S.tutorialDone.indexOf(id) < 0) { S.tutorialDone.push(id); Store.save(); }
    hideTutorial(); tut = null;
    SFX.levelWin(); buzz('levelWin');
    updateCoins();
    setTimeout(function () { if (my === session) showEnd(stars, res); }, (reduced ? 50 : 250) * animScale);
  }
  // 1.2.0 (docs/17): seviye sonu kutlaması — meşale/alev büyüklüğü performansa göre; mesaj = kademe × performans matrisi.
  // Performans: ad (reklamla devam) → küçük alev; l2 / l1 (can kaybı) → orta; flawless (kusursuz) → büyük + kıvılcım;
  // Aşırı zor + kusursuz → altın alev + havai fişek. Hız yalnızca bonus rozeti; yavaşlık hiçbir zaman söylenmez.
  var FAST_MS_PER_ARROW = 1500, FAST_MIN_ARROWS = 8; // AYAR: ok başına ortalama bu süreden hızlıysa "Şimşek gibi!" rozeti
  function perfOf(g) { return g.revived ? 'ad' : g.collisions >= 2 ? 'l2' : g.collisions === 1 ? 'l1' : 'flawless'; }
  function pickMsg(key) { var v = t(key).split('|'); return v[Math.floor(Math.random() * v.length)]; }
  function celebrationOf() {
    var tier = LV.diff || 'easy', perf = perfOf(G), n = LV.arrows.length;
    var size = perf === 'ad' ? 's' : perf === 'flawless' ? 'l' : 'm';
    return { tier: tier, perf: perf, size: size, sparks: perf === 'flawless', gold: perf === 'flawless' && tier === 'extreme',
      fast: perf !== 'ad' && n >= FAST_MIN_ARROWS && playMs > 0 && playMs / n <= FAST_MS_PER_ARROW, msg: pickMsg('cel.' + tier + '.' + perf) };
  }
  function flameHTML(c) {
    var h = '<div class="flame f-' + c.size + (c.gold ? ' gold' : '') + (c.sparks ? ' sparks' : '') + '" id="cel-flame" data-size="' + c.size + '" data-perf="' + c.perf + '" aria-hidden="true">' +
      '<svg viewBox="0 0 64 100"><g class="fl">' +
      '<path class="fl-out" d="M32 3C39 17 55 27 55 46c0 14-10 24-23 24S9 60 9 46c0-12 8-17 12-29 5 6 5 10 9 12 0-10-2-17 2-26z"/>' +
      '<path class="fl-in" d="M32 30c5 8 13 13 13 23 0 9-6 16-13 16s-13-7-13-16c0-6 4-9 6-15 3 4 5 5 7-8z"/>' +
      '<path class="fl-core" d="M32 49c3 4 7 6 7 12 0 5-3 8-7 8s-7-3-7-8c0-5 5-7 7-12z"/></g>' +
      '<rect class="torch-cup" x="24" y="68" width="16" height="7" rx="2.5"/><path class="torch-h" d="M27.5 75h9l-2 22h-5z"/></svg>';
    if (c.sparks) for (var k = 0; k < 7; k++) h += '<i class="spark" style="--dx:' + [-34, 26, -14, 38, -40, 12, 30][k] + 'px;--d:' + (k * 0.17).toFixed(2) + 's"></i>';
    if (c.gold) for (var b = 0; b < 3; b++) {
      h += '<span class="fw fw' + b + '">';
      for (var r = 0; r < 10; r++) h += '<i style="--a:' + (r * 36) + 'deg"></i>';
      h += '</span>';
    }
    return h + '</div>';
  }
  function showEnd(stars, res) {
    var id = LV.id, cel = celebrationOf();
    openModal(function (sh) {
      sh.id = 'end-sheet';
      sh.setAttribute('data-stars', stars);
      sh.setAttribute('data-perf', cel.perf); sh.setAttribute('data-tier', cel.tier);
      sh.insertAdjacentHTML('beforeend', flameHTML(cel));
      var h2 = el('h2', 'cel-msg'); h2.id = 'cel-msg'; h2.textContent = cel.msg; sh.appendChild(h2);
      sh.appendChild(el('p', 'end-sub')).textContent = t('end.title');
      var sb = el('div', 'stars-big');
      for (var i = 1; i <= 3; i++) sb.insertAdjacentHTML('beforeend', icon(i <= stars ? 'star' : 'starEmpty', i === 2 ? 'mid' : ''));
      sh.appendChild(sb);
      var line = el('p'); line.textContent = G.collisions === 0 ? t('end.perfect') : t('end.collisions', { n: G.collisions });
      sh.appendChild(line);
      if (G.opts.relaxed) sh.appendChild(el('p', 'relaxed-note')).textContent = t('end.relaxed_note');
      var rw = el('div'); rw.innerHTML = '<span class="reward">' + icon('coin') + '<span>' + esc(t('end.reward', { n: res.coins })) + '</span></span>';
      sh.appendChild(rw);
      var tags = el('div');
      if (cel.fast) { var ft = el('span', 'tag fast'); ft.id = 'cel-fast'; ft.textContent = pickMsg('cel.fast'); tags.appendChild(ft); }
      if (res.newBest) tags.appendChild(el('span', 'tag')).textContent = t('end.new_best');
      if (res.chapterDone) { tags.appendChild(el('span', 'tag')).textContent = t('end.chapter_done'); tags.appendChild(el('span', 'tag')).textContent = t('map.chapter_bonus', { n: res.bonus }); }
      sh.appendChild(tags);
      if (id === LG.DESIGNED) sh.appendChild(el('p')).textContent = t('end.all_done'); // 5.000 seviye bitti: sonsuz bölümler başlıyor
      var a = el('div', 'actions');
      // Oyuncu devam edince (ve yalnızca o zaman) geçiş reklamı kuralları değerlendirilir (ads.js)
      var going = false;
      var adToken = M.openLevelEnd(id); // 1.1.3: yerleştirme oturumu; geçiş reklamı yalnızca bu seviye sonu ekranı etkinken
      function cont(fn) { return function () { if (going) return; going = true; M.continueAfterLevel(id, function () { M.closeLevelEnd(adToken); fn(); }, adToken); }; }
      if (id < Store.MAX_LEVEL) a.appendChild(btn(t('end.next'), 'primary', cont(function () { startLevel(id + 1); }), 'end-next'));
      var row = el('div', 'actions row'); row.style.marginTop = '0';
      row.appendChild(btn(t('end.replay'), 'secondary', cont(function () { startLevel(id); }), 'end-replay'));
      row.appendChild(btn(t('end.map'), 'secondary', cont(function () { show('map'); }), 'end-map'));
      a.appendChild(row);
      sh.appendChild(a);
      // 1.1.4 (docs/21): show çağrıldıysa sonraki seviye reklam bitene dek bekler; 300 ms'den uzun sürerse nötr gösterge
      var waitP = el('p', 'ad-wait'); waitP.style.display = 'none'; sh.appendChild(waitP);
      M.setWaitListener(function (w) {
        if (w === 'none') { waitP.style.display = 'none'; return; }
        waitP.style.display = ''; waitP.textContent = t('ads.opening') + (w === 'slow' ? ' ' + t('ads.slow') : '');
      });
      // yıldız animasyonu: 380 ms, 180 ms aralık
      var my = session;
      var ics = sb.querySelectorAll('.ic');
      ics.forEach(function (n, k) {
        setTimeout(function () {
          if (my !== session) return;
          n.classList.add(k < stars ? 'on' : 'off');
          if (k < stars) SFX.star(k);
        }, reduced ? 50 + k * 80 : 200 + k * (T.anim.starPop * 0.5 + T.anim.starStagger));
      });
      if (res.coins > 0) setTimeout(function () { if (my === session) SFX.coin(); }, 200 + 3 * (T.anim.starPop * 0.5 + T.anim.starStagger));
    });
  }
  function showDailyEnd(stars, dr) {
    var info = window.Daily.streakInfo(S.dp, LV.daily);
    openModal(function (sh) {
      sh.id = 'dp-end';
      sh.setAttribute('data-stars', stars);
      sh.appendChild(el('h2')).textContent = t('dp.done');
      sh.insertAdjacentHTML('beforeend', '<div class="trophy-big">' + icon('trophy') + '</div>');
      if (dr && dr.first) sh.appendChild(el('p', 'tag')).textContent = t('dp.trophy_won');
      sh.appendChild(dpStats(info));
      sh.appendChild(el('p')).textContent = t('dp.come_back');
      var a = el('div', 'actions row');
      a.appendChild(btn(t('common.back'), 'secondary', function () { show('menu'); }, 'dp-end-menu'));
      a.appendChild(btn(t('dp.title'), 'primary', function () { show('menu'); openCalendar(); }, 'dp-end-cal'));
      sh.appendChild(a);
    });
  }
  function dpStats(info) {
    var box = el('div', 'dp-stats');
    [['dp.streak', info.current], ['dp.best', info.best], ['dp.trophies', info.trophies]].forEach(function (x) {
      box.appendChild(el('span', 'chip')).textContent = t(x[0], { n: x[1] });
    });
    return box;
  }
  function dayLabel(ymd) {
    var p = ymd.split('-').map(Number), months = t('cal.months').split(',');
    return p[2] + ' ' + (months[p[1] - 1] || p[1]);
  }
  var calMonth = null; // 'YYYY-MM'
  function openCalendar(month) {
    var today = Store.ymd(), info = window.Daily.streakInfo(S.dp, today);
    calMonth = month || today.slice(0, 7);
    openModal(function (sh) {
      sh.id = 'dp-sheet';
      sh.appendChild(el('h2')).textContent = t('dp.title');
      var y = +calMonth.slice(0, 4), m = +calMonth.slice(5, 7), months = t('cal.months').split(',');
      var nav = el('div', 'cal-nav');
      var prev = el('button', 'icon-btn'); prev.type = 'button'; prev.id = 'cal-prev'; prev.innerHTML = icon('back', 'flip-rtl'); prev.setAttribute('aria-label', t('common.back'));
      var title = el('div', 'cal-title'); title.textContent = months[m - 1] + ' ' + y;
      var next = el('button', 'icon-btn'); next.type = 'button'; next.id = 'cal-next'; next.innerHTML = icon('back', 'flip-rtl mirror'); next.setAttribute('aria-label', t('end.next'));
      var pm = m === 1 ? (y - 1) + '-12' : y + '-' + ('0' + (m - 1)).slice(-2), nm = m === 12 ? (y + 1) + '-01' : y + '-' + ('0' + (m + 1)).slice(-2);
      next.disabled = nm > today.slice(0, 7);
      prev.addEventListener('click', function () { SFX.button(); openCalendar(pm); });
      next.addEventListener('click', function () { if (!next.disabled) { SFX.button(); openCalendar(nm); } });
      nav.appendChild(prev); nav.appendChild(title); nav.appendChild(next);
      sh.appendChild(nav);
      var grid = el('div', 'cal');
      t('cal.weekdays').split(',').forEach(function (w) { grid.appendChild(el('div', 'cal-wd')).textContent = w; });
      var first = calMonth + '-01', lead = window.Daily.weekdayIndex(first);
      var days = new Date(Date.UTC(y, m, 0)).getUTCDate();
      for (var k = 0; k < lead; k++) grid.appendChild(el('div', 'cal-day empty'));
      for (var d = 1; d <= days; d++) {
        var ymd = calMonth + '-' + ('0' + d).slice(-2), done = S.dp.done && S.dp.done[ymd];
        var c = el('div', 'cal-day' + (done ? ' done' : '') + (ymd === today ? ' today' : '') + (ymd > today ? ' future' : ''));
        c.setAttribute('data-date', ymd);
        c.innerHTML = '<span class="num">' + d + '</span>' + (done ? icon('trophy') : '');
        grid.appendChild(c);
      }
      sh.appendChild(grid);
      sh.appendChild(dpStats(info));
      var a = el('div', 'actions');
      if (info.doneToday) sh.appendChild(el('p')).textContent = t('dp.done') + ' ' + t('dp.come_back');
      a.appendChild(btn((info.doneToday ? t('end.replay') : t('dp.play')), info.doneToday ? 'secondary' : 'primary', function () { closeModal(); startDaily(); }, 'dp-play'));
      a.appendChild(btn(t('common.close'), 'ghost', closeModal, 'dp-close'));
      sh.appendChild(a);
    }, function () { if (current === 'menu') renderers.menu(); });
  }
  function onDead() {
    busy = true;
    SFX.error(); buzz('error');
    openModal(function (sh) {
      sh.id = 'dead-sheet';
      sh.appendChild(el('h2')).textContent = t('game.out_of_lives_title');
      sh.appendChild(el('p')).textContent = t('game.out_of_lives_text');
      var a = el('div', 'actions');
      a.appendChild(btn(t('game.retry'), 'primary', function () { closeModal(); restartLevel(); }, 'dead-retry'));
      if (M.rewardedOffered() && G && revivedFor !== levelKey()) { // ödüllü +1 can: seviye başına en fazla 1 kez
        var my = session;
        a.appendChild(btn(t('ads.watch_life') + ' <small class="opt">· ' + esc(t('ads.optional')) + '</small>', 'secondary', function () {
          playRewarded('life', function () { if (my === session && G && G.revive()) revivedFor = levelKey(); }, function (rewarded) {
            if (my !== session) return;
            if (rewarded && G && !G.isDead()) { closeModal(); busy = false; updateHUD(); toast(t('ads.reward_life')); kick(); }
          });
        }, 'dead-revive'));
      }
      a.appendChild(btn(isDaily() ? t('common.back') : t('game.to_map'), 'secondary', function () { show(isDaily() ? 'menu' : 'map'); }));
      sh.appendChild(a);
    });
  }
  function restartLevel() {
    if (!G) return;
    G.reset(); anims = {}; shake = null; hintIdx = -1; busy = false; lockUntil = 0; exitStreak = 0; session++; winDone = false; aimSel = -1; playMs = 0; lastTapAt = 0;
    updateHUD(); refreshTutorial(); draw();
  }

  // ---- araç çubuğu
  $('btn-hint').addEventListener('click', function () { useHint(); });
  $('btn-restart').addEventListener('click', function () { SFX.button(); if (locked()) return; restartLevel(); });
  $('btn-pause').addEventListener('click', function () {
    SFX.button(); if (busy || !G) return;
    openModal(function (sh) {
      sh.id = 'pause-sheet';
      sh.appendChild(el('h2')).textContent = t('game.paused');
      var a = el('div', 'actions');
      a.appendChild(btn(t('game.resume'), 'primary', closeModal, 'pause-resume'));
      a.appendChild(btn(t('game.restart'), 'secondary', function () { closeModal(); restartLevel(); }));
      a.appendChild(btn(isDaily() ? t('common.back') : t('game.to_map'), 'secondary', function () { show(isDaily() ? 'menu' : 'map'); }, 'pause-map'));
      sh.appendChild(a);
    });
  });

  // İpucu için jeton yetmiyor: reklam izle (+50 jeton) / Mağaza / Kapat
  function openLowCoins() {
    openModal(function (sh) {
      sh.id = 'lowcoins-sheet';
      sh.appendChild(el('h2')).textContent = t('game.low_coins_title');
      sh.appendChild(el('p')).textContent = t('game.low_coins_text', { n: Store.PRICES.hint });
      var a = el('div', 'actions');
      if (Store.coinAdsLeft() > 0) {
        if (M.rewardedOffered()) {
          a.appendChild(btn(t('ads.watch_coins', { n: Store.AD_COINS }) + ' <small class="opt">· ' + esc(t('ads.coins_left', { n: Store.coinAdsLeft(), max: Store.MAX_COIN_ADS })) + '</small>', 'primary', function () {
            watchForCoins(function (rewarded) { if (rewarded) closeModal(); });
          }, 'lowcoins-watch'));
        }
      } else {
        a.appendChild(el('p', 'hint-note')).textContent = t('ads.coins_limit');
      }
      a.appendChild(btn(t('menu.shop'), 'secondary', function () { closeModal(); show('shop'); }, 'lowcoins-shop'));
      a.appendChild(btn(t('common.close'), 'ghost', closeModal, 'lowcoins-close'));
      sh.appendChild(a);
    });
  }
  function useHint() {
    if (!G || busy || G.isWon()) return;
    var i = G.hint();
    if (i < 0) return;
    var free = S.freeHints > 0;
    if (!free && S.coins < Store.PRICES.hint) { SFX.error(); buzz('error'); openLowCoins(); return; }
    if (!Store.spendBooster('hint')) { SFX.error(); buzz('error'); toast(t('game.not_enough_coins')); return; }
    SFX.hint(); buzz('button');
    hintIdx = i; hintUntil = performance.now() + 2600;
    focusArrow(i); // büyük tahtada ipucu oku ekranda değilse oraya kaydır
    updateHUD(); kick();
    if (tut && tut.id === 3) { $('btn-hint').classList.remove('pulse'); tut.step = 1; refreshTutorial(); }
    return { index: i, free: free };
  }


  // ---- öğretici (seviye 1-3; balon + el, yalnızca ilk kez)
  function hideTutorial() { $('bubble').hidden = true; $('bubble').classList.remove('pass'); $('hand').hidden = true; $('btn-hint').classList.remove('pulse'); }
  function tutorialTarget() {
    if (!tut || !G) return -1;
    if (tut.id === 1) return G.hint();
    if (tut.id === 2) {
      if (tut.step === 0) { for (var i = 0; i < LV.arrows.length; i++) if (G.alive[i] && !G.canExit(i)) return i; }
      return G.hint();
    }
    return -1;
  }
  function refreshTutorial() {
    if (!tut || !G) { hideTutorial(); return; }
    var key = null;
    if (tut.id === 1) key = 'tut.tap';
    else if (tut.id === 2) key = tut.step === 0 ? 'tut.crash' : 'tut.order';
    else if (tut.id === 3) key = tut.step === 0 ? 'tut.hint' : 'tut.order';
    $('bubble-text').textContent = t(key);
    $('bubble').hidden = false;
    $('btn-hint').classList.toggle('pulse', tut.id === 3 && tut.step === 0);
    positionTutorial();
  }
  function positionTutorial() {
    var hand = $('hand'), i = tutorialTarget();
    if (!tut || i < 0) { hand.hidden = true; return; }
    var a = LV.arrows[i], cl = E.cellsOf(a), c = lay.cell, t0 = cl[0], hd = cl[cl.length - 1];
    var mx = (t0[0] + hd[0]) / 2, my = (t0[1] + hd[1]) / 2;
    if (cl.length > 2 && !(t0[0] === hd[0] || t0[1] === hd[1])) { var mid = cl[cl.length >> 1]; mx = mid[0]; my = mid[1]; }
    hand.style.left = ((lay.ox + (mx + 0.5) * c) * view.s + view.x) + 'px';
    hand.style.top = ((lay.oy + (my + 0.5) * c) * view.s + view.y) + 'px';
    hand.hidden = false;
  }
  function onTutorialTap(r) {
    if (curveTip && r) closeCurveTip(); // ilk hamlede baloncuk kapanır (görüldü sayılır)
    if (!tut) return;
    if (tut.id === 2 && tut.step === 0 && r.type === 'bump') {
      tut.step = 1;
      setTimeout(function () { refreshTutorial(); if (tut) { hintIdx = G.hint(); hintUntil = performance.now() + 2000; kick(); } }, 350);
      return;
    }
    if (tut.id === 3 && r.type === 'exit') { tut.step = 1; }
    setTimeout(refreshTutorial, 30);
  }
  var curveTip = false;
  function closeCurveTip() { if (curveTip) { curveTip = false; markTip('curve_tip'); hideTutorial(); } }
  $('bubble-skip').addEventListener('click', function () {
    SFX.button();
    if (curveTip) { closeCurveTip(); return; }
    if (tut) {
      if (S.tutorialDone.indexOf(tut.id) < 0) { S.tutorialDone.push(tut.id); Store.save(); }
      if (G) G.opts.noLifeLoss = false;
    }
    tut = null; hideTutorial();
  });

  // ---------------------------------------------------------------- genel olaylar
  // Ses: ilk dokunuşta başlat
  function firstTouch() {
    try { SFX.init(); } catch (e) {}
    document.removeEventListener('pointerdown', firstTouch, true);
  }
  document.addEventListener('pointerdown', firstTouch, true);
  // çift dokunma / pinç zoom engelle
  document.addEventListener('gesturestart', function (e) { e.preventDefault(); });
  document.addEventListener('dblclick', function (e) { e.preventDefault(); }, { passive: false });
  // Çift dokunuş zoom'u CSS touch-action: manipulation (+ canvas'ta none) ile engellenir; touchend iptali hızlı dokunuşları yutardığı için kullanılmaz.
  $('modal').addEventListener('click', function (e) { if (e.target === $('modal') && !$('end-sheet') && !$('dead-sheet')) closeModal(); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && modalOpen() && !$('end-sheet') && !$('dead-sheet')) closeModal(); });
  document.addEventListener('visibilitychange', function () {
    // 1.1.4: bekleyen tam ekran reklam varsa "uygulamadan dönüş" bilgisi (ads.js beklemeyi bitirebilir)
    try { if (document.hidden) M.appHidden(true); else M.appResumed(); } catch (e) {}
    if (document.hidden && current === 'game' && G && !busy && !modalOpen()) $('btn-pause').click();
  });
  window.addEventListener('blur', function () { try { M.appHidden(false); } catch (e) {} });
  window.addEventListener('focus', function () { try { M.appResumed(); } catch (e) {} });

  // ---------------------------------------------------------------- Android kabuğu kancaları
  // Geri tuşu (MainActivity → onBack): 'exit' = uygulamadan çık (yalnızca ana menüde), 'handled' = oyun ele aldı.
  // refresh(): yerel durum değişti (bekleyen satın alma tamamlandı, onay/gizlilik seçenekleri güncellendi).
  window.ArrowtileApp = {
    onBack: function () {
      if (modalOpen()) {
        if ($('end-sheet') || $('dead-sheet')) return 'handled'; // seviye sonu / can bitti: düğmeyle seçilir
        if (pendingStart) pendingStart = 0;
        SFX.button(); closeModal(); return 'handled';
      }
      if (current === 'game') { if (G && !busy) $('btn-pause').click(); return 'handled'; }
      if (current === 'menu') return 'exit';
      var b = document.querySelector('#scr-' + current + ' [data-nav]');
      if (b) b.click(); else show('menu');
      return 'handled';
    },
    refresh: function () {
      if (current === 'settings' || current === 'shop' || current === 'menu') { if (renderers[current]) renderers[current](); fitAll($('scr-' + current)); }
    }
  };

  // ---------------------------------------------------------------- başlat
  SFX.setEnabled(S.sound);
  SFX.setVibration(S.vibration);
  fillIcons();
  applyAppearance();
  applyI18n();
  show('menu');
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { fitAll(); });

  // Hata ayıklama/test kancası: YALNIZCA ?debug=1 ile açılır (test raporu H2). Bu kipte kayıt ayrı bir kum havuzu
  // anahtarına yazılır (storage.js), oyuncunun gerçek kaydına hiçbir zaman dokunulmaz. state() salt okunur kopyadır.
  if (!Store.DEBUG) return;
  function deepFreeze(o) { Object.keys(o).forEach(function (k) { if (o[k] && typeof o[k] === 'object') deepFreeze(o[k]); }); return Object.freeze(o); }
  window.__ok = {
    version: VERSION,
    state: function () { return deepFreeze(JSON.parse(JSON.stringify(S))); },
    debugPatch: function (patch) { // yalnızca test kurulumu: kum havuzu kaydına yazar
      Object.keys(patch || {}).forEach(function (k) { S[k] = patch[k]; });
      S = Store.adopt(S); updateCoins(); if (renderers[current] && current !== 'game') renderers[current]();
      return true;
    },
    screen: function () { return current; },
    game: function () { // salt okunur anlık görüntü
      if (!G) return null;
      return deepFreeze({ id: LV.id, daily: LV.daily || null, alive: G.alive.slice(), lives: G.lives, collisions: G.collisions, remaining: G.remaining(),
        won: G.isWon(), stars: G.stars(), free: G.freeArrows(), relaxed: !!G.opts.relaxed });
    },
    level: function () { return LV ? deepFreeze(JSON.parse(JSON.stringify(LV))) : null; },
    startLevel: startLevel, setLang: setLang, show: show,
    tapArrow: function (i) { var r = tapArrow(i); return r ? JSON.parse(JSON.stringify(r)) : null; },
    busy: function () { return locked(); },
    view: function () { return { s: view.s, x: view.x, y: view.y, cell: lay.cell, sMin: lay.sMin, sMax: lay.sMax, W: lay.W, H: lay.H, ox: lay.ox, oy: lay.oy, pannable: pannable(), overview: overview(), tray: trayBox() }; },
    boardPoint: function (u, v) { var r = cv.getBoundingClientRect(); return { x: r.left + (lay.ox + u * lay.cell) * view.s + view.x, y: r.top + (lay.oy + v * lay.cell) * view.s + view.y }; },
    hitTest: function (x, y) { var r = cv.getBoundingClientRect(); return hitTest(x - r.left, y - r.top); },
    celebration: function () { var f = $('cel-flame'); return f ? { size: f.getAttribute('data-size'), perf: f.getAttribute('data-perf'), gold: f.classList.contains('gold'), sparks: f.classList.contains('sparks'), msg: $('cel-msg').textContent, fast: !!$('cel-fast') } : null; },
    setPlayMs: function (v) { playMs = v; },
    fastAnim: function (on) { animScale = on ? 0.02 : 1; },
    mapInfo: function () { var sc = $('map-scroll'); return mapSt ? { chapters: mapSt.chapters, rendered: Object.keys(mapSt.rendered).map(Number).sort(function (a, b) { return a - b; }), scrollTop: sc.scrollTop, chH: MAP.CH_H, nodes: sc.querySelectorAll('.node').length } : null; },
    mapScrollToChapter: function (c) { var sc = $('map-scroll'); sc.scrollTop = Math.max(0, (mapSt.chapters - c) * MAP.CH_H); updateMapWindow(); },
    ads: function () { return { paused: adPause, bannerShown: ['menu', 'map'].filter(function (n) { var b = document.querySelector('#scr-' + n + ' .banner'); return b && !b.hidden; }) }; },
    endless: function () { return { cached: Object.keys(endless).map(Number), queue: genQueue.slice(), job: genJob ? genJob.id : 0, stats: genStats.slice() }; },
    zoomAt: function (x, y, s) { zoomAt(x, y, s); },
    focus: function (i) { var hd = E.headOf(LV.arrows[i]), c = lay.cell; viewAnim = null; fling = null; view.x = lay.W / 2 - (lay.ox + (hd[0] + 0.5) * c) * view.s; view.y = lay.H / 2 - (lay.oy + (hd[1] + 0.5) * c) * view.s; clampView(); draw(); },
    fit: fitView,
    startDaily: startDaily, openCalendar: openCalendar,
    dailyLevel: function (ymd) { var d = dailyLevel(ymd || Store.ymd()); return d ? JSON.parse(JSON.stringify(d)) : null; },
    cellCenter: function (i) {
      var t0 = E.cellsOf(LV.arrows[i])[0], r = cv.getBoundingClientRect(), c = lay.cell; // kuyruk hücresinin merkezi (ekran dışında olabilir: önce __ok.focus(i))
      return { x: r.left + (lay.ox + (t0[0] + 0.5) * c) * view.s + view.x, y: r.top + (lay.oy + (t0[1] + 0.5) * c) * view.s + view.y };
    }
  };
})();
