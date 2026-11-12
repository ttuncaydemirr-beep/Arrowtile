// 1.2.1 (docs/27 §B2): kullanıcıya görünen yerelleştirilmiş metinlerde büyük/küçük harf dönüşümü YOK.
// Dart'ın toUpperCase()/toLowerCase() ve JS'in toUpperCase()/toLowerCase() Türkçe i/İ ve ı/I'yı yanlış çevirir ("ipucu" → "IPUCU").
// Denetim: (1) Dart (lib/) ve web (game/js, game/css) kaynağında dönüşüm yalnızca dil KODLARINDA (ASCII) kullanılabilir;
// (2) tr dilinde ekranlar ARB metnini harfi harfine gösterir (İ/ı korunur).
import 'dart:io';

import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/screens/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

final RegExp _caseCall = RegExp(r'toUpperCase|toLowerCase|toLocaleUpperCase|toLocaleLowerCase|text-transform\s*:\s*(uppercase|lowercase|capitalize)');
// izin verilen: dil kodu normalleştirme (ASCII "TR" → "tr"), kullanıcıya görünmez
final RegExp _allowed = RegExp(r'languageCode|navigator\.language');

List<File> _files(String dir, List<String> exts) {
  final Directory d = Directory(dir);
  if (!d.existsSync()) return <File>[];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => exts.any((String e) => f.path.endsWith(e)) && !f.path.contains('/l10n/app_localizations'))
      .toList();
}

void main() {
  test('kaynakta yerelleştirilmiş metne harf dönüşümü yok (Dart + web)', () {
    final List<File> files = <File>[
      ..._files('lib', <String>['.dart']),
      ..._files('../../game/js', <String>['.js']),
      ..._files('../../game/css', <String>['.css']),
    ];
    expect(files.length, greaterThan(20), reason: 'kaynak dosyalar bulunamadı');
    final List<String> bad = <String>[];
    for (final File f in files) {
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (_caseCall.hasMatch(lines[i]) && !_allowed.hasMatch(lines[i])) bad.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(bad, isEmpty, reason: 'Türkçe i/İ, ı/I bozulur — dönüşümü kaldırın:\n${bad.join('\n')}');
  });

  test('tr metinlerinde İ / ı içeren anahtarlar var ve ARB değeri kendisi büyük/küçük harf biçimini taşır', () {
    final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));
    // Örnek: "İpucu" büyük noktalı İ ile, "Ayarlar" / "Mağaza" olduğu gibi
    expect(tr.gameHint, startsWith('İ'));
    expect(tr.gameHint.contains('I'), isFalse, reason: 'noktasız büyük I olmamalı: ${tr.gameHint}');
  });

  testWidgets('tr menüsü metinleri harfi harfine gösterir (dönüşüm yok)', (WidgetTester t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final void Function(FlutterErrorDetails)? prev = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppController app = (await t.runAsync(() => AppController.create(adsPlatform: FakePlatform())))!;
    app.save.lang = 'tr';
    await t.pumpWidget(AppScope(
      controller: app,
      child: const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MenuScreen(),
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));
    for (final String s in <String>[tr.menuPlay, tr.menuMap, tr.menuShop, tr.dpMenu, tr.menuDaily]) {
      expect(find.text(s), findsOneWidget, reason: s);
      expect(find.text(s.toUpperCase()), s == s.toUpperCase() ? findsOneWidget : findsNothing);
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 5));
  });
}
