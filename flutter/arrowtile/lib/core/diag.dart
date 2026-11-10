// Arrowtile — diag.dart: cihaz üstü tanılama kaydı (1.1.4, docs/21). Saf Dart.
//
// Gerçek cihazda (gerçek AdMob birimleri) görülen ama emülatörde üretilemeyen hataları (seviye ortasında reklam, ses ölmesi,
// banner görünmemesi) görebilmek için son ~200 olayı BELLEKTE tutar. Ayarlar > sürüm metnine 7 kez dokununca açılan "Tanılama"
// ekranı bu kaydı gösterir; sahibi "Kopyala" / "Paylaş" ile bize gönderir.
//
// Gizlilik: yalnızca olay adları, sayılar, sabit sözcükler ve reklam SDK hata kodları/iletileri yazılır. Kullanıcı kimliği, e-posta,
// kayıt kodu, cihaz kimliği, reklam kimliği YAZILMAZ. Kayıt diske yazılmaz, hiçbir yere kendiliğinden gönderilmez.
import 'dart:collection';

class DiagEntry {
  final int wallMs; // duvar saati (yerel saat gösterimi için)
  final int upMs; // uygulama açılışından beri (monoton)
  final String cat; // ad | banner | level | audio | app | ui
  final String msg;
  final Map<String, Object?> f;
  const DiagEntry(this.wallMs, this.upMs, this.cat, this.msg, this.f);

  static String _two(int v) => v.toString().padLeft(2, '0');

  String get clock {
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(wallMs);
    return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  String toString() {
    final String extra = f.isEmpty ? '' : ' ${f.entries.map((MapEntry<String, Object?> e) => '${e.key}=${e.value}').join(' ')}';
    return '$clock +${(upMs / 1000).toStringAsFixed(1)}s [$cat] $msg$extra';
  }
}

class DiagLog {
  DiagLog({this.capacity = 200, this.playCapacity = 30, int Function()? wall})
      : _wall = wall ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _up.start();
  }

  /// Uygulama genelindeki tek kayıt.
  static final DiagLog I = DiagLog();

  final int capacity;
  final int playCapacity;
  final int Function() _wall;
  final Stopwatch _up = Stopwatch();
  final ListQueue<DiagEntry> _q = ListQueue<DiagEntry>();
  final ListQueue<DiagEntry> _plays = ListQueue<DiagEntry>(); // ses çalma olayları ayrı halka: reklam olaylarını itip çıkarmasın
  final Map<String, int> counters = <String, int>{};

  static Object? _clean(Object? v) {
    if (v == null || v is num || v is bool) return v;
    String s = '$v'.replaceAll(RegExp(r'\s+'), ' ');
    if (s.length > 120) s = '${s.substring(0, 117)}...';
    return s;
  }

  void add(String cat, String msg, [Map<String, Object?>? f]) {
    try {
      final Map<String, Object?> m = <String, Object?>{
        if (f != null)
          for (final MapEntry<String, Object?> e in f.entries) e.key: _clean(e.value)
      };
      final DiagEntry e = DiagEntry(_wall(), _up.elapsedMilliseconds, cat, msg, m);
      final ListQueue<DiagEntry> q = (cat == 'audio' && msg == 'play') ? _plays : _q;
      final int cap = identical(q, _plays) ? playCapacity : capacity;
      q.addLast(e);
      while (q.length > cap) {
        q.removeFirst();
      }
      count('$cat.$msg');
    } catch (_) {}
  }

  void count(String key) => counters[key] = (counters[key] ?? 0) + 1;

  List<DiagEntry> get entries => List<DiagEntry>.unmodifiable(_q);
  List<DiagEntry> get plays => List<DiagEntry>.unmodifiable(_plays);

  /// Son [n] olay içinde [cat]/[msg] eşleşenler (testler için).
  Iterable<DiagEntry> where(String cat, [String? msg]) =>
      _q.where((DiagEntry e) => e.cat == cat && (msg == null || e.msg == msg));

  void clear() {
    _q.clear();
    _plays.clear();
    counters.clear();
  }

  /// Gönderilecek metin: başlık (sürüm vb.), sayaçlar, son olaylar (eskiden yeniye), son ses çalmaları.
  String dump({Map<String, Object?> header = const <String, Object?>{}}) {
    final StringBuffer b = StringBuffer();
    b.writeln('Arrowtile diagnostics');
    for (final MapEntry<String, Object?> e in header.entries) {
      b.writeln('${e.key}: ${_clean(e.value)}');
    }
    b.writeln('uptime_s: ${(_up.elapsedMilliseconds / 1000).toStringAsFixed(0)}');
    final List<String> keys = counters.keys.toList()..sort();
    b.writeln('counters: ${keys.map((String k) => '$k=${counters[k]}').join(' ')}');
    b.writeln('--- events (${_q.length}/$capacity, oldest first)');
    for (final DiagEntry e in _q) {
      b.writeln(e.toString());
    }
    b.writeln('--- last sound plays (${_plays.length}/$playCapacity)');
    for (final DiagEntry e in _plays) {
      b.writeln(e.toString());
    }
    return b.toString();
  }
}

/// Kısayol: uygulama kaydına yaz. Asla istisna fırlatmaz.
void diag(String cat, String msg, [Map<String, Object?>? f]) => DiagLog.I.add(cat, msg, f);
