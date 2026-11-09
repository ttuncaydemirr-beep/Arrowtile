// Arka plana gidip dönme: duraklatma penceresi (docs/16). Web referansı: main.js visibilitychange.
//  - Arka planda pencere AÇILMAZ; öne gelince TEK pencere açılır, düğmeleri yanıt verir, Resume kapatır.
//  - Bayraklar her yolda sıfırlanır; tahta (CustomPaint) pencere kapandıktan sonra da çizilir.
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/board_painter.dart';
import 'package:arrowtile/ui/flow.dart';
import 'package:arrowtile/ui/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester t) async {
  for (int i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<AppController> _openGame(WidgetTester t, {int level = 5}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppController? made = await t.runAsync(AppController.create);
  final AppController app = made!;
  app.save.lang = 'en';
  await t.pumpWidget(AppScope(
    controller: app,
    child: MaterialApp(
      navigatorKey: app.navKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: SizedBox.expand()),
    ),
  ));
  app.navKey.currentState!.push(fadeRoute<void>(GameScreen(level: app.getLevel(level)!)));
  await _settle(t);
  expect(find.byType(GameScreen), findsOneWidget);
  return app;
}

void _life(WidgetTester t, List<AppLifecycleState> seq) {
  for (final AppLifecycleState s in seq) {
    t.binding.handleAppLifecycleStateChanged(s);
  }
}

const List<AppLifecycleState> _toBackground = <AppLifecycleState>[
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const List<AppLifecycleState> _toForeground = <AppLifecycleState>[
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

void main() {
  testWidgets('arka planda pencere açılmaz; öne gelince TEK "Paused" penceresi açılır', (WidgetTester t) async {
    await _openGame(t);
    expect(find.text('Paused'), findsNothing);

    _life(t, _toBackground);
    await _settle(t);
    expect(find.text('Paused'), findsNothing, reason: 'arka plandayken rota eklenmemeli');

    _life(t, _toForeground);
    await _settle(t);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Back to map'), findsOneWidget);
  });

  testWidgets('Resume pencereyi kapatır, bayraklar sıfırlanır, tahta çizilir, tekrar duraklatılabilir', (WidgetTester t) async {
    await _openGame(t);
    _life(t, _toBackground);
    _life(t, _toForeground);
    await _settle(t);
    expect(find.text('Paused'), findsOneWidget);

    await t.tap(find.text('Resume'));
    await _settle(t);
    expect(find.text('Paused'), findsNothing);
    final GameScreen gs = t.widget<GameScreen>(find.byType(GameScreen));
    expect(gs.level.id, 5);
    final dynamic st = t.state(find.byType(GameScreen));
    expect(st.pauseRequested, isFalse);
    // tahta boyayıcısı hâlâ ağaçta
    expect(find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is BoardPainter), findsOneWidget);

    // ikinci tur: yine tek pencere
    _life(t, _toBackground);
    _life(t, _toForeground);
    await _settle(t);
    expect(find.text('Paused'), findsOneWidget);
    await t.tap(find.text('Resume'));
    await _settle(t);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('pencere zaten açıkken arka plana gidip dönmek ikinci pencere/engel katmanı açmaz', (WidgetTester t) async {
    await _openGame(t);
    await t.tap(find.byIcon(Icons.pause));
    await _settle(t);
    expect(find.text('Paused'), findsOneWidget);

    for (int i = 0; i < 3; i++) {
      _life(t, _toBackground);
      await _settle(t);
      _life(t, _toForeground);
      await _settle(t);
    }
    expect(find.text('Paused'), findsOneWidget);
    await t.tap(find.text('Resume'));
    await _settle(t);
    expect(find.text('Paused'), findsNothing, reason: 'tek Resume ile tüm pencereler kapanmalı (üst üste ikinci pencere yok)');
  });

  testWidgets('yalnızca inactive (bildirim çubuğu, reklam/izin penceresi) duraklatmaz', (WidgetTester t) async {
    await _openGame(t);
    _life(t, <AppLifecycleState>[AppLifecycleState.inactive, AppLifecycleState.resumed]);
    await _settle(t);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('başka bir pencere açıkken arka plana gidip dönmek duraklatma penceresi eklemez', (WidgetTester t) async {
    final AppController app = await _openGame(t);
    final NavigatorState nav = app.navKey.currentState!;
    nav.push(DialogRoute<void>(context: nav.context, builder: (BuildContext c) => const Dialog(child: Text('Other sheet'))));
    await _settle(t);
    expect(find.text('Other sheet'), findsOneWidget);
    _life(t, _toBackground);
    _life(t, _toForeground);
    await _settle(t);
    expect(find.text('Paused'), findsNothing);
    expect(find.text('Other sheet'), findsOneWidget);
  });

  testWidgets('Restart pencereyi kapatır ve oyun yanıt verir durumda kalır', (WidgetTester t) async {
    await _openGame(t);
    _life(t, _toBackground);
    _life(t, _toForeground);
    await _settle(t);
    await t.tap(find.text('Restart'));
    await _settle(t);
    expect(find.text('Paused'), findsNothing);
    await t.tap(find.byIcon(Icons.pause));
    await _settle(t);
    expect(find.text('Paused'), findsOneWidget);
  });
}
