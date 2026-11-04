// Seviye üretici: aynı tohum → web sürümüyle AYNI seviye. Altın veri: seviye 217, 229, 300, 313 (test/golden/levelgen_golden.json).
// Bu testler Dart'ta ilk kez kullanıcı tarafında çalışır; ağır (22x31 aşırı zor) seviyeler JIT'te birkaç saniye sürebilir.
import 'package:arrowtile/core/levelgen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final Map<String, dynamic> g = golden('levelgen_golden.json') as Map<String, dynamic>;

  group('specFor / seedFor', () {
    for (final dynamic item in (g['specs'] as List<dynamic>)) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      final int id = m['id'] as int;
      test('seviye $id', () {
        final GenSpec s = specFor(id);
        final Map<String, dynamic> e = m['spec'] as Map<String, dynamic>;
        expect(s.w, e['w']);
        expect(s.h, e['h']);
        expect(s.fill, equals((e['fill'] as num).toDouble()));
        expect(s.fillMax, equals((e['fillMax'] as num).toDouble()));
        expect(s.maxFree, equals((e['maxFree'] as num).toDouble()));
        expect(s.curve, equals((e['curve'] as num).toDouble()));
        expect(s.maxLen, e['maxLen']);
        expect(s.tries, e['tries']);
        expect(s.effort, e['effort']);
        expect(s.passes, e['passes']);
        expect(s.cycles, e['cycles']);
        expect(s.tier, e['tier']);
        expect(s.chapter, e['chapter']);
        expect(seedFor(id, 0), m['seed0']);
        expect(seedFor(id, 3), m['seed3']);
      });
    }
  });

  group('makeLevel (altın)', () {
    for (final dynamic item in (g['levels'] as List<dynamic>)) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      final int id = m['id'] as int;
      test('seviye $id: ok listesi JS ile birebir', () {
        final LevelResult r = makeLevel(id);
        final Map<String, dynamic> e = m['level'] as Map<String, dynamic>;
        expect(r.w, e['w']);
        expect(r.h, e['h']);
        expect(r.diff, e['diff']);
        expect(r.chapter, e['chapter']);
        expect(r.ok, e['ok']);
        expect(r.rounds, e['rounds']);
        expect(r.par, e['par']);
        final String? diff = firstArrowDiff(r.arrows, arrowsFromJson(e['arrows']));
        expect(diff, isNull, reason: 'ilk fark: $diff');
        // ölçüler
        final Measure got = measure(LgBoard(r.w, r.h, r.arrows));
        final Map<String, dynamic> em = m['measure'] as Map<String, dynamic>;
        expect(got.solvable, isTrue);
        expect(got.depth, em['depth']);
        expect(got.initialFree, em['initialFree']);
        expect(got.arrows, em['arrows']);
        expect(got.curved, em['curved']);
        expect(got.fill, closeTo((em['fill'] as num).toDouble(), 1e-12));
        expect(got.score, closeTo((em['score'] as num).toDouble(), 1e-9));
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });
}
