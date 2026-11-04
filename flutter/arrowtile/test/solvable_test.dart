// 216 hazır seviyenin tamamı: yapı (komşu hücreler, sınır, çakışma yok, baş kendi gövdesine bakmaz), çözülebilirlik,
// par = ok sayısı, kademe = bölüm kademesi. Kaynak: lib/data/levels.json (tools/flutter/export-levels.js).
import 'dart:convert';
import 'dart:io';

import 'package:arrowtile/core/engine.dart';
import 'package:arrowtile/core/levelgen.dart';
import 'package:arrowtile/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<dynamic> raw = jsonDecode(File('lib/data/levels.json').readAsStringSync()) as List<dynamic>;
  final List<Level> levels = <Level>[for (final dynamic j in raw) Level.fromJson(j as Map<String, dynamic>)];

  test('216 seviye var, kimlikler 1..216', () {
    expect(levels.length, 216);
    for (int i = 0; i < levels.length; i++) {
      expect(levels[i].id, i + 1);
    }
  });

  test('hepsi yapısal olarak geçerli ve çözülebilir', () {
    final List<String> bad = <String>[];
    for (final Level lv in levels) {
      final Set<int> seen = <int>{};
      bool ok = lv.par == lv.arrows.length && lv.diff == tierOf(chapterOf(lv.id));
      for (final Arrow a in lv.arrows) {
        for (int k = 0; k < a.cells.length; k++) {
          final List<int> c = a.cells[k];
          if (c[0] < 0 || c[1] < 0 || c[0] >= lv.w || c[1] >= lv.h) ok = false;
          if (!seen.add(c[1] * lv.w + c[0])) ok = false; // çakışma
          if (k > 0 && (c[0] - a.cells[k - 1][0]).abs() + (c[1] - a.cells[k - 1][1]).abs() != 1) ok = false; // komşuluk
        }
        if (!ownLineOk(a.cells, a.dir, lv.w, lv.h)) ok = false;
      }
      if (!solve(lv).solvable) ok = false;
      if (!ok) bad.add('${lv.id}');
    }
    expect(bad, isEmpty, reason: 'geçersiz seviyeler: ${bad.join(',')}');
  });

  test('hazır seviyelerde ipucu her zaman çıkabilen bir oku gösterir ve ipuçlarıyla seviye 3 yıldızla biter', () {
    for (final Level lv in levels.where((Level l) => l.id % 9 == 1)) {
      final Game g = Game(lv);
      int guard = 0;
      while (!g.isWon && guard++ < 1000) {
        final int h = g.hint();
        expect(h, greaterThanOrEqualTo(0), reason: 'seviye ${lv.id}');
        expect(g.canExit(h), isTrue, reason: 'seviye ${lv.id}');
        g.tap(h);
      }
      expect(g.isWon, isTrue, reason: 'seviye ${lv.id}');
      expect(g.stars(), 3, reason: 'seviye ${lv.id}');
      expect(g.taps, lv.par, reason: 'seviye ${lv.id}');
    }
  });
}
