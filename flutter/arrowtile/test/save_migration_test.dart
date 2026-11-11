// 1.2.0 kayıt göçü (docs/26 §C): bölüm 10 → 20 seviye. Seviye numaraları yıldız/jetonu korur; eski 10'luk bölüm bonusu anahtarları
// 20'lik bölümlerde ne ÇİFT ÖDEME yapar ne de başka bir bölümün bonusunu KİLİTLER. Göç bir kez (cbv = 20) uygulanır.
import 'dart:convert';

import 'package:arrowtile/core/economy.dart';
import 'package:arrowtile/core/levelgen.dart' show kChapterBonus;
import 'package:arrowtile/core/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1.1.x kaydı: cbv alanı yok, chapterBonus 10'luk bölüm numaraları.
Map<String, dynamic> oldSave({required List<int> bonus, required int starsUpTo, int coins = 1000}) => <String, dynamic>{
      'lang': 'tr',
      'coins': coins,
      'freeHints': 2,
      'stars': <String, int>{for (int i = 1; i <= starsUpTo; i++) '$i': 3},
      'unlocked': starsUpTo + 1,
      'chapterBonus': bonus,
      'tutorialDone': <int>[1, 2, 3],
    };

SaveData roundTrip(SaveData s) => sanitize(jsonDecode(jsonEncode(s.toJson())), 'tr');

void main() {
  test('yıldızlar, jeton ve kilit seviye numarasıyla korunur', () {
    final SaveData s = sanitize(oldSave(bonus: <int>[1, 2, 3], starsUpTo: 30, coins: 777), 'tr');
    expect(s.coins, 777);
    expect(s.freeHints, 2);
    expect(s.unlocked, 31);
    for (int i = 1; i <= 30; i++) {
      expect(s.stars[i], 3, reason: 'seviye $i');
    }
    expect(s.cbv, kChapterBonusVersion);
  });

  test('eski bölüm k → yeni bölüm ⌈k/2⌉ (tekrarsız, sıra korunur)', () {
    expect(sanitize(oldSave(bonus: <int>[1, 2, 3, 7], starsUpTo: 0), 'tr').chapterBonus, <int>[1, 2, 4]);
    expect(sanitize(<String, dynamic>{'chapterBonus': <int>[2], 'cbv': 10}, 'tr').chapterBonus, <int>[1]);
    expect(sanitize(<String, dynamic>{'chapterBonus': <int>[1, 2, 3], 'cbv': 20}, 'tr').chapterBonus, <int>[1, 2, 3]); // zaten 20'lik
  });

  test('çift ödeme yok: eski bölüm 1+2 bonusu alınmışsa yeni bölüm 1 tekrar ödenmez', () {
    final SaveData s = sanitize(oldSave(bonus: <int>[1, 2], starsUpTo: 19), 'tr');
    final int before = s.coins;
    final CompleteResult r = completeLevel(s, 20, 3, false); // 20 zaten 3 yıldız değil: ilk tamamlama
    expect(r.chapterDone, isFalse);
    expect(r.bonus, 0);
    expect(s.coins, before + r.coins);
  });

  test('çift ödeme yok: yalnızca eski bölüm 1 (seviye 1–10) ödenmişse yeni bölüm 1 de ödenmiş sayılır', () {
    final SaveData s = sanitize(oldSave(bonus: <int>[1], starsUpTo: 10), 'tr');
    expect(s.chapterBonus, <int>[1]);
    int bonus = 0;
    for (int id = 11; id <= 20; id++) {
      bonus += completeLevel(s, id, 3, false).bonus;
    }
    expect(bonus, 0);
  });

  test('kilitleme yok: eski "bölüm 3" (seviye 21–30) yeni bölüm 3’ü (41–60) engellemez', () {
    final SaveData s = sanitize(oldSave(bonus: <int>[1, 2, 3], starsUpTo: 30), 'tr');
    expect(s.chapterBonus, <int>[1, 2]);
    int bonus = 0;
    for (int id = 31; id <= 40; id++) {
      bonus += completeLevel(s, id, 3, false).bonus; // bölüm 2'nin ilk yarısı (21–30) için 150 zaten ödenmişti
    }
    expect(bonus, 0);
    CompleteResult? last;
    for (int id = 41; id <= 60; id++) {
      last = completeLevel(s, id, 2, false);
      if (id < 60) expect(last.bonus, 0);
    }
    expect(last!.chapterDone, isTrue);
    expect(last.bonus, kChapterBonus);
    expect(s.chapterBonus, <int>[1, 2, 3]);
  });

  test('göç bir kez: kaydedip yeniden yüklemek numaraları bir daha bölmez', () {
    final SaveData s = sanitize(oldSave(bonus: <int>[1, 2, 3, 4, 5, 6], starsUpTo: 60), 'tr');
    expect(s.chapterBonus, <int>[1, 2, 3]);
    final SaveData again = roundTrip(s);
    expect(again.chapterBonus, <int>[1, 2, 3]);
    expect(roundTrip(again).chapterBonus, <int>[1, 2, 3]);
    expect(jsonEncode(again.toJson()), jsonEncode(s.toJson()));
  });

  test('yedek kodu: eski (1.1.x) kod içe aktarılırken de göç uygulanır; yeni kod olduğu gibi taşınır', () {
    final SaveData oldState = sanitize(oldSave(bonus: <int>[1, 2, 3], starsUpTo: 30), 'tr');
    // 1.1.x kodu: cbv alanı yok, eski numaralar
    final Map<String, dynamic> o = oldState.toJson()
      ..remove('lang')
      ..remove('ads')
      ..remove('cbv');
    o['chapterBonus'] = <int>[1, 2, 3];
    final String body = base64Encode(utf8.encode(jsonEncode(o)));
    final String oldCode = '$kCodePrefix-$body-${fnvHex(body)}';
    final SaveData? imported = importCode(SaveData.defaults('tr'), oldCode);
    expect(imported, isNotNull);
    expect(imported!.chapterBonus, <int>[1, 2]);
    final SaveData? again = importCode(SaveData.defaults('tr'), exportCode(imported));
    expect(again!.chapterBonus, <int>[1, 2]);
  });

  test('yeni kayıt ve sıfırlama: cbv = 20, chapterBonus boş, ok rengi Renkli', () {
    final SaveData d = SaveData.defaults('tr');
    expect(d.cbv, 20);
    expect(d.chapterBonus, isEmpty);
    expect(d.arrowColor, 'color');
    expect(resetProgress(sanitize(oldSave(bonus: <int>[1, 2], starsUpTo: 20), 'tr')).chapterBonus, isEmpty);
    expect(sanitize(<String, dynamic>{'arrowColor': 'mono'}, 'tr').arrowColor, 'mono');
    expect(sanitize(<String, dynamic>{'arrowColor': 'pink'}, 'tr').arrowColor, 'color');
  });
}
