# Tool
Oyun ekranının altındaki araç çubuğu düğmesi: simge + kalın etiket + isteğe bağlı alt etiket.

**Tüketicinin sağladığı:** `.at-toolbar` (2 sütun ızgara) içinde `<button class="at-tool">`; içerik sırası `.at-ic`, `.at-tool-label`, `.at-tool-sub`.

- 72 px (oyun ekranında 56 px, satır düzeni), `radius-tool` 16 px, `raise-4`.
- Alt etiket `ink-soft`; ücretsiz hak varsa `.free` ile `success`.
- `.pulse`: ipucu önerilirken `star` renginde nefes alan halka (900 ms). Azaltılmış harekette kapanır.
