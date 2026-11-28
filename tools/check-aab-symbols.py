#!/usr/bin/env python3
"""1.2.4: AAB içindeki yerel (native) kütüphanelerin hata ayıklama sembollerini denetler (Play "native debug symbols" uyarısı).

Kullanım: python3 tools/check-aab-symbols.py <app-release.aab>

Her ABI için base/lib/<abi>/*.so dosyalarını ve BUNDLE-METADATA/com.android.tools.build.debugsymbols/<abi>/*.so.sym|.dbg
dosyalarını eşleştirir. Play Console sembolleri AAB'nin içinden kendisi alır; ayrı yükleme gerekmez.
  - libflutter.so (motor) ve libapp.so (oyun kodu) sembolü YOKSA hata (çıkış 1).
  - Başka kütüphanelerin (eklentilerin hazır derlenmiş .so dosyaları) sembolü yoksa yalnızca uyarı: bunlar kütüphaneyle
    sembolsüz gelir, bizim derlememiz üretemez.
GitHub Actions'ta özet $GITHUB_STEP_SUMMARY dosyasına da yazılır.
"""
import os
import sys
import zipfile

LIB = 'base/lib/'
META = 'BUNDLE-METADATA/com.android.tools.build.debugsymbols/'
REQUIRED = ('libflutter.so', 'libapp.so')


def main(path):
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
    libs = {}
    for n in names:
        if n.startswith(LIB) and n.endswith('.so'):
            abi, so = n[len(LIB):].split('/', 1)
            libs.setdefault(abi, set()).add(so)
    syms = {}
    for n in names:
        if n.startswith(META) and (n.endswith('.so.sym') or n.endswith('.so.dbg')):
            abi, f = n[len(META):].split('/', 1)
            syms.setdefault(abi, set()).add(f.rsplit('.', 1)[0])
    lines = ['### AAB native debug sembolleri', '', '| ABI | kütüphane | sembol |', '|---|---|---|']
    errors, warns = [], []
    for abi in sorted(libs):
        for so in sorted(libs[abi]):
            ok = so in syms.get(abi, set())
            lines.append(f'| {abi} | {so} | {"var" if ok else "YOK"} |')
            if not ok:
                (errors if so in REQUIRED else warns).append(f'{abi}/{so}')
    if not libs:
        lines.append('| - | (yerel kütüphane yok) | - |')
    report = '\n'.join(lines)
    print(report)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write(report + '\n')
    for w in warns:
        print(f'::warning title=Sembolsüz yerel kütüphane::{w} için AAB içinde hata ayıklama sembolü yok (hazır derlenmiş eklenti kütüphanesi olabilir).')
    for e in errors:
        print(f'::error title=Sembol eksik::{e} için AAB içinde hata ayıklama sembolü yok.')
    return 1 if errors else 0


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
