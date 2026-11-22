#!/usr/bin/env python3
"""Play mağaza girişi GÖRSELLERİNİ (yalnızca görseller, metin alanlarına dokunmaz) Google Play Developer API ile yükler.

Her dil (tr-TR, en-US, de-DE, ar) için: edit oluştur -> phoneScreenshots deleteall + 6 görsel yükle,
featureGraphic deleteall + 1 görsel yükle -> edit commit.
Kaynak: store/screenshots/<tr|en|de|ar>/01..06-*.png (1080x1920) ve store/feature-graphic-<dil>.png (1024x500).

env: PLAY_SA_JSON  (dry-run dışında zorunlu), DRY_RUN (varsayılan "true": yalnızca doğrular ve listeler, API'yi ÇAĞIRMAZ),
     HOLD (true = otomatik incelemeye gönderme isteği; Play izin vermezse yok sayılır, play_promote.py ile aynı kural).
Doğrulama: PNG başlığı (saf Python), boyut, <= 8 MB, alfa kanalı yok (Play 24 bit PNG ister), adet (6 + 1).
Servis hesabının Play Console'da ilgili uygulama için "Mağaza girişini yönet" (Manage store presence) izni olmalı.
"""
import glob, json, os, struct, sys

PKG = "com.arrowtile.puzzle"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STORE = os.path.join(ROOT, "store")
LANGS = [("tr-TR", "tr"), ("en-US", "en"), ("de-DE", "de"), ("ar", "ar")]  # (Play dili, dosya klasörü/eki)
SHOT_SIZE, FEATURE_SIZE, MAX_BYTES, N_SHOTS = (1080, 1920), (1024, 500), 8 * 1024 * 1024, 6


def png_info(path):
    """(genişlik, yükseklik, renk_tipi) — yalnızca PNG başlığını okur; PNG değilse ValueError."""
    with open(path, "rb") as f:
        head = f.read(33)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise ValueError("PNG değil")
    w, h = struct.unpack(">II", head[16:24])
    return w, h, head[25]


def check(path, size):
    errs = []
    try:
        w, h, ct = png_info(path)
    except (ValueError, OSError) as e:
        return [f"{path}: {e}"]
    if (w, h) != size:
        errs.append(f"{path}: boyut {w}x{h}, beklenen {size[0]}x{size[1]}")
    if ct in (4, 6):
        errs.append(f"{path}: alfa kanalı var (Play 24 bit PNG ister)")
    n = os.path.getsize(path)
    if n > MAX_BYTES:
        errs.append(f"{path}: {n / 1048576:.1f} MB > 8 MB")
    return errs


def collect():
    """{play_dili: {'shots': [yollar], 'feature': yol}} ve hata listesi."""
    plan, errs = {}, []
    for lang, d in LANGS:
        shots = sorted(glob.glob(os.path.join(STORE, "screenshots", d, "0[1-6]-*.png")))
        feat = os.path.join(STORE, f"feature-graphic-{d}.png")
        if len(shots) != N_SHOTS:
            errs.append(f"{lang}: {len(shots)} ekran görüntüsü bulundu, beklenen {N_SHOTS}")
        if not os.path.isfile(feat):
            errs.append(f"{lang}: {feat} yok")
        for s in shots:
            errs += check(s, SHOT_SIZE)
        if os.path.isfile(feat):
            errs += check(feat, FEATURE_SIZE)
        plan[lang] = {"shots": shots, "feature": feat}
    return plan, errs


def main():
    plan, errs = collect()
    dry = (os.environ.get("DRY_RUN", "true").strip().lower() != "false")
    for lang, p in plan.items():
        print(f"{lang}: phoneScreenshots x{len(p['shots'])}, featureGraphic x1")
        for f in p["shots"] + [p["feature"]]:
            print("   ", os.path.relpath(f, ROOT), f"({os.path.getsize(f) // 1024} KB)" if os.path.isfile(f) else "(yok)")
    if errs:
        for e in errs:
            print("::error::" + e)
        sys.exit(1)
    if dry:
        print("DRY_RUN: dosyalar geçerli; API çağrılmadı, commit yapılmadı.")
        return

    import google.auth.transport.requests as gr
    import google.oauth2.service_account as sa
    import requests

    cred = sa.Credentials.from_service_account_info(
        json.loads(os.environ["PLAY_SA_JSON"]), scopes=["https://www.googleapis.com/auth/androidpublisher"])
    cred.refresh(gr.Request())
    h = {"Authorization": "Bearer " + cred.token}
    base = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}/edits"
    up = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}/edits"

    def ok(r):
        if not r.ok:
            print("::error::" + r.text)
            r.raise_for_status()
        return r

    eid = ok(requests.post(base, headers=h)).json()["id"]
    for lang, p in plan.items():
        for kind, files in (("phoneScreenshots", p["shots"]), ("featureGraphic", [p["feature"]])):
            ok(requests.delete(f"{base}/{eid}/listings/{lang}/{kind}", headers=h))
            for f in files:
                with open(f, "rb") as fh:
                    r = requests.post(f"{up}/{eid}/listings/{lang}/{kind}", headers={**h, "Content-Type": "image/png"},
                                      params={"uploadType": "media"}, data=fh.read())
                ok(r)
                print(f"yüklendi {lang} {kind} {os.path.basename(f)}")
    hold = (os.environ.get("HOLD") or "").lower() == "true"
    r = requests.post(f"{base}/{eid}:commit", headers=h, params={"changesNotSentForReview": "true"} if hold else {})
    auto = False
    if r.status_code == 400 and "must not be set" in r.text:
        print("::notice title=Otomatik inceleme::Play bu uygulamada değişiklikleri otomatik incelemeye gönderiyor; parametresiz commit ediliyor.")
        r = requests.post(f"{base}/{eid}:commit", headers=h)
        auto = True
    ok(r)
    print(f"Mağaza görselleri yüklendi (edit {r.json().get('id')})"
          + ("; incelemeye otomatik gönderildi." if auto or not hold else "; incelemeye gönderilmedi (Yayın özeti → Gönder)."))


if __name__ == "__main__":
    main()
