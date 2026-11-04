// RNG ve FNV özeti: JS (levelgen.js) çıktısıyla BİT BİT aynı olmalı. Altın veri: test/golden/rng_golden.json
import 'package:arrowtile/core/rng.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final Map<String, dynamic> g = golden('rng_golden.json') as Map<String, dynamic>;

  group('Rng (mulberry32 türevi)', () {
    for (final dynamic item in (g['rng'] as List<dynamic>)) {
      final int seed = (item as Map<String, dynamic>)['seed'] as int;
      test('tohum $seed: ilk 64 değer JS ile aynı', () {
        final Rng r = Rng(seed);
        final List<dynamic> expected = item['values'] as List<dynamic>;
        for (int i = 0; i < expected.length; i++) {
          final double v = r.next();
          expect(v, equals((expected[i] as num).toDouble()), reason: 'tohum $seed, #$i');
        }
      });
    }
  });

  group('fnv32 (JS hash)', () {
    for (final dynamic item in (g['hash'] as List<dynamic>)) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      test('"${m['s']}"', () => expect(fnv32(m['s'] as String), equals(m['h'] as int)));
    }
  });

  test('imul: JS Math.imul örnekleri (Node ile hesaplandı)', () {
    const List<List<int>> cases = <List<int>>[
      <int>[4294967295, 5, -5],
      <int>[2147483647, 2, -2],
      <int>[16777619, 2166136261, 84696351],
      <int>[1831565813, -7, 63941197],
      <int>[-2147483648, -1, -2147483648],
      <int>[123456789, 987654321, -67153019],
      <int>[4294967295, 4294967295, 1],
    ];
    for (final List<int> c in cases) {
      expect(imul(c[0], c[1]), equals(c[2]), reason: 'imul(${c[0]}, ${c[1]})');
    }
  });
}
