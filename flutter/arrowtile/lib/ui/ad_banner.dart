// Arrowtile — ad_banner.dart: uyarlanabilir (adaptive) banner reklam alanı (docs/15 §3).
// Yalnızca Ana menü ve Harita ekranlarının EN ALTINDA (güvenli alanın üstünde: ScreenScaffold SafeArea içinde) kullanılır;
// görünürlük kuralı core/ads_rules.dart Monetization.bannerVisible(): oyun, seviye sonu, mağaza, ayarlar, günlük bulmacada YOK,
// "Reklamları kaldır" alınmışsa YOK.
//  - Reklam yüklenene dek ve yüklenemezse hiç yer kaplamaz (SizedBox.shrink): boşluk bırakmaz.
//  - Yüklenince ekranın altında banner yüksekliği kadar yer ayrılır; içerik (Expanded) yukarı itilir.
//  - Reklam yalnızca SDK hazırken (UMP canRequestAds, MobileAds.initialize bitti) istenir; reklamsız satın almada anında kaldırılır.
//  - Yükleme başarısızsa 60 sn sonra bir daha denenir (ekran açık kaldıkça).
//  1.1.4 (docs/21): cihazda "banner hiç görünmüyor" bildirimi. Her olay (istek, boyut, yüklendi + boyut, hata kodu/iletisi/yanıt bilgisi,
//  gösterim) tanılama kaydına ve telemetriye (`banner {result, code}`) yazılır. Düzeltilen boşluklar: uyarlanabilir boyut null dönerse
//  ya da yükleme istisna verirse hiç yeniden denenmiyordu (ekran yeniden çizilene dek banner istenmezdi); genişlik 0 iken istek atlanır
//  ve sonraki karede yeniden denenir. Yükleyici testlerde sahtesiyle değiştirilebilir ([AdBannerSlot.debugLoader]).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import '../core/ads_rules.dart';
import '../core/diag.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';

/// Yüklenmiş bir banner: çizilecek widget + boyut + bırakma.
class BannerHandle {
  final Widget view;
  final Size size;
  final VoidCallback dispose;
  const BannerHandle(this.view, this.size, this.dispose);
}

/// Banner yükleyici: [onLoaded] / [onFailed] (AdMob kodu, ileti) TAM BİR KEZ çağrılır. [onImpression] isteğe bağlı.
typedef BannerLoader = void Function(
  int width, {
  required void Function(BannerHandle h) onLoaded,
  required void Function(int code, String message) onFailed,
  void Function()? onImpression,
});

/// Gerçek AdMob yükleyicisi.
void googleBannerLoader(
  int width, {
  required void Function(BannerHandle h) onLoaded,
  required void Function(int code, String message) onFailed,
  void Function()? onImpression,
}) {
  unawaited(() async {
    AnchoredAdaptiveBannerAdSize? size;
    try {
      // google_mobile_ads 9: önerilen "büyük sabitlenmiş uyarlanabilir" boyut; alınamazsa eski API ile bir kez daha dene
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      // ignore: deprecated_member_use
      size ??= await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    } catch (e) {
      onFailed(-2, 'adaptive size exception: $e');
      return;
    }
    if (size == null) {
      onFailed(-3, 'adaptive size null (width=$width)');
      return;
    }
    diag('banner', 'size', <String, Object?>{'w': size.width, 'h': size.height});
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: AdsConfig.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad a) {
          onLoaded(BannerHandle(AdWidget(ad: ad), Size(ad.size.width.toDouble(), ad.size.height.toDouble()), () => a.dispose()));
        },
        onAdFailedToLoad: (Ad a, LoadAdError error) {
          a.dispose();
          String info = '';
          try {
            final ResponseInfo? ri = error.responseInfo;
            if (ri != null) info = ' adapter=${ri.mediationAdapterClassName ?? '-'} rid=${ri.responseId == null ? 'none' : 'yes'}';
          } catch (_) {}
          onFailed(error.code, '${error.domain}: ${error.message}$info');
        },
        onAdImpression: (Ad a) => onImpression?.call(),
      ),
    );
    try {
      await ad.load();
    } catch (e) {
      try {
        ad.dispose();
      } catch (_) {}
      onFailed(-4, 'load exception: $e');
    }
  }());
}

class AdBannerSlot extends StatefulWidget {
  final AdScreen screen;
  const AdBannerSlot({super.key, required this.screen});

  /// Test: gerçek AdMob yerine sahte yükleyici.
  @visibleForTesting
  static BannerLoader? debugLoader;

  /// Yeniden deneme bekleme süresi (testte kısaltılabilir).
  @visibleForTesting
  static Duration retryAfter = const Duration(seconds: 60);

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerHandle? _ad;
  bool _loading = false;
  int _gen = 0; // her yükleme denemesine yeni numara: bayat yanıtlar durumu bozmaz
  int _width = 0;
  Timer? _retry;

  String get _scr => widget.screen.name;

  bool _want(AppController app) => app.mon.bannerVisible(widget.screen) && app.mon.platform.sdkReady;

  void _drop() {
    _gen++;
    _retry?.cancel();
    _retry = null;
    _ad?.dispose();
    _ad = null;
    _loading = false;
  }

  void _scheduleRetry(Duration d) {
    _retry?.cancel();
    _retry = Timer(d, () {
      _retry = null;
      if (mounted) setState(() {}); // yeniden denemek için build'i tetikle
    });
  }

  void _load(AppController app, int width) {
    if (_loading || _ad != null) return;
    if (width <= 0) {
      diag('banner', 'skip_zero_width', <String, Object?>{'screen': _scr});
      _scheduleRetry(const Duration(milliseconds: 500));
      return;
    }
    _loading = true;
    _width = width;
    final int gen = ++_gen;
    diag('banner', 'load', <String, Object?>{'screen': _scr, 'width': width, 'unit': AdsConfig.unitTail(AdsConfig.bannerId)});
    app.telemetry.banner(result: 'load', screen: _scr);
    final BannerLoader loader = AdBannerSlot.debugLoader ?? googleBannerLoader;
    bool settled = false;
    try {
      loader(width, onLoaded: (BannerHandle h) {
        if (settled) return;
        settled = true;
        if (!mounted || gen != _gen) {
          h.dispose();
          return;
        }
        diag('banner', 'loaded', <String, Object?>{'screen': _scr, 'w': h.size.width, 'h': h.size.height});
        app.telemetry.banner(result: 'loaded', screen: _scr);
        setState(() {
          _ad = h;
          _loading = false;
        });
      }, onFailed: (int code, String msg) {
        if (settled) return;
        settled = true;
        diag('banner', 'failed', <String, Object?>{'screen': _scr, 'code': code, 'msg': msg});
        app.telemetry.banner(result: code == -3 ? 'size_null' : (code <= -2 ? 'exception' : 'failed'), code: code, screen: _scr);
        if (kDebugMode) debugPrint('Ads: banner failed ($code): $msg');
        if (!mounted || gen != _gen) return;
        setState(() {
          _ad = null;
          _loading = false;
        });
        _scheduleRetry(AdBannerSlot.retryAfter);
      }, onImpression: () {
        diag('banner', 'impression', <String, Object?>{'screen': _scr});
        app.telemetry.banner(result: 'impression', screen: _scr);
      });
    } catch (e) {
      settled = true;
      diag('banner', 'failed', <String, Object?>{'screen': _scr, 'code': -4, 'msg': '$e'});
      _loading = false;
      _scheduleRetry(AdBannerSlot.retryAfter);
    }
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final bool want = _want(app);
    if (!want) {
      if (_ad != null || _loading) {
        // reklamsız satın alma vb.: reklamı hemen kaldır (build sırasında durum değişikliği yapmadan)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_want(AppScope.read(context))) setState(_drop);
        });
      }
      return const SizedBox.shrink();
    }
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints bc) {
      final int w = bc.maxWidth.isFinite ? bc.maxWidth.floor() : MediaQuery.sizeOf(ctx).width.floor();
      if (_ad == null && !_loading && _retry == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _want(AppScope.read(context))) _load(AppScope.read(context), w);
        });
      } else if (_ad != null && (_width - w).abs() > 8) {
        // genişlik değişti (döndürme / pencere): yeni boyutla yeniden iste
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(_drop);
        });
      }
      final BannerHandle? ad = _ad;
      if (ad == null) return const SizedBox.shrink(); // yüklenmedi: yer kaplamaz
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(key: const ValueKey<String>('ad-banner'), width: ad.size.width, height: ad.size.height, child: ad.view),
      );
    });
  }
}
