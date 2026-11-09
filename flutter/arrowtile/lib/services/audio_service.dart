// Arrowtile — audio_service.dart: assets/sfx/*.wav (tools/flutter/render-sfx.js, audio.js sentezinden) çalma.
// Web'deki gibi her ses için en küçük tekrar aralığı vardır (ready(name, minGapMs)). Hata olursa sessiz kalır.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  bool enabled = true;
  bool _ready = false;

  /// Tam ekran reklam gösterilirken (docs/15 §4) yeni ses çalınmaz; reklam kapanınca [setHeld](false) ile devam eder.
  bool _held = false;
  bool get held => _held;
  void setHeld(bool v) => _held = v;
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
    try {
      // AudioPool.start() bir Future<StopFunction> döndürür; asenkron hata (platform kanalı vb.) yutulur, oyun sessiz devam eder.
      _pools[file]?.start().then<void>((_) {}, onError: (Object _) {});
    } catch (_) {}
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
    for (final AudioPool p in _pools.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _pools.clear();
    _ready = false;
  }
}
