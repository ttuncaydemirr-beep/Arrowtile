// Arrowtile — l10n_lookup.dart: anahtarı çalışma anında belirlenen metinler (bölüm adı, kademe, tema adı).
// Doğrudan getter'lar app_localizations.dart (flutter gen-l10n çıktısı) içindedir; burada yalnızca dinamik aramalar vardır.
import 'app_localizations.dart';

/// Roma rakamı (1..3999; bölüm sayısı bunun çok altındadır). main.js roman() ile aynı.
String roman(int n) {
  const List<(int, String)> m = <(int, String)>[
    (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'), (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'),
  ];
  final StringBuffer r = StringBuffer();
  for (final (int v, String sym) in m) {
    while (n >= v) {
      r.write(sym);
      n -= v;
    }
  }
  return r.toString();
}

/// Bölüm adı: mevcut 18 ad döngüyle; tekrarlarda Roma rakamı ("Mağara II"). Rakam Arapçada da Latin harfle,
/// soldan sağa yalıtılır (U+2066 LRI … U+2069 PDI; main.js chapterName ile aynı).
String chapterName(AppLocalizations loc, int c) {
  final int cyc = (c - 1) ~/ 18 + 1;
  final String name = _baseChapterName(loc, (c - 1) % 18 + 1);
  return cyc > 1 ? '$name \u2066${roman(cyc)}\u2069' : name;
}

String _baseChapterName(AppLocalizations loc, int n) {
  switch (n) {
    case 1:
      return loc.mapChapter1;
    case 2:
      return loc.mapChapter2;
    case 3:
      return loc.mapChapter3;
    case 4:
      return loc.mapChapter4;
    case 5:
      return loc.mapChapter5;
    case 6:
      return loc.mapChapter6;
    case 7:
      return loc.mapChapter7;
    case 8:
      return loc.mapChapter8;
    case 9:
      return loc.mapChapter9;
    case 10:
      return loc.mapChapter10;
    case 11:
      return loc.mapChapter11;
    case 12:
      return loc.mapChapter12;
    case 13:
      return loc.mapChapter13;
    case 14:
      return loc.mapChapter14;
    case 15:
      return loc.mapChapter15;
    case 16:
      return loc.mapChapter16;
    case 17:
      return loc.mapChapter17;
    default:
      return loc.mapChapter18;
  }
}

/// Kademe etiketi: easy | medium | hard | extreme.
String diffName(AppLocalizations loc, String tier) {
  switch (tier) {
    case 'easy':
      return loc.diffEasy;
    case 'medium':
      return loc.diffMedium;
    case 'hard':
      return loc.diffHard;
    default:
      return loc.diffExtreme;
  }
}

/// Ok teması adı.
String themeName(AppLocalizations loc, String id) {
  switch (id) {
    case 'lokum':
      return loc.themeLokum;
    case 'cini':
      return loc.themeCini;
    case 'bakir':
      return loc.themeBakir;
    case 'gece':
      return loc.themeGece;
    default:
      return loc.themeEmaye;
  }
}

/// Dil seçicide her dil kendi adıyla (endonim) görünür.
String langEndonym(AppLocalizations loc, String l) {
  switch (l) {
    case 'tr':
      return loc.langTr;
    case 'de':
      return loc.langDe;
    case 'ar':
      return loc.langAr;
    default:
      return loc.langEn;
  }
}
