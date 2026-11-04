// Günlük bulmaca (5 tarih altın) + tarih yardımcıları + seri/kupa kuralları.
import 'package:arrowtile/core/daily.dart';
import 'package:arrowtile/core/levelgen.dart';
import 'package:arrowtile/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final Map<String, dynamic> g = golden('daily_golden.json') as Map<String, dynamic>;

  group('günlük bulmaca (altın)', () {
    for (final dynamic item in (g['puzzles'] as List<dynamic>)) {
      final Map<String, dynamic> m = item as Map<String, dynamic>;
      final String date = m['date'] as String;
      test('$date (gün ${m['weekday']})', () {
        expect(weekdayIndex(date), m['weekday']);
        final Level? p = puzzleFor(date);
        expect(p, isNotNull);
        final Map<String, dynamic> e = m['puzzle'] as Map<String, dynamic>;
        expect(p!.daily, date);
        expect(p.id, 0);
        expect(p.w, e['w']);
        expect(p.h, e['h']);
        expect(p.diff, e['diff']);
        expect(p.ok, e['ok']);
        expect(p.par, e['par']);
        final String? diff = firstArrowDiff(p.arrows, arrowsFromJson(e['arrows']));
        expect(diff, isNull, reason: 'ilk fark: $diff');
        expect(measure(LgBoard(p.w, p.h, p.arrows)).solvable, isTrue);
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });

  test('diffDays / addDays', () {
    for (final dynamic x in (g['dd'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      expect(diffDays(m['a'] as String, m['b'] as String), m['diff']);
    }
    for (final dynamic x in (g['add'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      expect(addDays(m['d'] as String, m['n'] as int), m['r']);
    }
  });

  test('seri / kupa senaryosu (recordSolve) JS ile aynı', () {
    final DailyProgress dp = DailyProgress();
    for (final dynamic x in (g['steps'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      final SolveRecord r = recordSolve(dp, m['d'] as String, m['st'] as int);
      final Map<String, dynamic> er = m['r'] as Map<String, dynamic>;
      expect(r.first, er['first'] ?? false, reason: m['d'] as String);
      expect(r.clockBack, er['clockBack'] ?? false, reason: m['d'] as String);
      expect(r.streak, er['streak'], reason: m['d'] as String);
      final Map<String, dynamic> edp = m['dp'] as Map<String, dynamic>;
      expect(dp.streak, edp['streak'] ?? 0);
      expect(dp.best, edp['best'] ?? 0);
      expect(dp.trophies, edp['trophies'] ?? 0);
      expect(dp.last, edp['last']);
      expect(dp.done, equals(<String, int>{for (final MapEntry<String, dynamic> e in (edp['done'] as Map<String, dynamic>).entries) e.key: e.value as int}));
    }
    for (final dynamic x in (g['info'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      final StreakInfo s = streakInfo(dp, m['today'] as String);
      final Map<String, dynamic> e = m['info'] as Map<String, dynamic>;
      expect(s.current, e['current']);
      expect(s.best, e['best']);
      expect(s.trophies, e['trophies']);
      expect(s.doneToday, e['doneToday']);
    }
  });

  test('kademe planı: Pzt–Çar easy, Per–Cum medium, Cmt hard, Paz extreme', () {
    expect(kDailyPlan, <String>['easy', 'easy', 'easy', 'medium', 'medium', 'hard', 'extreme']);
    expect(weekdayIndex('2026-10-26'), 0);
    expect(weekdayIndex('2026-11-01'), 6);
  });
}
