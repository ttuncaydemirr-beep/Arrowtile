// Arrowtile — diag_screen.dart: gizli "Tanılama" ekranı (1.1.4, docs/21). Ayarlar'da sürüm metnine 7 kez dokununca açılır.
// Bellekteki son olayları (core/diag.dart) gösterir; "Kopyala" panoya kopyalar, "Paylaş" Android paylaşım penceresini açar
// (WhatsApp / e-posta). Kişisel veri içermez (yalnızca olay adları, süreler, reklam SDK hata kodları, sürüm bilgisi).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/ads_config.dart';
import '../../core/diag.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../tokens.dart';
import '../widgets.dart';

const MethodChannel _share = MethodChannel('com.arrowtile.puzzle/share');

/// Tanılama metni: başlık (sürüm, derleme türü, reklam birimi türü/son haneleri, SDK/onay durumu) + olaylar.
String diagReport(AppController app) {
  String unit(String id) => '${AdsConfig.isTestUnit(id) ? 'test' : 'real'}..${AdsConfig.unitTail(id)}';
  return DiagLog.I.dump(header: <String, Object?>{
    'version': AppInfo.version,
    'build': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
    'units': 'interstitial=${unit(AdsConfig.interstitialId)} rewarded=${unit(AdsConfig.rewardedId)} banner=${unit(AdsConfig.bannerId)}',
    'sdk_ready': app.mon.platform.sdkReady,
    'online': app.mon.platform.online,
    'ad_free': app.mon.isAdFree(),
    // 1.2.1 (docs/27): banner kontrol grubu + uzaktan anahtarlar (banner_group, kova, yüzde, menü/harita, kaynak default|remote)
    ...app.bannerPolicy.toDiag(),
    'ad_hold': app.mon.adHoldFormat ?? 'none',
    'ads_since': app.save.ads.since,
    'sound': app.save.sound,
    'audio_ready': app.sfx.ready,
    'audio_held': app.sfx.held,
    'lang': app.lang,
    'unlocked': app.save.unlocked,
  });
}

class DiagScreen extends StatefulWidget {
  const DiagScreen({super.key});
  @override
  State<DiagScreen> createState() => _DiagScreenState();
}

class _DiagScreenState extends State<DiagScreen> {
  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = AppLocalizations.of(context);
    final Palette pal = Palette.of(context);
    final String text = diagReport(app);
    return ScreenScaffold(
      child: Column(children: <Widget>[
        ScreenBar(title: loc.diagTitle, onBack: () => Navigator.of(context).maybePop()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(loc.diagHint, textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoftC, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: <Widget>[
            Expanded(
              child: AppButton(loc.diagCopy, kind: BtnKind.primary, onTap: () async {
                await Clipboard.setData(ClipboardData(text: text));
                app.toast(loc.diagCopied);
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(loc.diagShare, onTap: () async {
                bool ok = false;
                try {
                  ok = await _share.invokeMethod<bool>('text', <String, String>{'text': text, 'subject': 'Arrowtile ${AppInfo.version} diagnostics'}) ?? false;
                } catch (_) {
                  ok = false;
                }
                if (!ok) {
                  // paylaşım açılamadı: en azından panoya kopyala
                  await Clipboard.setData(ClipboardData(text: text));
                  app.toast(loc.diagCopied);
                }
              }),
            ),
          ]),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: pal.boardC, borderRadius: BorderRadius.circular(12)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                reverse: true, // en yeni olaylar altta, görünür
                child: SelectableText(text, style: TextStyle(color: pal.inkC, fontSize: 11, fontFamily: 'monospace', height: 1.3)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextButton(
            onPressed: () => setState(() {}),
            child: Text('↻', style: TextStyle(color: pal.inkSoftC, fontSize: 20)),
          ),
        ),
      ]),
    );
  }
}
