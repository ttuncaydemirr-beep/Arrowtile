// 1.1.4 (docs/21): tanılama halkası — sınır, sıra, ses çalmaları ayrı halka, döküm biçimi, kişisel veri yok.
import 'package:arrowtile/core/diag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('son 200 olay tutulur (eskiden yeniye), ses çalmaları ayrı halkada (reklam olaylarını itip çıkarmaz)', () {
    final DiagLog d = DiagLog(capacity: 200, playCapacity: 30);
    for (int i = 0; i < 250; i++) {
      d.add('ad', 'e$i', <String, Object?>{'i': i});
    }
    for (int i = 0; i < 100; i++) {
      d.add('audio', 'play', <String, Object?>{'s': 'tap'});
    }
    expect(d.entries.length, 200);
    expect(d.entries.first.msg, 'e50');
    expect(d.entries.last.msg, 'e249');
    expect(d.plays.length, 30);
    expect(d.counters['audio.play'], 100);
  });

  test('döküm: başlık, sayaçlar, zaman damgalı satırlar; uzun değerler kısaltılır', () {
    final DiagLog d = DiagLog();
    d.add('ad', 'load_failed', <String, Object?>{'format': 'banner', 'code': 3, 'msg': 'x' * 500});
    final String s = d.dump(header: <String, Object?>{'version': '1.1.4'});
    expect(s, contains('version: 1.1.4'));
    expect(s, contains('[ad] load_failed format=banner code=3'));
    expect(RegExp(r'\d\d:\d\d:\d\d\.\d\d\d \+\d+\.\ds').hasMatch(s), isTrue);
    expect(s.contains('x' * 200), isFalse);
  });

  test('istisna fırlatmaz', () {
    expect(() => diag('app', 'x', <String, Object?>{'o': Object()}), returnsNormally);
  });
}
