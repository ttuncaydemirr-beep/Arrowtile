// 1.2.3+15 (docs/29, "Billing 8 yükseltmesi"): Google Play, Play Billing Library < 8 kullanan paketleri reddeder.
//  - in_app_purchase_android 0.5.0 ve üzeri Billing 8+ kullanır (0.4.x = Billing 7.1.1 → reddedilir).
//  - 0.5.0 ile kaldırılan queryPurchaseHistory / queryPurchaseHistoryAsync kodda kullanılmaz.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec.lock: in_app_purchase_android >= 0.5.0 (Play Billing Library >= 8)', () {
    final String lock = File('pubspec.lock').readAsStringSync();
    final RegExp re = RegExp(r'in_app_purchase_android:\n(?:    .*\n)*?    version: "(\d+)\.(\d+)\.(\d+)(?:\+\d+)?"');
    final Match? m = re.firstMatch(lock);
    expect(m, isNotNull, reason: 'pubspec.lock içinde in_app_purchase_android bulunamadı');
    final int major = int.parse(m!.group(1)!);
    final int minor = int.parse(m.group(2)!);
    expect(major > 0 || minor >= 5, isTrue, reason: 'in_app_purchase_android 0.5.0 altı Billing 7 kullanır; Play reddeder');
  });

  test('pubspec.yaml: in_app_purchase_android kısıtı 0.5.x altına inmez', () {
    final String y = File('pubspec.yaml').readAsStringSync();
    final Match? m = RegExp(r'in_app_purchase_android:\s*\^(\d+)\.(\d+)').firstMatch(y);
    expect(m, isNotNull);
    expect(int.parse(m!.group(1)!) > 0 || int.parse(m.group(2)!) >= 5, isTrue);
  });

  test('lib/: Billing 8 ile kaldırılan geçmiş sorgusu API\'leri kullanılmaz', () {
    final List<File> files = Directory('lib').listSync(recursive: true).whereType<File>().where((File f) => f.path.endsWith('.dart')).toList();
    expect(files, isNotEmpty);
    for (final File f in files) {
      final String s = f.readAsStringSync();
      expect(s.contains('queryPurchaseHistory'), isFalse, reason: '${f.path}: queryPurchaseHistory Billing 8\'de kaldırıldı');
    }
  });
}
