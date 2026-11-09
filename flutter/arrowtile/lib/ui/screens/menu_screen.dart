// Arrowtile — menu_screen.dart: ana menü (index.html #scr-menu).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ads_rules.dart' show AdScreen;
import '../../core/daily.dart' as daily;
import '../../core/economy.dart' as eco;
import '../../l10n/app_localizations.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../ad_banner.dart';
import '../flow.dart';
import '../tokens.dart';
import '../widgets.dart';
import 'daily_dialogs.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final bool anyProgress = app.save.stars.isNotEmpty;
    final eco.DailyStatus st = eco.dailyStatus(app.save, app.today());
    final daily.StreakInfo info = daily.streakInfo(app.save.dp, app.today());
    // "Devam" anında açılsın: sonsuz seviyeyi önceden üret
    if (app.save.unlocked > app.prebuilt.length) app.prefetchNext(app.save.unlocked - 1);

    return PopScope(
      canPop: true, // ana menüde geri tuşu uygulamadan çıkar
      child: ScreenScaffold(
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: const <Widget>[Spacer(), CoinPill()]),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Center(
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 6))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset('assets/images/icon.png', width: 132, height: 132, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4 + 10, 0, 10),
                    child: Text(loc.appName,
                        textAlign: TextAlign.center, style: TextStyle(color: pal.inkC, fontSize: 30, fontWeight: FontWeight.w800)),
                  ),
                  AppButton(anyProgress ? loc.menuContinue(app.save.unlocked) : loc.menuPlay,
                      kind: BtnKind.primary, big: true, onTap: () => unawaited(startLevel(context, app.save.unlocked))),
                  const SizedBox(height: 14),
                  Row(children: <Widget>[
                    Expanded(
                      child: AppButton(loc.menuMap,
                          icon: Icons.map_outlined,
                          onTap: () => Navigator.of(context).push(fadeRoute<void>(const MapScreen()))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(loc.menuShop,
                          icon: Icons.shopping_bag_outlined,
                          onTap: () => Navigator.of(context).push(fadeRoute<void>(const ShopScreen()))),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  AppButton(loc.dpMenu,
                      icon: Icons.calendar_month_outlined,
                      alignStart: true,
                      sub: info.doneToday ? loc.dpDone : loc.dpStreak(info.current),
                      subColor: info.doneToday ? pal.successC : pal.inkSoftC,
                      onTap: () => unawaited(openCalendar(context))),
                  const SizedBox(height: 14),
                  Stack(alignment: AlignmentDirectional.centerEnd, children: <Widget>[
                    AppButton(loc.menuDaily,
                        icon: Icons.card_giftcard,
                        iconColor: pal.dangerC,
                        alignStart: true,
                        sub: st.canClaim ? loc.menuDailyReady : null,
                        onTap: () => unawaited(openDailyReward(context))),
                    if (st.canClaim)
                      PositionedDirectional(
                        end: 14,
                        child: IgnorePointer(
                          child: Container(width: 14, height: 14, decoration: BoxDecoration(color: pal.dangerC, shape: BoxShape.circle)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  AppButton(loc.menuSettings,
                      kind: BtnKind.ghost,
                      icon: Icons.settings_outlined,
                      onTap: () => Navigator.of(context).push(fadeRoute<void>(const SettingsScreen()))),
                ]),
              ),
            ),
          ),
          // banner (docs/15 §3): yalnızca ana menü ve harita; reklamsızda / yüklenmediyse yer kaplamaz; içerik üstte kalır
          const AdBannerSlot(screen: AdScreen.menu),
        ]),
      ),
    );
  }
}
