// Arrowtile — audio_service.dart: assets/sfx/*.wav (tools/flutter/render-sfx.js, audio.js sentezinden) çalma.
// Web'deki gibi her ses için en küçük tekrar aralığı vardır (ready(name, minGapMs)). Hata olursa sessiz kalır.
import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  bool enabled = true;
  bool _ready = false;

  /// Tam ekran reklam gösterilirken (docs/15 §4) yeni ses çalınmaz; reklam kapanınca [setHeld](false) ile devam eder.
  /// 1.1.3 (docs/20): YALNIZCA reklam gerçekten EKRANDAYKEN true. Tutulurken ses DÜŞÜRÜLÜR (sıraya alınmaz, ertelenmez).
  bool _held = false;
  bool get held => _held;
  void setHeld(bool v) {
    final bool was = _held;
    _held = v;
    if (was && !v) recover(); // reklam etkinliğinden dönüldü: ses havuzları bozulmuş olabilir → yeniden kur
  }

  // 1.1.3: havuz bekçisi. AudioPool.start() boş oyuncu yoksa bekler (sıraya girer); arka plan/reklam etkinliği sırasında
  // "bitti" olayları gelmezse havuz tükenir (ses ölür) ve olaylar sonradan gelince bekleyen start() kendiliğinden çalar.
  // Bu yüzden: bekleyen start sayısı havuz boyutuna ulaştıysa yeni ses ÇALINMAZ (düşer), 2 sn'den uzun bekleyen start
  // havuzu "takılı" sayar ve havuzlar yeniden kurulur; üretim numarası değişince geç gelen start sonucu yok sayılır.
  int _gen = 0;
  bool _recovering = false;
  int _pausedAt = 0;
  final Map<String, int> _pending = <String, int>{};
  static const int _stuckMs = 2000;
  static const int _staleAwayMs = 3000;

  /// Test: gerçek havuz yerine çalma kaydı.
  void Function(String file)? _playHook;
  @visibleForTesting
  void debugReady({void Function(String file)? onPlay}) {
    _ready = true;
    _playHook = onPlay;
  }

  /// Uygulama arka plana gitti / öne geldi (ads_service reklam etkinliği dahil).
  void onLifecycle({required bool foreground}) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (!foreground) {
      if (_pausedAt == 0) _pausedAt = now;
      return;
    }
    final int away = _pausedAt == 0 ? 0 : now - _pausedAt;
    _pausedAt = 0;
    if (away >= _staleAwayMs) recover();
  }

  /// Havuzları atıp yeniden kurar. Sürerken gelen sesler düşer (kuyruğa alınmaz).
  void recover() {
    if (_playHook != null || _recovering || _pools.isEmpty && !_ready) return;
    _recovering = true;
    _gen++;
    _pending.clear();
    final List<AudioPool> old = _pools.values.toList();
    _pools.clear();
    _ready = false;
    unawaited(() async {
      for (final AudioPool p in old) {
        try {
          await p.dispose();
        } catch (_) {}
      }
      _recovering = false;
      await init();
    }());
  }
  final Map<String, AudioPool> _pools = <String, AudioPool>{};
  final Map<String, int> _lastPlay = <String, int>{};

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
  // ses adı → dosya (assets/ önekini audioplayers kendisi ekler)
  static const Map<String, String> _files = <String, String>{
    'tap': 'tap',
    'slide_out_0': 'slide_out_0',
    'slide_out_1': 'slide_out_1',
    'slide_out_2': 'slide_out_2',
    'bump': 'bump',
    'level_win': 'level_win',
    'star_0': 'star_0',
    'star_1': 'star_1',
    'star_2': 'star_2',
    'coin': 'coin',
    'button': 'button',
    'error': 'error',
    'hint': 'hint',
  };

  Future<void> init() async {
    if (_ready) return;
    try {
      // Oyun sesleri başka uygulamaların müziğini kesmesin (Android: ses odağı istenmez).
      final AudioContext ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
      for (final MapEntry<String, String> e in _files.entries) {
        _pools[e.key] = await AudioPool.create(
          source: AssetSource('sfx/${e.value}.wav'),
          maxPlayers: e.key == 'tap' || e.key == 'button' ? 3 : 2,
          playerMode: PlayerMode.lowLatency,
          audioContext: ctx,
        );
      }
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('AudioService.init: $e');
      _ready = false;
    }
  }

  bool _gate(String gapName) {
    if (!enabled || !_ready || _held) return false;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int gap = _gap[gapName] ?? 0;
    final int? last = _lastPlay[gapName];
    if (gap > 0 && last != null && now - last < gap) return false;
    _lastPlay[gapName] = now;
    return true;
  }

  void _play(String file) {
    final void Function(String)? hook = _playHook;
    if (hook != null) {
      hook(file);
      return;
    }
    final AudioPool? pool = _pools[file];
    if (pool == null) return;
    final int n = _pending[file] ?? 0;
    if (n >= pool.maxPlayers) {
      // havuz tükenmiş görünüyor: sesi DÜŞÜR (sıraya alma) ve havuzları yeniden kur
      recover();
      return;
    }
    _pending[file] = n + 1;
    final int gen = _gen;
    bool done = false;
    void settle() {
      if (done) return;
      done = true;
      if (gen == _gen) _pending[file] = math.max(0, (_pending[file] ?? 1) - 1);
    }

    final Timer stuck = Timer(const Duration(milliseconds: _stuckMs), () {
      if (!done && gen == _gen) recover();
    });
    try {
      // AudioPool.start() bir Future<StopFunction> döndürür; asenkron hata yutulur, oyun sessiz devam eder.
      pool.start().then<void>((_) {
        stuck.cancel();
        settle();
      }, onError: (Object _) {
        stuck.cancel();
        settle();
      });
    } catch (_) {
      stuck.cancel();
      settle();
    }
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
    for (final AudioPool p in _pools.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _pools.clear();
    _ready = false;
  }
}
