// Arrowtile — shop_screen.dart: mağaza (ok temaları + yardımcılar + reklamları kaldır).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/economy.dart' as eco;
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_lookup.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../board_painter.dart';
import '../rewarded_flow.dart';
import '../tokens.dart';
import '../widgets.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _tab = 'themes';

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    return ScreenScaffold(
      child: Column(children: <Widget>[
        ScreenBar(title: loc.shopTitle, onBack: () => Navigator.of(context).maybePop(), trailing: const <Widget>[CoinPill()]),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                child: Text(loc.shopBalance(app.save.coins),
                    style: TextStyle(color: pal.inkC, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: pal.cellC, border: pal.hcBorder, borderRadius: BorderRadius.circular(16)),
                child: Row(children: <Widget>[
                  Expanded(child: _tabBtn(pal, 'themes', loc.shopThemes, app)),
                  const SizedBox(width: 6),
                  Expanded(child: _tabBtn(pal, 'boosters', loc.shopBoosters, app)),
                ]),
              ),
              if (_tab == 'themes') ..._themeItems(context, app, loc, pal) else ..._boosterItems(context, app, loc, pal),
              const AdsCard(where: 'shop'),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(loc.shopEarnNote,
                    textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoftC, fontSize: 14)),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _tabBtn(Palette pal, String id, String label, AppController app) {
    final bool on = _tab == id;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          app.sfx.button();
          setState(() => _tab = id);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? pal.boardC : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: on ? <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 2))] : null,
          ),
          child: withSelectedMark(
              pal, FitText(label, style: TextStyle(color: pal.inkC, fontSize: 16, fontWeight: FontWeight.w700), minFont: 12, maxLines: 3), on),
        ),
      ),
    );
  }

  List<Widget> _themeItems(BuildContext context, AppController app, AppLocalizations loc, Palette pal) {
    return <Widget>[
      for (final ArrowTheme th in kArrowThemes)
        _ItemCard(
          leading: ThemePreview(theme: th),
          title: themeName(loc, th.id),
          priceWidget: _themePrice(th, app, loc, pal),
          action: _themeAction(context, th, app, loc),
        ),
    ];
  }

  Widget _themePrice(ArrowTheme th, AppController app, AppLocalizations loc, Palette pal) {
    final bool owned = app.save.themesOwned.contains(th.id);
    if (th.price == 0) return _priceText(pal, loc.shopFree);
    if (owned) return _priceText(pal, loc.shopOwned);
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Icon(Icons.monetization_on, size: 20, color: pal.coinInkC),
      const SizedBox(width: 4),
      Flexible(child: _priceText(pal, loc.shopPrice(th.price))),
    ]);
  }

  Widget _priceText(Palette pal, String t) =>
      Text(t, style: TextStyle(color: pal.inkSoftC, fontSize: 14, fontWeight: FontWeight.w700));

  Widget _themeAction(BuildContext context, ArrowTheme th, AppController app, AppLocalizations loc) {
    final bool owned = app.save.themesOwned.contains(th.id);
    final bool inUse = app.save.theme == th.id;
    if (inUse) {
      return AppButton(loc.shopEquipped, kind: BtnKind.equipped, icon: Icons.check, fontSize: 16, onTap: () {});
    }
    if (owned) {
      return AppButton(loc.shopEquip, fontSize: 16, onTap: () {
        app.save.theme = th.id;
        app.commit();
        app.themeEquipped(th.id);
      });
    }
    return AppButton(loc.shopBuy, kind: BtnKind.primary, fontSize: 16, onTap: () {
      if (app.save.coins < th.price) {
        app.sfx.error();
        app.buzz('error');
        app.toast(loc.gameNotEnoughCoins);
        return;
      }
      confirmBox(context, loc.shopConfirm(th.price), () {
        if (app.save.coins < th.price) return;
        app.save.coins -= th.price;
        app.save.themesOwned.add(th.id);
        app.save.theme = th.id;
        app.commit();
        app.themeEquipped(th.id);
        app.sfx.coin();
        app.toast(loc.shopBought);
      }, yesLabel: loc.shopBuy);
    });
  }

  List<Widget> _boosterItems(BuildContext context, AppController app, AppLocalizations loc, Palette pal) {
    final int free = app.save.freeHints;
    return <Widget>[
      _ItemCard(
        leading: Icon(Icons.lightbulb, size: 48, color: pal.starInkC),
        title: loc.gameHint,
        desc: loc.shopHintDesc,
        priceWidget: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(Icons.monetization_on, size: 20, color: pal.coinInkC),
          const SizedBox(width: 4),
          Flexible(child: _priceText(pal, loc.shopPrice(eco.kHintPrice) + (free > 0 ? ' · ${loc.gameFreeLeft(free)}' : ''))),
        ]),
        action: app.mon.rewardedOffered()
            ? AppButton(loc.adsWatchHint, fontSize: 16, onTap: () => unawaited(watchForHint(context))) // ödüllü +1 ipucu
            : null,
      ),
      _coinAdItem(context, app, loc, pal),
    ];
  }

  /// "Reklam izle: +50 jeton" — kalan günlük hakla (kural: economy.dart grantAdCoins).
  Widget _coinAdItem(BuildContext context, AppController app, AppLocalizations loc, Palette pal) {
    final int left = eco.coinAdsLeft(app.save, app.today());
    return _ItemCard(
      leading: Icon(Icons.monetization_on, size: 48, color: pal.coinInkC),
      title: loc.adsWatchCoins(eco.kAdCoins),
      desc: loc.adsCoinsDesc(eco.kMaxCoinAdsPerDay),
      priceWidget: _priceText(pal, left > 0 ? loc.adsCoinsLeft(left, eco.kMaxCoinAdsPerDay) : loc.adsCoinsLimit),
      action: (left > 0 && app.mon.rewardedOffered())
          ? AppButton(loc.adsWatchCoins(eco.kAdCoins), fontSize: 16, onTap: () => unawaited(watchForCoins(context)))
          : null,
    );
  }
}

/// Ödüllü reklam izleyerek +1 ücretsiz ipucu (main.js watchForHint).
Future<void> watchForHint(BuildContext context) async {
  final AppController app = AppScope.read(context);
  final AppLocalizations loc = AppLocalizations.of(context);
  final bool rewarded = await playRewarded(context, 'hint', onReward: () {
    app.save.freeHints++;
    app.persist();
  });
  if (rewarded) {
    app.sfx.coin();
    app.toast(loc.adsRewardHint);
  }
  app.commit();
}

class _ItemCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? desc;
  final Widget priceWidget;
  final Widget? action;
  const _ItemCard({required this.leading, required this.title, required this.priceWidget, this.desc, this.action});

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.boardC,
        border: pal.hcBorder,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 3))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
        SizedBox(width: 88, child: Center(child: leading)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(title, style: TextStyle(color: pal.inkC, fontSize: 18, fontWeight: FontWeight.w700)),
            if (desc != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(desc!, style: TextStyle(color: pal.inkSoftC, fontSize: 14)),
            ],
            const SizedBox(height: 6),
            priceWidget,
            if (action != null) ...<Widget>[const SizedBox(height: 10), action!],
          ]),
        ),
      ]),
    );
  }
}

/// Tema önizlemesi: 88x64 tuvalde 5 örnek ok (main.js themePreview).
class ThemePreview extends StatelessWidget {
  final ArrowTheme theme;
  const ThemePreview({super.key, required this.theme});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Container(
      width: 88,
      height: 64,
      decoration: BoxDecoration(color: pal.cellC, border: pal.hcBorder, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(painter: _ThemePreviewPainter(theme, pal)),
      ),
    );
  }
}

class _ThemePreviewPainter extends CustomPainter {
  final ArrowTheme th;
  final Palette pal;
  _ThemePreviewPainter(this.th, this.pal);

  void _arrow(Canvas canvas, double x, double y, String dir, int len, int color) {
    const Map<String, List<int>> d = <String, List<int>>{
      'R': <int>[1, 0],
      'D': <int>[0, 1],
      'L': <int>[-1, 0],
      'U': <int>[0, -1],
    };
    final List<int> s = d[dir]!;
    drawArrow(
        canvas,
        ArrowDrawOpts(
            ox: x,
            oy: y,
            cells: <List<int>>[for (int k = 0; k < len; k++) <int>[s[0] * k, s[1] * k]],
            dir: dir,
            cell: 20,
            color: color,
            chevron: th.chevron,
            chevronAlpha: th.chevronAlpha),
        pal);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _arrow(canvas, 6, 4, 'R', 3, th.colors[0]);
    _arrow(canvas, 66, 4, 'D', 2, th.colors[1]);
    _arrow(canvas, 6, 26, 'U', 2, th.colors[2]);
    _arrow(canvas, 26, 40, 'L', 2, th.colors[3]);
    _arrow(canvas, 46, 24, 'R', 1, th.colors[4]);
  }

  @override
  bool shouldRepaint(covariant _ThemePreviewPainter old) => old.th != th || old.pal != pal;
}

/// "Reklamları kaldır" kartı (Mağaza + Ayarlar): satın alma + geri yükleme (main.js buildAdsCard).
class AdsCard extends StatefulWidget {
  final String where;
  final bool embedded; // Ayarlar'da kart çerçevesiz
  const AdsCard({super.key, required this.where, this.embedded = false});
  @override
  State<AdsCard> createState() => _AdsCardState();
}

class _AdsCardState extends State<AdsCard> {
  bool _busy = false;

  Future<void> _buy(AppController app, AppLocalizations loc) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await app.mon.purchaseRemoveAds();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      // yalnızca GERÇEK başarılı satın alma analiz olayı olur (zaten sahip / test modu / iptal / bekleyen / hata değil)
      if (!r.already && !r.test) {
        app.telemetry.purchaseRemoveAds(currency: app.billing.priceCurrency, value: app.billing.priceValue);
      }
      app.sfx.coin();
      app.toast(loc.adsPurchased + (r.test ? ' · ${loc.adsTestMode}' : ''));
    } else if (r.reason == 'pending') {
      app.toast(loc.adsPending);
    } else {
      app.sfx.error();
      app.toast(r.reason == 'cancelled' ? loc.adsCancelled : (r.reason == 'offline' ? loc.adsOffline : loc.adsFailed));
    }
    app.commit();
  }

  Future<void> _restore(AppController app, AppLocalizations loc) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await app.mon.restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      app.sfx.error();
      app.toast(r.reason == 'offline' ? loc.adsOffline : loc.adsFailed);
    } else {
      app.toast(r.adFree ? loc.adsRestoredOk : loc.adsRestoredNone);
    }
    app.commit();
  }

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final bool adFree = app.mon.isAdFree();
    final Widget inner = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: <Widget>[
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        SizedBox(width: 88, child: Center(child: Icon(Icons.block, size: 44, color: pal.dangerC))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(loc.adsRemoveTitle, style: TextStyle(color: pal.inkC, fontSize: 18, fontWeight: FontWeight.w700)),
            if (!adFree) ...<Widget>[
              const SizedBox(height: 6),
              Text(loc.adsRemoveDesc, style: TextStyle(color: pal.inkSoftC, fontSize: 14)),
            ],
            if (app.mon.isTestMode) ...<Widget>[
              const SizedBox(height: 6),
              Text(loc.adsTestMode, style: TextStyle(color: pal.coinC, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      if (adFree)
        AppButton(loc.adsAdFree, kind: BtnKind.equipped, icon: Icons.check, fontSize: 16, onTap: () {})
      else
        AppButton(loc.adsRemoveTitle, kind: BtnKind.primary, fontSize: 16, onTap: _busy ? null : () => unawaited(_buy(app, loc))),
      const SizedBox(height: 6),
      AppButton(loc.adsRestore, kind: BtnKind.ghost, fontSize: 16, onTap: _busy ? null : () => unawaited(_restore(app, loc))),
    ]);
    if (widget.embedded) return inner;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.boardC,
        border: pal.hcBorder,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 3))],
      ),
      child: inner,
    );
  }
}
