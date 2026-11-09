// Seviye üretici (v1.1, docs/15 §5): aynı seviye numarası → web sürümüyle AYNI seviye.
//  1) specFor / seedFor / sizeOfChapter: JS çıktısıyla alan alan eşit (test/golden/levelgen_golden.json).
//  2) makeLevel: seçilmiş seviyelerde tam ok listesi JS ile birebir (ilk fark açıkça raporlanır).
//  3) levelHash (FNV-1a 32 / canon): tools/level-hashes.json (verify-5000.js çıktısı, seviye 1..5000) ile rastgele örneklenmiş +
//     sabit seçilmiş seviyelerde (1, 200, 201, her kademeden, 1619, 5000) eşit; 5.000 sonrası (5001+) için altın dosyadaki özetlerle.
//  4) Hazır paket (lib/data/levels.json, ilk 200) özetleri level-hashes.json ile eşit: paket == oyun içi üretici.
// Dart JIT'te 22x31 aşırı zor seviyeler birkaç saniye sürebilir; testler seviye başına ayrı koşar ve geniş zaman aşımı kullanır.
import 'dart:convert';
import 'dart:io';

import 'package:arrowtile/core/levelgen.dart';
import 'package:arrowtile/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// tools/level-hashes.json: hashes[i] = seviye i+1 (verify-5000.js, web CI).
List<String> loadHashes() {
  final dynamic j = jsonDecode(File('../../tools/level-hashes.json').readAsStringSync());
  return <String>[for (final dynamic h in ((j as Map<String, dynamic>)['hashes'] as List<dynamic>)) h as String];
}

/// Belirlenimli sahte-rastgele örnek (LCG; dart:math Random algoritması sürümler arasında değişebilir).
List<int> sampleIds(int count, int from, int to, int seed) {
  int x = seed;
  final Set<int> out = <int>{};
  while (out.length < count) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    out.add(from + (x >> 8) % (to - from + 1));
  }
  return out.toList()..sort();
}

void main() {
  final Map<String, dynamic> g = golden('levelgen_golden.json') as Map<String, dynamic>;
  final List<String> hashes = loadHashes();
  const Timeout long = Timeout(Duration(minutes: 10));

  test('level-hashes.json: 5.000 özet, sekiz hane', () {
    expect(hashes.length, kDesigned);
    expect(hashes.every((String h) => RegExp(r'^[0-9a-f]{8}$').hasMatch(h)), isTrue);
  });

  group('bölüm yapısı (saf fonksiyonlar)', () {
    test('bölüm = 10 seviye; kademe döngüsü 1-3 Kolay, 4-6 Orta, 7-8 Zor, 9-10 Aşırı zor', () {
      expect(kPerChapter, 10);
      const List<String> want = <String>['easy', 'easy', 'easy', 'medium', 'medium', 'medium', 'hard', 'hard', 'extreme', 'extreme'];
      for (int ch = 0; ch < 3; ch++) {
        for (int k = 0; k < 10; k++) {
          expect(tierOf(ch * 10 + k + 1), want[k], reason: 'seviye ${ch * 10 + k + 1}');
          expect(chapterOf(ch * 10 + k + 1), ch + 1);
          expect(indexOf(ch * 10 + k + 1), k);
        }
      }
      expect(chapterOf(5000), kChapters);
      expect(chapterOf(5001), kChapters + 1);
    });

    test('tahta boyu bölüme bağlı: 7x9 → 22x31 sınırı, JS ile aynı', () {
      for (final dynamic x in (g['sizes'] as List<dynamic>)) {
        final Map<String, dynamic> m = x as Map<String, dynamic>;
        final ({int w, int h}) sz = sizeOfChapter(m['ch'] as int);
        final Map<String, dynamic> e = m['size'] as Map<String, dynamic>;
        expect(sz.w, e['w'], reason: 'bölüm ${m['ch']}');
        expect(sz.h, e['h'], reason: 'bölüm ${m['ch']}');
      }
      expect(sizeOfChapter(1).w, 7);
      expect(sizeOfChapter(1).h, 9);
      expect(sizeOfChapter(21).w, kMaxW);
      expect(sizeOfChapter(21).h, kMaxH);
      expect(sizeOfChapter(500).w, kMaxW);
    });
  });

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
        expect(s.index, e['index']);
        expect(s.minDepth, e['minDepth']);
        expect(s.maxDepth, e['maxDepth']); // aşırı zorda null (sınırsız)
        expect(seedFor(id, 0), m['seed0']);
        expect(seedFor(id, 3), m['seed3']);
      });
    }
  });

  group('makeLevel (altın: tam ok listesi)', () {
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
        final Measure got = measure(LgBoard(r.w, r.h, r.arrows));
        final Map<String, dynamic> em = m['measure'] as Map<String, dynamic>;
        expect(got.solvable, isTrue);
        expect(got.depth, em['depth']);
        expect(got.initialFree, em['initialFree']);
        expect(got.arrows, em['arrows']);
        expect(got.curved, em['curved']);
        expect(got.fill, closeTo((em['fill'] as num).toDouble(), 1e-12));
        expect(got.score, closeTo((em['score'] as num).toDouble(), 1e-9));
      }, timeout: long);
    }
  });

  group('levelHash == tools/level-hashes.json', () {
    // sabit: ilk/son hazır, her kademe küçük ve en büyük tahtada, 1619 (rastgele seçilmiş orta bölüm), 5000
    const List<int> fixed = <int>[
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 17, 19, 20, 38, 99, 100, 150, 199, 200, //
      201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 1619, 4999, 5000,
    ];
    final List<int> random = sampleIds(24, 12, 5000, 20261109).where((int i) => !fixed.contains(i)).toList();
    for (final int id in <int>[...fixed, ...random]) {
      test('seviye $id', () {
        final LevelResult r = makeLevel(id);
        expect(levelResultHash(r), hashes[id - 1], reason: 'seviye $id (${r.w}x${r.h} ${r.diff}, ok=${r.ok}, tur=${r.rounds})');
      }, timeout: long);
    }
  });

  group('5.000 sonrası (sonsuz) seviyeler: altın özet', () {
    for (final dynamic x in (g['extraHashes'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      final int id = m['id'] as int;
      test('seviye $id', () {
        expect(levelResultHash(makeLevel(id)), m['hash']);
      }, timeout: long);
    }
  });

  test('hazır paket (levels.json, ilk $kPrebuilt) özetleri level-hashes.json ile eşit', () {
    final List<dynamic> raw = jsonDecode(File('lib/data/levels.json').readAsStringSync()) as List<dynamic>;
    expect(raw.length, kPrebuilt);
    final List<int> bad = <int>[];
    for (int i = 0; i < raw.length; i++) {
      final Level lv = Level.fromJson(raw[i] as Map<String, dynamic>);
      if (lv.id != i + 1 || levelHash(lv) != hashes[i]) bad.add(i + 1);
    }
    expect(bad, isEmpty, reason: 'paket ≠ üretici: ${bad.join(',')}');
  });
}
