// ARB anahtar eşitliği: dört dilde (tr, en, de, ar) aynı anahtarlar ve aynı yer tutucular.
// (Node tarafındaki karşılığı: tools/flutter/check-arb.js — ayrıca i18n.js ile değer eşitliğini de denetler.)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<String> langs = <String>['tr', 'en', 'de', 'ar'];
  final Map<String, Map<String, dynamic>> arb = <String, Map<String, dynamic>>{
    for (final String l in langs) l: jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync()) as Map<String, dynamic>
  };
  List<String> keys(String l) => arb[l]!.keys.where((String k) => !k.startsWith('@')).toList()..sort();
  String ph(dynamic s) => (RegExp(r'\{\w+\}').allMatches(s as String).map((RegExpMatch m) => m.group(0)!).toList()..sort()).join(',');

  test('dört dilde anahtarlar birebir aynı', () {
    final List<String> ref = keys('tr');
    expect(ref.length, greaterThan(150));
    for (final String l in langs) {
      expect(keys(l), equals(ref), reason: l);
      expect(arb[l]!['@@locale'], l);
    }
  });

  test('yer tutucular dört dilde aynı ve boş değer yok', () {
    for (final String k in keys('tr')) {
      for (final String l in langs) {
        expect((arb[l]![k] as String).trim(), isNotEmpty, reason: '$l.$k');
        expect(ph(arb[l]![k]), ph(arb['tr']![k]), reason: '$l.$k');
      }
    }
  });

  test('tr şablonunda her yer tutucu için @meta bildirimi var', () {
    for (final String k in keys('tr')) {
      final List<String> p = RegExp(r'\{(\w+)\}').allMatches(arb['tr']![k] as String).map((RegExpMatch m) => m.group(1)!).toList();
      for (final String x in p) {
        final Map<String, dynamic>? meta = arb['tr']!['@$k'] as Map<String, dynamic>?;
        expect(meta?['placeholders']?[x], isNotNull, reason: '$k.$x');
      }
    }
  });
}
