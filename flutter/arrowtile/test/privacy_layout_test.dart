// 1.2.4: gizlilik ekranı taşma testi — uzun Almanca ve Arapça (RTL) metin, küçük telefon ekranı ve büyük yazı boyutu.
// Yeni onay cümlesi (privacyPAnalytics sonu) ekranda kaydırılarak görünür olmalı; hiçbir "overflowed" hatası olmamalı.
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/screens/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

/// Yeni onay cümlesinden her dilde ayırt edici bir parça (Sohbet'in 1.2.4 metni).
const Map<String, String> _consent = <String, String>{
  'tr': 'reklamlar ise onay formunda seçimini yaptıktan sonra başlar',
  'en': 'ads start after you make your choice in the consent form',
  'de': 'Werbung startet, nachdem du im Einwilligungsformular deine Wahl getroffen hast',
  'ar': 'أما الإعلانات فتبدأ بعد أن تحدد اختيارك في نموذج الموافقة',
};

void main() {
  test('ARB: yeni onay cümlesi 4 dilde var, eski "yalnızca onay verirsen başlar" (reklamlar dahil) ifadesi yok', () {
    for (final String lang in _consent.keys) {
      final String an = lookupAppLocalizations(Locale(lang)).privacyPAnalytics;
      expect(an, contains(_consent[lang]!), reason: lang);
    }
    expect(lookupAppLocalizations(const Locale('tr')).privacyPAnalytics, isNot(contains('Analytics ve reklamlar ise')));
    expect(lookupAppLocalizations(const Locale('en')).privacyPAnalytics, isNot(contains('Analytics and ads wait')));
  });

  for (final String lang in <String>['de', 'ar', 'tr', 'en']) {
    for (final Size size in <Size>[const Size(320, 568), const Size(360, 640)]) {
      testWidgets('gizlilik ekranı $lang ${size.width.toInt()}x${size.height.toInt()} yazı 1.3×: taşma yok, onay cümlesi görünür',
          (WidgetTester t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        final List<String> overflows = <String>[];
        final void Function(FlutterErrorDetails)? prev = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails d) {
          if (d.exceptionAsString().contains('overflowed')) {
            overflows.add(d.exceptionAsString().split('\n').first);
            return;
          }
          prev?.call(d);
        };
        addTearDown(() => FlutterError.onError = prev);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final AppController app = (await t.runAsync(() => AppController.create(adsPlatform: FakePlatform())))!;
        app.save.lang = lang;
        await t.pumpWidget(AppScope(
          controller: app,
          child: MaterialApp(
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (BuildContext c, Widget? child) =>
                MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
            home: const PrivacyScreen(),
          ),
        ));
        await t.pump(const Duration(milliseconds: 300));
        if (lang == 'ar') {
          expect(Directionality.of(t.element(find.byType(PrivacyScreen))), TextDirection.rtl);
        }
        final Finder sentence = find.textContaining(_consent[lang]!, findRichText: true);
        await t.scrollUntilVisible(sentence, 300, scrollable: find.byType(Scrollable).first);
        await t.pump();
        expect(sentence, findsOneWidget);
        expect(overflows, isEmpty, reason: overflows.join('\n'));
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(seconds: 5));
      });
    }
  }
}
