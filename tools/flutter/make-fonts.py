# Arrowtile -> Flutter: Readex Pro değişken yazı tipinden (game/assets/fonts/ReadexPro-VF.ttf, SIL OFL 1.1) sabit ağırlıklı
# örnekler üretir: flutter/arrowtile/assets/fonts/ReadexPro-{Regular,Medium,SemiBold,Bold}.ttf (wght 400/500/600/700, HEXP 0).
# Neden: Flutter'da FontWeight değişken yazı tipinin wght eksenini her sürümde kendiliğinden uygulamaz; sabit örnekler her
# cihazda aynı kalınlığı verir. OFL 1.1 değiştirilmiş sürümlerin dağıtımına izin verir (aile adı aynı kalır: Ayrılmış Yazı Tipi
# Adı yok). Lisans: flutter/arrowtile/assets/fonts/OFL.txt (uygulamada Lisanslar sayfasına eklenir, main.dart).
# Kullanım (proje kökünden): python3 tools/flutter/make-fonts.py   (gerekli: pip install fonttools)
import os
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
SRC = os.path.join(ROOT, 'game', 'assets', 'fonts', 'ReadexPro-VF.ttf')
OUT = os.path.join(ROOT, 'flutter', 'arrowtile', 'assets', 'fonts')
os.makedirs(OUT, exist_ok=True)
for name, w in (('Regular', 400), ('Medium', 500), ('SemiBold', 600), ('Bold', 700)):
    f = TTFont(SRC)
    inst = instantiateVariableFont(f, {'wght': w, 'HEXP': 0}, updateFontNames=True)
    dst = os.path.join(OUT, 'ReadexPro-%s.ttf' % name)
    inst.save(dst)
    print('%s: %d KB' % (os.path.relpath(dst, ROOT), os.path.getsize(dst) // 1024))
