// Arrowtile — rng.dart: levelgen.js'teki tohumlu RNG (mulberry32 türevi) ve FNV-1a özetinin Dart karşılığı.
//
// ÖNEMLİ — BİREBİR AYNI SONUÇ GEREKİR: aynı tohum, web sürümüyle aynı seviyeyi/günlük bulmacayı üretmelidir.
// JS'te sayılar 32-bit işaretli/işaretsiz tamsayı kuralıyla işlenir (|0, >>>0, Math.imul). Dart'ta int 64-bit'tir
// (yalnızca Dart VM / Android'de; Dart-web'de int bir double'dır ve bu dosya orada GEÇERLİ DEĞİLDİR — hedef Android).
// Bu yüzden her işlemde 32-bit davranışı açıkça taklit edilir. Doğrulama: test/golden/*.json (JS'ten üretildi) —
// `flutter test` ile KULLANICI TARAFINDA yapılır; bu ortamda Dart derlenemediği için çalıştırılamadı.

/// JS `Math.imul(a, b)`: iki sayıyı 32-bit işaretli tamsayı gibi çarpıp alt 32 biti işaretli döndürür.
/// a ve b en çok 32 bitlik olduğundan a*b en çok 2^64'e yaklaşır; ancak her ikisi de işaretli 32-bit (|x| ≤ 2^31)
/// alındığında |a*b| ≤ 2^62 olur ve Dart'ın 64-bit int'ine sığar (taşma yok); alt 32 bit doğru kalır.
int imul(int a, int b) {
  final int x = a.toSigned(32); // JS: ToInt32(a)
  final int y = b.toSigned(32); // JS: ToInt32(b)
  return (x * y).toSigned(32); // JS: (x*y) mod 2^32, işaretli
}

/// levelgen.js `rng(seed)`: her çağrıda [0,1) aralığında double döndürür.
class Rng {
  /// JS: `seed |= 0` — durum her zaman işaretli 32-bit tutulur.
  int _seed;

  Rng(int seed) : _seed = seed.toSigned(32);

  double next() {
    // JS: seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    _seed = (_seed + 0x6D2B79F5).toSigned(32); // (seed + C) | 0
    final int seed = _seed;
    // JS: var t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    //   `seed >>> 15`: seed önce uint32'ye çevrilir, sonra mantıksal kaydırılır → (seed & 0xFFFFFFFF) >> 15
    //   `seed ^ (...)`: ToInt32 sonucu işaretli; imul zaten ToInt32 uyguladığı için işaretsiz kalması sorun değildir.
    //   `1 | seed`: işaretli 32-bit OR.
    int t = imul(seed ^ ((seed & 0xFFFFFFFF) >> 15), 1 | seed);
    // JS: t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    //   önce toplama (çift hassasiyetli, taşmaz), sonra `^` ToInt32 uygular → toplamı 32 bite sar, sonra t ile XOR.
    //   `t >>> 7`: t'nin uint32 hali sağa kaydırılır.
    final int m2 = imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t);
    t = ((t + m2).toSigned(32)) ^ t; // (t + m2) → ToInt32, sonra ^ t (ikisi de işaretli 32-bit; sonuç işaretli 32-bit)
    // JS: return ((t ^ t >>> 14) >>> 0) / 4294967296;
    //   `t >>> 14`: uint32 kaydırma; `^` sonucu işaretli; `>>> 0` işaretsize çevirir.
    final int u = (t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF; // >>> 0
    return u / 4294967296.0;
  }
}

/// levelgen.js `hash(str)`: 32-bit FNV-1a, işaretsiz sonuç.
int fnv32(String str) {
  int h = 0x811c9dc5; // JS: var h = 0x811c9dc5 (işaretsiz görünür; ilk XOR'da ToInt32 olur)
  for (final int c in str.codeUnits) {
    // JS: h ^= str.charCodeAt(i);  → UTF-16 kod birimi
    h = (h ^ c) & 0xFFFFFFFF;
    // JS: h = Math.imul(h, 0x01000193);  → alt 32 bit; burada işaretsiz tutuyoruz (alt 32 bit aynıdır)
    h = imul(h, 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0xFFFFFFFF; // JS: h >>> 0
}
