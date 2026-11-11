// Seviye üretici (1.2.0 v2, docs/24 + docs/26): aynı seviye numarası → web sürümüyle AYNI seviye.
//  1) bölüm yapısı (20 seviye, 5'li kademe dilimleri), bölüm tahtası, kademe tahtası (sahip kararı #2), specFor/seedFor: JS ile alan alan eşit
//     (test/golden/levelgen_golden.json, tools/flutter/make-goldens.js).
//  2) makeMask: aynı tohumla JS ile aynı satırlar (şekilli tahta).
//  3) makeLevel: seçilmiş seviyelerde TAM ok listesi + maske + ölçüler JS ile birebir (ilk fark açıkça raporlanır).
//  4) levelHash (FNV-1a 32 / canon, maske dahil): tools/level-hashes.json (verify-5000.js, seviye 1..5000) ile ≥ 40 seviyede
//     (sabit seçilmiş: her kademe, her bölüm boyu, bölüm sınırları 1/20/21/100/101/180/181, 1619, 5000 + örneklenmiş) eşit;
//     5.000 sonrası (5001+, sonsuz) için altın dosyadaki özetlerle.
//  5) Hazır paket (lib/data/levels.json, ilk 100) özetleri level-hashes.json ile eşit: paket == oyun içi üretici.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arrowtile/core/levelgen.dart';
import 'package:arrowtile/core/models.dart';
import 'package:arrowtile/core/rng.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// tools/level-hashes.json: hashes[i] = seviye i+1 (verify-5000.js, web CI).
Map<String, dynamic> loadHashDoc() => jsonDecode(File('../../tools/level-hashes.json').readAsStringSync()) as Map<String, dynamic>;

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
  final Map<String, dynamic> hashDoc = loadHashDoc();
  final List<String> hashes = <String>[for (final dynamic h in (hashDoc['hashes'] as List<dynamic>)) h as String];
  const Timeout long = Timeout(Duration(minutes: 5));

  test('level-hashes.json: 5.000 özet, sekiz hane, üretici sürümü Dart ile aynı', () {
    expect(hashes.length, kDesigned);
    expect(hashes.every((String h) => RegExp(r'^[0-9a-f]{8}$').hasMatch(h)), isTrue);
    expect(hashDoc['generator'], kGenVersion);
    expect(g['version'], kGenVersion);
  });

  group('bölüm yapısı (saf fonksiyonlar)', () {
    test('bölüm = 20 seviye: 5 Kolay → 5 Orta → 5 Zor → 5 Aşırı zor', () {
      expect(kPerChapter, 20);
      for (int ch = 0; ch < 3; ch++) {
        for (int k = 0; k < 20; k++) {
          final int id = ch * 20 + k + 1;
          expect(tierOf(id), kTierOrder[k ~/ 5], reason: 'seviye $id');
          expect(chapterOf(id), ch + 1);
          expect(indexOf(id), k);
        }
      }
      expect(chapterOf(5000), kChapters);
      expect(chapterOf(5001), kChapters + 1);
      expect(tierOf(5001), 'easy');
      expect(tierOf(5020), 'extreme');
    });

    test('bölüm tahtası 9x13 → 28x45 (GROW_CHAPTERS = 9), kademe tahtası (#2) JS ile aynı', () {
      expect(kGrowChapters, 9);
      for (final dynamic x in (g['sizes'] as List<dynamic>)) {
        final Map<String, dynamic> m = x as Map<String, dynamic>;
        final int ch = m['ch'] as int;
        final ({int w, int h}) sz = sizeOfChapter(ch);
        final Map<String, dynamic> e = m['size'] as Map<String, dynamic>;
        expect(sz.w, e['w'], reason: 'bölüm $ch');
        expect(sz.h, e['h'], reason: 'bölüm $ch');
        final List<dynamic> tiers = m['tiers'] as List<dynamic>;
        for (int k = 0; k < 4; k++) {
          final ({int w, int h}) ts = sizeOf((ch - 1) * kPerChapter + k * 5 + 1);
          final Map<String, dynamic> te = tiers[k] as Map<String, dynamic>;
          expect(ts.w, te['w'], reason: 'bölüm $ch ${kTierOrder[k]}');
          expect(ts.h, te['h'], reason: 'bölüm $ch ${kTierOrder[k]}');
          expect(ts.w >= kMinW && ts.h >= kMinH, isTrue);
        }
        expect(sizeOf(ch * kPerChapter).w, sz.w, reason: 'Aşırı zor = bölüm tahtası');
      }
      expect(sizeOfChapter(1), (w: kMinW, h: kMinH));
      expect(sizeOfChapter(9), (w: kMaxW, h: kMaxH));
      expect(sizeOfChapter(10), (w: kMinW, h: kMinH));
      // bölüm 9 (28x45): Kolay ≈ %50, Orta ≈ %72, Zor ≈ %90 alan
      expect(sizeOf(161), (w: 20, h: 32));
      expect(sizeOf(166), (w: 24, h: 38));
      expect(sizeOf(171), (w: 27, h: 43));
      expect(sizeOf(176), (w: 28, h: 45));
    });
  });

  group('specFor / seedFor', () {
    for (final dynamic item in (g['specs'] as List<dynamic>)) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      final int id = m['id'] as int;
      test('seviye $id', () {
        final LevelSpec s = specFor(id);
        final Map<String, dynamic> e = m['spec'] as Map<String, dynamic>;
        expect(s.w, e['w']);
        expect(s.h, e['h']);
        expect(s.tier, e['tier']);
        expect(s.chapter, e['chapter']);
        expect(s.index, e['index']);
        expect(s.shape, e['shape']);
        expect(seedFor(id, 0), m['seed0']);
        expect(seedFor(id, 3), m['seed3']);
        expect(s.seed, m['seed0']);
      });
    }
  });

  group('makeMask (şekilli tahta) JS ile aynı', () {
    for (final dynamic item in (g['masks'] as List<dynamic>)) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      test('${m['kind']} ${m['w']}x${m['h']} tohum ${m['seed']}', () {
        final int w = m['w'] as int, h = m['h'] as int;
        final Uint8List mask = makeMask(w, h, m['kind'] as String, Rng(m['seed'] as int).next);
        expect(maskRows(mask, w, h), equals(<String>[for (final dynamic r in (m['rows'] as List<dynamic>)) r as String]));
      });
    }
  });

  group('makeLevel (altın: tam ok listesi + maske + ölçüler)', () {
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
        final dynamic em0 = e['mask'];
        expect(r.mask, em0 == null ? isNull : equals(<String>[for (final dynamic x in (em0 as List<dynamic>)) x as String]));
        final String? diff = firstArrowDiff(r.arrows, arrowsFromJson(e['arrows']));
        expect(diff, isNull, reason: 'ilk fark: $diff');
        final Measure2 got = measure2(r.w, r.h, r.arrows, r.mask);
        final Map<String, dynamic> em = m['measure'] as Map<String, dynamic>;
        expect(got.solvable, isTrue);
        expect(got.depth, em['depth']);
        expect(got.initialFree, em['initialFree']);
        expect(got.arrows, em['arrows']);
        expect(got.curved, em['curved']);
        expect(got.maxLen, em['maxLen']);
        expect(got.fill, equals((em['fill'] as num).toDouble()));
        expect(got.meanTurns, equals((em['meanTurns'] as num).toDouble()));
        expect(got.score, equals((em['score'] as num).toDouble()));
      }, timeout: long);
    }
  });

  group('levelHash == tools/level-hashes.json (≥ 40 seviye)', () {
    // sabit: öğretici, bölüm sınırları, her kademe her bölüm boyunda (1. büyüme döngüsü), şekilli Aşırı zor, 1619, 5000
    const List<int> fixed = <int>[
      1, 2, 3, 4, 5, 6, 10, 11, 15, 16, 19, 20, 21, 25, 26, 35, 36, 40, //
      41, 46, 51, 56, 57, 58, 59, 60, 61, 66, 71, 80, 81, 86, 91, 100, //
      101, 106, 111, 116, 120, 121, 126, 131, 140, 141, 146, 151, 160, //
      161, 166, 171, 176, 177, 178, 179, 180, 181, 200, 1619, 4999, 5000,
    ];
    final List<int> random = sampleIds(20, 4, 5000, 20261111).where((int i) => !fixed.contains(i)).toList();
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
        final LevelResult r = makeLevel(id);
        expect(r.w, m['w']);
        expect(r.h, m['h']);
        expect(r.diff, m['diff']);
        expect(levelResultHash(r), m['hash']);
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

  test('Level JSON gidiş-dönüşü maskeyi korur (önbellek / izolat)', () {
    final LevelResult r = makeLevel(56);
    expect(r.mask, isNotNull);
    final Level back = Level.fromJson(jsonDecode(jsonEncode(r.toLevel().toJson())) as Map<String, dynamic>);
    expect(back.mask, r.mask);
    expect(levelHash(back), hashes[55]);
  });
}
