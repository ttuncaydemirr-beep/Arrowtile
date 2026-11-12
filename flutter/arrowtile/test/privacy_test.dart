// Gizlilik metni (docs/15 §6): Google iş ortağı veri kullanımı bağlantısı ve 13 yaş altı cümlesi 4 dilde; https:// adresleri bağlantıya bölünür.
import 'dart:convert';
import 'dart:io';

import 'package:arrowtile/config/ads_config.dart';
import 'package:arrowtile/ui/screens/privacy_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('geliştirici adı Demir Games Studio; gizlilik tarihi web ile aynı', () {
    expect(AppInfo.developerName, 'Demir Games Studio');
    final String web = File('../../game/js/privacy.js').readAsStringSync();
    expect(web, contains("var UPDATED = '${AppInfo.privacyUpdated}'"));
  });

  const String partner = 'https://policies.google.com/technologies/partner-sites';

  test('splitLinks: adres bağlantı olur, çevresindeki metin korunur', () {
    expect(splitLinks('önce $partner'), <(String, bool)>[('önce ', false), (partner, true)]);
    expect(splitLinks('a https://x.y/z b'), <(String, bool)>[('a ', false), ('https://x.y/z', true), (' b', false)]);
    expect(splitLinks('bağlantı yok'), <(String, bool)>[('bağlantı yok', false)]);
    expect(splitLinks(''), isEmpty);
  });

  for (final String lang in <String>['tr', 'en', 'de', 'ar']) {
    test('gizlilik ($lang): iş ortağı bağlantısı + 13 yaş altı cümlesi var', () {
      final Map<String, dynamic> arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
      final String ads = arb['privacyPAds'] as String;
      expect(ads.contains(partner), isTrue);
      expect(splitLinks(ads).where(((String, bool) p) => p.$2).map(((String, bool) p) => p.$1), <String>[partner]);
      // 1.1.2 (docs/19): Firebase Analytics + Crashlytics açıklaması ve Google gizlilik bağlantısı
      final String an = arb['privacyPAnalytics'] as String;
      expect(an.contains('Firebase Analytics'), isTrue);
      expect(an.contains('Crashlytics'), isTrue);
      expect(splitLinks(an).where(((String, bool) p) => p.$2).map(((String, bool) p) => p.$1), <String>['https://firebase.google.com/support/privacy']);
      final String data = arb['privacyPData'] as String;
      const Map<String, String> under13 = <String, String>{
        'tr': '13 yaş altındaki çocuklara yönelik değildir',
        'en': 'not directed at children under 13',
        'de': 'unter 13',
        'ar': '13',
      };
      expect(data.contains(under13[lang]!), isTrue, reason: data);
      // 1.2.1: geliştirici adı her dilde
      expect(arb['privacyPContact'] as String, contains('Demir Games Studio'));
    });
  }
}
