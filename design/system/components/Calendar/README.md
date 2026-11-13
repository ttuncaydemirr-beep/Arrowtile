# Calendar
Günlük bulmaca takvimi: ayın günleri, çözülen günler yıldızlı.

**Tüketicinin sağladığı:** 7 sütunlu ızgarada hafta günü başlıkları (`.at-cal-wd`, 11/700) ve gün hücreleri; üstte `IconButton` + ay başlığı + `IconButton` (48 px / 1fr / 48 px).
- Gün: kare, `cell`, `radius-sm`. `.done` `star` %28 tonu + yıldız simgesi; `.today` 3 px `accent` iç çerçeve; `.future` %45 opaklık; `.empty` saydam.
- Hafta Pazartesi başlar; rakamlar Batı rakamı.
