// 1.2.1 (docs/27 §B3): renk tek başına anlam taşımaz — kazanılmamış yıldız içi boş çerçeve, kademe noktası şekille ayrılır,
// seçili sekme/seçenek alt çizgiyle işaretli.
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/screens/map_screen.dart';
import 'package:arrowtile/ui/screens/shop_screen.dart';
import 'package:arrowtile/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

Future<AppController> _boot(WidgetTester t, Widget home) async {
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
  app.save.lang = 'en';
  app.save.unlocked = 4;
  app.save.stars[1] = 3;
  app.save.stars[2] = 1;
  app.save.stars[3] = 2;
  await t.pumpWidget(AppScope(
    controller: app,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  ));
  await t.pump(const Duration(milliseconds: 300));
  return app;
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('yıldız satırı: kazanılan dolu, kazanılmayan içi boş (şekil) + "n/3" etiketi', (WidgetTester t) async {
    await _boot(t, const Scaffold(body: Center(child: StarsRow(filled: 1))));
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    expect(find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == '1/3 stars'), findsOneWidget);
    await _end(t);
  });

  testWidgets('harita: kademe noktası şekille ayrılır (Zor baklava, Orta kare, Kolay/Aşırı zor daire)', (WidgetTester t) async {
    await _boot(t, const MapScreen());
    for (final String tier in <String>['easy', 'medium', 'hard', 'extreme']) {
      expect(find.byKey(ValueKey<String>('tier-dot-$tier')), findsWidgets, reason: tier);
    }
    final Container medium = t.widget<Container>(find.byKey(const ValueKey<String>('tier-dot-medium')).first);
    expect((medium.decoration! as BoxDecoration).shape, BoxShape.rectangle);
    final Container easy = t.widget<Container>(find.byKey(const ValueKey<String>('tier-dot-easy')).first);
    expect((easy.decoration! as BoxDecoration).shape, BoxShape.circle);
    expect(find.ancestor(of: find.byKey(const ValueKey<String>('tier-dot-hard')).first, matching: find.byType(Transform)), findsWidgets);
    // kilitli düğüm kilit simgesiyle (renk dışında)
    expect(find.byIcon(Icons.lock), findsWidgets);
    await _end(t);
  });

  testWidgets('mağaza: seçili sekme alt çizgiyle işaretli (yalnızca zemin rengi değil)', (WidgetTester t) async {
    await _boot(t, const ShopScreen());
    expect(find.byKey(const ValueKey<String>('selected-mark')), findsOneWidget);
    await _end(t);
  });
}
