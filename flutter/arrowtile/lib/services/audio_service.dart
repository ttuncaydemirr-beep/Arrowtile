// Arrowtile — audio_service.dart: assets/sfx/*.wav (tools/flutter/render-sfx.js, audio.js sentezinden) çalma.
// Web'deki gibi her ses için en küçük tekrar aralığı vardır. Hata olursa sessiz kalır.
//
// 1.1.4 (docs/21) — ses "ölmesi" ve "dokunuşsuz ses" kök nedeni ve yeni tasarım:
//  1.1.3'e kadar her ses audioplayers `AudioPool` (PlayerMode.lowLatency) ile çalınıyordu. Düşük gecikme kipinde (Android SoundPool)
//  "bitti" (onPlayerComplete) olayı gelmez; AudioPool oyuncuyu ancak bu olayla havuza geri koyar. Sonuç: HER `start()` yeni bir
//  AudioPlayer yaratır (yerel oyuncu + kaynak yükleme + "hazır" olayı beklenir) ve eskileri hiç bırakılmaz; tüm bu işler havuzun
//  kilidi (lock) altında SIRAYLA yürür. Oturum uzadıkça yerel oyuncular birikir, bir yaratma/hazırlanma takılınca (reklam etkinliği,
//  arka plan, yoğun ana iş parçacığı) sonraki tüm `start()` çağrıları kilidin arkasında KUYRUĞA girer (ses ölür); kilit açılınca
//  kuyruktaki çağrılar sırayla çalar (dokunuşsuz "ok çıkış" sesi). 1.1.3'ün "bekleyen ≥ havuz boyu → düşür + yeniden kur" bekçisi
//  bu kuyruğu boşaltmıyordu (AudioPool.dispose kilit arkasındaki çağrıları iptal etmez).
//  Yeni tasarım: her ses için açılışta ÖNCEDEN yaratılmış SABİT sayıda oyuncu (2-3), PlayerMode.lowLatency + ReleaseMode.stop,
//  sırayla (round-robin). Çalma "ateşle ve unut": oyuncu meşgul/hazır değilse ses DÜŞER (kuyruk YOK); `stop()` geç dönerse (> [lateMs])
//  `resume()` HİÇ çağrılmaz (geç ses yok). Takılan/hata veren oyuncu → hepsi yeniden kurulur (audio_dead_recovered).
//  Susturma yalnızca tam ekran reklam EKRANDAYKEN ([setHeld]); reklam kapanınca ve arka plandan dönünce sağlık denetimi yapılır.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../core/diag.dart';

/// Tek bir önceden yüklenmiş ses oyuncusu (testlerde sahtesi kullanılır).
abstract class SfxVoice {
  /// Kaynağı yükler; bitince çalmaya hazırdır.
  Future<void> prepare();
  Future<void> stop();
  Future<void> resume();
  Future<void> dispose();

  /// Yerel oyuncu atılmış / bozulmuş görünüyor mu.
  bool get broken;
}

typedef SfxVoiceFactory = SfxVoice Function(String file);

class _AudioPlayerVoice implements SfxVoice {
  _AudioPlayerVoice(this.file);
  final String file;
  AudioPlayer? _p;

  // Oyun sesleri başka uygulamaların müziğini kesmesin ve ses odağı olaylarıyla kendiliğinden devam etmesin (Android: odak istenmez).
  static final AudioContext _ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  @override
  Future<void> prepare() async {
    final AudioPlayer p = AudioPlayer();
    _p = p;
    await p.setAudioContext(_ctx);
    await p.setPlayerMode(PlayerMode.lowLatency);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setSource(AssetSource('sfx/$file.wav'));
  }

  @override
  Future<void> stop() => _p?.stop() ?? Future<void>.value();

  @override
  Future<void> resume() => _p?.resume() ?? Future<void>.value();

  @override
  Future<void> dispose() => _p?.dispose() ?? Future<void>.value();

  @override
  bool get broken => _p == null || _p!.state == PlayerState.disposed;
}

class _Slot {
  _Slot(this.v);
  final SfxVoice v;
  bool ready = false;
  bool busy = false;
  bool failed = false;
  int busyAt = 0;
}

class AudioService {
  AudioService({
    SfxVoiceFactory? voiceFactory,
    int Function()? clock,
    this.opTimeoutMs = 800,
    this.lateMs = 250,
    this.prepareTimeoutMs = 5000,
    this.recoverMinGapMs = 2000,
    this.longAwayMs = 30000,
  })  : _factory = voiceFactory ?? ((String f) => _AudioPlayerVoice(f)),
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SfxVoiceFactory _factory;
  final int Function() _clock;

  /// Bir oyuncu işlemi (stop/resume) bu süreyi aşarsa oyuncu "takılı" sayılır, hepsi yeniden kurulur.
  final int opTimeoutMs;

  /// Dokunuştan bu kadar sonra hâlâ `resume()` çağrılamadıysa ses ÇALINMAZ (geç ses yasak).
  final int lateMs;
  final int prepareTimeoutMs;
  final int recoverMinGapMs;

  /// Arka planda bu süreden uzun kalındıysa dönüşte oyuncular koşulsuz yeniden kurulur.
  final int longAwayMs;

  bool enabled = true;
  bool _ready = false;
  bool _recovering = false;
  int _gen = 0;
  int _lastRecover = 0;
  int _pausedAt = 0;
  final Map<String, List<_Slot>> _voices = <String, List<_Slot>>{};
  final Map<String, int> _rr = <String, int>{};
  final Map<String, int> _lastPlay = <String, int>{};

  /// "Ses öldü ve kurtarıldı" bildirimi (telemetri `audio_dead_recovered`); [reason]: timeout | error | stuck | broken.
  void Function(String reason)? onDeadRecovered;

  bool get ready => _ready;

  /// Tam ekran reklam EKRANDAYKEN true (docs/20). Tutulurken ses DÜŞER (sıraya alınmaz, ertelenmez).
  bool _held = false;
  bool get held => _held;
  void setHeld(bool v) {
    if (_held == v) return;
    _held = v;
    diag('audio', v ? 'mute' : 'unmute');
    if (!v) checkHealth('ad_closed'); // reklam etkinliğinden dönüldü
  }

  /// Test: gerçek oyuncu yerine çalma kaydı (eski testler; yeni testler [voiceFactory] kullanır).
  void Function(String file)? _playHook;
  @visibleForTesting
  void debugReady({void Function(String file)? onPlay}) {
    _ready = true;
    _playHook = onPlay;
  }

  @visibleForTesting
  int get debugGen => _gen;

  // audio.js: safe(name, minGapMs, fn)
  static const Map<String, int> _gap = <String, int>{
    'tap': 30,
    'slideOut': 40,
    'bump': 80,
    'levelWin': 400,
    'star': 60,
    'coin': 50,
    'button': 40,
    'error': 150,
    'hint': 100,
  };
  // ses adı → dosya
  static const List<String> files = <String>[
    'tap',
    'slide_out_0',
    'slide_out_1',
    'slide_out_2',
    'bump',
    'level_win',
    'star_0',
    'star_1',
    'star_2',
    'coin',
    'button',
    'error',
    'hint',
  ];

  static int _voicesFor(String f) => f == 'tap' || f == 'button' || f.startsWith('slide_out') ? 3 : 2;

  Future<void> init() async {
    if (_ready || _recovering) return;
    await _build(reason: 'init');
  }

  Future<void> _build({required String reason}) async {
    final int gen = ++_gen;
    _ready = false;
    final Map<String, List<_Slot>> made = <String, List<_Slot>>{};
    int ok = 0, bad = 0;
    for (final String f in files) {
      final List<_Slot> slots = <_Slot>[];
      for (int i = 0; i < _voicesFor(f); i++) {
        final _Slot s = _Slot(_factory(f));
        try {
          await s.v.prepare().timeout(Duration(milliseconds: prepareTimeoutMs));
          s.ready = true;
          ok++;
        } catch (e) {
          bad++;
          s.failed = true;
          if (kDebugMode) debugPrint('AudioService.prepare $f: $e');
        }
        slots.add(s);
      }
      made[f] = slots;
    }
    if (gen != _gen) {
      // bu sırada yeniden kurma istendi: bu kurulum bayat
      for (final List<_Slot> l in made.values) {
        for (final _Slot s in l) {
          unawaited(_safeDispose(s.v));
        }
      }
      return;
    }
    _voices
      ..clear()
      ..addAll(made);
    _rr.clear();
    _ready = ok > 0;
    diag('audio', 'players_ready', <String, Object?>{'reason': reason, 'ok': ok, 'failed': bad});
  }

  static Future<void> _safeDispose(SfxVoice v) async {
    try {
      await v.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Oyuncuları atıp yeniden kurar. Sürerken sesler düşer (kuyruğa alınmaz). [dead]: ölü ses kurtarması (telemetri).
  void recover(String reason, {bool dead = false}) {
    if (_playHook != null) return;
    final int now = _clock();
    if (_recovering || now - _lastRecover < recoverMinGapMs) return;
    _recovering = true;
    _lastRecover = now;
    diag('audio', 'recreate', <String, Object?>{'reason': reason, 'dead': dead});
    if (dead) {
      try {
        onDeadRecovered?.call(reason);
      } catch (_) {}
    }
    final List<_Slot> old = <_Slot>[for (final List<_Slot> l in _voices.values) ...l];
    _voices.clear();
    _ready = false;
    unawaited(() async {
      try {
        for (final _Slot s in old) {
          await _safeDispose(s.v);
        }
        await _build(reason: reason);
      } finally {
        _recovering = false;
      }
    }());
  }

  /// Reklamdan / arka plandan dönüşte: takılı ya da bozuk oyuncu varsa yeniden kur.
  void checkHealth(String why) {
    if (_playHook != null || _voices.isEmpty) return;
    final int now = _clock();
    bool bad = false;
    for (final List<_Slot> l in _voices.values) {
      for (final _Slot s in l) {
        if (s.failed || (s.ready && s.v.broken) || (s.busy && now - s.busyAt > opTimeoutMs)) bad = true;
      }
    }
    if (bad) recover('health_$why', dead: true);
  }

  /// Uygulama arka plana gitti / öne geldi.
  void onLifecycle({required bool foreground}) {
    final int now = _clock();
    if (!foreground) {
      if (_pausedAt == 0) _pausedAt = now;
      return;
    }
    final int away = _pausedAt == 0 ? 0 : now - _pausedAt;
    _pausedAt = 0;
    if (away >= longAwayMs) {
      recover('long_away');
    } else {
      checkHealth('resume');
    }
  }

  bool _gate(String gapName) {
    if (!enabled) return false;
    if (_held || !_ready) {
      DiagLog.I.count(_held ? 'audio.drop_held' : 'audio.drop_not_ready');
      return false;
    }
    final int now = _clock();
    final int gap = _gap[gapName] ?? 0;
    final int? last = _lastPlay[gapName];
    if (gap > 0 && last != null && now - last < gap) return false;
    _lastPlay[gapName] = now;
    return true;
  }

  void _drop(String file, String why) {
    diag('audio', 'drop', <String, Object?>{'s': file, 'why': why});
  }

  void _play(String file) {
    final void Function(String)? hook = _playHook;
    if (hook != null) {
      hook(file);
      return;
    }
    final List<_Slot>? slots = _voices[file];
    if (slots == null || slots.isEmpty) return _drop(file, 'no_player');
    final int now = _clock();
    final int start = _rr[file] ?? 0;
    _Slot? pick;
    int idx = 0;
    bool stuck = false;
    for (int i = 0; i < slots.length; i++) {
      final int k = (start + i) % slots.length;
      final _Slot s = slots[k];
      if (s.busy && now - s.busyAt > opTimeoutMs) stuck = true;
      if (!s.busy && s.ready && !s.failed) {
        pick = s;
        idx = k;
        break;
      }
    }
    if (stuck) recover('stuck', dead: true);
    if (pick == null) return _drop(file, 'busy');
    _rr[file] = idx + 1;
    final _Slot s = pick;
    final int gen = _gen;
    s.busy = true;
    s.busyAt = now;
    unawaited(() async {
      try {
        await s.v.stop().timeout(Duration(milliseconds: opTimeoutMs));
        if (gen != _gen || _held || !enabled) return _drop(file, 'stale');
        if (_clock() - now > lateMs) return _drop(file, 'late'); // dokunuştan çok sonra: ÇALMA
        diag('audio', 'play', <String, Object?>{'s': file});
        await s.v.resume().timeout(Duration(milliseconds: opTimeoutMs));
      } on TimeoutException {
        s.failed = true;
        diag('audio', 'player_timeout', <String, Object?>{'s': file});
        if (gen == _gen) recover('timeout', dead: true);
      } catch (e) {
        s.failed = true;
        diag('audio', 'player_error', <String, Object?>{'s': file, 'e': e});
        if (gen == _gen) recover('error', dead: true);
      } finally {
        s.busy = false;
      }
    }());
  }

  void tap() {
    if (_gate('tap')) _play('tap');
  }

  /// [pitch] 0..1 ardışık çıkışlarda yükselir (main.js: Math.min(1, exitStreak / 6)); 3 kademe: 0, 0,5, 1.
  void slideOut([double pitch = 0]) {
    if (!_gate('slideOut')) return;
    final int b = (pitch.clamp(0.0, 1.0) * 2).round();
    _play('slide_out_$b');
  }

  void bump() {
    if (_gate('bump')) _play('bump');
  }

  void levelWin() {
    if (_gate('levelWin')) _play('level_win');
  }

  void star(int i) {
    if (_gate('star')) _play('star_${i.clamp(0, 2)}');
  }

  void coin() {
    if (_gate('coin')) _play('coin');
  }

  void button() {
    if (_gate('button')) _play('button');
  }

  void error() {
    if (_gate('error')) _play('error');
  }

  void hint() {
    if (_gate('hint')) _play('hint');
  }

  Future<void> dispose() async {
    _gen++;
    final List<_Slot> old = <_Slot>[for (final List<_Slot> l in _voices.values) ...l];
    _voices.clear();
    _ready = false;
    for (final _Slot s in old) {
      await _safeDispose(s.v);
    }
  }
}
