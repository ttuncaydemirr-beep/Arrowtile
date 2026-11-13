// 1.2.2 (Madde 9): yüksek kontrast — palet seçimi, kayıt alanı (null = cihaz ayarı) ve kenarlık yardımcısı.
// Renk eşikleri (metin ≥ 7:1, kenarlık / simge ≥ 3:1) tools/contrast.js ile CI'da denetlenir.
import 'dart:convert';

import 'package:arrowtile/core/save_data.dart';
import 'package:arrowtile/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Palette.select: parlaklık + yüksek kontrast → dört palet', () {
    expect(identical(Palette.select(Brightness.light), Palette.light), isTrue);
    expect(identical(Palette.select(Brightness.dark), Palette.darkP), isTrue);
    expect(identical(Palette.select(Brightness.light, highContrast: true), Palette.lightHc), isTrue);
    expect(identical(Palette.select(Brightness.dark, highContrast: true), Palette.darkHc), isTrue);
    expect(Palette.light.hc, isFalse);
    expect(Palette.darkP.hc, isFalse);
    expect(Palette.lightHc.hc, isTrue);
    expect(Palette.darkHc.hc, isTrue);
    expect(Palette.lightHc.dark, isFalse);
    expect(Palette.darkHc.dark, isTrue);
  });

  test('hcBorder yalnızca yüksek kontrastta', () {
    expect(Palette.light.hcBorder, isNull);
    expect(Palette.darkP.hcBorder, isNull);
    expect(Palette.lightHc.hcBorder, isNotNull);
    expect(Palette.lightHc.hcBorder!.top.width, 2);
    expect(Palette.darkHc.hcBorder!.top.color, Palette.darkHc.edgeC);
  });

  test('kayıt: highContrast null (cihaz ayarı) / true / false korunur, bozuk değer null olur', () {
    expect(sanitize(<String, dynamic>{'lang': 'tr'}, 'tr').highContrast, isNull);
    for (final bool v in <bool>[true, false]) {
      final SaveData s = sanitize(<String, dynamic>{'lang': 'tr', 'highContrast': v}, 'tr');
      expect(s.highContrast, v);
      final SaveData again = sanitize(jsonDecode(jsonEncode(s.toJson())), 'tr');
      expect(again.highContrast, v);
    }
    expect(sanitize(<String, dynamic>{'lang': 'tr', 'highContrast': 'evet'}, 'tr').highContrast, isNull);
    expect(sanitize(<String, dynamic>{'lang': 'tr', 'highContrast': 1}, 'tr').highContrast, isNull);
  });

  testWidgets('PaletteScope highContrast → Palette.of yüksek kontrast paleti döndürür', (WidgetTester t) async {
    late Palette got;
    Widget probe(Brightness b, bool hc) => PaletteScope(
          brightness: b,
          highContrast: hc,
          child: Builder(builder: (BuildContext c) {
            got = Palette.of(c);
            return const SizedBox();
          }),
        );
    await t.pumpWidget(probe(Brightness.light, false));
    expect(identical(got, Palette.light), isTrue);
    await t.pumpWidget(probe(Brightness.light, true));
    expect(identical(got, Palette.lightHc), isTrue);
    await t.pumpWidget(probe(Brightness.dark, true));
    expect(identical(got, Palette.darkHc), isTrue);
  });
}
