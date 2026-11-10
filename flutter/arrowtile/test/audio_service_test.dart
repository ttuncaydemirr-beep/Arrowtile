// 1.1.4 (docs/21): ses servisi — ateşle ve unut, kuyruk yok, geç ses yok, takılan oyuncu yeniden kurulur.
// Sahte oyuncular (SfxVoice) ile; gerçek audioplayers kullanılmaz.
import 'dart:async';

import 'package:arrowtile/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVoice implements SfxVoice {
  FakeVoice(this.file, this.log, this.cfg);
  final String file;
  final List<String> log; // gerçekten çalınan (resume çağrısı TAMAMLANAN) sesler
  final VoiceCfg cfg;
  bool disposed = false;
  int resumes = 0;

  @override
  Future<void> prepare() async {
    if (cfg.prepareFails) throw StateError('prepare');
  }

  @override
  Future<void> stop() async {
    final Duration? d = cfg.stopDelay;
    if (d != null) await Future<void>.delayed(d);
  }

  @override
  Future<void> resume() async {
    resumes++;
    if (disposed) return;
    log.add(file);
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  bool get broken => disposed || cfg.broken;
}

class VoiceCfg {
  Duration? stopDelay;
  bool prepareFails = false;
  bool broken = false;
}

class Rig {
  final List<String> played = <String>[];
  final List<FakeVoice> voices = <FakeVoice>[];
  final VoiceCfg cfg = VoiceCfg();
  final List<String> dead = <String>[];
  late final AudioService a;
  Rig({int opTimeoutMs = 150, int lateMs = 60}) {
    a = AudioService(
      voiceFactory: (String f) {
        final FakeVoice v = FakeVoice(f, played, cfg);
        voices.add(v);
        return v;
      },
      opTimeoutMs: opTimeoutMs,
      lateMs: lateMs,
      recoverMinGapMs: 0,
      longAwayMs: 200,
    );
    a.onDeadRecovered = dead.add;
  }
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('normal: her dokunuş TAM bir ses; oyuncular açılışta önceden kurulur (çalmada yeni oyuncu yaratılmaz)', () async {
    final Rig r = Rig();
    await r.a.init();
    final int made = r.voices.length;
    expect(made, greaterThan(AudioService.files.length));
    r.a.slideOut();
    await _wait(10);
    expect(r.played, <String>['slide_out_0']);
    await _wait(50);
    r.a.slideOut();
    await _wait(10);
    expect(r.played, <String>['slide_out_0', 'slide_out_0']);
    expect(r.voices.length, made, reason: 'AudioPool gibi her çalmada oyuncu yaratılmaz');
  });

  test('reklam ekrandayken ses düşer; reklam kapanınca düşen ses ÇALINMAZ; sonraki dokunuşta tam bir ses', () async {
    final Rig r = Rig();
    await r.a.init();
    r.a.setHeld(true);
    r.a.slideOut();
    r.a.tap();
    await _wait(30);
    expect(r.played, isEmpty);
    r.a.setHeld(false);
    await _wait(100);
    expect(r.played, isEmpty, reason: 'ertelenmiş / kuyruktaki ses yok');
    r.a.slideOut();
    await _wait(10);
    expect(r.played, <String>['slide_out_0']);
  });

  test('takılı oyuncu (stop 400 ms sürer): ses GEÇ çalınmaz, oyuncular yeniden kurulur, sonraki dokunuşta tam bir ses', () async {
    final Rig r = Rig();
    await r.a.init();
    r.cfg.stopDelay = const Duration(milliseconds: 400);
    r.a.slideOut(); // takılır
    await _wait(600); // stop sonunda tamamlandı ama zaman aşımı/geç: resume YOK
    expect(r.played, isEmpty, reason: 'dokunuştan çok sonra (kendiliğinden) ses çalmamalı');
    expect(r.dead, isNotEmpty, reason: 'audio_dead_recovered');
    r.cfg.stopDelay = null;
    await _wait(50); // yeniden kurulum
    expect(r.a.ready, isTrue);
    r.a.slideOut();
    await _wait(10);
    expect(r.played, <String>['slide_out_0']);
    await _wait(500);
    expect(r.played, hasLength(1), reason: 'eski takılı oyuncudan sonradan ses gelmez');
  });

  test('stop yavaş ama zaman aşımından kısa (geç sınırını aşar): ses DÜŞER, sonradan çalmaz', () async {
    final Rig r = Rig(opTimeoutMs: 500, lateMs: 60);
    await r.a.init();
    r.cfg.stopDelay = const Duration(milliseconds: 120);
    r.a.bump();
    await _wait(300);
    expect(r.played, isEmpty);
  });

  test('tüm oyuncular meşgulse ses kuyruğa alınmaz (düşer)', () async {
    final Rig r = Rig(opTimeoutMs: 1000, lateMs: 1000);
    await r.a.init();
    r.cfg.stopDelay = const Duration(milliseconds: 400);
    for (int i = 0; i < 4; i++) {
      r.a.coin();
      await _wait(55); // tekrar aralığından uzun; ilk iki oyuncu hâlâ meşgul
    }
    await _wait(700);
    expect(r.played, <String>['coin', 'coin'], reason: 'coin için 2 oyuncu: fazlası düşer, sonradan ÇALMAZ');
  });

  test('uzun arka plandan dönüş: oyuncular yeniden kurulur; sonraki dokunuşta tam bir ses', () async {
    final Rig r = Rig();
    await r.a.init();
    final int gen = r.a.debugGen;
    r.a.onLifecycle(foreground: false);
    await _wait(250);
    r.a.onLifecycle(foreground: true);
    await _wait(50);
    expect(r.a.debugGen, greaterThan(gen));
    r.a.tap();
    await _wait(10);
    expect(r.played, <String>['tap']);
  });

  test('reklam kapanınca bozuk oyuncu varsa yeniden kurulur (audio_dead_recovered)', () async {
    final Rig r = Rig();
    await r.a.init();
    r.a.setHeld(true);
    r.cfg.broken = true; // reklam etkinliği sırasında yerel oyuncular bozuldu
    r.a.setHeld(false);
    expect(r.dead, isNotEmpty);
    r.cfg.broken = false;
    await _wait(50);
    r.a.hint();
    await _wait(10);
    expect(r.played, <String>['hint']);
  });

  test('ses kapalıysa hiç çalmaz', () async {
    final Rig r = Rig();
    await r.a.init();
    r.a.enabled = false;
    r.a.slideOut();
    await _wait(20);
    expect(r.played, isEmpty);
  });
}
