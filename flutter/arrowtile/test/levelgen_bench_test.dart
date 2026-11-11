// 1.2.0 (docs/26 §D): Dart üretim süresi ölçümü — en büyük tahta (bölüm 28x45). CI günlüğüne p50/p95/en çok yazılır.
// Ölçüt: Aşırı zor 28x45 p95 < 400 ms (CI, `flutter test` JIT). Web (Node) ölçümü: p95 ≈ 40 ms (docs/24 §3, docs/26).
// Ayrıca: üretim UI iş parçacığı dışında (Isolate.run) aynı seviyeyi verir — oyun sonsuz seviyeleri izolatta üretir.
import 'dart:isolate';

import 'package:arrowtile/core/levelgen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bölüm tahtası 28x45 olan bölümler (büyüme döngüsünün son adımı): 9, 18, 27, …
List<int> maxBoardIds(String tier, int chapters) {
  final int k = kTierOrder.indexOf(tier);
  return <int>[
    for (int c = 1; c <= chapters; c++)
      for (int j = 1; j <= 5; j++) (c * kGrowChapters - 1) * kPerChapter + k * 5 + j
  ];
}

({double p50, double p95, double max, double avg}) stats(List<double> ms) {
  final List<double> a = List<double>.of(ms)..sort();
  double at(double q) => a[(a.length * q).floor().clamp(0, a.length - 1)];
  return (p50: at(0.5), p95: at(0.95), max: a.last, avg: a.reduce((double x, double y) => x + y) / a.length);
}

List<double> timeLevels(List<int> ids) {
  final List<double> out = <double>[];
  for (final int id in ids) {
    final Stopwatch sw = Stopwatch()..start();
    final LevelResult r = makeLevel(id);
    sw.stop();
    expect(r.arrows, isNotEmpty);
    out.add(sw.elapsedMicroseconds / 1000.0);
  }
  return out;
}

void main() {
  test('üretim süresi: en büyük bölüm (28x45) — Aşırı zor p95 < 400 ms', () {
    // ısınma (JIT derlemesi ölçüme girmesin)
    for (final int id in <int>[176, 171, 161]) {
      makeLevel(id);
    }
    final Map<String, List<int>> sets = <String, List<int>>{
      'easy': maxBoardIds('easy', 2),
      'medium': maxBoardIds('medium', 2),
      'hard': maxBoardIds('hard', 4),
      'extreme': maxBoardIds('extreme', 8),
    };
    final Map<String, ({double p50, double p95, double max, double avg})> res = <String, ({double p50, double p95, double max, double avg})>{};
    for (final MapEntry<String, List<int>> e in sets.entries) {
      final ({int w, int h}) sz = sizeOf(e.value.first);
      final ({double p50, double p95, double max, double avg}) s = stats(timeLevels(e.value));
      res[e.key] = s;
      // ignore: avoid_print
      print('LEVELGEN_BENCH ${e.key} ${sz.w}x${sz.h} n=${e.value.length} '
          'ort=${s.avg.toStringAsFixed(1)} p50=${s.p50.toStringAsFixed(1)} p95=${s.p95.toStringAsFixed(1)} max=${s.max.toStringAsFixed(1)} ms');
    }
    expect(sizeOf(sets['extreme']!.first), (w: kMaxW, h: kMaxH));
    expect(res['extreme']!.p95, lessThan(400), reason: 'Aşırı zor 28x45 p95');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('üretim izolatta (UI iş parçacığı dışında) aynı seviyeyi verir', () async {
    final Map<String, dynamic> j = await Isolate.run<Map<String, dynamic>>(() => makeLevel(5037).toLevel().toJson());
    expect(j['w'], kMaxW);
    expect(j['h'], kMaxH);
    expect(j['mask'], isNotNull); // 5037: şekilli Aşırı zor
    expect(levelResultHash(makeLevel(5037)), isNotEmpty);
    final List<dynamic> a = j['arrows'] as List<dynamic>;
    expect(a.length, makeLevel(5037).arrows.length);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
