/* Arrowtile — audio.js
 * Tüm sesler Web Audio ile kodla üretilir (dosya yok). Kısa, yumuşak, düşük seviye.
 * Kullanım: ilk dokunuşta SFX.init(); sonra SFX.tap(), SFX.slideOut() ...
 */
(function () {
  'use strict';

  var ctx = null, master = null, noiseBuf = null;
  var enabled = true, held = false; // held: reklam gösterilirken ses bağlamı duraklatılır (docs/15 §4)
  var lastPlay = {};

  function now() { return ctx ? ctx.currentTime : 0; }

  function init() {
    try {
      if (!ctx) {
        var AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return false;
        ctx = new AC();
        master = ctx.createGain();
        master.gain.value = 0.55;
        // yumuşak tepe sınırlayıcı: üst üste binen seslerde patlamayı önler
        var comp = ctx.createDynamicsCompressor();
        comp.threshold.value = -14; comp.knee.value = 12; comp.ratio.value = 4;
        comp.attack.value = 0.003; comp.release.value = 0.15;
        master.connect(comp); comp.connect(ctx.destination);
        // 1 sn beyaz gürültü tamponu
        noiseBuf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
        var d = noiseBuf.getChannelData(0);
        for (var i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      }
      if (ctx.state === 'suspended' && ctx.resume) ctx.resume();
      return true;
    } catch (e) { ctx = null; return false; }
  }

  function ready(name, minGapMs) {
    if (!enabled || held) return false;
    if (!ctx && !init()) return false;
    if (ctx.state === 'suspended') { try { ctx.resume(); } catch (e) {} }
    var t = Date.now();
    if (name && minGapMs && lastPlay[name] && t - lastPlay[name] < minGapMs) return false;
    lastPlay[name] = t;
    return true;
  }

  // Zarflı ton: frekans f0 -> f1, süre dur (sn)
  function tone(o) {
    var t0 = now() + (o.delay || 0);
    var osc = ctx.createOscillator(), g = ctx.createGain();
    osc.type = o.type || 'sine';
    osc.frequency.setValueAtTime(o.f0, t0);
    if (o.f1) osc.frequency.exponentialRampToValueAtTime(o.f1, t0 + o.dur);
    var a = o.attack || 0.005, peak = o.gain || 0.3;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + o.dur);
    osc.connect(g);
    var out = g;
    if (o.lp) {
      var f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = o.lp;
      g.connect(f); out = f;
    }
    out.connect(master);
    osc.start(t0); osc.stop(t0 + o.dur + 0.02);
  }

  // Filtreli gürültü: bant geçiren frekansı süpürür
  function noise(o) {
    var t0 = now() + (o.delay || 0);
    var src = ctx.createBufferSource(); src.buffer = noiseBuf;
    var f = ctx.createBiquadFilter(); f.type = o.filter || 'bandpass';
    f.Q.value = o.q || 1;
    f.frequency.setValueAtTime(o.f0, t0);
    if (o.f1) f.frequency.exponentialRampToValueAtTime(o.f1, t0 + o.dur);
    var g = ctx.createGain(), peak = o.gain || 0.3, a = o.attack || 0.01;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + o.dur);
    src.connect(f); f.connect(g); g.connect(master);
    src.start(t0, Math.random() * 0.5); src.stop(t0 + o.dur + 0.02);
  }

  function safe(name, gap, fn) {
    return function () {
      try { if (ready(name, gap)) fn.apply(null, arguments); } catch (e) { /* sessiz */ }
    };
  }

  // C majör pentatonik — her şey uyumlu kalsın
  var N = { C5: 523.25, D5: 587.33, E5: 659.25, G5: 783.99, A5: 880, C6: 1046.5, E6: 1318.5, G6: 1568 };

  var SFX = {
    init: init,
    setEnabled: function (b) { enabled = !!b; try { if (master) master.gain.value = enabled ? 0.55 : 0; } catch (e) {} },
    isEnabled: function () { return enabled; },
    /** Reklam gösterilirken: yeni ses çalınmaz, bağlam askıya alınır. resume() reklam kapanınca devam ettirir. */
    pause: function () { held = true; try { if (ctx && ctx.state === 'running') ctx.suspend(); } catch (e) {} },
    resume: function () { held = false; try { if (ctx && enabled && !document.hidden && ctx.state === 'suspended') ctx.resume(); } catch (e) {} },
    isPaused: function () { return held; },
    setVolume: function (v) { try { if (master) master.gain.value = Math.max(0, Math.min(1, v)); } catch (e) {} },

    // Oka dokunma: kısa ahşap "tık"
    tap: safe('tap', 30, function () {
      tone({ f0: 900, f1: 600, dur: 0.05, type: 'triangle', gain: 0.22 });
    }),

    // Ok çıkışı: havalı whoosh + yükselen ince ton. pitch (0..1) ardışık çıkışlarda yükseltilebilir
    slideOut: safe('slideOut', 40, function (pitch) {
      var p = 1 + (pitch || 0) * 0.5;
      noise({ f0: 500 * p, f1: 3200 * p, dur: 0.24, q: 1.2, gain: 0.28, attack: 0.03 });
      tone({ f0: 420 * p, f1: 980 * p, dur: 0.18, type: 'sine', gain: 0.09, attack: 0.02 });
    }),

    // Çarpışma: boğuk "tonk" + kısa düşük gürültü
    bump: safe('bump', 80, function () {
      tone({ f0: 180, f1: 70, dur: 0.18, type: 'sine', gain: 0.42 });
      tone({ f0: 320, f1: 140, dur: 0.08, type: 'triangle', gain: 0.12, lp: 900 });
      noise({ f0: 300, dur: 0.07, q: 0.8, gain: 0.12, filter: 'lowpass' });
    }),

    // Seviye bitti: 4 notalık yükselen arpej + parıltı
    levelWin: safe('levelWin', 400, function () {
      var seq = [N.C5, N.E5, N.G5, N.C6];
      for (var i = 0; i < seq.length; i++) {
        tone({ f0: seq[i], dur: 0.32, type: 'triangle', gain: 0.2, delay: i * 0.1 });
        tone({ f0: seq[i] * 2, dur: 0.2, type: 'sine', gain: 0.05, delay: i * 0.1 });
      }
      tone({ f0: N.E6, dur: 0.5, type: 'sine', gain: 0.08, delay: 0.42 });
      tone({ f0: N.G6, dur: 0.6, type: 'sine', gain: 0.06, delay: 0.5 });
    }),

    // Yıldız: i = 0,1,2 — her yıldız bir üst nota
    star: safe('star', 60, function (i) {
      var notes = [N.E6 / 2 * 1.5, N.A5 * 1.5, N.C6 * 1.5];
      var f = notes[Math.max(0, Math.min(2, i | 0))];
      tone({ f0: f, dur: 0.28, type: 'sine', gain: 0.16 });
      tone({ f0: f * 2, dur: 0.14, type: 'sine', gain: 0.04, delay: 0.02 });
    }),

    // Jeton: klasik iki nota "ding-ding"
    coin: safe('coin', 50, function () {
      tone({ f0: 1318.5, dur: 0.07, type: 'square', gain: 0.06, lp: 4000 });
      tone({ f0: 1975.5, dur: 0.22, type: 'square', gain: 0.06, lp: 4000, delay: 0.065 });
    }),

    // Arayüz butonu: yumuşak "pop"
    button: safe('button', 40, function () {
      tone({ f0: 520, f1: 780, dur: 0.07, type: 'sine', gain: 0.18 });
    }),

    // Hata (jeton yetmedi, can bitti): iki alçalan, yumuşak nota
    error: safe('error', 150, function () {
      tone({ f0: 330, dur: 0.12, type: 'triangle', gain: 0.18, lp: 1500 });
      tone({ f0: 247, dur: 0.2, type: 'triangle', gain: 0.18, lp: 1500, delay: 0.12 });
    }),

    // Ek: ipucu ve geri al
    hint: safe('hint', 100, function () {
      tone({ f0: N.G5, dur: 0.18, type: 'sine', gain: 0.12 });
      tone({ f0: N.D5 * 2, dur: 0.25, type: 'sine', gain: 0.1, delay: 0.09 });
    }),
    undo: safe('undo', 80, function () {
      noise({ f0: 2400, f1: 600, dur: 0.18, q: 1.2, gain: 0.18, attack: 0.02 });
    })
  };

  // Titreşim yardımcısı (THEME.vibrate desenleriyle)
  var vibOn = true;
  SFX.setVibration = function (b) { vibOn = !!b; };
  SFX.vibrate = function (name) {
    try {
      if (!vibOn) return;
      var pat = (window.THEME && window.THEME.vibrate && window.THEME.vibrate[name]) || name;
      if (!pat) return;
      // Android kabuğu: yerel titreşim (WebView'de navigator.vibrate her cihazda güvenilir değil)
      var b = window.AndroidBridge;
      if (b && typeof b.vibrate === 'function') { b.vibrate(JSON.stringify(pat)); return; }
      if (navigator.vibrate) navigator.vibrate(pat);
    } catch (e) {}
  };

  // Uygulama arka plana gidince bağlamı askıya al (pil)
  try {
    document.addEventListener('visibilitychange', function () {
      try {
        if (!ctx) return;
        if (document.hidden) ctx.suspend(); else if (enabled) ctx.resume();
      } catch (e) {}
    });
  } catch (e) {}

  window.SFX = SFX;
})();
