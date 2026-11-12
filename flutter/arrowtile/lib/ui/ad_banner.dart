// Arrowtile — ad_banner.dart: KÜÇÜK banner reklam alanı (docs/15 §3; 1.2.1: docs/27 §A).
// Yalnızca Ana menü ve Harita ekranlarının EN ALTINDA (güvenli alanın üstünde: ScreenScaffold SafeArea içinde) kullanılır;
// görünürlük kuralı core/ads_rules.dart Monetization.bannerVisible(): oyun, seviye sonu, mağaza, ayarlar, günlük bulmacada YOK,
// "Reklamları kaldır" alınmışsa YOK, 1.2.1: kontrol grubunda (holdout) ve yerleştirme uzaktan kapatılmışsa YOK.
//  - 1.2.1 YER AYIRMA: banner'a izin varsa yuva, reklam yüklenmeden ÖNCE sabit yükseklikte ([kBannerSlotHeight] = 56 dp) boş bir alan
//    ayırır ve üstünde [kBannerGap] = 16 dp dokunulmaz boşluk bırakır; reklam gelince yalnızca bu alanın içine yerleşir → hiçbir düğme kaymaz.
//    Doldurulamazsa (no fill) ya da SDK hazır değilse alan OTURUM BOYUNCA ayrılı kalır (oyuncu dokunurken düzen değişmesin; docs/27 §A1).
//    Alan yalnızca banner hakkı kalktığında (reklamsız satın alma) hemen kapanır.
//  - Boyut: standart (büyük DEĞİL) sabitlenmiş uyarlanabilir banner; yüksekliği yuvayı aşarsa ya da alınamazsa klasik 320x50 banner.
//  - Reklam yalnızca SDK hazırken (UMP canRequestAds, MobileAds.initialize bitti) istenir.
//  - Yükleme başarısızsa 60 sn sonra bir daha denenir (ekran açık kaldıkça).
//  1.1.4 (docs/21): her olay (istek, boyut, yüklendi + boyut, hata kodu/iletisi/yanıt bilgisi, gösterim) tanılama kaydına ve telemetriye
//  (`banner {result, code}`; 1.2.1: ayrıca `banner_loaded` / `banner_failed {placement, code}`) yazılır. Yükleyici testlerde sahtesiyle
//  değiştirilebilir ([AdBannerSlot.debugLoader]).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import '../core/ads_rules.dart';
import '../core/diag.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';

/// 1.2.1: banner yuvasının sabit yüksekliği (dp). Küçük banner (320x50 ya da standart uyarlanabilir ≤ 56) buna sığar.
const double kBannerSlotHeight = 56;

/// 1.2.1: yuvanın üstündeki dokunulmaz boşluk (dp): hiçbir düğme banner'a 16 dp'den yakın olmaz (yanlışlıkla tıklama önlemi).
const double kBannerGap = 16;

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
    // 1.2.1 (docs/27 §A4): KÜÇÜK banner. Standart sabitlenmiş uyarlanabilir boyut (büyük değil); yuvaya (56 dp) sığmazsa ya da
    // alınamazsa klasik 320x50. Böylece yüklenen reklam önceden ayrılan alanı asla aşmaz (kayma yok).
    AdSize size = AdSize.banner;
    try {
      // ignore: deprecated_member_use
      final AnchoredAdaptiveBannerAdSize? a = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (a != null && a.height > 0 && a.height <= kBannerSlotHeight && a.width <= width) size = a;
      diag('banner', 'adaptive', <String, Object?>{'w': a?.width, 'h': a?.height, 'used': identical(size, a)});
    } catch (e) {
      diag('banner', 'adaptive', <String, Object?>{'error': '$e'});
    }
    if (width < size.width) {
      onFailed(-3, 'width $width < ${size.width}');
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
  Animation<double>? _routeAnim;
  BannerHandle? _ad;
  bool _loading = false;
  int _gen = 0; // her yükleme denemesine yeni numara: bayat yanıtlar durumu bozmaz
  int _width = 0;
  Timer? _retry;

  String get _scr => widget.screen.name;

  // 1.1.5 (docs/22): reklam görünümü (platform view) rota geçiş animasyonu (FadeTransition → Opacity) sürerken bağlanmaz.
  bool get _settled => _routeAnim == null || _routeAnim!.status == AnimationStatus.completed;

  void _onRouteStatus(AnimationStatus st) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? a = ModalRoute.of(context)?.animation;
    if (!identical(a, _routeAnim)) {
      _routeAnim?.removeStatusListener(_onRouteStatus);
      _routeAnim = a;
      a?.addStatusListener(_onRouteStatus);
    }
  }

  /// Bu yerleştirmede banner hakkı var mı (yer ayrılır): kural + kontrol grubu + uzaktan anahtar + reklamsız değil.
  bool _reserve(AppController app) => app.mon.bannerVisible(widget.screen);

  /// Reklam istenir/tutulur mu: hak var ve SDK hazır.
  bool _want(AppController app) => _reserve(app) && app.mon.platform.sdkReady;

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
        app.telemetry.bannerLoaded(placement: _scr);
        setState(() {
          _ad = h;
          _loading = false;
        });
      }, onFailed: (int code, String msg) {
        if (settled) return;
        settled = true;
        diag('banner', 'failed', <String, Object?>{'screen': _scr, 'code': code, 'msg': msg});
        app.telemetry.banner(result: code == -3 ? 'size_null' : (code <= -2 ? 'exception' : 'failed'), code: code, screen: _scr);
        app.telemetry.bannerFailed(placement: _scr, code: code);
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
      app.telemetry.bannerFailed(placement: _scr, code: -4);
      _loading = false;
      _scheduleRetry(AdBannerSlot.retryAfter);
    }
  }

  @override
  void dispose() {
    _routeAnim?.removeStatusListener(_onRouteStatus);
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    // 1.2.1: hak yoksa (reklamsız, kontrol grubu, uzaktan kapalı, banner'sız ekran) yuva hiç yer kaplamaz; hak varsa yer HER ZAMAN ayrılır.
    final bool reserve = _reserve(app);
    // 1.1.5 (docs/22): başka bir ekranın altında kalan (Offstage: TickerMode kapalı) yuva reklamını bırakır; aksi halde menü banner'ı
    // harita açıkken de canlı kalıp aynı anda iki yerel AdView olurdu (haritada dar kutu / ham metin / banner yok bildirimi).
    final bool active = TickerMode.of(context);
    final bool want = active && _want(app);
    if (!want) {
      if (_ad != null || _loading) {
        // reklamsız satın alma vb.: reklamı hemen kaldır (build sırasında durum değişikliği yapmadan)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!(TickerMode.of(context) && _want(AppScope.read(context)))) setState(_drop);
        });
      }
      return reserve ? _strip(null) : const SizedBox.shrink();
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
      return _strip(_ad);
    });
  }

  /// Tam genişlikte alt şerit (Column'un son çocuğu; harita/menü içeriği Expanded ile ÜSTTE): üstte [kBannerGap] boşluk, altında sabit
  /// [kBannerSlotHeight] yüksekliğinde alan. Reklam yoksa alan boştur (yer tutucu: düz zemin, metin/çerçeve yok — tıklamaya davet etmez).
  /// AdWidget yalnızca yüklendikten sonra, tam reklam boyutunda SizedBox içinde; Transform/Opacity/Clip yok, kaydırılan listenin içinde değil.
  Widget _strip(BannerHandle? ad) {
    final double h = ad == null ? kBannerSlotHeight : math.max(kBannerSlotHeight, ad.size.height);
    return Padding(
      padding: const EdgeInsets.only(top: kBannerGap),
      child: SizedBox(
        key: const ValueKey<String>('ad-banner-strip'),
        width: double.infinity,
        height: h,
        child: ad != null && _settled
            ? Center(child: SizedBox(key: const ValueKey<String>('ad-banner'), width: ad.size.width, height: ad.size.height, child: ad.view))
            : null,
      ),
    );
  }
}
