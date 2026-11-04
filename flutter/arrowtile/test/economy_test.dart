// Ekonomi, günlük ödül, bölüm bonusu, yardımcı harcama, kayıt onarımı/göçü ve yedek kodu — storage.js altın verisiyle.
import 'dart:convert';

import 'package:arrowtile/core/economy.dart';
import 'package:arrowtile/core/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// SaveData → düz JSON (altın dosyadaki JSON.stringify(state) ile karşılaştırılabilir biçim).
dynamic plain(SaveData s) => jsonDecode(jsonEncode(s.toJson()));

void main() {
  final Map<String, dynamic> g = golden('economy_golden.json') as Map<String, dynamic>;

  test('levelReward tablosu (kademe çarpanlı) ve bölüm bonusları', () {
    for (final dynamic x in (g['rewards'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      expect(levelReward(m['id'] as int, m['st'] as int), m['r'], reason: 'seviye ${m['id']} yıldız ${m['st']}');
    }
    for (final dynamic x in (g['tiers'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      expect(tierOfChapterId(m['c'] as int), m['tier']);
      expect(chapterBonusFor(m['c'] as int), m['bonus']);
    }
  });

  test('completeLevel dizisi: jeton farkı, rahat mod yarısı, bölüm bonusu, kilit açma', () {
    final SaveData s = SaveData.defaults('en');
    for (final dynamic x in (g['complete'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      final CompleteResult r = completeLevel(s, m['id'] as int, m['st'] as int, m['rl'] as bool);
      final Map<String, dynamic> er = m['r'] as Map<String, dynamic>;
      final String w = 'seviye ${m['id']} yıldız ${m['st']} rahat ${m['rl']}';
      expect(r.coins, er['coins'], reason: w);
      expect(r.newBest, er['newBest'], reason: w);
      expect(r.firstClear, er['firstClear'], reason: w);
      expect(r.bonus, er['bonus'], reason: w);
      expect(r.chapterDone, er['chapterDone'], reason: w);
      expect(plain(s), equals(m['s']), reason: w);
      expect(totalStars(s), m['total'], reason: w);
    }
  });

  test('günlük ödül: durum + alma + seri kaybı + saat geri', () {
    final SaveData s = SaveData.defaults('en');
    for (final dynamic x in (g['daily'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      final String d = m['d'] as String;
      final DailyStatus st = dailyStatus(s, d);
      final Map<String, dynamic> es = m['st'] as Map<String, dynamic>;
      expect(st.canClaim, es['canClaim'], reason: d);
      expect(st.day, es['day'], reason: d);
      expect(st.claimedToday, es['claimedToday'] ?? false, reason: d);
      expect(st.streakLost, es['streakLost'] ?? false, reason: d);
      expect(st.clockBack, es['clockBack'] ?? false, reason: d);
      final ClaimResult? r = claimDaily(s, d);
      final dynamic er = m['r'];
      if (er == null) {
        expect(r, isNull, reason: d);
      } else {
        expect(r!.day, (er as Map<String, dynamic>)['day'], reason: d);
        expect(r.coins, er['coins'], reason: d);
        expect(r.hint, er['hint'], reason: d);
      }
      expect(plain(s)['daily'], equals(m['daily']), reason: d);
      expect(s.coins, m['coins'], reason: d);
      expect(s.freeHints, m['freeHints'], reason: d);
    }
  });

  test('ipucu harcama / iade', () {
    final SaveData s = SaveData.defaults('en');
    final List<dynamic> steps = g['spend'] as List<dynamic>;
    int k = 0;
    for (int i = 0; i < 6; i++) {
      final Map<String, dynamic> m = steps[k++] as Map<String, dynamic>;
      expect(spendHint(s), m['ok'], reason: 'adım ${k - 1}');
      expect(s.coins, m['coins']);
      expect(s.freeHints, m['freeHints']);
    }
    s.coins = 120;
    for (int i = 0; i < 3; i++) {
      final Map<String, dynamic> m = steps[k++] as Map<String, dynamic>;
      expect(spendHint(s), m['ok'], reason: 'adım ${k - 1}');
      expect(s.coins, m['coins']);
      expect(s.freeHints, m['freeHints']);
    }
    refundHint(s, true);
    Map<String, dynamic> m = steps[k++] as Map<String, dynamic>;
    expect(s.coins, m['coins']);
    expect(s.freeHints, m['freeHints']);
    refundHint(s, false);
    m = steps[k++] as Map<String, dynamic>;
    expect(s.coins, m['coins']);
    expect(s.freeHints, m['freeHints']);
  });

  group('sanitize (bozuk veri onarımı + v1.2 freeUndos göçü)', () {
    final List<dynamic> cases = g['sanitize'] as List<dynamic>;
    for (int i = 0; i < cases.length; i++) {
      final Map<String, dynamic> m = cases[i] as Map<String, dynamic>;
      test('vaka #$i: ${jsonEncode(m['raw'])}', () {
        final SaveData s = sanitize(m['raw'], 'en');
        expect(plain(s), equals(m['state']));
      });
    }
  });

  test('yedek kodu: dışa aktarma JS ile birebir, geri okuma, bozuk kodlar', () {
    final Map<String, dynamic> b = g['backup'] as Map<String, dynamic>;
    final SaveData s = sanitize(b['state'], 'en');
    expect(plain(s), equals(b['state']), reason: 'durum round-trip');
    expect(exportCode(s), equals(b['code']));
    final SaveData? p = parseCode(b['code'] as String, 'en');
    expect(p, isNotNull);
    expect(plain(p!), equals(b['parsed']));
    for (final dynamic x in (b['bad'] as List<dynamic>)) {
      final Map<String, dynamic> m = x as Map<String, dynamic>;
      final SaveData? r = parseCode(m['code'] as String?, 'en');
      if (m['parsed'] == null) {
        expect(r, isNull, reason: '${m['code']}');
      } else {
        expect(plain(r!), equals(m['parsed']), reason: '${m['code']}');
      }
    }
  });

  test('importCode dil ve reklam durumunu korur; resetProgress dil + satın almayı korur', () {
    final SaveData cur = SaveData.defaults('de');
    cur.ads.adFree = true;
    cur.ads.since = 2;
    cur.coins = 999;
    final SaveData src = SaveData.defaults('en')..coins = 123;
    final SaveData? imp = importCode(cur, exportCode(src));
    expect(imp, isNotNull);
    expect(imp!.coins, 123);
    expect(imp.lang, 'de');
    expect(imp.ads.adFree, isTrue);
    expect(imp.ads.since, 2);
    expect(importCode(cur, 'bozuk'), isNull);
    final SaveData r = resetProgress(cur);
    expect(r.lang, 'de');
    expect(r.ads.adFree, isTrue);
    expect(r.coins, 50);
    expect(r.freeHints, 2);
  });
}
