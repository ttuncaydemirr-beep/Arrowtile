// Bölüm adları (docs/15 §5): mevcut 18 ad döngüyle + Roma rakamı ("Mağara II"), dört dilde; Arapçada rakam LRI/PDI ile yalıtılır.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/l10n/l10n_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roman()', () {
    const Map<int, String> want = <int, String>{1: 'I', 2: 'II', 3: 'III', 4: 'IV', 9: 'IX', 14: 'XIV', 28: 'XXVIII', 40: 'XL', 90: 'XC', 556: 'DLVI', 1994: 'MCMXCIV'};
    want.forEach((int n, String r) => expect(roman(n), r));
  });

  for (final String lang in <String>['tr', 'en', 'de', 'ar']) {
    test('chapterName: 18 ad döngü + Roma rakamı ($lang)', () async {
      final Map<String, dynamic> arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
      final AppLocalizations loc = await AppLocalizations.delegate.load(Locale(lang));
      for (final int c in <int>[1, 2, 17, 18, 19, 20, 36, 37, 54, 55, 500, 501, 10000]) {
        final String base = arb['mapChapter${(c - 1) % 18 + 1}'] as String;
        final int cyc = (c - 1) ~/ 18 + 1;
        final String want = cyc > 1 ? '$base \u2066${roman(cyc)}\u2069' : base;
        expect(chapterName(loc, c), want, reason: 'bölüm $c');
      }
      expect(chapterName(loc, 18).contains('\u2066'), isFalse); // ilk turda rakam yok
      expect(chapterName(loc, 19).endsWith('II\u2069'), isTrue);
      expect(chapterName(loc, 1) != chapterName(loc, 2), isTrue);
    });
  }
}
