// Arrowtile — rewarded_flow.dart: ödüllü reklamın DOKUNUŞTAKİ akışı (yükleme kaplaması → reklam → bildirim).
// Düğmeler reklamın önceden yüklenmiş olmasına bağlı değildir; hazır değilse "Reklam yükleniyor…" penceresi açılır,
// Monetization.watchRewarded yüklemeyi başlatır. Reklam yoksa yerelleştirilmiş toast gösterilir; test kimlikli/debug
// derlemelerde AdMob hata kodu parantez içinde eklenir (neden yüklenmediğini görmek için).
// v1.1 (docs/15 §4): ödüllü reklam oyun açılınca / can 1'e düşünce önceden yüklenir; "Reklam yükleniyor…" penceresi yalnızca gerçekten
// bekleniyorsa ve bekleme [kLoadingOverlayDelay] (300 ms) süresini aşarsa görünür (hazır ya da çabuk gelen reklamda hiç açılmaz).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/ads_config.dart';
import '../core/ads_rules.dart';
import '../core/economy.dart' as eco;
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import 'flow.dart';
import 'screens/shop_screen.dart' show ShopScreen;
import 'tokens.dart';
import 'widgets.dart';

/// "Reklam yok" iletisi; test derlemesinde hata kodu eklenir.
String adUnavailableText(AppLocalizations loc, String? code) {
  final bool diag = kDebugMode || AdsConfig.usingTestIdsInRelease;
  return diag ? '${loc.adsUnavailable} (${code ?? 'unknown'})' : loc.adsUnavailable;
}

/// Ödüllü reklamı yükleyip gösterir. [onReward] ödül hak edilince en çok bir kez çağrılır.
/// Dönen değer: ödül verildi mi. Toast'ları kendisi gösterir (reklam yok / ödül yok). Hiçbir yolda takılmaz.
Future<bool> playRewarded(BuildContext context, String placement, {required void Function() onReward}) async {
  final AppController app = AppScope.read(context);
  final AppLocalizations loc = AppLocalizations.of(context);
  if (app.rewardBusy) return false;
  app.rewardBusy = true;
  bool loadingDone = false;
  bool popQueued = false; // yükleme penceresi en fazla BİR kez kapatılır (ikinci pop alttaki ekranı kapatırdı)
  BuildContext? loadingCtx;
  Timer? overlayTimer; // 300 ms eşiği: pencere yalnızca bekleme uzarsa açılır
  void closeLoading() {
    loadingDone = true;
    overlayTimer?.cancel();
    overlayTimer = null;
    final BuildContext? c = loadingCtx;
    loadingCtx = null;
    if (c != null && c.mounted && !popQueued) {
      popQueued = true;
      Navigator.of(c).pop();
    }
  }

  RewardedResult res;
  try {
    res = await app.mon.watchRewarded(
      placement,
      onReward: onReward,
      onLoading: () {
        overlayTimer?.cancel();
        overlayTimer = Timer(kLoadingOverlayDelay, () {
          overlayTimer = null;
          if (loadingDone || !context.mounted) return; // 300 ms içinde yüklendi / bitti: pencere hiç açılmaz
          unawaited(showSheet<void>(context, dismissible: false, builder: (BuildContext ctx) {
            loadingCtx = ctx;
            if (loadingDone && !popQueued) {
              // yükleme pencere çizilmeden bitti: ilk karede kapat
              popQueued = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) Navigator.of(ctx).pop();
              });
            }
            final Palette pal = Palette.of(ctx);
            return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const SizedBox(height: 4),
              SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 4, color: pal.inkC)),
              sheetText(ctx, loc.adsLoading, weight: FontWeight.w700),
            ]);
          }));
        });
      },
      onLoadingDone: closeLoading,
      stillWanted: () => context.mounted, // 1.1.3: ekran kapandıysa reklam ASLA otomatik gösterilmez
    );
  } catch (_) {
    res = const RewardedResult(RewardedOutcome.unavailable, errorCode: 'exception');
  } finally {
    app.rewardBusy = false;
    if (!loadingDone) closeLoading();
  }
  app.telemetry.rewardedAd(
      placement: placement, result: res.rewarded ? 'rewarded' : (res.unavailable ? 'unavailable' : 'closed'));
  if (res.rewarded) return true;
  app.sfx.error();
  app.toast(res.unavailable ? adUnavailableText(loc, res.errorCode) : loc.adsNoReward);
  return false;
}

/// Ödüllü reklam izleyerek +[eco.kAdCoins] jeton (günde en çok [eco.kMaxCoinAdsPerDay]). [onDone]: ödül verildiyse true.
Future<void> watchForCoins(BuildContext context, {void Function(bool rewarded)? onDone}) async {
  final AppController app = AppScope.read(context);
  final AppLocalizations loc = AppLocalizations.of(context);
  if (eco.coinAdsLeft(app.save, app.today()) <= 0) {
    app.sfx.error();
    app.toast(loc.adsCoinsLimit);
    onDone?.call(false);
    return;
  }
  int granted = 0;
  final bool ok = await playRewarded(context, 'coins', onReward: () {
    granted = eco.grantAdCoins(app.save, app.today());
    app.persist();
  });
  if (ok && granted > 0) {
    app.sfx.coin();
    app.toast(loc.adsRewardCoins(granted));
  }
  app.commit();
  onDone?.call(ok && granted > 0);
}

/// Oyunda ipucu istendi ama ücretsiz hak da jeton da yok: "Jetonun yetmiyor" penceresi
/// (Reklam izle: +50 jeton / Mağaza / Kapat). [onCoins]: reklamdan jeton gelince (arayüzü yenilemek için).
Future<void> openLowCoinsSheet(BuildContext context, {VoidCallback? onCoins}) {
  final AppController app = AppScope.read(context);
  final AppLocalizations loc = AppLocalizations.of(context);
  return showSheet<void>(context, builder: (BuildContext ctx) {
    final int left = eco.coinAdsLeft(app.save, app.today());
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      sheetTitle(ctx, loc.gameLowCoinsTitle),
      sheetText(ctx, loc.gameLowCoinsText(eco.kHintPrice)),
      if (left <= 0) sheetText(ctx, loc.adsCoinsLimit, weight: FontWeight.w700),
      actionsColumn(<Widget>[
        if (left > 0 && app.mon.rewardedOffered())
          AppButton('${loc.adsWatchCoins(eco.kAdCoins)} · ${loc.adsCoinsLeft(left, eco.kMaxCoinAdsPerDay)}',
              kind: BtnKind.primary, onTap: () {
            unawaited(watchForCoins(context, onDone: (bool rewarded) {
              if (!rewarded) return;
              if (ctx.mounted) Navigator.of(ctx).pop();
              onCoins?.call();
            }));
          }),
        AppButton(loc.menuShop, onTap: () {
          Navigator.of(ctx).pop();
          if (context.mounted) unawaited(Navigator.of(context).push(fadeRoute<void>(const ShopScreen())));
        }),
        AppButton(loc.commonClose, onTap: () => Navigator.of(ctx).pop()),
      ]),
    ]);
  });
}
