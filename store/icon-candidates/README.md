# Simge adayı — "Kum ve Mürekkep" (1.2.1, docs/27 §B4)

Uygulama başlatıcı simgesi 1.2.1'de **DEĞİŞTİRİLMEDİ** (Android `mipmap-*` ve `store/play-icon-512.png` aynı). Bu klasör, ileride
Play Console **Mağaza girişi denemesi** (Store listing experiment) ile mevcut mavi simgeye karşı denenecek adaydır.

| Dosya | Ne |
|---|---|
| `icon-512.png` | Play mağaza simgesi adayı, 512x512, 32 bit, saydamlık yok, tam taşan kare (Play köşeleri kendisi yuvarlar) |
| `icon-512.svg` | yukarıdakinin kaynağı |
| `adaptive-foreground.svg` / `-432.png` | Android uyarlanabilir simge ön plan katmanı (108 dp = 432 px, saydam; öğeler 66 dp güvenli dairede) |
| `adaptive-background.svg` / `-432.png` | arka plan katmanı (mürekkep #22252B → #343943 ışınsal geçiş) |
| `preview-masks.png` | daire ve yuvarlak kare maskeli önizleme |

Renkler oyunla aynı (`game/js/theme.js`, `lib/ui/tokens.dart`): kum tahta #FBF9F5, kenar #D8D0C3, hücre #EEE8DE, turkuaz ok #1F8A8A,
kiremit ok #E0703C, zemin mürekkep #22252B. Çizim mevcut simgeyle aynı (2x2 tahta, yukarı ok + tahtadan kaçan ok); yalnızca palet değişti.

Deneme önerisi: Play Console › Büyüme › Mağaza girişi denemeleri › varsayılan grafikler › Simge; %50 / %50, en az 7 gün, ölçüt
"ilk kez yükleyenler" (dönüşüm). Kazanırsa simge ayrı bir sürümde uygulamaya da (mipmap + adaptive-icon) taşınır; PNG'ler
`node` + Playwright ile SVG'den yeniden üretilebilir.

## 1.2.2 durumu: mağaza görselleri yenilendi, simge denemeye hazır

- `store/feature-graphic-*.png` (4 dil) ve `store/screenshots/<dil>/` (24 adet) "Kum ve Mürekkep" paletiyle yeniden üretildi:
  `python3 tools/android/make-store-assets.py`. Özellik grafiği renkleri `design/colors.json`'dan okur, tahta ve oklar bu klasördeki
  adaydan alınır, yazı tipi Readex Pro'dur (Arapça dahil). Ekran görüntüleri gerçek oyundandır; menüdeki logo, simge kararı
  verilene dek yayındaki kobalt simgedir.
- Başlatıcı simgesi ve `store/play-icon-512.png` **değişmedi**. Karar: önce Play mağaza denemesi (sahip onayı, 1.2.2).

### Deneme adımları (Play Console)
1. Büyüme › Mağaza girişi denemeleri › **Varsayılan grafikler denemesi oluştur**.
2. Deneme özelliği: **Uygulama simgesi**. Varyant A: mevcut (`store/play-icon-512.png`). Varyant B: `store/icon-candidates/icon-512.png`.
3. Hedef kitle: %50 / %50. Ölçüt: **İlk kez yükleyenler** (elde tutulanlar değil). En az 7 gün, tercihen 14.
4. Sonuç: B anlamlı biçimde kazanırsa ayrı bir sürümde simgeyi uygulamaya taşıyın (`tools/android/make-icons.py` adaptive katmanlar +
   `game/assets/icon.svg`), sonra `make-store-assets.py` ile ekran görüntülerini yeniden üretin. Kaybederse ya da fark yoksa mevcut simge kalır.
