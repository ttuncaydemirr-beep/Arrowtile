// Motor: engine.js ile aynı çözüm sırası, ipucu, renklendirme ve dokunuş sonuçları (test/golden/engine_golden.json).
import 'package:arrowtile/core/engine.dart';
import 'package:arrowtile/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

List<int> ints(dynamic l) => <int>[for (final dynamic x in (l as List<dynamic>)) x as int];

/// make-goldens.js içindeki run() ile aynı politikalar.
Map<String, dynamic> run(Level level, {bool relaxed = false, bool noLifeLoss = false, required String policy}) {
  final Game g = Game(level, relaxed: relaxed, noLifeLoss: noLifeLoss);
  final List<Map<String, dynamic>> steps = <Map<String, dynamic>>[];
  for (int n = 0; n < 600 && !g.isWon && !g.isDead; n++) {
    int i;
    if (policy == 'lowest') {
      i = g.alive.indexOf(true);
    } else if (policy == 'hint') {
      i = g.hint();
    } else {
      i = (n % 4 == 3) ? g.hint() : g.alive.indexOf(true);
    }
    final TapResult? r = g.tap(i);
    steps.add(<String, dynamic>{'i': i, 'r': r, 'remaining': g.remaining(), 'lives': g.lives, 'collisions': g.collisions});
  }
  Map<String, dynamic>? revived;
  if (g.isDead) {
    final bool ok = g.revive();
    revived = <String, dynamic>{'ok': ok, 'lives': g.lives, 'revived': g.revived};
  }
  return <String, dynamic>{
    'steps': steps,
    'won': g.isWon,
    'dead': g.isDead,
    'stars': g.stars(),
    'taps': g.taps,
    'lives': g.lives,
    'collisions': g.collisions,
    'revived': revived,
  };
}

void expectTap(TapResult? got, dynamic exp, String where) {
  if (exp == null) {
    expect(got, isNull, reason: where);
    return;
  }
  final Map<String, dynamic> e = exp as Map<String, dynamic>;
  expect(got, isNotNull, reason: where);
  expect(got!.type, e['type'], reason: where);
  expect(got.i, e['i'], reason: where);
  if (e['type'] == 'exit') {
    expect(got.steps, e['steps'], reason: where);
    expect(got.won, e['won'], reason: where);
  } else {
    expect(got.free, e['free'], reason: where);
    expect(got.blocker, e['blocker'], reason: where);
    expect(got.lifeLost, e['lifeLost'], reason: where);
    expect(got.dead, e['dead'], reason: where);
  }
}

void main() {
  final List<dynamic> scen = golden('engine_golden.json') as List<dynamic>;
  for (final dynamic s in scen) {
    final Map<String, dynamic> m = s as Map<String, dynamic>;
    final Map<String, dynamic> lj = m['level'] as Map<String, dynamic>;
    final Level level = Level.fromJson(lj);
    group('seviye ${level.id} (${level.w}x${level.h}, ${level.arrows.length} ok)', () {
      test('solve / hint / serbest oklar / ızgara / renk', () {
        final SolveResult sol = solve(level);
        final Map<String, dynamic> es = m['solve'] as Map<String, dynamic>;
        expect(sol.solvable, es['solvable']);
        expect(sol.order, ints(es['order']));
        expect(sol.layers, es['layers']);
        final Game g0 = Game(level);
        expect(g0.hint(), m['hint0']);
        expect(g0.freeArrows(), ints(m['free0']));
        expect(colorize(level, 5), ints(m['colors5']));
        expect(colorize(level, 3), ints(m['colors3']));
        expect(buildGrid(level, List<bool>.filled(level.arrows.length, true)), ints(m['grid0']));
      });
      final Map<String, dynamic> runs = m['runs'] as Map<String, dynamic>;
      final Map<String, Map<String, dynamic> Function()> variants = <String, Map<String, dynamic> Function()>{
        'lowest': () => run(level, policy: 'lowest'),
        'lowestRelaxed': () => run(level, relaxed: true, policy: 'lowest'),
        'lowestTutorial': () => run(level, noLifeLoss: true, policy: 'lowest'),
        'hint': () => run(level, policy: 'hint'),
        'mixed': () => run(level, policy: 'mixed'),
      };
      variants.forEach((String name, Map<String, dynamic> Function() fn) {
        test('oyun: $name', () {
          final Map<String, dynamic> got = fn();
          final Map<String, dynamic> exp = runs[name] as Map<String, dynamic>;
          final List<dynamic> es = exp['steps'] as List<dynamic>;
          final List<Map<String, dynamic>> gs = got['steps'] as List<Map<String, dynamic>>;
          expect(gs.length, es.length);
          for (int k = 0; k < es.length; k++) {
            final Map<String, dynamic> e = es[k] as Map<String, dynamic>;
            expect(gs[k]['i'], e['i'], reason: 'adım $k');
            expectTap(gs[k]['r'] as TapResult?, e['r'], 'adım $k');
            expect(gs[k]['remaining'], e['remaining'], reason: 'adım $k');
            expect(gs[k]['lives'], e['lives'], reason: 'adım $k');
            expect(gs[k]['collisions'], e['collisions'], reason: 'adım $k');
          }
          for (final String k in <String>['won', 'dead', 'stars', 'taps', 'lives', 'collisions']) {
            expect(got[k], exp[k], reason: k);
          }
          expect(got['revived'], exp['revived']);
        });
      });
    });
  }

  test('rewardFor', () {
    expect(<int>[rewardFor(0), rewardFor(1), rewardFor(2), rewardFor(3), rewardFor(4)], <int>[0, 10, 15, 20, 0]);
  });
}
