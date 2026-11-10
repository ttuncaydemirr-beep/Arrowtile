// 1.1.4 (docs/21): tam ekran reklam show() çağrısının YALNIZCA izin verilen yollarda olduğunu kaynak taramasıyla doğrular.
//  - `ad.show(` yalnızca services/ads_service.dart içinde (geçiş + ödüllü, birer kez).
//  - platform.showInterstitial( yalnızca core/ads_rules.dart continueAfterLevel içinde; continueAfterLevel( yalnızca oyun ekranının
//    seviye sonu adımında (_adThenContinue).
//  - ödüllü: platform.showRewarded( yalnızca Monetization.showRewarded; watchRewarded( yalnızca ui/rewarded_flow.dart playRewarded.
//  - Uygulama açılış reklamı (AppOpenAd) yok; banner yalnızca ui/ad_banner.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _sources() {
  final Map<String, String> m = <String, String>{};
  for (final FileSystemEntity e in Directory('lib').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart') && !e.path.contains('l10n${Platform.pathSeparator}app_localizations')) {
      m[e.path.replaceAll('\\', '/')] = e.readAsStringSync();
    }
  }
  return m;
}

/// Yorum satırları çıkarılmış kaynak.
String _code(String s) => s.split('\n').map((String l) {
      final int i = l.indexOf('//');
      return i >= 0 ? l.substring(0, i) : l;
    }).join('\n');

List<String> _hits(Map<String, String> src, RegExp re) {
  final List<String> out = <String>[];
  src.forEach((String path, String s) {
    final int n = re.allMatches(_code(s)).length;
    for (int i = 0; i < n; i++) {
      out.add(path);
    }
  });
  return out;
}

void main() {
  final Map<String, String> src = _sources();

  test('kaynaklar okundu', () => expect(src.length, greaterThan(20)));

  test('ad.show( yalnızca ads_service.dart: geçiş + ödüllü birer çağrı', () {
    expect(_hits(src, RegExp(r'\bad\.show\(')), <String>['lib/services/ads_service.dart', 'lib/services/ads_service.dart']);
    expect(_hits(src, RegExp(r'\.show\(')).toSet(), <String>{'lib/services/ads_service.dart'});
  });

  test('showInterstitial( yalnızca Monetization.continueAfterLevel', () {
    expect(_hits(src, RegExp(r'\.showInterstitial\(')), <String>['lib/core/ads_rules.dart']);
    final String rules = _code(src['lib/core/ads_rules.dart']!);
    final int at = rules.indexOf('.showInterstitial(');
    final int fn = rules.lastIndexOf('Future<bool> continueAfterLevel(', at);
    final int next = rules.indexOf('void _reportInterstitial(', fn);
    expect(fn, greaterThan(0));
    expect(at, lessThan(next), reason: 'çağrı continueAfterLevel gövdesinde olmalı');
  });

  test('continueAfterLevel( yalnızca oyun ekranının seviye sonu adımında', () {
    final List<String> h = _hits(src, RegExp(r'\.continueAfterLevel\('));
    expect(h, <String>['lib/ui/screens/game_screen.dart']);
    final String g = _code(src['lib/ui/screens/game_screen.dart']!);
    final int at = g.indexOf('.continueAfterLevel(');
    expect(g.lastIndexOf('Future<void> _adThenContinue(', at), greaterThan(0));
  });

  test('ödüllü show yalnızca dokunuş akışından', () {
    expect(_hits(src, RegExp(r'platform\s*\.showRewarded\(')), <String>['lib/core/ads_rules.dart']);
    expect(_hits(src, RegExp(r'\.watchRewarded\(')), <String>['lib/ui/rewarded_flow.dart']);
    final List<String> callers = _hits(src, RegExp(r'\bplayRewarded\(|\bwatchForCoins\(')).toSet().toList()..sort();
    // tanım + dokunuş işleyicileri (oyun: +1 can; mağaza/düşük jeton: +50 jeton)
    for (final String c in callers) {
      expect(<String>{'lib/ui/rewarded_flow.dart', 'lib/ui/screens/game_screen.dart', 'lib/ui/screens/shop_screen.dart'}, contains(c));
    }
  });

  test('uygulama açılış reklamı yok; banner yalnızca ad_banner.dart', () {
    expect(_hits(src, RegExp(r'AppOpenAd')), isEmpty);
    expect(_hits(src, RegExp(r'BannerAd\(')).toSet(), <String>{'lib/ui/ad_banner.dart'});
  });

  test('yükleme geri çağrıları show() çağırmaz (onAdLoaded gövdelerinde show yok)', () {
    final String svc = _code(src['lib/services/ads_service.dart']!);
    for (final Match m in RegExp(r'onAdLoaded: \(').allMatches(svc)) {
      final String body = svc.substring(m.start, svc.indexOf('onAdFailedToLoad', m.start));
      expect(body.contains('.show('), isFalse);
      expect(body.contains('showInterstitial'), isFalse);
      expect(body.contains('showRewarded'), isFalse);
    }
  });
}
