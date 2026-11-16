import json
import os
import urllib.error
import urllib.parse
import urllib.request

# Figlio del test del blocco login: fa UNA richiesta di login verso l'app girante nel container
# e stampa "CODICE|detail|retry-after".
# L'header X-Forwarded-For serve a riprodurre il caso reale dell'attaccante, che si attribuisce
# un indirizzo diverso a ogni richiesta: e' proprio lo scenario che il limiter per IP non riesce
# a fermare. uvicorn accetta l'header perche' la connessione arriva da 127.0.0.1, incluso in
# --forwarded-allow-ips.
u = os.environ["LK_USER"]
p = os.environ["LK_PASS"]
x = os.environ.get("LK_XFF", "10.77.0.1")

data = urllib.parse.urlencode({"username": u, "password": p}).encode()
req = urllib.request.Request(
    "http://localhost:8000/auth/token",
    data=data,
    headers={"Content-Type": "application/x-www-form-urlencoded", "X-Forwarded-For": x},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        print("%s|%s|%s" % (r.status, "", r.headers.get("Retry-After", "")))
except urllib.error.HTTPError as e:
    detail = ""
    try:
        detail = json.loads(e.read().decode()).get("detail", "")
    except Exception:
        pass
    print("%s|%s|%s" % (e.code, detail, e.headers.get("Retry-After", "")))
