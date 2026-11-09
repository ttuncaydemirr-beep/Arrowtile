// Arrowtile — ad_banner.dart: uyarlanabilir (adaptive) banner reklam alanı (docs/15 §3).
// Yalnızca Ana menü ve Harita ekranlarının EN ALTINDA (güvenli alanın üstünde: ScreenScaffold SafeArea içinde) kullanılır;
// görünürlük kuralı core/ads_rules.dart Monetization.bannerVisible(): oyun, seviye sonu, mağaza, ayarlar, günlük bulmacada YOK,
// "Reklamları kaldır" alınmışsa YOK.
//  - Reklam yüklenene dek ve yüklenemezse hiç yer kaplamaz (SizedBox.shrink): boşluk bırakmaz.
//  - Yüklenince ekranın altında banner yüksekliği kadar yer ayrılır; içerik (Expanded) yukarı itilir, hiçbir düğme banner'ın
//    altında kalmaz (banner içeriğin ÜSTÜNE binmez, içerikle aynı sütundadır).
//  - Reklam yalnızca SDK hazırken (UMP onayı alındı, MobileAds.initialize bitti) istenir; reklamsız satın almada anında kaldırılır.
//  - Yükleme başarısızsa 60 sn sonra bir daha denenir (ekran açık kaldıkça).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import '../core/ads_rules.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';

class AdBannerSlot extends StatefulWidget {
  final AdScreen screen;
  const AdBannerSlot({super.key, required this.screen});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  int _gen = 0; // her yükleme denemesine yeni numara: bayat yanıtlar durumu bozmaz
  int _width = 0;
  Timer? _retry;

  static const Duration _retryAfter = Duration(seconds: 60);

  bool _want(AppController app) => app.mon.bannerVisible(widget.screen) && app.platform.sdkReady;

  void _drop() {
    _gen++;
    _retry?.cancel();
    _retry = null;
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _loading = false;
  }

  Future<void> _load(int width) async {
    if (_loading || _ad != null || width <= 0) return;
    _loading = true;
    _width = width;
    final int gen = ++_gen;
    try {
      final AnchoredAdaptiveBannerAdSize? size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (!mounted || gen != _gen || size == null) {
        if (gen == _gen) _loading = false;
        return;
      }
      final BannerAd ad = BannerAd(
        adUnitId: AdsConfig.bannerId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad a) {
            if (!mounted || gen != _gen) {
              a.dispose();
              return;
            }
            setState(() {
              _loaded = true;
              _loading = false;
            });
          },
          onAdFailedToLoad: (Ad a, LoadAdError error) {
            a.dispose();
            if (kDebugMode) debugPrint('Ads: banner onAdFailedToLoad (${error.code}): ${error.message}');
            if (!mounted || gen != _gen) return;
            setState(() {
              _ad = null;
              _loaded = false;
              _loading = false;
            });
            _retry?.cancel();
            _retry = Timer(_retryAfter, () {
              _retry = null;
              if (mounted) setState(() {}); // yeniden denemek için build'i tetikle
            });
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (e) {
      if (kDebugMode) debugPrint('Ads: banner load exception: $e');
      if (gen == _gen) {
        _ad?.dispose();
        _ad = null;
        _loaded = false;
        _loading = false;
      }
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
          if (mounted && _want(AppScope.read(context))) unawaited(_load(w));
        });
      } else if (_ad != null && _loaded && (_width - w).abs() > 8) {
        // genişlik değişti (döndürme / pencere): yeni boyutla yeniden iste
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(_drop);
          }
        });
      }
      final BannerAd? ad = _ad;
      if (ad == null || !_loaded) return const SizedBox.shrink(); // yüklenmedi: yer kaplamaz
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      );
    });
  }
}
