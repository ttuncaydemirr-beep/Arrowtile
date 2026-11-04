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
  function toast(msg) {
    var n = $('toast'); n.textContent = msg; n.classList.add('show');
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { n.classList.remove('show'); }, 1600);
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
  function show(name) {
    if (modalOpen()) closeModal();
    if (current === 'game' && name !== 'game') stopGame();
    current = name;
    $('toast').classList.remove('show');
    document.querySelectorAll('.screen').forEach(function (s) { s.classList.toggle('active', s.id === 'scr-' + name); });
    if (renderers[name]) renderers[name]();
    updateCoins();
    requestAnimationFrame(function () { fitAll($('scr-' + name)); });
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
  renderers.map = function () {
    // v1.3 (docs/09): hazır 18 bölüm her zaman; sonsuz bölümler oyuncunun bölümü + bir sonraki (kilitli)
    var chapters = Math.max(Math.ceil(PREBUILT / 12), Math.ceil(S.unlocked / 12) + 1);
    var total = Store.totalStars(), max = chapters * 12 * 3;
    $('map-stars').textContent = total + '/' + max;
    $('map-stars').parentNode.setAttribute('aria-label', t('map.stars_total', { n: total, max: max }));
    var sc = $('map-scroll'); sc.innerHTML = '';
    var STEP = 96, PADB = 48, PADT = 40; // yıldızlar için düğümler arası boşluk
    var curNode = null;
    // Aşağıdan yukarıya: en üstte son bölüm
    for (var c = chapters; c >= 1; c--) {
      var tier = Store.tierOfChapter(c);
      var ch = el('section', 'chapter tier-' + tier); ch.setAttribute('data-chapter', c); ch.setAttribute('data-tier', tier);
      var first = (c - 1) * 12 + 1, last = c * 12, cs = 0;
      for (var k = first; k <= last; k++) cs += S.stars[k] || 0;
      var head = el('div', 'chapter-head');
      head.innerHTML = '<h3></h3><span class="diff-tag tier-badge d-' + tier + '"></span><div class="sub"><div class="pill-in">' + icon('star', 'star-ic') + ' <span class="num">' + cs + '/' + ((last - first + 1) * 3) + '</span></div><div></div></div>';
      head.querySelector('h3').textContent = c <= 18 ? t('map.chapter' + c) : t('map.chapter_n', { n: c });
      head.querySelector('.tier-badge').textContent = t('diff.' + tier);
      head.querySelector('.sub > div:last-child').textContent = S.chapterBonus.indexOf(c) >= 0 ? t('end.chapter_done') : t('map.chapter_bonus', { n: Store.chapterBonusFor(c) });
      var count = last - first + 1, H = PADB + PADT + (count - 1) * STEP;
      var path = el('div', 'path'); path.style.height = H + 'px';
      var pts = [];
      for (var i = 0; i < count; i++) {
        var x = 50 + 30 * Math.sin(i * Math.PI / 3);
        if (isRTL()) x = 100 - x; // harita yönü aynalanır
        pts.push([x, H - PADB - i * STEP]);
      }
      var d = pts.map(function (p, j) { return (j ? 'L' : 'M') + p[0].toFixed(2) + ' ' + p[1]; }).join(' ');
      path.innerHTML = '<svg class="trail" viewBox="0 0 100 ' + H + '" preserveAspectRatio="none" aria-hidden="true">' +
        '<path d="' + d + '" fill="none" stroke="var(--edge)" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/>' +
        '<path d="' + d + '" fill="none" stroke="var(--board)" stroke-width="4" stroke-dasharray="2 12" stroke-linecap="round" vector-effect="non-scaling-stroke"/></svg>';
      for (i = 0; i < count; i++) {
        var id = first + i, stars = S.stars[id] || 0, locked = id > S.unlocked;
        var nb = el('button', 'node' + (locked ? ' locked' : stars ? ' done' : '') + (id === S.unlocked ? ' current' : ''));
        nb.type = 'button';
        nb.style.left = pts[i][0] + '%'; nb.style.top = pts[i][1] + 'px';
        nb.setAttribute('data-level', id);
        // v1.3: etiket bölüm başlığında (kademe); düğümlerde yalnızca numara ve yıldız
        nb.setAttribute('data-diff', tier);
        nb.setAttribute('aria-label', t('map.level', { n: id }) + ' · ' + t('diff.' + tier) + (locked ? ' — ' + t('map.locked') : ''));
        nb.innerHTML = (locked ? icon('lock') : '<span>' + id + '</span>') +
          (!locked && stars ? '<span class="node-stars">' + [1, 2, 3].map(function (s) { return icon(s <= stars ? 'star' : 'starEmpty'); }).join('') + '</span>' : '');
        (function (id, locked) {
          nb.addEventListener('click', function () {
            if (locked) { SFX.error(); toast(t('map.locked_hint')); return; }
            SFX.button(); startLevel(id);
          });
        })(id, locked);
        if (id === S.unlocked) curNode = nb;
        path.appendChild(nb);
      }
      ch.appendChild(head); ch.appendChild(path);
      sc.appendChild(ch);
    }
    // sıradaki seviyeye kaydır
    requestAnimationFrame(function () {
      if (curNode) {
        var r = curNode.getBoundingClientRect(), sr = sc.getBoundingClientRect();
        sc.scrollTop += r.top - sr.top - sr.height / 2;
      } else sc.scrollTop = sc.scrollHeight;
    });
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
        if (r[0] === 'hint' && M.rewardedAvailable()) {
          it.appendChild(btn(t('ads.watch_hint'), 'secondary', function () { watchForHint(); }, 'shop-watch-hint'));
        }
        list.appendChild(it);
      });
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
  function refreshAfterPurchase() { if (renderers[current]) renderers[current](); fitAll($('scr-' + current)); }
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
  function watchForHint() {
    M.showRewarded('hint', function () { S.freeHints++; Store.save(); }, function (rewarded) {
      if (rewarded) { SFX.coin(); toast(t('ads.reward_hint')); } else toast(t('ads.no_reward'));
      if (current === 'game') updateHUD(); else if (renderers[current]) { renderers[current](); fitAll($('scr-' + current)); }
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
    view = { s: 1, x: 0, y: 0 }; aimSel = -1; flash = null;
    tut = tutorial ? { id: id, step: 0 } : null;
    if (!lv.daily) prefetchNext(id);
    show('game');
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
    // v1.2 (docs/08 §4): sığdırılmış hücre 30 px'ten küçükse ilk büyük seviyede bir kez
    // "iki parmakla yakınlaştır / önce seç, sonra fırlat" önerisi
    if (lay.cell < 26 && !S.aim && !hasTip('aim_suggest')) { // v1.3: eşik 26 px
      markTip('aim_suggest');
      confirmBox(t('game.aim_suggest'), function () { S.aim = true; Store.save(); }, t('common.yes'));
      return;
    }
    // G2: büyük tahtada bir kez yakınlaştırma ipucu
    if (lay.cell < 36 && !hasTip('zoom_tip') && !tut) { markTip('zoom_tip'); toast(t('game.zoom_tip')); }
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

  function resize() {
    if (!LV) return;
    var wrap = $('board-wrap'), W = wrap.clientWidth, H = wrap.clientHeight;
    if (!W || !H) return;
    var dpr = Math.min(3, window.devicePixelRatio || 1);
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    var padF = T.boardPadFor(LV.w) * 2;
    // Tahta tepsisi ekran kenarına 2 px yaklaşabilir: 360 px'te 22 sütunda hücre ≥ 16 px (docs/09)
    var cell = Math.min((W - 4) / (LV.w + padF), (H - 16) / (LV.h + padF + 0.1), 72);
    cell = Math.floor(cell);
    lay = { cell: cell, dpr: dpr, W: W, H: H,
      ox: Math.round((W - LV.w * cell) / 2), oy: Math.round((H - LV.h * cell) / 2) };
    clampView();
    draw();
    positionTutorial();
  }

  // ---- G2: yakınlaştırma / kaydırma. Tahta her zaman ekrana sığarak başlar (s=1); oyun kendiliğinden kaydırmaz.
  var ZMAX = 5; // v1.3 (docs/09): yakınlaştırma üst sınırı 5×
  function trayBox() { var p = T.boardPadFor(LV.w) * lay.cell; return [lay.ox - p, lay.oy - p, lay.ox + LV.w * lay.cell + p, lay.oy + LV.h * lay.cell + p]; }
  function clampView() {
    if (!LV) return;
    view.s = Math.max(1, Math.min(ZMAX, view.s));
    if (view.s <= 1.001) { view.s = 1; view.x = 0; view.y = 0; return; }
    var b = trayBox(), m = 12;
    [[0, lay.W], [1, lay.H]].forEach(function (ax) {
      var lo = b[ax[0]] * view.s, hi = b[ax[0] + 2] * view.s, size = ax[1], key = ax[0] ? 'y' : 'x';
      if (hi - lo + 2 * m <= size) view[key] = (size - (lo + hi)) / 2;
      else view[key] = Math.min(m - lo, Math.max(size - m - hi, view[key]));
    });
  }
  function toBoard(px, py) { return [(px - view.x) / view.s, (py - view.y) / view.s]; }
  function zoomAt(px, py, ns) {
    var bp = toBoard(px, py);
    view.s = Math.max(1, Math.min(ZMAX, ns));
    view.x = px - bp[0] * view.s; view.y = py - bp[1] * view.s;
    clampView(); updateFitBtn(); draw(); positionTutorial();
  }
  function fitView() { view = { s: 1, x: 0, y: 0 }; updateFitBtn(); draw(); positionTutorial(); }
  function updateFitBtn() { $('btn-fit').hidden = !(view.s > 1.01); }
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

  function offscreenCells(a) {
    // v1.3: gövde başı izler; kuyruk önce (uzunluk−1) adımda başın yerine gelir, sonra baş doğrusundan çıkar
    var hd = E.headOf(a), extra = E.cellsOf(a).length - 1;
    var c = lay.cell, d = E.DIRS[a.dir], tx = lay.ox + hd[0] * c, ty = lay.oy + hd[1] * c;
    return extra + offscreenFrom(tx, ty, c, d);
  }
  function offscreenFrom(tx, ty, c, d) {
    // hücre tamamen ekran dışına çıkana kadar (yakınlaştırma hesaba katılır)
    var L = -view.x / view.s, R = (lay.W - view.x) / view.s, Tp = -view.y / view.s, B = (lay.H - view.y) / view.s;
    if (d[0] > 0) return (R - tx) / c + 0.2;
    if (d[0] < 0) return (tx + c - L) / c + 0.2;
    if (d[1] > 0) return (B - ty) / c + 0.3;
    return (ty + c - Tp) / c + 0.3;
  }

  function loop() {
    rafId = 0;
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
    draw(now);
    if (active) rafId = requestAnimationFrame(loop);
  }
  function kick() { if (!rafId) rafId = requestAnimationFrame(loop); }

  function draw(now) {
    if (!LV || !ctx) return;
    now = now || performance.now();
    var c = lay.cell, dpr = lay.dpr;
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
    window.drawBoard(ctx, lay.ox, lay.oy, LV.w, LV.h, c);
    var th = T.arrowThemes[themeIndex()];
    if (!colorMap || colorMap.lv !== LV || colorMap.k !== th.colors.length) colorMap = { lv: LV, k: th.colors.length, c: E.colorize(LV, th.colors.length) };
    var pulse = 0.5 + 0.5 * Math.sin(now / T.anim.hintPulse * Math.PI * 2);
    LV.arrows.forEach(function (a, i) {
      var an = anims[i];
      if (!G.alive[i] && !(an && an.kind === 'exit')) return;
      var off = 0, alpha = 1;
      if (an) {
        var q = Math.min(1, (now - an.t0) / an.dur);
        if (an.kind === 'exit') {
          off = an.dist * easeSlide(q);
          var left = an.dur - (now - an.t0);
          if (left < T.anim.exitFade) alpha = Math.max(0, left / T.anim.exitFade);
        } else if (an.kind === 'bump') {
          var tf = an.fwd / an.dur;
          if (q < tf) off = an.dist * easeIn(q / tf);
          else off = an.dist * (1 - easeBack((q - tf) / (1 - tf)));
        } else if (an.kind === 'appear') alpha = q;
      }
      var hl = i === hintIdx, col = th.colors[colorMap.c[i]], cl = E.cellsOf(a);
      if (hl) {
        ctx.save(); ctx.globalAlpha = 0.5 + 0.5 * pulse;
        window.drawArrow(ctx, { ox: lay.ox, oy: lay.oy, cells: cl, off: off, cell: c, dir: a.dir, color: col, highlight: true, chevron: th.chevron });
        ctx.restore();
      }
      var sel = i === aimSel || (flash && flash.ids.indexOf(i) >= 0);
      window.drawArrow(ctx, { ox: lay.ox, oy: lay.oy, cells: cl, off: off, cell: c, dir: a.dir,
        color: col, alpha: alpha, chevron: th.chevron, highlight: sel });
    });
    if (aimSel >= 0 && G.alive[aimSel] && !anims[aimSel]) drawAimPath(aimSel, c);
    if (view.s > 1.01) drawMinimap(th);
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
  function drawMinimap(th) {
    var mw = 76, cs = mw / (LV.w + 0.6), mh = cs * (LV.h + 0.6), m = 8, pal = T.palette();
    var mx = isRTL() ? lay.W - mw - m : m, my = m;
    ctx.setTransform(lay.dpr, 0, 0, lay.dpr, 0, 0);
    ctx.save();
    ctx.globalAlpha = 0.92; ctx.fillStyle = pal.board; ctx.strokeStyle = pal.boardEdge; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.rect(mx, my, mw, mh); ctx.fill(); ctx.stroke();
    var ox = mx + cs * 0.3, oy = my + cs * 0.3;
    LV.arrows.forEach(function (a, i) {
      if (!G.alive[i]) return;
      ctx.fillStyle = th.colors[colorMap ? colorMap.c[i] : i % th.colors.length];
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
  var HIT_MAX = 0.5, AMBIG = 0.18; // hücre birimi — v1.2: isabet eşiği 0,5 hücre (küçük hücreler, yoğun tahta)
  // v1.3: okun çizgisine (hücre merkezlerinden geçen polyline) en yakın mesafe
  function segDist(u, v, a) {
    var cl = E.cellsOf(a), best = 1e9;
    for (var k = 0; k < cl.length; k++) {
      var x1 = cl[k][0] + 0.5, y1 = cl[k][1] + 0.5, b = cl[k + 1] || cl[k], x2 = b[0] + 0.5, y2 = b[1] + 0.5;
      var dx = x2 - x1, dy = y2 - y1, L2 = dx * dx + dy * dy, q = L2 ? Math.max(0, Math.min(1, ((u - x1) * dx + (v - y1) * dy) / L2)) : 0;
      var px = x1 + q * dx - u, py = y1 + q * dy - v, dd = Math.sqrt(px * px + py * py);
      if (dd < best) best = dd;
      if (cl.length > 1 && k === cl.length - 2) break;
    }
    return best;
  }
  function hitTest(px, py) {
    var b = toBoard(px, py), u = (b[0] - lay.ox) / lay.cell, v = (b[1] - lay.oy) / lay.cell;
    var best = -1, bd = 1e9, second = -1, sd = 1e9;
    LV.arrows.forEach(function (a, i) {
      if (!G.alive[i]) return;
      var d = segDist(u, v, a);
      if (d < bd) { second = best; sd = bd; best = i; bd = d; } else if (d < sd) { second = i; sd = d; }
    });
    if (best < 0 || bd > HIT_MAX) return { i: -1 };
    if (second >= 0 && sd <= HIT_MAX && sd - bd < AMBIG) return { i: -1, amb: [best, second] };
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
  var ptrs = {}, gest = null;
  function ptrList() { return Object.keys(ptrs).map(function (k) { return ptrs[k]; }); }
  function local(ev) { var r = cv.getBoundingClientRect(); return [ev.clientX - r.left, ev.clientY - r.top]; }
  cv.addEventListener('pointerdown', function (ev) {
    lastInput = performance.now();
    ev.preventDefault();
    try { cv.setPointerCapture(ev.pointerId); } catch (e) {}
    var p = local(ev); ptrs[ev.pointerId] = { x: p[0], y: p[1] };
    var list = ptrList();
    if (list.length === 1) gest = { type: 'tap', x0: p[0], y0: p[1], vx: view.x, vy: view.y, moved: false };
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
      view.s = Math.max(1, Math.min(ZMAX, gest.s0 * d / gest.d0));
      view.x = mx - bx * view.s; view.y = my - by * view.s;
      clampView(); updateFitBtn(); draw(); positionTutorial();
    } else if (gest.type === 'tap' || gest.type === 'pan') {
      var dx = p[0] - gest.x0, dy = p[1] - gest.y0;
      if (gest.type === 'tap' && Math.hypot(dx, dy) > 10) { gest.type = view.s > 1.01 ? 'pan' : 'none'; }
      if (gest.type === 'pan') { view.x = gest.vx + dx; view.y = gest.vy + dy; clampView(); draw(); positionTutorial(); }
    }
  });
  function endPtr(ev, cancel) {
    if (!ptrs[ev.pointerId]) return;
    delete ptrs[ev.pointerId];
    if (!cancel && gest && gest.type === 'tap' && !ptrList().length) onBoardTap(gest.x0, gest.y0);
    if (!ptrList().length) gest = null; else if (gest && gest.type === 'pinch') gest = { type: 'none' };
  }
  cv.addEventListener('pointerup', function (ev) { endPtr(ev, false); });
  cv.addEventListener('pointercancel', function (ev) { endPtr(ev, true); });
  cv.addEventListener('wheel', function (ev) { // masaüstü / emülatör: tekerlekle yakınlaştırma
    if (!LV) return; ev.preventDefault();
    var p = local(ev); zoomAt(p[0], p[1], view.s * (ev.deltaY < 0 ? 1.15 : 1 / 1.15));
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
    SFX.tap(); buzz('tap');
    hintIdx = -1;
    var a = LV.arrows[i], now = performance.now();
    var per = reduced ? 30 : T.anim.slidePerCell;
    if (r.type === 'exit') {
      var dist = offscreenCells(a);
      var dur = Math.max(T.anim.slideMin, dist * per);
      if (reduced) dur = Math.max(120, dist * per);
      dur *= animScale;
      anims[i] = { kind: 'exit', t0: now, dur: dur, dist: dist, done: function () { if (G.isWon()) onWin(); } };
      // easeSlide(q)·dist = tahtadan çıkış mesafesi olan q'yu ikiye bölerek bul
      var need = Math.min(dist, boardLeaveCells(a)), lo = 0, hi = 1;
      for (var it = 0; it < 18; it++) { var mid = (lo + hi) / 2; if (easeSlide(mid) * dist < need) lo = mid; else hi = mid; }
      lockUntil = now + hi * dur;
      SFX.slideOut(Math.min(1, exitStreak / 6)); exitStreak++;
      buzz('slideOut');
      busy = G.isWon(); // son ok: kazanma ekranına kadar girdi kapalı
    } else {
      exitStreak = 0;
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
        if (r.lifeLost) { toast(t('game.crash')); var h = $('hearts'); h.classList.remove('shake'); void h.offsetWidth; h.classList.add('shake'); }
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
  function showEnd(stars, res) {
    var id = LV.id;
    openModal(function (sh) {
      sh.id = 'end-sheet';
      sh.setAttribute('data-stars', stars);
      sh.appendChild(el('h2', null)).textContent = t('end.title');
      var sb = el('div', 'stars-big');
      for (var i = 1; i <= 3; i++) sb.insertAdjacentHTML('beforeend', icon(i <= stars ? 'star' : 'starEmpty', i === 2 ? 'mid' : ''));
      sh.appendChild(sb);
      var line = el('p'); line.textContent = G.collisions === 0 ? t('end.perfect') : t('end.collisions', { n: G.collisions });
      sh.appendChild(line);
      if (G.opts.relaxed) sh.appendChild(el('p', 'relaxed-note')).textContent = t('end.relaxed_note');
      var rw = el('div'); rw.innerHTML = '<span class="reward">' + icon('coin') + '<span>' + esc(t('end.reward', { n: res.coins })) + '</span></span>';
      sh.appendChild(rw);
      var tags = el('div');
      if (res.newBest) tags.appendChild(el('span', 'tag')).textContent = t('end.new_best');
      if (res.chapterDone) { tags.appendChild(el('span', 'tag')).textContent = t('end.chapter_done'); tags.appendChild(el('span', 'tag')).textContent = t('map.chapter_bonus', { n: res.bonus }); }
      sh.appendChild(tags);
      if (id === PREBUILT) sh.appendChild(el('p')).textContent = t('end.all_done'); // v1.3: sonsuz bölümler başlıyor
      var a = el('div', 'actions');
      // Oyuncu devam edince (ve yalnızca o zaman) geçiş reklamı kuralları değerlendirilir (ads.js)
      var going = false;
      function cont(fn) { return function () { if (going) return; going = true; M.continueAfterLevel(id, function () { fn(); }); }; }
      if (id < Store.MAX_LEVEL) a.appendChild(btn(t('end.next'), 'primary', cont(function () { startLevel(id + 1); }), 'end-next'));
      var row = el('div', 'actions row'); row.style.marginTop = '0';
      row.appendChild(btn(t('end.replay'), 'secondary', cont(function () { startLevel(id); }), 'end-replay'));
      row.appendChild(btn(t('end.map'), 'secondary', cont(function () { show('map'); }), 'end-map'));
      a.appendChild(row);
      sh.appendChild(a);
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
      if (M.rewardedAvailable() && G && revivedFor !== levelKey()) { // ödüllü +1 can: seviye başına en fazla 1 kez
        var my = session;
        a.appendChild(btn(t('ads.watch_life') + ' <small class="opt">· ' + esc(t('ads.optional')) + '</small>', 'secondary', function () {
          M.showRewarded('life', function () { if (my === session && G && G.revive()) revivedFor = levelKey(); }, function (rewarded) {
            if (my !== session) return;
            if (rewarded && G && !G.isDead()) { closeModal(); busy = false; updateHUD(); toast(t('ads.reward_life')); kick(); }
            else toast(t('ads.no_reward'));
          });
        }, 'dead-revive'));
      }
      a.appendChild(btn(isDaily() ? t('common.back') : t('game.to_map'), 'secondary', function () { show(isDaily() ? 'menu' : 'map'); }));
      sh.appendChild(a);
    });
  }
  function restartLevel() {
    if (!G) return;
    G.reset(); anims = {}; shake = null; hintIdx = -1; busy = false; lockUntil = 0; exitStreak = 0; session++; winDone = false; aimSel = -1;
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

  function useHint() {
    if (!G || busy || G.isWon()) return;
    var i = G.hint();
    if (i < 0) return;
    var free = S.freeHints > 0;
    if (!Store.spendBooster('hint')) { SFX.error(); buzz('error'); toast(t('game.not_enough_coins')); return; }
    SFX.hint(); buzz('button');
    hintIdx = i; hintUntil = performance.now() + 2000;
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
    if (document.hidden && current === 'game' && G && !busy && !modalOpen()) $('btn-pause').click();
  });

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
    view: function () { return { s: view.s, x: view.x, y: view.y, cell: lay.cell }; },
    fastAnim: function (on) { animScale = on ? 0.02 : 1; },
    endless: function () { return { cached: Object.keys(endless).map(Number), queue: genQueue.slice(), job: genJob ? genJob.id : 0, stats: genStats.slice() }; },
    zoomAt: function (x, y, s) { zoomAt(x, y, s); },
    startDaily: startDaily, openCalendar: openCalendar,
    dailyLevel: function (ymd) { var d = dailyLevel(ymd || Store.ymd()); return d ? JSON.parse(JSON.stringify(d)) : null; },
    cellCenter: function (i) {
      var t0 = E.cellsOf(LV.arrows[i])[0], r = cv.getBoundingClientRect(), c = lay.cell; // kuyruk hücresinin merkezi
      return { x: r.left + (lay.ox + (t0[0] + 0.5) * c) * view.s + view.x, y: r.top + (lay.oy + (t0[1] + 0.5) * c) * view.s + view.y };
    }
  };
})();
