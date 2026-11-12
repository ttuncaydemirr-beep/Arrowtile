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
