// Ortak test yardımcıları: altın dosyaları okuma ve ok listesi karşılaştırma.
import 'dart:convert';
import 'dart:io';

import 'package:arrowtile/core/models.dart';

/// `flutter test` proje kökünden çalışır; altın dosyalar test/golden altındadır (tools/flutter/make-goldens.js üretir).
dynamic golden(String name) => jsonDecode(File('test/golden/$name').readAsStringSync());

List<Arrow> arrowsFromJson(dynamic list) => <Arrow>[
      for (final dynamic a in (list as List<dynamic>)) Arrow.fromJson(a as Map<String, dynamic>)
    ];

/// İki ok listesi aynı mı? Değilse ilk farkı anlatan bir metin döner, aynıysa null.
String? firstArrowDiff(List<Arrow> actual, List<Arrow> expected) {
  if (actual.length != expected.length) return 'ok sayısı ${actual.length} != beklenen ${expected.length}';
  for (int i = 0; i < actual.length; i++) {
    if (actual[i].dir != expected[i].dir) return 'ok #$i yön ${actual[i].dir} != ${expected[i].dir}';
    if (jsonEncode(actual[i].cells) != jsonEncode(expected[i].cells)) {
      return 'ok #$i hücreler ${jsonEncode(actual[i].cells)} != ${jsonEncode(expected[i].cells)}';
    }
  }
  return null;
}
