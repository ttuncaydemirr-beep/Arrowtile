# Arrowtile — Mağaza metinleri (Google Play, 4 dil)

Kaynak: `game/js/i18n.js` (`store.title`, `store.short`, `store.long`). Bu belge oradan üretildi; metin değişirse önce i18n.js güncellenir, `node tools/validate-i18n.js` sınırları denetler (başlık ≤ 30, kısa açıklama ≤ 80, uzun açıklama ≤ 4000 karakter).

Öne çıkan üç vaat (v1.3, docs/09): **süre sınırı yok**, **internetsiz oynanır**, **gerçekten zorlu bulmacalar** (18 bölümde 216 seviye ve ardından sonsuz bölümler, Kolay → Orta → Zor → Aşırı zor döngüsü, 20x28'e varan dolu tahtalar, kıvrımlı yılan oklar, her gün yeni günlük bulmaca). "Geri alma var" vaadi geri alma kaldırıldığı için çıkarıldı; "veri toplamaz" ifadesi reklam nedeniyle kullanılmaz.

## Özet

| Dil | Başlık | Karakter | Kısa açıklama | Karakter | Uzun açıklama |
|---|---|---|---|---|---|
| tr | Arrowtile: Ok Bulmacası | 23/30 | Süre yok, internetsiz: 216 zorlu seviye, sonra sonsuz bölüm ve günlük bulmaca! | 78/80 | 1855/4000 |
| en | Arrowtile: Arrow Puzzle | 23/30 | No timers, no internet: 216 tough levels, endless chapters and a daily puzzle! | 78/80 | 1966/4000 |
| de | Arrowtile: Pfeil-Rätsel | 23/30 | Kein Zeitlimit, ohne Internet: 216 knifflige Level, dann endlos und täglich neu! | 80/80 | 2158/4000 |
| ar | Arrowtile: لغز الأسهم | 21/30 | بلا وقت محدد، بلا إنترنت: 216 مستوى صعبًا ثم فصول لا تنتهي ولغز جديد كل يوم! | 76/80 | 1650/4000 |

## Play Console notları

- Uygulama adı: **Arrowtile** (tüm dillerde Latin harfle). Paket adı önerisi: `com.arrowtile.puzzle` (yayından önce doğrulanacak).
- Kategori: Oyun › Bulmaca. Hedef kitle: genel (her yaş); çocuklara yönelik "Aile" programına girilmiyor.
- "Reklam içerir": **Evet** (yalnızca seviye sonu geçiş reklamı + isteğe bağlı ödüllü reklam, AdMob). "Uygulama içi satın alma": **Evet** (`remove_ads`, tüketilmeyen, tek seferlik).
- Gizlilik politikası URL'si: `game/privacy.html` bir web adresinde yayımlanıp girilmeli (sayfa 4 dilde, `?lang=tr|en|de|ar`). Veri güvenliği formu AdMob (reklam kimliği, cihaz/uygulama bilgileri, IP) için doldurulmalı.
- Destek e-postası: nilkaren.tuncay.demir@gmail.com

## Türkçe (tr-TR)

**Başlık (23/30):** Arrowtile: Ok Bulmacası

**Kısa açıklama (78/80):** Süre yok, internetsiz: 216 zorlu seviye, sonra sonsuz bölüm ve günlük bulmaca!

**Uzun açıklama (1855/4000):**

```
Arrowtile sakin ve akıllı bir ok bulmacası. Tahtadaki bir oka dokun; ok baktığı yöne kayar. Yolu açıksa tahtadan kaçar, önünde başka bir ok varsa çarpıp geri döner. Doğru sırayı bul ve tahtayı boşalt!

NEDEN ARROWTILE?
• Süre sınırı yok: Hiçbir seviyede geri sayım yok. İstediğin kadar düşün.
• İnternetsiz oynanır: Uçakta, metroda, yaylada… Bütün bulmacalar cihazında.
• Gerçekten zorlu bulmacalar: 20x28’e varan dolu tahtalar, kıvrımlı yılan oklar, yüzlerce ince ok ve her gün yeni bir günlük bulmaca. Her çarpışma bir can götürür; acele etme, düşün.

İÇİNDEKİLER
• 18 bölümde 216 seviye, ardından sonsuz bölümler: Kolay, Orta, Zor ve Aşırı zor bölümler döngü halinde gelir, tahta her bölümde biraz büyür.
• Dürüst zorluk etiketleri: Kolay, Orta, Zor, Aşırı zor. Her bölümün kademesi çözücünün ölçtüğü doluluk, başta çıkabilen ok oranı ve derinlikle doğrulanır; Aşırı zor bölümler haritada ayrıca işaretlidir ve daha çok jeton verir.
• Günlük bulmaca: Her gün yeni bir bulmaca, seri sayacı ve kupa takvimi.
• İpucu: O an çıkabilecek en akıllı oku gösterir.
• Rahat mod: Can yok, yalnızca bulmaca.
• Dokunma koruması ve “Önce seç, sonra fırlat” seçeneği: Komşu oka yanlışlıkla dokunmak tarih oluyor.
• İki parmakla 4 kata kadar yakınlaştır; tek dokunuşla tahtayı ekrana sığdır.
• Ok temaları: Emaye, Lokum, Çini, Bakır ve Gece Lambası.
• Açık, koyu ya da otomatik görünüm.
• Türkçe, İngilizce, Almanca ve Arapça (sağdan sola tam destek).
• İlerlemeni bir kodla dışa aktar, yeni cihazında içe aktar.

ADİL OYUN
Seviye aralarındaki reklamlar en erken üç seviyede bir ve en az üç dakika arayla gelir. İlk bölüm tamamen reklamsızdır; seviye ortasında asla reklam yoktur. İstersen reklamları tek seferlik bir satın alımla kalıcı olarak kaldırabilirsin. Ödüllü reklamlar her zaman isteğe bağlıdır.

Soruların ve önerilerin için: nilkaren.tuncay.demir@gmail.com
```

## English (en-US)

**Başlık (23/30):** Arrowtile: Arrow Puzzle

**Kısa açıklama (78/80):** No timers, no internet: 216 tough levels, endless chapters and a daily puzzle!

**Uzun açıklama (1966/4000):**

```
Arrowtile is a calm, clever arrow puzzle. Tap an arrow and it slides the way it points. If the path is clear it escapes the board; if another arrow is in the way it bumps and slides back. Find the right order and clear the board!

WHY ARROWTILE?
• No timers: There is no countdown in any level. Take all the time you need.
• Play without internet: On a plane, on the subway, in the mountains… every puzzle lives on your device.
• Genuinely tough puzzles: packed boards up to 20×28, bending snake arrows, hundreds of slim arrows and a fresh daily puzzle every day. Every crash costs a life, so take your time and think.

WHAT’S INSIDE
• 216 levels across 18 chapters, then endless chapters: Easy, Medium, Hard and Very hard chapters come in a cycle, and the board grows a little every chapter.
• Honest difficulty labels: Easy, Medium, Hard, Very hard. Each chapter’s tier is verified by our solver from density, the share of arrows free at the start and depth; Very hard chapters are marked on the map and pay more coins.
• Daily puzzle: a fresh puzzle every day, a streak counter and a trophy calendar.
• Hints that highlight the smartest arrow you can move right now.
• Relaxed mode: no lives, just the puzzle.
• Tap protection and an optional “Select, then launch” mode, so no more accidental taps on the neighbouring arrow.
• Pinch to zoom up to 4×; fit the whole board back with one tap.
• Arrow themes: Enamel, Delight, Tile, Copper and Night Light.
• Light, dark or automatic appearance.
• Turkish, English, German and Arabic (full right-to-left support).
• Export your progress as a code and import it on a new device.

FAIR PLAY
Ads between levels appear at most once every three levels and at least three minutes apart. The first chapter is completely ad-free, and there are never ads in the middle of a level. If you like, remove ads for good with a one-time purchase. Rewarded ads are always optional.

Questions or ideas? nilkaren.tuncay.demir@gmail.com
```

## Deutsch (de-DE)

**Başlık (23/30):** Arrowtile: Pfeil-Rätsel

**Kısa açıklama (80/80):** Kein Zeitlimit, ohne Internet: 216 knifflige Level, dann endlos und täglich neu!

**Uzun açıklama (2158/4000):**

```
Arrowtile ist ein ruhiges, cleveres Pfeil-Rätsel. Tippe auf einen Pfeil, und er gleitet in seine Richtung. Ist der Weg frei, verlässt er das Brett; steht ein anderer Pfeil im Weg, stößt er an und gleitet zurück. Finde die richtige Reihenfolge und räume das Brett leer!

WARUM ARROWTILE?
• Kein Zeitlimit: In keinem Level läuft ein Countdown. Denk so lange nach, wie du willst.
• Ohne Internet spielbar: Im Flugzeug, in der U-Bahn, in den Bergen… alle Rätsel sind auf deinem Gerät.
• Richtig knifflig: volle Bretter bis 20×28, gebogene Schlangenpfeile, Hunderte schmale Pfeile und jeden Tag ein neues Tagesrätsel. Jeder Zusammenstoß kostet ein Leben – lass dir Zeit und denk nach.

DAS ERWARTET DICH
• 216 Level in 18 Kapiteln, danach endlose Kapitel: Leichte, mittlere, schwere und sehr schwere Kapitel wechseln sich ab, und das Brett wächst mit jedem Kapitel ein wenig.
• Ehrliche Schwierigkeitsangaben: Leicht, Mittel, Schwer, Sehr schwer. Die Stufe jedes Kapitels prüft unser Löser anhand von Dichte, Anteil der anfangs freien Pfeile und Tiefe; sehr schwere Kapitel sind auf der Karte markiert und bringen mehr Münzen.
• Tagesrätsel: jeden Tag ein neues Rätsel, eine Serienzählung und ein Pokal-Kalender.
• Tipps, die den klügsten Pfeil zeigen, der gerade herauskann.
• Entspannter Modus: keine Leben, nur das Rätsel.
• Tippschutz und die Option „Erst wählen, dann starten“: kein versehentliches Antippen des Nachbarpfeils mehr.
• Mit zwei Fingern bis 4× zoomen, mit einem Tipp das ganze Brett wieder einpassen.
• Pfeil-Designs: Emaille, Lokum, Fliese, Kupfer und Nachtlicht.
• Helle, dunkle oder automatische Darstellung.
• Türkisch, Englisch, Deutsch und Arabisch (volle Rechts-nach-links-Unterstützung).
• Fortschritt als Code exportieren und auf einem neuen Gerät importieren.

FAIR GESPIELT
Werbung zwischen den Levels erscheint höchstens alle drei Level und mit mindestens drei Minuten Abstand. Das erste Kapitel ist komplett werbefrei, und mitten im Level gibt es nie Werbung. Wenn du möchtest, entfernst du die Werbung dauerhaft mit einem einmaligen Kauf. Belohnungswerbung ist immer freiwillig.

Fragen oder Ideen? nilkaren.tuncay.demir@gmail.com
```

## العربية (ar)

**Başlık (21/30):** Arrowtile: لغز الأسهم

**Kısa açıklama (76/80):** بلا وقت محدد، بلا إنترنت: 216 مستوى صعبًا ثم فصول لا تنتهي ولغز جديد كل يوم!

**Uzun açıklama (1650/4000):**

```
Arrowtile لغز أسهم هادئ وذكي. المس سهمًا فينزلق في الاتجاه الذي يشير إليه. إذا كان الطريق مفتوحًا يخرج من اللوحة، وإذا اعترضه سهم آخر يصطدم به ويعود. اعثر على الترتيب الصحيح وأفرغ اللوحة!

لماذا Arrowtile؟
• بلا وقت محدد: لا يوجد عدّ تنازلي في أي مستوى. فكّر كما تشاء.
• تلعب بلا إنترنت: في الطائرة أو المترو أو الجبال… كل الألغاز على جهازك.
• ألغاز صعبة فعلًا: لوحات ممتلئة حتى 20×28، وأسهم منحنية كالأفعى، ومئات الأسهم الرفيعة، ولغز يومي جديد كل يوم. كل اصطدام يكلّفك روحًا، فلا تستعجل وفكّر.

ماذا ستجد؟
• 216 مستوى في 18 فصلًا، ثم فصول لا تنتهي: فصول سهلة ومتوسطة وصعبة وصعبة جدًا تتوالى في دورة، وتكبر اللوحة قليلًا مع كل فصل.
• تصنيفات صعوبة صادقة: سهل، متوسط، صعب، صعب جدًا. يتحقق برنامج الحل من مستوى كل فصل عبر الكثافة ونسبة الأسهم الحرة في البداية والعمق؛ والفصول الصعبة جدًا مميزة على الخريطة وتمنح عملات أكثر.
• لغز اليوم: لغز جديد كل يوم، مع عدّاد للسلسلة وتقويم للكؤوس.
• تلميحات تُبرز أذكى سهم يمكنه الخروج الآن.
• الوضع المريح: بلا أرواح، اللغز فقط.
• حماية من اللمس الخاطئ وخيار «اختر أولًا ثم أطلق»: لا مزيد من لمس السهم المجاور بالخطأ.
• كبّر بإصبعين حتى 4 أضعاف، وأعد اللوحة كاملة بلمسة واحدة.
• أشكال الأسهم: مينا، راحة الحلقوم، قيشاني، نحاس، ضوء الليل.
• مظهر فاتح أو داكن أو تلقائي.
• التركية والإنجليزية والألمانية والعربية (دعم كامل للكتابة من اليمين إلى اليسار).
• صدّر تقدّمك برمز واستورده على جهاز جديد.

لعب عادل
تظهر الإعلانات بين المستويات مرة كل ثلاثة مستويات على الأكثر، وبفاصل ثلاث دقائق على الأقل. الفصل الأول خالٍ تمامًا من الإعلانات، ولا تظهر الإعلانات أبدًا في منتصف المستوى. يمكنك إزالة الإعلانات نهائيًا بشراء لمرة واحدة. الإعلانات بمكافأة اختيارية دائمًا.

لديك سؤال أو اقتراح؟ nilkaren.tuncay.demir@gmail.com
```
