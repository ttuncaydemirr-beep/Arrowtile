/* Arrowtile — theme.js
 * Görsel token'lar + drawArrow(ctx, opts). Bağımlılıksız, çevrimdışı.
 * Estetik: "Emaye levha" — porselen zemin, emaye renkli kalın oklar,
 * altta hafif "kalınlık" gölgesi; yön her zaman şekille (ok başı + gövde
 * şevronları) okunur, renk sadece süs.
 */
(function () {
  'use strict';

  var THEME = {
    // Fiyatlar: yönetici kararıyla tasarım belgesinden (0/300/500/750/1000).
    version: 1,

    colors: {
      light: {
        bg:         '#E3E9EE', // porselen gri-mavi zemin
        board:      '#F6F8FA', // tahta yüzü
        boardEdge:  '#C9D3DC', // tahta kenarı / alt kalınlık
        cell:       '#E6ECF1', // hücre çukuru
        cellDot:    '#C3CED8', // hücre köşe noktası
        ink:        '#1D2C3B', // ana metin (lacivert mürekkep)
        inkSoft:    '#5B6B7B', // ikincil metin
        accent:     '#2456A6', // kobalt — birincil buton
        accentInk:  '#FFFFFF',
        star:       '#E8A317', // safran yıldız
        starEmpty:  '#C9D3DC',
        coin:       '#D99A1E',
        danger:     '#C9372F', // can / hata
        success:    '#2E8B57',
        highlight:  '#FFFFFF', // ipucu halkası iç
        highlightRing: '#E8A317',
        shadow:     'rgba(29,44,59,0.18)'
      },
      dark: {
        bg:         '#0F1B27',
        board:      '#172736',
        boardEdge:  '#0A131C',
        cell:       '#1E3245',
        cellDot:    '#2C4560',
        ink:        '#E9EFF4',
        inkSoft:    '#93A5B6',
        accent:     '#5B8DE0',
        accentInk:  '#0F1B27',
        star:       '#F2B632',
        starEmpty:  '#2C4560',
        coin:       '#F0B23A',
        danger:     '#EF5B52',
        success:    '#4DBB7F',
        highlight:  '#FFFFFF',
        highlightRing: '#F2B632',
        shadow:     'rgba(0,0,0,0.45)'
      }
    },

    // Açılabilir ok temaları. Oklar dizideki renkleri sırayla (index % n) kullanır.
    // chevron: gövde üstündeki yön işaretlerinin rengi.
    // names: dil bazlı tema adları (i18n.js'e de kopyalanabilir)
    arrowThemes: [
      { id: 'emaye',  name: 'Emaye', names: { tr: 'Emaye', en: 'Enamel', de: 'Emaille', ar: 'مينا' },  price: 0,
        colors: ['#2456A6', '#C9372F', '#E09A12', '#2E8B57', '#6B4C9A'],
        chevron: 'rgba(255,255,255,0.78)' },
      { id: 'lokum',  name: 'Lokum', names: { tr: 'Lokum', en: 'Delight', de: 'Lokum', ar: 'راحة الحلقوم' },  price: 300,
        colors: ['#E77FA0', '#F2A65A', '#7FB8A4', '#A78BD4', '#E7C65A'],
        chevron: 'rgba(255,255,255,0.85)' },
      { id: 'cini',   name: 'Çini', names: { tr: 'Çini', en: 'Tile', de: 'Fliese', ar: 'قيشاني' },   price: 500,
        colors: ['#1F5FA8', '#1C8C8C', '#C2362B', '#2F7A3D', '#14397A'],
        chevron: 'rgba(255,255,255,0.80)' },
      { id: 'bakir',  name: 'Bakır', names: { tr: 'Bakır', en: 'Copper', de: 'Kupfer', ar: 'نحاس' },  price: 750,
        colors: ['#B5652E', '#8E4A24', '#D08A45', '#6E3B1F', '#C9773A'],
        chevron: 'rgba(255,240,220,0.80)' },
      { id: 'gece',   name: 'Gece Lambası', names: { tr: 'Gece Lambası', en: 'Night Light', de: 'Nachtlicht', ar: 'ضوء الليل' }, price: 1000,
        colors: ['#38D1E0', '#F25FA6', '#B6F25F', '#FFC83D', '#9D7BFF'],
        chevron: 'rgba(15,27,39,0.70)' }
    ],

    // Tüm oranlar hücre boyuna (cell) göredir.
    // v1.2 (docs/08 §2): ince oklar. Gövde hücrenin ~%28'i, ok başı ~%55'i; şevron ve uç noktası orantılı küçüldü.
    shape: {
      margin:      0.12,  // okun hücre kenarından içeride kalma payı (kuyruk ve uç)
      bodyWidth:   0.15,  // gövde kalınlığı (1.2.0, docs/24: %18 → %15 — daha ince oklar)
      headWidth:   0.40,  // ok başı genişliği (1.2.0: %42 → %40; en az headMinPx)
      monoBody:    0.085, // 1.2.0 tek renk kipi: ince çizgi gövde (en az monoMinPx)
      monoHead:    0.34,  // tek renk kipi: küçük ok başı genişliği
      monoMinPx:   1.6,
      headLength:  0.30,  // ok başı uzunluğu
      headMinPx:   7,     // ok başı en az 7 px genişlikte kalır (küçük hücrede yön okunur)
      chevronMinCell: 22, // hücre bundan küçükse gövde şevronları çizilmez; yönü ok başı verir
      headRadius:  0.05,  // ok başı yan köşe yuvarlaklığı
      tipRadius:   0.04,  // uç yuvarlaklığı
      depth:       0.045, // alt kalınlık gölgesi (ekran aşağısına)
      chevronSize: 0.075, // gövde şevronu yarı yüksekliği
      chevronLine: 0.045, // şevron çizgi kalınlığı
      dotRadius:   0.04,  // ok başındaki nokta
      gridDot:     0.045, // tahtadaki ızgara noktası (hücre köşelerinde)
      cellRadius:  0.16,  // hücre çukuru köşe yarıçapı
      cellGap:     0.06,  // hücreler arası boşluk
      boardRadius: 0.30,  // tahta köşe yarıçapı (hücreye oranla)
      boardPad:    0.30,  // tahta iç dolgusu
      buttonRadius: 14,   // px
      buttonMinHeight: 52 // px, dokunma hedefi
    },

    // ms + CSS/JS easing
    anim: {
      slidePerCell:  55,   // ok kayışı: hücre başına
      slideMin:      160,
      slideEase:     'cubic-bezier(0.45, 0, 0.85, 0.35)', // hızlanarak çıkış
      exitFade:      120,  // (eski) tahta dışına çıkınca sönme — 1.2.0'da kullanılmaz
      exitPerCell:   26,   // 1.2.0 çıkış: sabit hız, hücre başına ms (ok kendi yolunu izleyerek tahta kenarına dek gider)
      exitMin:       260,  // en kısa çıkış süresi
      exitMax:       1100, // en uzun çıkış süresi (çok uzun yol: hız artar, yine sabit)
      tapGap:        110,  // çıkış başladıktan sonra sıradaki dokunuşa kadar en kısa ara
      bumpForward:   90,   // çarpışma noktasına gidiş
      bumpBack:      220,  // geri sekme
      bumpEase:      'cubic-bezier(0.34, 1.56, 0.64, 1)',
      shake:         260,  // tahta sarsıntısı
      shakeAmp:      0.08, // hücre oranı
      shakeCycles:   3,
      starPop:       380,  // her yıldız
      starStagger:   180,
      starEase:      'cubic-bezier(0.34, 1.7, 0.6, 1)',
      buttonPress:   90,   // basınca scale 0.95
      buttonRelease: 160,
      buttonEase:    'cubic-bezier(0.2, 0.8, 0.2, 1)',
      screenFade:    200,
      hintPulse:     900   // ipucu halkası nefes döngüsü
    },

    vibrate: {
      // 1.2.0 (docs/17 §7): titreşim tüm olaylarda TEK kısa darbe
      tap:      [16],
      slideOut: [16],
      bump:     [16],
      levelWin: [16],
      error:    [16],
      button:   [16]
    },

    font: {
      // Dış font yok: yalnızca cihazda bulunan sistem fontları.
      stacks: {
        latin:  'system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", Ubuntu, Arial, sans-serif',
        arabic: '"Noto Naskh Arabic", "Noto Sans Arabic", "Geeza Pro", "Segoe UI", Tahoma, "Droid Arabic Naskh", sans-serif',
        numeric: 'ui-rounded, "SF Pro Rounded", system-ui, -apple-system, Roboto, sans-serif'
      },
      byLang: { tr: 'latin', en: 'latin', de: 'latin', ar: 'arabic' },
      // Arapça glifler aynı px'te daha küçük görünür, satır yüksekliği daha fazla ister
      scaleByLang: { tr: 1, en: 1, de: 1, ar: 1.08 },
      lineHeightByLang: { tr: 1.3, en: 1.3, de: 1.3, ar: 1.55 },
      sizes: { title: 30, h2: 22, body: 17, button: 18, buttonMin: 14, small: 14, levelNum: 20, hud: 18 },
      weights: { regular: 400, medium: 600, bold: 800 }
    },

    rtlLangs: ['ar'],

    // Uzun metinli buton kuralı (özellikle Almanca)
    button: {
      minHeight: 52,      // px
      padX: 18,           // px
      maxLines: 2,        // önce satır kaydır
      shrinkStep: 1,      // sonra 1px adımlarla küçült
      minFont: 14,        // bunun altına inme; asla ellipsis yok
      hyphens: 'auto'     // <html lang> doğru verilirse tarayıcı heceler
    }
  };

  // ---- yardımcılar --------------------------------------------------------

  function hexToRgb(h) {
    h = String(h).replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  function shade(hex, amt) { // amt <0 koyulaştır, >0 açar
    try {
      var c = hexToRgb(hex), t = amt < 0 ? 0 : 255, p = Math.abs(amt);
      return 'rgb(' + c.map(function (v) { return Math.round(v + (t - v) * p); }).join(',') + ')';
    } catch (e) { return hex; }
  }
  THEME.shade = shade;
  var shadeCache = {};
  function shadeOf(c) { return shadeCache[c] || (shadeCache[c] = shade(c, -0.35)); }

  THEME.forceMode = null; // G7: 'light' | 'dark' | null (otomatik = sistem)
  THEME.palette = function (mode) {
    if (!mode) mode = THEME.forceMode;
    if (!mode) {
      try { mode = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'; }
      catch (e) { mode = 'light'; }
    }
    return THEME.colors[mode] || THEME.colors.light;
  };
  THEME.arrowColor = function (themeIndex, arrowIndex) {
    var t = THEME.arrowThemes[themeIndex] || THEME.arrowThemes[0];
    return t.colors[arrowIndex % t.colors.length];
  };

  // Köşeleri ayrı yarıçaplı kapalı çokgen (arcTo ile).
  function roundedPoly(ctx, pts, radii) {
    var n = pts.length;
    var last = pts[n - 1], first = pts[0];
    ctx.moveTo((last[0] + first[0]) / 2, (last[1] + first[1]) / 2);
    for (var i = 0; i < n; i++) {
      var p = pts[i], q = pts[(i + 1) % n];
      ctx.arcTo(p[0], p[1], q[0], q[1], radii[i] || 0);
    }
    ctx.closePath();
  }

  var ANGLE = { R: 0, D: Math.PI / 2, L: Math.PI, U: -Math.PI / 2 };
  var STEP = { R: [1, 0], D: [0, 1], L: [-1, 0], U: [0, -1] };

  /**
   * drawArrow(ctx, opts) — v1.3 (docs/09): kıvrımlı (yılan) oklar da çizilir.
   * Yeni kullanım: { ox, oy, cells: [[x,y]...] (kuyruk→baş), dir, cell, off, color, alpha, highlight, chevron }
   *  ox,oy : tahtanın sol üst köşesi (piksel); cells hücre koordinatı
   *  off   : iz üzerindeki kayma (hücre). İz = gövde hücreleri + baştan dir yönünde düz doğru; gövde başı
   *          tren gibi izler (çıkış ve çarpma animasyonu).
   * Eski kullanım (önizleme): { x, y, cell, dir, len, ... } — x,y kuyruk hücresinin sol üst köşesi, düz ok.
   * Çizim: köşeleri yuvarlak ince çizgi + sonda ok başı; şevronlar (hücre ≥ chevronMinCell) düz parçalarda.
   */
  function drawArrow(ctx, o) {
    if (!ctx || !o) return;
    var cell = o.cell || 40, dir = ANGLE.hasOwnProperty(o.dir) ? o.dir : 'R', D = STEP[dir];
    var cells = o.cells, ox = o.ox, oy = o.oy;
    if (!cells) { // eski düz biçim
      cells = []; for (var k0 = 0; k0 < Math.max(1, o.len || 1); k0++) cells.push([D[0] * k0, D[1] * k0]);
      ox = o.x; oy = o.y;
    }
    var n = cells.length, off = o.off || 0;
    var S = THEME.shape, color = o.color || THEME.arrowThemes[0].colors[0];
    var mono = !!o.mono; // 1.2.0: tek renk ince çizgi (gölge, şevron, nokta yok)
    var mg = S.margin, bw = mono ? Math.max(S.monoMinPx, S.monoBody * cell) : Math.max(2, S.bodyWidth * cell), hw = mono ? Math.max(5, S.monoHead * cell) : Math.max(S.headMinPx || 0, S.headWidth * cell);
    var hl = Math.max(hw * 0.72, S.headLength * cell);
    // iz noktası (hücre merkezleri, hücre biriminde): -1 = kuyruğun arkasındaki sanal nokta
    var back = n > 1 ? [cells[0][0] - cells[1][0], cells[0][1] - cells[1][1]] : [-D[0], -D[1]];
    function P(i) {
      if (i < 0) return [cells[0][0] + back[0], cells[0][1] + back[1]];
      if (i <= n - 1) return cells[i];
      return [cells[n - 1][0] + D[0] * (i - n + 1), cells[n - 1][1] + D[1] * (i - n + 1)];
    }
    function T(sv) {
      var i = Math.floor(sv); if (i > n - 2 && sv >= n - 1) { var hd = cells[n - 1], q = sv - (n - 1); return [hd[0] + D[0] * q, hd[1] + D[1] * q]; }
      if (i < -1) i = -1;
      var a = P(i), b = P(i + 1), t = sv - i;
      return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
    }
    function px(pt) { return [ox + (pt[0] + 0.5) * cell, oy + (pt[1] + 0.5) * cell]; }
    var s0 = off - (0.5 - mg), s1 = off + n - 1 + (0.5 - mg), sb = s1 - hl / cell; // kuyruk ucu, uç, ok başı tabanı
    var tip = px(T(s1)), basePt = px(T(sb)), ang = ANGLE[dir];
    function bodyPath(dy) {
      ctx.beginPath();
      var p0 = px(T(s0)); ctx.moveTo(p0[0], p0[1] + dy);
      for (var i = Math.ceil(s0 + 1e-6); i < sb; i++) { var pi = px(T(i)); ctx.lineTo(pi[0], pi[1] + dy); }
      ctx.lineTo(basePt[0] + Math.cos(ang) * bw * 0.3, basePt[1] + Math.sin(ang) * bw * 0.3 + dy);
    }
    function headPath(dy) {
      ctx.save();
      ctx.translate(tip[0], tip[1] + dy); ctx.rotate(ang);
      ctx.beginPath();
      roundedPoly(ctx, [[-hl, -hw / 2], [0, 0], [-hl, hw / 2]], [S.headRadius * cell, S.tipRadius * cell, S.headRadius * cell]);
      ctx.restore();
    }
    function whole(dy, width, style, fill) {
      bodyPath(dy); ctx.lineWidth = width; ctx.strokeStyle = style; ctx.stroke();
      headPath(dy); if (fill) { ctx.fillStyle = style; ctx.fill(); }
      if (width > bw) { ctx.lineWidth = width - bw; ctx.stroke(); }
    }
    ctx.save();
    ctx.globalAlpha = (o.alpha == null ? 1 : Math.max(0, Math.min(1, o.alpha)));
    ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    if (o.highlight) {
      var pal = THEME.palette();
      whole(0, bw + cell * 0.20, pal.highlightRing, true);
      whole(0, bw + cell * 0.08, pal.highlight, true);
    }
    if (!mono) whole(S.depth * cell, bw, shadeOf(color), true); // alt kalınlık (ekran aşağısı)
    whole(0, bw, color, true);                           // yüz
    if (mono) { ctx.restore(); return; }
    // şevronlar: her gövde hücresinde akış yönünde ">" (köşe ve baş hücresi hariç)
    if (cell >= (S.chevronMinCell || 0)) {
      var cs = S.chevronSize * cell;
      ctx.lineWidth = Math.max(0.9, S.chevronLine * cell);
      ctx.strokeStyle = o.chevron || 'rgba(255,255,255,0.78)';
      for (var c = 0; c < n - 1; c++) {
        var sv = off + c; if (sv > sb - 0.35) break;
        var fi = Math.floor(sv), fr = sv - fi;
        var a1 = T(fi), a2 = T(fi + 1), ddx = a2[0] - a1[0], ddy = a2[1] - a1[1];
        if (fr < 0.01 && fi >= 0 && fi <= n - 2) { // tam hücre merkezinde: gelen ve giden yön aynı olmalı (köşe değil)
          var pv = T(fi - 1); if (fi > 0 && (a1[0] - pv[0] !== ddx || a1[1] - pv[1] !== ddy)) continue;
        } else if (fr > 0.65 || fr < 0.35 && fi > 0 && (function () { var pv2 = T(fi - 1); return a1[0] - pv2[0] !== ddx || a1[1] - pv2[1] !== ddy; })()) continue;
        var cp = px(T(sv)), ca = Math.atan2(ddy, ddx);
        ctx.save(); ctx.translate(cp[0], cp[1]); ctx.rotate(ca);
        ctx.beginPath(); ctx.moveTo(-cs * 0.6, -cs); ctx.lineTo(cs * 0.4, 0); ctx.lineTo(-cs * 0.6, cs); ctx.stroke();
        ctx.restore();
      }
    }
    // ok başında küçük beyaz nokta: yönü renk dışı bir işaretle pekiştirir
    ctx.beginPath();
    ctx.arc(tip[0] - Math.cos(ang) * hl * 0.70, tip[1] - Math.sin(ang) * hl * 0.70, Math.max(0.9, cell * S.dotRadius), 0, Math.PI * 2);
    ctx.fillStyle = o.chevron || 'rgba(255,255,255,0.78)';
    ctx.fill();
    ctx.restore();
  }

  // Tepsi dolgusu (hücre oranı): geniş tahtada (≥ 21 sütun) 0,1, aksi halde 0,3 — 360 px'te 22 sütunda hücre ≥ 16 px
  THEME.boardPadFor = function (w) { return w >= 21 ? 0.1 : THEME.shape.boardPad; };
  // Izgara/tahta çizimi (geliştirici kolaylığı için)
  function drawBoard(ctx, ox, oy, w, h, cell, mode) {
    var pal = THEME.palette(mode), S = THEME.shape;
    var pad = THEME.boardPadFor(w) * cell, r = Math.min(S.boardRadius * cell, 10);
    var bx = ox - pad, by = oy - pad, bwid = w * cell + pad * 2, bh = h * cell + pad * 2;
    ctx.save();
    function rr(x, y, ww, hh, rad) {
      ctx.beginPath();
      roundedPoly(ctx, [[x, y], [x + ww, y], [x + ww, y + hh], [x, y + hh]], [rad, rad, rad, rad]);
    }
    rr(bx, by + cell * 0.1, bwid, bh, r); ctx.fillStyle = pal.boardEdge; ctx.fill();
    rr(bx, by, bwid, bh, r); ctx.fillStyle = pal.board; ctx.fill();
    // v1.2 (docs/08 §2): hücre kutuları yok; tek düz yüzey + hücre köşelerinde çok hafif nokta ızgara.
    // Noktalar hücre merkezinde değil köşelerde: boş hücrenin ortası tahta renginde kalır, oklar ince çizgiler gibi okunur.
    var dr = Math.max(0.7, S.gridDot * cell);
    ctx.fillStyle = pal.cellDot;
    ctx.globalAlpha = mode === 'dark' || (!mode && pal === THEME.colors.dark) ? 0.55 : 0.75;
    ctx.beginPath();
    for (var j = 0; j <= h; j++) for (var i = 0; i <= w; i++) {
      var px = ox + i * cell, py = oy + j * cell;
      ctx.moveTo(px + dr, py); ctx.arc(px, py, dr, 0, Math.PI * 2);
    }
    ctx.fill();
    ctx.restore();
  }

  // Dil yardımcıları
  THEME.fontFor = function (lang) {
    var k = THEME.font.byLang[lang] || 'latin';
    return THEME.font.stacks[k];
  };
  THEME.isRTL = function (lang) { return THEME.rtlLangs.indexOf(lang) !== -1; };
  // <html> etiketine dil, yön ve CSS değişkenlerini uygular
  THEME.applyLang = function (lang) {
    try {
      var root = document.documentElement;
      root.setAttribute('lang', lang);
      root.setAttribute('dir', THEME.isRTL(lang) ? 'rtl' : 'ltr');
      root.style.setProperty('--font', THEME.fontFor(lang));
      root.style.setProperty('--font-num', THEME.font.stacks.numeric);
      root.style.setProperty('--lh', THEME.font.lineHeightByLang[lang] || 1.3);
      root.style.setProperty('--fs-scale', THEME.font.scaleByLang[lang] || 1);
    } catch (e) {}
  };
  // Metni sığdır: kelime arasından kaydır (maxLines) -> 1px adımlarla küçült (minFont) -> en son çare heceleme.
  // Ellipsis ve kırpma yok. Bir kelimenin iki satıra bölünmesi de "sığmadı" sayılır (test raporu H4).
  // opts: { minFont, maxLines } (verilmezse THEME.button değerleri)
  function wordSplit(el) {
    try {
      var w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT), n, re = /\S+/g, m;
      while ((n = w.nextNode())) {
        if (n.parentElement && n.parentElement.closest && n.parentElement.closest('svg')) continue;
        re.lastIndex = 0;
        while ((m = re.exec(n.textContent))) {
          if (m[0].length < 2) continue;
          var rg = document.createRange(); rg.setStart(n, m.index); rg.setEnd(n, m.index + m[0].length);
          var rs = rg.getClientRects(), top = null;
          for (var i = 0; i < rs.length; i++) {
            if (rs[i].width < 0.5) continue;
            if (top === null) top = Math.round(rs[i].top); else if (Math.abs(Math.round(rs[i].top) - top) > 2) return true;
          }
        }
      }
    } catch (e) {}
    return false;
  }
  THEME.fitButton = function (el, opts) {
    try {
      var B = THEME.button, o = opts || {}, minF = o.minFont || B.minFont, maxL = o.maxLines || B.maxLines;
      el.style.fontSize = ''; el.style.hyphens = ''; el.style.webkitHyphens = ''; el.style.overflowWrap = '';
      var cs = getComputedStyle(el);
      var fs = parseFloat(cs.fontSize) || THEME.font.sizes.button;
      var ratio = (parseFloat(cs.lineHeight) || fs * 1.3) / fs;
      var padV = (parseFloat(cs.paddingTop) || 0) + (parseFloat(cs.paddingBottom) || 0);
      var boxed = cs.display !== 'inline';
      function over() {
        return el.scrollWidth > el.clientWidth + 1 ||
               (boxed && el.scrollHeight - padV > fs * ratio * maxL + 2 && el.textContent.trim().indexOf(' ') > 0) ||
               wordSplit(el);
      }
      while (fs > minF && over()) { fs -= B.shrinkStep; el.style.fontSize = fs + 'px'; }
      if (el.scrollWidth > el.clientWidth + 1) { // son çare: heceleme (<html lang> doğru olmalı), sonra satır içi kırma
        el.style.hyphens = 'auto'; el.style.webkitHyphens = 'auto';
        if (el.scrollWidth > el.clientWidth + 1) el.style.overflowWrap = 'anywhere';
      }
    } catch (e) {}
  };

  THEME.STEP = STEP;
  window.THEME = THEME;
  window.drawArrow = drawArrow;
  window.drawBoard = drawBoard;
})();
