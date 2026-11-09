// UMP onay formu kapısı: açılışta bir kez, yalnızca ön planda ve oyun dışında, öne her gelişte yeniden gösterilmez (docs/16).
import 'package:arrowtile/core/consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onay bilgisi güncellemesi açılışta yalnızca bir kez başlar', () {
    final ConsentFormGate g = ConsentFormGate();
    expect(g.beginSession(), isTrue);
    expect(g.beginSession(), isFalse);
    expect(g.beginSession(), isFalse);
  });

  test('ön plandayken ve oyun dışındayken form gösterilir; bitene dek ikinci form yok', () {
    final ConsentFormGate g = ConsentFormGate();
    g.beginSession();
    expect(g.active, isTrue); // bilgi güncellemesi bekleniyor
    expect(g.tryShow(foreground: true), isTrue);
    expect(g.busy, isTrue);
    expect(g.active, isTrue);
    expect(g.tryShow(foreground: true), isFalse);
    g.finished();
    expect(g.busy, isFalse);
    expect(g.active, isFalse);
  });

  test('arka plandayken form gösterilmez, bekler; öne gelince en çok bir kez gösterilir', () {
    final ConsentFormGate g = ConsentFormGate();
    g.beginSession();
    expect(g.tryShow(foreground: false), isFalse);
    expect(g.pending, isTrue);
    expect(g.active, isFalse, reason: 'ertelenen form oyun başlatmayı bekletmez');
    expect(g.retryPending(foreground: false), isFalse);
    expect(g.retryPending(foreground: true), isTrue); // ön plana dönünce
    expect(g.pending, isFalse);
    g.finished();
    // sonraki her öne gelişte kendiliğinden yeni form tetiklenmez
    expect(g.retryPending(foreground: true), isFalse);
    expect(g.retryPending(foreground: true), isFalse);
  });

  test('oyun ekranı açıkken form gösterilmez; oyundan çıkınca bir kez gösterilir', () {
    final ConsentFormGate g = ConsentFormGate();
    g.beginSession();
    expect(g.tryShow(foreground: true, interruptible: false), isFalse);
    expect(g.pending, isTrue);
    expect(g.retryPending(foreground: true, interruptible: false), isFalse); // hâlâ oyunda
    expect(g.retryPending(foreground: true, interruptible: true), isTrue);
    g.finished();
    expect(g.retryPending(foreground: true, interruptible: true), isFalse);
  });

  test('form meşgulken öne gelmek ya da oyundan çıkmak ikinci form açmaz', () {
    final ConsentFormGate g = ConsentFormGate();
    g.beginSession();
    expect(g.tryShow(foreground: true), isTrue);
    expect(g.retryPending(foreground: true), isFalse);
    expect(g.tryShow(foreground: false), isFalse);
    g.finished();
  });

  test('hiç form istenmediyse öne gelmek form tetiklemez', () {
    final ConsentFormGate g = ConsentFormGate();
    g.beginSession();
    expect(g.retryPending(foreground: true), isFalse);
    expect(g.pending, isFalse);
  });

  test('bilgi güncellemesi hata verirse akış sürüyor sayılmaz', () {
    final ConsentFormGate g = ConsentFormGate();
    g.beginSession();
    expect(g.active, isTrue);
    g.updateFailed();
    expect(g.active, isFalse);
  });
}
