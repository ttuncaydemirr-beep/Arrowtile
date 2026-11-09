// Arrowtile — flow.dart: gezinme yardımcıları (ekran geçişleri, seviye başlatma).
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/save_data.dart' show kMaxLevel;
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import 'screens/game_screen.dart';
import 'screens/map_screen.dart';
import 'tokens.dart';
import 'widgets.dart';

/// 200 ms solma geçişi (CSS .screen: opacity 200ms).
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) => page,
      transitionsBuilder: (BuildContext c, Animation<double> a, Animation<double> s, Widget child) =>
          FadeTransition(opacity: a, child: child),
    );

/// Seviyeyi başlatır. Sonsuz seviye henüz üretilmediyse "Seviye hazırlanıyor…" penceresi gösterilir.
/// [replace]: true ise mevcut oyun ekranının yerine geçer (Sonraki seviye / Tekrar oyna).
Future<void> startLevel(BuildContext context, int id, {bool replace = false}) async {
  final AppController app = AppScope.read(context);
  final NavigatorState nav = Navigator.of(context);
  Level? lv = app.getLevel(id);
  if (!replace) {
    // onay formu (UMP) sürüyorsa kısa süre bekle: form oyunun üstüne çıkmasın (replace: oyuncu zaten oyunda)
    await app.waitConsentIdle();
    if (!context.mounted) return;
  }
  if (lv == null) {
    if (id <= app.prebuilt.length || id > kMaxLevel) return;
    bool open = true;
    final AppLocalizations loc = AppLocalizations.of(context);
    unawaited(showSheet<void>(context, builder: (BuildContext ctx) {
      final Palette pal = Palette.of(ctx);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(loc.gamePreparing,
            textAlign: TextAlign.center, style: TextStyle(color: pal.inkC, fontSize: 17, fontWeight: FontWeight.w700)),
      );
    }).then((void _) => open = false));
    try {
      lv = await app.ensureLevel(id);
    } catch (_) {
      lv = null;
    }
    if (!open) return; // oyuncu pencereyi kapattı → başlatma iptal
    nav.pop(); // "hazırlanıyor" penceresini kapat
    if (lv == null) return;
  }
  final Route<void> r = fadeRoute<void>(GameScreen(level: lv));
  if (replace) {
    unawaited(nav.pushReplacement(r));
  } else {
    unawaited(nav.push(r));
  }
}

/// Oyundan haritaya dön: yığını menüye kadar boşalt, haritayı aç.
void goToMap(BuildContext context) {
  final NavigatorState nav = Navigator.of(context);
  nav.popUntil((Route<dynamic> r) => r.isFirst);
  unawaited(nav.push(fadeRoute<void>(const MapScreen())));
}

void goToMenu(BuildContext context) {
  Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
}

/// Günlük bulmacayı başlatır (id 0, tarih tohumlu). Reklam, harita ilerlemesi ve bölüm bonusu yoktur.
Future<void> startDaily(BuildContext context) async {
  final AppController app = AppScope.read(context);
  final NavigatorState nav = Navigator.of(context);
  final AppLocalizations loc = AppLocalizations.of(context);
  await app.waitConsentIdle();
  if (!context.mounted) return;
  bool open = true;
  unawaited(showSheet<void>(context, builder: (BuildContext ctx) {
    final Palette pal = Palette.of(ctx);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(loc.gamePreparing,
          textAlign: TextAlign.center, style: TextStyle(color: pal.inkC, fontSize: 17, fontWeight: FontWeight.w700)),
    );
  }).then((void _) => open = false));
  Level? lv;
  try {
    lv = await app.dailyLevel(app.today());
  } catch (_) {
    lv = null;
  }
  if (!open) return;
  nav.pop();
  if (lv == null) return;
  unawaited(nav.push(fadeRoute<void>(GameScreen(level: lv))));
}
