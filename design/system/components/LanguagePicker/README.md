# LanguagePicker
Ayarlar › Dil bölümündeki 2 × 2 dil düğmeleri.

**Tüketicinin sağladığı:** `.at-langs` içinde her dil için `<button class="at-lang-btn" lang="…" aria-pressed="…">`; dil adı **kendi dilinde** yazılır (Türkçe, English, Deutsch, العربية). Arapça düğmeye `dir="rtl"`.

- Düğme 52 px, `cell` dolgu, `radius-btn`, 700 ağırlık. Seçili: `board` dolgu + 2 px `accent` kenar (yalnızca renk değil, kenar da değişir).
- Arapça düğme `arabic` yığınıyla çizilir; uygulama dili değişince `<html lang dir>` ve yazı ölçeği (`×1,08`, satır 1,55) güncellenir.
- Seçim anında uygulanır, onay penceresi yoktur.
