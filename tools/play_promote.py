#!/usr/bin/env python3
"""İç teste yüklenmiş sürümü (pubspec versionCode) Play kapalı test (alpha) parçasına API ile yükseltir.

env: PLAY_SA_JSON (zorunlu), STATUS (completed|draft), HOLD (true = otomatik incelemeye gönderme),
     NOTES_DIR (whatsnew-<locale> dosyaları; isteğe bağlı)
Play bazı uygulamalarda değişiklikleri otomatik incelemeye gönderir ve changesNotSentForReview
parametresini reddeder ("must not be set"); bu durumda parametresiz yeniden commit edilir.
"""
import glob, json, os, re

import google.auth.transport.requests as gr
import google.oauth2.service_account as sa
import requests

PKG = "com.arrowtile.puzzle"
cred = sa.Credentials.from_service_account_info(
    json.loads(os.environ["PLAY_SA_JSON"]), scopes=["https://www.googleapis.com/auth/androidpublisher"])
cred.refresh(gr.Request())
h = {"Authorization": "Bearer " + cred.token}
base = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}/edits"

pub = open("flutter/arrowtile/pubspec.yaml", encoding="utf-8").read()
vc = re.search(r"^version:\s*[^+\s]+\+(\d+)", pub, re.M).group(1)
ver = re.search(r"^version:\s*([^+\s]+)", pub, re.M).group(1)

notes = []
d = os.environ.get("NOTES_DIR") or ""
for f in sorted(glob.glob(os.path.join(d, "whatsnew-*"))) if d else []:
    txt = open(f, encoding="utf-8").read().strip()
    if txt:
        notes.append({"language": os.path.basename(f)[len("whatsnew-"):], "text": txt[:500]})


def check(r):
    if not r.ok:
        print("::error::" + r.text)
        r.raise_for_status()
    return r


eid = check(requests.post(base, headers=h)).json()["id"]
rel = {"name": f"{vc} ({ver})", "versionCodes": [vc], "status": os.environ.get("STATUS") or "completed"}
if notes:
    rel["releaseNotes"] = notes
check(requests.put(f"{base}/{eid}/tracks/alpha", headers=h, json={"track": "alpha", "releases": [rel]}))

hold = (os.environ.get("HOLD") or "").lower() == "true"
r = requests.post(f"{base}/{eid}:commit", headers=h, params={"changesNotSentForReview": "true"} if hold else {})
auto = False
if r.status_code == 400 and "must not be set" in r.text:
    print("::notice title=Otomatik inceleme::Play bu uygulamada değişiklikleri otomatik incelemeye gönderiyor; parametresiz commit ediliyor.")
    r = requests.post(f"{base}/{eid}:commit", headers=h)
    auto = True
check(r)
print(f"Kapalı test (alpha): versionCode {vc} ({ver}) atandı, edit {r.json().get('id')}"
      + ("; incelemeye otomatik gönderildi." if auto or not hold else "; incelemeye gönderilmedi (Yayın özeti → Gönder)."))
