// Arrowtile — app.dart: MaterialApp (dil, açık/koyu tema, RTL, toast katmanı, yaşam döngüsü).
import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/ads_config.dart';
import 'core/diag.dart';
import 'l10n/app_localizations.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'ui/flow.dart' show startLevel;
import 'ui/screens/menu_screen.dart';
import 'ui/tokens.dart';

class ArrowtileApp extends StatefulWidget {
  final AppController controller;
  const ArrowtileApp({super.key, required this.controller});
  @override
  State<ArrowtileApp> createState() => _ArrowtileAppState();
}

class _ArrowtileAppState extends State<ArrowtileApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ilk kare çizildikten sonra: ses, satın alma, onay formu (UMP), reklamlar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.startServices();
      // docs/18: AUTOPLAY_FROM tanımlıysa (yalnızca debug) o seviyeyi kendiliğinden aç
      if (AdsConfig.autoPlayFrom > 0 && !kReleaseMode) {
        final BuildContext? c = widget.controller.navKey.currentContext;
        if (c != null) unawaited(startLevel(c, AdsConfig.autoPlayFrom));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    diag('app', 'lifecycle', <String, Object?>{'state': state.name});
    if (state == AppLifecycleState.resumed) widget.controller.onAppResumed();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) widget.controller.onAppBackgrounded();
    if (state == AppLifecycleState.inactive) widget.controller.onAppInactive();
  }

  ThemeData _theme(Palette p) {
    final Brightness b = p.dark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: kAppFont, // 1.2.0: Readex Pro (pakette, OFL 1.1)
      scaffoldBackgroundColor: p.bgC,
      canvasColor: p.bgC,
      colorScheme: ColorScheme.fromSeed(seedColor: p.accentC, brightness: b).copyWith(surface: p.boardC, primary: p.accentC),
      splashFactory: NoSplash.splashFactory,
      textSelectionTheme: TextSelectionThemeData(cursorColor: p.accentC),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: Builder(builder: (BuildContext ctx) {
        final AppController app = AppScope.of(ctx);
        // 1.2.2 (Madde 9): yüksek kontrast — oyuncu seçmediyse (null) cihazın erişilebilirlik ayarı
        final bool hcTheme = app.save.highContrast ?? WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.highContrast;
        return MaterialApp(
          navigatorKey: app.navKey,
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (BuildContext c) => AppLocalizations.of(c).appName,
          locale: Locale(app.lang), // uygulama içi dil seçimi; cihaz dilinden bağımsız
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: app.save.appearance == 'light'
              ? ThemeMode.light
              : (app.save.appearance == 'dark' ? ThemeMode.dark : ThemeMode.system),
          theme: _theme(Palette.select(Brightness.light, highContrast: hcTheme)),
          darkTheme: _theme(Palette.select(Brightness.dark, highContrast: hcTheme)),
          builder: (BuildContext c, Widget? child) {
            final MediaQueryData mq = MediaQuery.of(c);
            // Arapça glifler aynı boyutta daha küçük görünür: yazı ölçeği 1,08 (theme.js scaleByLang) ve satır yüksekliği 1,55
            final double scale = mq.textScaler.scale(1.0) * (app.lang == 'ar' ? 1.08 : 1.0);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(scale)),
              child: PaletteScope(
                brightness: Theme.of(c).brightness,
                highContrast: app.save.highContrast ?? mq.highContrast,
                child: DefaultTextStyle.merge(
                  style: TextStyle(height: app.lang == 'ar' ? 1.55 : 1.3),
                  child: Stack(children: <Widget>[
                    if (child != null) Positioned.fill(child: child),
                    const _ToastLayer(),
                  ]),
                ),
              ),
            );
          },
          home: const MenuScreen(),
        );
      }),
    );
  }
}

/// Alt kısımda kısa süre görünen bildirim (CSS .toast).
class _ToastLayer extends StatelessWidget {
  const _ToastLayer();
  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final Palette pal = Palette.of(context);
    final String? text = app.toastText;
    final double bottom = 110 + MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: text == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: pal.inkC, borderRadius: BorderRadius.circular(14)),
                child: Text(text ?? '',
                    textAlign: TextAlign.center, style: TextStyle(color: pal.bgC, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
